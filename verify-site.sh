#!/usr/bin/env bash
# =============================================================================
# 本地验证 workflow 里那段 CI 逻辑（不用推送到 GitHub 就能跑）。
#
# 对应 AGENTS.md §6「改 workflow 后的验证清单」，把第 1–4 步做成可执行的：
#   1) 从 YAML 里抽出所有 run: 脚本
#   2) bash -n 语法检查 + 多字节陷阱 lint
#   3) 在 /tmp 的临时副本里真跑「编译」与「生成导航页」等步骤，覆盖 ①~⑪：
#        冷启动全量（含占位符注入与残留检查）/ HTML 转义 / 只改一个 deck 的增量
#        （含非 ASCII 目录名）/ 删除某套后的残留清理 / 某套编译失败必须 exit 1 /
#        文件夹名非法必须 exit 1（空格/点号开头/含换行）/ 一套都没有必须 exit 1 /
#        导航页边界（读不到 /Count、残留文件清理、BUILD_DIR 危险值被拒）/
#        Release/tag 逻辑（stub gh）/ 事件维度全量退化 / 列表顺序 / 样式表花括号平衡
#
# 用法：
#   bash verify-site.sh            # 只做静态检查（不编译，几秒）
#   bash verify-site.sh --build    # 连编译一起跑（需要本地 typst，约十几秒）
#
# 退出码 0 表示全部通过。
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")"

# 前置依赖检查（fail closed，报错指明缺什么）：本脚本用 ruby 解析 workflow 的 env、
# python3 做多字节 lint 与 ⑪、git 造夹具。缺了再往下跑只会得到**假红**
# （exit 127、或 YAML 读到空值后连环误报），所以先在这里拦住。
# （strings / typst 只有 --build 的编译路径才用，在 §3 开头单独查。）
for dep in ruby python3 git; do
  command -v "$dep" >/dev/null || { printf 'FAIL 缺少依赖：%s（verify-site.sh 需要它才能运行）\n' "$dep" >&2; exit 1; }
done

WF=.github/workflows/build-and-deploy.yml
# 每次运行用**独立**临时目录：写死 /tmp/slides-verify 时，两个并发运行（本地跑一遍的同时
# 另一个 agent 也在跑，或 CI 与本地同时跑）会互相 rm -rf 掉对方的 $TMP，
# 症状是后面莫名其妙的 exit 127 / 断言乱飞（本轮真踩过）。trap 负责清理。
TMP="$(mktemp -d "${TMPDIR:-/tmp}/slides-verify.XXXXXX")"
PASS=0; FAIL=0
ok()  { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
chk() { if [ "$2" = "$3" ]; then ok "$1（$3）"; else bad "$1：期望 [$3]，实际 [$2]"; fi; }
# 统一抓「输出 + 退出码」：`out="$(...)"; rc=$?` 在门禁自己被 -e 跑时（有人 `bash -e verify-site.sh`）
# 会在期望非零的断言处静默退出、连 FAIL 都印不出来。capture 用 if/else 取码，-e 下也不中断。
capture() { if out="$("$@" 2>&1)"; then rc=0; else rc=$?; fi; }

# 无论从哪条路径退出都清掉临时目录 —— 校验脚本自己不该留垃圾（失败时最容易留）
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/scripts"

# workflow env: 里的这两个值不写死：直接从 YAML 读，避免和 workflow 各说各话
# （写死过一次 TYPST_VERSION，workflow 一升级就会让 stamp 比对失败、走进全量分支而**假红**）
wf_env() {
  ruby -ryaml -e 'v = YAML.load_file(ARGV[0])["env"] || {}; print(v[ARGV[1]].to_s)' "$WF" "$1"
}
TYPST_VERSION="$(wf_env TYPST_VERSION)"
RELEASE_TZ="$(wf_env RELEASE_TZ)"
BUILD_DIR="$(wf_env BUILD_DIR)"
# RECENT_DAYS 也要从 YAML 读、并传给导航页那步：不读的话门禁永远只测到脚本里的
# `${RECENT_DAYS:-3}` 兜底值，workflow 里写成 'abc' 也能全绿（实测），而线上是
# **一个圆点都不出现**的静默失效。
RECENT_DAYS="$(wf_env RECENT_DAYS)"
if [ -n "$TYPST_VERSION" ] && [ -n "$BUILD_DIR" ]; then
  ok "从 workflow 读到 env：TYPST_VERSION=$TYPST_VERSION BUILD_DIR=$BUILD_DIR RECENT_DAYS=${RECENT_DAYS:-（空）}"
else
  bad "没读到 workflow 的 env（TYPST_VERSION/BUILD_DIR），脚本和工作流可能已脱节"
  TYPST_VERSION="${TYPST_VERSION:-0.15.1}"; BUILD_DIR="${BUILD_DIR:-build}"
fi
RECENT_DAYS="${RECENT_DAYS:-3}"
RELEASE_TZ="${RELEASE_TZ:-Asia/Shanghai}"

echo "── 1) 从 YAML 抽出 run: 脚本 ──"
ruby -ryaml -e '
  wf = YAML.load_file(ARGV[0]); out = ARGV[1]; require "fileutils"; FileUtils.mkdir_p(out)
  wf["jobs"].each { |jn, job| job["steps"].each_with_index { |s, i|
    next unless s["run"]; File.write("#{out}/#{jn}-#{i}.sh", s["run"]) } }
  # 复合 action（.github/actions/*\/action.yml）里的 run 步骤同样是 CI 逻辑，
  # 但不在 workflow 文件里 —— 不抽出来的话 bash -n / 多字节 lint 都覆盖不到它。
  Dir.glob(".github/actions/*/action.yml").each { |af|
    a = YAML.load_file(af); steps = a.dig("runs", "steps"); next unless steps
    name = File.basename(File.dirname(af))
    steps.each_with_index { |s, i|
      next unless s["run"]; File.write("#{out}/action-#{name}-#{i}.sh", s["run"]) } }' \
  "$WF" "$TMP/scripts"
n=$(ls "$TMP/scripts"/*.sh 2>/dev/null | wc -l | tr -d ' ')
if [ "$n" -ge 4 ]; then ok "抽出 $n 段脚本"; else bad "只抽出 $n 段脚本（应 ≥4）"; fi
n_act=$(ls "$TMP"/scripts/action-*.sh 2>/dev/null | wc -l | tr -d ' ')
if [ -f .github/actions/setup-fonts/action.yml ] && [ "$n_act" -eq 0 ]; then
  bad "setup-fonts 复合 action 的 run 步骤没被抽出来（语法/lint 覆盖不到它）"
elif [ "$n_act" -gt 0 ]; then
  ok "复合 action 的 $n_act 段 run 脚本也纳入检查"
fi

echo "── 2) 语法与多字节检查 ──"
# 注意：`bash -n f1 f2 f3` 只把第一个当脚本、其余当位置参数 —— 语法检查会**静默只覆盖一个文件**。
# 所以必须逐个文件跑（本轮对抗复核实测：把第二个文件改坏，原来的写法仍然报「全部通过」）。
n_syn=0; syn_ok=1; : > "$TMP/syntax.err"
for f in "$TMP"/scripts/*.sh; do
  n_syn=$((n_syn + 1))
  bash -n "$f" 2>>"$TMP/syntax.err" || syn_ok=0
done
if [ "$syn_ok" -eq 1 ]; then ok "bash -n 全部通过（$n_syn 个脚本）"
else bad "bash -n 报错：$(head -2 "$TMP/syntax.err" | tr '\n' ' ')"; fi

# 多字节陷阱 lint 也扫**门禁自己**（verify-site.sh）：以前只扫抽出来的 workflow 脚本，于是
# 门禁自己踩了同一个坑却没人拦 —— 2026-10-17 我就在 ③ 里写了 `chk "…（$survivor）"`，
# bash 3.2 把 `）` 当成变量名的一部分，直接 `survivor）: unbound variable` 中断整次运行
# （GNU bash 5 上不会复现，所以 CI 也发现不了）。**整行注释不算**：注释不参与参数展开，
# 里面写 `$var 紧跟中文` 是解释文字，不是陷阱 —— 不去掉的话这条 lint 会把说明文字也判红。
mb=$(python3 - "$TMP/scripts" verify-site.sh <<'PY'
import glob, re, sys
p = re.compile(rb'\$[A-Za-z_][A-Za-z0-9_]*(\[[^\]]*\])?(?=[\x80-\xff])')
def count(path):
    n = 0
    for line in open(path, 'rb').read().split(b'\n'):
        if line.lstrip().startswith(b'#'):
            continue
        n += len(p.findall(line))
    return n
files = glob.glob(sys.argv[1] + '/*.sh') + [sys.argv[2]]
print(sum(count(f) for f in files))
PY
)
chk "多字节陷阱（\$var 紧跟中文）数量" "$mb" 0

# ── 2.2) job/step 级配置的不变量 ──
# 这一层（job 的 if / needs、checkout 的 with）门禁以前**一个字都读不到**：它只抽取 `run:` 脚本。
# 而这些配置改坏了全是静默失效，实测（2026-10-17 独立复核）把下面任何一处改坏，门禁都**依然
# 98 通过 / 0 失败**：
#   * verify job 少跑 `--build` → 编译路径 ①~⑪ 整个不跑，门禁退化成「只做静态检查」的假绿；
#   * build 不再 `needs: verify` → 门禁红了站点与 Release 照样发布；
#   * 少 `github.event.deleted != true` → 删 tag/分支会把它重新创建出来；
#   * checkout 少 `fetch-depth: 0` → 首页排序与「最近更新」圆点拿不到真实历史（夹具各自带 .git，
#     端到端那部分**测不到**这一层）。
echo "── 2.2) job/step 级配置（YAML 结构断言）──"
wfq() { ruby -ryaml -e "$1" "$WF" 2>/dev/null; }
verify_run="$(wfq 'wf=YAML.load_file(ARGV[0]); print((wf["jobs"]["verify"]["steps"]||[]).map{|s| s["run"].to_s}.grep(/verify-site\.sh/).first.to_s)')"
if grep -q -- '--build' <<<"$verify_run"; then
  ok "②·2 verify job 跑的是 verify-site.sh --build"
else
  bad "②·2 verify job 没跑 verify-site.sh --build（编译路径 ①~⑪ 会整个不跑，门禁变成假绿）"
fi
chk "②·2 build job 依赖 verify（needs）" \
    "$(wfq 'print(Array(YAML.load_file(ARGV[0])["jobs"]["build"]["needs"]).join(","))')" "verify"
# **不能只做子串包含**：把条件写成 `github.event.deleted != true || (…)`（恒真）时子串断言照样绿，
# 而 deploy 会在 PR / tag 事件上跑（2026-10-17 复核实测）。所以折叠空白后要求守卫是**第一个合取项**。
for j in verify build release deploy; do
  if [ "$(wfq "v=YAML.load_file(ARGV[0])['jobs']['$j']['if'].to_s.gsub(/\s+/, ' '); print((v == 'github.event.deleted != true' || v.start_with?('github.event.deleted != true &&')) ? 'yes' : 'no')")" = "yes" ]; then
    ok "②·2 $j job 带 deleted 防护（删 tag/分支不该重建 Release）"
  else
    bad "②·2 $j job 的 if 里没有 github.event.deleted != true（删 tag/分支会触发它）"
  fi
done
chk "②·2 build 的 checkout 带 fetch-depth: 0（首页排序与圆点要真实历史）" \
    "$(wfq 'print((YAML.load_file(ARGV[0])["jobs"]["build"]["steps"]||[]).map{|s| (s["with"]||{})["fetch-depth"]}.compact.first.to_s)')" "0"
# 其余 job 级配置同样「改坏了没有任何断言会红」（2026-10-17 加的 4 条，仍是结构性的少数几条）：
chk "②·2 四个 job 的 runs-on 都钉在 ubuntu-24.04（不用 ubuntu-latest）" \
    "$(wfq 'print(YAML.load_file(ARGV[0])["jobs"].map{|k,j| j["runs-on"].to_s}.uniq.join(","))')" "ubuntu-24.04"
chk "②·2 每个 job 都有 timeout-minutes（不设默认 6 小时，会占着 runner 与 concurrency）" \
    "$(wfq 'print(YAML.load_file(ARGV[0])["jobs"].count{|k,j| j["timeout-minutes"].is_a?(Integer)})')" \
    "$(wfq 'print(YAML.load_file(ARGV[0])["jobs"].size)')"
chk "②·2 build 有 slides-build-<ref> 的 concurrency 且 cancel-in-progress" \
    "$(wfq 'c=(YAML.load_file(ARGV[0])["jobs"]["build"]["concurrency"]||{}); print((c["group"].to_s.include?("slides-build-") && c["cancel-in-progress"]==true) ? "ok" : c.inspect)')" "ok"
chk "②·2 deploy 的 permissions 有 pages: write + id-token: write" \
    "$(wfq 'p=YAML.load_file(ARGV[0])["jobs"]["deploy"]["permissions"]||{}; print((p["pages"]=="write" && p["id-token"]=="write") ? "ok" : p.inspect)')" "ok"

# ── 2.5) Release/tag 计算逻辑（stub 掉 gh，不需要 typst，几毫秒）──
# 这段逻辑决定「写不写 Release 说明」，一旦判错就会覆盖用户手写的说明，所以必须真跑一遍。
# 关键不变量：只有明确 not found / 404 才算「不存在」，403/5xx 必须 fail closed。
echo "── 2.5) Release/tag 计算（stub gh）──"
TAGSTEP=""
for f in "$TMP"/scripts/*.sh; do grep -q 'managed=true' "$f" 2>/dev/null && TAGSTEP="$f"; done
if [ -z "$TAGSTEP" ]; then
  bad "找不到「计算 tag」步骤（应含 managed=true）"
else
  ok "找到「计算 tag」步骤"
  STUB="$TMP/stub"; mkdir -p "$STUB"
  cat > "$STUB/gh" <<'STUBEOF'
#!/usr/bin/env bash
# 测试替身：只实现 `gh release view`，行为由 GH_STUB_MSG / GH_STUB_RC 控制
if [ "${1:-}" = "release" ] && [ "${2:-}" = "view" ]; then
  printf '%s\n' "${GH_STUB_MSG:-}"
  exit "${GH_STUB_RC:-1}"
fi
exit 0
STUBEOF
  chmod +x "$STUB/gh"
  OUTF="$TMP/runner25/tag-out.txt"; mkdir -p "$TMP/runner25"
  run_tag() { ( cd "$TMP" && PATH="$STUB:$PATH" RUNNER_TEMP="$TMP/runner25" GITHUB_OUTPUT="$OUTF" \
      GITHUB_REPOSITORY=o/r RELEASE_TZ="$RELEASE_TZ" GITHUB_EVENT_NAME="$1" GITHUB_REF_TYPE="$2" \
      GITHUB_REF_NAME="$3" RELEASE_TAG="$4" GH_STUB_MSG="$5" GH_STUB_RC="$6" \
      RELEASE_VIEW_RETRIES=2 RELEASE_VIEW_BACKOFF=0 bash "$TAGSTEP" ); }

  : > "$OUTF"; capture run_tag push branch main "" "release not found" 1
  chk "⑧ push main：exit" "$rc" 0
  grep -q '^managed=true$' "$OUTF" && ok "⑧ 日常 push → managed=true" || bad "⑧ 日常 push 的 managed 不对"
  grep -q "^tag=v$(TZ="$RELEASE_TZ" date +%Y.%m.%d)$" "$OUTF" && ok "⑧ 日常 push → tag 按日期" || bad "⑧ tag 不是日期格式"
  grep -q '^exists=false$' "$OUTF" && ok "⑧ not found → exists=false" || bad "⑧ not found 没被判成不存在"

  capture run_tag push branch main "" "HTTP 403: API rate limit exceeded" 1
  chk "⑧ gh 403 必须 exit 1（不许当成「不存在」）" "$rc" 1
  if grep -q '::error::' <<<"$out"; then ok "⑧ 403 有 ::error:: 标注"; else bad "⑧ 403 没有 ::error::"; fi

  : > "$OUTF"; capture run_tag push branch main "" "" 0
  chk "⑧ gh 正常：exit" "$rc" 0
  grep -q '^exists=true$' "$OUTF" && ok "⑧ 已存在 → exists=true" || bad "⑧ exists 不是 true"
  grep -q '^ours=false$' "$OUTF" && ok "⑧ 无机器标记 → ours=false（说明是别人的，别动）" || bad "⑧ ours 不是 false"

  # 只有带机器标记的说明才允许刷新：手写说明必须被保护（日期 tag 也一样）
  : > "$OUTF"; capture run_tag push branch main "" '<!-- ci-managed -->' 0
  chk "⑧ 带标记的说明：exit" "$rc" 0
  grep -q '^ours=true$' "$OUTF" && ok "⑧ 带机器标记 → ours=true（可以刷新说明）" || bad "⑧ 带标记却判成了 ours=false"

  : > "$OUTF"; run_tag push tag "v1.0.0" "" "release not found" 1 >/dev/null 2>&1
  grep -q '^tag=v1.0.0$' "$OUTF" && ok "⑧ 推 tag → 用该 tag" || bad "⑧ 推 tag 没用该 tag"
  grep -q '^managed=false$' "$OUTF" && ok "⑧ 推 tag → managed=false" || bad "⑧ 推 tag 的 managed 不对"

  : > "$OUTF"; run_tag release "" "" "v9.9.9" "release not found" 1 >/dev/null 2>&1
  grep -q '^tag=v9.9.9$' "$OUTF" && ok "⑧ release 事件 → 用 Release 自带的 tag" || bad "⑧ release 事件没用自带 tag"

  # 旋钮防呆：RELEASE_VIEW_RETRIES 被设成非数字时**绝不能**退化成「循环零次 → 静默当成不存在」。
  # （GNU 的 `seq 1 abc` 给空输出，正是这么退化的；本机 BSD 反而是跑一次。）
  if out="$(cd "$TMP" && PATH="$STUB:$PATH" RUNNER_TEMP="$TMP/runner25" GITHUB_OUTPUT="$TMP/runner25/knob.txt" \
    GITHUB_REPOSITORY=o/r RELEASE_TZ="$RELEASE_TZ" GITHUB_EVENT_NAME=push GITHUB_REF_TYPE=branch \
    GITHUB_REF_NAME=main RELEASE_TAG= GH_STUB_MSG="HTTP 500: server error" GH_STUB_RC=1 \
    RELEASE_VIEW_RETRIES=abc RELEASE_VIEW_BACKOFF=0 bash "$TAGSTEP" 2>&1)"; then rc=0; else rc=$?; fi
  chk "⑧ RELEASE_VIEW_RETRIES=abc 仍要 fail closed" "$rc" 1
fi

# ⑧c 「只更新附件」这步（Release 已存在但说明不是我们写的）：改用 gh release upload --clobber，
#     理由是**语义性**的 —— 它只动附件、天然不碰 body。softprops 的更新路径在本仓库报过一次
#     403（2026-10-01，61 次运行里仅此一次、样本 n=1，因果未坐实；2026-10-17 复核指出旧注释
#     写成「实测必然 403」是过度断言）。
#     这条断言钉住「用 gh、带 --clobber、没有 PDF 必须 exit 1」。
ATTACH=""
for f in "$TMP"/scripts/*.sh; do grep -q 'gh release upload' "$f" 2>/dev/null && ATTACH="$f"; done
if [ -z "$ATTACH" ]; then
  bad "找不到「只更新附件」步骤（应含 gh release upload）"
else
  ok "找到「只更新附件」步骤"
  AT="$TMP/attach"; mkdir -p "$AT/build"
  cat > "$AT/gh" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${GH_CALLS:-/dev/null}"
exit "${GH_RC:-0}"
STUBEOF
  chmod +x "$AT/gh"
  printf 'x\n' > "$AT/build/a.pdf"; printf 'y\n' > "$AT/build/b.pdf"
  : > "$AT/calls.txt"
  if ( cd "$AT" && PATH="$AT:$PATH" GH_CALLS="$AT/calls.txt" BUILD_DIR=build TAG=v1.0 GITHUB_REPOSITORY=o/r bash "$ATTACH" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
  chk "⑧ 只更新附件：exit" "$rc" 0
  if grep -q 'release upload v1.0 build/a.pdf build/b.pdf --clobber --repo o/r' "$AT/calls.txt" 2>/dev/null; then
    ok "⑧ 附件走 gh release upload --clobber（完全不碰 body）"
  else bad "⑧ 附件上传参数不对：$(head -1 "$AT/calls.txt" 2>/dev/null)"; fi
  rm -f "$AT/build"/*.pdf
  if ( cd "$AT" && PATH="$AT:$PATH" BUILD_DIR=build TAG=v1.0 GITHUB_REPOSITORY=o/r bash "$ATTACH" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
  chk "⑧ 没有 PDF 时必须 exit 1（替代 action 的 fail_on_unmatched_files）" "$rc" 1
fi

# ⑧b 「生成 Release 说明」这步也真跑一遍：它决定说明里的下载链接，tag 里的特殊字符
#     （空格/括号/#/%）必须整体百分号编码，只转义括号会让 Markdown 链接被截断。
NOTES=""
for f in "$TMP"/scripts/*.sh; do grep -q 'release-notes.md' "$f" 2>/dev/null && NOTES="$f"; done
if [ -z "$NOTES" ]; then
  bad "找不到「生成 Release 说明」步骤（应含 release-notes.md）"
else
  NT="$TMP/notes"; mkdir -p "$NT/build"; printf 'x\n' > "$NT/build/demo.pdf"
  if out="$(cd "$NT" && RUNNER_TEMP="$NT" BUILD_DIR=build RELEASE_TZ="$RELEASE_TZ" \
      TAG='v1.0 (beta)#1' MANAGED=false GITHUB_REPOSITORY=o/r GITHUB_REPOSITORY_OWNER=o \
      GITHUB_SHA=abcdef1234 bash "$NOTES" 2>&1)"; then rc=0; else rc=$?; fi
  chk "⑧ 生成 Release 说明：exit" "$rc" 0
  if grep -q 'v1.0%20%28beta%29%231' "$NT/release-notes.md" 2>/dev/null; then
    ok "⑧ tag 里的空格/括号/# 被整体百分号编码"
  else bad "⑧ tag 没有被整体编码（说明里的下载链接可能被截断）"; fi
  if grep -q 'demo.pdf' "$NT/release-notes.md" 2>/dev/null; then ok "⑧ 说明里列出了 PDF"
  else bad "⑧ 说明里没列出 PDF"; fi
  if grep -qF '<!-- ci-managed -->' "$NT/release-notes.md" 2>/dev/null; then ok "⑧ 说明末尾带机器标记（下次靠它判断该不该刷新）"
  else bad "⑧ 说明里没有机器标记 → 下次会把自己的说明当成别人的，永不刷新"; fi
fi

# ⑪ 样式表花括号平衡。多一个（或少一个）`}` **不报错、不白屏**，只会把它**后面的规则静默吞掉**：
#    2026-10 真踩过 —— 一段重复的注释末尾多带了一个 `}`，紧跟其后的
#    `@media (min-width: 640px) { .page-title { margin-left: 1.5rem } }` 被整块吃掉，
#    表现是桌面端 h1 和头像**贴在一起**（无头 Chrome 实测 gap 0.0px，修好是 24px）。
#    页面照样渲染、CSSOM 也不抛错（只是 cssRules 从 51 悄悄变成 50），截图极易看漏 ——
#    这一类没有运行时替代品（CI 里没有浏览器），所以用静态计数钉住。
#    统计前先去掉 **HTML 注释**与 `/* … */`（注释里的括号不该参与计数）；python3 是本脚本已有的依赖。
#    为什么必须先去 HTML 注释：模板开头的注释里就写着 `<style>` 这个字面量（提醒维护者去哪改样式），
#    不剥注释的话 `re.search(r"<style>")` 会从**注释里那个** `<style>` 开始、一直截到真正的
#    `</style>`，把注释与整个 `<head>` 都算进「样式表」（实测多算 1482 字节）。后果是双向的：
#    注释里多一个 `}` 会**假红**，而真实样式表少一个 `}` 恰好被注释里多出的一个抵消时**假绿**
#    —— 历史事故正是「一段重复的注释末尾多带了一个 `}`」，这个 bug 恰好把它盖回去。
BAL="$(python3 - index.template.html <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
s = re.sub(r"<!--[\s\S]*?-->", "", s)
s = re.sub(r"/\*[\s\S]*?\*/", "", s)
m = re.search(r"<style>([\s\S]*?)</style>", s)
print(m.group(1).count("{"), m.group(1).count("}")) if m else print("no-style")
PY
)"
case "$BAL" in
  no-style|"") bad "⑪ 模板里找不到 <style> 块（选择器改坏了？）" ;;
  *)
    opens="${BAL%% *}"; closes="${BAL##* }"
    if [ "$opens" = "$closes" ]; then
      ok "⑪ 样式表花括号平衡（{ ${opens} 个 = } ${closes} 个）"
    else
      bad "⑪ 样式表花括号不平衡：{ ${opens} 个、} ${closes} 个 —— 多/少的那一个会把它后面的规则静默吞掉"
    fi ;;
esac

if [ "${1:-}" != "--build" ]; then
  echo
  printf '静态检查：%d 通过 / %d 失败（加 --build 可连编译路径一起验）\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]; exit
fi

echo "── 3) 真跑 ①~⑪（需要 typst）──"
# 编译路径的额外依赖：typst 编译夹具；导航页步骤用 strings 读 PDF 的 /Count。
for dep in typst strings; do
  command -v "$dep" >/dev/null || { bad "没找到 ${dep}，跳过编译路径"; printf '%d 通过 / %d 失败\n' "$PASS" "$FAIL"; exit 1; }
done

COMPILE=""; INDEX=""
# **按内容签名定位步骤，不认 steps 下标**：抽取出来的文件名是 build-<下标>.sh，
# 而 workflow 里插入/删除任何一步都会让下标整体位移 —— 错位最坏的后果不是报错，而是
# 静默测错步骤（比如拿生成导航页的脚本去验护栏，永远通过）。所以按签名挑文件。
for f in "$TMP"/scripts/*.sh; do
  grep -q 'typst compile' "$f" 2>/dev/null && COMPILE="$f"
  grep -q '<!--SLIDES-->' "$f" 2>/dev/null && INDEX="$f"
done
if [ -z "$COMPILE" ]; then
  bad "在抽出的脚本里找不到「编译」步骤（应含 typst compile），门禁需要更新"
  printf '%d 通过 / %d 失败\n' "$PASS" "$FAIL"; exit 1
fi
if [ -z "$INDEX" ]; then
  bad "在抽出的脚本里找不到「生成导航页」步骤（应含 <!--SLIDES-->），门禁需要更新"
  printf '%d 通过 / %d 失败\n' "$PASS" "$FAIL"; exit 1
fi
# ⑨b 编译环境哈希必须覆盖装字体的复合 action：字体逻辑抽到 .github/actions/setup-fonts 之后，
#    wf_rev 若仍只哈希 workflow 文件，改字体（在 action 里）就不会让 stamp 失配 ——
#    未改动的 deck 会静默复用「旧字体编出来的 PDF」，正是 stamp 机制要防的那种失效。
if grep -q 'setup-fonts/action\.yml' "$COMPILE"; then
  ok "⑨b 编译环境哈希覆盖 setup-fonts 复合 action（改字体 = 全量重编）"
else
  bad "⑨b 编译环境哈希没覆盖 setup-fonts/action.yml（改字体不会触发全量重编）"
fi
# ⑨b' 指纹还要含**装上的字体包版本**：runs-on 钉住 ubuntu-24.04 不等于钉住字体（镜像标签会被
#     原地滚动、apt 取的是档案库当前版本），不记版本的话字体悄悄更新后未改动的 deck 会复用旧字体
#     编出的 PDF，而这次改过的 deck 用新字体 —— 同一站点排版不一致且不自愈。
# 只 `grep -q 'dpkg-query'` 会被**注释**满足：编译步的注释里就写着这个词（解释取不到时为空），
# 于是把真调用删掉、注释留着，门禁依然全绿（2026-10-17 复核实测）。所以锚到赋值那一行。
if grep -qE '^[[:space:]]*fonts_ver=.*dpkg-query' "$COMPILE"; then
  ok "⑨b' 编译环境指纹含字体包版本（dpkg-query）"
else
  bad "⑨b' 指纹没有含字体包版本：字体悄悄更新后未改动的 deck 会复用旧字体编出的 PDF"
fi
# workflow 里 env: 级别的变量（上面已从 YAML 读出，不再写死）
run_compile() { ( cd "$1" && RUNNER_TEMP="$2" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
    RELEASE_TZ="$RELEASE_TZ" GITHUB_EVENT_NAME="${4:-push}" GITHUB_REF="${5:-refs/heads/main}" \
    GITHUB_SHA="${3:-$(git rev-parse HEAD 2>/dev/null || echo nosha)}" bash "$COMPILE" ); }
run_index() { ( cd "$1" && RUNNER_TEMP="$2" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
    RELEASE_TZ="$RELEASE_TZ" RECENT_DAYS="$RECENT_DAYS" bash "$INDEX" ); }
# 与 workflow 编译步骤的「编译环境哈希」算法保持一致：workflow + 装字体的复合 action
# 两个文件一起哈希，**再加装上的字体包版本**（dpkg-query；本机 macOS 上没有它 → 空串，
# 与 workflow 里的算法逐字相同，两边都为空即一致）。两边只要有一处对不上，②⑨ 就会走进
# 「环境变了 → 全量」分支而**假红**（这门门禁自己的 TYPST_VERSION 写死翻车史见 §6 的
# 鲁棒性约定 —— 同一个教训）。
wf_rev_of() {
  ( cd "$1" && h="$(git hash-object "$WF" .github/actions/setup-fonts/action.yml 2>/dev/null)" \
      && fonts="$( (dpkg-query -W -f='${Package}=${Version}\n' fonts-noto-cjk fonts-inter 2>/dev/null || true) | LC_ALL=C sort )" \
      && printf '%s\n%s\n' "$h" "$fonts" | git hash-object --stdin | cut -c1-12 )
}
# 夹具里的提交一律显式关掉 GPG 签名：开发机若全局开了 commit.gpgsign（很常见的配置），
# 夹具的 commit 会直接失败（rc=128、`cannot run gpg`），而下面几处 `|| true` 会把它吞掉 ——
# 夹具 HEAD 不前进，于是 ①（圆点=套数）、②（复用 N-1）、②b、⑩ 一起假红，报错还分别指向
# core.quotePath、排序键这些**完全无关**的子系统（实测：全局 gpgsign 下 93 通过 / 5 失败）。
# `gitc` 只关签名，其它（日期、消息）照旧由调用方给。
gitc() { git -c commit.gpgsign=false -c user.email=v@x -c user.name=v commit "$@"; }
fresh() {
  rm -rf "$1"; mkdir -p "$1" "$1/build"; cp -R ./. "$1"/; rm -rf "$1/build"; mkdir -p "$1/build"
  # 快照一次：工作树里未提交的改动（新增了 deck 目录等）不会出现在 `git diff <基准> HEAD` 里，
  # 会让 ② 的「改了一套 → 复用 N-1」断言假红。先提交副本里的现状，基准才与内容一致。
  # 这一次在干净工作树上**允许**是空操作（nothing to commit），所以不检查 HEAD 是否前进。
  ( cd "$1" && git add -A && gitc -qm "fixture snapshot" ) >/dev/null 2>&1 || true
  # 让每套 deck 都「**刚刚**提交过」—— 这是 ①「最近更新标记数 = 套数」的前提，而它**不能靠
  # 真实历史**：上面那次快照提交在**干净工作树**上是个空操作（nothing to commit，被 `|| true`
  # 吞掉），而 CI 的检出就是干净的 —— 夹具于是继承仓库真实提交日期。后果是「某套 deck 超过
  # RECENT_DAYS 没动过」的那天起，① 会突然变红 → verify 失败 → `build: needs: verify` 把
  # 部署和发版一起卡死（实测：把副本里所有 deck 的提交日期改成 20–25 天前、工作树干净 →
  # 「① 最近更新标记数：期望 [2]，实际 [0]」，98 通过 / 1 失败）。**假红比漏报更糟**，
  # 所以这里显式给每套 deck 追加一行注释并提交：内容照样可编译，路径历史被刷新成「刚刚」。
  for d in "$1"/slides/*/; do
    [ -f "${d}main.typ" ] || continue
    printf '\n// fixture: freshly committed（门禁夹具专用，见 verify-site.sh 的 fresh()）\n' >> "${d}main.typ"
  done
  # 这一次提交**必须**真的产生新提交（有内容可提交），否则 ① 会在别处报一个误导人的假红。
  # 所以显式比较提交前后的 HEAD：没前进就当场 bad，把原因指到夹具初始化上。
  before_head="$( cd "$1" && git rev-parse HEAD 2>/dev/null || true )"
  ( cd "$1" && git add -A && gitc -qm "fixture: make every deck freshly committed" ) >/dev/null 2>&1 || true
  after_head="$( cd "$1" && git rev-parse HEAD 2>/dev/null || true )"
  if [ -z "$after_head" ] || [ "$after_head" = "$before_head" ]; then
    bad "夹具初始化失败：fresh($1) 的「刚刚提交」没产生新提交（HEAD 停在 ${before_head:-空}）——① 的圆点断言会因此假红（gpgsign？磁盘满？）"
  fi
}

# typst 默认把包缓存写到 $HOME；HOME 不可写（沙箱 / 受限 runner）时每套 deck 都会报
# 「failed to create temporary package directory」，看起来像 deck 坏了 —— 典型假红。
# 默认指到本次运行的临时目录；外部显式设了 TYPST_PACKAGE_CACHE_PATH 就尊重外部值。
export TYPST_PACKAGE_CACHE_PATH="${TYPST_PACKAGE_CACHE_PATH:-$TMP/typst-pkg}"
mkdir -p "$TYPST_PACKAGE_CACHE_PATH" 2>/dev/null || true

R="$TMP/repo"; T="$TMP/runner"; mkdir -p "$T"
fresh "$R"
# 期望套数**从夹具推导**，不写死：仓库加一套幻灯片（§1 承诺的「cp -R slides/template … 后
# push 即可」）不该让门禁假红 —— 假红比漏报更糟，它会诱使人把断言改松（§6 已警告过）。
n_decks=0
for d in "$R"/slides/*/; do [ -f "${d}main.typ" ] && n_decks=$((n_decks + 1)); done
capture run_compile "$R" "$T"
chk "① 冷启动全量：exit" "$rc" 0
chk "① 产出 PDF 数" "$(ls "$R"/build/*.pdf 2>/dev/null | wc -l | tr -d ' ')" "$n_decks"
chk "① 写了 .build-stamp" "$([ -f "$R/build/.build-stamp" ] && echo yes || echo no)" yes
run_index "$R" "$T" >/dev/null 2>&1
chk "① 首页卡片数" "$(grep -c 'class="deck fade"' "$R/build/index.html")" "$n_decks"
# 卡片必须落在**可见**位置。只数字面量的断言有两种盲区（2026-10-17 独立复核实测，两种变异
# 都能让门禁 98 通过 / 0 失败）：
#   (a) 模板里有个漏写 `-->` 的注释 → 从注释处起、卡片与页脚全被浏览器吞掉（产物注释不成对）；
#   (b) 注入点被包进一对**完整**的注释 → 注释成对，但卡片全在注释里。
# 两条断言必须一起上：只查成对抓不到 (b)（模板里多出的注释恰好配平），只剥注释再数抓不到 (a)
# （未闭合的 `<!--` 不会被正则删掉，卡片照旧数得到）。
prod="$R/build/index.html"
c_open="$(grep -o '<!--' "$prod" | wc -l | tr -d ' ')"
c_close="$(grep -o -- '-->' "$prod" | wc -l | tr -d ' ')"
if [ "$c_open" = "$c_close" ]; then
  ok "① 产物里 HTML 注释成对（$c_open 对；不成对说明模板漏写了 -->，会把整段卡片吞掉）"
else
  bad "① 产物里 HTML 注释不成对（<!-- $c_open 个、--> $c_close 个）：多半是模板里漏写 -->，整段卡片会被注释吞掉"
fi
chk "① 卡片在注释之外（剥掉注释后仍数得到）" "$(python3 - "$prod" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
print(re.sub(r"<!--[\s\S]*?-->", "", s).count('class="deck fade"'))
PY
)" "$n_decks"
# 头像等站点资源是「生成导航页」那步从 assets/ 拷进 build/ 的：漏拷不会报错，
# 只是 img 被 onerror 静默删掉，所以这里钉一下产物里确实有它
chk "① 站点资源 icon.png 已进 build/" "$([ -f "$R/build/icon.png" ] && echo yes || echo no)" yes
# 「最近更新」小圆点：夹具里的 deck 都是 fresh() 刚提交的（提交日期=今天），所以每张卡片
# 都该有。反方向（旧 deck / 取不到日期时**不能**有）由 ⑩ 的 R10 夹具钉着。
chk "① 最近更新标记数 = 套数（夹具都是刚提交的）" "$(grep -c 'class="dot"' "$R/build/index.html" || true)" "$n_decks"
# 占位注释必须被**消费掉**：token 拼对了、但 workflow 那侧的 awk 规则被删/改名时，那一行会
# 原样留在产物里（HTML 注释在页面上根本看不见，连症状都没有）—— 属于典型「门禁假绿」区。
# **它不管什么**：token 自己拼错（比如写成 `<!--SLIDE-->`）时残留 grep 是空的，那种由上面
# 那条「首页卡片数」兜住（卡片会变成 0）。别把这条当万能。
# 以前这里钉的是「页面 h1 里的 count 胶囊是个数字」，那条断言跟着标题从 h2 搬到 h1 改过一次；
# 2026-10 标题旁的套数去掉之后（见 docs/site-design.md），改成钉三个 token 的残留。
# `|| true`：没有残留 = grep 退出 1，pipefail 会让整条管道非零，而那是**成功**路径 ——
# 不加的话 `bash -e verify-site.sh` 会在这里无声中止（脚本顶部 capture 的注释讲的就是这件事）。
left="$(grep -oE '<!--(SLIDES|COUNT|META)-->' "$R/build/index.html" | paste -sd' ' - || true)"
chk "① 占位注释已全部消费（产物里没有残留）" "$left" ""
# 断言**页脚区里出现一个 YYYY-MM-DD HH:MM 时间戳**，而不是某句固定文案：文案是随时会改的
# 展示措辞（「最后更新」→「更新于」，2026-10 改），钉死它只会制造假红 —— 实测只改那句文案
# 就 85 通过 / 1 失败，报的还是「META 可能被改名/拼错」，把排查引向错误的方向。
# 占位符真被改名时页脚里会剩下 `<!--META-->`（上面那条残留 grep 也钉着），这条照样红。
# 用 here-string 而不是 `printf '%s' "$x" | grep -q`：脚本是 `set -uo pipefail`，数据一大、grep
# 提前退出就会让 printf 吃 EPIPE、整条管道变非零，把「匹配成功」判成失败（见 §7 那条坑）。
footer_html="$(sed -n '/<footer/,/<\/footer>/p' "$R/build/index.html")"
if grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}' <<<"$footer_html"; then
  ok "① 页脚时间戳已注入（META 占位符生效）"
else bad "① 页脚没有 YYYY-MM-DD HH:MM 时间戳：META 占位符被改名/拼错，或时间格式被改了"; fi
# ①b HTML 转义：title/subtitle 来自可编辑的 main.typ，转义护栏一旦回归就会在站点上执行注入。
# 造一个带 & < > 的标题，断言产物里是实体、且没有原始标签。
R7="$TMP/repo-escape"; fresh "$R7"
rm -rf "$R7/slides"; mkdir -p "$R7/slides/evil"
{
  printf '#set document(title: "<img src=x onerror=alert(1)> & q")\n'
  printf '#set page(paper: "a4")\n= 正文\n'
} > "$R7/slides/evil/main.typ"
capture run_compile "$R7" "$T"
chk "①b 转义夹具编译：exit" "$rc" 0
run_index "$R7" "$T" >/dev/null 2>&1
if grep -q '&lt;img src=x onerror=alert(1)&gt; &amp; q' "$R7/build/index.html"; then
  ok "①b 标题里的 & < > 被转义成实体"
else bad "①b 转义失效：产物里没有实体化的标题"; fi
if grep -q '<img src=x' "$R7/build/index.html"; then bad "①b 产物里出现未转义的原始标签（注入风险）"
else ok "①b 产物里没有未转义的原始标签"; fi

# ①c title/subtitle 抽取（tools/deck-meta.py）。旧实现是 shell 里三段逐行 sed，遇到下面这些
#     写法会**静默**截断或整段取不到 —— 而截断后的标题看着还挺合理，构建与门禁全绿
#     （2026-10-17 独立复核实测：`title: [外层 [内层] 结束]` 的卡片显示成「外层 [内层」；
#     跨行 `[ … ]` 直接退回文件夹名；正文里更晚出现的 `title: [...]` 会盖掉第一行的字符串标题）。
#     直接**单测脚本本身**，比只在产物里断言卡片文字更容易覆盖这些刁钻写法。
MT="$TMP/meta"; mkdir -p "$MT"
meta() { python3 tools/deck-meta.py "$1" "$2"; }
printf '#set document(title: "数组 a[0] 的用法")\n' > "$MT/inner.typ"
chk "①c 标题里的内层 ] 不被截断" "$(meta "$MT/inner.typ" title)" "数组 a[0] 的用法"
printf 'config-info(\n  title: [\n    跨行标题\n  ],\n  subtitle: [跨行副标题],\n)\n' > "$MT/multiline.typ"
chk "①c 跨行 title 能取到" "$(meta "$MT/multiline.typ" title)" "跨行标题"
chk "①c 跨行 subtitle 能取到" "$(meta "$MT/multiline.typ" subtitle)" "跨行副标题"
printf '#set document(title: "真标题")\n#outline(title: [目录], indent: auto)\n' > "$MT/order.typ"
chk "①c 取行序第一个 title（#set document 优先于更晚的 #outline）" "$(meta "$MT/order.typ" title)" "真标题"
printf '// title: [注释里的旧标题]\nconfig-info(title: [真标题])\n' > "$MT/comment.typ"
chk "①c 跳过注释行里的 title" "$(meta "$MT/comment.typ" title)" "真标题"
printf 'config-info(subtitle: [只有副标题], title: "单行")\n' > "$MT/keys.typ"
chk "①c subtitle: 不会被误当成 title:" "$(meta "$MT/keys.typ" title)" "单行"
chk "①c 单行 subtitle 能取到" "$(meta "$MT/keys.typ" subtitle)" "只有副标题"
printf '#set document(title: "他说 \\"你好\\" 然后走了")\n' > "$MT/escaped.typ"
chk "①c 转义引号不被截断" "$(meta "$MT/escaped.typ" title)" '他说 \"你好\" 然后走了'
printf 'config-info(title: [])\n' > "$MT/empty.typ"
chk "①c 空值返回空串（调用方退回文件夹名）" "$(meta "$MT/empty.typ" title)" ""
# ①c 还必须覆盖 `[...]` 分支本身：只测字符串分支的话，把配平换成「截到第一个 ]」也能全绿
# （2026-10-17 复核实测），而线上正是方括号写法最常见。顺带覆盖转义与两种注释。
printf 'config-info(title: [外层 [内层] 结束])\n' > "$MT/nested.typ"
chk "①c 方括号分支：内层 [ ] 不被截断" "$(meta "$MT/nested.typ" title)" "外层 [内层] 结束"
printf 'config-info(title: [他说 \\] 然后])\n' > "$MT/escbr.typ"
chk "①c 方括号分支：转义的 \\] 不参与配平" "$(meta "$MT/escbr.typ" title)" '他说 \] 然后'
printf '#let n = 1 // title: [行尾注释里的假标题]\nconfig-info(title: [真标题])\n' > "$MT/tailcomment.typ"
chk "①c 跳过行尾 // 注释里的 title" "$(meta "$MT/tailcomment.typ" title)" "真标题"
printf '/* title: [块注释里的假标题] */\nconfig-info(title: [真标题])\n' > "$MT/blockcomment.typ"
chk "①c 跳过 /* */ 块注释里的 title" "$(meta "$MT/blockcomment.typ" title)" "真标题"
# 光单测脚本还不够：导航页步骤必须**真的调用**它 —— 换回旧的逐行 sed 时 ①c 仍会全绿
# （那几条直接跑脚本，不经过 workflow），门禁就白钉了（2026-10-17 复核实测）。
if grep -q 'tools/deck-meta.py' "$INDEX"; then
  ok "①c 导航页步骤确实调用 tools/deck-meta.py"
else
  bad "①c 导航页步骤没有调用 tools/deck-meta.py（换回 shell 逐行解析时 ①c 会假绿）"
fi

# 增量：先把基准写成当前提交，再只改一个 deck
# （版本与 workflow 哈希都必须和脚本真正会写的那份一致，否则会走进「环境变了→全量」分支，
#   ② 就测不到增量路径了 —— 所以这里用上面从 YAML 读到的 TYPST_VERSION）
sha0="$(cd "$R" && git rev-parse HEAD)"
printf '%s %s %s\n' "$sha0" "$TYPST_VERSION" "$(wf_rev_of "$R")" > "$R/build/.build-stamp"
printf '\n// 故意改动\n' >> "$R/slides/template/main.typ"
(cd "$R" && git add -A && gitc -qm tmp) >/dev/null 2>&1
capture run_compile "$R" "$T" "$(cd "$R" && git rev-parse HEAD)"
chk "② 增量：exit" "$rc" 0
if grep -q '增量编译' <<<"$out"; then ok "② 走了增量"; else bad "② 没走增量"; fi
chk "② 复用的套数" "$(grep -c '没有改动，复用' <<<"$out")" "$((n_decks - 1))"
chk "② 重编的套数" "$(grep -c '✅' <<<"$out")" 1

# ②b 非 ASCII 文件夹名（§3.8 允许汉字名）的增量。
# git diff 默认 core.quotePath=true，会把 slides/中文甲/main.typ 输出成带引号 + 八进制转义的
# 形式，编译步骤里的 `grep -F "slides/中文甲/"` 于是永远匹配不上 → 该 deck 被当成「没有改动」
# 而复用旧 PDF，stamp 却照写新提交 → 静默发布旧内容且永不自愈。这条断言钉住 quotePath=false。
mkdir -p "$R/slides/中文甲"
cp -R "$R/slides/template/." "$R/slides/中文甲/"
(cd "$R" && git add -A && gitc -qm tmp-cjk) >/dev/null 2>&1
run_compile "$R" "$T" "$(cd "$R" && git rev-parse HEAD)" >/dev/null 2>&1   # 先编出来，并作为新基准
printf '\n// 故意改动\n' >> "$R/slides/中文甲/main.typ"
(cd "$R" && git add -A && gitc -qm tmp-cjk2) >/dev/null 2>&1
capture run_compile "$R" "$T" "$(cd "$R" && git rev-parse HEAD)"
chk "②b 中文目录名：exit" "$rc" 0
if grep -q '✅ 中文甲' <<<"$out"; then ok "②b 中文目录名的改动被重编（core.quotePath 已关）"
else bad "②b 中文目录名的改动被当成「没改动」而复用了旧 PDF（core.quotePath 没关？）"; fi

rm -rf "$R/slides/template"
capture run_compile "$R" "$T"
chk "③ 删除后清理：exit" "$rc" 0
chk "③ 残留 template.pdf" "$([ -f "$R/build/template.pdf" ] && echo 还在 || echo 已删)" 已删
# 「其余 PDF 保留」的幸存者**从夹具里动态取**，不写死某套 deck 的名字：这里曾经写死 26-09-30，
# 而作者哪天把日期型 deck 改名/归档（AGENTS.md 明说「改名等于换 URL」，归档很正常）就会假红成
# 「期望 [在]，实际 [没了]」，把排查引向清理逻辑（2026-10-17 独立复核实测：一次正常改名打出 3 条
# 假红 FAIL，③×1 + ④×2）。同一个教训在 §6 已写过一次（期望套数不写死）。
survivor=""
for d in "$R"/slides/*/; do
  sv="$(basename "$d")"
  if [ "$sv" != template ] && [ -f "${d}main.typ" ]; then survivor="$sv"; break; fi
done
if [ -n "$survivor" ]; then
  # ${survivor} 必须带花括号：`$survivor）` 在 bash 3.2 下会把多字节字节当成变量名的一部分，
  # 变成「survivor）: unbound variable」——本仓库 §7 记录的那个多字节陷阱，门禁自己踩了一次。
  chk "③ 其余 PDF 保留（${survivor}）" "$([ -f "$R/build/$survivor.pdf" ] && echo 在 || echo 没了)" 在
else
  bad "③ 夹具里找不到 template 之外的 deck，无法断言「其余 PDF 保留」"
fi

R2="$TMP/repo-fail"; fresh "$R2"
# 坏 deck 用夹具**自己造**的，不覆写真实 deck：以前往 slides/26-09-30/main.typ 写坏内容，
# 那套改名/删除后 `printf > …` 直接 No such file or directory，④ 的两条断言会一起假红。
rm -rf "$R2/slides"; mkdir -p "$R2/slides/broken"
printf '#set document(title: "坏的")\n#set page(paper: "a4")\n= 坏的\n#undefined-fn-xyz()\n' > "$R2/slides/broken/main.typ"
capture run_compile "$R2" "$T"
chk "④ 编译失败：exit" "$rc" 1
if grep -q '::error::' <<<"$out"; then ok "④ 有 ::error:: 标注"; else bad "④ 没有 ::error::"; fi

R3="$TMP/repo-badname"; fresh "$R3"
mkdir -p "$R3/slides/a b"; cp "$R3/slides/template/main.typ" "$R3/slides/a b/main.typ"
capture run_compile "$R3" "$T"
chk "⑤ 非法文件夹名：exit" "$rc" 1
if grep -q '不安全的字符' <<<"$out"; then ok "⑤ 拦住了空格"; else bad "⑤ 没拦住空格"; fi

# ⑤b 点号开头的目录：`slides/*/` 通配不到它，没有护栏就会被完全无视（不编译、不出卡片）却 exit 0
R3b="$TMP/repo-dotname"; fresh "$R3b"
mkdir -p "$R3b/slides/.hidden"; cp "$R3b/slides/template/main.typ" "$R3b/slides/.hidden/main.typ"
capture run_compile "$R3b" "$T"
chk "⑤b 点号开头的目录：exit" "$rc" 1
if grep -q '以点号开头' <<<"$out"; then ok "⑤b 拦住了 .hidden（否则会静默少一套）"
else bad "⑤b 没拦住点号开头的目录"; fi

# ⑤c 目录名含换行：basename 会吃掉换行，两个目录落到同一个 PDF 名上互相覆盖
R3c="$TMP/repo-nlname"; fresh "$R3c"
mkdir -p "$R3c/slides/nl"$'\n'
cp "$R3c/slides/template/main.typ" "$R3c/slides/nl"$'\n'"/main.typ"
capture run_compile "$R3c" "$T"
chk "⑤c 含换行的目录名：exit" "$rc" 1
if grep -q '含换行或回车' <<<"$out"; then ok "⑤c 拦住了含换行的目录名"
else bad "⑤c 没拦住含换行的目录名"; fi

R4="$TMP/repo-empty"; fresh "$R4"; rm -rf "$R4/slides"
capture run_compile "$R4" "$T"
chk "⑥ 一套都没有：exit" "$rc" 1

# ⑦ 生成导航页的边界 + env 护栏
#    上一轮引入过的高危 bug：清理循环按 "$BUILD_DIR"/* 遍历，BUILD_DIR 为空时通配符会展开成
#    /*（实测），于是清理会把文件系统顶层目录当「旧产物」删掉。workflow 里加了独立的
#    「校验构建环境变量」步骤 fail closed；这里既验那一步，也验导航页本身的容错。
R5="$TMP/repo-nav"; fresh "$R5"
printf 'not a real pdf, no /Count here\n' > "$R5/build/template.pdf"   # 故意让 /Count 读不到
printf 'stale\n' > "$R5/build/stale.html"                              # 上一轮残留的非 PDF 文件
printf 'stale\n' > "$R5/build/.stale-hidden"                           # 隐藏的残留文件
printf 'stale\n' > "$R5/build/avatar-old.png"                          # 根级残留图片：仍然要清掉
# 残留**子目录**：整棵都要清。目录名故意用中性的 stale-dir —— 历史上有过 `covers/` 白名单，
# 但那是已撤掉的封面功能留下的；继续用 covers 当夹具名会让人以为「covers 是个特殊目录」。
mkdir -p "$R5/build/stale-dir" && printf 'stale\n' > "$R5/build/stale-dir/old.png"
printf 'sha ver wf\n' > "$R5/build/.build-stamp"                       # 增量基准，必须留下
capture run_index "$R5" "$T"
chk "⑦ 导航页：读不到 /Count 也必须成功" "$rc" 0
chk "⑦ 残留的非 PDF 文件被清掉" "$([ -f "$R5/build/stale.html" ] && echo 还在 || echo 已删)" 已删
chk "⑦ 隐藏的残留文件也被清掉" "$([ -f "$R5/build/.stale-hidden" ] && echo 还在 || echo 已删)" 已删
chk "⑦ .build-stamp 必须保留" "$([ -f "$R5/build/.build-stamp" ] && echo 在 || echo 没了)" 在
# 残留图片照旧要清掉（白名单里**不能**出现 `*.png` 这种通配 —— 历史上封面功能一度加过
# `covers` 目录白名单，功能撤掉后白名单也一起收回，这条断言留着防止有人再用通配放开）。
chk "⑦ 根级残留图片仍然被清掉" "$([ -f "$R5/build/avatar-old.png" ] && echo 还在 || echo 已删)" 已删
# 残留的**子目录**也必须整棵清掉：白名单一旦写回任何目录名（历史上有过 `covers`），
# 该目录就会永远留在缓存里、并随 Pages 一起发布。docs/gate-design.md 曾经还在教人把
# `covers` 加回白名单去「钉断言」—— 那段文档 2026-10-17 已改（改前 verify-site.sh 里
# 那句「那条文档已改」是假的，独立复核指出过），这条断言则是真正的护栏。
chk "⑦ 残留子目录整棵被清掉（白名单里不许再加目录名）" "$([ -e "$R5/build/stale-dir" ] && echo 还在 || echo 已删)" 已删
chk "⑦ 站点资源仍然拷进 build/" "$([ -f "$R5/build/icon.png" ] && echo yes || echo no)" yes
# 读不到 /Count 时不该冒出「只有『页』字的空胶囊」——整枚 badge 都不输出
if grep -q ' 页</span>' "$R5/build/index.html"; then
  bad "⑦ 读不到 /Count 却渲染出了「N 页」胶囊（可能把别的东西当成了 /Count）"
else ok "⑦ 读不到 /Count 时不渲染页数胶囊"; fi
# 正对照：能读到页数时必须渲染（否则这条断言会掩盖「胶囊永远不出现」的回归）
if grep -qE '<span class="badge">[0-9]+ 页</span>' "$R/build/index.html"; then
  ok "⑦ 能读到 /Count 时正常渲染「N 页」胶囊"
else bad "⑦ 正常 PDF 的页数胶囊没渲染出来（/Count 解析回归？）"; fi
# ⑦b 页数必须来自**页树根**（`/Type/Pages/Count`），不能是全文 `/Count` 的最大值：大纲（书签）里
#     也有 `/Type/Outlines … /Count N`，而那个 N 是**标题数**。造一个「1 页 + 2 个 = 标题」的 deck：
#     正确实现显示「1 页」，旧写法（全文取最大）显示「2 页」。现有两套 deck 恰好都是页数 > 标题数
#     （template 20 页/3 标题、26-09-30 49 页/5 标题），所以这个错从上线起就没被任何断言发现
#     ——2026-10-17 独立复核实测：1 页写 2 个 `=` 标题，卡片真的显示「2 页」。
R7b="$TMP/repo-pages"; fresh "$R7b"; rm -rf "$R7b/slides" "$R7b/build"
mkdir -p "$R7b/slides/two-headings" "$R7b/build"
printf '#set document(title: "两标题一页")\n#set page(paper: "a4")\n= 第一节\n正文\n= 第二节\n更多\n' > "$R7b/slides/two-headings/main.typ"
capture run_compile "$R7b" "$T"
chk "⑦b 页数夹具编译：exit" "$rc" 0
run_index "$R7b" "$T" >/dev/null 2>&1
badge="$(grep -oE '<span class="badge">[0-9]+ 页</span>' "$R7b/build/index.html" | head -n 1 || true)"
chk "⑦b 1 页 2 标题 → 页数取页树根（必须显示「1 页」）" "$badge" '<span class="badge">1 页</span>'
# 第二个夹具补「多页、标题少」：上面那个只能挡住「取全文 /Count 最大值」（1 与 2 之间取最大 = 2），
# 而「取最小值」的写法在它上面恰好也得 1。4 页 2 标题反过来：真值 4、最大值 4、最小值 2
# （2026-10-17 复核指出单夹具挡不住取最小值的实现）。
rm -rf "$R7b/slides" "$R7b/build"; mkdir -p "$R7b/slides/four-pages" "$R7b/build"
printf '#set document(title: "两标题四页")\n#set page(paper: "a4")\n= 第一节\n正文\n#pagebreak()\n#pagebreak()\n#pagebreak()\n= 第二节\n' > "$R7b/slides/four-pages/main.typ"
capture run_compile "$R7b" "$T"
chk "⑦b 多页夹具编译：exit" "$rc" 0
run_index "$R7b" "$T" >/dev/null 2>&1
badge="$(grep -oE '<span class="badge">[0-9]+ 页</span>' "$R7b/build/index.html" | head -n 1 || true)"
chk "⑦b 4 页 2 标题 → 页数取页树根（必须显示「4 页」）" "$badge" '<span class="badge">4 页</span>'

# ⑩ 列表顺序（最新在前）。这条是**静默失效**区：
#    * 顺序退回 glob（= 当前 locale 的字典序）不会报错，只是没有意图，而且中文名的先后会随
#      runner 的 locale 变（实测 C.UTF-8 把中文排最后、en_US.UTF-8 排最前）；
#    * 空日期那一行有个真实解析坑：`read` 会吃掉行首的 IFS 空白，若直接把空值写进 TSV，
#      文件名会被读进日期字段（整行错位）——所以夹具里专门放一套**从未提交过**的 deck。
#    夹具构成（三套有日期 + 一套没有，故意让各种排法都给出不同顺序）：
#      mm-same  2026-01-01 ┐同一天：专门钉 `-k2,2` 这个**同日兜底键**（名字升序 → mm-same 在前）
#      zz-new   2026-01-01 ┘
#      aa-old   2020-01-01    最旧
#      mm-nodate 从未提交     空日期 → 走 0000-00-00 占位，排最后
#    期望 mm-same zz-new aa-old mm-nodate 与「纯名字升序」（aa-old mm-nodate mm-same zz-new）、
#    「同日按名字倒序」（zz-new mm-same …）都不同，所以这两种写错都会红。
#    **没覆盖的**：`LC_ALL=C` 本身 —— 要验它得用非 ASCII 名字，而中日韩名字在不同 locale 下
#    的先后本来就不同、会随 runner 的 locale 变，钉进去就是假红风险，所以只在这里说明、不钉。
#    日期只在构建时用来排序、**不渲染到页面**（用户明确不要那一列），下面另有一条正面断言查这个。
R10="$TMP/repo-order"; fresh "$R10"
rm -rf "$R10/slides" "$R10/build"; mkdir -p "$R10/slides" "$R10/build"
mkdeck() {
  mkdir -p "$R10/slides/$1"
  printf '#set document(title: "%s")\n#set page(paper: "a4")\n= 正文\n' "$2" > "$R10/slides/$1/main.typ"
  : > "$R10/build/$1.pdf"   # 空 PDF：导航页只要求文件存在（大小 0 B、读不到 /Count，正好也覆盖那条路径）
}
mkdeck mm-same "同一天 A"
mkdeck zz-new "同一天 B"
( cd "$R10" && git add -A && GIT_AUTHOR_DATE=2026-01-01T00:00:00 GIT_COMMITTER_DATE=2026-01-01T00:00:00 \
    gitc -qm same ) >/dev/null 2>&1
mkdeck aa-old "旧的"
( cd "$R10" && git add -A && GIT_AUTHOR_DATE=2020-01-01T00:00:00 GIT_COMMITTER_DATE=2020-01-01T00:00:00 \
    gitc -qm old ) >/dev/null 2>&1
mkdeck mm-nodate "没提交过的"   # 故意不提交：git log 取不到日期
capture run_index "$R10" "$T"
chk "⑩ 含无日期 deck 时导航页仍要成功" "$rc" 0
# grep 在「没有匹配」时退出 1，pipefail 会让整条管道非零 —— 那是**成功**路径，
# 不加 `|| true` 的话 `bash -e verify-site.sh` 会在这里无声中止（见顶部 capture 的注释）。
order="$(grep -o 'href="[^"]*\.pdf"' "$R10/build/index.html" | sed 's/href="//;s/"$//' | paste -sd' ' - || true)"
chk "⑩ 顺序＝最新在前（日期倒序、同日按名字升序、无日期排最后）" \
    "$order" "mm-same.pdf zz-new.pdf aa-old.pdf mm-nodate.pdf"
# 正面断言：**卡片区**里不该出现任何 YYYY-MM-DD 形态的文本（日期只用于排序）。
# 注意不能直接整页 grep —— 页脚的「更新于 2026-…」本身就是一个日期，而且它在 <main> 之外。
# 先钉区间非空：`<main>` 一旦被改名（比如换成 `<div class="content">`），sed 区间为空、下面的
# 日期 grep 永远不匹配，这条断言就会**空过并打印 ok**（2026-10-17 实测；同文件里页脚那条同型
# 断言是 fail-closed 的，两条行为不一致，容易被误以为都安全）。
region="$(sed -n '/<main/,/<\/main>/p' "$R10/build/index.html")"
if [ -z "$region" ]; then
  bad "⑩ 产物里找不到 <main> 区间（模板结构改了？这条断言会空过，等于没查）"
elif grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' <<<"$region"; then
  bad "⑩ 卡片区渲染出了日期（日期只用于排序，不该上页面）"
else ok "⑩ 卡片区没有日期（只用于排序）"; fi
# 「最近更新」小圆点的**反方向**：这个夹具里的 deck 要么是 2020/2026-01 的老提交、要么
# 从未提交（取不到日期），都不该被标成「最近更新」。
# 尤其是「取不到日期」那套：早期实现把它当成"新 deck"直接标上，于是浅克隆 / 无历史的
# 环境里**每一行都会带圆点** —— 那比没有标记更误导人。现在改成 fail safe（取不到日期就不标）。
chk "⑩ 旧 deck / 无日期时不得出现「最近更新」标记" \
    "$(grep -c 'class="dot"' "$R10/build/index.html" || true)" 0
ENVCHECK=""
for f in "$TMP"/scripts/*.sh; do grep -q 'BUILD_DIR 非法' "$f" 2>/dev/null && ENVCHECK="$f"; done
if [ -n "$ENVCHECK" ]; then ok "⑦ 找到「校验构建环境变量」步骤"
else bad "⑦ 找不到「校验构建环境变量」步骤：BUILD_DIR 为空时清理会作用于 / 顶层"; fi
if [ -n "$ENVCHECK" ]; then
  # 危险写法必须全部被拒（'./' 与 '.' 等价、'.//' 折叠后也是 '.'、'/tmp' 绝对路径、'build/../' 含 ..）
  for bad_dir in "" "/" ".." "./" ".//" "/tmp" "build/.." "a b"; do
    if ( cd "$R5" && RUNNER_TEMP="$T" BUILD_DIR="$bad_dir" TYPST_VERSION="$TYPST_VERSION" bash "$ENVCHECK" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
    chk "⑦ BUILD_DIR='${bad_dir}' 必须被拒绝" "$rc" 1
  done
  # 正对照：正常值必须放行，否则守卫本身会变成假红
  for ok_dir in "build" "slides/build"; do
    if ( cd "$R5" && RUNNER_TEMP="$T" BUILD_DIR="$ok_dir" TYPST_VERSION="$TYPST_VERSION" bash "$ENVCHECK" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
    chk "⑦ BUILD_DIR='${ok_dir}' 必须放行" "$rc" 0
  done
  # RECENT_DAYS：写错时 git **不报错**、只是让 --since 落到一个无效/过去的时间点，
  # 结果是首页一个圆点都不出现而 CI 全绿（实测 'abc' → 0 个圆点、rc=0）—— 又一个静默失效。
  # 所以它必须被「校验构建环境变量」那步显式拦下；这里钉住拒绝与放行两面。
  for bad_days in "" "abc" "0" "-3" "14 days" "99999"; do
    if ( cd "$R5" && RUNNER_TEMP="$T" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
         RELEASE_TZ="$RELEASE_TZ" RECENT_DAYS="$bad_days" bash "$ENVCHECK" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
    chk "⑦ RECENT_DAYS='${bad_days}' 必须被拒绝" "$rc" 1
  done
  for ok_days in "1" "14" "3650"; do
    if ( cd "$R5" && RUNNER_TEMP="$T" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
         RELEASE_TZ="$RELEASE_TZ" RECENT_DAYS="$ok_days" bash "$ENVCHECK" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
    chk "⑦ RECENT_DAYS='${ok_days}' 必须放行" "$rc" 0
  done
  # RELEASE_TZ：配错时 `TZ=Not/AZone date` 在 glibc/BSD 下**不报错**、静默退回 UTC，跨零点就让
  # tag 的日期差一天。校验步骤靠 zoneinfo 的存在性拦它 —— 这条断言钉住那道守卫：2026-10-17 之前
  # 门禁里**一个 RELEASE_TZ 负例都没有**，实测把整段守卫删掉仍是 98 通过 / 0 失败。
  # （注意 `RELEASE_TZ=''` 要**放行**：脚本用 `${RELEASE_TZ:-Asia/Shanghai}`，空 = 用默认值。）
  # 负例里必须包含「路径存在但不是合法时区」的四类：Asia / Etc 是**目录**，zone.tab / tzdata.zi
  # 是**普通文件** —— 旧的 `[ -e ]` 写法对这四者全部放行（2026-10-17 实测），而它们都会静默退回 UTC。
  for bad_tz in "Not/AZone" "Asia/Shangai" "UTC+8" "Asia" "Etc" "zone.tab" "tzdata.zi"; do
    if ( cd "$R5" && RUNNER_TEMP="$T" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
         RELEASE_TZ="$bad_tz" bash "$ENVCHECK" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
    chk "⑦ RELEASE_TZ='${bad_tz}' 必须被拒绝" "$rc" 1
  done
  for ok_tz in "UTC" "Asia/Shanghai" ""; do
    if ( cd "$R5" && RUNNER_TEMP="$T" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
         RELEASE_TZ="$ok_tz" bash "$ENVCHECK" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
    chk "⑦ RELEASE_TZ='${ok_tz}' 必须放行" "$rc" 0
  done
  # BUILD_DIR 指到 slides/ 里的源码目录：字符集合法、也不在 `""|/|.|..|/*|*..*` 里，所以旧守卫会
  # **放行** —— 而导航页那步的 `rm -rf "$BUILD_DIR"/*` 会把 main.typ 与 src/ 删掉（实测
  # BUILD_DIR=slides/d1 删掉 d1/main.typ 与 d1/src/、首页只是少一张卡片、exit 0，一句报错都没有）。
  # 「必须叫 build」这条规则把整类误删一起堵死：2026-10-17 复核实测 BUILD_DIR=docs 会删掉
  # docs/*.md、=.github 会删掉 workflow 与复合 action、=slides/<deck>/src 会删掉未跟踪的真实图片。
  for bad_src in "slides" "slides/template" "docs" ".github" "assets" "slides/26-09-30/src"; do
    if ( cd "$R5" && RUNNER_TEMP="$T" BUILD_DIR="$bad_src" TYPST_VERSION="$TYPST_VERSION" \
         RELEASE_TZ="$RELEASE_TZ" bash "$ENVCHECK" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
    chk "⑦ BUILD_DIR='${bad_src}'（不是产物目录）必须被拒绝" "$rc" 1
  done
  # 第二道防线（结构性）：就算 BUILD_DIR 绕过校验直接进了导航页步骤，也不许删源码 ——
  # 探测到 main.typ 就 fail closed，一个字节都不删。
  if ( cd "$R5" && RUNNER_TEMP="$T" BUILD_DIR="slides/template" TYPST_VERSION="$TYPST_VERSION" \
       RELEASE_TZ="$RELEASE_TZ" RECENT_DAYS="$RECENT_DAYS" bash "$INDEX" ) >/dev/null 2>&1; then rc=0; else rc=$?; fi
  chk "⑦ 导航页：BUILD_DIR 指向 deck 目录时必须 exit 1（不许静默删源码）" "$rc" 1
  chk "⑦ 导航页没删掉 deck 的 main.typ" "$([ -f "$R5/slides/template/main.typ" ] && echo 在 || echo 没了)" 在
fi

# ⑨ 事件/环境维度：stamp 失配、非 main push、workflow_dispatch 都必须退化成**全量编译**
#    （增量只在「main push + stamp 匹配」这一种情况下成立）。用两套 1 页 A4 的极小夹具，
#    每次编译只要几百毫秒，不会拖慢门禁。
tiny_slides() {
  rm -rf "$1/slides"; mkdir -p "$1/slides/tiny-a" "$1/slides/tiny-b"
  for d in tiny-a tiny-b; do
    printf '#set document(title: "%s")\n#set page(paper: "a4")\n= %s\n\n正文\n' "$d" "$d" > "$1/slides/$d/main.typ"
  done
}
write_stamp() { printf '%s %s %s\n' "$1" "$2" "${3:-$(wf_rev_of "$R6")}" > "$R6/build/.build-stamp"; }

R6="$TMP/repo-events"; fresh "$R6"; tiny_slides "$R6"
(cd "$R6" && git add -A && gitc -qm tiny) >/dev/null 2>&1
sha6="$(cd "$R6" && git rev-parse HEAD)"

capture run_compile "$R6" "$T" "$sha6"
chk "⑨ 极小夹具冷启动：exit" "$rc" 0
chk "⑨ 极小夹具产出 PDF 数" "$(ls "$R6"/build/*.pdf 2>/dev/null | wc -l | tr -d ' ')" 2

# 正对照：同样的 stamp + main push → 必须走增量（证明下面三条的「全量」不是因为别的）
out="$(run_compile "$R6" "$T" "$sha6" 2>&1)"
chk "⑨ 正对照：main push + stamp 匹配 → 复用" "$(grep -c '没有改动，复用' <<<"$out")" 2

write_stamp "$sha6" "9.9.9"
out="$(run_compile "$R6" "$T" "$sha6" 2>&1)"
if grep -q '编译环境变了' <<<"$out" && [ "$(grep -c '✅' <<<"$out")" = "2" ]; then
  ok "⑨ TYPST_VERSION 失配 → 全量重编"
else bad "⑨ TYPST_VERSION 失配没有触发全量重编"; fi

write_stamp "$sha6" "$TYPST_VERSION"
# ⑨c 编译环境指纹（wf_rev）被**整项从比较里删掉**时也必须退化成全量：只比 Typst 版本的话，
#     改了 workflow / 装了新字体之后，未改动的 deck 会静默复用「旧环境编出来的 PDF」—— 正是
#     stamp 要防的那种失效。2026-10-17 独立复核实测：把 stamp 比较里 `[ "$stamp_wf" = "$wf_rev" ]`
#     那半句删掉，门禁依然 98 通过 / 0 失败（另外几种改坏法会被 ② 或 ⑨b 抓到，只有这一种是静默绿）。
write_stamp "$sha6" "$TYPST_VERSION" "deadbeefcafe"
out="$(run_compile "$R6" "$T" "$sha6" 2>&1)"
if grep -q '编译环境变了' <<<"$out" && [ "$(grep -c '✅' <<<"$out")" = "2" ]; then
  ok "⑨c 编译环境指纹失配 → 全量重编"
else bad "⑨c 指纹失配没有触发全量重编（stamp 比较里 wf_rev 那一项是不是被删了？）"; fi

write_stamp "$sha6" "$TYPST_VERSION"
out="$(run_compile "$R6" "$T" "$sha6" workflow_dispatch refs/heads/main 2>&1)"
if grep -q '全量编译' <<<"$out" && [ "$(grep -c '✅' <<<"$out")" = "2" ]; then
  ok "⑨ workflow_dispatch → 全量重编"
else bad "⑨ workflow_dispatch 没走全量"; fi

write_stamp "$sha6" "$TYPST_VERSION"
out="$(run_compile "$R6" "$T" "$sha6" push refs/heads/feature 2>&1)"
if grep -q '全量编译' <<<"$out" && [ "$(grep -c '✅' <<<"$out")" = "2" ]; then
  ok "⑨ 非 main 分支 push → 全量重编"
else bad "⑨ 非 main 分支 push 没走全量"; fi

echo
printf '结果：%d 通过 / %d 失败\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

# tortrixx/slides · 仓库约定见 AGENTS.md

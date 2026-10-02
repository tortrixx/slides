#!/usr/bin/env bash
# =============================================================================
# 本地验证 workflow 里那段 CI 逻辑（不用推送到 GitHub 就能跑）。
#
# 对应 AGENTS.md §6「改 workflow 后的验证清单」，把第 1–4 步做成可执行的：
#   1) 从 YAML 里抽出所有 run: 脚本
#   2) bash -n 语法检查 + 多字节陷阱 lint
#   3) 在 /tmp 的临时副本里真跑「编译」与「生成导航页」等步骤，覆盖 ①~⑩：
#        冷启动全量 / 只改一个 deck 的增量（含非 ASCII 目录名）/ 删除某套后的残留清理 /
#        某套编译失败必须 exit 1 / 文件夹名非法必须 exit 1 / 一套都没有必须 exit 1 /
#        导航页边界（读不到 /Count、残留文件清理、BUILD_DIR 为空必须被拒）
#
# 用法：
#   bash verify-site.sh            # 只做静态检查（不编译，几秒）
#   bash verify-site.sh --build    # 连编译一起跑（需要本地 typst，约十几秒）
#
# 退出码 0 表示全部通过。
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")"

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
if [ -n "$TYPST_VERSION" ] && [ -n "$BUILD_DIR" ]; then
  ok "从 workflow 读到 env：TYPST_VERSION=$TYPST_VERSION BUILD_DIR=$BUILD_DIR"
else
  bad "没读到 workflow 的 env（TYPST_VERSION/BUILD_DIR），脚本和工作流可能已脱节"
  TYPST_VERSION="${TYPST_VERSION:-0.15.1}"; BUILD_DIR="${BUILD_DIR:-build}"
fi
RELEASE_TZ="${RELEASE_TZ:-Asia/Shanghai}"

echo "── 1) 从 YAML 抽出 run: 脚本 ──"
ruby -ryaml -e '
  wf = YAML.load_file(ARGV[0]); out = ARGV[1]; require "fileutils"; FileUtils.mkdir_p(out)
  wf["jobs"].each { |jn, job| job["steps"].each_with_index { |s, i|
    next unless s["run"]; File.write("#{out}/#{jn}-#{i}.sh", s["run"]) } }' \
  "$WF" "$TMP/scripts"
n=$(ls "$TMP/scripts"/*.sh 2>/dev/null | wc -l | tr -d ' ')
if [ "$n" -ge 4 ]; then ok "抽出 $n 段脚本"; else bad "只抽出 $n 段脚本（应 ≥4）"; fi

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

mb=$(python3 - "$TMP/scripts" <<'PY'
import glob, re, sys
p = re.compile(rb'\$[A-Za-z_][A-Za-z0-9_]*(\[[^\]]*\])?(?=[\x80-\xff])')
print(sum(len(p.findall(open(f, 'rb').read())) for f in glob.glob(sys.argv[1] + '/*.sh')))
PY
)
chk "多字节陷阱（\$var 紧跟中文）数量" "$mb" 0

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

# ⑧c 「只更新附件」这步（Release 已存在但说明不是我们写的）：本仓库实测 softprops 的更新路径
#     会 PATCH 整个 release 并返回 403，所以改成了 gh release upload --clobber。
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
#    统计前先去掉 `/* … */`（注释里的括号不该参与计数）；python3 是本脚本已有的依赖。
BAL="$(python3 - index.template.html <<'PY'
import re, sys
s = re.sub(r"/\*[\s\S]*?\*/", "", open(sys.argv[1], encoding="utf-8").read())
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

echo "── 3) 真跑 ①~⑩（需要 typst）──"
command -v typst >/dev/null || { bad "没找到 typst，跳过"; printf '%d 通过 / %d 失败\n' "$PASS" "$FAIL"; exit 1; }

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
# workflow 里 env: 级别的变量（上面已从 YAML 读出，不再写死）
run_compile() { ( cd "$1" && RUNNER_TEMP="$2" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
    RELEASE_TZ="$RELEASE_TZ" GITHUB_EVENT_NAME="${4:-push}" GITHUB_REF="${5:-refs/heads/main}" \
    GITHUB_SHA="${3:-$(git rev-parse HEAD 2>/dev/null || echo nosha)}" bash "$COMPILE" ); }
run_index() { ( cd "$1" && RUNNER_TEMP="$2" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
    RELEASE_TZ="$RELEASE_TZ" bash "$INDEX" ); }
fresh() {
  rm -rf "$1"; mkdir -p "$1" "$1/build"; cp -R ./. "$1"/; rm -rf "$1/build"; mkdir -p "$1/build"
  # 快照一次：工作树里未提交的改动（新增了 deck 目录等）不会出现在 `git diff <基准> HEAD` 里，
  # 会让 ② 的「改了一套 → 复用 N-1」断言假红。先提交副本里的现状，基准才与内容一致。
  ( cd "$1" && git add -A && git -c user.email=v@x -c user.name=v commit -qm "fixture snapshot" ) >/dev/null 2>&1 || true
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
# 头像等站点资源是「生成导航页」那步从 assets/ 拷进 build/ 的：漏拷不会报错，
# 只是 img 被 onerror 静默删掉，所以这里钉一下产物里确实有它
chk "① 站点资源 icon.png 已进 build/" "$([ -f "$R/build/icon.png" ] && echo yes || echo no)" yes
# 占位注释必须被**全部消费掉**：改名/拼错一个 token 不会报错，只会让那段内容静默消失
# （而且它本来是 HTML 注释，页面上根本看不见，连症状都没有）—— 属于典型「门禁假绿」区。
# 以前这里钉的是「页面 h1 里的 count 胶囊是个数字」，那条断言跟着标题从 h2 搬到 h1 改过一次；
# 2026-10 标题旁的套数去掉之后（见 AGENTS「首页视觉」），改成钉三个 token 的残留 ——
# 覆盖面反而更宽（SLIDES / COUNT / META 一起），也不再依赖标题那一行的写法。
left="$(grep -oE '<!--(SLIDES|COUNT|META)-->' "$R/build/index.html" | paste -sd' ' -)"
chk "① 占位注释已全部替换（产物里没有残留）" "$left" ""
if grep -q '最后更新 ' "$R/build/index.html"; then ok "① 页脚时间戳已注入（META 占位符生效）"
else bad "① 页脚没有时间戳：META 占位符可能被改名/拼错"; fi

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

# 增量：先把基准写成当前提交，再只改一个 deck
# （版本与 workflow 哈希都必须和脚本真正会写的那份一致，否则会走进「环境变了→全量」分支，
#   ② 就测不到增量路径了 —— 所以这里用上面从 YAML 读到的 TYPST_VERSION）
sha0="$(cd "$R" && git rev-parse HEAD)"
printf '%s %s %s\n' "$sha0" "$TYPST_VERSION" "$(cd "$R" && git hash-object "$WF" | cut -c1-12)" > "$R/build/.build-stamp"
printf '\n// 故意改动\n' >> "$R/slides/template/main.typ"
(cd "$R" && git add -A && git -c user.email=v@x -c user.name=v commit -qm tmp) >/dev/null 2>&1
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
(cd "$R" && git add -A && git -c user.email=v@x -c user.name=v commit -qm tmp-cjk) >/dev/null 2>&1
run_compile "$R" "$T" "$(cd "$R" && git rev-parse HEAD)" >/dev/null 2>&1   # 先编出来，并作为新基准
printf '\n// 故意改动\n' >> "$R/slides/中文甲/main.typ"
(cd "$R" && git add -A && git -c user.email=v@x -c user.name=v commit -qm tmp-cjk2) >/dev/null 2>&1
capture run_compile "$R" "$T" "$(cd "$R" && git rev-parse HEAD)"
chk "②b 中文目录名：exit" "$rc" 0
if grep -q '✅ 中文甲' <<<"$out"; then ok "②b 中文目录名的改动被重编（core.quotePath 已关）"
else bad "②b 中文目录名的改动被当成「没改动」而复用了旧 PDF（core.quotePath 没关？）"; fi

rm -rf "$R/slides/template"
capture run_compile "$R" "$T"
chk "③ 删除后清理：exit" "$rc" 0
chk "③ 残留 template.pdf" "$([ -f "$R/build/template.pdf" ] && echo 还在 || echo 已删)" 已删
chk "③ 其余 PDF 保留" "$([ -f "$R/build/26-09-30.pdf" ] && echo 在 || echo 没了)" 在

R2="$TMP/repo-fail"; fresh "$R2"
printf '#set page(paper: "a4")\n= 坏的\n#undefined-fn-xyz()\n' > "$R2/slides/26-09-30/main.typ"
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
printf 'sha ver wf\n' > "$R5/build/.build-stamp"                       # 增量基准，必须留下
capture run_index "$R5" "$T"
chk "⑦ 导航页：读不到 /Count 也必须成功" "$rc" 0
chk "⑦ 残留的非 PDF 文件被清掉" "$([ -f "$R5/build/stale.html" ] && echo 还在 || echo 已删)" 已删
chk "⑦ 隐藏的残留文件也被清掉" "$([ -f "$R5/build/.stale-hidden" ] && echo 还在 || echo 已删)" 已删
chk "⑦ .build-stamp 必须保留" "$([ -f "$R5/build/.build-stamp" ] && echo 在 || echo 没了)" 在
chk "⑦ 站点资源仍然拷进 build/" "$([ -f "$R5/build/icon.png" ] && echo yes || echo no)" yes
# 读不到 /Count 时不该冒出「只有『页』字的空胶囊」——整枚 badge 都不输出
if grep -q ' 页</span>' "$R5/build/index.html"; then
  bad "⑦ 读不到 /Count 却渲染出了「N 页」胶囊（可能把别的东西当成了 /Count）"
else ok "⑦ 读不到 /Count 时不渲染页数胶囊"; fi
# 正对照：能读到页数时必须渲染（否则这条断言会掩盖「胶囊永远不出现」的回归）
if grep -qE '<span class="badge">[0-9]+ 页</span>' "$R/build/index.html"; then
  ok "⑦ 能读到 /Count 时正常渲染「N 页」胶囊"
else bad "⑦ 正常 PDF 的页数胶囊没渲染出来（/Count 解析回归？）"; fi

# ⑩ 列表顺序（最新在前）。这条是**静默失效**区：
#    * 顺序退回 glob（= 当前 locale 的字典序）不会报错，只是没有意图，而且中文名的先后会随
#      runner 的 locale 变（实测 C.UTF-8 把中文排最后、en_US.UTF-8 排最前）；
#    * 空日期那一行有个真实解析坑：`read` 会吃掉行首的 IFS 空白，若直接把空值写进 TSV，
#      文件名会被读进日期字段（整行错位）——所以夹具里专门放一套**从未提交过**的 deck。
#    夹具刻意让「日期序」与「名字序」相反（zz-old 名字靠后但日期最新），这样只按名字排也会挂。
#    日期只在构建时用来排序、**不渲染到页面**（用户明确不要那一列日期），所以这里只钉 href 顺序。
R10="$TMP/repo-order"; fresh "$R10"
rm -rf "$R10/slides" "$R10/build"; mkdir -p "$R10/slides" "$R10/build"
mkdeck() {
  mkdir -p "$R10/slides/$1"
  printf '#set document(title: "%s")\n#set page(paper: "a4")\n= 正文\n' "$2" > "$R10/slides/$1/main.typ"
  : > "$R10/build/$1.pdf"   # 空 PDF：导航页只要求文件存在（大小 0 B、读不到 /Count，正好也覆盖那条路径）
}
mkdeck zz-old "旧的"
( cd "$R10" && git add -A && GIT_AUTHOR_DATE=2020-01-01T00:00:00 GIT_COMMITTER_DATE=2020-01-01T00:00:00 \
    git -c user.email=v@x -c user.name=v commit -qm old ) >/dev/null 2>&1
mkdeck aa-new "新的"
( cd "$R10" && git add -A && GIT_AUTHOR_DATE=2026-01-01T00:00:00 GIT_COMMITTER_DATE=2026-01-01T00:00:00 \
    git -c user.email=v@x -c user.name=v commit -qm new ) >/dev/null 2>&1
mkdeck mm-nodate "没提交过的"   # 故意不提交：git log 取不到日期
capture run_index "$R10" "$T"
chk "⑩ 含无日期 deck 时导航页仍要成功" "$rc" 0
order="$(grep -o 'href="[^"]*\.pdf"' "$R10/build/index.html" | sed 's/href="//;s/"$//' | paste -sd' ' -)"
chk "⑩ 顺序＝最新在前（日期倒序，无日期排最后）" "$order" "aa-new.pdf zz-old.pdf mm-nodate.pdf"
# 反面对照：日期只用于排序，不该被渲染出来（那一列已经去掉了；顺手钉住，免得又悄悄回来）
if grep -q 'class="lede"' "$R10/build/index.html"; then
  bad "⑩ 页面上不应该再出现日期列（class=\"lede\"）"
else ok "⑩ 日期不渲染到页面（只用于排序）"; fi

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
write_stamp() { printf '%s %s %s\n' "$1" "$2" "$(cd "$R6" && git hash-object "$WF" | cut -c1-12)" > "$R6/build/.build-stamp"; }

R6="$TMP/repo-events"; fresh "$R6"; tiny_slides "$R6"
(cd "$R6" && git add -A && git -c user.email=v@x -c user.name=v commit -qm tiny) >/dev/null 2>&1
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

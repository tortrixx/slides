#!/usr/bin/env bash
# =============================================================================
# 本地验证 workflow 里那段 CI 逻辑（不用推送到 GitHub 就能跑）。
#
# 对应 AGENTS.md §6「改 workflow 后的验证清单」，把第 1–4 步做成可执行的：
#   1) 从 YAML 里抽出所有 run: 脚本
#   2) bash -n 语法检查 + 多字节陷阱 lint
#   3) 在 /tmp 的临时副本里真跑「编译」与「生成导航页」两步，覆盖六条路径：
#        冷启动全量 / 只改一个 deck 的增量 / 删除某套后的残留清理 /
#        某套编译失败必须 exit 1 / 文件夹名非法必须 exit 1 / 一套都没有必须 exit 1
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
TMP="${TMPDIR:-/tmp}/slides-verify"
PASS=0; FAIL=0
ok()  { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
chk() { if [ "$2" = "$3" ]; then ok "$1（$3）"; else bad "$1：期望 [$3]，实际 [$2]"; fi; }

# 无论从哪条路径退出都清掉临时目录 —— 校验脚本自己不该留垃圾（失败时最容易留）
trap 'rm -rf "$TMP"' EXIT INT TERM
rm -rf "$TMP"; mkdir -p "$TMP/scripts"

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
if bash -n "$TMP"/scripts/*.sh 2>"$TMP/syntax.err"; then ok "bash -n 全部通过"
else bad "bash -n 报错：$(head -2 "$TMP/syntax.err" | tr '\n' ' ')"; fi

mb=$(python3 - "$TMP/scripts" <<'PY'
import glob, re, sys
p = re.compile(rb'\$[A-Za-z_][A-Za-z0-9_]*(\[[^\]]*\])?(?=[\x80-\xff])')
print(sum(len(p.findall(open(f, 'rb').read())) for f in glob.glob(sys.argv[1] + '/*.sh')))
PY
)
chk "多字节陷阱（\$var 紧跟中文）数量" "$mb" 0

if [ "${1:-}" != "--build" ]; then
  echo
  printf '静态检查：%d 通过 / %d 失败（加 --build 可连编译路径一起验）\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]; exit
fi

echo "── 3) 真跑六条路径（需要 typst）──"
command -v typst >/dev/null || { bad "没找到 typst，跳过"; printf '%d 通过 / %d 失败\n' "$PASS" "$FAIL"; exit 1; }

COMPILE="$TMP/scripts/build-4.sh"   # 「编译 slides/*/main.typ」这步
INDEX="$TMP/scripts/build-5.sh"     # 「生成导航页」这步
# 这两个编号是按 steps 下标抽出来的，workflow 里插入/删除任何一步都会错位。
# 错位最坏的后果不是报错，而是**静默测错步骤**（比如拿生成导航页的脚本去验护栏，永远通过），
# 所以先按内容签名确认它们确实是那两步，不对就立刻停。
if ! grep -q 'typst compile' "$COMPILE" 2>/dev/null; then
  bad "抽取到的 build-4.sh 不是「编译」步骤（workflow 步骤顺序变了），请按内容重新定位"
  printf '%d 通过 / %d 失败\n' "$PASS" "$FAIL"; exit 1
fi
if ! grep -q '<!--SLIDES-->' "$INDEX" 2>/dev/null; then
  bad "抽取到的 build-5.sh 不是「生成导航页」步骤（workflow 步骤顺序变了），请按内容重新定位"
  printf '%d 通过 / %d 失败\n' "$PASS" "$FAIL"; exit 1
fi
# workflow 里 env: 级别的变量（上面已从 YAML 读出，不再写死）
run_compile() { ( cd "$1" && RUNNER_TEMP="$2" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
    RELEASE_TZ="$RELEASE_TZ" GITHUB_EVENT_NAME=push GITHUB_REF=refs/heads/main \
    GITHUB_SHA="${3:-$(git rev-parse HEAD 2>/dev/null || echo nosha)}" bash "$COMPILE" ); }
run_index() { ( cd "$1" && RUNNER_TEMP="$2" BUILD_DIR="$BUILD_DIR" TYPST_VERSION="$TYPST_VERSION" \
    RELEASE_TZ="$RELEASE_TZ" bash "$INDEX" ); }
fresh() { rm -rf "$1"; mkdir -p "$1" "$1/build"; cp -R ./. "$1"/; rm -rf "$1/build"; mkdir -p "$1/build"; }

R="$TMP/repo"; T="$TMP/runner"; mkdir -p "$T"
fresh "$R"
# 期望套数**从夹具推导**，不写死：仓库加一套幻灯片（§1 承诺的「cp -R slides/template … 后
# push 即可」）不该让门禁假红 —— 假红比漏报更糟，它会诱使人把断言改松（§6 已警告过）。
n_decks=0
for d in "$R"/slides/*/; do [ -f "${d}main.typ" ] && n_decks=$((n_decks + 1)); done
out="$(run_compile "$R" "$T" 2>&1)"; rc=$?
chk "① 冷启动全量：exit" "$rc" 0
chk "① 产出 PDF 数" "$(ls "$R"/build/*.pdf 2>/dev/null | wc -l | tr -d ' ')" "$n_decks"
chk "① 写了 .build-stamp" "$([ -f "$R/build/.build-stamp" ] && echo yes || echo no)" yes
run_index "$R" "$T" >/dev/null 2>&1
chk "① 首页卡片数" "$(grep -c 'class="deck fade"' "$R/build/index.html")" "$n_decks"
# 头像等站点资源是「生成导航页」那步从 assets/ 拷进 build/ 的：漏拷不会报错，
# 只是 img 被 onerror 静默删掉，所以这里钉一下产物里确实有它
chk "① 站点资源 icon.png 已进 build/" "$([ -f "$R/build/icon.png" ] && echo yes || echo no)" yes

# 增量：先把基准写成当前提交，再只改一个 deck
# （版本与 workflow 哈希都必须和脚本真正会写的那份一致，否则会走进「环境变了→全量」分支，
#   ② 就测不到增量路径了 —— 所以这里用上面从 YAML 读到的 TYPST_VERSION）
sha0="$(cd "$R" && git rev-parse HEAD)"
printf '%s %s %s\n' "$sha0" "$TYPST_VERSION" "$(cd "$R" && git hash-object "$WF" | cut -c1-12)" > "$R/build/.build-stamp"
printf '\n// 故意改动\n' >> "$R/slides/template/main.typ"
(cd "$R" && git add -A && git -c user.email=v@x -c user.name=v commit -qm tmp) >/dev/null 2>&1
out="$(run_compile "$R" "$T" "$(cd "$R" && git rev-parse HEAD)" 2>&1)"; rc=$?
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
out="$(run_compile "$R" "$T" "$(cd "$R" && git rev-parse HEAD)" 2>&1)"; rc=$?
chk "②b 中文目录名：exit" "$rc" 0
if grep -q '✅ 中文甲' <<<"$out"; then ok "②b 中文目录名的改动被重编（core.quotePath 已关）"
else bad "②b 中文目录名的改动被当成「没改动」而复用了旧 PDF（core.quotePath 没关？）"; fi

rm -rf "$R/slides/template"
out="$(run_compile "$R" "$T" 2>&1)"; rc=$?
chk "③ 删除后清理：exit" "$rc" 0
chk "③ 残留 template.pdf" "$([ -f "$R/build/template.pdf" ] && echo 还在 || echo 已删)" 已删
chk "③ 其余 PDF 保留" "$([ -f "$R/build/26-09-30.pdf" ] && echo 在 || echo 没了)" 在

R2="$TMP/repo-fail"; fresh "$R2"
printf '#set page(paper: "a4")\n= 坏的\n#undefined-fn-xyz()\n' > "$R2/slides/26-09-30/main.typ"
out="$(run_compile "$R2" "$T" 2>&1)"; rc=$?
chk "④ 编译失败：exit" "$rc" 1
if grep -q '::error::' <<<"$out"; then ok "④ 有 ::error:: 标注"; else bad "④ 没有 ::error::"; fi

R3="$TMP/repo-badname"; fresh "$R3"
mkdir -p "$R3/slides/a b"; cp "$R3/slides/template/main.typ" "$R3/slides/a b/main.typ"
out="$(run_compile "$R3" "$T" 2>&1)"; rc=$?
chk "⑤ 非法文件夹名：exit" "$rc" 1
if grep -q '不安全的字符' <<<"$out"; then ok "⑤ 拦住了空格"; else bad "⑤ 没拦住空格"; fi

R4="$TMP/repo-empty"; fresh "$R4"; rm -rf "$R4/slides"
out="$(run_compile "$R4" "$T" 2>&1)"; rc=$?
chk "⑥ 一套都没有：exit" "$rc" 1

echo
printf '结果：%d 通过 / %d 失败\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

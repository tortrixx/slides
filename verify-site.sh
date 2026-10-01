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

rm -rf "$TMP"; mkdir -p "$TMP/scripts"

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
# workflow 里 env: 级别的变量，手工补上
run_compile() { ( cd "$1" && RUNNER_TEMP="$2" BUILD_DIR=build TYPST_VERSION=0.15.1 \
    RELEASE_TZ=Asia/Shanghai GITHUB_EVENT_NAME=push GITHUB_REF=refs/heads/main \
    GITHUB_SHA="${3:-$(git rev-parse HEAD 2>/dev/null || echo nosha)}" bash "$COMPILE" ); }
run_index() { ( cd "$1" && RUNNER_TEMP="$2" BUILD_DIR=build TYPST_VERSION=0.15.1 \
    RELEASE_TZ=Asia/Shanghai bash "$INDEX" ); }
fresh() { rm -rf "$1"; mkdir -p "$1" "$1/build"; cp -R ./. "$1"/; rm -rf "$1/build"; mkdir -p "$1/build"; }

R="$TMP/repo"; T="$TMP/runner"; mkdir -p "$T"
fresh "$R"
out="$(run_compile "$R" "$T" 2>&1)"; rc=$?
chk "① 冷启动全量：exit" "$rc" 0
chk "① 产出 PDF 数" "$(ls "$R"/build/*.pdf 2>/dev/null | wc -l | tr -d ' ')" 2
chk "① 写了 .build-stamp" "$([ -f "$R/build/.build-stamp" ] && echo yes || echo no)" yes
run_index "$R" "$T" >/dev/null 2>&1
chk "① 首页卡片数" "$(grep -c 'class="deck fade"' "$R/build/index.html")" 2

# 增量：先把基准写成当前提交，再只改一个 deck
sha0="$(cd "$R" && git rev-parse HEAD)"
printf '%s %s %s\n' "$sha0" 0.15.1 "$(cd "$R" && git hash-object "$WF" | cut -c1-12)" > "$R/build/.build-stamp"
printf '\n// 故意改动\n' >> "$R/slides/template/main.typ"
(cd "$R" && git add -A && git -c user.email=v@x -c user.name=v commit -qm tmp) >/dev/null 2>&1
out="$(run_compile "$R" "$T" "$(cd "$R" && git rev-parse HEAD)" 2>&1)"; rc=$?
chk "② 增量：exit" "$rc" 0
if grep -q '增量编译' <<<"$out"; then ok "② 走了增量"; else bad "② 没走增量"; fi
chk "② 复用的套数" "$(grep -c '没有改动，复用' <<<"$out")" 1
chk "② 重编的套数" "$(grep -c '✅' <<<"$out")" 1

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

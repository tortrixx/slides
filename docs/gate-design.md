# 门禁设计（docs/gate-design.md）

`verify-site.sh` 每个检查项在守什么、对抗验证记录，以及不依赖脚本时的手工核对流程。
AGENTS.md §6 是操作摘要（基线数字以那里为准）；这份是完整参考。
2026-10-11 从 AGENTS.md §6 拆出。

## 检查项明细

当前基线：`--build` 全绿 = **86 项通过**（静态 30 + 编译路径 56），覆盖这些路径：
① 冷启动全量（含 `assets/icon.png` 确实进了 `build/`，以及 SLIDES / META 两处**真的注入了**：
卡片数、页脚时间戳；**三个占位注释在产物里一个都不许残留**（SLIDES / COUNT / META 一起 grep ——
COUNT 现在模板里没用，所以只查残留）。两条断言分工要清楚：**awk 规则被删/改名**（token 本身
拼对）由残留 grep 抓；**token 自己拼错**（如 `<!--SLIDE-->`）残留 grep 是空的，由「首页卡片数」
变成 0 来抓 —— 都是静默失效，别指望一条全包。
这条以前是「页面 `h1` 里的 count 胶囊是个数字」，随标题从 h2 搬到 h1、又在 2026-10 跟着套数
一起被删掉，改了两次 —— 现在的写法不依赖任何标题写法。
**页脚时间戳那条断言不绑文案**：只要求 `<footer>` 区里出现 `YYYY-MM-DD HH:MM`，不 grep
「最后更新」这类展示措辞。2026-10 把文案改成「更新于」时实测：绑文案的写法让门禁
85 通过 / 1 失败，报的还是「META 可能被改名/拼错」—— 把排查方向引到占位符上，而真正的原因
只是有人改了句措辞。占位符真被改名时页脚里会剩下 `<!--META-->`（残留 grep 也钉着），这条照样红。
①b **HTML 转义**：造一个标题含 `& < >` 的 deck，断言产物里是实体且没有原始标签（转义回归是注入风险）
② 只改一个 deck 的增量
②b **非 ASCII 文件夹名**的增量必须重编那一套（钉住 `core.quotePath=false`，见 docs/pitfalls.md）
③ 删除某套后清理残留 PDF ④ 某套编译失败必须 `exit 1`
⑤ 文件夹名非法必须 `exit 1`（空格）；⑤b **点号开头**的目录必须被拒；⑤c **含换行**的目录名必须被拒
⑥ 一套都没有必须 `exit 1`
⑦ 导航页边界：读不到 `/Count` 时**不渲染页数那一项**（能读到时要出现「N 页」）、残留（含隐藏）
文件被清掉而 `.build-stamp` 保留、`BUILD_DIR` 的危险取值（空/`/`/`..`/`./`/`.//`/绝对路径/含 `..`/
含空格）必须被拒而 `build`、`slides/build` 必须放行
⑧ Release/tag 逻辑（stub 掉 `gh`）：三种入口算出的 tag/managed、not found→`exists=false`、
403→重试后 fail closed、`RELEASE_VIEW_RETRIES=abc` 不许静默降级、机器标记决定 `ours`、
说明里的 tag 被整体百分号编码、说明末尾带标记
⑧b **生成 Release 说明**那步也真跑一遍：tag 里的空格/括号/`#` 必须整体百分号编码、说明里列出 PDF、
末尾带机器标记
⑧c 「只更新附件」那步走 `gh release upload --clobber`（不用 action：它 PATCH release 会 403）、
没有 PDF 时必须 `exit 1`
⑨ 事件维度（用两套 1 页 A4 的极小夹具）：main push + stamp 匹配 → 增量；TYPST_VERSION 失配 /
workflow_dispatch / 非 main push → 全量重编。
⑩ 列表顺序（最新在前）：夹具造四套 deck —— `mm-same` 与 `zz-new`（**同一天** 2026-01-01，
所以钉住了 `-k2,2` 这个同日兜底键）、`aa-old`（2020，最旧）、`mm-nodate`（**故意不提交**，
走空日期占位）。断言产物的 href 顺序正好是 `mm-same zz-new aa-old mm-nodate` —— 它与
「纯名字升序」（`aa-old mm-nodate mm-same zz-new`）、「同日按名字倒序」（`zz-new mm-same …`）
都不同，所以这两种写错都会红；再加一条**正面**断言：卡片区里不出现 `YYYY-MM-DD` 形态的文本
（日期只用于排序、不上页面；不能整页 grep —— 页脚的「更新于」本身就是日期）。
对抗验证：`-k1,1r -k2,2` → `-k2,2`（纯名字）与 → `-k2,2r`（同日倒序）都能让 ⑩ 变红。
**这条没覆盖的**：`LC_ALL=C` 本身（要验它得用非 ASCII 名字，而中日韩名字在不同 locale 下的
先后本来就不同、会随 runner 的 locale 变，钉进去就是假红风险），所以只在注释里说明。
⑪ 样式表花括号平衡（静态）：`<style>` 里 `{` 与 `}` 必须一样多。**多一个（或少一个）`}` 不报错、
不白屏，只会把它后面的规则静默吞掉** —— 2026-10 真踩过：一段重复的注释末尾多带了一个 `}`，
把紧跟其后的 `@media (min-width: 640px) { .page-title { margin-left: 1.5rem } }` 整块吃掉，
桌面端 h1 与头像**贴在一起**（无头 Chrome 实测 gap 0.0px，修好是 24px）；页面照样渲染、
CSSOM 也不抛错（只是 cssRules 从 51 悄悄变成 50），截图极易看漏。CI 里没有浏览器、这类没有
运行时替代品，所以用静态计数钉住（统计前先去掉 `/* … */` 注释）。

## 手工核对流程

手工做的话，对应下面几步（脚本就是照这个写的）：

1. **解析 YAML 并抽出脚本**（用 Ruby 自带的 psych，避免手抄）：

   ```bash
   ruby -ryaml -e '
     wf = YAML.load_file(ARGV[0]); out = ARGV[1]; require "fileutils"; FileUtils.mkdir_p(out)
     wf["jobs"].each { |jn, job| job["steps"].each_with_index { |s, i|
       next unless s["run"]; File.write("#{out}/#{jn}-#{i}.sh", s["run"]) } }
     Dir.glob(".github/actions/*/action.yml").each { |af|
       a = YAML.load_file(af); steps = a.dig("runs", "steps"); next unless steps
       name = File.basename(File.dirname(af))
       steps.each_with_index { |s, i|
         next unless s["run"]; File.write("#{out}/action-#{name}-#{i}.sh", s["run"]) } }' \
     .github/workflows/build-and-deploy.yml /tmp/wf-scripts
   ```

2. **语法与引号检查**：逐个文件 `for f in /tmp/wf-scripts/*.sh; do bash -n "$f" || echo "坏: $f"; done`。
   **别写 `bash -n /tmp/wf-scripts/*.sh`** —— 它只把第一个当脚本、其余当位置参数，第二个文件语法
   坏了也照样「通过」（本轮实测）。本机是 bash 3.2（比 runner 的 bash 5 严格），能提前暴露问题。
3. **多字节陷阱 lint**：`$var` 紧跟中文字符时 bash 3.2 会把首个字节吞进变量名，
   必须写成 `${var}`：

   ```bash
   python3 -c "
   import glob,re
   p=re.compile(rb'\\\$[A-Za-z_][A-Za-z0-9_]*(\[[^\]]*\])?(?=[\x80-\xff])')
   print(sum(len(p.findall(open(f,'rb').read())) for f in glob.glob('/tmp/wf-scripts/*.sh')))"
   ```

4. **在临时副本里跑编译步骤**（覆盖哪些路径见上面「检查项明细」）。
   **按内容挑脚本，别认编号**：文件名叫 `build-<下标>.sh`，插一步就整体错位（错位后可能
   「静默测错步骤」）。用 `grep -l 'typst compile'` 找编译步、`grep -l '<!--SLIDES-->'` 找导航页、
   `grep -l 'managed=true'` 找计算 tag、`grep -l 'release-notes.md'` 找写说明（`verify-site.sh`
   就是这么做的）。
   另外这些脚本依赖 workflow `env:` 里的 `TYPST_VERSION` / `BUILD_DIR` / `RELEASE_TZ`，
   手工跑时要自己补上，否则 `set -u` 会直接报 `unbound variable`。
5. push 之后用 `gh run watch <id> --exit-status` 看结果，并用
   `gh api repos/.../actions/runs/<id>/logs`（zip 里的文件名可能不是 UTF-8，
   用 Python 的 `zipfile` 读，别用 macOS 的 `unzip`）核对：
   是否走了增量、Release 附件是否为最新。
6. **收尾清掉临时目录**：`/tmp/wf-scripts`、`/tmp/slides-verify.*`（`verify-site.sh` 每次用
   `mktemp -d` 建、trap 会删，异常退出时才可能剩下）、自己造的 `/tmp/ci-t*`、`/tmp/a4-*` 之类。
   这些都不在仓库里，但堆着容易在下次排查时误读成"当前状态"（我就踩过：拿上一次的
   `/tmp/wf-scripts` 去验证新改的 workflow）。

<!-- tortrixx/slides · 仓库约定见 AGENTS.md -->

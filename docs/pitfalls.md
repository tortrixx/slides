# 已踩过的坑（docs/pitfalls.md）

完整坑清单（AGENTS.md §7 的展开版，2026-10-11 拆出，条目内容未改动）。
每条都附实测现象与修法，多数已被门禁（verify-site.sh）的对应断言钉住。
**这些坑的共同点是不会报错，只会安静地出错** —— 改 CI 脚本前建议先过一遍。

---

- **`git diff --name-only` 默认会转义非 ASCII 路径**（2026-10 实测，严重）：文件夹名允许汉字 /
  假名 / emoji（§3.8），而 `core.quotePath=true`（默认）把 `slides/中文/main.typ` 输出成
  `"slides/\346\226\207/main.typ"` —— 编译步骤用 `grep -qF -- "slides/中文/"` 判断「这套 deck
  改没改」，于是永远匹配不上：**复用旧 PDF 却照写新 stamp**，静默发布旧内容且永不自愈。
  修法是 `git -c core.quotePath=false diff …`，门禁的 ②b 专门钉这一条。
  凡是拿 git 输出的路径做字符串比较的地方，都要先想一遍「非 ASCII 会不会被转义或加引号」。
- **`set -euo pipefail` 下，命令替换里的管道失败会终止整个步骤**：生成导航页那步读 `/Count` 的
  `pages="$(… | grep -o … | tail -1)"` 在「读不到」时 grep 返回 1 → 整步退出，与注释里承诺的
  「不渲染页数那一项」正好相反（部署会被整个跳过）。已补 `|| true`。同一步里新增命令替换时留意。
- **`printf … | grep -q` 在 `pipefail` 下会把「匹配成功」变成「失败」**（2026-10 实测，严重）：
  `grep -q` 命中即退出，若左侧数据超过管道缓冲（Linux 64 KiB，约上千条路径），printf 撞 EPIPE
  返回 141，`set -o pipefail` 让整条管道算失败 —— 于是 `if ! printf … | grep -qF …` 里的 `!`
  把「有改动」翻成「没改动」，**静默复用旧 PDF**。判断「这个 deck 改没改」的地方已改成
  here-string（`grep -qF -- "$dir" <<<"$changed"`），没有管道就没有 SIGPIPE。
  凡是「可能很大的数据 | grep -q」都要这样写。
- **`slides/*/` 通配不到点号开头的目录**：`slides/.hidden/main.typ` 会被完全无视（不编译、不出卡片），
  而只要还有别的 deck 就 `exit 0` —— 站点永远少一套且没有任何报错。已加显式护栏报错。
- **`basename` 会吃掉结尾换行**：目录名 `nl\n` 与 `nl` 会落到同一个 `nl.pdf` 上互相覆盖。已按
  原始字节拦掉含换行/回车的目录名。
- **`BUILD_DIR` 为空/`./` 时的通配符会指向文件系统顶层**：`"$BUILD_DIR"/*` 空值展开成 `/*`、
  `'./'` 等价于 `.`（都实测过），而清理循环里有 `rm -rf`。已加「校验构建环境变量」步骤
  归一化后 fail closed。
- **CI 的 run 块带 `-e`，本地门禁不带**：`wf_rev="$(git hash-object … 2>/dev/null | cut …)"` 这种
  「本意容忍失败」的写法，在 CI 上会**静默中止整步**（rc=128、一行日志都没有），而本地门禁里
  它会正常降级成全量编译 —— 两边行为不同，所以必须显式写 `|| wf_rev=""`。
- **`actions/cache` 的 `if:` 是无效的**（实测）：官方文档写明「cache action 不支持 `if:`，
  条件会被忽略」。本仓库 `恢复上次的编译产物` 那步挂着
  `if: github.event_name == 'push' && github.ref == 'refs/heads/main'`，但查运行日志，
  在 main push 上是真的执行了（`Cache restored from key: slides-build-main-<旧 run_id>`）——
  行为上"碰巧对"，但**别指望这个条件真的拦住什么**。真要"只在 main 上恢复缓存"，
  得把 cache 拆到独立 job 或用 `actions/cache/restore` + 显式条件。
  好消息是增量逻辑本身不依赖这个条件：非 main push 一律全量编译（第 1 步的判断），
  缓存里那份旧 build/ 只会被全量覆盖，不会造成陈旧复用。
- `upload-artifact` 保存的是「路径公共祖先」下的相对结构；`download-artifact`
  用 `path: build` 还原后仍是 `build/*.pdf`，Release 的 `files` 通配符依赖这一点。
- Jekyll 不参与（Pages 走 Actions 上传 artifact），无需 `.nojekyll`。
- `softprops/action-gh-release` 的 `body_path` 指向不存在的文件时会回退到 `body`；
  本仓库用两个独立步骤（新建 / 只更新附件）来彻底避免误覆盖说明。
- GitHub 上「发布 Release」会**同时**产生 tag push 事件，可能让 workflow 跑两次；
  release job 的 concurrency group 会串行化它们。
- 用 `GITHUB_TOKEN` 创建 tag 不会触发新的 workflow run，所以按日期发版不会自激。
- 改 workflow 里的**编译相关参数**（Typst 版本、装哪些字体、`--font-path`）会自动触发全量编译
  （stamp 里存了 workflow 哈希）。但如果是**外部**变化——例如 apt 上的字体包本身升级、
  Typst 上游改了默认字体——哈希不变，未改动的 deck 仍复用旧 PDF。这种极少见的情况才需要
  到 **Actions → Caches** 删掉 `slides-build-main-*` 再跑一次。
  代码字体不在此列：它按 sha256 钉死，上游换包会直接红而不是悄悄换掉排版（见 §4「build 细节」）；
  仍会随镜像漂的只有 apt 装的 Noto / Inter，所以 `runs-on` 才钉 `ubuntu-24.04`。
- Release 说明里的站点链接是按「项目页」拼出来的（`<owner>.github.io/<repo>/`）。若以后
  换成自定义域名，这段（以及首页里的相对链接之外的地方）需要同步改。
- 首页的卡片标题是**纯文本**：deck 里 `title: [*粗体*]` 会原样显示星号，不会渲染成粗体。
- 写 Typst 内容时注意这几个和 Markdown 不一样的地方（都在模板里踩过并改对了）：
  - 粗体是*单*星号 `*粗体*`。写 `**粗体**` 不会报错，但只会得到「两个空的强调标记」警告，
    并原样冒出一堆星号。
  - 多行公式里的换行必须写成**两个**反斜杠 `\\`（源码里就是两个字符）；
    只写一个 `\`，Typst 会把数学变成普通文本，几行公式挤成一行。
    而正文里想显示「两个反斜杠」这串字符，同样要写 `\\`。
  - 正文里显示反引号要用双反引号包起来：` `` `反引号` `` `。
  - `#cols` 的列数/列宽必须走具名参数：`#cols(columns: 2, ...)`、`#cols(columns: (2fr, 1fr), ...)`。
    写成位置参数 `#cols(2, ...)` 或 `#cols((2fr, 1fr), ...)` 都会
    `expected content, found integer/array`（`cols` 的可变参数是内容块，不是列定义）。
- **`#pause` 不要放在一页的最后**。它把一页拆成多张子页，而*它后面的内容*直到那一页才出现；
  放在末尾后面没有内容可藏，只会多出一张与上一页完全一样的空白子页（v0.8.0 实测）。
  查这种问题时把每页渲染成 PNG 比对哈希，连续两页 sha1 相同即可认定是空子页。

- **每个文件末尾都有一行「仓库级标记」（`tortrixx/slides · 仓库约定见 AGENTS.md`）**：
  文本文件用各自的注释语法；两个 PNG 里是 IHDR 之后的 tEXt 注释块（全部 chunk 的 CRC 已复核）。
  （原先 `slides/26-09-30/src/demo.pdf` 里也放过一行 `%` 注释，但那个 PDF 没有任何 deck 引用 ——
  73 KB 死重量，已删除；门禁 ⑧ 的夹具是自己在 `$TMP` 里造同名文件，与此无关。）
  它唯一的作用是让 GitHub 仓库首页**每个文件的「最后提交」一列显示同一条消息**（否则各文件的
  最后改动分散在不同提交里，那一列会五花八门）。**纯装饰，别删**：删掉哪个文件，哪个文件的
  那一列就会退回旧消息。README 那行是**行尾内联**的，所以 README 仍然是 6 行。

<!-- tortrixx/slides · 仓库约定见 AGENTS.md -->

# AGENTS.md

给在本仓库工作的 AI agent（以及未来的维护者）的技术说明。
**README 只有 6 行：仓库定位 + 在线地址**（幻灯片清单看站点，不放目录树）。本文件放全部
操作说明、实现细节和坑。

> 文档分工（请务必遵守）：**README 只讲仓库的定位，能多短就多短**——一句话说明这是什么仓库，
> 加一个在线地址，就结束了。幻灯片清单、目录结构、操作步骤、注意事项、机制、约定、边角情况
> 一律不写；需要说明的写在本文件。目录树和清单会随仓库变化而过时，站点才是权威列表。

---

## 1. 项目概览

Typst + Touying 幻灯片仓库。每套幻灯片是 `slides/` 下的一个独立文件夹，
推送到 `main` 后由 GitHub Actions 自动：

1. 安装模板用到的字体（Noto Sans CJK SC / Inter）；
2. **增量**编译所有 `slides/*/main.typ` 为 PDF；
3. 生成 `build/index.html` 导航页并部署到 GitHub Pages；
4. 按**当天日期**创建/更新一个 Release，把全部 PDF 作为附件。

**唯一的目录约定**：`slides/<名称>/main.typ` 存在 → 编译成 `<名称>.pdf`。
没有 `main.typ` 的文件夹会被忽略（可以安全地放笔记、素材）。

新建一套幻灯片：`cp -R slides/template slides/my-talk`（连 `src/` 等资源目录一起复制），
改名和内容后 push 即可。

- 仓库：`tortrixx/slides`，默认分支 `main`
- 站点：<https://tortrixx.github.io/slides/>（Pages Source = GitHub Actions，已开启）
- 固定下载：`https://github.com/tortrixx/slides/releases/latest/download/<名称>.pdf`

## 2. 仓库结构

```
.
├── slides/
│   ├── template/             # 唯一的模板：前言样板 + 封面/目录/分节 + 各类写法示例
│   │   ├── main.typ
│   │   └── src/README.md     # 空的资源目录（占位说明），cp -R 后会一起复制过去
│   └── 26-09-30/             # 实际使用的 deck（自带 src/ 图片等资源）
│       ├── main.typ
│       └── src/
├── .github/workflows/
│   └── build-and-deploy.yml  # 全部自动化逻辑（唯一的 CI 文件）
├── index.template.html       # 站点首页模板（构建时注入幻灯片列表）
├── verify-site.sh            # CI 门禁脚本：抽 workflow 脚本 + 语法/lint + 真跑六条编译路径
├── AGENTS.md                 # 本文件
├── README.md                 # 6 行：定位一句话 + 在线地址，不放任何清单/操作
└── .gitignore                # 忽略 build/ 与本地编译出的 slides/*.main.pdf
```

`build/` 是 CI 产物目录（站点根），不要提交。

## 3. 幻灯片约定（改 `slides/` 前必读）

1. **每套幻灯片自带完整前言**，不依赖其它文件夹。CI 的做法是
   `cd slides/<名称> && typst compile main.typ <repo>/build/<名称>.pdf`，
   因此编译时的项目根目录就是该幻灯片文件夹本身 —— 跨文件夹 `#import "../common.typ"`
   或 `"../../shared.typ"` 都会报 `would escape the project root`（已实测），
   共享代码只能靠每份 deck 各存一份，或用 `--root` 显式指定更大的根目录。
2. **资源用相对路径**，放在幻灯片自己的目录下：`#image("src/figure.png")`。
3. **统一前言**（所有 deck 保持一致，改动时请同步；`slides/template/main.typ` 是样板）：

   ```typst
   #import "@preview/touying:0.8.0": *
   #import themes.metropolis: *
   #import "@preview/numbly:0.1.0": numbly
   #import "@preview/pinit:0.2.2": *

   #show: metropolis-theme.with(aspect-ratio: "16-9", config-info(..))

   #set text(
     font: ((name: "Inter", covers: "latin-in-cjk"), "Noto Sans CJK SC"),
     weight: "regular", size: 20pt, lang: "zh", region: "cn",
   )
   #show math.equation: set text(font: "New Computer Modern Math")

   #set heading(numbering: numbly("{1}.", default: "1.1"))
   ```

4. **中西文混排不要加 `#show regex(...)` 缩放/位移规则**（2026-10 决定）：汉字与西文同为
   20pt、共用基线，交给字体自己的度量。历史上试过两种「平衡」写法，都已实测否决、别再重试：
   - `set text(size: 0.9em)`（缩字号）：汉字块头是小了，但墨迹**底线比拉丁基线低约
     1.4pt/20pt**，中文看着往下掉、和数字/大写字母对不齐——「偏小、不齐」就是这么来的。
   - `set text(size: 1em, baseline: -0.08em)`（抬基线把底线拉平）：300dpi 实测底线确实
     做到 0.0pt，但汉字整体上浮，实际观感仍别扭。
   - 300dpi 实测（20pt，拉丁基线为 0）：`1em` 汉字墨迹 18.5pt / 底线 +1.4pt；
     `1em + baseline -0.08em` 18.5pt / **0.0pt**；`0.9em` 16.6pt / +1.4pt。
   - 顺带结论：这类微调**收益很小**，不值得再折腾——见 §3.5 关于字号的那笔账。
   - 如果以后要局部调整，只在某一页用 `#slide[#set text(...)]`，别动全篇。
5. 字号：正文 20pt 是 metropolis 的默认值，`#set text` 里显式写出来只为可读性。
   内容特别密的单页用局部覆盖（`#slide[#set text(size: 18pt) ...]`），不要全局改小。
   实测过「调小全局字号能装更多内容」这个想法：`size` 会等比缩小正文、页眉标题、封面、
   页码（`1.2em` 系相对父级），但**一页容量只从 28 条涨到 32 条（16pt，+14%）**，
   而且**总页数完全不变**（页数由标题与 `#pause` 决定，不是字数）。想装更多就拆页，
   想看着轻松就压单页。
6. 主题切换：`themes.metropolis` → `themes.university` / `dewdrop` / `stargazer` / `aqua`
   （实测这五个可以只换开头两行、正文不动）。两个例外：
   - `themes.simple` 的封面必须写 `#title-slide[标题]`，写 `#title-slide()` 会
     `missing argument: body`——旧文档说的「metropolis 可以直接写」只对上面那五个成立；
   - `themes.default` 不是主题（只导出 `slide` 等构件，没有 `*-theme` 函数），
     `themes.article` 是 A4 文章主题（见 §3.9），都别往放映稿里套。
7. 包版本固定：touying 0.8.0（要求 Typst ≥ 0.15.0）、numbly 0.1.0、pinit 0.2.2。
8. **文件夹名即 URL**：允许 **字母 / 数字 / `.` / `_` / `-`** 以及**任何非 ASCII 字符**
   （汉字、假名、emoji 都行）；禁止空格和其余 ASCII 符号。编译步骤会检查，违规直接
   `::error::` 并退出（否则会做出坏链接、坏 HTML、坏 Markdown）。改名等于换 URL，旧链接会 404。

9. **非 Touying / A4 文档**：流水线不关心内容形态 —— A4 讲义、读书笔记、论文式文档都能和放映稿
   共存。硬性要求只有三条：`slides/<名称>/main.typ` 存在、能用
   `typst compile main.typ <out>.pdf` 编出 PDF、资源走相对路径。与放映稿的差异：
   - **标题**：首页取的是 `main.typ` 里第一个 `title:`。A4 用 Typst 原生的
     `#set document(title: "…")`，**必须是字符串**；写成 `title: [..]` 会
     `error: expected string or array, found content` 直接编译失败
     （实测踩过，且会连带拦住整次部署）。不写 `title:` 则卡片退回文件夹名。
     实测：A4 文档写 `#set document(title: "A4 讲义示例")` → 卡片标题就是它
     （首页的提取只是按 `title:` 取第一个值，不关心它属于 `config-info` 还是 `document`），
     不写则退回文件夹名——所以 A4 卡片想要好看的中文标题，写上 `#set document(title: …)` 即可。
   - **副标题**：`subtitle:` 在放映稿里是 `config-info` 的字段，A4 文档没有 `config-info`，
     所以**不要在 A4 里写 `subtitle:`**——那行会原样印进正文（实测：PDF 页面上真的出现
     `subtitle: [A4 也想有说明]` 这一行字），虽然首页确实会把它当描述取走，但代价是正文里
     多一行源码垃圾。想让 A4 卡片带一行说明，**别用 `subtitle:`**：不写就是描述行整行不渲染，
     或者改模板 / workflow 另加一个专门的字段。
   - **字体**：A4 文档没有模板前言，需自己
     `#set text(font: ((name: "Inter", covers: "latin-in-cjk"), "Noto Sans CJK SC"), size: 11pt, lang: "zh", region: "cn")`，
     否则中文用回退字体（CI 里只保证这两个字体已安装）。
   - 中西文混排**不用加任何缩放规则**（见 §3.4，那两条都已被否决）；字号走 11pt 左右
     （放映稿才是 20pt）。
   - 增量编译、按日期发版、首页列表对它一视同仁。
   最小可用模板（已逐字编译验证，产出 595.28×841.89pt 的 A4）：
   `#set document(title: "…")` + `#set page(paper: "a4", margin: (x: 2.2cm, y: 2cm), numbering: "1")`
   + `#set text(font: ((name: "Inter", covers: "latin-in-cjk"), "Noto Sans CJK SC"), size: 11pt, lang: "zh", region: "cn")`
   + `#set heading(numbering: "1.")`，然后正常写 `= 一级标题` 与正文。
   实测：1 页 / 2 页都正常列出；与 Touying deck 混排全部编译通过，只改其中一份时也只重编那一份。
   这些注意事项**只写在本文件**，README 保持极简（见文首的文档分工规则）。

## 4. CI/CD（`.github/workflows/build-and-deploy.yml`）

### 触发条件

| 事件 | 说明 |
| --- | --- |
| `push` 到 `main` | 编译 + 部署 Pages + 按日期发版 |
| `push` tag `v*` | 编译 + 用该 tag 建版本化 Release（**不**部署 Pages） |
| `release: published` | 只给该 Release 补/覆盖附件，不动说明 |
| `workflow_dispatch` | 手动：选 `main` 则编译+部署；不发版 |

### 四个 job

| job | 条件 | 权限 | 作用 |
| --- | --- | --- | --- |
| `verify` | `github.event.deleted != true` | 默认（`contents: read`） | 门禁：跑 `verify-site.sh --build`（六条路径），失败则后面全部不执行 |
| `build` | `github.event.deleted != true` | `contents: read` | 装字体 → 增量编译 → 生成导航页 → 上传两份产物 |
| `deploy` | `refs/heads/main` 的 push 或手动 | `pages: write`, `id-token: write` | `actions/deploy-pages` 发布 `build/` |
| `release` | main push / 推送 tag / release 事件 | `contents: write` | 计算 tag → 写说明 → 建/更新 Release |

`deploy` 用固定的 `pages` concurrency group；`release` 用 `release-<tag>`（main push 时即
`release-main`）串行化，避免同一天两个 push 并发改同一个 Release。

### build 细节

- **字体**：`apt-get install fonts-noto-cjk fonts-inter`（取不到时降级为只装 CJK）。
  故意**不装** `fonts-noto-cjk-extra`（多 145MB），代价是 `weight: "medium"` 之类中间字重回退。
- **增量编译**：`actions/cache@v6` 以 `slides-build-main-<run_id>` 为 key、`slides-build-main-`
  为 restore-keys 缓存 `build/`。逐套判断：全量 / 缓存缺 PDF / 该目录相对**基准提交**有改动 → 重编。
  最后清理「`slides/<名称>/main.typ` 已不存在」的残留 PDF。
  基准**不是** `github.event.before`，而是缓存目录里 `.build-stamp` 记的**上一次真正编译成功的提交**：
  ```
  <sha> <TYPST_VERSION> <workflow 文件哈希>
  ```
  为什么不用 `before`：它只覆盖本次 push。若上一次运行失败（缓存没存下）或两次 push 挨得很近，
  那一次改过的 deck 就既不在 diff 里、缓存里又是旧 PDF，会被**永久复用成旧版本**且不会自愈
  （已实测复现，两份独立审查也都指出过）。用 stamp 作基准，差异永远是「相对上次成功编译」，
  而编译失败时不会写 stamp，所以失败的下一次 push 必然把那些 deck 重新编译一遍。
  另两个字段用来在**编译环境变化**（Typst 版本、workflow 里的字体/编译参数）时强制全量。
  stamp 是 `build/` 里的隐藏文件：只进 patch 缓存，不进 artifact、不进 Pages。
  tag / release / 手动运行一律全量编译。
- **导航页**：`index.template.html` 是首页模板（版式/样式都在里面），workflow 只负责
  注入数据，产物 `build/index.html` 是**服务端渲染**的静态页（无 JS 也能看）。
  三处占位注释由 `awk` 替换：`SLIDES`（卡片列表）、`COUNT`（套数）、`META`（页脚的「最后更新 …」）。
  页脚**只放这个时间戳**：原来那句「本页由 GitHub Actions 自动生成」说的是构建过程、不是页面内容，
  已删（与早先删掉 "Built by Typst & Touying." 同理）；提交号也一并不显示了——它是构建提交，
  跟某套幻灯片最后一次改动无关，容易被误读。
  卡片数据来源：
  - **标题/副标题**：`sed` 从 `main.typ` 里取**第一个** `title:` / `subtitle:`，依次尝试
    `[..]` 单独成行 → 单行里的 `[..]` → `".."` 字符串写法；**跳过注释行**（否则
    `// title: [旧标题]` 会中选），单行模式要求键前面不是字母/下划线（否则 `subtitle:` 里的
    `title:` 会被贪婪匹配成标题——实测踩过）。
    注意它**不检查这个键属于谁**：`config-info(title: …)`、A4 的
    `#set document(title: "…")`、甚至正文里一行 `title: [x]` 都会被取走（后者见 §3.9 的警告）。
    回退策略**两者不同**：`title` 取不到就退回**文件夹名**；`subtitle` 取不到（没写、
    `subtitle: []`、或压根没有这一行）则**整行都不渲染**，
    不再塞一句默认文案（旧版是一句「点击卡片在线预览…」，已移除——缺副标题的卡片宁可少一行，
    也不要一句与内容无关的话）。注意 `subtitle: []` 也走「不渲染」，没法用它保留空行。
    实现上 `desc_html` 变量里**只放标签、不放换行**：换行由模板那一行提供，否则空串时会把下一行
    顶走、在卡片中间留下纯空格行；另外别把变量写在行首，YAML 的块标量会因此提前结束（已踩）。
  - **链接与文件名**：`<文件夹名>.pdf`（与 `title` 无关）；大小由 `wc -c` 换算，
    分 B / KB / MB 三档（不足 1 MiB 时封顶 1023，避免出现 "1024 KB"）。
  - **卡片副信息行**：`<页数> 页 · <大小> · <文件名>.pdf`，前两项是 .badge 胶囊标签。
    页数从 PDF 页树根节点的 `/Count` 取（`strings | grep -o '/Count [0-9]\{1,4\}'`
    取最大值；Typst 产出的 PDF 未压缩所以读得到，已核对 49/20 与逐页渲染数一致）。
    **原来看起来多余的 `PDF` 徽章已去掉**——链接本身就是 `.pdf`、点了就是打开 PDF，
    文件名里又写了一遍，三处重复；换成页数更有信息量。若哪天读不到 `/Count`（例如 PDF 开始
    压缩），那一枚会渲染成空胶囊而不是错误数字，所以这个取法不会给出错的信息。
  - **转义**：文件夹名与标题/副标题都会做 HTML 转义（`&` `<` `>` `"`），
    文件夹名另有字符集护栏（见 §3.8），两道一起保证生成的 HTML 不会被名字搞坏。
  - 标题按**原文**显示：Typst 标记（`*粗体*`、反引号）不会被渲染，也不会被剥离。
- **首页视觉**：沿用 <https://github.com/tortrixx/tortrixx> 的设计语言（等宽字体、
  shadcn neutral 色阶、虚线网格背景、hover 光边框 BorderBeam、BlurFade 入场、
  深浅色主题）。改样式只动 `index.template.html`，不用碰 workflow。
  注意 `<meta charset>` 必须留在文件最前面——模板开头那段中文注释一旦挪到它前面，
  就会超出 1024 字节的编码探测窗口，页面会乱码。
  装饰性动效都做了降级：光带用 `@supports (offset-path: rect(...))` 包住（不支持就整条不显示，
  否则会在左上角糊一块渐变色），`prefers-reduced-motion: reduce` 时关闭淡入并隐藏光带，
  键盘焦点用 `:focus-visible` 描边。改 CSS 时请保留这些降级。
- **页面背景要设在 `html` 上，不能只设在 `body`**（Safari 踩过）：`body` 是
  `width: 90%` 的居中盒子、只有内容那么高，把 `background` 只写在它上面时，浏览器**可能**
  把 body 背景提升为画布背景（Chrome 会），Safari 不会 —— 结果内容高度以下露出一条浅色，
  深色模式下特别明显（用户截图报过）。现在是这样，三条一起保证铺满：

  ```css
  html { background: hsl(var(--background)); height: 100%; }
  body { min-height: 100vh; color: hsl(var(--foreground)); }  /* 注意：body 上不要再写 background */
  ```

  **`body` 上不能再写 `background`**：`.bg-grid` 是 `z-index: -1`，它画在**根背景之上、
  body 背景之下** —— body 一旦有不透明背景就把整片网格盖掉（这正是"背景修好了、网格
  却没了"的原因：根背景原本是透明的，加了颜色后就挡住了网格）。
  实测下半区灰度标准差：盖住时 0.46、去掉后 2.89（深色）/ 1.76（浅色）。

  同样要注意 `.bg-grid` 用 `position: fixed; inset: 0; height: 100%`，**百分比高度需要有
  参照**：只在 body 上写 `min-height: 100vh`、html 不给 `height` 时，Safari 里这层仍可能
  只覆盖内容高度（`html` 没有确定高度，body 的百分比高度就悬空）。
  判定方法（Chrome 也能做，因为量的是几何而不是颜色）：

  ```js
  // 旧写法会暴露：html 高只有内容高、背景透明，全靠浏览器提升 body 背景
  document.documentElement.getBoundingClientRect().height   // 应等于 innerHeight
  getComputedStyle(document.documentElement).backgroundColor // 不应是 rgba(0,0,0,0)
  ```

  实测对比：旧写法 视口 857 / html 289 / 根背景 transparent；新写法 857 / 857 / rgb(10,10,10)。
  另外 Safari 的 WebDriver（`safaridriver`）需要手动在 Safari 设置里开「允许远程自动化」，
  开不了就只能靠 Chrome 量几何 + 让用户在 Safari 里目视确认。
- **`prefers-color-scheme` 只在"跟随系统"时等于实际主题**：手动固定浅/深后，所有
  `<meta name="theme-color" media="(prefers-color-scheme: ...)">` 都会和页面对不上，
  所以 JS 应用主题时会 `removeAttribute("media")` 并改写 `content`，让地址栏那圈颜色跟着
  **实际生效的主题**走。
- **首页主题策略（三态循环，不是两态）**：`auto` / `light` / `dark`，右上角按钮依次循环。
  - `auto`（默认，也是 localStorage 没存 `theme` 时的状态）：**每次加载都重新读**浏览器的
    `prefers-color-scheme`，并在 `matchMedia` 的 `change` 事件里实时跟随。所以「首次打开按浏览器、
    之后每次刷新也按浏览器」在不手动干预时始终成立。
  - **图标按模式换，不是「太阳/月亮 + 小圆点」**：`data-mode` 决定显示哪一个——
    浅色=太阳、深色=月亮、**自动=半明半暗的圆**（`<circle>` 描边 + 右半 `<path>` 填充；
    这是「自动/对比度」的经典符号）。早先试过在太阳/月亮角上加 5px 小圆点表示自动，
    但那个点太小、不像个图标，已经换掉。
  - **图标显隐必须写成「默认全隐藏，只打开当前那个」**，别写成「基础的 `display: none`
    + 两条按模式覆盖」：后者上线后深色模式下太阳没被藏住，**太阳和月亮叠在一起画出来**
    （用户截图发现）。现在是这样，任何情况下最多一个可见：

    ```css
    .icon-sun, .icon-auto, .icon-moon { display: none; }
    [data-mode="light"] .icon-sun,
    [data-mode="dark"]  .icon-moon,
    [data-mode="auto"]  .icon-auto,
    .icon-btn:not([data-mode]) .icon-sun { display: block; }
    ```

    查这类「明明写了 display:none 却还在」的问题，**别只看 CSS 有没有写对**：
    用无头 Chrome 跑一段探针，对三种模式分别 `getBoundingClientRect()` 看谁不是 0×0，
    一眼就能定位（当时就是靠它确认 `dark` 下 sun=22×22、moon=18×18 同时存在）。
    注意本机 headless 默认 `prefers-color-scheme: dark`，要截浅色得显式
    `--blink-settings=preferredColorScheme=1`；截图前还要关掉 `.fade` 的入场动画，
    否则元素是 `opacity: 0`，截出来一片空白（会误判成"没渲染"）。
  - 注意：**别用「实心圆 + 月牙挖空」那种自创路径**画半明半暗——在 24 网格里实心圆会把
    挖空盖掉，渲染出来就是一坨黑圆（无头 Chrome 渲染预览才看出来）。
  - `light` / `dark`：用户明确选过才写进 `localStorage.theme` 固定下来；回到 `auto` 时
    `removeItem` 把键清掉，否则刷新后又被固定住。
  - **为什么不是两态**：二态按钮没有「跟随系统」这个位置，一按就只能写死，检测于是永远失效
    （这正是改之前的毛病）。三态把 auto 变成可见、可切回的状态。
  - **关键实现坑**：应用主题必须判断模式——`apply(mode === "auto" ? query.matches : mode === "dark")`。
    若照抄成 `apply(query.matches)`，每次系统变化/刷新都会把手动选择覆盖掉，固定模式形同虚设
    （写了这个 bug，被 `ok/fail` 断言抓出来）。
  - 其它实现细节：点击用**事件委托**（脚本在 `<head>`、先于按钮执行，不能直接
    `getElementById(...).addEventListener`）；`aria-label`/`title` 说明「当前模式 + 点一下去哪」，
    `aria-pressed` 只反映当前是否为深色；切模式时通过 `#themeStatus`（`role="status"`）播报，
    首屏那次不播报（用 `announcedMode` 比较）。`localStorage` 全部包在 `try/catch` 里。
  - `:root`/`.dark` 变量与太阳/月亮图标只由 `html.dark` 驱动；JS 另写行内 `color-scheme`
    （优先级高于样式表里 `html` / `html.dark` 两条兜底）让表单控件与滚动条一起变。
    无 JS 时没有 `.dark`，页面恒为浅色，内容与链接不受影响。
- **产物**：`slides-build`（普通 artifact，给 release job 下载，`retention-days: 3`）+
  `github-pages`（`actions/upload-pages-artifact@v5`，给 deploy job，自带 1 天保留期）。
  两份都只在同一次运行内使用，所以保留期压得很短，避免长期堆积；留 3 天是为了隔天
  「Re-run failed jobs」时还取得到产物。`index.template.html` 在仓库根，不会进站点
  （只上传 `build/`）。

### release 细节

- tag 规则（「计算 tag」步骤的 else 分支）：
  `tag="v$(TZ="${RELEASE_TZ}" date +%Y.%m.%d)"`，`RELEASE_TZ` 默认 `Asia/Shanghai`。
- `managed=true` 表示这是工作流按天维护的 Release → **每次都刷新说明与附件**；
  `managed=false`（手动 tag / release 事件）→ 只在 `exists=false` 时写说明，
  已存在时**只覆盖附件、绝不传 body**，以免覆盖用户手写的说明。
- `exists` 用 `gh release view <tag>` 探测。
- 发布用 `softprops/action-gh-release@v3` + `overwrite_files: true`（同一天重复 push 靠它覆盖）。
- **tag 一旦创建就不再移动**：同一天的附件会更新，但 tag 停在当天第一次 push 的提交。
  移动已存在的 tag 会让所有克隆的 `git fetch --tags` 报 `would clobber existing tag`。
- `verify` / `build` / `release` **三个 job 都有** `if: github.event.deleted != true` 防护：
  **删除 tag/分支同样会产生 push 事件**，没有这个防护，删掉 `v2026.09.30` 后工作流会
  判定该版本不存在而把它重新创建出来。（`verify` 也带这个条件，是为了「删分支」这类事件
  不必白跑一遍校验。）

### 运维备忘

- **换默认分支**（比如 `main` → `master`）要一起改 workflow 里**全部 6 处**：顶部的
  `branches:` 触发器，4 处 `if`（`verify`、`build` 各一处 `github.event.deleted != true`；
  `deploy`、`release` 各一处分支判断），以及增量编译判断里的
  `[ "$GITHUB_REF" = "refs/heads/main" ]`。
  漏掉最后那处不会报错，但每次都退化成全量编译。用
  `grep -n 'branches:\|refs/heads/main\|event.deleted' .github/workflows/build-and-deploy.yml`
  全部找出来改（改 `deploy`/`release` 时注意别把 `verify`/`build` 的删除防护一起改掉）。
- **`deploy` 报 Pages 未启用**：Settings → Pages → Build and deployment → Source 选
  **GitHub Actions**。
- **某套幻灯片编译失败**：站点与 Release 都会整次跳过，不会发布残缺内容；日志里会指出
  是哪个 `main.typ`，修好再推即可（stamp 机制保证下次必然重编它）。
- **`build/` 不要提交**：CI 产物，已在 `.gitignore` 里。

## 5. 常用命令

```bash
# 本地编译某套幻灯片（必须在它的目录里跑，相对路径才有效）
cd slides/template && typst compile main.typ && typst watch main.typ

# 渲染某页为图片来肉眼检查
typst compile --format png --pages 6 main.typ '/tmp/p-{p}.png'

# 本地 Typst 版本应与 workflow 的 TYPST_VERSION 一致（当前 0.15.1）

# 本地跑门禁（CI 里也是同一条命令；改完 workflow 务必先本地过一遍）
bash verify-site.sh --build    # 静态检查 + 六条编译路径（20 项）
bash verify-site.sh            # 只做静态部分，几秒（不真编译）

# 查看线上状态
gh run list --repo tortrixx/slides
gh release list --repo tortrixx/slides
gh api repos/tortrixx/slides/releases --jq '.[].tag_name'
```

**本地预览首页**（模板 + 生成步骤）：

```bash
# 先按 §6 第 1 步把 workflow 脚本抽到 /tmp/wf-scripts，再跑「生成导航页」那一步：
RUNNER_TEMP=/tmp/rt BUILD_DIR=build RELEASE_TZ=Asia/Shanghai \
  bash /tmp/wf-scripts/build-5.sh
# 是 build-5.sh（生成导航页），不是 build-4.sh（编译 PDF）—— 编号对应见 §6 第 4 步。
# 这一步已不需要 GITHUB_SHA（页脚不再显示提交号）。
# 然后用无头 Chrome 截图看效果。两个坑：
#   1) headless 默认 prefers-color-scheme: dark —— 想截浅色要显式 remove("dark")
#   2) 入场动画带 fill-mode: both，t=0 时元素是 opacity:0 —— 截图前注入
#      .fade{animation:none;opacity:1}，否则截出一张空页
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
  --user-data-dir=/tmp/cprof --window-size=1100,1250 \
  --screenshot=/tmp/shot.png file:///path/to/index.html
```

## 6. 改 workflow 后的验证清单（务必执行）

CI 逻辑全在 YAML 的 `run: |` 里，改完不能只靠肉眼。**`verify-site.sh` 就是 CI 门禁本身**
（`verify` job 跑 `--build`），本地可以先跑一遍再推：

```bash
bash verify-site.sh            # 静态检查：抽脚本 + bash -n + 多字节 lint（几秒）
bash verify-site.sh --build    # 再六条编译路径，和 CI 门禁完全同一条命令
```

当前基线：`--build` 全绿 = 20 项通过，覆盖六条路径：
① 冷启动全量 ② 只改一个 deck 的增量 ③ 删除某套后清理残留 PDF
④ 某套编译失败必须 `exit 1` ⑤ 文件夹名非法必须 `exit 1` ⑥ 一套都没有必须 `exit 1`。

**为什么这个门禁值得存在**：这六条守的都是**静默失效**的不变量 —— stamp 基准错了会
长期复用旧 PDF、护栏失效会做出坏链接、失败没 `exit 1` 会发布残缺站点。它们破了不报错，
只是安静地出错，所以必须靠真跑一遍来守。反过来，`bash -n` 那类静态检查当门禁是**零增量**
（语法错 GitHub 起不来 job、运行时也立刻炸），所以门禁的价值全在 `--build` 那部分。

**门禁脚本自身的鲁棒性约定（`verify-site.sh`）**：
- **不写死 workflow 的 `env:` 值**，改成从 YAML 读 `TYPST_VERSION` / `BUILD_DIR` / `RELEASE_TZ`。
  写死过 `TYPST_VERSION`，后果实测很严重：workflow 一升级版本号，脚本造的 stamp 里的版本就和
  真正会写的那份不一致 → 走进「编译环境变了 → 全量」分支 → ②③ 的增量断言全挂。
  实测对比（把 workflow 的版本改成 9.9.9）：**写死版 2 通过 / 17 失败（exit 127）**，
  读 env 版 **19 通过 / 0 失败**（当时还没加 env 断言，现在是 20 项）。这类假红比漏报更糟 —— 它会诱使人把测试改松。
- **用 `trap 'rm -rf "$TMP"' EXIT INT TERM` 清理临时目录**：失败路径最容易留垃圾，
  而留下的 `/tmp/slides-verify` 会在下次排查时被误读成"当前状态"（真踩过）。
- 顺带：脚本里 `git commit` 用 `git -c user.email=… -c user.name=…`，不依赖 runner 上有
  git 身份配置（那是环境相关的，不该假设）。

**门禁的结构约束（别改坏）**：
- 必须是**独立 job**。塞进 `build` 的步骤里有坑：`build` 最后会写 `.build-stamp`，
  如果顺序成了「编译 → 写 stamp → 门禁失败」，stamp 已落盘，下次 push 会以为编译过了而
  跳过重编 —— 门禁反而制造了它本该防的那种不一致。
- `build` 靠 `needs: verify` 依赖它，所以门禁红了站点和 Release 都不会动（fail closed）。
- 门禁会自己触发全量重编：workflow 文件哈希进了 stamp，所以**改 workflow 必然全量编译**，
  而门禁又额外编译约 5 遍。这个成本只落在「改了 workflow」的 push 上，日常改 deck 不受影响。
- 门禁 job 也装了字体（和 build 同一套）。脚本要真编译含中文的 deck，字体齐全才能保证
  不因环境差异假红。注意 **`--font-path` 是追加、不是限制**（实测带空目录时字体数不变：
  394 → 394），所以没法用它模拟「没装字体」来验证这件事。

手工做的话，对应下面几步（脚本就是照这个写的）：

1. **解析 YAML 并抽出脚本**（用 Ruby 自带的 psych，避免手抄）：

   ```bash
   ruby -ryaml -e '
     wf = YAML.load_file(ARGV[0]); out = ARGV[1]; require "fileutils"; FileUtils.mkdir_p(out)
     wf["jobs"].each { |jn, job| job["steps"].each_with_index { |s, i|
       next unless s["run"]; File.write("#{out}/#{jn}-#{i}.sh", s["run"]) } }' \
     .github/workflows/build-and-deploy.yml /tmp/wf-scripts
   ```

2. **语法与引号检查**：`bash -n /tmp/wf-scripts/*.sh`。
   本机是 bash 3.2（比 runner 的 bash 5 严格），能提前暴露问题。
3. **多字节陷阱 lint**：`$var` 紧跟中文字符时 bash 3.2 会把首个字节吞进变量名，
   必须写成 `${var}`：

   ```bash
   python3 -c "
   import glob,re
   p=re.compile(rb'\\\$[A-Za-z_][A-Za-z0-9_]*(\[[^\]]*\])?(?=[\x80-\xff])')
   print(sum(len(p.findall(open(f,'rb').read())) for f in glob.glob('/tmp/wf-scripts/*.sh')))"
   ```

4. **在临时副本里跑编译步骤**（覆盖四条路径：冷启动全量 / 只改一个 deck 的增量 /
   删除某套 deck 的清理 / 某套编译失败必须 `exit 1`）。
   **注意抽出来的脚本编号**：`build-4.sh` 是「编译」那步（含文件夹名护栏、stamp、
   六条路径的判定），`build-5.sh` 是「生成导航页」那步 —— 想验编译逻辑别拿错文件
   （拿 `build-5.sh` 测护栏会永远通过，因为它根本不看 `slides/`）。
   另外这些脚本依赖 workflow `env:` 里的 `TYPST_VERSION` / `BUILD_DIR` / `RELEASE_TZ`，
   手工跑时要自己补上，否则 `set -u` 会直接报 `unbound variable`。
5. push 之后用 `gh run watch <id> --exit-status` 看结果，并用
   `gh api repos/.../actions/runs/<id>/logs`（zip 里的文件名可能不是 UTF-8，
   用 Python 的 `zipfile` 读，别用 macOS 的 `unzip`）核对：
   是否走了增量、Release 附件是否为最新。
6. **收尾清掉临时目录**：`/tmp/wf-scripts`、`/tmp/slides-verify`（`verify-site.sh` 建的）、
   自己造的 `/tmp/ci-t*`、`/tmp/a4-*` 之类。这些都不在仓库里，但堆着容易在下次排查时
   误读成"当前状态"（我就踩过：拿上一次的 `/tmp/wf-scripts` 去验证新改的 workflow）。

## 7. 值得注意的坑（已踩过）

- `setup-typst` 的 `cache-dependency-path` **只接受单个可编译的 `.typ` 文件**，
  不支持通配符；cache miss 时它会 `typst compile` 这个文件来拉包。
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

## 8. 可能的后续改进

- 缓存 `@preview` 宏包：思路是在安装 Typst 前，把所有 `#import "@preview/..."` 行聚合到
  `$RUNNER_TEMP` 下的一个 `.typ` 文件，再把它交给 `cache-dependency-path`（该输入只认单个可编译文件）。
- 首页卡片已显示标题、副标题、页数、大小、文件名；还想要封面缩略图或每套 deck 的自定义
  描述，可以在 index 生成步骤里扩展（缩略图可用 `typst compile --format png` 首先生成首几页）。
- `fonts-noto-cjk-extra` 需要时加回即可（换更多中文字重）。
- 存储会随「每天一个 Release」线性增长：每次 Release 都保存一套完整 PDF 且不会自动清理。
  公开仓库的 Actions 存储免费，所以这是「慢」而不是「贵」的问题；真开始嫌大时，可以只上传
  本次重编的 PDF，或定期 `gh release delete --cleanup-tag` 清掉旧的日期版本。
- `setup-typst@v5` 与 `softprops/action-gh-release@v3` 目前按主版本号引用（可读性好、自动收补丁）。
  若要更强的供应链保证，可以把这两个第三方 action 固定到 commit SHA，并让 Dependabot 升级。
- 首页的标题层级：`h1` 是标语，`h2` 是 `Slides`；改动时别把唯一的主标题弄丢。

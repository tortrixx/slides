# AGENTS.md

给在本仓库工作的 AI agent（以及未来的维护者）的技术说明。
**README 只有 6 行：仓库定位 + 在线地址**（幻灯片清单看站点，不放目录树）。本文件放**操作约定**
（在这里工作必须遵守的规则与机制）；设计依据、测量数据和踩坑史话在 `docs/` 下，按需查阅。

> 文档分工（请务必遵守）：**README 只讲仓库的定位，能多短就多短**——一句话说明这是什么仓库，
> 加一个在线地址，就结束了。幻灯片清单、目录结构、操作步骤、注意事项、机制、约定、边角情况
> 一律不写进 README；**工作规则写在本文件，长篇的设计推演与历史记录写到 `docs/` 并在这里留指针**。
> 目录树和清单会随仓库变化而过时，站点才是权威列表。
>
> **本文件刻意保持精简**（2026-10 起，目标 ~50KB 以内）：agent 运行环境的指令预算有限
> （DSH 约 64KB），超出会被**截断** —— 它曾经被截断到 65KB，末尾的坑清单整节消失，agent
> 于是按「直觉」重试已被否决的方案。所以新增内容先想「这是工作规则还是历史依据」：
> 后者进 `docs/`，这里只留一行指针。

- `docs/site-design.md` — 首页视觉/版式的全部依据：历史方案、像素测量、外部规范、降级策略
- `docs/gate-design.md` — 门禁（verify-site.sh）每个检查项的完整说明 + 手工核对流程
- `docs/pitfalls.md` — 已踩过的坑完整清单（§7 的展开版）
- `docs/ci-design.md` — `build-and-deploy.yml` 的 build/release 细则与**实测依据**：2026-10-17
  从 §4 原样搬出（那天 §4 把本文件顶到 68 KB、撞上 64 KB 指令预算**被截断**，§7/§8 整节消失）

---

## 1. 项目概览

Typst + Touying 幻灯片仓库。每套幻灯片是 `slides/` 下的一个独立文件夹，
推送到 `main` 后由 GitHub Actions 自动：

1. 安装模板用到的字体（Noto Sans CJK SC / Inter / Maple Mono Normal NF）；
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
├── .github/
│   ├── workflows/
│   │   └── build-and-deploy.yml  # 全部自动化逻辑（唯一的 workflow）
│   └── actions/
│       └── setup-fonts/      # 装字体的复合 action（verify/build 共用；它的哈希进了编译环境指纹）
├── index.template.html       # 站点首页模板（构建时注入幻灯片列表）
├── tools/
│   └── deck-meta.py          # 从 main.typ 取 title/subtitle（导航页步骤调用；门禁 ①c 直接单测它）
├── assets/
│   └── icon.png              # 站点静态资源（左上角头像），构建时拷进 build/
├── docs/                     # 设计依据与踩坑史（site-design / gate-design / ci-design / pitfalls）
├── verify-site.sh            # CI 门禁脚本：抽 workflow/action 脚本 + 语法/lint + 真跑 ①~⑪
├── AGENTS.md                 # 本文件（操作约定；刻意保持精简，见文首分工）
├── README.md                 # 6 行：定位一句话 + 在线地址，不放任何清单/操作
└── .gitignore                # 忽略 build/ 与本地编译出的 /slides/*/main.pdf
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

   // 代码块（raw）用 Maple Mono Normal NF，由 CI 固定版本安装（见 §4「build 细节」）；
   // 本地没装会静默回退成默认等宽字体，所以名字写错/字体没装都不会报错。
   #show raw: set text(font: "Maple Mono Normal NF")

   #show math.equation: set text(font: "New Computer Modern Math")

   #set heading(numbering: numbly("{1}.", default: "1.1"))
   ```

   三个字族的分工：**Inter** 管西文、**Noto Sans CJK SC** 管中文（`covers: "latin-in-cjk"`
   让 Inter 只吃拉丁、混合文本按字形逐个回退）、**Maple Mono Normal NF** 管 `raw` 代码块；
   数学走 Typst 自带的 New Computer Modern Math，不用装。
   注意名字写的是 **`Maple Mono Normal NF`**：字体文件 name 表里的家族名其实是
   `Maple Mono Normal NF CN`，Typst 会把末尾的 `cn` 当风格后缀剥掉（原理见 §4），
   所以 deck 里、CI 断言里都用剥完后的名字。

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
   另外两条**不靠字符集**的护栏：**以 `.` 开头的目录会直接报错**（`slides/*/` 通配不到它，
   否则会静默少一套），**含换行/回车的目录名也直接报错**（`basename` 会吃掉换行，两个目录会
   落到同一个 PDF 名上互相覆盖）。
   **已知取舍**（2026-10-17 审查记录，别当 bug 修）：非 ASCII 那一半只按「高位字节」放行，
   所以 **Unicode 格式字符（`Cf`，如 U+202E 双向覆盖）也能进目录名**，页面上会出现视觉上
   反转的文件名（链接本身逐字节一致、点了能开，不构成坏链接）。没有拦它，是因为要在编译循环里
   加一次 python3 判定，而 ZWJ（emoji 序列用）也属于 `Cf`，一刀切会误伤 emoji 目录名 ——
   代价（多一个依赖 + 误伤）大于收益（单作者仓库、纯展示层欺骗）。真在意就按码位白名单
   （U+202A–U+202E / U+2066–U+2069 / U+200E–U+200F）单独拦，别按 `Cf` 整类拦。

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
     否则中文用回退字体（CI 里保证这两个字体已安装，见 §4「build 细节」）。
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
| `pull_request` | 只跑 verify + build（门禁 + 试编译）；不部署、不发版、不走增量缓存（全量编译） |
| `workflow_dispatch` | 手动：选 `main` 则编译+部署；不发版 |

### 四个 job

| job | 条件 | 权限 | 作用 |
| --- | --- | --- | --- |
| `verify` | `github.event.deleted != true` | 默认（`contents: read`） | 门禁：跑 `verify-site.sh --build`（①~⑪ + Release/tag 逻辑），失败则后面全部不执行 |
| `build` | `github.event.deleted != true` | `contents: read` | 装字体（复合 action）→ 增量编译 → 生成导航页 → 上传两份产物 |
| `deploy` | `github.event.deleted != true` **且** `refs/heads/main` 的 push 或手动 | `pages: write`, `id-token: write` | `actions/deploy-pages` 发布 `build/` |
| `release` | `github.event.deleted != true` 且（main push / 推送 tag / release 事件） | `contents: write` | 计算 tag → 写说明 → 建/更新 Release |

`deploy` 用固定的 `pages` concurrency group；`release` 用 `release-<tag>`（main push 时即
`release-main`）串行化，避免同一天两个 push 并发改同一个 Release。

**`build` 另有一个 `slides-build-${ref}` + `cancel-in-progress: true` 的 concurrency**：同一个 ref
来了新 push 就取消还在跑的旧 build。为什么需要它：两个 concurrency group 只保证「不并发」，
不保证「顺序」—— 若两次 push 挨得很近、且**先推的那次 build 更慢**（冷缓存/全量），它会晚于
新运行才进入 `pages` / `release-main` 组，把站点与当天 Release 刷回旧提交。取消掉被取代的 build
之后，它的 `deploy`/`release` 因 `needs` 未满足而根本不跑；被取消的运行也不会保存缓存
（`actions/cache` 是 `post-if: success()`），所以不污染缓存。

四个 job 都显式写了 `timeout-minutes`（verify 10 / build 20 / deploy 10 / release 10）：
不写的话默认上限是 **6 小时**，卡住的 job 会一直占着 runner，`deploy`/`release` 还会一直占着
自己的 concurrency 名额，把后续运行排队卡死（实测现有量级只用 9–37 s，余量 15× 以上；
套数涨到约 90 套时才需要抬 verify 的上限）。另外两个 `checkout` 都带
`persist-credentials: false` —— 没有任何步骤需要推送，不留 token 在 `.git/config` 里
（编译步骤用的 `git hash-object / diff / cat-file` 全是本地操作，不需要凭据）。

`runs-on` 全部**钉在 `ubuntu-24.04`**（不是 `ubuntu-latest`）：镜像迁移会让 apt 字体包版本变化、
进而改变 PDF 排版。但**光钉镜像标签挡不住字体漂移** —— 这个标签会被 GitHub 原地滚动，
`apt-get install` 取到的也是档案库当前版本，两者都能在不改任何仓库文件的前提下换掉
Noto Sans CJK / Inter（2026-10-17 独立复核指出：旧文档写「钉住后想换镜像是显式动作」是**错的**）。
所以现在**把装上的字体包版本也算进编译环境指纹**（`dpkg-query -W fonts-noto-cjk fonts-inter`
的输出与两个文件哈希一起哈希）——字体一变，stamp 立刻失配、自动全量重编。
想真正换镜像/字体时，除了改 `runs-on`，也记得删 `slides-build-main-*` 缓存。


### build 细节（**完整细则、实测数据与历史在 docs/ci-design.md**）

> 这一段原本 22 KB；2026-10-17 它把 AGENTS.md 顶到 68 KB、**撞上 64 KB 指令预算被截断**
> （末尾 §7/§8 整节消失），于是整段原样搬进 `docs/ci-design.md`，这里只留**必须遵守的不变量**。
> 新增内容时先想「这是规则还是依据」：依据进 `docs/ci-design.md`，这里只留一行。

- **字体**（verify/build 共用复合 action `.github/actions/setup-fonts`）：中文/西文
  `apt-get install fonts-noto-cjk fonts-inter`（**不装** `fonts-noto-cjk-extra`）；代码字体
  Maple Mono 从上游 Release **固定版本**下载，zip 与 TTF 两个 sha256 都钉在 `env:` 里，
  **缓存命中也照跑 sha256**。装完必须断言 `typst fonts` 里同时有 `Inter` / `Noto Sans CJK SC` /
  `Maple Mono Normal NF` —— 缺字体时 Typst **不报错**、只静默回退。断言写
  **`Maple Mono Normal NF`**，不是 name 表里的 `…NF CN`（Typst 会剥掉末尾风格词）。
  改字体 = 全量重编（哈希进了指纹）。
- **增量编译**：`actions/cache@v6` 缓存 `build/`（key `slides-build-main-<run_id>`、restore-keys
  `slides-build-main-`）；复用基准是 `.build-stamp` 里的
  `<sha> <TYPST_VERSION> <编译环境指纹>`，**不是** `github.event.before`；编译失败不写 stamp。
  逐套判断「全量 / 缓存缺 PDF / 相对基准有改动」，最后删掉 `main.typ` 已不存在的残留 PDF。
  **`build/` 里只该有 `*.pdf`、`index.html`、`.build-stamp`**（封面图那步 2026-10-17 加过、
  当天撤掉）。stamp 必须是**隐藏文件**：只进缓存，不进 artifact / Pages / Release，
  **别改成非隐藏名**。tag / release / PR / 手动运行一律全量。
- **构建环境校验（第一步，在装字体与恢复缓存之前）**：`BUILD_DIR` 归一化后必须是仓库内相对目录、
  只含 `A-Za-z0-9._-/`，且**最后一段必须叫 `build`**（`build` / `slides/build` 合法）——
  导航页那步会 `rm -rf "$BUILD_DIR"/*`，指到 `docs`、`.github`、`slides/<deck>` 之类就是删源码
  （2026-10-17 复核实测：`docs` 删 *.md、`.github` 删 workflow 与复合 action、`slides/<deck>/src`
  删未跟踪的真实图片）；另有一道冗余的「不许含 `main.typ`」检查；`TYPST_VERSION` 非空；`RELEASE_TZ` 用
  `python3 -c 'zoneinfo.ZoneInfo(...)'` 实打实解析（`[ -e /usr/share/zoneinfo/… ]` 太松）；
  `RECENT_DAYS` 必须是 1–3650 的整数；**三处用同一个 `${RELEASE_TZ:-Asia/Shanghai}` 兜底**
  （`TZ=""` 是 UTC，不是「系统默认」）。危险值（空 / `/` / `.` / `..` / 绝对路径 / 含 `..` /
  含空格）一律 `::error::` + `exit 1`。
- **目录名护栏**：点号开头（`slides/.hidden`）与含换行/回车都必须报错（前者 `slides/*/` 匹配不到，
  后者 `basename` 会吃掉换行）；字符集护栏见 §3.8。
- **导航页**：`index.template.html` + awk 按行替换三处占位（`SLIDES` / `COUNT` / `META`）；
  **占位符原文绝不能出现在模板里**；`COUNT` 现在没用（套数已去掉），替换规则留着。
  页脚只放「更新于 …」时间戳（**别再加回「全部 PDF」链接**）。顺序＝按
  `git log -1 --format=%cs` 倒序、同日按名字升序、无日期排最后（`LC_ALL=C`，**别退回 glob 顺序**），
  日期不上页面；`count` 必须显式兜底（process substitution 的退出码不参与 `set -e`）；
  checkout 必须 `fetch-depth: 0`。卡片数据：标题/副标题由 `tools/deck-meta.py` 取**行序第一个**
  非注释键（title 取不到退回文件夹名，subtitle 取不到整行不渲染）；页数**必须锚
  `/Type/Pages/Count`**（取全文 `/Count` 最大值会把大纲的标题数当页数）；文件夹名/标题/副标题
  都要 HTML 转义；「最近更新」圆点靠 `git log --since`，取不到日期就不标（fail safe）。
- **站点静态资源**：`assets/` 由导航页那步拷进 `build/`（缺失即 `::error::`，fail closed）；
  拷之前先清掉 `build/` 里非 `*.pdf` / `index.html` / `.build-stamp` 的旧文件，
  **白名单不许用通配、也不许加回任何目录名**（缓存会把它永久带下去并发布出去）。
  头像用仓库内 PNG，**别改回外链**。
- **站点视觉/前端**：改样式只动 `index.template.html`。`<meta charset>` 留在最前；全页**唯一 h1**；
  顶栏**一行到底**（窄屏不堆叠）；版式是**纯列表**（别再加封面/缩略图）；字重 `500`（**别写 600**）；
  行分隔线用 `.deck + .deck::before` 伪元素（**别改回 `border-top`**）；整行可点用 stretched-link
  （别加第二个链接）；主题三态 auto/light/dark 且
  `apply(mode === "auto" ? query.matches : mode === "dark")`；装饰 SVG 一律 `aria-hidden`；
  动效保留 `@supports` 与 `prefers-reduced-motion`（该偏好下除了淡入与光带，还要关掉
  `.avatar` / `.deck-title` / `.ext` 的 transition）；背景设在 `html`，
  **`body` 上不能再写 background**；页脚靠 flex 压底、不用 `position: fixed`。
  长串断行靠 `.deck-main` 上的 `overflow-wrap: anywhere`（**可继承，别只加在 `.deck-title`**，
  否则长副标题照样溢出）；`.deck-meta` 是 `flex-wrap: nowrap` + `.file { min-width: 0 }`
  （一换行，分隔点就会孤零零落在第二行行首）；hover 时元信息也要提到 `--foreground`
  （`--secondary` 灰底上 muted 只有 4.16:1，不合格）。依据与实测见 docs/site-design.md ⑤。
- **产物**：`slides-build`（给 release job，`retention-days: 3`）+ `github-pages`（给 deploy job）。
  两份都只在本运行内使用，保留期刻意压短。

## 5. 常用命令

```bash
# 本地编译某套幻灯片（必须在它的目录里跑，相对路径才有效）
cd slides/template && typst compile main.typ && typst watch main.typ

# 渲染某页为图片来肉眼检查
typst compile --format png --pages 6 main.typ '/tmp/p-{p}.png'

# 本地 Typst 版本应与 workflow 的 TYPST_VERSION 一致（当前 0.15.1）

# 本地跑门禁（CI 里也是同一条命令；改完 workflow 务必先本地过一遍）
bash verify-site.sh            # 只做静态部分（41 项，含 Release/tag 逻辑，几秒）
bash verify-site.sh --build    # 再加 ①~⑪ 的编译路径（共 150 项），和 CI 门禁完全同一条命令

# 查看线上状态
gh run list --repo tortrixx/slides
gh release list --repo tortrixx/slides
gh api repos/tortrixx/slides/releases --jq '.[].tag_name'
```

**本地预览首页**（模板 + 生成步骤）：

```bash
# 先按 docs/gate-design.md「手工核对流程」第 1 步把 workflow 脚本抽到 /tmp/wf-scripts，
# 再跑「生成导航页」那一步。
# **按内容挑，别认编号**：抽出来的文件叫 build-<下标>.sh，workflow 插一步就整体错位
# （编号会漂：2026-10-17 时导航页是 build-8.sh、编译步是 build-7.sh）。docs/gate-design.md
# 第 4 步就是这么要求的：
NAV="$(grep -l '<!--SLIDES-->' /tmp/wf-scripts/*.sh)"
RUNNER_TEMP=/tmp/rt BUILD_DIR=build RELEASE_TZ=Asia/Shanghai bash "$NAV"
# 注意 RUNNER_TEMP 目录得先 mkdir -p（脚本往那里写 slides-items.html）。
# 这一步已不需要 GITHUB_SHA（页脚不再显示提交号）。
# 然后用无头 Chrome 截图看效果。三个坑：
#   1) headless 的 prefers-color-scheme 跟随系统（本机实测过 dark 也实测过 light）——
#      想固定哪个主题，就在截图前注入 html.classList.add("dark")（页面自己的 JS 会按
#      matchMedia 覆盖 class，所以要放在 </body> 前）；
#   2) 入场动画带 fill-mode: both，t=0 时元素是 opacity:0 —— 截图前注入
#      .fade{animation:none;opacity:1}，否则截出一张空页（**不是**页面没渲染）；
#   3) **macOS 上无头 Chrome 的最小视口宽是 500px**：--window-size=390 实际按 500px 布局再
#      裁成 390px（看着像内容整体偏右，不是布局 bug）。窄屏只能验到 500px；
#      截图时 index.html 必须与 icon.png 同目录（页面用相对路径引用它）。
#      两条的完整说明见 docs/site-design.md 末尾。
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
  --user-data-dir=/tmp/cprof --window-size=1100,1250 \
  --screenshot=/tmp/shot.png file:///path/to/index.html
```

## 6. 改 workflow 后的验证清单（务必执行）

CI 逻辑全在 YAML 的 `run: |` 里（含 `.github/actions/` 下复合 action 里的 run 步骤），改完
不能只靠肉眼。**`verify-site.sh` 就是 CI 门禁本身**（`verify` job 跑 `--build`），本地可以先跑一遍再推：

```bash
bash verify-site.sh            # 静态检查 + Release/tag 逻辑（41 项，几秒，不需要 typst）
bash verify-site.sh --build    # 再加 ①~⑪ 的编译路径（共 150 项），和 CI 门禁完全同一条命令
```

当前基线：`--build` 全绿 = **150 项通过**（静态 41 + 编译路径 109）。每项的完整说明、对抗验证
记录与手工核对流程见 docs/gate-design.md，这里只留索引：

- ① 冷启动全量：产出 PDF 数、`.build-stamp`、首页卡片数、`icon.png` 进 `build/`、
  **「最近更新」标记数 = 套数（夹具里每套 deck 都被显式提交成「刚刚」）**、
  页脚时间戳已注入、三个占位注释（SLIDES/COUNT/META）在产物里零残留、
  **产物里的 HTML 注释成对 + 卡片在注释之外**（漏写 `-->` 或把注入点包进注释时，
  「卡片数」这条照样绿，但浏览器一张都看不到 —— 两种坏法要两条断言分别钉）
- ①b HTML 转义：标题含 `& < >` 的 deck，产物必须是实体、没有原始标签
- ①c `tools/deck-meta.py` 直接单测：字符串分支的内层 `]`（`数组 a[0] 的用法`）、**方括号分支
  的内层 `[ ]` 与转义 `\]`**、跨行 `[ … ]`、转义引号、整行 `//` 与**行尾 `//` 与 `/* */`
  块注释**里的 `title:` 必须跳过、`subtitle:` 不许被当成 `title:`、行序第一个 `title:` 优先
  （`#set document` 胜过更晚的 `#outline(title: [目录])`）、空值返回空串；
  **另有一条断言查「导航页步骤真的调用这个脚本」** —— 只单测脚本、却换回 shell 逐行解析时，
  上面那几条会全绿（2026-10-17 复核实测）
- ② 只改一个 deck 的增量；②b 非 ASCII 目录名的增量（钉住
  `core.quotePath=false`，背景见 docs/pitfalls.md）
- ③ 删除 deck 后清理残留 PDF；④ 编译失败必须 `exit 1`
- ⑤ 非法目录名必须 `exit 1`（空格 / 点号开头 / 含换行三种）；⑥ 一套都没有必须 `exit 1`
- ⑦ 导航页边界：读不到 `/Count` 不渲染页数项（读得到必须渲染）、残留文件清掉而
  `.build-stamp` 保留（根级残留图片**与残留子目录**都照清，白名单不许用 `*.png` 这类通配、
  也不许写回任何目录名 —— 夹具里放了 `build/stale-dir/old.png` 钉这一面）、`BUILD_DIR` 危险值全拒、正常值放行、
  **`RECENT_DAYS` 非 1–3650 的整数全拒（含空串与 `'14 days'`）**、
  **`RELEASE_TZ` 负例（`Not/AZone` / `Asia/Shangai` / `UTC+8` / `Asia` / `Etc` / `zone.tab` /
  `tzdata.zi`）全拒、`UTC` / `Asia/Shanghai` / 空串放行**、
  **`BUILD_DIR` 的最后一段必须叫 `build`**（`docs` / `.github` / `assets` / `slides/<deck>` 一律被拒，
  2026-10-17 复核实测它们会被导航页的 `rm -rf` 删掉内容），
  以及「导航页步骤本身见到 `main.typ` 也必须 `exit 1` 且**一个字节都不删**」这第二道防线
- ⑦b 页数取**页树根**：两个夹具 —— 「1 页 + 2 个 `=` 标题」必须显示「1 页」（挡住「取全文
  `/Count` 最大值」：大纲的 `/Count` 是标题数），「4 页 + 2 个标题」必须显示「4 页」（挡住
  「取最小值」那种写法；单个夹具挡不住，2026-10-17 复核指出）
- ②·2 job/step 级配置（YAML 结构断言，门禁以前完全看不到这一层）：verify job 必须跑
  `verify-site.sh --build`、`build` 必须 `needs: verify`、`verify`/`build`/`release`/**`deploy`**
  四个 job 都必须带 `github.event.deleted != true`、build 的 checkout 必须 `fetch-depth: 0`、
  四个 job 的 `runs-on` 都钉 `ubuntu-24.04`、每个 job 都有整数 `timeout-minutes`、
  build 有 `slides-build-<ref>` 的 concurrency 且 `cancel-in-progress`、deploy 的 permissions
  含 `pages: write` + `id-token: write`（2026-10-17 复核指出：这一层改坏原本**零断言**覆盖）
- ⑧/⑧b/⑧c Release/tag 逻辑（stub `gh`）：三种入口的 tag/managed、not found→`exists=false`、
  403 重试后 fail closed、旋钮防呆、机器标记决定 `ours`、说明里 tag 整体百分号编码且末尾带
  机器标记、「只更新附件」走 `gh release upload --clobber` 且无 PDF 必须 `exit 1`
- ⑨ 事件维度：stamp 失配 / `workflow_dispatch` / 非 main push → 全量重编；
  ⑨b 编译环境哈希必须覆盖 `setup-fonts` 复合 action（改字体 = 全量重编）；
  ⑨b' 指纹必须含**字体包版本**（`dpkg-query`）；⑨c **指纹失配**（stamp 里 wf_rev 对不上）
  必须退化成全量 —— 把 stamp 比较里 wf_rev 那一项整项删掉时，只有 ⑨c 会红
- ⑩ 列表顺序：最新在前、同日按名字升序、无日期排最后、日期不渲染进卡片区、
  **旧 deck / 取不到日期时不得出现「最近更新」标记**
- ⑪ 样式表花括号平衡（静态计数，统计前去掉注释）

**为什么这个门禁值得存在**：这些守的都是**静默失效**的不变量 —— stamp 基准错了会长期复用
旧 PDF、`core.quotePath` 会让中文名 deck 永不重编、护栏失效会做出坏链接、失败没 `exit 1`
会发布残缺站点、说明判断错了会覆盖用户手写内容。它们破了不报错，只是安静地出错，
所以必须靠真跑一遍来守。反过来，`bash -n` 那类静态检查当门禁是**零增量**（语法错 GitHub
起不来 job、运行时也立刻炸），所以门禁的价值全在真跑那部分 —— 但也别把静态部分写成假绿
（见下面 `bash -n` 那条）。

**门禁脚本自身的鲁棒性约定（`verify-site.sh`）**：
- **依赖前置检查**：脚本开头先查 `ruby` / `python3` / `git`（`--build` 加查 `typst` / `strings`），
  缺了直接 FAIL 并指明缺什么 —— 否则只会得到 exit 127 或 YAML 读空后的连环假红。
- **不写死 workflow 的 `env:` 值**，改成从 YAML 读 `TYPST_VERSION` / `BUILD_DIR` / `RELEASE_TZ`。
  写死过 `TYPST_VERSION`，后果实测很严重：workflow 一升级版本号，脚本造的 stamp 里的版本就和
  真正会写的那份不一致 → 走进「编译环境变了 → 全量」分支 → ②③ 的增量断言全挂。
  实测对比（把 workflow 的版本改成 9.9.9）：**写死版 2 通过 / 17 失败（exit 127）**，
  读 env 版 **19 通过 / 0 失败**（当时还没加 env 断言，现在是 150 项）。这类假红比漏报更糟 —— 它会诱使人把测试改松。
- **typst 包缓存要显式指定**：脚本默认 `TYPST_PACKAGE_CACHE_PATH="$TMP/typst-pkg"`
  （外部设了就尊重外部值）。typst 默认写 `$HOME`，HOME 不可写时每套 deck 都会报
  `failed to create temporary package directory` —— 看起来像 deck 坏了，是典型假红
  （本机沙箱就踩过：不设这个变量 12 通过 / 11 失败，设了才全绿）。CI 的 verify job 会把它
  显式指到 setup-typst 恢复的缓存目录（`$XDG_CACHE_HOME/typst/packages`），让门禁的夹具
  编译复用 @preview 包缓存；本地默认仍是每次运行的独立临时目录。
- **夹具先做一次快照提交**：`fresh()` 复制完仓库会 `git add -A && commit` 一次。原因是工作树里
  未提交的改动（比如刚 `cp -R` 出来的新 deck）不在 `git diff <基准> HEAD` 里，会让 ② 的
  「复用 N-1」断言假红 —— 本地开发时几乎必然命中。
- **夹具还要「让每套 deck 都刚刚提交过」**（`fresh()` 里紧接着的一步：给每个 `slides/*/main.typ`
  追加一行注释并提交）。这是 ①「最近更新标记数 = 套数」的前提，**不能靠真实历史**：上面那次
  快照提交在**干净工作树**（＝CI 检出的状态）上是空操作（`nothing to commit`，被 `|| true` 吞掉），
  夹具于是继承真实提交日期 → 某套 deck 超过 RECENT_DAYS 没动过的那天起 ① 突然变红 → verify 失败
  → `build: needs: verify` 把部署与发版一起卡死（独立复核实测：所有 deck 改成 20–25 天前、
  工作树干净 → 期望 [2] 实际 [0]，98 通过 / 1 失败；补上后 109 通过 / 0 失败）。
  **任何「夹具依赖当前时间/真实历史」的断言都要先想这件事**（完整记录见 docs/gate-design.md）。
- **每次运行用独立临时目录**（`TMP="$(mktemp -d …)"` + `trap` 清理），不再写死 `/tmp/slides-verify`：
  写死时两个并发运行（本地跑一遍的同时另一个 agent 也在跑、或 CI 与本地同时跑）会互相
  `rm -rf` 掉对方的 `$TMP`，症状是后面莫名其妙的 `exit 127`、断言乱飞 —— 本轮真踩过，
  而且当时误以为是代码坏了。trap 仍负责清理。
- **期望套数从夹具推导，不写死**：`n_decks` 由 `$R/slides/*/main.typ` 数出来，①③ 的数量断言
  和 ② 的复用套数都用它。写死过 `2`／`1`，而 §1 承诺「`cp -R slides/template slides/my-talk`
  后 push 即可」—— 加第三套 slide 的那次 push 会让门禁假红，进而 `needs: verify` 把部署和发版
  全卡死（正是上面警告的「假红诱使人把测试改松」）。
- **要跑的步骤脚本按内容签名定位，不认文件名里的下标**：抽取出来的文件叫 `build-<下标>.sh`，
  workflow 插一步就整体错位，而错位最坏的结果是**静默测错步骤**（拿生成导航页的脚本验护栏会
  永远通过）。现在直接扫 `$TMP/scripts/*.sh`，按内容挑：含 `typst compile` 的是编译步、
  含 `<!--SLIDES-->` 的是导航页、含 `managed=true` 的是计算 tag、含 `release-notes.md` 的是写说明；
  一个都找不到就立刻 `bad` + `exit 1`。加/删步骤不需要改门禁。
- **复合 action 的 run 步骤也要抽出来检查**：抽取时一并扫 `.github/actions/*/action.yml`
  （存成 `action-<名>-<下标>.sh`），否则 `bash -n` 与多字节 lint 都覆盖不到它 —— 装字体逻辑
  2026-10 抽成复合 action 后这条就是必须的，漏抽 = 那个文件从此不受任何静态检查。
- **编译环境哈希用 `wf_rev_of()`，与 workflow 同算法**（workflow、
  `.github/actions/setup-fonts/action.yml`、**以及 `dpkg-query` 报出的字体包版本**三者一起哈希）。
  抽复合 action 时最容易漏这处：只哈希 workflow 的话，改字体不会触发全量重编 ——
  正是 stamp 要防的静默失效，门禁 ⑨b 钉住；漏掉字体版本则由 ⑨b' 钉住。改这个算法时
  **两边必须同时改**（门禁的 `wf_rev_of()` 与编译步那段），否则 ②⑨ 会走进「环境变了 → 全量」而假红。
- **多字节 lint 也扫门禁自己**（`verify-site.sh`）：以前只扫抽出来的 workflow 脚本，于是门禁
  自己踩了同一个坑却没人拦 —— 2026-10-17 我在 ③ 里写了 `chk "…（$survivor）"`，bash 3.2 把
  `）` 当成变量名的一部分，直接 `survivor）: unbound variable` 中断整次运行（GNU bash 5 上
  不复现，所以 CI 也发现不了）；改成扫自己之后，它又当场揪出 306 行那条一直存在的
  `bad "没找到 $dep，…"`。**整行注释不算**（注释不参与参数展开），不然说明文字会被判红。
- **`bash -n` 必须逐个文件跑**：`bash -n f1 f2 f3` 只把**第一个**当脚本、其余当位置参数，
  第二个文件语法坏了它照样报「全部通过」（对抗复核实测）。现在是循环 + 计数。
- **抓预期失败的退出码用 `capture`（`if out=$(…); then rc=0; else rc=$?; fi`）**，不要写
  `out="$(…)"; rc=$?`：门禁若被外人用 `bash -e verify-site.sh` 跑，后者会在第一个期望非零的
  断言处直接退出、连 FAIL 和汇总都印不出来。
- **CI 与本地仍有一个已知差异**：CI 的 `run:` 由 runner 以带 `-e` 的 shell 启动，而门禁用
  `bash <脚本>`（不继承 `-e`）。所以脚本里任何「失败又没被 `|| true`/`if`/`case` 包住」的命令，
  CI 会立刻中止而门禁会继续 —— 这类命令要当成「必须有兜底」来写（`wf_rev` 那处就是这么踩的：
  `2>/dev/null` 本意是容忍失败，实际在 CI 上会静默中止整步）。
- 顺带：脚本里所有夹具提交都走 `gitc()`（`git -c commit.gpgsign=false -c user.email=… -c user.name=… commit`），
  既不依赖 runner 上有 git 身份配置，也不怕开发机全局开了 `commit.gpgsign`（很常见的配置）——
  开了签名时夹具的 `commit` 会 rc=128 失败、被 `|| true` 吞掉，于是夹具 HEAD 不前进，
  ①（圆点=套数）、②（复用 N-1）、②b、⑩ 一起假红，报错还分别指向 `core.quotePath`、
  排序键这些**完全无关**的子系统（实测：全局 gpgsign 下 93 通过 / 5 失败）。
  `fresh()` 里另外显式比较了「刚刚提交」前后的 HEAD，没前进就当场 `bad`，把原因指到夹具初始化上。
- **夹具里不要写死某套 deck 的名字**（同一个教训的第三次）：③ 的「其余 PDF 保留」曾经写死
  `26-09-30`、④ 曾经往 `slides/26-09-30/main.typ` 写坏内容，作者哪天把日期型 deck 改名/归档
  （§3.8：改名等于换 URL）就会打出 3 条假红 FAIL，报错分别指向清理逻辑与编译失败检测。
  现在 ③ 的幸存者从夹具动态取、④ 用夹具自己合成的坏 deck。

**门禁的结构约束（别改坏）**：
- 必须是**独立 job**。塞进 `build` 的步骤里有坑：`build` 最后会写 `.build-stamp`，
  如果顺序成了「编译 → 写 stamp → 门禁失败」，stamp 已落盘，下次 push 会以为编译过了而
  跳过重编 —— 门禁反而制造了它本该防的那种不一致。
- `build` 靠 `needs: verify` 依赖它，所以门禁红了站点和 Release 都不会动（fail closed）。
- 门禁会自己触发全量重编：workflow 文件哈希进了 stamp，所以**改 workflow 必然全量编译**，
  而门禁自己会把编译步真跑 **18 次**（每次编夹具里的若干套，见 `grep -c 'run_compile ' verify-site.sh`；2026-10-17 加 ⑦b 页数夹具后 16 → 18）。
  这个成本只落在「改了 workflow」的 push 上，日常改 deck 不受影响。
- 门禁 job 也装了字体（和 build 用**同一个复合 action** `setup-fonts`）。脚本要真编译含中文的
  deck，字体齐全才能保证不因环境差异假红。注意 **`--font-path` 是追加、不是限制**（实测带空
  目录时字体数不变：394 → 394），所以没法用它模拟「没装字体」来验证这件事。

手工核对流程（不用脚本、手工逐步验证 CI 的做法）与每个检查项的完整说明见 docs/gate-design.md。

## 7. 值得注意的坑（已踩过）

完整清单在 **docs/pitfalls.md**（每条都附实测现象与修法，多数已被门禁的对应断言钉住）。
这些坑的共同点是不会报错、只会安静地出错，改 CI 脚本前最值得先过一遍的几条：

- `git diff` 默认转义非 ASCII 路径（`core.quotePath`）—— 拿 git 输出做路径比较前先想这件事；
- `pipefail` 下「大数据 `| grep -q`」会 EPIPE 反转结果 —— 用 here-string；
- 命令替换里的管道失败在 `set -e` 下会终止整步 —— 「容忍失败」要显式写 `|| true`；
- `slides/*/` 通配不到点号开头的目录；`basename` 会吃掉结尾换行；`"$BUILD_DIR"/*` 空值展开成 `/*`；
- CI 的 run 块带 `-e`、本地门禁不带 —— 「本地是好的」不等于「CI 上是好的」；
- `actions/cache` 步骤上的 `if:` 会被忽略（官方不支持），别指望它拦住什么；
- 每个文件末尾的「仓库级标记」注释是纯装饰，别删。

## 8. 可能的后续改进

- ~~缓存 `@preview` 宏包~~（2026-10-11 已做：两个 job 都把 `cache-dependency-path` 指向构建时
  聚合出的 `preview-deps.typ`；verify job 里门禁通过显式设置 `TYPST_PACKAGE_CACHE_PATH`
  复用同一份缓存）。
- ~~首页封面预览~~（2026-10-17 当天加、当天撤：先是行首 96×54 缩略图，后改卡片网格 + 大封面，
  用户最终选择纯列表 —— 缩略图在列表尺寸下不传递信息，放大到能读又得放弃列表。封面生成、
  `covers/` 白名单、门禁里 5 条封面断言全部删净；完整推演见 docs/site-design.md）。
  还想要的**每套 deck 自定义描述**仍未做：现在的描述行
  直接取 `subtitle`，想让它和封面页的副标题分开，得在 workflow 里另加一个字段（A4 文档
  用不了 `subtitle:`，见 §3.9）。
- **同一 ref 上「旧运行后到」的并发乱序**（2026-10-17 复核记录，**尚未修**）：`build` 的
  `slides-build-${ref}` + `cancel-in-progress` 只保证「不并发」且能取消**正在跑**的那次，
  但当**旧提交那次运行更慢**时，是它**后**进入 concurrency 组、于是取消掉新提交的运行，
  最后 deploy/release 用的是**更旧的**提交（站点与当天 Release 被刷回旧版本）。
  历史 61 次运行从未触发（0 次 cancelled、无时间重叠），窗口很窄（两次 push 相隔 ≲1 分钟
  且旧那次的 verify 明显更慢），而且下一次 push 会自愈，所以**没有在本轮盲改** —— 修法涉及
  deploy/release 路径、本地无法端到端验证，改了反而可能引入更糟的失败。候选修法（待验证）：
  把并发组提到 **workflow 级**（`group: ${{ github.workflow }}-${{ github.ref }}` +
  `cancel-in-progress: true`，组在派发时就进入，顺序因此单调），副作用是 `release: published`
  与同 tag 的 push 事件共用 `github.ref`、会互相取消一次（两者做的事基本相同，但要写进注释）。
- **首页的规模化改造**（2026-10-17 明确暂缓，等 deck 数涨上来再说，触发条件 ≈15 套）：
  按年/主题分组（组标题用 `h2`）、客户端搜索/过滤框（会引入 JS，与「无 JS 也能看」的现状冲突）、
  Atom 订阅（现在 Releases 页面已经能订阅，属重复建设）。现在只有 2 套，做了都是装饰。
- 分享卡片：`<meta name="twitter:card">` 目前是 `summary`（没有配图）。想升级成
  `summary_large_image` 需要一张 1200×630 的 `assets/og.png` + 绝对 URL 的 `og:image`，
  并且要改 workflow 的静态资源拷贝（现在是写死的 `cp assets/icon.png` + fail-closed 检查）。
- `fonts-noto-cjk-extra` 需要时加回即可（换更多中文字重）。
- 代码字体目前只装 **Regular**（和作者本机 `~/Library/Fonts/` 里那一份一致）。若以后要用粗体代码，
  在复合 action 的 `unzip` 成员里加上 `MapleMonoNormal-NF-CN-Bold.ttf`、并在 workflow 顶部 `env:`
  补一个对应的 TTF sha256（zip 的哈希不变）；只加文件不补哈希会让「只校验 Regular」这件事悄悄漏掉。
- 代码字体依赖上游 Release 的固定版本资产。zip 已有 `actions/cache` 兜底（key = sha256，命中也
  重新校验），上游短暂不可达能顶住；万一上游真删了 `v7.9` 且缓存过期，出路是把那份 TTF
  （约 20MB）自持进仓库、改成从本地拷贝，`env:` 里的 TTF sha256 原样留着继续校验。
- 存储会随「每天一个 Release」线性增长：每次 Release 都保存一套完整 PDF 且不会自动清理。
  公开仓库的 Actions 存储免费，所以这是「慢」而不是「贵」的问题；真开始嫌大时，可以只上传
  本次重编的 PDF，或定期 `gh release delete --cleanup-tag` 清掉旧的日期版本。
- `setup-typst@v5` 与 `softprops/action-gh-release@v3` 目前按主版本号引用（可读性好、自动收补丁）。
  若要更强的供应链保证，可以把这两个第三方 action 固定到 commit SHA，并让 Dependabot 升级。
- 首页的标题层级：全页**只有**一个 `h1`（顶栏里的 `Slides`，`.page-title`），没有标语、没有区块 `h2`
  （见 docs/site-design.md）；以后若分组，组标题用 `h2`。**改动时别把唯一的 h1 弄丢**。

<!-- tortrixx/slides · 仓库约定见 AGENTS.md -->

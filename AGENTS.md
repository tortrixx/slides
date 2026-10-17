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
├── assets/
│   └── icon.png              # 站点静态资源（左上角头像），构建时拷进 build/
├── docs/                     # 设计依据与踩坑史（site-design / gate-design / pitfalls）
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
| `deploy` | `refs/heads/main` 的 push 或手动 | `pages: write`, `id-token: write` | `actions/deploy-pages` 发布 `build/` |
| `release` | main push / 推送 tag / release 事件 | `contents: write` | 计算 tag → 写说明 → 建/更新 Release |

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
进而改变 PDF 排版，而 workflow 文件哈希不会因此变化 —— 那就会「部分 deck 用旧镜像的字体、
部分用新镜像」，且不会触发全量重编。钉住后想换镜像是显式动作（同时记得删
`slides-build-main-*` 缓存强制全量）。


### build 细节

- **字体**（verify 与 build 共用同一个复合 action `.github/actions/setup-fonts`；三个字族各一套
  来源，装完统一 fail closed）：
  - **中文 / 西文**：`apt-get install fonts-noto-cjk fonts-inter`（取不到时降级为只装 CJK）。
    故意**不装** `fonts-noto-cjk-extra`（多 145MB），代价是 `weight: "medium"` 之类中间字重回退。
  - **代码字体（`#show raw`）**：Ubuntu 源里没有 Maple Mono，所以从上游 Release **固定版本下载**：
    `MAPLE_MONO_VERSION`（当前 `v7.9`）+ zip 与解出的 TTF 两个 sha256，全在 workflow 顶部 `env:` 里。
    zip 由 job 层的 `actions/cache` 缓存（key = zip 的 sha256）；**缓存命中也照跑 sha256 校验** ——
    上游换包 / 下载被劫持 / 缓存被污染都直接红，不会静默换字体。
    只解压并安装 **Regular** 一个权重 —— 和作者本机 `~/Library/Fonts/` 里那一份完全一致
    （v7.9 的 `MapleMonoNormal-NF-CN-Regular.ttf`，sha256 已核对相同）。
  - **装完的断言（这一步才是关键）**：`typst fonts` 里必须同时出现 `Inter` / `Noto Sans CJK SC` /
    `Maple Mono Normal NF`，缺一个就 `::error::` + `exit 1`。为什么必须显式断言：**缺字体时 Typst
    不报错**，只是按字形静默回退（中文掉方块、代码掉 DejaVu），PDF 照样编得出来、CI 全绿 ——
    这正是这次改动要根治的那种静默失效。
  - **断言写 `Maple Mono Normal NF`，不是字体 name 表里的 `Maple Mono Normal NF CN`**：Typst 的
    `FontInfo` 用 `typographic_family()` 把 family 末尾的风格词当后缀剥掉
    （`crates/typst-library/src/text/font/info.rs`，SUFFIXES 里含 `cn`、`normal`、`cond`、`vf` 等），
    系统字体与 `--font-path` 两条路径都走这段代码、跨平台结果一致 —— 按 name 表原文断言会假红。
    （同一个机制也让 macOS 上 `typst fonts` 显示的是 `Maple Mono Normal NF`。）
  - **改字体 = 全量重编**：复合 action 文件的哈希与 workflow 的哈希一起进了 `.build-stamp` 的
    「编译环境指纹」（见下条），改任何一个都会让旧 stamp 失配。门禁 ⑨b 钉着这一点。
- **增量编译**：`actions/cache@v6` 以 `slides-build-main-<run_id>` 为 key、`slides-build-main-`
  为 restore-keys 缓存 `build/`。逐套判断：全量 / 缓存缺 PDF / 该目录相对**基准提交**有改动 → 重编。
  最后清理「`slides/<名称>/main.typ` 已不存在」的残留 PDF。
  **不再有封面图这一步**（2026-10-17 加过、当天撤掉）：编译步只产 PDF，`build/` 里除了
  `*.pdf`、`index.html`、`.build-stamp` 不该有别的东西。历史与理由见 docs/site-design.md。
  基准**不是** `github.event.before`，而是缓存目录里 `.build-stamp` 记的**上一次真正编译成功的提交**：
  ```
  <sha> <TYPST_VERSION> <编译环境指纹>
  ```
  编译环境指纹 = workflow 文件与 `.github/actions/setup-fonts/action.yml` 两个文件的哈希再哈希
  （装字体逻辑 2026-10 抽成了复合 action；只哈希 workflow 的话，改字体不会触发全量重编 ——
  那正是 stamp 要防的静默失效，门禁 ⑨b 钉住）。
  为什么不用 `before`：它只覆盖本次 push。若上一次运行失败（缓存没存下）或两次 push 挨得很近，
  那一次改过的 deck 就既不在 diff 里、缓存里又是旧 PDF，会被**永久复用成旧版本**且不会自愈
  （已实测复现，两份独立审查也都指出过）。用 stamp 作基准，差异永远是「相对上次成功编译」，
  而编译失败时不会写 stamp，所以失败的下一次 push 必然把那些 deck 重新编译一遍。
  另两个字段用来在**编译环境变化**（Typst 版本、workflow 与字体 action 里的编译参数）时强制全量。
  stamp 是 `build/` 里的隐藏文件：只进 patch 缓存，不进 artifact、不进 Pages。
  这一条核对过 action 源码（2026-10）：`upload-pages-artifact@v5` 的 `include-hidden-files`
  默认 `false`，打包时会加 `--exclude=.[^/]*`；`upload-artifact@v7` 同样默认不收隐藏文件。
  所以 `.build-stamp` 不会出现在站点上，也不会进 Release 附件（release 那边另有
  `files: build/*.pdf` 兜底）。**别把它改成非隐藏文件名**，否则会被发布出去。
  tag / release / PR / 手动运行一律全量编译。
- **构建环境校验（写文件之前第一步）**：`BUILD_DIR` 归一化（折叠 `//`、去掉开头 `./` 与结尾 `/`）后
  必须是仓库内的相对目录名，且只含 `A-Za-z0-9._-/`；`TYPST_VERSION` 不能为空；`RELEASE_TZ` 必须能被
  `date` 解析。为什么非要这一步：后面几段脚本按 `"$BUILD_DIR"/*` 遍历并 `rm -rf`，**`BUILD_DIR` 为空时
  通配符会展开成 `/*`**（实测会枚举 `/Applications`、`/Library`…），而 `'./'` 又等价于 `.`
  —— 清理会把整个工作树删掉。空值/`/`/`.`/`..`/绝对路径/含 `..`/含空格等一律 `::error::` + `exit 1`。
  这一步刻意放在装字体、恢复缓存**之前**（配错了 5 秒内就红，也不会先恢复一份缓存再失败）。
  同一处还校验 **`RECENT_DAYS` 必须是 1–3650 的整数**（`${RECENT_DAYS-3}`：未设置兜底 3、
  显式空串报错）。值写错时 `git log --since` **不报错**、只是圆点一个都不出现而 CI 全绿
  （实测 `'abc'` → 0 个圆点、rc=0）；门禁 ⑦ 对 `''/'abc'/'0'/'-3'/'14 days'/'99999'` 全拒。
- **幻灯片目录名的另外两个护栏**（§3.8 只管字符集）：
  - **点号开头**（`slides/.hidden`）：`for dir in slides/*/` 根本匹配不到它，会静默不编译、不出卡片，
    而只要还有别的 deck 就 `exit 0` —— 站点永远少一套。所以单独扫 `slides/.[!.]*/`、`slides/..?*/`
    报错（宁可让人改名）。
  - **含换行/回车**：`basename` 会把尾部换行吃掉，两个不同目录会落到同一个 `<名称>.pdf` 上互相覆盖。
    按 `$dir` 的原始字节先拦掉。
- **导航页**：`index.template.html` 是首页模板（版式/样式都在里面），workflow 只负责
  注入数据，产物 `build/index.html` 是**服务端渲染**的静态页（无 JS 也能看）。
  三处占位注释由 `awk` 替换：`SLIDES`（卡片列表）、`COUNT`（套数）、`META`（页脚的「更新于 …」时间戳）。
  **`awk` 是按行替换的，不认 HTML 注释** —— 所以**绝不要在模板（或任何会被喂给那段 awk 的文件）里
  写出占位符的原文**：写了 `SLIDES` 那处的原文，整行会被换成卡片列表并塞在注释中间；写了 `COUNT`
  那处的原文，它会就地变成数字。这不是推演：模板开头的注释里最早写过 `COUNT` 的原文，
  构建产物里那句真的成了「注意 2 现在模板里没有用了」（2026-10 实测）。
  现在模板里提到它们只写名字，原文只出现在两处真正的注入点（`SLIDES` 与 `META`）；
  **`COUNT` 目前模板里没有用到**（标题旁的套数已按用户要求去掉，理由见 docs/site-design.md），
  但 workflow 的替换规则留着 —— 想恢复套数显示只需改模板，不用碰 YAML。
  页脚**只放「更新于 …」这个时间戳**。时间戳那句「本页由 GitHub Actions 自动生成」说的是构建过程、
  不是页面内容，已删（与早先删掉 "Built by Typst & Touying." 同理）；提交号也一并不显示了 ——
  它是构建提交，跟某套幻灯片最后一次改动无关，容易被误读。
  **2026-10-17 删掉过页脚里的「全部 PDF」链接**（当时指向 `releases/latest`）：用户要求去掉，
  理由是顶栏右上角已经有 GitHub 图标、进仓库就能看到 Releases，页脚再来一个是重复入口。
  连带把门禁 ① 里那条「页脚必须有 releases/latest 链接」的断言一起删了（109 → 108 项）；
  **别再把它加回来**。若以后真往页脚塞 HTML，注意 `awk` 的 `sub()` 替换串里 `&` 表示
  「匹配到的文本」，文案里不能出现 `&`（要写就写 `\&`）。
  - **顺序＝最新在前**：先按 `git log -1 --format=%cs -- "slides/<名>/"` 取每套 deck **最后一次
    提交的日期**，`LC_ALL=C sort -t $'\t' -k1,1r -k2,2` 排序（日期倒序、同一天按文件夹名升序），
    取不到日期（浅克隆 / 从未提交）的排最后。**不要退回 `for dir in slides/*/`**：那是 bash 的
    glob 顺序 =「当前 locale 的字典序」，跟改没改无关，而且中文名的先后会随 runner 的 locale 变
    （实测同一组名字：C.UTF-8 把中文排最后、en_US.UTF-8 排最前、zh_CN.UTF-8 又排最后）。
    日期**只用于排序、不渲染到页面**（那一列已经去掉了，原因见 docs/site-design.md）。
    两个实现坑（都踩过并写进了门禁）：① 空日期不能直接写进 TSV —— `read` 会吃掉行首的 IFS 空白，
    文件名会被读进日期字段、整行错位；脚本里把它换成 `0000-00-00` 占位、循环里再换回空串。
    ② `[ "$d" = "x" ] && x=""` 这种一行写法在 `set -e` 下会留下非零退出码，落在脚本末尾会把
    整步判成失败，所以写成正常的 `if`。
    ③ **`count` 必须显式兜底**：卡片循环读的是 process substitution（`done < <(sort …)`），
    而它的退出码**不参与** `set -e` / `pipefail` —— sort 一旦失败（命令没了、文件读不了、参数
    写错），while 读到 0 行、脚本照样走完并 `exit 0`，首页变成一个列表都没有而 CI 全绿
    （实测：把 sort 换成不存在的命令，输出「已生成 build/index.html（0 套幻灯片）」、rc=0）。
    所以循环后显式判 `count -eq 0` 就 `::error::` + `exit 1`（能走到那里就必然有 deck，
    前面「编译」那步已经保证"一套都没有"时 fail closed）。
    日期取自 git，所以 checkout 的 `fetch-depth: 0`（增量编译本来就需要）不能去掉。
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
  - **卡片副信息行**：`<页数> 页 · <大小> · <文件名>.pdf`（一行淡色文字，分隔点由 CSS 生成）。
    前两项在 workflow 里仍写作 `<span class="badge">`，但**CSS 里已经没有胶囊样式了**（见 docs/site-design.md）。
    页数从 PDF 页树根节点的 `/Count` 取（`strings | grep -o '/Count [0-9]\{1,4\}'`
    取最大值；Typst 产出的 PDF 未压缩所以读得到，已核对 49/20 与逐页渲染数一致）。
    **原来看起来多余的 `PDF` 徽章已去掉**——链接本身就是 `.pdf`、点了就是打开 PDF，
    文件名里又写了一遍，三处重复；换成页数更有信息量。若哪天读不到 `/Count`（例如 PDF 开始
    压缩），**那一枚整枚都不渲染**（不会留下一个只有「页」字的空项），所以这个取法不会给出错的信息。
    门禁同时钉了两面：读不到时不许出现「N 页」，正常 PDF 必须出现「N 页」。
  - **转义**：文件夹名与标题/副标题都会做 HTML 转义（`&` `<` `>` `"`），
    文件夹名另有字符集护栏（见 §3.8），两道一起保证生成的 HTML 不会被名字搞坏。
  - **「最近更新」小圆点**：最近 `RECENT_DAYS`（workflow 顶部 `env:`，当前 3）天内提交过的
    deck，标题后加 `<span class="dot">` + `<span class="sr-only">最近更新</span>`。判定用
    `git log -1 --since="… days ago"`（**交给 git 做相对时间**，BSD/GNU 的 `date -d` 不通用）；
    **取不到提交日期时不标记**（fail safe）—— 否则浅克隆/无历史的环境会把每行都标成「最近更新」。
    门禁两面都钉：① 夹具里每套 deck 都被 `fresh()` 显式提交成「刚刚」，所以必须有；
    ⑩ 那个夹具是 2020/2026-01 的老提交 + 一套从未提交的，必须一个都没有。
    实现坑：`.deck-title` 是 inline-flex，**flex item 之间的空白会被忽略**，所以 `.dot` 得自带
    `margin-left`，靠换行分不开。
  - 标题按**原文**显示：Typst 标记（`*粗体*`、反引号）不会被渲染，也不会被剥离。
- **站点静态资源（`assets/`）**：Pages 只发布 `build/`，所以仓库里的静态文件由「生成导航页」
  那步开头拷进站点根目录（现在只有 `assets/icon.png`，即左上角头像；模板里写 `src="icon.png"`）。
  文件缺失是 `::error::` + 退出，**故意 fail closed**：页面不会因此报错，只是 `img` 被
  `onerror` 静默删掉，不失败的话很难发现。`verify-site.sh` 里钉了一条产物断言。
  拷之前先清掉 `build/` 里「非 `*.pdf`、非 `index.html`、非 `.build-stamp`」的旧文件
  （三个通配符 `*` / `.[!.]*` / `..?*` 一起覆盖普通文件与隐藏文件；`.build-stamp` 是增量基准，
  必须留下）：`build/` 是 `actions/cache` 的缓存对象，
  只清 PDF 的话，某个版本拷进来、后来不再拷的
  静态资源会被缓存**永久**带下去，并随两份 artifact 一起发布到站点根目录，自愈不了
  （本地 `build/` 里就躺过 `avatar-*.png` 这种中间态残留）。
  **白名单只有那三项，别用 `*.png` 之类的通配**：写成通配会把「根级残留文件也要清掉」这条
  一起废掉，门禁 ⑦ 用 `build/avatar-old.png` 钉着这一面。（2026-10-17 封面功能短暂存在时这里
  加过 `covers` 目录白名单，功能撤掉后白名单也一起收回了。）
  头像原来写的是 `https://github.com/tortrixx.png`，为什么换掉（2026-10 实测）：
  - 那是**全页唯一的跨站请求**（其余 CSS/JS/图标全是内联的），所以必然最后出现；
  - 它会 **302** 到 `avatars.githubusercontent.com`，多一次 DNS + TLS，实测 1.84s 才拿到图；
    而且这个 302 带 `cache-control: no-cache`，**每次打开都要重走一遍**（图的 `max-age=300`
    只能省掉第二步）；
  - 抓回来的是 **460×460 / 38 KB**，而（当时）页面只用 80px 显示（`?size=160` 才是 12 KB）；
  - 国内网络下 `avatars.githubusercontent.com` 还常慢/不可达（那 `onerror` 会把图整个删掉）。
  现在用仓库内 160×160（2× DPR）PNG，15.9 KB，同源、可长期缓存、零外部依赖。
  **换图直接替换 `assets/icon.png` 即可**，别改回外链。
- **站点视觉与前端（细则与踩坑史见 docs/site-design.md）**：改样式只动 `index.template.html`，
  不用碰 workflow。动手前必须知道的现行约定（每条都在 docs/site-design.md 里有实测依据，
  多数是否决过替代方案才定下来的）：
  - `<meta charset>` 必须留在文件最前面（1024 字节编码探测窗口），中文注释不许挪到它前面；
  - 全页**只有一个 h1**（顶栏 `.page-title`），没有标语、没有区块 h2、标题旁无套数胶囊；
  - **顶栏一行到底**（头像 + h1 + 右上角按钮，2026-10 改）：窄屏只是把头像收到 48px、
    标题收到 1.25rem，**不再纵向堆叠**。改之前窄屏 `.head-row` 高 176.4px（`.spacer{flex:1}`
    在 column 方向也参与分配），第一张卡片被压到 y=220；现在同条件 62px、卡片从 y=98 开始。
    `.avatar` 的 CSS 分两档（48/64），`<img>` 上的 `width/height="64"` 是无 CSS 时的兜底；
  - 版式是**纯列表**：一行一套，行内标题/副标题/元信息，行间一条两端渐隐的细线。
    2026-10-17 试过两种带封面的版式（行首 96×54 缩略图、卡片网格 + 大封面），**当天全撤**，
    回到这里 —— 缩略图在列表尺寸下不传递信息，放大到能读又必须放弃列表；详见 docs/site-design.md；
  - 标题后的 **`.dot`** 是「最近更新」小圆点（纯装饰 + 紧随其后的 `.sr-only` 文本承担语义）；
  - 字重写 `500`（意图 medium），**别写 600**（本字体栈里 600 就是 bold）；层级靠字号 + 颜色承担；
  - 行分隔线是 `.deck + .deck::before` 伪元素画的**两端渐隐**细线（页眉线是 2px 通栏实线，
    两条线"重量"必须不同）—— **别改回 `border-top`**（圆角会拐弯、渐变画不进 border）；
  - 整行可点用 stretched-link（`.deck-title::after` 伪元素铺满整行），不要再往行里加第二个
    链接/按钮；日期只用于构建时排序、**不渲染**到页面；
  - 主题是三态循环 auto/light/dark，应用时必须判断模式
    （`apply(mode === "auto" ? query.matches : mode === "dark")`，照抄 `apply(query.matches)`
    会把手动固定覆盖掉）；图标显隐用「默认全隐藏 + 按 data-mode 打开一个」的写法；
  - 装饰性 SVG 一律 `aria-hidden="true"`；动效保留 `@supports` 与 `prefers-reduced-motion` 降级；
  - 背景设在 `html` 上；`body` 上**不能再写 background**（会盖住 `z-index:-1` 的 `.bg-grid`）；
  - 页脚由 `body` 的 flex 布局 + `main` 的 `flex:1` 压到页面底部，不用 `position: fixed`。
- **产物**：`slides-build`（普通 artifact，给 release job 下载，`retention-days: 3`）+
  `github-pages`（`actions/upload-pages-artifact@v5`，给 deploy job，自带 1 天保留期）。
  两份都只在同一次运行内使用，所以保留期压得很短，避免长期堆积；留 3 天是为了隔天
  「Re-run failed jobs」时还取得到产物。`index.template.html` 在仓库根，不会进站点
  （只上传 `build/`）。

### release 细节

- tag 规则（「计算 tag」步骤的 else 分支）：
  `tag="v$(TZ="${RELEASE_TZ}" date +%Y.%m.%d)"`，`RELEASE_TZ` 默认 `Asia/Shanghai`。
- **说明「是不是我们写的」由 body 里的机器标记决定，不再只看 managed**：自动生成的说明末尾有一行
  `<!-- ci-managed -->`（渲染后不可见）。`gh release view --json body` 读回来带这个标记 → `ours=true`，
  才允许重写说明；没标记（用户手写、或旧版工作流建的）→ **只覆盖同名附件，一个字都不动**。
  三条步骤条件是完整划分：`exists=false || ours=true` → 生成说明 + 发布（带 body）；
  `exists=true && ours!=true` → **只更新附件**。
  为什么用标记而不是只看 managed：原来的条件是「managed=true 就刷说明」，而 managed 只看
  「这次是不是 main push」—— 用户手动建/手改了当天日期 Release 的说明后，同一天再 push 就会
  把他的说明整段盖掉（不可恢复）。
  最后那条路径**刻意不用 softprops、改用 `gh release upload --clobber`**：softprops 的更新路径
  会 PATCH 整个 release，**实测在本仓库返回 `403 Resource not accessible by integration`**
  （同一个 job、同一个 token 上传附件却是成功的，2026-10-01 的运行日志有据），而 gh 只动附件、
  天然不碰 body —— 语义上正是我们要的，也不会因为一次无关的 PATCH 让发版失败。
  **一次性副作用**：改造前建的 Release body 里没有标记，所以它们不会再有说明刷新（附件照常更新）；
  跨天新建的 Release 就正常了。
- `exists` / `ours` 用 `gh release view <tag> --json body` 一次拿到，但**只有明确报
  `not found` / `HTTP 404` 才判 false**：403 限流 / 5xx / 网络错误先按瞬时故障退避重试
  （默认 3 次、5 秒起，可用 `RELEASE_VIEW_RETRIES` / `RELEASE_VIEW_BACKOFF` 调；门禁里设 2/0 保持秒级），
  重试仍失败才 `::error::` 退出。把「查不到」当成「不存在」，会让已存在的 Release 被当成新建、
  连带覆盖说明。旋钮值非法时回退默认值 —— 曾经的 `for x in $(seq 1 "$retries")` 在 GNU 下遇到
  非数字会「循环零次」，静默退化成 `exists=false`（本机 BSD 反而跑一次，行为还分叉）。
- Release 说明里的 tag 片段用 `python3 -c 'urllib.parse.quote(...)'` 整体做百分号编码：
  手写 tag 里可能出现 `(` `)` `#` `%` 等字符，只转义括号会让 Markdown 链接被截断。
- **已知行为（不是 bug，但改前要想清楚）**：`overwrite_files: true` 只覆盖**同名**附件、不做
  prune —— 同一天里删掉或改名某套 deck 后再 push，旧 PDF 仍留在当天 Release 上，
  `releases/latest/download/<旧名>.pdf` 会继续返回旧内容，直到跨天新建 Release 才换掉链接
  （线上实证：v2026.09.30 仍带着 `example.pdf`，下载链接 302、站点链接 404）。
  想清理就得显式删附件，但那会连手动附加的文件一起误删，所以这里选择只记录不自动做。
- **`deploy` 与 `release` 是兄弟 job，可以单边成功**：Pages 侧失败（Source 没选 Actions、Pages 5xx）
  而 Release 照发，或反过来 —— 站点与 Release 会短暂不一致，补救手段是「Re-run failed jobs」，
  而它受产物保留期限制（pages 1 天 / slides-build 3 天）。另外**说明里的站点链接对「新 deck」在部署
  完成前是 404**（附件下载链接正常）。这是有意接受的取舍：宁可让 PDF 先可下载，也不因为 Pages
  出问题就把发版一起卡住。`needs.deploy` 串联会改变这个取舍，所以没那么做。
- 发布用 `softprops/action-gh-release@v3` + `overwrite_files: true`（同一天重复 push 靠它覆盖）。
- **tag 一旦创建就不再移动**：同一天的附件会更新，但 tag 停在当天第一次 push 的提交。
  移动已存在的 tag 会让所有克隆的 `git fetch --tags` 报 `would clobber existing tag`。
- `verify` / `build` / `release` **三个 job 都有** `if: github.event.deleted != true` 防护：
  **删除 tag/分支同样会产生 push 事件**，没有这个防护，删掉 `v2026.09.30` 后工作流会
  判定该版本不存在而把它重新创建出来。（`verify` 也带这个条件，是为了「删分支」这类事件
  不必白跑一遍校验。）

### 运维备忘

- **换默认分支**（比如 `main` → `master`）：要改的是**引用分支名的 5 处**（2026-10-11 数过）——
  `branches:` 触发器、缓存恢复步的 `github.ref == 'refs/heads/main'`、增量编译基准判断、
  `deploy` 的 `if`、`release` 的 `if`（行号会随插步骤漂移，**按下面的 grep 找、别背行号**）。
  漏掉增量基准那处不会报错，但每次都退化成全量编译。
  **别把另外 3 处 `github.event.deleted != true`（`verify`/`build`/`release`）也算进来** ——
  那是「删除 tag/分支也会触发 push 事件」的防护，跟分支名叫什么无关，改分支名时不用动它们。
  用 `grep -n "branches:\|refs/heads/main\|event.deleted" .github/workflows/build-and-deploy.yml`
  全部列出来逐个判断（曾经写成「全部 6 处」并把 3 处删除防护算进去、同时漏掉缓存那处）。
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
bash verify-site.sh            # 只做静态部分（30 项，含 Release/tag 逻辑，几秒）
bash verify-site.sh --build    # 再加 ①~⑪ 的编译路径（共 98 项），和 CI 门禁完全同一条命令

# 查看线上状态
gh run list --repo tortrixx/slides
gh release list --repo tortrixx/slides
gh api repos/tortrixx/slides/releases --jq '.[].tag_name'
```

**本地预览首页**（模板 + 生成步骤）：

```bash
# 先按 docs/gate-design.md「手工核对流程」第 1 步把 workflow 脚本抽到 /tmp/wf-scripts，
# 再跑「生成导航页」那一步。
# **按内容挑，别认编号**：现在的导航页是 build-6.sh、编译步是 build-5.sh，而 workflow 插一步
# 编号就整体错位（docs/gate-design.md 第 4 步就是这么要求的）：
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
bash verify-site.sh            # 静态检查 + Release/tag 逻辑（30 项，几秒，不需要 typst）
bash verify-site.sh --build    # 再加 ①~⑪ 的编译路径（共 98 项），和 CI 门禁完全同一条命令
```

当前基线：`--build` 全绿 = **98 项通过**（静态 30 + 编译路径 68）。每项的完整说明、对抗验证
记录与手工核对流程见 docs/gate-design.md，这里只留索引：

- ① 冷启动全量：产出 PDF 数、`.build-stamp`、首页卡片数、`icon.png` 进 `build/`、
  **「最近更新」标记数 = 套数（夹具里每套 deck 都被显式提交成「刚刚」）**、
  页脚时间戳已注入、三个占位注释（SLIDES/COUNT/META）在产物里零残留
- ①b HTML 转义：标题含 `& < >` 的 deck，产物必须是实体、没有原始标签
- ② 只改一个 deck 的增量；②b 非 ASCII 目录名的增量（钉住
  `core.quotePath=false`，背景见 docs/pitfalls.md）
- ③ 删除 deck 后清理残留 PDF；④ 编译失败必须 `exit 1`
- ⑤ 非法目录名必须 `exit 1`（空格 / 点号开头 / 含换行三种）；⑥ 一套都没有必须 `exit 1`
- ⑦ 导航页边界：读不到 `/Count` 不渲染页数项（读得到必须渲染）、残留文件清掉而
  `.build-stamp` 保留（根级残留图片也照清，白名单不许用 `*.png` 这类通配）、`BUILD_DIR` 危险值全拒、正常值放行、
  **`RECENT_DAYS` 非 1–3650 的整数全拒（含空串与 `'14 days'`）**
- ⑧/⑧b/⑧c Release/tag 逻辑（stub `gh`）：三种入口的 tag/managed、not found→`exists=false`、
  403 重试后 fail closed、旋钮防呆、机器标记决定 `ours`、说明里 tag 整体百分号编码且末尾带
  机器标记、「只更新附件」走 `gh release upload --clobber` 且无 PDF 必须 `exit 1`
- ⑨ 事件维度：stamp 失配 / `workflow_dispatch` / 非 main push → 全量重编；
  ⑨b 编译环境哈希必须覆盖 `setup-fonts` 复合 action（改字体 = 全量重编）
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
  读 env 版 **19 通过 / 0 失败**（当时还没加 env 断言，现在是 98 项）。这类假红比漏报更糟 —— 它会诱使人把测试改松。
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
- **编译环境哈希用 `wf_rev_of()`，与 workflow 同算法**（workflow 与
  `.github/actions/setup-fonts/action.yml` 两个文件一起哈希）。抽复合 action 时最容易漏这处：
  只哈希 workflow 的话，改字体不会触发全量重编 —— 正是 stamp 要防的静默失效。门禁 ⑨b 钉住。
- **`bash -n` 必须逐个文件跑**：`bash -n f1 f2 f3` 只把**第一个**当脚本、其余当位置参数，
  第二个文件语法坏了它照样报「全部通过」（对抗复核实测）。现在是循环 + 计数。
- **抓预期失败的退出码用 `capture`（`if out=$(…); then rc=0; else rc=$?; fi`）**，不要写
  `out="$(…)"; rc=$?`：门禁若被外人用 `bash -e verify-site.sh` 跑，后者会在第一个期望非零的
  断言处直接退出、连 FAIL 和汇总都印不出来。
- **CI 与本地仍有一个已知差异**：CI 的 `run:` 由 runner 以带 `-e` 的 shell 启动，而门禁用
  `bash <脚本>`（不继承 `-e`）。所以脚本里任何「失败又没被 `|| true`/`if`/`case` 包住」的命令，
  CI 会立刻中止而门禁会继续 —— 这类命令要当成「必须有兜底」来写（`wf_rev` 那处就是这么踩的：
  `2>/dev/null` 本意是容忍失败，实际在 CI 上会静默中止整步）。
- 顺带：脚本里 `git commit` 用 `git -c user.email=… -c user.name=…`，不依赖 runner 上有
  git 身份配置（那是环境相关的，不该假设）。

**门禁的结构约束（别改坏）**：
- 必须是**独立 job**。塞进 `build` 的步骤里有坑：`build` 最后会写 `.build-stamp`，
  如果顺序成了「编译 → 写 stamp → 门禁失败」，stamp 已落盘，下次 push 会以为编译过了而
  跳过重编 —— 门禁反而制造了它本该防的那种不一致。
- `build` 靠 `needs: verify` 依赖它，所以门禁红了站点和 Release 都不会动（fail closed）。
- 门禁会自己触发全量重编：workflow 文件哈希进了 stamp，所以**改 workflow 必然全量编译**，
  而门禁自己会把编译步真跑 **16 次**（每次编夹具里的若干套，见 `grep -c 'run_compile ' verify-site.sh`）。
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

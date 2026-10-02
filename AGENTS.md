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
├── assets/
│   └── icon.png              # 站点静态资源（左上角头像），构建时拷进 build/
├── verify-site.sh            # CI 门禁脚本：抽 workflow 脚本 + 语法/lint + 真跑 ①~⑩ + Release/tag 逻辑
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
| `verify` | `github.event.deleted != true` | 默认（`contents: read`） | 门禁：跑 `verify-site.sh --build`（①~⑩ + Release/tag 逻辑），失败则后面全部不执行 |
| `build` | `github.event.deleted != true` | `contents: read` | 装字体 → 增量编译 → 生成导航页 → 上传两份产物 |
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
  这一条核对过 action 源码（2026-10）：`upload-pages-artifact@v5` 的 `include-hidden-files`
  默认 `false`，打包时会加 `--exclude=.[^/]*`；`upload-artifact@v7` 同样默认不收隐藏文件。
  所以 `.build-stamp` 不会出现在站点上，也不会进 Release 附件（release 那边另有
  `files: build/*.pdf` 兜底）。**别把它改成非隐藏文件名**，否则会被发布出去。
  tag / release / 手动运行一律全量编译。
- **构建环境校验（写文件之前第一步）**：`BUILD_DIR` 归一化（折叠 `//`、去掉开头 `./` 与结尾 `/`）后
  必须是仓库内的相对目录名，且只含 `A-Za-z0-9._-/`；`TYPST_VERSION` 不能为空；`RELEASE_TZ` 必须能被
  `date` 解析。为什么非要这一步：后面几段脚本按 `"$BUILD_DIR"/*` 遍历并 `rm -rf`，**`BUILD_DIR` 为空时
  通配符会展开成 `/*`**（实测会枚举 `/Applications`、`/Library`…），而 `'./'` 又等价于 `.`
  —— 清理会把整个工作树删掉。空值/`/`/`.`/`..`/绝对路径/含 `..`/含空格等一律 `::error::` + `exit 1`。
  这一步刻意放在装字体、恢复缓存**之前**（配错了 5 秒内就红，也不会先恢复一份缓存再失败）。
- **幻灯片目录名的另外两个护栏**（§3.8 只管字符集）：
  - **点号开头**（`slides/.hidden`）：`for dir in slides/*/` 根本匹配不到它，会静默不编译、不出卡片，
    而只要还有别的 deck 就 `exit 0` —— 站点永远少一套。所以单独扫 `slides/.[!.]*/`、`slides/..?*/`
    报错（宁可让人改名）。
  - **含换行/回车**：`basename` 会把尾部换行吃掉，两个不同目录会落到同一个 `<名称>.pdf` 上互相覆盖。
    按 `$dir` 的原始字节先拦掉。
- **导航页**：`index.template.html` 是首页模板（版式/样式都在里面），workflow 只负责
  注入数据，产物 `build/index.html` 是**服务端渲染**的静态页（无 JS 也能看）。
  三处占位注释由 `awk` 替换：`SLIDES`（卡片列表）、`COUNT`（套数）、`META`（页脚的「最后更新 …」）。
  **`awk` 是按行替换的，不认 HTML 注释** —— 所以**绝不要在模板（或任何会被喂给那段 awk 的文件）里
  写出占位符的原文**：写了 `SLIDES` 那处的原文，整行会被换成卡片列表并塞在注释中间；写了 `COUNT`
  那处的原文，它会就地变成数字。这不是推演：模板开头的注释里最早写过 `COUNT` 的原文，
  构建产物里那句真的成了「注意 2 现在模板里没有用了」（2026-10 实测）。
  现在模板里提到它们只写名字，原文只出现在两处真正的注入点（`SLIDES` 与 `META`）；
  **`COUNT` 目前模板里没有用到**（标题旁的套数已按用户要求去掉，理由见「首页视觉」），
  但 workflow 的替换规则留着 —— 想恢复套数显示只需改模板，不用碰 YAML。
  页脚**只放这个时间戳**：原来那句「本页由 GitHub Actions 自动生成」说的是构建过程、不是页面内容，
  已删（与早先删掉 "Built by Typst & Touying." 同理）；提交号也一并不显示了——它是构建提交，
  跟某套幻灯片最后一次改动无关，容易被误读。
  - **顺序＝最新在前**：先按 `git log -1 --format=%cs -- "slides/<名>/"` 取每套 deck **最后一次
    提交的日期**，`LC_ALL=C sort -t $'\t' -k1,1r -k2,2` 排序（日期倒序、同一天按文件夹名升序），
    取不到日期（浅克隆 / 从未提交）的排最后。**不要退回 `for dir in slides/*/`**：那是 bash 的
    glob 顺序 =「当前 locale 的字典序」，跟改没改无关，而且中文名的先后会随 runner 的 locale 变
    （实测同一组名字：C.UTF-8 把中文排最后、en_US.UTF-8 排最前、zh_CN.UTF-8 又排最后）。
    日期**只用于排序、不渲染到页面**（那一列已经去掉了，原因见「首页视觉」那节）。
    两个实现坑（都踩过并写进了门禁）：① 空日期不能直接写进 TSV —— `read` 会吃掉行首的 IFS 空白，
    文件名会被读进日期字段、整行错位；脚本里把它换成 `0000-00-00` 占位、循环里再换回空串。
    ② `[ "$d" = "x" ] && x=""` 这种一行写法在 `set -e` 下会留下非零退出码，落在脚本末尾会把
    整步判成失败，所以写成正常的 `if`。
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
    前两项在 workflow 里仍写作 `<span class="badge">`，但**CSS 里已经没有胶囊样式了**（见「首页视觉」）。
    页数从 PDF 页树根节点的 `/Count` 取（`strings | grep -o '/Count [0-9]\{1,4\}'`
    取最大值；Typst 产出的 PDF 未压缩所以读得到，已核对 49/20 与逐页渲染数一致）。
    **原来看起来多余的 `PDF` 徽章已去掉**——链接本身就是 `.pdf`、点了就是打开 PDF，
    文件名里又写了一遍，三处重复；换成页数更有信息量。若哪天读不到 `/Count`（例如 PDF 开始
    压缩），**那一枚整枚都不渲染**（不会留下一个只有「页」字的空项），所以这个取法不会给出错的信息。
    门禁同时钉了两面：读不到时不许出现「N 页」，正常 PDF 必须出现「N 页」。
  - **转义**：文件夹名与标题/副标题都会做 HTML 转义（`&` `<` `>` `"`），
    文件夹名另有字符集护栏（见 §3.8），两道一起保证生成的 HTML 不会被名字搞坏。
  - 标题按**原文**显示：Typst 标记（`*粗体*`、反引号）不会被渲染，也不会被剥离。
- **站点静态资源（`assets/`）**：Pages 只发布 `build/`，所以仓库里的静态文件由「生成导航页」
  那步开头拷进站点根目录（现在只有 `assets/icon.png`，即左上角头像；模板里写 `src="icon.png"`）。
  文件缺失是 `::error::` + 退出，**故意 fail closed**：页面不会因此报错，只是 `img` 被
  `onerror` 静默删掉，不失败的话很难发现。`verify-site.sh` 里钉了一条产物断言。
  拷之前先清掉 `build/` 里「非 `*.pdf`、非 `index.html`、非 `.build-stamp`」的旧文件
  （三个通配符 `*` / `.[!.]*` / `..?*` 一起覆盖普通文件与隐藏文件；`.build-stamp` 是增量基准，
  必须留下）：`build/` 是 `actions/cache` 的缓存对象，只清 PDF 的话，某个版本拷进来、后来不再拷的
  静态资源会被缓存**永久**带下去，并随两份 artifact 一起发布到站点根目录，自愈不了
  （本地 `build/` 里就躺过 `avatar-*.png` 这种中间态残留）。
  头像原来写的是 `https://github.com/tortrixx.png`，为什么换掉（2026-10 实测）：
  - 那是**全页唯一的跨站请求**（其余 CSS/JS/图标全是内联的），所以必然最后出现；
  - 它会 **302** 到 `avatars.githubusercontent.com`，多一次 DNS + TLS，实测 1.84s 才拿到图；
    而且这个 302 带 `cache-control: no-cache`，**每次打开都要重走一遍**（图的 `max-age=300`
    只能省掉第二步）；
  - 抓回来的是 **460×460 / 38 KB**，而（当时）页面只用 80px 显示（`?size=160` 才是 12 KB）；
  - 国内网络下 `avatars.githubusercontent.com` 还常慢/不可达（那 `onerror` 会把图整个删掉）。
  现在用仓库内 160×160（2× DPR）PNG，15.9 KB，同源、可长期缓存、零外部依赖。
  **换图直接替换 `assets/icon.png` 即可**，别改回外链。
- **首页视觉**：沿用 <https://github.com/tortrixx/tortrixx> 的设计语言（等宽字体、
  shadcn neutral 色阶、虚线网格背景、hover 光边框 BorderBeam、BlurFade 入场、
  深浅色主题）。改样式只动 `index.template.html`，不用碰 workflow。
  注意 `<meta charset>` 必须留在文件最前面——模板开头那段中文注释一旦挪到它前面，
  就会超出 1024 字节的编码探测窗口，页面会乱码。
  装饰性动效都做了降级：光带用 `@supports (offset-path: rect(...))` 包住（不支持就整条不显示，
  否则会在左上角糊一块渐变色），`prefers-reduced-motion: reduce` 时关闭淡入并隐藏光带，
  键盘焦点用 `:focus-visible` 描边。改 CSS 时请保留这些降级。
  两处**对着原站量过**的地方（2026-10，用户对照 <https://tortrixx.pages.dev/> 提的）：
  - **顶栏 = 头像 + 主标题（h1）+ 右上角按钮，一行（≥640px；窄屏纵向堆叠）；页面没有标语，也没有区块 h2**（2026-10 定稿）：
    原来这里是「头像 + 标语 `Less noise, more signal.`」一行，下面再单独一行 `h2 Slides`。
    去掉标语的理由：① 那是原站（个人主页）的座右铭，对这一页不携带任何信息；
    ② 这一页只有一个区块，"标识行 + 区块标题行"两行在说同一件事，本来就冗余；
    ③ 把 `Slides` 提上来当 `h1` 之后**语义更好** —— h1 说的是这一页到底是什么，
    而标语当 h1 属于"没说出页面主题"。
    **别把唯一的 h1 弄丢**（无 h1 对读屏和搜索都不友好），要改标题名就改 `.page-title` 这一处；
    以后若按年/主题分组，每组再用 `h2`（字号 1.125rem 一档、比主标题小），别把主标题降级。
    用户如果哪天真想留这句标语，正确的位置是**页脚**（一行小字），不要放回顶栏。
    头像跟着从 80px 改到 64px（`img` 的 `width`/`height` 属性要一起改）：一行里它和 1.5rem 的
    标题按居中对齐，80px 会显得头重。
    **主标题不带任何装饰**（不加下划线、不加边框）：参考站全站没有一处 `underline`（它的 h1 就是
    `text-xl font-bold`，2026-10 拉下它的 HTML 核过），而这里标题下方已经有 `.head-row` 的通栏
    `border-bottom` 收口，再加下划线是重复装饰。
    顺带一个**踩过的真坑**（用户报"Slides 和 2 都带下划线"）：`.page-title` 是 flex 容器，里面的
    `.count` 作为 flex item 会被 **blockify**（`inline-block` → `block`），于是它不再是「原子内联
    后代」，而 **祖先的 `text-decoration` 会传播进后代、后代自己写 `text-decoration: none` 是撤不掉
    的** —— 所以下划线会画到计数胶囊下面去（无头 Chrome 3× 截图可见）。两条出路：要么别给标题加
    下划线（现在的选择），要么把文字包进内层 `<span class="pt-text">` 再把下划线加在它身上。
    别指望 `.count` 自己那条 `display: inline-block` 能挡住传播 —— 它只在父级**不是** flex/grid
    容器时才有效。
    **标题旁的套数胶囊也删了**（2026-10 用户提的，`.count` 那条 CSS 跟着一起删，模板里现在只剩
    一段「当年怎么写」的注释）：计数的价值在于「概括你看不到的东西」——GitHub 那种 tab 计数概括的
    是**筛选后的子集**（Open 12 / Closed 30），而我们这个数字概括的就是你正在看的这一页，
    跟逐条数一遍是同一件事；**放页脚也不行**：读到页脚时列表早看完了，那时它更没用。
    真要恢复：h1 里加回套数 span + 把 `.count` 规则写回模板（注释里留了原文），
    **workflow 不用动** —— `COUNT` 的 `awk` 替换规则一直留着（也见下面「导航页」那节里
    「别在模板里写占位符原文」那个坑）。
  - **字重：两处都写 `500`（意图 medium），不要写 600**（2026-10 定稿；用户前后提过两次 ——
    先是「照着原站把标语/标题加粗一点」，看到效果后又说「加粗有点过了、每个 pdf 的标题也不能过粗」）：
    原站那两处写的是 `font-medium`(500)，它看着真的是 medium，是因为它**自带 Roboto Mono Variable**
    （`@font-face` 里 `font-weight: 100 700`）。本页走系统等宽字体栈（`ui-monospace` → SF Mono /
    Menlo / Consolas…），无头 Chrome 实测（macOS，3× 放大、20px/18px 两个真实字号）：
    **400 与 500 渲染完全一致、600 与 700 都画出粗体且彼此一致** —— 这套字体只有 regular + bold
    两档，**"medium" 这一档根本不存在**。
    所以：写 600 等于 bold（用户觉得过了），写 500 在本机落 regular，但在**有自变量字体**的环境里
    会自然落到真正的 medium —— 写 500 表达的是**意图**，两个方向都不吃亏。
    层级由此改由**字号 + 颜色**承担：h1 24px / 行标题 18px / 副标题 14px / 元信息 12px，
    颜色只用「纯黑 vs muted」两级。**别再改回 600**（在当前环境里就是 bold）。
    想连字形一起 100% 复刻原站的真实 medium，唯一办法是把它那份
    `roboto-mono-*-wght-normal.woff2` 自持进 `assets/`：加 `@font-face`（`font-weight: 100 700`）、
    把 `Roboto Mono` 放到字体栈最前，**并且改 workflow 的 assets 拷贝那一步**（现在是写死的
    `cp assets/icon.png …` + fail-closed 检查，不是通配）—— 改 YAML 会让下一次 push 全量重编。
    为这 ~30KB 暂时不做，路径记在这里：将来要做就是这三处（另外记得给门禁补一条产物断言）。
  - **列表版式：纯列表 + 两级分隔线（行线两端渐隐），行内不再有任何色条，也不显示日期**（2026-10 定稿）：
    历史是：① 每张卡一根粉条 → ② 红条挪到 `h2`、卡片竖条改中性灰 hover 变粉 → ③ 去掉色条、
    改成「左侧日期列 + 通栏细线」 → ④ 去掉日期列、分隔线做层级 → ⑤（现在）行线的两端改为渐隐、
    行距放大，**主标题（h1）的下划线去掉**（行标题仍保留 hover 下划线，见 `.deck:hover .deck-title`）。
    为什么最后全去掉：原站那根 `w-1.5 bg-red-400/60 group-hover:bg-red-400` 是**分组标题**的
    标记（<https://tortrixx.pages.dev/workspace> 整页 4 个分组 = 4 根，组内几十个 `<li>` 一根
    都不带），我们把它按行复制就等于把一个章节符号复印 N 份；而挪到 `h2` 后又只剩"装饰"一个
    理由（单组页面里它不携带信息，用户也不想要）。所以：**一行一根条、一页一根条都不要再加**。
    **日期为什么不上页面**（③ 那版的 `.lede` 列已删，用户提的）：它是「这套 deck 上一次提交」，
    不是内容本身的日期（改个错别字也会把它顶到最前，容易被读成"最新内容"）；而且要占一条
    5.6rem 的固定列、窄屏还得为它堆叠换行。顺序仍然是「最新在前」—— 日期只用于**构建时排序**
    （见下面「导航页」那节），不渲染。真想在页面上透出"新旧"，更轻的做法是给最近改过的行加个
    小圆点，**不要**恢复整列日期。
    分隔线做成**两级**（2026-10 用户提的「行线跟页眉那条一样，分不出来」，改了两轮）：
    * 页眉下面那条（`.head-row` 的 `border-bottom`）= **区块边界**：通栏、实线、`hsl(var(--border))`，
      两端到头；
    * 行与行之间（`.deck + .deck::before`）= **区块内的条目**：`height: 1px` + `background-image`
      的**两端渐隐**细线（`transparent → hsl(var(--border)) 12% → 88% → transparent`）。
    第一版是「两端各内缩 0.5rem + `hsl(var(--border) / 0.6)`」，问题是行线仍在跟页眉那条**比长短**
    （硬端点对硬端点），层级是黏的；改成渐隐后行线是"一段化开的毛发线"，跟通栏实线在**质感**上就分开了。
    顺带两处：行距放大到 `0.68rem/0.6rem`、用伪元素而不是 `border-top`（`.deck` 是圆角盒子，
    `border-top` 会跟着圆角拐弯；而且渐变也画不进 border）。**别把它改回 `border-top`**。
    这两条外部依据（2026-10 查过）：
    * Material 3 的 divider 指南：full-width divider 分隔不同 section，inset divider 分隔同一
      section 内的条目（<https://m3.material.io/components/divider/guidelines>）—— 我们的行是
      "同一区块内的条目"，所以线不接地、不撞边缘；
    * iOS 的 `UITableViewCell.separatorInset`：表格分隔线从**内容左边缘**开始、不到屏幕左边缘
      （<https://developer.apple.com/documentation/uikit/uitableviewcell/separatorinset>），同一个思路；
    * Primer 的 action list：条目分隔线**只在多行条目（带描述）时才建议用**，并提醒「用分隔线时
      同时把 item 尺寸放大有助可读性，别只增加视觉噪音」
      （<https://primer.github.io/design/components/action-list/>）—— 我们一行三行文字（标题/副标题/
      元信息），所以保留细线是有依据的，行距也据此放大了一档。
    * 参考站（<https://tortrixx.pages.dev/workspace>）**一根分隔线都没有**：它的 `<li>` 只有
      `space-y-2 sm:space-y-1` 的小间距，4 个分组各自是 `rounded-lg border border-transparent
      hover:border-secondary hover:bg-blue-50/80 hover:shadow` 的卡片（`mb-3` 隔开）。
      它敢不用线，是因为每条只有一两行、靠间距就够；我们三行文字用间距会糊，所以取"渐隐细线"这条
      中间路线 —— 保留信息结构，但去掉表格感。
    行内的三级层次（2026-10 用户问「页数/大小会不会抢标题注意力」，量过之后调的）：
    无头 Chrome 取到的计算样式是**标题 16px/400、副标题 14px/400、元信息 12px/400** ——
    三级只差 2px、全是 regular，层级完全靠颜色撑着；于是一行里"最有形状"的东西变成了
    那两个 1px 描边胶囊。**改之前量过：当时整页带 1px 边框 + 圆角的元素只有这些胶囊**
    （当时站点 2 套 = 4 个，每套 2 个线性增长；主题按钮 `.icon-btn` 是 `border: 0`、GitHub
    链接也没有边框），所以它们不只是"数量最多"，而是**全页唯一一类封闭描边图形**，标题自然
    抢不过；改完之后全页是 0 个。（别写死套数：这里曾经写成"12 套 = 24 个"，而站点当时只有
    2 套 —— 数字要能当场量出来。）
    两处一起改：
    * `.deck-title` → **1.125rem（18px）/ weight 500**（字重见上面那条：本字体栈里 600 就是 bold，
      用户明确说"过粗"，所以写 500＝意图 medium、本机落 regular），标题靠字号 + 纯黑与灰色拉开；
    * 元信息去掉胶囊的**边框与内边距**，退化成一行淡色规格文字 `49 页 · 748 KB · 26-09-30.pdf`
      （分隔点用 `.badge + .badge::before` / `.badge + .file::before` 生成，所以**不用动 workflow**；
      workflow 里那个 class 名仍叫 `badge`，但它现在就是个普通 span —— 改名要动 YAML =
      触发全量重编、还会让当天缓存作废，不值当）。
      去掉胶囊后**分隔点从"装饰"变成了"承重"**（原来分组的活由那两个盒子干）：它是
      `hsl(var(--muted-foreground) / 0.55)`，实测浅色 **#B2B2B2 = 2.12:1**、深色
      **#5E5E5E = 3.05:1** —— 浅色下它几乎只是一点空气（真正分开三项的是 0.5rem 左右留白），
      深色下反倒比浅色清楚。这是**有意留着的**：`·` 是纯装饰、不承载可读内容，不适用 3:1 的
      非文本对比要求，而这一页的方向是"少一点墨"。真觉得三项挨得太近，加法只有一种 ——
      把它提到满色 muted（浅 4.74:1 / 深 7.85:1）；**不要**为此把胶囊加回来，
      那是把一个装饰问题换回一个层级问题。
    **减重不能靠把颜色调淡**：浅色模式下 muted `#737373` 对白底是 **4.74:1**，刚过 WCAG AA 的
    4.5:1（深色 7.85:1）—— 能去掉的只有装饰（描边、内边距），不是对比度。动这三级的字号/颜色前先算一遍。
    一个连带的取舍，改之前先想清楚：**hover 从「灰块包住内容」回到「整行」**。贴合式灰块是②
    那版在**无分隔线的浮动卡片**里成立的做法；一旦有了分隔线，高亮块右边缘和分隔线右边缘对不齐
    就是"脏"。所以 `.deck` 是 `width: 100%`，和分隔线共用同一条右边界。
    改分隔线/版式后记得同步门禁 ⑩（它钉顺序，并顺手钉住"日期不再渲染"）。
  无障碍上另有两条硬约定（2026-10 补齐）：
  - **装饰性 SVG 一律 `aria-hidden="true"`**：背景网格（`.bg-grid`）、主题按钮里的三个图标、
    GitHub 图标、卡片上的「外链」小箭头。它们的可访问名由外层承担（按钮/链接的 `aria-label`、
    卡片标题的可见文本），SVG 自己不提供名字，留着只会让读屏软件多念一句「图形」。
    注意卡片里那个箭头 SVG 是**在 workflow 的 heredoc 里**生成的（改它要动 YAML）。
  - 头像 `img` 显式写 `width="64" height="64"`（与 CSS 一致）：样式表万一没生效也不会撑破布局。
  另外 `target="_blank"` 的链接都带 `rel="noopener noreferrer"`（`noreferrer` 本身就蕴含
  `noopener`，写全是为了不依赖这条蕴含关系；Lighthouse 的「跨源跳转安全」审计认这两者之一）。
- **页脚位置**：`body` 是 `display: flex; flex-direction: column`（已有 `min-height: 100vh`），
  `main` 吃剩余高度（`flex: 1 0 auto`），`footer` 只留 `margin-top: 1.25rem` + `text-align: center`
  —— 内容少时页脚落在**页面最下方、整行居中**，内容超过一屏时仍旧跟在最后一张卡片之后
  （不用 `position: fixed`，那会盖住内容）。原来它紧跟在卡片下面，只有一两套幻灯片时看着像"浮在中间"。
  实测（无头 Chrome，视口高 1000、两套幻灯片）：footer 底边距视口底 40px（= body 的
  `padding-bottom: 2.5rem`）、中心 x=550 与 body 中心重合；16 张卡片的页面：文档高 1646、
  页脚距最后一张卡片 20px，无重叠。
- **页面背景要设在 `html` 上，不能只设在 `body`**（Safari 踩过）：`body` 是
  `width: 90%` 的居中盒子、高度只由内容与 `min-height: 100vh` 决定，把 `background` 只写在它上面时，浏览器**可能**
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
    注意 headless 的 `prefers-color-scheme` 是**跟着系统走**的（本机两次实测结果就不一样：
    写过「默认 dark」，2026-10 再测又是 light），别假设固定值 —— 要哪种就在截图前显式定：
    浅色 `--blink-settings=preferredColorScheme=1`，深色则在 `</body>` 前注入
    `document.documentElement.classList.add("dark")`（放在 head 里会被页面自己的 JS 覆盖）。
    截图前还要关掉 `.fade` 的入场动画，否则元素是 `opacity: 0`，截出来一片空白（会误判成"没渲染"）。
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

- **换默认分支**（比如 `main` → `master`）：要改的是**引用分支名的 5 处**（2026-10 数过）——
  `:25` 的 `branches:` 触发器、`:182` 缓存恢复步的 `github.ref == 'refs/heads/main'`、
  `:224` 增量编译基准判断、`:525` `deploy` 的 `if`、`:553` `release` 的 `if`
  （行号会随插步骤漂移，**按下面的 grep 找、别背行号**）。
  漏掉 `:224` 那处不会报错，但每次都退化成全量编译。
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
bash verify-site.sh            # 只做静态部分（29 项，含 Release/tag 逻辑，几秒）
bash verify-site.sh --build    # 再加 ①~⑩ 的编译路径（共 84 项），和 CI 门禁完全同一条命令

# 查看线上状态
gh run list --repo tortrixx/slides
gh release list --repo tortrixx/slides
gh api repos/tortrixx/slides/releases --jq '.[].tag_name'
```

**本地预览首页**（模板 + 生成步骤）：

```bash
# 先按 §6 第 1 步把 workflow 脚本抽到 /tmp/wf-scripts，再跑「生成导航页」那一步。
# **按内容挑，别认编号**：现在的导航页是 build-6.sh、编译步是 build-5.sh，而 workflow 插一步
# 编号就整体错位（§6 第 4 步就是这么要求的）：
NAV="$(grep -l '<!--SLIDES-->' /tmp/wf-scripts/*.sh)"
RUNNER_TEMP=/tmp/rt BUILD_DIR=build RELEASE_TZ=Asia/Shanghai bash "$NAV"
# 注意 RUNNER_TEMP 目录得先 mkdir -p（脚本往那里写 slides-items.html）。
# 这一步已不需要 GITHUB_SHA（页脚不再显示提交号）。
# 然后用无头 Chrome 截图看效果。两个坑：
#   1) headless 的 prefers-color-scheme 跟随系统（本机实测过 dark 也实测过 light）——
#      想固定哪个主题，就在截图前注入 html.classList.add("dark")（页面自己的 JS 会按
#      matchMedia 覆盖 class，所以要放在 </body> 前）；
#   2) 入场动画带 fill-mode: both，t=0 时元素是 opacity:0 —— 截图前注入
#      .fade{animation:none;opacity:1}，否则截出一张空页（**不是**页面没渲染）
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
  --user-data-dir=/tmp/cprof --window-size=1100,1250 \
  --screenshot=/tmp/shot.png file:///path/to/index.html
```

## 6. 改 workflow 后的验证清单（务必执行）

CI 逻辑全在 YAML 的 `run: |` 里，改完不能只靠肉眼。**`verify-site.sh` 就是 CI 门禁本身**
（`verify` job 跑 `--build`），本地可以先跑一遍再推：

```bash
bash verify-site.sh            # 静态检查 + Release/tag 逻辑（29 项，几秒，不需要 typst）
bash verify-site.sh --build    # 再加 ①~⑩ 的编译路径（共 84 项），和 CI 门禁完全同一条命令
```

当前基线：`--build` 全绿 = **84 项通过**（静态 29 + 编译路径 55），覆盖这些路径：
① 冷启动全量（含 `assets/icon.png` 确实进了 `build/`，以及 SLIDES / META 两处**真的注入了**：
卡片数、页脚时间戳；**三个占位注释在产物里一个都不许残留**（SLIDES / COUNT / META 一起 grep ——
COUNT 现在模板里没用，所以只查残留）。
这条以前是「页面 `h1` 里的 count 胶囊是个数字」，随标题从 h2 搬到 h1、又在 2026-10 跟着套数一起
被删掉，改了两次 —— 现在的写法不依赖任何标题写法，覆盖面反而更宽：占位符被改名/拼错时
那段内容会**静默消失**，而 HTML 注释在页面上根本看不见，不钉就完全没有症状）
①b **HTML 转义**：造一个标题含 `& < >` 的 deck，断言产物里是实体且没有原始标签（转义回归是注入风险）
② 只改一个 deck 的增量
②b **非 ASCII 文件夹名**的增量必须重编那一套（钉住 `core.quotePath=false`，见 §7）
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
⑩ 列表顺序（最新在前）：夹具里造三套 deck —— `zz-old`（提交日期 2020，名字靠后）、`aa-new`（2026，
名字靠前）、`mm-nodate`（**故意不提交**）。断言产物的 href 顺序正好是 `aa-new zz-old mm-nodate`
（日期倒序、无日期排最后；名字顺序与日期顺序**故意相反**，所以退回 glob 排序必挂），
外加一条反面对照：产物里不该再出现 `class="lede"`（日期只用于排序、不上页面）。
这两条做过对抗验证：把 `-k1,1r -k2,2` 改成 `-k1,2` 后 ⑩ 直接变红（导航页那步崩了，href 列表为空）。
⑪ 样式表花括号平衡（静态）：`<style>` 里 `{` 与 `}` 必须一样多。**多一个（或少一个）`}` 不报错、
不白屏，只会把它后面的规则静默吞掉** —— 2026-10 真踩过：一段重复的注释末尾多带了一个 `}`，
把紧跟其后的 `@media (min-width: 640px) { .page-title { margin-left: 1.5rem } }` 整块吃掉，
桌面端 h1 与头像**贴在一起**（无头 Chrome 实测 gap 0.0px，修好是 24px）；页面照样渲染、
CSSOM 也不抛错（只是 cssRules 从 51 悄悄变成 50），截图极易看漏。CI 里没有浏览器、这类没有
运行时替代品，所以用静态计数钉住（统计前先去掉 `/* … */` 注释）。

**为什么这个门禁值得存在**：这些守的都是**静默失效**的不变量 —— stamp 基准错了会长期复用
旧 PDF、`core.quotePath` 会让中文名 deck 永不重编、护栏失效会做出坏链接、失败没 `exit 1`
会发布残缺站点、说明判断错了会覆盖用户手写内容。它们破了不报错，只是安静地出错，
所以必须靠真跑一遍来守。反过来，`bash -n` 那类静态检查当门禁是**零增量**（语法错 GitHub
起不来 job、运行时也立刻炸），所以门禁的价值全在真跑那部分 —— 但也别把静态部分写成假绿
（见下面 `bash -n` 那条）。

**门禁脚本自身的鲁棒性约定（`verify-site.sh`）**：
- **不写死 workflow 的 `env:` 值**，改成从 YAML 读 `TYPST_VERSION` / `BUILD_DIR` / `RELEASE_TZ`。
  写死过 `TYPST_VERSION`，后果实测很严重：workflow 一升级版本号，脚本造的 stamp 里的版本就和
  真正会写的那份不一致 → 走进「编译环境变了 → 全量」分支 → ②③ 的增量断言全挂。
  实测对比（把 workflow 的版本改成 9.9.9）：**写死版 2 通过 / 17 失败（exit 127）**，
  读 env 版 **19 通过 / 0 失败**（当时还没加 env 断言，现在是 84 项）。这类假红比漏报更糟 —— 它会诱使人把测试改松。
- **typst 包缓存要显式指到临时目录**：脚本默认 `TYPST_PACKAGE_CACHE_PATH="$TMP/typst-pkg"`
  （外部设了就尊重外部值）。typst 默认写 `$HOME`，HOME 不可写时每套 deck 都会报
  `failed to create temporary package directory` —— 看起来像 deck 坏了，是典型假红
  （本机沙箱就踩过：不设这个变量 12 通过 / 11 失败，设了才 80/0）。CI 里 HOME 可写、
  本来也没缓存这个目录，所以行为不变。
- **夹具先做一次快照提交**：`fresh()` 复制完仓库会 `git add -A && commit` 一次。原因是工作树里
  未提交的改动（比如刚 `cp -R` 出来的新 deck）不在 `git diff <基准> HEAD` 里，会让 ② 的
  「复用 N-1」断言假红 —— 本地开发时几乎必然命中。
- **每次运行用独立临时目录**（`TMP="$(mktemp -d …)"` + `trap` 清理），不再写死 `/tmp/slides-verify`：
  写死时两个并发运行（本地跑一遍的同时另一个 agent 也在跑、或 CI 与本地同时跑）会互相
  `rm -rf` 掉对方的 `$TMP`，症状是后面莫名其妙的 `exit 127`、断言乱飞 —— 本轮真踩过，
  而且当时误以为是代码坏了。trap 仍负责清理。
- **期望套数从夹具推导，不写死**：`n_decks` 由 `$R/slides/*/main.typ` 数出来，①③ 的数量断言
  和 ② 的复用套数都用它。写死过 `2`／`1`，而 §1 承诺「`cp -R slides/template slides/my-talk`
  后 push 即可」—— 加第三套 slide 的那次 push 会让门禁假红，进而 `needs: verify` 把部署和发版
  全卡死（正是 §6 警告的「假红诱使人把测试改松」）。
- **要跑的步骤脚本按内容签名定位，不认文件名里的下标**：抽取出来的文件叫 `build-<下标>.sh`，
  workflow 插一步就整体错位，而错位最坏的结果是**静默测错步骤**（拿生成导航页的脚本验护栏会
  永远通过）。现在直接扫 `$TMP/scripts/*.sh`，按内容挑：含 `typst compile` 的是编译步、
  含 `<!--SLIDES-->` 的是导航页、含 `managed=true` 的是计算 tag、含 `release-notes.md` 的是写说明；
  一个都找不到就立刻 `bad` + `exit 1`。加/删步骤不需要改门禁。
- **`bash -n` 必须逐个文件跑**：`bash -n f1 f2 f3` 只把**第一个**当脚本、其余当位置参数，
  第二个文件语法坏了它照样报「全部通过」（本轮对抗复核实测）。现在是循环 + 计数。
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

4. **在临时副本里跑编译步骤**（覆盖四条路径：冷启动全量 / 只改一个 deck 的增量 /
   删除某套 deck 的清理 / 某套编译失败必须 `exit 1`）。
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

## 7. 值得注意的坑（已踩过）

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
- 首页的标题层级：全页**只有**一个 `h1`（顶栏里的 `Slides`，`.page-title`），没有标语、没有区块 `h2`
  （见 §4「首页视觉」）；以后若分组，组标题用 `h2`。**改动时别把唯一的 h1 弄丢**。

<!-- tortrixx/slides · 仓库约定见 AGENTS.md -->

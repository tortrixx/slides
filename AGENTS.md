# AGENTS.md

给在本仓库工作的 AI agent（以及未来的维护者）的技术说明。
**README 只有一页「有什么」**，本文件放全部操作说明、实现细节和坑。

> 文档分工（请务必遵守）：**README 只讲「仓库里有什么」，保持极简**——只列幻灯片清单、
> 在线地址、以及「文件夹名即 URL」这条约束，不写操作步骤、不写注意事项；
> 所有操作说明、机制、注意事项、踩坑记录都写在本文件。
> 不要因为「用户可能不知道」就往 README 里加提示、警示、边角情况——需要时在本文件里写清楚。

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
改名和内容后 push 即可。README 只讲仓库里有什么，操作细节都记在本文件。

- 仓库：`tortrixx/slides`，默认分支 `main`
- 站点：<https://tortrixx.github.io/slides/>（Pages Source = GitHub Actions，已开启）
- 固定下载：`https://github.com/tortrixx/slides/releases/latest/download/<名称>.pdf`

## 2. 仓库结构

```
.
├── slides/
│   ├── template/main.typ     # 唯一的模板：前言样板 + 封面/目录/分节 + 各类写法示例
│   └── 26-09-30/             # 实际使用的 deck（自带 src/ 图片等资源）
│       ├── main.typ
│       └── src/
├── .github/workflows/
│   └── build-and-deploy.yml  # 全部自动化逻辑（唯一的 CI 文件）
├── index.template.html       # 站点首页模板（构建时注入幻灯片列表）
├── AGENTS.md                 # 本文件
├── README.md                 # 一页概览：有哪些幻灯片、在线地址
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

   // 中西文混排的视觉平衡：汉字/假名/中文标点缩到 0.9em，西文与公式保持 20pt
   #show regex("[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\u{3000}-\u{303F}\u{FF00}-\u{FFEF}]"): set text(size: 0.9em)

   #set heading(numbering: numbly("{1}.", default: "1.1"))
   ```

4. **不要随手删掉那条 `#show regex(...)`**。同样 20pt 时汉字墨迹高约是 Inter 大写字母的
   1.28 倍，看起来「胖一圈」；缩到 0.9em 后降到约 1.17。实测单页要点容量 14 → 16 条，
   公式与西文不受影响。调档只改一个数：`0.85em` 更明显、`0.95em` 接近原样。
   正则里的 `\u{3000}-\u{303F}`、`\u{FF00}-\u{FFEF}` 必须保留，否则汉字缩小而
   「。、，：」不变，标点会显得特别大。
5. 字号：正文 20pt 是 metropolis 的默认值，`#set text` 里显式写出来只为可读性。
   内容特别密的单页用局部覆盖（`#slide[#set text(size: 18pt) ...]`），不要全局改小。
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
   - **标题**：首页取的是 `title:` 那行。A4 用 Typst 原生的 `#set document(title: "…")`，
     **必须是字符串**；写成 `title: [..]` 会 `error: expected string or array, found content`
     直接编译失败（实测踩过，且会连带拦住整次部署）。不写则卡片退回文件夹名。
   - **副标题**：`subtitle:` 属于 `config-info`，A4 文档没有 → 卡片的描述行整行不渲染
     （见 §4「导航页」）；想让 A4 卡片也带一行说明，就在文档里写 `subtitle:` 是不行的，
     只能改模板或 workflow。
   - **字体**：A4 文档没有模板前言，需自己
     `#set text(font: ((name: "Inter", covers: "latin-in-cjk"), "Noto Sans CJK SC"), size: 11pt, lang: "zh", region: "cn")`，
     否则中文用回退字体（CI 里只保证这两个字体已安装）。
   - `#show regex(...)` 那条 CJK 缩放**不是必需**，A4 想要中英视觉平衡也可照加；
     字号走 11pt 左右（放映稿才是 20pt）。
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

### 三个 job

| job | 条件 | 权限 | 作用 |
| --- | --- | --- | --- |
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
  三处占位注释由 `awk` 替换：`SLIDES`（卡片列表）、`COUNT`（套数）、`META`（更新时间+提交号）。
  卡片数据来源：
  - **标题/副标题**：`sed` 从各 deck 的 `config-info(...)` 里取 `title:` / `subtitle:`，依次尝试
    `[..]` 单独成行 → 单行里的 `[..]` → `".."` 字符串写法；**跳过注释行**（否则
    `// title: [旧标题]` 会中选），单行模式要求键前面不是字母/下划线（否则 `subtitle:` 里的
    `title:` 会被贪婪匹配成标题——实测踩过）。
    两者回退策略**不同**：`title` 取不到就退回**文件夹名**；`subtitle` 取不到（没写、
    `subtitle: []`、或 A4 文档这种本来就没有 `config-info` 的）则**整行都不渲染**，
    不再塞一句默认文案（旧版是一句「点击卡片在线预览…」，已移除——缺副标题的卡片宁可少一行，
    也不要一句与内容无关的话）。注意 `subtitle: []` 也走「不渲染」，没法用它保留空行。
    实现上 `desc_html` 变量里**只放标签、不放换行**：换行由模板那一行提供，否则空串时会把下一行
    顶走、在卡片中间留下纯空格行；另外别把变量写在行首，YAML 的块标量会因此提前结束（已踩）。
  - **链接与文件名**：`<文件夹名>.pdf`（与 `title` 无关）；大小由 `wc -c` 换算，
    分 B / KB / MB 三档（不足 1 MiB 时封顶 1023，避免出现 "1024 KB"）。
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
- **首页主题策略**：默认**跟随系统** `prefers-color-scheme`，在 `matchMedia` 的 `change`
  事件里实时切换（同时保留 `addListener` 分支兼容老 Safari）。用户点过右上角按钮才写
  `localStorage.theme`，此后以手动选择为准、系统再变也不动。监听器**故意不摘除**：它可重入、
  有 `saved` 就早退，而在点击回调里 `removeEventListener` 会在回调执行到一半时把自己摘掉，
  容易写出竞态。想恢复「跟随系统」清掉本站 localStorage 即可。
  `:root`/`.dark` 变量与太阳/月亮图标都只由 `html.dark` 这一个类驱动，所以「跟随系统」和
  「手动切换」走同一套状态；手动覆盖时 JS 再用行内 `color-scheme`（优先级高于样式表里
  `html` / `html.dark` 两条兜底）让表单控件与滚动条一起变。
  按钮的 `aria-pressed`/`aria-label`/`title` 必须跟主题一致，但 `<head>` 里那段防闪白脚本
  执行时按钮还没解析出来 → 首屏这次对齐放在 `DOMContentLoaded`，系统主题变化时再同步一次；
  切换结果通过 `#themeStatus`（`role="status"`）播报。无 JS 时没有 `.dark`，页面恒为浅色，
  内容与链接不受影响。
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
- `build` 与 `release` 都有 `if: github.event.deleted != true` 防护：
  **删除 tag/分支同样会产生 push 事件**，没有这个防护，删掉 `v2026.09.30` 后工作流会
  判定该版本不存在而把它重新创建出来。

### 运维备忘

- **换默认分支**（比如 `main` → `master`）要一起改 workflow 里**全部 5 处**：顶部的
  `branches:` 触发器，3 处 `if`（`build` 的 `run` 里、`deploy`、`release`），
  以及增量编译判断里的 `[ "$GITHUB_REF" = "refs/heads/main" ]`。
  漏掉最后那处不会报错，但每次都退化成全量编译。用
  `grep -n 'branches:\|refs/heads/main' .github/workflows/build-and-deploy.yml` 全部找出来改。
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

# 查看线上状态
gh run list --repo tortrixx/slides
gh release list --repo tortrixx/slides
gh api repos/tortrixx/slides/releases --jq '.[].tag_name'
```

**本地预览首页**（模板 + 生成步骤）：

```bash
RUNNER_TEMP=/tmp/rt BUILD_DIR=build RELEASE_TZ=Asia/Shanghai \
  GITHUB_SHA=$(git rev-parse --short HEAD) bash /tmp/wf-scripts/build-5-*.sh
# 然后用无头 Chrome 截图看效果。两个坑：
#   1) headless 默认 prefers-color-scheme: dark —— 想截浅色要显式 remove("dark")
#   2) 入场动画带 fill-mode: both，t=0 时元素是 opacity:0 —— 截图前注入
#      .fade{animation:none;opacity:1}，否则截出一张空页
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
  --user-data-dir=/tmp/cprof --window-size=1100,1250 \
  --screenshot=/tmp/shot.png file:///path/to/index.html
```

## 6. 改 workflow 后的验证清单（务必执行）

CI 逻辑全在 YAML 的 `run: |` 里，改完不能只靠肉眼。推荐流程：

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
5. push 之后用 `gh run watch <id> --exit-status` 看结果，并用
   `gh api repos/.../actions/runs/<id>/logs`（zip 里的文件名可能不是 UTF-8，
   用 Python 的 `zipfile` 读，别用 macOS 的 `unzip`）核对：
   是否走了增量、Release 附件是否为最新。

## 7. 值得注意的坑（已踩过）

- `setup-typst` 的 `cache-dependency-path` **只接受单个可编译的 `.typ` 文件**，
  不支持通配符；cache miss 时它会 `typst compile` 这个文件来拉包。
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
- 首页目前只显示标题/副标题/大小；想要页数、封面缩略图或每套 deck 的自定义描述，
  可以在 index 生成步骤里扩展（页数可解析 PDF，缩略图可用 `typst compile --format png` 首先生成）。
- `fonts-noto-cjk-extra` 需要时加回即可（换更多中文字重）。
- 存储会随「每天一个 Release」线性增长：每次 Release 都保存一套完整 PDF 且不会自动清理。
  公开仓库的 Actions 存储免费，所以这是「慢」而不是「贵」的问题；真开始嫌大时，可以只上传
  本次重编的 PDF，或定期 `gh release delete --cleanup-tag` 清掉旧的日期版本。
- `setup-typst@v5` 与 `softprops/action-gh-release@v3` 目前按主版本号引用（可读性好、自动收补丁）。
  若要更强的供应链保证，可以把这两个第三方 action 固定到 commit SHA，并让 Dependabot 升级。
- 首页的标题层级：`h1` 是标语，`h2` 是 `Slides`；改动时别把唯一的主标题弄丢。

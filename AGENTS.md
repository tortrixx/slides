# AGENTS.md

给在本仓库工作的 AI agent（以及未来的维护者）的技术说明。
**面向使用者的精简说明在 [README.md](README.md)**，本文件放实现细节、约定和坑。

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

- 仓库：`tortrixx/slides`，默认分支 `main`
- 站点：<https://tortrixx.github.io/slides/>（Pages Source = GitHub Actions，已开启）
- 固定下载：`https://github.com/tortrixx/slides/releases/latest/download/<名称>.pdf`

## 2. 仓库结构

```
.
├── slides/
│   ├── intro/main.typ        # 完整模板：封面/目录/分节/#pause/中文/公式/pinit 标注
│   ├── example/main.typ      # 最小模板：同样的前言，内容最少
│   └── 26-09-30/             # 实际使用的 deck（自带 src/ 图片等资源）
│       ├── main.typ
│       └── src/
├── .github/workflows/
│   └── build-and-deploy.yml  # 全部自动化逻辑（唯一的 CI 文件）
├── index.template.html       # 站点首页模板（构建时注入幻灯片列表）
├── AGENTS.md                 # 本文件
├── README.md                 # 用户文档
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
3. **统一前言**（三份 deck 保持一致，改动时请同步）：

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
6. 主题切换：`themes.metropolis` → `themes.simple` / `themes.university` 等。
   注意 `themes.simple` 的封面必须写 `#title-slide[标题]`，metropolis 可以直接 `#title-slide()`。
7. 包版本固定：touying 0.8.0（要求 Typst ≥ 0.15.0）、numbly 0.1.0、pinit 0.2.2。
8. **文件夹名即 URL**：只允许 **汉字 / 字母 / 数字 / `.` / `_` / `-`**。编译步骤会检查，
   出现空格、引号、`&`、`#`、`?` 等字符会直接 `::error::` 并退出（避免坏链接、坏 HTML、
   坏 Markdown）。改名会改变 PDF 链接，等于换 URL，旧链接会 404。

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
  为 restore-keys 缓存 `build/`。编译脚本逐套判断：全量 / 缓存缺 PDF / 该目录在
  `git diff --name-only <BEFORE_SHA> <GITHUB_SHA> -- slides` 里出现过 → 重编，否则复用。
  最后清理「`slides/<名称>/main.typ` 已不存在」的残留 PDF。
  tag / release / 手动运行一律全量编译。
- **导航页**：`index.template.html` 是首页模板（版式/样式都在里面），workflow 只负责
  注入数据，产物 `build/index.html` 是**服务端渲染**的静态页（无 JS 也能看）。
  三处占位注释由 `awk` 替换：`SLIDES`（卡片列表）、`COUNT`（套数）、`META`（更新时间+提交号）。
  卡片数据来源：
  - **标题/副标题**：`sed` 从各 deck 的 `config-info(...)` 里取 `title:` / `subtitle:`，
    先按「键单独占一行」匹配，再按单行写法匹配（模式里要求键前面不是字母或下划线，
    否则 `subtitle:` 里的 `title:` 会被贪婪匹配成标题——实测踩过）；
    取不到时标题退回文件夹名、副标题退回一句默认文案。
  - **链接与文件名**：`<文件夹名>.pdf`（与 `title` 无关），大小由 `wc -c` 换算。
  - **转义**：文件夹名与标题/副标题都会做 HTML 转义（`&` `<` `>` `"`），
    文件夹名另有字符集护栏（见 §3.8），两道一起保证生成的 HTML 不会被名字搞坏。
  - 标题按**原文**显示：Typst 标记（`*粗体*`、反引号）不会被渲染，也不会被剥离。
- **首页视觉**：沿用 <https://github.com/tortrixx/tortrixx> 的设计语言（等宽字体、
  shadcn neutral 色阶、虚线网格背景、hover 光边框 BorderBeam、BlurFade 入场、
  localStorage 记忆深浅色）。改样式只动 `index.template.html`，不用碰 workflow。
  注意 `<meta charset>` 必须留在文件最前面——模板开头那段中文注释一旦挪到它前面，
  就会超出 1024 字节的编码探测窗口，页面会乱码。
  装饰性动效都做了降级：光带用 `@supports (offset-path: rect(...))` 包住（不支持就整条不显示，
  否则会在左上角糊一块渐变色），`prefers-reduced-motion: reduce` 时关闭淡入并隐藏光带，
  键盘焦点用 `:focus-visible` 描边。改 CSS 时请保留这些降级。
- **产物**：`slides-build`（普通 artifact，给 release job 下载）+ `github-pages`
  （`actions/upload-pages-artifact@v5`，给 deploy job）。`index.template.html` 在仓库根，
  不会进站点（只上传 `build/`）。

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

## 5. 常用命令

```bash
# 本地编译某套幻灯片（必须在它的目录里跑，相对路径才有效）
cd slides/intro && typst compile main.typ && typst watch main.typ

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
- **增量编译的判断只看 `slides/<名称>/` 是否在 diff 里**。所以改了「编译参数」（字体、
  `--font-path`、Typst 版本）或仓库级公共文件时，没动过的 deck 会继续复用缓存里的旧 PDF。
  这类改动之后，请到 **Actions → Caches** 删掉 `slides-build-main-*` 再跑一次，或随便
  碰一下那些 deck（例如给 `main.typ` 加个空行）。
- Release 说明里的站点链接是按「项目页」拼出来的（`<owner>.github.io/<repo>/`）。若以后
  换成自定义域名，这段（以及首页里的相对链接之外的地方）需要同步改。
- 首页的卡片标题是**纯文本**：deck 里 `title: [*粗体*]` 会原样显示星号，不会渲染成粗体。

## 8. 可能的后续改进

- 缓存 `@preview` 宏包：思路是在安装 Typst 前，把所有 `#import "@preview/..."` 行聚合到
  `$RUNNER_TEMP` 下的一个 `.typ` 文件，再把它交给 `cache-dependency-path`（该输入只认单个可编译文件）。
- 首页目前只显示标题/副标题/大小；想要页数、封面缩略图或每套 deck 的自定义描述，
  可以在 index 生成步骤里扩展（页数可解析 PDF，缩略图可用 `typst compile --format png` 首先生成）。
- `fonts-noto-cjk-extra` 需要时加回即可（换更多中文字重）。

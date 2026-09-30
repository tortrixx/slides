# slides

用 [Typst](https://typst.app/) + [Touying](https://github.com/touying-typ/touying) 写的幻灯片集合。
每套幻灯片放在 `slides/` 下的一个独立文件夹里，推送到 `main` 后由 GitHub Actions 自动：

1. 安装模板里用到的字体（Noto Sans CJK SC / Inter）；
2. 编译 `slides/*/main.typ` 为 PDF（只重编改动过的幻灯片）；
3. 生成导航页并部署到 **GitHub Pages**；
4. **自动发版本**：自动把版本号 +1 并创建 GitHub Release，把全部 PDF 作为附件传上去。

## 访问地址

| 内容 | 地址 |
| --- | --- |
| 首页（自动生成的导航页） | <https://tortrixx.github.io/slides/> |
| 单套幻灯片 | `https://tortrixx.github.io/slides/<文件夹名>.pdf` |
| 例如 | <https://tortrixx.github.io/slides/intro.pdf> |

> 文件名就是 `slides/` 下的文件夹名。`slides/intro/` 编译出来就是 `.../slides/intro.pdf`。

## 目录结构

```
.
├── slides/
│   ├── intro/main.typ        # 完整模板（metropolis + 中文 + pinit 标注）
│   ├── example/main.typ      # 最小模板（同样的设置，内容最少）
│   └── 26-09-30/             # 你自己的幻灯片（含 src/ 图片等资源）
│       ├── main.typ
│       └── src/
├── .github/workflows/
│   └── build-and-deploy.yml  # 全部自动化逻辑
├── build/index.html          # 不需要手动维护：构建时生成（已被 .gitignore 忽略）
└── README.md
```

约定只有一条：**`slides/<名称>/main.typ` 存在，就自动编译成 `<名称>.pdf`**。
没有 `main.typ` 的文件夹会被自动忽略，可以安全地放笔记、素材等。

## 首次启用（3 步）

### 1. 打开 GitHub Pages

仓库页面 → **Settings → Pages → Build and deployment → Source** 选择
**GitHub Actions**（不要选 "Deploy from a branch"）。

### 2. 推送代码

本目录**已经**初始化好 git 仓库，并把 `origin` 指向
`https://github.com/tortrixx/slides.git`，所以只需要：

```bash
git add -A
git commit -m "Add Typst slides and CI"   # 首次提交；之后改完再提交即可
git push -u origin main
```

（如果是一个全新的目录，则先执行：
`git init -b main`、`git remote add origin https://github.com/tortrixx/slides.git`。）

### 3. 等待自动构建

推送后到仓库的 **Actions** 标签页可以看到 “Build & Deploy Slides” 正在运行
（首次因为要下载中文字体，约 1～2 分钟）。完成后访问
<https://tortrixx.github.io/slides/> 即可看到导航页。

> 第一次部署完成后，如果 Pages 页面显示 404，等 1～2 分钟再刷新即可。

## 添加一套新幻灯片

```bash
mkdir -p slides/my-talk
cp slides/example/main.typ slides/my-talk/main.typ   # 从最小模板复制
# 然后编辑 slides/my-talk/main.typ，把标题、作者、内容改成你的
```

```bash
git add slides/my-talk
git commit -m "Add my-talk slides"
git push
```

推送后会自动编译出 `https://tortrixx.github.io/slides/my-talk.pdf`，并出现在首页列表里。
如果幻灯片要用图片，放在 `slides/my-talk/src/` 下，在 `main.typ` 中用相对路径引用：

```typst
#image("src/figure.png", width: 80%)
```

（工作流会先 `cd` 进幻灯片目录再编译，所以相对路径能正确解析。）

## 幻灯片模板

两份模板的设置完全一致，只有内容多少不同：

| 文件 | 说明 |
| --- | --- |
| `slides/intro/main.typ` | 完整模板：封面、目录、分节、`#pause`、中文、公式、pinit 重点标注 |
| `slides/example/main.typ` | 最小模板：同样设置，只有一页内容和一页结尾 |

统一设置包括：

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

// 中西文混排的视觉平衡：汉字 / 假名 / 中文标点缩到 0.9em，西文与公式保持 20pt
#show regex("[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\u{3000}-\u{303F}\u{FF00}-\u{FFEF}]"): set text(size: 0.9em)

#set heading(numbering: numbly("{1}.", default: "1.1"))
```

**关于最后那条 `#show regex(...)`**：同样 20pt 时，汉字的墨迹高度约为 Inter 大写字母的
1.28 倍，看起来会比西文「重」一圈。把它缩到 `0.9em`（汉字 18pt + 西文 20pt）后，
比值降到约 1.17，混排就自然了。实测：单页能放的要点从 14 条变成 16 条，公式和西文不受影响。

- 想更明显 → 改成 `0.85em`；想接近原样 → 改成 `0.95em`；
- 不想缩放 → 删掉这一行即可；
- 正则里的 `\u{3000}-\u{303F}`、`\u{FF00}-\u{FFEF}` 是中文标点（。、，：），不带上它们的话
  汉字缩小而标点不变，会显得标点特别大。

想换主题：把 `themes.metropolis` 换成 `themes.simple` / `themes.university` 等。
注意 `themes.simple` 的封面要写成 `#title-slide[标题]`，而 metropolis 可以直接写
`#title-slide()`。

## 本地编译 / 预览

```bash
cd slides/intro
typst compile main.typ        # 生成 main.pdf
typst watch main.typ          # 保存即自动重新编译
```

安装 Typst：`brew install typst`（macOS）或见 <https://github.com/typst/typst#installation>。
本地版本建议与工作流中的 `TYPST_VERSION` 保持一致（当前为 `0.15.1`）。

## 自动发版本（不需要手动打 tag）

每次推送到 `main` 且构建成功后，工作流会：

1. 取仓库里已有的 `vX.Y.Z` 标签中最大的那个，把 patch 号 +1（一个都没有就从 `v1.0.0` 开始）；
2. 用这个版本号自动创建 tag 和 GitHub Release（自动创建的 tag 指向本次构建的提交）；
3. 把 `build/` 下所有 PDF 作为附件上传。

所以正常开发只要 `git push`，不用管 tag：

| 你的操作 | 结果 |
| --- | --- |
| 第一次 push 到 `main` | 自动发 `v1.0.0` |
| 之后每次 push 到 `main` | 自动发 `v1.0.1`、`v1.0.2`… |
| 手动 `git tag v2.0.0 && git push origin v2.0.0` | 用你指定的 `v2.0.0` 发版本，不再自动 +1 |
| 在网页上编辑 / 发布 Release | 把最新的 PDF 补传到该 Release |

Release 标题就是版本号（例如 `v1.0.4`），附件是 `build/` 下的全部 PDF。

**Release 说明是自动生成的**，只在**新建**版本时写入（已存在的 Release 绝不会被改动，
所以你在网页上手写的说明不会被覆盖）。内容大致是：

```markdown
本次发布包含 build 下编译好的幻灯片，点击文件名可直接在线预览：

- [`26-09-30.pdf`](https://tortrixx.github.io/slides/26-09-30.pdf)
- [`example.pdf`](https://tortrixx.github.io/slides/example.pdf)
- [`intro.pdf`](https://tortrixx.github.io/slides/intro.pdf)

站点首页：<https://tortrixx.github.io/slides/>

**完整变更**：https://github.com/tortrixx/slides/compare/v1.0.3...v1.0.4

<sub>由 GitHub Actions 自动生成 · 提交 `ccfea2a`</sub>
```

## 增量编译（只重编改动过的幻灯片）

`build/` 目录会用 [actions/cache](https://github.com/actions/cache) 缓存下来，每次
推送到 `main` 时：

- 用 `git diff` 找出这次 push 改动了哪些 `slides/<名称>/`；
- **只重新编译这些幻灯片**，其余直接复用缓存里的 PDF；
- 缓存里缺的 PDF（首次运行、缓存被清理）会自动补编译，不会漏；
- 被删除或改名的幻灯片，残留的旧 PDF 会被自动清理，不会继续留在站点上。

tag 推送 / 发布 Release / 手动运行一律**全量编译**，保证发出去的是完整产物。
如果某次增量结果不符合预期，删掉缓存（**Actions → Caches**）再跑一次即可。

## 手动触发一次构建

**Actions → Build & Deploy Slides → Run workflow**，记得分支选择 `main`：

- 选 `main`：全量编译 + 部署 Pages；
- 选其它分支：只编译和上传产物，**不会**部署线上站点；
- 手动运行**不会**创建 Release。

## 字体（模板已自动安装）

模板里指定了两种字体，工作流在编译前会通过 apt 装好：

| 用途 | 字体 | 来源 |
| --- | --- | --- |
| 中文 | Noto Sans CJK SC | `fonts-noto-cjk` |
| 西文 | Inter | `fonts-inter` |
| 数学 | New Computer Modern Math | Typst 自带，无需安装 |

说明：

- 字体缺失**不会**让编译失败，但中文会缺字或回退，所以默认就装好；
- 为了加快构建，**没有**安装 `fonts-noto-cjk-extra`（它要额外下载约 145MB）。
  因此 `weight: "medium"` 之类的中间字重会回退到 Regular / Bold；
  确实需要更多中文字重时，把它加回 workflow 里「安装模板字体」那一步的列表即可；
- 纯英文仓库可以把 workflow 里「安装模板字体」整个步骤删掉，约省 1 分钟；
- 想用别的字体（思源黑体、霞鹜文楷、Fira Code…）：把字体文件放进仓库，
  例如 `fonts/`，然后给编译命令加 `--font-path`：

  ```yaml
  if (cd "$dir" && typst compile --font-path "$PWD/../../fonts" main.typ "$build_dir/$name.pdf"); then
  ```

  （`$PWD` 在 `cd` 之后展开，所以这两级 `..` 正好回到仓库根目录。）
- 也可以改用 [Fontist](https://www.fontist.org/) 之类的方式在 CI 里装字体。

## 工作流在做什么

`.github/workflows/build-and-deploy.yml` 分三个互相独立的 job，权限各自最小化：

| job | 触发条件 | 权限 | 作用 |
| --- | --- | --- | --- |
| `build` | 任何触发都会运行 | `contents: read` | 装字体、**增量**编译幻灯片、生成 `build/index.html`、上传产物 |
| `deploy` | `main` 分支的 push / 在 `main` 上手动运行 | `pages: write`, `id-token: write` | 部署 `build/` 到 GitHub Pages |
| `release` | push 到 `main` / 推送 `v*` tag / 发布 Release | `contents: write` | 计算版本号并创建 Release，上传全部 PDF |

触发条件：`push` 到 `main`、推送 `v*` tag、`release: published`、以及 `workflow_dispatch`。
`deploy` 用固定的 `pages` concurrency group 串行化，`release` 用每个 tag 一个 group，
避免并发冲突。

## 常见问题

**推送后没有触发构建？**
检查默认分支名是不是 `main`。若是 `master`，把 workflow 里的
`branches: [main]` 和两个 `if` 里的 `refs/heads/main` 一起改成 `master`。

**Actions 里 `deploy` 失败，提示 Pages 未启用？**
回到 **Settings → Pages**，把 Source 设成 **GitHub Actions** 再重新运行。

**某套幻灯片编译失败？**
`deploy` 和 `release` 都会跳过（不会发布残缺的站点），错误日志里会直接指出
是哪个目录的 `main.typ` 出错。先按日志里的行列号修好再推送。

**想推送任意 tag 都能发 Release？**
把 workflow 里的 `tags: ["v*"]` 改成 `tags: ["**"]`（匹配所有 tag）。

**不想每次 push 都自动发版本？**
把 `release` job 的 `if:` 里 `(github.event_name == 'push' && github.ref == 'refs/heads/main')`
这一段删掉，就回到「只有手动 tag / 发布 Release 才发版本」。

**想改版本号规则（比如按日期）？**
改 `release` job 里「计算版本号」那一步：把 `tag="v${major}.${minor}.$((patch + 1))"`
换成比如 `tag="v$(date -u +%Y.%m.%d)-${GITHUB_RUN_NUMBER}"` 即可。

**`build/` 目录需要提交吗？**
不需要，它由 CI 生成，已在 `.gitignore` 中忽略。

## 进阶

### 缓存 `@preview` 宏包（加快构建）

`setup-typst` 的 `cache-dependency-path` 只接受**单个可编译的 `.typ` 文件**（不支持通配符）。
可以在 `build` job 里自动聚合所有宏包导入行，然后交给它缓存 —— 顺序必须是先生成清单、
再安装 Typst：

```yaml
      - name: 生成宏包依赖清单（缓存用）
        run: |
          mkdir -p "$RUNNER_TEMP/typst-deps"
          grep -rhoE --include='*.typ' '^#import "@preview/[^"]+"' slides \
            | sort -u > "$RUNNER_TEMP/typst-deps/requirements.typ"
          [ -s "$RUNNER_TEMP/typst-deps/requirements.typ" ] || echo '// no preview packages' > "$RUNNER_TEMP/typst-deps/requirements.typ"

      - name: 安装 Typst
        uses: typst-community/setup-typst@v5
        with:
          typst-version: ${{ env.TYPST_VERSION }}
          cache-dependency-path: ${{ runner.temp }}/typst-deps/requirements.typ
```

### 换 Typst 版本

改 workflow 顶部的 `TYPST_VERSION`（`env` 里那行）即可，也可以写成 `latest`。
注意与 Touying 的兼容性：`@preview/touying:0.8.0` 要求 Typst ≥ 0.15.0。

### 自定义首页样式

首页 HTML 由 workflow 里「生成导航页」那一步的 heredoc 生成，直接改里面的
`<style>` 即可；若想让每套幻灯片显示中文标题而不是文件夹名，可以自己维护一份
标题映射表并替换生成逻辑。

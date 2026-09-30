// =============================================================================
// 幻灯片模板（metropolis 主题）—— 复制这个文件夹即可新建一套幻灯片
// -----------------------------------------------------------------------------
// 本地预览：  cd slides/intro && typst compile main.typ     （生成 main.pdf）
//             cd slides/intro && typst watch main.typ       （保存即重新编译）
// 线上：      CI 编译成 build/intro.pdf
//             → https://tortrixx.github.io/slides/intro.pdf
//
// 模板要点（与仓库其它幻灯片保持一致）：
//   * 中西文混排：Inter 负责西文，Noto Sans CJK SC 负责中文
//   * 数学公式：New Computer Modern Math（Typst 自带）
//   * 标题编号：numbly
//   * 重点标注：pinit
// 这些字体在 GitHub Actions 里由 workflow 自动安装，详见 README「中文字体」。
// =============================================================================

#import "@preview/touying:0.8.0": *
#import themes.metropolis: *
#import "@preview/numbly:0.1.0": numbly
#import "@preview/pinit:0.2.2": *

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [幻灯片标题],
    subtitle: [副标题写在这里],
    author: [Your Name],
    date: datetime.today(),
    institution: [Your Institution],
  ),
)

#set text(
  font: (
    (name: "Inter", covers: "latin-in-cjk"),
    "Noto Sans CJK SC",
  ),
  weight: "regular",
  size: 20pt,
  lang: "zh",
  region: "cn",
)

#show math.equation: set text(font: "New Computer Modern Math")

#set heading(numbering: numbly("{1}.", default: "1.1"))

// ========== 封面 ==========
#title-slide()

// ========== 目录 ==========
= 目录 <touying:hidden>
#outline(title: none, indent: auto, depth: 1)

// ========== 第一节 ==========
= 开始使用

== 一套幻灯片 = 一个文件夹

`slides/<文件夹名>/main.typ` 会被自动编译成 `<文件夹名>.pdf`：

```text
slides/intro/main.typ    ->  build/intro.pdf
slides/example/main.typ  ->  build/example.pdf
```

推送到 `main` 分支后，它们会出现在首页
#link("https://tortrixx.github.io/slides/")[tortrixx.github.io/slides]。

#pause

== 中文、西文与公式

中文由 Noto Sans CJK SC 渲染：智能体、强化学习、马尔可夫决策过程。

西文与数学由 Inter + New Computer Modern Math 渲染：

$ V^pi(s) = E_pi[G_t | s_t = s] $

#pause

== 用 pinit 做重点标注

#pin(1)关键结论可以直接高亮#pin(2)，并在旁边加一句解释。

#pinit-highlight(1, 2, fill: rgb(0, 180, 255).transparentize(65%))
#pinit-point-from(
  fill: rgb(0, 180, 255),
  pin-dx: 0em,
  pin-dy: 0.35em,
  body-dx: 8pt,
  body-dy: 0.2em,
  offset-dx: 12pt,
  offset-dy: 1.6em,
  2,
  [
    #set text(fill: rgb(0, 180, 255), size: 0.82em, weight: "medium")
    这里是标注说明
  ],
)

// ========== 第二节 ==========
= 下一步

== 换成你自己的内容

1. 复制 `slides/intro/` 整个文件夹并重命名
2. 修改上面的 `config-info(...)` 和正文
3. `git push`，等待 Actions 编译并部署

#focus-slide[
  谢谢！

  有问题欢迎提问
]

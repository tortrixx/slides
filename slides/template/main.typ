// =============================================================================
// 幻灯片模板（metropolis 主题）—— 复制这个文件夹即可新建一套幻灯片
// -----------------------------------------------------------------------------
// 本地预览：  cd slides/template && typst compile main.typ     （生成 main.pdf）
//             cd slides/template && typst watch main.typ       （保存即重新编译）
// 线上：      CI 编译成 build/template.pdf
//             → https://tortrixx.github.io/slides/template.pdf
//
// 这份文件既是*可直接复制的骨架*，也是*用法速查*：
//   * 第 1 节 全部是样板设置，照抄即可，一般不用改；
//   * 第 2 节的每一页演示一种写法，改成你自己的内容就行；
//   * 第 3 节讲主题、字号等定制选项；
//   * 第 4 节是新建一套幻灯片的清单。
// 想让文件更小：第 2～4 节整段删掉，只留封面和前言即可（前言不要动）。
// 仓库约定与踩坑记录见根目录的 AGENTS.md，用户向说明见 README.md。
// =============================================================================

#import "@preview/touying:0.8.0": *
#import themes.metropolis: *
#import "@preview/numbly:0.1.0": numbly
#import "@preview/pinit:0.2.2": *

// config-info 里的元信息会同时用于封面页和首页卡片：
// 首页卡片取的是 title / subtitle 这两项，副标题不写就不显示那一行（见 AGENTS.md）。
#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [幻灯片标题],
    subtitle: [副标题写在这里],
    author: [你的名字],
    date: datetime.today(),
    institution: [你的机构],
  ),
  // footer-progress: false,   // 去掉底部进度条
)

// 中西文混排：Inter 负责西文，Noto Sans CJK SC 负责中文
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

// 数学公式用 Typst 自带的 New Computer Modern Math
#show math.equation: set text(font: "New Computer Modern Math")

// 中西文混排：不加任何 show 规则，汉字和西文都用 20pt、共用同一条基线。
// 这是「默认」情形，也是目前选定的方案。历史上试过两种「平衡」写法，都不用了：
//   * `set text(size: 0.9em)` —— 缩字号。汉字块头是小了，但墨迹底线比拉丁基线低约
//     1.4pt/20pt，中文看着往下掉、和西文对不齐；
//   * `set text(size: 1em, baseline: -0.08em)` —— 抬基线把底线拉平。量出来是齐的，
//     但汉字会整体上浮，读起来仍别扭。
// 结论：让 Typst 用字体自己的度量最稳。要调字号就改上面 `#set text` 里的 size
// （会影响全篇），或者只在某一页用 `#slide[#set text(size: 18pt) ...]` 局部覆盖。

// 标题编号：一级 "1."、二级 "1.1"
#set heading(numbering: numbly("{1}.", default: "1.1"))

// =============================================================================
// 1. 框架页：封面 + 目录
// =============================================================================

#title-slide()

// 目录页的标题 <touying:hidden> 表示它不参与编号、也不进目录自己
= 目录 <touying:hidden>
#outline(title: none, indent: auto, depth: 1)

// =============================================================================
// 2. 常用写法：每页演示一种，改成你的内容即可
// =============================================================================

= 快速开始

== 一个文件夹就是一套幻灯片

`slides/<文件夹名>/main.typ` 会被自动编译成 `<文件夹名>.pdf`：

```text
slides/template/main.typ   ->  build/template.pdf
slides/my-talk/main.typ    ->  build/my-talk.pdf
```

推送到 `main` 之后，它们会出现在首页
#link("https://tortrixx.github.io/slides/")[tortrixx.github.io/slides]，
并按当天日期发布一个 Release。

文件夹名直接用进 URL，只允许*汉字 / 字母 / 数字 / `.` / `_` / `-`*，
不要空格和其它符号，否则 CI 会直接报错让你改名。

== 标题、列表与强调

`= 一级标题` 开新的一节，`== 二级标题` 留在同一节里。

正文用 `*粗体*`、`_斜体_`、`` `等宽` ``、`#link("https://typst.app")[链接]`。

- 无序列表用 `-` 或 `+`
- 需要强调的结论放在这里
  - 缩进两个空格就是第二层
+ 有序列表用 `1.` `2.`（实际写 `+` 让 Typst 自动编号）

> 引用块用 `>` 开头，适合放定义或别人的话。

== 公式

行内公式写 $E = m c^2$，独立成行的公式用 `$ ... $` 并前后留空行：

$ V^pi(s) = E_pi[G_t | s_t = s] $

多行对齐用 `&` 对齐、`\\` 换行（源码里要写成两个反斜杠）：

$ C_t &= R_(t+1) + gamma R_(t+2) + dots.c \
      &= sum_(k=0)^oo gamma^k R_(t+k+1) $

公式里的西文与符号不会被上面那条 CJK 缩放影响，字号仍是 20pt。

== 代码

```python
def greet(name):
    return f"Hello, {name}!"
```

```bash
cd slides/my-talk && typst watch main.typ
```

语言名写在三个反引号后面；不写语言就没有高亮。
需要在正文里用等宽小块，写 `` `反引号` `` 即可。

== 图片

图片放在*这套幻灯片自己的目录*下，用相对路径引用：

```typst
#image("src/figure.png")
```

两条硬性约定：

1. 相对路径是相对 `main.typ` 所在目录，不是仓库根目录；
2. 不要用 `../` 跨出文件夹 —— CI 会报 `would escape the project root`。

== 左右分栏

两段并排用 `#cols`，列宽可以自己定：

#cols(columns: (1fr, 1fr))[
  *左边这一栏*

  - 第一个要点
  - 第二个要点
][
  *右边这一栏*

  - 第一个要点
  - 第二个要点
]

需要 2:1 这种不等宽，写成 `#cols(columns: (2fr, 1fr))` —— 列数/列宽都得走具名参数。

== 分步显示与重点标注

`#pause` 把一页拆成多张「子页」：它*后面*的内容要讲到才出现，标题不变。

#pause

这一行是 `#pause` 之后才出现的，讲的时候按一次空格出现一批。

#pause

反过来，`#pause` 放在整页的最后没有意义 —— 它后面没有内容可藏，只会多出一张空白的子页。

== 重点标注

重点标注用 pinit：#pin(1)关键结论可以直接高亮#pin(2)，并在旁边加一句解释。

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

== 整页强调

`#focus-slide` 会生成一张只有一句话的整页幻灯片，适合放在章节之间或结尾：

```typst
#focus-slide[
  谢谢！
]
```

本文件末尾就有一张。

// =============================================================================
// 3. 主题与版式定制
// =============================================================================

= 定制

== 换主题

幻灯片主题都是「换掉开头两行、正文不动」：

```typst
#import themes.university: *
#show: university-theme.with(aspect-ratio: "16-9", config-info(..))
```

可以直接替换的有 `metropolis`（当前）、`university`、`dewdrop`、`stargazer`、`aqua`，
这五个的封面都写 `#title-slide()`。

`simple` 要多改一处：它的封面要求写成 `#title-slide[标题]`，直接写 `#title-slide()`
会报 `missing argument: body`。

另外两个不要往这里套：`default` 只导出 `slide` 之类的构件、没有主题函数；`article` 是
连续排版的 A4 文章主题，给讲义/论文用（见 AGENTS.md §3.9），不是放映稿主题。

== 字号与页面比例

正文默认 20pt（metropolis 的默认值，前面为了可读性显式写出来了）。
*内容特别密*的单页做局部覆盖，不要全局改小：

```typst
#slide[#set text(size: 18pt)
  ...
]
```

比例在 `metropolis-theme.with(aspect-ratio: ...)` 里，可选 `"16-9"`（当前）
或 `"4-3"`。

页脚右下角默认显示 `当前页 / 总页数`（封面和分节页不显示），由 `footer-right` 控制；
不想要就加 `footer-right: none`。底部那条进度条是另一个开关，
连它一起去掉写 `footer-progress: false`。

// =============================================================================
// 4. 新建一套幻灯片的清单
// =============================================================================

= 新建一套

== 清单

1. 复制整个文件夹：`cp -R slides/template slides/my-talk`
2. 改 `config-info(...)` 里的标题、副标题、作者、机构
3. 删掉第 2～4 节，写你自己的内容；图片放到 `slides/my-talk/src/` 下
4. 本地预览：`cd slides/my-talk && typst watch main.typ`
5. `git push` —— Actions 会自动编译、更新站点，并按当天日期发版

不用打 tag、不用写 Release 说明；只有改动过的幻灯片会重新编译。

// =============================================================================
// 5. 结尾（演示 focus-slide；同样用 <touying:hidden> 让它不进目录、不占编号）
// =============================================================================

= 结尾 <touying:hidden>

#focus-slide[
  谢谢！

  有问题欢迎提问
]

// tortrixx/slides · 仓库约定见 AGENTS.md

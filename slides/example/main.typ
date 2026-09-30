// =============================================================================
// 最小模板（metropolis 主题）—— 想快速开始就用这一份
// -----------------------------------------------------------------------------
// 本地预览：  cd slides/example && typst compile main.typ
// 线上：      CI 编译成 build/example.pdf
//             → https://tortrixx.github.io/slides/example.pdf
//
// 这里保留了仓库统一的设置（中西文字体、公式字体、标题编号、pinit 标注），
// 正文只留最少的内容，方便你直接替换。
// 如果你更喜欢简洁风格：把下面两行主题换掉即可
//   #import themes.simple: *
//   #show: simple-theme.with(...)     注意 simple 主题的封面要写 #title-slide[标题]
// =============================================================================

#import "@preview/touying:0.8.0": *
#import themes.metropolis: *
#import "@preview/numbly:0.1.0": numbly
#import "@preview/pinit:0.2.2": *

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [最小示例],
    subtitle: [Minimal Touying deck],
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

// 中西文混排的视觉平衡：同样 20pt 时汉字会显得比西文「重」一圈，
// 所以把汉字 / 假名 / 中文标点缩到 0.9em（20pt → 18pt），西文与公式保持 20pt。
// 想更明显改成 0.85em，想更接近原样改成 0.95em。
#show regex("[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\u{3000}-\u{303F}\u{FF00}-\u{FFEF}]"): set text(size: 0.9em)

#set heading(numbering: numbly("{1}.", default: "1.1"))

#title-slide()

= 第一节

== 要点

- 这是最小可用的模板，把这段换成你的内容
- 图片放在 `src/` 下，用相对路径引用：`#image("src/figure.png")`
- 需要分步显示时插入 `#pause`

#pause

这一行是 `#pause` 之后才出现的。

== 代码与公式

```python
def greet(name):
    return f"Hello, {name}!"
```

#align(center)[$ E = m c^2 $]

#focus-slide[
  谢谢！
]

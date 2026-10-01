# 资源目录

把图片、PDF 等素材放在这个目录里，在 `../main.typ` 中用相对路径引用，例如：

```typst
#image("src/figure.png")
```

两条硬性约定（见仓库根目录的 AGENTS.md §3.2）：

1. 相对路径是相对 `main.typ` 所在目录，不是仓库根目录；
2. 不要用 `../` 跨出本文件夹 —— CI 编译时会把本文件夹当作项目根，
   跨出去会报 `would escape the project root`。

新建一套幻灯片时用 `cp -R slides/template slides/我的主题`，这个目录会一起复制过去。

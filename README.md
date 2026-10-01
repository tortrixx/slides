# slides

用 [Typst](https://typst.app/) + [Touying](https://github.com/touying-typ/touying) 写的幻灯片集合。

在线浏览：<https://tortrixx.github.io/slides/>

| 幻灯片 | 说明 |
| --- | --- |
| [template](slides/template/main.typ) | 模板：复制它开始写新的一套，也是各类写法的示例 |
| [26-09-30](slides/26-09-30/main.typ) | Intelligent Agents — From Theory to Modern AI Systems |

每套幻灯片是 `slides/` 下的一个文件夹，名下的 `main.typ` 就是内容。
文件夹名请只用**汉字 / 字母 / 数字 / 点 / 下划线 / 连字符**，不要空格和引号 ——
它会直接变成 URL（`slides/<文件夹名>.pdf`），带了别的字符 CI 会直接报错让你改名。

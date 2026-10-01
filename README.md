# slides

用 [Typst](https://typst.app/) + [Touying](https://github.com/touying-typ/touying) 写的幻灯片集合。
每套幻灯片是 `slides/` 下的一个文件夹；推送到 `main` 后 GitHub Actions 会自动编译 PDF、
更新站点，并按当天日期发一个 Release。

## 地址

| 内容 | 地址 |
| --- | --- |
| 首页（自动生成的导航页） | <https://tortrixx.github.io/slides/> |
| 单套幻灯片 | `https://tortrixx.github.io/slides/<文件夹名>.pdf` |
| 固定下载地址（永远最新） | `https://github.com/tortrixx/slides/releases/latest/download/<文件夹名>.pdf` |

## 写一套新幻灯片

```bash
cp -R slides/template slides/my-talk
# 编辑 slides/my-talk/main.typ，把标题、作者、内容改成你的
git add slides/my-talk && git commit -m "add my-talk" && git push
```

约 1 分钟后即可在 `https://tortrixx.github.io/slides/my-talk.pdf` 和首页列表里看到。

`slides/template` 既是骨架也是用法速查：标题与列表、公式、代码、图片、`#cols` 分栏、
`#pause` 分步、pinit 标注、`#focus-slide`、换主题都有示范；
想先看效果，直接打开 <https://tortrixx.github.io/slides/template.pdf>。

图片放在 `slides/my-talk/src/`，正文里用相对路径引用：`#image("src/figure.png")`。

> 新建时用 `cp -R` 连整个文件夹一起复制（别只拷 `main.typ`），这样资源目录也会一起带上。

> 文件夹名请只用**汉字 / 字母 / 数字 / 点 / 下划线 / 连字符**，不要空格和引号。
> 它会直接变成 URL（`<文件夹名>.pdf`），带了别的字符 CI 会直接报错让你改名。

## 本地预览

```bash
cd slides/my-talk
typst watch main.typ          # 保存即自动重新编译；typst compile main.typ 只编译一次
```

Typst 的安装见[官方说明](https://github.com/typst/typst#installation)，本仓库用 0.15.1。
中文字体（Noto Sans CJK SC、Inter）CI 会自动装好；本地没装也能编译，只是中文会回退。

## 发版规则

- **日常 `git push` 就够了**：自动用当天日期创建/更新 Release（如 `v2026.09.30`），
  同一天多次 push 只刷新同一个 Release，不用打 tag、不用写说明；
  跨天会自动新建一个日期版本。
- **想要一个正式快照**：`git tag v2.0.0 && git push origin v2.0.0`。

## 常见问题

**推送后没有触发构建？**
默认分支不是 `main` 的话，要把 workflow 里**全部 5 处**一起改掉：`branches: [main]`，
以及 4 处 `refs/heads/main`（3 处在 `if`，1 处在 `run:` 的增量判断里——漏掉它会导致
每次都全量编译，不会报错但会明显变慢）。

**`deploy` 报错说 Pages 未启用？**
Settings → Pages → Build and deployment → Source 选 **GitHub Actions**。

**某套幻灯片编译失败？**
站点和 Release 都会跳过，不会发布残缺内容；日志里会指出是哪个 `main.typ` 出错，修好再推。

**`build/` 目录要提交吗？**
不用，它由 CI 生成，已在 `.gitignore` 中忽略。

---

工作流内部实现（增量编译、字体、发版细节、改动后的验证方法）见 [AGENTS.md](AGENTS.md)。

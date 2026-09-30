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
mkdir -p slides/my-talk
cp slides/example/main.typ slides/my-talk/main.typ   # example 是最小模板，intro 是完整模板
# 编辑 slides/my-talk/main.typ，把标题、作者、内容改成你的
git add slides/my-talk && git commit -m "add my-talk" && git push
```

约 1 分钟后即可在 `https://tortrixx.github.io/slides/my-talk.pdf` 和首页列表里看到。
图片放在 `slides/my-talk/src/`，正文里用相对路径引用：`#image("src/figure.png")`。

> 文件夹名请只用**汉字 / 字母 / 数字 / 点 / 下划线 / 连字符**，不要空格和引号。
> 它会直接变成 URL（`<文件夹名>.pdf`），带了别的字符 CI 会直接报错让你改名。

不想写幻灯片、只想放普通 A4 讲义？同样放在 `slides/<名称>/` 下即可，见后面「用 A4 文档」一节。

## 用 A4 文档（不套 Touying 模板）

不写幻灯片也行：`slides/<名称>/main.typ` 只要能编译出 PDF，就会被编译、上线、自动更新。
A4 讲义、读书笔记、论文式文档可以和 Touying 放映稿混在同一个仓库里。

最小可用的 A4 模板：

```typst
#set document(title: "线性代数讲义")   // 字符串，不是 [...]，会显示成首页卡片标题
#set page(paper: "a4", margin: (x: 2.2cm, y: 2cm), numbering: "1")
#set text(
  font: ((name: "Inter", covers: "latin-in-cjk"), "Noto Sans CJK SC"),
  size: 11pt, lang: "zh", region: "cn",
)
#set heading(numbering: "1.")

= 第一章 线性方程组

正文……
```

三件要知道的事：

1. **`title:` 必须写成字符串**。写成 `title: [线性代数讲义]` 会直接编译失败
   （`expected string or array, found content`）。不写 `title:` 也能跑，只是卡片上显示文件夹名。
2. **副标题没有对应字段**。`subtitle:` 是 Touying `config-info` 的字段，A4 文档没有，
   卡片会退回到默认提示文案。
3. **字体要自己设**。CI 里已经装好 Noto Sans CJK SC 和 Inter，但不写上面那段 `#set text(...)`，
   中文会用回退字体。

Touying 模板里那条中文缩放的 `#show regex(...)` 对 A4 文档**不是必需**的，
想要中英视觉平衡也可以照加。其余自动化（增量编译、按日期发版、首页列表）一视同仁；
唯一的共同约束是：任何一份文档编译失败都会拦住整次部署。

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

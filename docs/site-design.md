# 站点视觉与前端设计（docs/site-design.md）

`index.template.html` 的全部设计依据：历史方案对比、像素级测量数据、外部规范依据、降级策略。
**改样式前读 AGENTS.md §4 的「站点视觉与前端」摘要通常就够了**；这份文档回答「为什么是现在这样」——
推翻任何一条现行约定之前，先来这里核对它当年是怎么定下来的（多数替代方案被实测否决过）。
2026-10-11 从 AGENTS.md §4 拆出，条目内容未改动。

---

- **首页视觉**：沿用 <https://github.com/tortrixx/tortrixx> 的设计语言（等宽字体、
  shadcn neutral 色阶、虚线网格背景、hover 光边框 BorderBeam、BlurFade 入场、
  深浅色主题）。改样式只动 `index.template.html`，不用碰 workflow。
  注意 `<meta charset>` 必须留在文件最前面——模板开头那段中文注释一旦挪到它前面，
  就会超出 1024 字节的编码探测窗口，页面会乱码。
  装饰性动效都做了降级：光带用 `@supports (offset-path: rect(...))` 包住（不支持就整条不显示，
  否则会在左上角糊一块渐变色），`prefers-reduced-motion: reduce` 时关闭淡入并隐藏光带，
  键盘焦点用 `:focus-visible` 描边。改 CSS 时请保留这些降级。
  两处**对着原站量过**的地方（2026-10，用户对照 <https://tortrixx.pages.dev/> 提的）：
  - **顶栏 = 头像 + 主标题（h1）+ 右上角按钮，一行（≥640px；窄屏纵向堆叠）；页面没有标语，也没有区块 h2**（2026-10 定稿）：
    原来这里是「头像 + 标语 `Less noise, more signal.`」一行，下面再单独一行 `h2 Slides`。
    去掉标语的理由：① 那是原站（个人主页）的座右铭，对这一页不携带任何信息；
    ② 这一页只有一个区块，"标识行 + 区块标题行"两行在说同一件事，本来就冗余；
    ③ 把 `Slides` 提上来当 `h1` 之后**语义更好** —— h1 说的是这一页到底是什么，
    而标语当 h1 属于"没说出页面主题"。
    **别把唯一的 h1 弄丢**（无 h1 对读屏和搜索都不友好），要改标题名就改 `.page-title` 这一处；
    以后若按年/主题分组，每组再用 `h2`（字号 1.125rem 一档、比主标题小），别把主标题降级。
    用户如果哪天真想留这句标语，正确的位置是**页脚**（一行小字），不要放回顶栏。
    头像跟着从 80px 改到 64px（`img` 的 `width`/`height` 属性要一起改）：一行里它和 1.5rem 的
    标题按居中对齐，80px 会显得头重。
    **主标题不带任何装饰**（不加下划线、不加边框）：参考站全站没有一处 `underline`（它的 h1 就是
    `text-xl font-bold`，2026-10 拉下它的 HTML 核过），而这里标题下方已经有 `.head-row` 的通栏
    `border-bottom` 收口，再加下划线是重复装饰。
    顺带一个**踩过的真坑**（用户报"Slides 和 2 都带下划线"）：`.page-title` 是 flex 容器，里面的
    `.count` 作为 flex item 会被 **blockify**（`inline-block` → `block`），于是它不再是「原子内联
    后代」，而 **祖先的 `text-decoration` 会传播进后代、后代自己写 `text-decoration: none` 是撤不掉
    的** —— 所以下划线会画到计数胶囊下面去（无头 Chrome 3× 截图可见）。两条出路：要么别给标题加
    下划线（现在的选择），要么把文字包进内层 `<span class="pt-text">` 再把下划线加在它身上。
    别指望 `.count` 自己那条 `display: inline-block` 能挡住传播 —— 它只在父级**不是** flex/grid
    容器时才有效。
    **标题旁的套数胶囊也删了**（2026-10 用户提的，`.count` 那条 CSS 跟着一起删，模板里现在只剩
    一段「当年怎么写」的注释）：计数的价值在于「概括你看不到的东西」——GitHub 那种 tab 计数概括的
    是**筛选后的子集**（Open 12 / Closed 30），而我们这个数字概括的就是你正在看的这一页，
    跟逐条数一遍是同一件事；**放页脚也不行**：读到页脚时列表早看完了，那时它更没用。
    真要恢复：h1 里加回套数 span + 把 `.count` 规则写回模板（注释里留了原文），
    **workflow 不用动** —— `COUNT` 的 `awk` 替换规则一直留着（也见下面「导航页」那节里
    「别在模板里写占位符原文」那个坑）。
  - **字重：两处都写 `500`（意图 medium），不要写 600**（2026-10 定稿；用户前后提过两次 ——
    先是「照着原站把标语/标题加粗一点」，看到效果后又说「加粗有点过了、每个 pdf 的标题也不能过粗」）：
    原站那两处写的是 `font-medium`(500)，它看着真的是 medium，是因为它**自带 Roboto Mono Variable**
    （`@font-face` 里 `font-weight: 100 700`）。本页走系统等宽字体栈（`ui-monospace` → SF Mono /
    Menlo / Consolas…），无头 Chrome 实测（macOS，3× 放大、20px/18px 两个真实字号）：
    **400 与 500 渲染完全一致、600 与 700 都画出粗体且彼此一致** —— 这套字体只有 regular + bold
    两档，**"medium" 这一档根本不存在**。
    所以：写 600 等于 bold（用户觉得过了），写 500 在本机落 regular，但在**有自变量字体**的环境里
    会自然落到真正的 medium —— 写 500 表达的是**意图**，两个方向都不吃亏。
    层级由此改由**字号 + 颜色**承担：h1 24px / 行标题 18px / 副标题 14px / 元信息 12px，
    颜色只用「纯黑 vs muted」两级。**别再改回 600**（在当前环境里就是 bold）。
    想连字形一起 100% 复刻原站的真实 medium，唯一办法是把它那份
    `roboto-mono-*-wght-normal.woff2` 自持进 `assets/`：加 `@font-face`（`font-weight: 100 700`）、
    把 `Roboto Mono` 放到字体栈最前，**并且改 workflow 的 assets 拷贝那一步**（现在是写死的
    `cp assets/icon.png …` + fail-closed 检查，不是通配）—— 改 YAML 会让下一次 push 全量重编。
    为这 ~30KB 暂时不做，路径记在这里：将来要做就是这三处（另外记得给门禁补一条产物断言）。
  - **列表版式：纯列表 + 两级分隔线（行线两端渐隐），行内不再有任何色条，也不显示日期**（2026-10 定稿）：
    历史是：① 每张卡一根粉条 → ② 红条挪到 `h2`、卡片竖条改中性灰 hover 变粉 → ③ 去掉色条、
    改成「左侧日期列 + 通栏细线」 → ④ 去掉日期列、分隔线做层级 → ⑤（现在）行线的两端改为渐隐、
    行距放大，**主标题（h1）的下划线去掉**（行标题仍保留 hover 下划线，见 `.deck:hover .deck-title`）。
    为什么最后全去掉：原站那根 `w-1.5 bg-red-400/60 group-hover:bg-red-400` 是**分组标题**的
    标记（<https://tortrixx.pages.dev/workspace> 整页 4 个分组 = 4 根，组内几十个 `<li>` 一根
    都不带），我们把它按行复制就等于把一个章节符号复印 N 份；而挪到 `h2` 后又只剩"装饰"一个
    理由（单组页面里它不携带信息，用户也不想要）。所以：**一行一根条、一页一根条都不要再加**。
    **日期为什么不上页面**（③ 那版的 `.lede` 列已删，用户提的）：它是「这套 deck 上一次提交」，
    不是内容本身的日期（改个错别字也会把它顶到最前，容易被读成"最新内容"）；而且要占一条
    5.6rem 的固定列、窄屏还得为它堆叠换行。顺序仍然是「最新在前」—— 日期只用于**构建时排序**
    （见下面「导航页」那节），不渲染。真想在页面上透出"新旧"，更轻的做法是给最近改过的行加个
    小圆点，**不要**恢复整列日期。
    分隔线做成**两级**（2026-10 用户提的「行线跟页眉那条一样，分不出来」，改了两轮）：
    * 页眉下面那条（`.head-row` 的 `border-bottom`）= **区块边界**：通栏、实线、`hsl(var(--border))`，
      两端到头；
    * 行与行之间（`.deck + .deck::before`）= **区块内的条目**：`height: 1px` + `background-image`
      的**两端渐隐**细线（`transparent → hsl(var(--border)) 12% → 88% → transparent`）。
    第一版是「两端各内缩 0.5rem + `hsl(var(--border) / 0.6)`」，问题是行线仍在跟页眉那条**比长短**
    （硬端点对硬端点），层级是黏的；改成渐隐后行线是"一段化开的毛发线"，跟通栏实线在**质感**上就分开了。
    顺带两处：行内边距放大到 `0.9375rem/0.875rem`（15px / 14px，为什么不是对称的见下条）、
    用伪元素而不是 `border-top`（`.deck` 是圆角盒子，
    `border-top` 会跟着圆角拐弯；而且渐变也画不进 border）。**别把它改回 `border-top`**。
    第三轮（2026-10，用户对着浅色截图提的「页眉线与下方 PDF 的间距、和 PDF 之间的间距不同，
    而且两条线显示效果也差不多」）—— 这一轮才把上面那两级真正做出来，量过之后的两条结论：
    * **两条线必须"重量"不同，不能只靠"长短/渐隐"区分**：页眉线改 `border-bottom: 2px`
      （行线仍是 1px）。两条都是 1px + 同色时，只有"两端渐隐"这点差别，放大到 2× 也几乎看不出来，
      页眉线看着跟行线就是同一级 —— 当初"靠质感分层"的想法在 1px 尺度上不成立。
    * **线的两侧留白也要不对称得对**：旧值 `.head-row` 的 `padding-bottom: 1rem` +
      `header` 的 `margin-bottom: 1.25rem` 让页眉线到第一行墨迹只有 **33.9px**，而行距是
      **23.5px** —— 线离内容比行距还近，方向正好反了。现在 `header` 的 `margin-bottom: 1.5rem`
      （线到第一行墨迹 **42.0px** ≥ 行距），页眉"上面紧、下面松"才是区块边界该有的样子。
      **这两个数都是"墨迹"距离**（按行盒量会多出该行 `line-height` 的 half-leading，实测那一下
      是 +8px，所以同一个位置按 `getBoundingClientRect()` 会读到 50.0px）。换 deck 内容不同、
      多出来的 leading 也不同 —— 比较层级时始终用同一种量法，别把两种数混着看。
      线上方那侧：线落在 `.head-row` 的 `padding-bottom: 16px` 之下，而页眉区最高的元素是 64px 的
      头像（比 1.5rem 的标题高 25px），所以实测**线在头像之下 18px**（按 h1 的行盒算会得出 30.8px ——
      差异就是 h1 那 38.4px 行高里上下各约 7px 的 half-leading）。
    * 行线那侧：`.deck` 的 `padding-top: 0.9375rem` / `padding-bottom: 0.875rem` 让行线到上一行
      墨迹 **14px**、到下一行墨迹 **18px**（行高 19.2px 的 `line-height` 会在墨迹上下各留 ~3.6px
      的 leading，所以 `padding` 写成 15/14 反映到墨迹上是 18/18）。旧值 `0.68rem/0.6rem`
      差得更多，线明显偏上。
    * 量这些值**不能只读 CSS**：`getBoundingClientRect()` 给的是行盒（含 `line-height` 的
      half-leading），而观感是**墨迹**到线的距离，两者能差 3–4px；本轮就是先用行盒算出
      "上 22 / 下 34、对称"，实测才发现方向反了。
    这两条外部依据（2026-10 查过）：
    * Material 3 的 divider 指南：full-width divider 分隔不同 section，inset divider 分隔同一
      section 内的条目（<https://m3.material.io/components/divider/guidelines>）—— 我们的行是
      "同一区块内的条目"，所以线不接地、不撞边缘；
    * iOS 的 `UITableViewCell.separatorInset`：表格分隔线从**内容左边缘**开始、不到屏幕左边缘
      （<https://developer.apple.com/documentation/uikit/uitableviewcell/separatorinset>），同一个思路；
    * Primer 的 action list：条目分隔线**只在多行条目（带描述）时才建议用**，并提醒「用分隔线时
      同时把 item 尺寸放大有助可读性，别只增加视觉噪音」
      （<https://primer.github.io/design/components/action-list/>）—— 我们一行三行文字（标题/副标题/
      元信息），所以保留细线是有依据的，行距也据此放大了一档。
    * 参考站（<https://tortrixx.pages.dev/workspace>）**一根分隔线都没有**：它的 `<li>` 只有
      `space-y-2 sm:space-y-1` 的小间距，4 个分组各自是 `rounded-lg border border-transparent
      hover:border-secondary hover:bg-blue-50/80 hover:shadow` 的卡片（`mb-3` 隔开）。
      它敢不用线，是因为每条只有一两行、靠间距就够；我们三行文字用间距会糊，所以取"渐隐细线"这条
      中间路线 —— 保留信息结构，但去掉表格感。
    行内的三级层次（2026-10 用户问「页数/大小会不会抢标题注意力」，量过之后调的）：
    无头 Chrome 取到的计算样式是**标题 16px/400、副标题 14px/400、元信息 12px/400** ——
    三级只差 2px、全是 regular，层级完全靠颜色撑着；于是一行里"最有形状"的东西变成了
    那两个 1px 描边胶囊。**改之前量过：当时整页带 1px 边框 + 圆角的元素只有这些胶囊**
    （当时站点 2 套 = 4 个，每套 2 个线性增长；主题按钮 `.icon-btn` 是 `border: 0`、GitHub
    链接也没有边框），所以它们不只是"数量最多"，而是**全页唯一一类封闭描边图形**，标题自然
    抢不过；改完之后全页是 0 个。（别写死套数：这里曾经写成"12 套 = 24 个"，而站点当时只有
    2 套 —— 数字要能当场量出来。）
    两处一起改：
    * `.deck-title` → **1.125rem（18px）/ weight 500**（字重见上面那条：本字体栈里 600 就是 bold，
      用户明确说"过粗"，所以写 500＝意图 medium、本机落 regular），标题靠字号 + 纯黑与灰色拉开；
    * 元信息去掉胶囊的**边框与内边距**，退化成一行淡色规格文字 `49 页 · 748 KB · 26-09-30.pdf`
      （分隔点用 `.badge + .badge::before` / `.badge + .file::before` 生成，所以**不用动 workflow**；
      workflow 里那个 class 名仍叫 `badge`，但它现在就是个普通 span —— 改名要动 YAML =
      触发全量重编、还会让当天缓存作废，不值当）。
      去掉胶囊后**分隔点从"装饰"变成了"承重"**（原来分组的活由那两个盒子干）：它是
      `hsl(var(--muted-foreground) / 0.55)`，实测浅色 **#B2B2B2 = 2.12:1**、深色
      **#5E5E5E = 3.05:1** —— 浅色下它几乎只是一点空气（真正分开三项的是 0.5rem 左右留白），
      深色下反倒比浅色清楚。这是**有意留着的**：`·` 是纯装饰、不承载可读内容，不适用 3:1 的
      非文本对比要求，而这一页的方向是"少一点墨"。真觉得三项挨得太近，加法只有一种 ——
      把它提到满色 muted（浅 4.74:1 / 深 7.85:1）；**不要**为此把胶囊加回来，
      那是把一个装饰问题换回一个层级问题。
    **减重不能靠把颜色调淡**：浅色模式下 muted `#737373` 对白底是 **4.74:1**，刚过 WCAG AA 的
    4.5:1（深色 7.85:1）—— 能去掉的只有装饰（描边、内边距），不是对比度。动这三级的字号/颜色前先算一遍。
    一个连带的取舍，改之前先想清楚：**hover 从「灰块包住内容」回到「整行」**。贴合式灰块是②
    那版在**无分隔线的浮动卡片**里成立的做法；一旦有了分隔线，高亮块右边缘和分隔线右边缘对不齐
    就是"脏"。所以 `.deck` 是 `width: 100%`，和分隔线共用同一条右边界。
    改分隔线/版式后记得同步门禁 ⑩（它钉顺序，并顺手钉住"日期不再渲染"）。
  无障碍上另有两条硬约定（2026-10 补齐）：
  - **装饰性 SVG 一律 `aria-hidden="true"`**：背景网格（`.bg-grid`）、主题按钮里的三个图标、
    GitHub 图标、卡片上的「外链」小箭头。它们的可访问名由外层承担（按钮/链接的 `aria-label`、
    卡片标题的可见文本），SVG 自己不提供名字，留着只会让读屏软件多念一句「图形」。
    注意卡片里那个箭头 SVG 是**在 workflow 的 heredoc 里**生成的（改它要动 YAML）。
  - 头像 `img` 显式写 `width="64" height="64"`（与 CSS 一致）：样式表万一没生效也不会撑破布局。
  另外 `target="_blank"` 的链接都带 `rel="noopener noreferrer"`（`noreferrer` 本身就蕴含
  `noopener`，写全是为了不依赖这条蕴含关系；Lighthouse 的「跨源跳转安全」审计认这两者之一）。
- **页脚位置**：`body` 是 `display: flex; flex-direction: column`（已有 `min-height: 100vh`），
  `main` 吃剩余高度（`flex: 1 0 auto`），`footer` 只留 `margin-top: 1.25rem` + `text-align: center`
  —— 内容少时页脚落在**页面最下方、整行居中**，内容超过一屏时仍旧跟在最后一张卡片之后
  （不用 `position: fixed`，那会盖住内容）。原来它紧跟在卡片下面，只有一两套幻灯片时看着像"浮在中间"。
  实测（无头 Chrome，视口高 1000、两套幻灯片）：footer 底边距视口底 40px（= body 的
  `padding-bottom: 2.5rem`）、中心 x=550 与 body 中心重合；16 张卡片的页面：文档高 1646、
  页脚距最后一张卡片 20px，无重叠。
- **页面背景要设在 `html` 上，不能只设在 `body`**（Safari 踩过）：`body` 是
  `width: 90%` 的居中盒子、高度只由内容与 `min-height: 100vh` 决定，把 `background` 只写在它上面时，浏览器**可能**
  把 body 背景提升为画布背景（Chrome 会），Safari 不会 —— 结果内容高度以下露出一条浅色，
  深色模式下特别明显（用户截图报过）。现在是这样，三条一起保证铺满：

  ```css
  html { background: hsl(var(--background)); height: 100%; }
  body { min-height: 100vh; color: hsl(var(--foreground)); }  /* 注意：body 上不要再写 background */
  ```

  **`body` 上不能再写 `background`**：`.bg-grid` 是 `z-index: -1`，它画在**根背景之上、
  body 背景之下** —— body 一旦有不透明背景就把整片网格盖掉（这正是"背景修好了、网格
  却没了"的原因：根背景原本是透明的，加了颜色后就挡住了网格）。
  实测下半区灰度标准差：盖住时 0.46、去掉后 2.89（深色）/ 1.76（浅色）。

  同样要注意 `.bg-grid` 用 `position: fixed; inset: 0; height: 100%`，**百分比高度需要有
  参照**：只在 body 上写 `min-height: 100vh`、html 不给 `height` 时，Safari 里这层仍可能
  只覆盖内容高度（`html` 没有确定高度，body 的百分比高度就悬空）。
  判定方法（Chrome 也能做，因为量的是几何而不是颜色）：

  ```js
  // 旧写法会暴露：html 高只有内容高、背景透明，全靠浏览器提升 body 背景
  document.documentElement.getBoundingClientRect().height   // 应等于 innerHeight
  getComputedStyle(document.documentElement).backgroundColor // 不应是 rgba(0,0,0,0)
  ```

  实测对比：旧写法 视口 857 / html 289 / 根背景 transparent；新写法 857 / 857 / rgb(10,10,10)。
  另外 Safari 的 WebDriver（`safaridriver`）需要手动在 Safari 设置里开「允许远程自动化」，
  开不了就只能靠 Chrome 量几何 + 让用户在 Safari 里目视确认。
- **`prefers-color-scheme` 只在"跟随系统"时等于实际主题**：手动固定浅/深后，所有
  `<meta name="theme-color" media="(prefers-color-scheme: ...)">` 都会和页面对不上，
  所以 JS 应用主题时会 `removeAttribute("media")` 并改写 `content`，让地址栏那圈颜色跟着
  **实际生效的主题**走。
- **首页主题策略（三态循环，不是两态）**：`auto` / `light` / `dark`，右上角按钮依次循环。
  - `auto`（默认，也是 localStorage 没存 `theme` 时的状态）：**每次加载都重新读**浏览器的
    `prefers-color-scheme`，并在 `matchMedia` 的 `change` 事件里实时跟随。所以「首次打开按浏览器、
    之后每次刷新也按浏览器」在不手动干预时始终成立。
  - **图标按模式换，不是「太阳/月亮 + 小圆点」**：`data-mode` 决定显示哪一个——
    浅色=太阳、深色=月亮、**自动=半明半暗的圆**（`<circle>` 描边 + 右半 `<path>` 填充；
    这是「自动/对比度」的经典符号）。早先试过在太阳/月亮角上加 5px 小圆点表示自动，
    但那个点太小、不像个图标，已经换掉。
  - **图标显隐必须写成「默认全隐藏，只打开当前那个」**，别写成「基础的 `display: none`
    + 两条按模式覆盖」：后者上线后深色模式下太阳没被藏住，**太阳和月亮叠在一起画出来**
    （用户截图发现）。现在是这样，任何情况下最多一个可见：

    ```css
    .icon-sun, .icon-auto, .icon-moon { display: none; }
    [data-mode="light"] .icon-sun,
    [data-mode="dark"]  .icon-moon,
    [data-mode="auto"]  .icon-auto,
    .icon-btn:not([data-mode]) .icon-sun { display: block; }
    ```

    查这类「明明写了 display:none 却还在」的问题，**别只看 CSS 有没有写对**：
    用无头 Chrome 跑一段探针，对三种模式分别 `getBoundingClientRect()` 看谁不是 0×0，
    一眼就能定位（当时就是靠它确认 `dark` 下 sun=22×22、moon=18×18 同时存在）。
    注意 headless 的 `prefers-color-scheme` 是**跟着系统走**的（本机两次实测结果就不一样：
    写过「默认 dark」，2026-10 再测又是 light），别假设固定值 —— 要哪种就在截图前显式定：
    浅色 `--blink-settings=preferredColorScheme=1`，深色则在 `</body>` 前注入
    `document.documentElement.classList.add("dark")`（放在 head 里会被页面自己的 JS 覆盖）。
    截图前还要关掉 `.fade` 的入场动画，否则元素是 `opacity: 0`，截出来一片空白（会误判成"没渲染"）。
  - 注意：**别用「实心圆 + 月牙挖空」那种自创路径**画半明半暗——在 24 网格里实心圆会把
    挖空盖掉，渲染出来就是一坨黑圆（无头 Chrome 渲染预览才看出来）。
  - `light` / `dark`：用户明确选过才写进 `localStorage.theme` 固定下来；回到 `auto` 时
    `removeItem` 把键清掉，否则刷新后又被固定住。
  - **为什么不是两态**：二态按钮没有「跟随系统」这个位置，一按就只能写死，检测于是永远失效
    （这正是改之前的毛病）。三态把 auto 变成可见、可切回的状态。
  - **关键实现坑**：应用主题必须判断模式——`apply(mode === "auto" ? query.matches : mode === "dark")`。
    若照抄成 `apply(query.matches)`，每次系统变化/刷新都会把手动选择覆盖掉，固定模式形同虚设
    （写了这个 bug，被 `ok/fail` 断言抓出来）。
  - 其它实现细节：点击用**事件委托**（脚本在 `<head>`、先于按钮执行，不能直接
    `getElementById(...).addEventListener`）；`aria-label`/`title` 说明「当前模式 + 点一下去哪」，
    `aria-pressed` 只反映当前是否为深色；切模式时通过 `#themeStatus`（`role="status"`）播报，
    首屏那次不播报（用 `announcedMode` 比较）。`localStorage` 全部包在 `try/catch` 里。
  - `:root`/`.dark` 变量与太阳/月亮图标只由 `html.dark` 驱动；JS 另写行内 `color-scheme`
    （优先级高于样式表里 `html` / `html.dark` 两条兜底）让表单控件与滚动条一起变。

## 后续增补

- **2026-10-11：整行可点（stretched-link）**。此前 `.deck:hover` 整行高亮、但只有标题文字是链接，
  点行内空白无反应（hover 的 affordance 与点击面不一致）。修法是给 `.deck-title` 加
  `::after { content: ""; position: absolute; inset: 0 }`：定位上下文是 `.deck`
  （`position: relative`），于是链接的点击面铺满整行。不新增 tab 停靠点（读屏/键盘仍只见
  一个链接），workflow 的卡片 heredoc 不用动。固有代价：行内文字无法划选（伪元素盖在最上层），
  GitHub/Primer 的同款取舍。

- **2026-10-17：封面缩略图 + 「最近更新」圆点 + 页脚「全部 PDF」+ 顶栏一行到底**。
  这一轮同时动了模板、编译步与导航页，四件事的实测依据：

  **① 封面缩略图**（首页从"纯文字列表"变成"小图 + 文字"）。图由**编译步**产出：
  `typst compile --format png --ppi 32 --pages 1 main.typ build/covers/<名称>.png`。
  - 选 `--ppi 32` 的理由是**字节数**：16:9 出来 374×210，实测 26-09-30 = 3989 B、
    template = 5783 B（`--ppi 64` 同样内容 9680 B）。首页按 96 CSS px 宽显示，374px 已接近 4×，
    再高就是白送流量。排版成本与一次 PDF 编译同量级，所以只为**这次真编过**的 deck 生成
    （复用的那套若缺图只补图、不重编 PDF，见门禁 ②/②c）。
  - 版式：行首 96×54（窄屏 72px），`.deck` 本来就是 `display:flex`，加一张图不用动布局；
    stretched-link 的 `::after{inset:0}` 仍然铺满整行（定位上下文是 `.deck`）。
  - 三个 CSS 细节都是踩出来的，**别改**：
    * `object-fit: contain`（不是 `cover`）：仓库允许 A4/竖版文档（AGENTS.md §3.9），
      `cover` 会把竖版页面裁成一条横带；`contain` 对 16:9 完全等价，对竖版留边不裁切，
      留边处露 `--secondary` 底色。
    * `align-self: center`：`.deck` 没写 `align-items`，默认 `stretch` 会把图盒拉到整行高
      （图本身因 `contain` 不变形，但会多出一圈底色，看着像个大灰块）。
    * `height: auto` + `aspect-ratio: 16/9`：**必须写 `height: auto`**，否则 `<img>` 上的
      `height="54"` 属性（无 CSS 时的兜底）会在窄屏把 72px 宽的图压扁。
  - 深色模式下不加滤镜/反色：封面是"纸张"，加一层 1px 边框就够，反色会让它不再像 PDF。

  **② 「最近更新」小圆点**。docs 里早就写着"想透出新旧，比恢复日期列更轻的做法是加个小圆点"，
  这轮兑现：构建时用 `git log -1 --since="${RECENT_DAYS} days ago" --format=%H -- slides/<名>/` 判断
  （**交给 git 做相对时间**，不自己解析日期 —— BSD/GNU 的 `date -d` 不通用）。
  取不到提交日期时**不标记**（fail safe）：浅克隆/无历史的环境里宁可没有圆点，也不要每行都标。
  视觉上是标题右侧一个 6px 的 `--accent-blue` 圆点（页面上唯一的彩色元素，正好当"新"的信号），
  语义由紧随其后的 `.sr-only` 文本承担，圆点自己 `aria-hidden`。
  **实现坑**：`.deck-title` 是 `inline-flex`，**flex item 之间的空白会被浏览器忽略** ——
  靠换行/空格分不开圆点和标题，必须给 `.dot` 自己写 `margin-left`。
  窗口是 workflow 顶部 `env: RECENT_DAYS`，**2026-10-17 定为 3 天**（原 14）：这个仓库更新不频繁，
  14 天窗口下「两套 deck 都带圆点」是常态，等于没有信息量；3 天则接近「我刚改过这套」的语义 ——
  代价是大多数时候一个圆点都不出现（那也是可接受的：没有新鲜事就不显示）。嫌吵/嫌少就调这个值，
  或直接去掉那个 span（`fresh_mark` 一行）。**注意它是构建时算的**：站点没重建之前，
  圆点会一直停在「上次构建时」的状态。

  **③ 页脚「全部 PDF」**：`更新于 … · 全部 PDF`，链接指向
  `https://github.com/tortrixx/slides/releases/latest`（当天那个 Release 汇总了全部 PDF），
  所以**不需要新增任何 CI 逻辑**。踩到的坑：`awk` 的 `sub()` 替换串里 `&` 表示"匹配到的文本"，
  meta 文案里出现 `&` 会被吃掉，所以文案里不要写 `&`（真要写就写 `\&`）。

  **④ 顶栏一行到底**。原来是"窄屏纵向堆叠、≥640px 才转横向"，实测（500px 视口）
  `.head-row` 高 **176.4px**（头像 64 + 标题 38.4 + 按钮 32 + 两个 gap = 150.4，多出来的 ~26px
  是 `.spacer{flex:1}` 在**纵向**也参与分配撑开的），第一张卡片被压到 y=220；
  改成所有宽度都是一行、窄屏只是把头像收到 48px / 标题收到 1.25rem 之后，同一条件
  `.head-row` 高 **62px**、卡片从 y=98 开始 —— 首屏多出约 120px。
  前提是标题固定为 `Slides`（很短）；以后若换成长标题，先在这个断点验一遍会不会挤掉右侧按钮。
  `.avatar` 的 CSS 分两档（48/64），`<img>` 上的 `width/height="64"` 保留为无 CSS 时的兜底。

  **验证方法与一个工具坑**：无头 Chrome 在 macOS 上**最小视口宽是 500px**
  （`--headless` 与 `--headless=new` 实测一致：`--window-size=390` 时 `innerWidth` 仍是 500，
  截出来的图是"按 500px 布局、裁成 390px"）。所以 `--window-size=390` 的截图看着像内容整体偏右，
  那是工具在骗人、不是布局 bug；窄屏只能验到 500px，375/390 要靠实机或设备模拟。
  另外截图时 `index.html` 必须和 `covers/`、`icon.png` 同目录（页面用相对路径），
  把 HTML 单独拷到别处截会让封面全变成破图。

<!-- tortrixx/slides · 仓库约定见 AGENTS.md -->

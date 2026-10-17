# CI 设计细则（docs/ci-design.md）

`build-and-deploy.yml` 的 build 细节、release 细节与运维备忘 —— **实测数据、历史推演与理由**都在这里。
2026-10-17 从 AGENTS.md §4 原样搬出：那天 AGENTS.md 长到 68 KB，撞上运行环境的 64 KB 指令预算，
**被截断**（末尾 §7/§8 整节消失，正是本文件一直在警告的那种失效）。搬出后 AGENTS.md 只留
「必须遵守的不变量 + 指针」，**操作规则仍以 AGENTS.md 为准**，这里放的是它们的依据。

> 看这份文件时的定位：想知道「为什么这么写、当年试过什么、实测数字是多少」→ 这里；
> 想知道「我现在该怎么做」→ AGENTS.md §4/§6。

---

### build 细节

- **字体**（verify 与 build 共用同一个复合 action `.github/actions/setup-fonts`；三个字族各一套
  来源，装完统一 fail closed）：
  - **中文 / 西文**：`apt-get install fonts-noto-cjk fonts-inter`（取不到时降级为只装 CJK）。
    故意**不装** `fonts-noto-cjk-extra`（多 145MB），代价是 `weight: "medium"` 之类中间字重回退。
  - **代码字体（`#show raw`）**：Ubuntu 源里没有 Maple Mono，所以从上游 Release **固定版本下载**：
    `MAPLE_MONO_VERSION`（当前 `v7.9`）+ zip 与解出的 TTF 两个 sha256，全在 workflow 顶部 `env:` 里。
    zip 由 job 层的 `actions/cache` 缓存（key = zip 的 sha256）；**缓存命中也照跑 sha256 校验** ——
    上游换包 / 下载被劫持 / 缓存被污染都直接红，不会静默换字体。
    只解压并安装 **Regular** 一个权重 —— 和作者本机 `~/Library/Fonts/` 里那一份完全一致
    （v7.9 的 `MapleMonoNormal-NF-CN-Regular.ttf`，sha256 已核对相同）。
  - **装完的断言（这一步才是关键）**：`typst fonts` 里必须同时出现 `Inter` / `Noto Sans CJK SC` /
    `Maple Mono Normal NF`，缺一个就 `::error::` + `exit 1`。为什么必须显式断言：**缺字体时 Typst
    不报错**，只是按字形静默回退（中文掉方块、代码掉 DejaVu），PDF 照样编得出来、CI 全绿 ——
    这正是这次改动要根治的那种静默失效。
  - **断言写 `Maple Mono Normal NF`，不是字体 name 表里的 `Maple Mono Normal NF CN`**：Typst 的
    `FontInfo` 用 `typographic_family()` 把 family 末尾的风格词当后缀剥掉
    （`crates/typst-library/src/text/font/info.rs`，SUFFIXES 里含 `cn`、`normal`、`cond`、`vf` 等），
    系统字体与 `--font-path` 两条路径都走这段代码、跨平台结果一致 —— 按 name 表原文断言会假红。
    （同一个机制也让 macOS 上 `typst fonts` 显示的是 `Maple Mono Normal NF`。）
  - **改字体 = 全量重编**：复合 action 文件的哈希与 workflow 的哈希一起进了 `.build-stamp` 的
    「编译环境指纹」（见下条），改任何一个都会让旧 stamp 失配。门禁 ⑨b 钉着这一点。
- **增量编译**：`actions/cache@v6` 以 `slides-build-main-<run_id>` 为 key、`slides-build-main-`
  为 restore-keys 缓存 `build/`。逐套判断：全量 / 缓存缺 PDF / 该目录相对**基准提交**有改动 → 重编。
  最后清理「`slides/<名称>/main.typ` 已不存在」的残留 PDF。
  **不再有封面图这一步**（2026-10-17 加过、当天撤掉）：编译步只产 PDF，`build/` 里除了
  `*.pdf`、`index.html`、`.build-stamp` 不该有别的东西。历史与理由见 docs/site-design.md。
  基准**不是** `github.event.before`，而是缓存目录里 `.build-stamp` 记的**上一次真正编译成功的提交**：
  ```
  <sha> <TYPST_VERSION> <编译环境指纹>
  ```
  编译环境指纹 = workflow 文件与 `.github/actions/setup-fonts/action.yml` 两个文件的哈希，
  **再加上装上的字体包版本**（`dpkg-query -W fonts-noto-cjk fonts-inter`，见上面 `runs-on` 那段），
  三者一起再哈希。装字体逻辑 2026-10 抽成了复合 action；只哈希 workflow 的话，改字体不会触发
  全量重编 —— 那正是 stamp 要防的静默失效，门禁 ⑨b 钉住；只哈希两个文件、不记字体版本的话，
  镜像/档案库悄悄换了字体也一样不会触发全量，门禁 ⑨b' 钉住。
  取不到 `dpkg-query` 的机器（macOS）上这一项为空串，门禁的 `wf_rev_of()` 用**逐字相同**的算法、
  同样为空，两边一致；算法一旦漂移，②⑨ 会走进「环境变了 → 全量」而**假红**。
  为什么不用 `before`：它只覆盖本次 push。若上一次运行失败（缓存没存下）或两次 push 挨得很近，
  那一次改过的 deck 就既不在 diff 里、缓存里又是旧 PDF，会被**永久复用成旧版本**且不会自愈
  （已实测复现，两份独立审查也都指出过）。用 stamp 作基准，差异永远是「相对上次成功编译」，
  而编译失败时不会写 stamp，所以失败的下一次 push 必然把那些 deck 重新编译一遍。
  另两个字段用来在**编译环境变化**（Typst 版本、workflow 与字体 action 里的编译参数）时强制全量。
  stamp 是 `build/` 里的隐藏文件：只进 patch 缓存，不进 artifact、不进 Pages。
  这一条核对过 action 源码（2026-10）：`upload-pages-artifact@v5` 的 `include-hidden-files`
  默认 `false`，打包时会加 `--exclude=.[^/]*`；`upload-artifact@v7` 同样默认不收隐藏文件。
  所以 `.build-stamp` 不会出现在站点上，也不会进 Release 附件（release 那边另有
  `files: build/*.pdf` 兜底）。**别把它改成非隐藏文件名**，否则会被发布出去。
  tag / release / PR / 手动运行一律全量编译。
- **构建环境校验（写文件之前第一步）**：`BUILD_DIR` 归一化（折叠 `//`、去掉开头 `./` 与结尾 `/`）后
  必须是仓库内的相对目录名、只含 `A-Za-z0-9._-/`，**且最后一段必须叫 `build`**（`build` 或
  `xxx/build`）；`TYPST_VERSION` 不能为空；`RELEASE_TZ` 用 `python3 -c 'zoneinfo.ZoneInfo(...)'`
  实打实解析。为什么非要这一步：后面几段脚本按 `"$BUILD_DIR"/*` 遍历并 `rm -rf`，**`BUILD_DIR` 为空时
  通配符会展开成 `/*`**（实测会枚举 `/Applications`、`/Library`…），而 `'./'` 又等价于 `.`
  —— 清理会把整个工作树删掉。空值/`/`/`.`/`..`/绝对路径/含 `..`/含空格等一律 `::error::` + `exit 1`。
  这一步刻意放在装字体、恢复缓存**之前**（配错了 5 秒内就红，也不会先恢复一份缓存再失败）。
  同一处还校验 **`RECENT_DAYS` 必须是 1–3650 的整数**（`${RECENT_DAYS-3}`：未设置兜底 3、
  显式空串报错）。值写错时 `git log --since` **不报错**、只是圆点一个都不出现而 CI 全绿
  （实测 `'abc'` → 0 个圆点、rc=0）；门禁 ⑦ 对 `''/'abc'/'0'/'-3'/'14 days'/'99999'` 全拒。
  **`RELEASE_TZ`** 也有负例（`Not/AZone` / `Asia/Shangai` / `UTC+8` / **`Asia` / `Etc` /
  `zone.tab` / `tzdata.zi`** 必须被拒，`UTC` / `Asia/Shanghai` / 空串必须放行）：
  `TZ=Not/AZone date` 在 glibc 与 BSD 下都**不报错**、静默退回 UTC，跨零点就让 tag 的日期差一天。
  **校验必须用 `python3 -c 'zoneinfo.ZoneInfo(...)'` 实打实解析**，不能只看
  `/usr/share/zoneinfo/$tz` 是否存在：`Asia`、`Etc` 是**目录**，`zone.tab`、`tzdata.zi` 是
  **普通文件**，四者都存在、都会被 `[ -e ]` 放行，而 `TZ=Asia` / `TZ=zone.tab` 同样静默退回 UTC
  （2026-10-17 独立复核实测，macOS 与 ubuntu-24.04 都中）；原来那道 `TZ="$tz" date` 检查是
  **死代码**（对任何非法值都返回 0），已删。
  还有一处**「校验的值 ≠ 使用的值」**：校验步用 `${RELEASE_TZ:-Asia/Shanghai}` 归一化后再查，
  而两个消费者（导航页页脚、tag）原先直接用 `${RELEASE_TZ}` —— 而 `TZ=""` 不是「系统默认」，
  是 **UTC**。所以现在**三处都写全兜底** `${RELEASE_TZ:-Asia/Shanghai}`：`RELEASE_TZ` 一旦被删空，
  校验打印默认值并放行、消费者也按默认值算；两边写法再漂移就又会错开（跨零点差一天）。
  **`BUILD_DIR` 还必须是「不含幻灯片源码」的目录**：`slides`、`slides/<deck>` 这类取值字符集
  完全合法，但导航页那步的 `rm -rf "$BUILD_DIR"/*` 会把 `main.typ` 和 `src/` 删掉 ——
  实测 `BUILD_DIR=slides/d1` 删掉 d1 的源码、首页只是少一张卡片、**exit 0**，一句报错都没有
  （未跟踪的新图片直接永久丢失）。所以两道防线：校验步直接拒绝「自身含 `main.typ` 或其子目录
  含 `main.typ`」的取值（门禁 ⑦ 有负例），导航页那步再在动手前做一次**只读探测**，
  见到 `main.typ` 就 `::error::` + `exit 1`（门禁 ⑦ 也钉住「一个字节都没删」）。
- **幻灯片目录名的另外两个护栏**（§3.8 只管字符集）：
  - **点号开头**（`slides/.hidden`）：`for dir in slides/*/` 根本匹配不到它，会静默不编译、不出卡片，
    而只要还有别的 deck 就 `exit 0` —— 站点永远少一套。所以单独扫 `slides/.[!.]*/`、`slides/..?*/`
    报错（宁可让人改名）。
  - **含换行/回车**：`basename` 会把尾部换行吃掉，两个不同目录会落到同一个 `<名称>.pdf` 上互相覆盖。
    按 `$dir` 的原始字节先拦掉。
- **导航页**：`index.template.html` 是首页模板（版式/样式都在里面），workflow 只负责
  注入数据，产物 `build/index.html` 是**服务端渲染**的静态页（无 JS 也能看）。
  三处占位注释由 `awk` 替换：`SLIDES`（卡片列表）、`COUNT`（套数）、`META`（页脚的「更新于 …」时间戳）。
  **`awk` 是按行替换的，不认 HTML 注释** —— 所以**绝不要在模板（或任何会被喂给那段 awk 的文件）里
  写出占位符的原文**：写了 `SLIDES` 那处的原文，整行会被换成卡片列表并塞在注释中间；写了 `COUNT`
  那处的原文，它会就地变成数字。这不是推演：模板开头的注释里最早写过 `COUNT` 的原文，
  构建产物里那句真的成了「注意 2 现在模板里没有用了」（2026-10 实测）。
  现在模板里提到它们只写名字，原文只出现在两处真正的注入点（`SLIDES` 与 `META`）；
  **`COUNT` 目前模板里没有用到**（标题旁的套数已按用户要求去掉，理由见 docs/site-design.md），
  但 workflow 的替换规则留着 —— 想恢复套数显示只需改模板，不用碰 YAML。
  页脚**只放「更新于 …」这个时间戳**。时间戳那句「本页由 GitHub Actions 自动生成」说的是构建过程、
  不是页面内容，已删（与早先删掉 "Built by Typst & Touying." 同理）；提交号也一并不显示了 ——
  它是构建提交，跟某套幻灯片最后一次改动无关，容易被误读。
  **2026-10-17 删掉过页脚里的「全部 PDF」链接**（当时指向 `releases/latest`）：用户要求去掉，
  理由是顶栏右上角已经有 GitHub 图标、进仓库就能看到 Releases，页脚再来一个是重复入口。
  连带把门禁 ① 里那条「页脚必须有 releases/latest 链接」的断言一起删了（**同一次提交还删了
  11 条断言（10 条封面相关 + 1 条页脚链接），合计 109 → 98 项** —— 旧文档写的「109 → 108」
  在算术上不可能，2026-10-17 复核指出）；
  **别再把它加回来**。若以后真往页脚塞 HTML，注意 `awk` 的 `sub()` 替换串里 `&` 表示
  「匹配到的文本」，文案里不能出现 `&`（要写就写 `\&`）。
  - **顺序＝最新在前**：先按 `git log -1 --format=%cs -- "slides/<名>/"` 取每套 deck **最后一次
    提交的日期**，`LC_ALL=C sort -t $'\t' -k1,1r -k2,2` 排序（日期倒序、同一天按文件夹名升序），
    取不到日期（浅克隆 / 从未提交）的排最后。**不要退回 `for dir in slides/*/`**：那是 bash 的
    glob 顺序 =「当前 locale 的字典序」，跟改没改无关，而且中文名的先后会随 runner 的 locale 变
    （实测同一组名字：C.UTF-8 把中文排最后、en_US.UTF-8 排最前、zh_CN.UTF-8 又排最后）。
    日期**只用于排序、不渲染到页面**（那一列已经去掉了，原因见 docs/site-design.md）。
    两个实现坑（都踩过并写进了门禁）：① 空日期不能直接写进 TSV —— `read` 会吃掉行首的 IFS 空白，
    文件名会被读进日期字段、整行错位；脚本里把它换成 `0000-00-00` 占位、循环里再换回空串。
    ② `[ "$d" = "x" ] && x=""` 这种一行写法在 `set -e` 下会留下非零退出码，落在脚本末尾会把
    整步判成失败，所以写成正常的 `if`。
    ③ **`count` 必须显式兜底**：卡片循环读的是 process substitution（`done < <(sort …)`），
    而它的退出码**不参与** `set -e` / `pipefail` —— sort 一旦失败（命令没了、文件读不了、参数
    写错），while 读到 0 行、脚本照样走完并 `exit 0`，首页变成一个列表都没有而 CI 全绿
    （实测：把 sort 换成不存在的命令，输出「已生成 build/index.html（0 套幻灯片）」、rc=0）。
    所以循环后显式判 `count -eq 0` 就 `::error::` + `exit 1`（能走到那里就必然有 deck，
    前面「编译」那步已经保证"一套都没有"时 fail closed）。
    日期取自 git，所以 checkout 的 `fetch-depth: 0`（增量编译本来就需要）不能去掉。
  卡片数据来源：
  - **标题/副标题**：由 `tools/deck-meta.py` 从 `main.typ` 里取**行序第一个**非注释的
    `title:` / `subtitle:`（导航页步骤调用 `python3 tools/deck-meta.py <main.typ> <键>`，
    缺 python3 直接 `::error::`）。**不要退回「shell 里逐行 sed」**：值可能是跨行的 `[ … ]`、
    里面可能含 `]`（`数组 a[0] 的用法`）或转义引号（`"他说 \"你好\""`），逐行正则会**静默**
    截断（`外层 [内层` 这种看着还挺合理）或整段取不到（退回文件夹名）。旧实现按「形态优先级」
    分三遍全文件扫描，于是正文里更晚出现的 `title: [...]` 会盖掉第一行的字符串标题 ——
    现在是严格行序（门禁 ①c 直接单测这个脚本，覆盖内层 `]`、跨行、转义引号、注释行、
    `subtitle:` 不误配、空值等写法）。
    注意它**不检查这个键属于谁**：`config-info(title: …)`、A4 的
    `#set document(title: "…")`、甚至正文里一行 `title: [x]` 都会被取走（后者见 §3.9 的警告，
    只是现在「第一个」真的按行号算了）。
    回退策略**两者不同**：`title` 取不到就退回**文件夹名**；`subtitle` 取不到（没写、
    `subtitle: []`、或压根没有这一行）则**整行都不渲染**，
    不再塞一句默认文案（旧版是一句「点击卡片在线预览…」，已移除——缺副标题的卡片宁可少一行，
    也不要一句与内容无关的话）。注意 `subtitle: []` 也走「不渲染」，没法用它保留空行。
    实现上 `desc_html` 变量里**只放标签、不放换行**：换行由模板那一行提供，否则空串时会把下一行
    顶走、在卡片中间留下纯空格行；另外别把变量写在行首，YAML 的块标量会因此提前结束（已踩）。
  - **链接与文件名**：`<文件夹名>.pdf`（与 `title` 无关）；大小由 `wc -c` 换算，
    分 B / KB / MB 三档（不足 1 MiB 时封顶 1023，避免出现 "1024 KB"）。
  - **卡片副信息行**：`<页数> 页 · <大小> · <文件名>.pdf`（一行淡色文字，分隔点由 CSS 生成）。
    前两项在 workflow 里仍写作 `<span class="badge">`，但**CSS 里已经没有胶囊样式了**（见 docs/site-design.md）。
    页数**必须锚在页树根上**取：`strings | grep -oE '/Type[[:space:]]*/Pages[[:space:]]*/Count[[:space:]]+[0-9]{1,6}'`
    （Typst 产出的 PDF 未压缩所以读得到）。**不能只找 `/Count` 再取最大值** —— 大纲（书签）里
    也有 `/Type/Outlines … /Count N`，而那个 N 是**标题数**：1 页写 2 个 `=` 标题就会显示「2 页」
    （2026-10-17 独立复核实测）。现有两套 deck 恰好都是页数 > 标题数（template 20 页/3 标题、
    26-09-30 49 页/5 标题），所以这个错从上线起一直没暴露；门禁 ⑦b 现在用「1 页 2 标题」的
    夹具正面钉住它。
    **原来看起来多余的 `PDF` 徽章已去掉**——链接本身就是 `.pdf`、点了就是打开 PDF，
    文件名里又写了一遍，三处重复；换成页数更有信息量。若哪天读不到 `/Count`（例如 PDF 开始
    压缩），**那一枚整枚都不渲染**（不会留下一个只有「页」字的空项），所以这个取法不会给出错的信息。
    门禁同时钉了两面：读不到时不许出现「N 页」，正常 PDF 必须出现「N 页」。
  - **转义**：文件夹名与标题/副标题都会做 HTML 转义（`&` `<` `>` `"`），
    文件夹名另有字符集护栏（见 §3.8），两道一起保证生成的 HTML 不会被名字搞坏。
  - **「最近更新」小圆点**：最近 `RECENT_DAYS`（workflow 顶部 `env:`，当前 3）天内提交过的
    deck，标题后加 `<span class="dot">` + `<span class="sr-only">最近更新</span>`。判定用
    `git log -1 --since="… days ago"`（**交给 git 做相对时间**，BSD/GNU 的 `date -d` 不通用）；
    **取不到提交日期时不标记**（fail safe）—— 否则浅克隆/无历史的环境会把每行都标成「最近更新」。
    门禁两面都钉：① 夹具里每套 deck 都被 `fresh()` 显式提交成「刚刚」，所以必须有；
    ⑩ 那个夹具是 2020/2026-01 的老提交 + 一套从未提交的，必须一个都没有。
    实现坑：`.deck-title` 是 inline-flex，**flex item 之间的空白会被忽略**，所以 `.dot` 得自带
    `margin-left`，靠换行分不开。
  - 标题按**原文**显示：Typst 标记（`*粗体*`、反引号）不会被渲染，也不会被剥离。
- **站点静态资源（`assets/`）**：Pages 只发布 `build/`，所以仓库里的静态文件由「生成导航页」
  那步开头拷进站点根目录（现在只有 `assets/icon.png`，即左上角头像；模板里写 `src="icon.png"`）。
  文件缺失是 `::error::` + 退出，**故意 fail closed**：页面不会因此报错，只是 `img` 被
  `onerror` 静默删掉，不失败的话很难发现。`verify-site.sh` 里钉了一条产物断言。
  拷之前先清掉 `build/` 里「非 `*.pdf`、非 `index.html`、非 `.build-stamp`」的旧文件
  （三个通配符 `*` / `.[!.]*` / `..?*` 一起覆盖普通文件与隐藏文件；`.build-stamp` 是增量基准，
  必须留下）：`build/` 是 `actions/cache` 的缓存对象，
  只清 PDF 的话，某个版本拷进来、后来不再拷的
  静态资源会被缓存**永久**带下去，并随两份 artifact 一起发布到站点根目录，自愈不了
  （本地 `build/` 里就躺过 `avatar-*.png` 这种中间态残留）。
  **白名单只有那三项，别用 `*.png` 之类的通配**：写成通配会把「根级残留文件也要清掉」这条
  一起废掉，门禁 ⑦ 用 `build/avatar-old.png` 钉着这一面。（2026-10-17 封面功能短暂存在时这里
  加过 `covers` 目录白名单，功能撤掉后白名单也一起收回了。）
  头像原来写的是 `https://github.com/tortrixx.png`，为什么换掉（2026-10 实测）：
  - 那是**全页唯一的跨站请求**（其余 CSS/JS/图标全是内联的），所以必然最后出现；
  - 它会 **302** 到 `avatars.githubusercontent.com`，多一次 DNS + TLS，实测 1.84s 才拿到图；
    而且这个 302 带 `cache-control: no-cache`，**每次打开都要重走一遍**（图的 `max-age=300`
    只能省掉第二步）；
  - 抓回来的是 **460×460 / 38 KB**，而（当时）页面只用 80px 显示（`?size=160` 才是 12 KB）；
  - 国内网络下 `avatars.githubusercontent.com` 还常慢/不可达（那 `onerror` 会把图整个删掉）。
  现在用仓库内 160×160（2× DPR）PNG，15.9 KB，同源、可长期缓存、零外部依赖。
  **换图直接替换 `assets/icon.png` 即可**，别改回外链。
- **站点视觉与前端（细则与踩坑史见 docs/site-design.md）**：改样式只动 `index.template.html`，
  不用碰 workflow。动手前必须知道的现行约定（每条都在 docs/site-design.md 里有实测依据，
  多数是否决过替代方案才定下来的）：
  - `<meta charset>` 必须留在文件最前面（1024 字节编码探测窗口），中文注释不许挪到它前面；
  - 全页**只有一个 h1**（顶栏 `.page-title`），没有标语、没有区块 h2、标题旁无套数胶囊；
  - **顶栏一行到底**（头像 + h1 + 右上角按钮，2026-10 改）：窄屏只是把头像收到 48px、
    标题收到 1.25rem，**不再纵向堆叠**。改之前窄屏 `.head-row` 高 176.4px（`.spacer{flex:1}`
    在 column 方向也参与分配），第一张卡片被压到 y=220；现在同条件 62px、卡片从 y=98 开始。
    `.avatar` 的 CSS 分两档（48/64），`<img>` 上的 `width/height="64"` 是无 CSS 时的兜底；
  - 版式是**纯列表**：一行一套，行内标题/副标题/元信息，行间一条两端渐隐的细线。
    2026-10-17 试过两种带封面的版式（行首 96×54 缩略图、卡片网格 + 大封面），**当天全撤**，
    回到这里 —— 缩略图在列表尺寸下不传递信息，放大到能读又必须放弃列表；详见 docs/site-design.md；
  - 标题后的 **`.dot`** 是「最近更新」小圆点（纯装饰 + 紧随其后的 `.sr-only` 文本承担语义）；
  - 字重写 `500`（意图 medium），**别写 600**（本字体栈里 600 就是 bold）；层级靠字号 + 颜色承担；
  - 行分隔线是 `.deck + .deck::before` 伪元素画的**两端渐隐**细线（页眉线是 2px 通栏实线，
    两条线"重量"必须不同）—— **别改回 `border-top`**（圆角会拐弯、渐变画不进 border）；
  - 整行可点用 stretched-link（`.deck-title::after` 伪元素铺满整行），不要再往行里加第二个
    链接/按钮；日期只用于构建时排序、**不渲染**到页面；
  - 主题是三态循环 auto/light/dark，应用时必须判断模式
    （`apply(mode === "auto" ? query.matches : mode === "dark")`，照抄 `apply(query.matches)`
    会把手动固定覆盖掉）；图标显隐用「默认全隐藏 + 按 data-mode 打开一个」的写法；
  - 装饰性 SVG 一律 `aria-hidden="true"`；动效保留 `@supports` 与 `prefers-reduced-motion` 降级；
  - 背景设在 `html` 上；`body` 上**不能再写 background**（会盖住 `z-index:-1` 的 `.bg-grid`）；
  - 页脚由 `body` 的 flex 布局 + `main` 的 `flex:1` 压到页面底部，不用 `position: fixed`。
- **产物**：`slides-build`（普通 artifact，给 release job 下载，`retention-days: 3`）+
  `github-pages`（`actions/upload-pages-artifact@v5`，给 deploy job，自带 1 天保留期）。
  两份都只在同一次运行内使用，所以保留期压得很短，避免长期堆积；留 3 天是为了隔天
  「Re-run failed jobs」时还取得到产物。`index.template.html` 在仓库根，不会进站点
  （只上传 `build/`）。

### release 细节

- tag 规则（「计算 tag」步骤的 else 分支）：
  `tag="v$(TZ="${RELEASE_TZ}" date +%Y.%m.%d)"`，`RELEASE_TZ` 默认 `Asia/Shanghai`。
- **说明「是不是我们写的」由 body 里的机器标记决定，不再只看 managed**：自动生成的说明末尾有一行
  `<!-- ci-managed -->`（渲染后不可见）。`gh release view --json body` 读回来带这个标记 → `ours=true`，
  才允许重写说明；没标记（用户手写、或旧版工作流建的）→ **只覆盖同名附件，一个字都不动**。
  三条步骤条件是完整划分：`exists=false || ours=true` → 生成说明 + 发布（带 body）；
  `exists=true && ours!=true` → **只更新附件**。
  为什么用标记而不是只看 managed：原来的条件是「managed=true 就刷说明」，而 managed 只看
  「这次是不是 main push」—— 用户手动建/手改了当天日期 Release 的说明后，同一天再 push 就会
  把他的说明整段盖掉（不可恢复）。
  最后那条路径**刻意不用 softprops、改用 `gh release upload --clobber`**：softprops 的更新路径
  会 PATCH 整个 release，而在本仓库**报过一次 `403 Resource not accessible by integration`**
  （2026-10-01 的运行日志）。**注意这个成因并未坐实**：2026-10-17 的独立复核把 61 次运行的
  release job 日志逐条扫过，403 只出现那一次，且那次恰好是「已存在 Release + 不带
  `body_path`」的组合（样本 n=1）；同一 action 的 `updateRelease` PATCH 在「发布」步成功过 40+ 次。
  所以这里改用 `gh` 的理由写成**语义性的**：`gh release upload` 只动附件、天然不碰 body，
  正是我们要的，也不会因为一次无关的 PATCH 让发版失败（原先那句「实测必然 403」是过度断言）。
  **一次性副作用**：改造前建的 Release body 里没有标记，所以它们不会再有说明刷新（附件照常更新）；
  跨天新建的 Release 就正常了。
- `exists` / `ours` 用 `gh release view <tag> --json body` 一次拿到，但**只有明确报
  `not found` / `HTTP 404` 才判 false**：403 限流 / 5xx / 网络错误先按瞬时故障退避重试
  （默认 3 次、5 秒起，可用 `RELEASE_VIEW_RETRIES` / `RELEASE_VIEW_BACKOFF` 调；门禁里设 2/0 保持秒级），
  重试仍失败才 `::error::` 退出。把「查不到」当成「不存在」，会让已存在的 Release 被当成新建、
  连带覆盖说明。旋钮值非法时回退默认值 —— 曾经的 `for x in $(seq 1 "$retries")` 在 GNU 下遇到
  非数字会「循环零次」，静默退化成 `exists=false`（本机 BSD 反而跑一次，行为还分叉）。
- Release 说明里的 tag 片段用 `python3 -c 'urllib.parse.quote(...)'` 整体做百分号编码：
  手写 tag 里可能出现 `(` `)` `#` `%` 等字符，只转义括号会让 Markdown 链接被截断。
- **已知行为（不是 bug，但改前要想清楚）**：`overwrite_files: true` 只覆盖**同名**附件、不做
  prune —— 同一天里删掉或改名某套 deck 后再 push，旧 PDF 仍留在当天 Release 上，
  `releases/latest/download/<旧名>.pdf` 会继续返回旧内容，直到跨天新建 Release 才换掉链接
  （线上实证：v2026.09.30 仍带着 `example.pdf`，下载链接 302、站点链接 404）。
  想清理就得显式删附件，但那会连手动附加的文件一起误删，所以这里选择只记录不自动做。
- **`deploy` 与 `release` 是兄弟 job，可以单边成功**：Pages 侧失败（Source 没选 Actions、Pages 5xx）
  而 Release 照发，或反过来 —— 站点与 Release 会短暂不一致，补救手段是「Re-run failed jobs」，
  而它受产物保留期限制（pages 1 天 / slides-build 3 天）。另外**说明里的站点链接对「新 deck」在部署
  完成前是 404**（附件下载链接正常）。这是有意接受的取舍：宁可让 PDF 先可下载，也不因为 Pages
  出问题就把发版一起卡住。`needs.deploy` 串联会改变这个取舍，所以没那么做。
- 发布用 `softprops/action-gh-release@v3` + `overwrite_files: true`（同一天重复 push 靠它覆盖）。
- **tag 一旦创建就不再移动**：同一天的附件会更新，但 tag 停在当天第一次 push 的提交。
  移动已存在的 tag 会让所有克隆的 `git fetch --tags` 报 `would clobber existing tag`。
- `verify` / `build` / `release` / **`deploy`** **四个 job 都有** `if: github.event.deleted != true` 防护：
  **删除 tag/分支同样会产生 push 事件**，没有这个防护，删掉 `v2026.09.30` 后工作流会
  判定该版本不存在而把它重新创建出来。（`verify` 也带这个条件，是为了「删分支」这类事件
  不必白跑一遍校验；`deploy` 是 2026-10-17 独立复核后补的 —— 它当时是唯一「能在 push 上跑、
  却没有这道防护」的 job，虽然当前没有实际触发路径（删除分支会带着 build 一起被跳过、
  删 tag 时 `github.ref` 不是 main），但防线不该不对称，门禁 ②·2 现在四个都钉。）
  注意下面「运维备忘」里那句「别把另外 3 处 deleted 也算进来」说的是**换分支名时**不用动它们
  —— 现在这份名单是 4 个，grep 数出来的分支名引用仍是 5 处。

### 运维备忘

- **换默认分支**（比如 `main` → `master`）：要改的是**引用分支名的 5 处**（2026-10-11 数过）——
  `branches:` 触发器、缓存恢复步的 `github.ref == 'refs/heads/main'`、增量编译基准判断、
  `deploy` 的 `if`、`release` 的 `if`（行号会随插步骤漂移，**按下面的 grep 找、别背行号**）。
  漏掉增量基准那处不会报错，但每次都退化成全量编译。
  **别把另外 4 处 `github.event.deleted != true`（`verify`/`build`/`release`/`deploy`）也算进来** ——
  那是「删除 tag/分支也会触发 push 事件」的防护，跟分支名叫什么无关，改分支名时不用动它们。
  用 `grep -n "branches:\|refs/heads/main\|event.deleted" .github/workflows/build-and-deploy.yml`
  全部列出来逐个判断（曾经写成「全部 6 处」并把 3 处删除防护算进去、同时漏掉缓存那处）。
- **`deploy` 报 Pages 未启用**：Settings → Pages → Build and deployment → Source 选
  **GitHub Actions**。
- **某套幻灯片编译失败**：站点与 Release 都会整次跳过，不会发布残缺内容；日志里会指出
  是哪个 `main.typ`，修好再推即可（stamp 机制保证下次必然重编它）。
- **`build/` 不要提交**：CI 产物，已在 `.gitignore` 里。


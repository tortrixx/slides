#!/usr/bin/env python3
"""从一套幻灯片的 main.typ 里取第一个 `title:` / `subtitle:` 的值。

用法：
    python3 tools/deck-meta.py <main.typ> <title|subtitle>

输出取到的值（单行、内部空白折叠成空格）；取不到时输出空行、退出码 0。
只有参数用法错误才返回 2。

为什么值得单独一个脚本，而不是 workflow 里的一行 sed：
`title:` 的值可能是**跨行**的 `[ … ]`、里面可能含 `]`（`数组 a[0] 的用法`）或转义引号
（`"他说 \"你好\""`）。逐行正则遇到这几种写法会**静默**截断或整段取不到 —— 而截断后的标题
看着还挺合理，构建与门禁全绿（2026-10-17 独立复核实测：`title: [外层 [内层] 结束]` 的卡片
显示成「外层 [内层」；跨行写法则整个退回文件夹名）。这里按**括号配平 + 转义感知**扫描，
并且取**行序第一个**非注释的键（不是「先看形态、再看行号」—— 后者会让正文里更晚出现的
`title: [...]` 盖掉第一行的 `#set document(title: "…")`）。

单独成文件的另一个好处：门禁可以**直接单测**它（见 verify-site.sh 的 ①c），
比只在端到端产物里断言卡片文字更容易覆盖刁钻写法。

已知取舍（有意为之，别当 bug 修）：只做字符级配平，不解析 Typst 语法 ——
值里若出现字符串形式的括号（`title: [他说 "[" 然后]`），配平会数错。
这种写法在标题里不现实，真出现时属于「解析失败 → 退回文件夹名」而不是静默截断。
**注释**是按字符扫描跳过的（`//` 到行尾、`/* … */` 跨行），所以行尾注释与块注释里的
`title:` 不会被取到；但字符串字面量不解析，`#let s = "title: [x]"` 里的键仍会被取到
（那是「第一个键」语义的一部分，见 AGENTS.md §4）。
"""

import re
import sys


def _mask_comments(src: str) -> str:
    """把注释内容换成等长空格（**长度不变**，偏移量因此保持可用）。

    处理 `//` 行注释与 `/* … */` 块注释。用「遮罩」而不是「删除」，是为了让
    `keypat.finditer()` 的偏移量能直接用于原文切片（取值必须来自原文，转义才不丢）。
    不解析字符串字面量：字符串里的 `//` 会被误当成注释起点（只会让那一行少认几个键），
    字符串里的键也仍会被取到 —— 两者都是已知取舍，写进了文件末尾的说明。
    """
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != "\n":
                    out[k] = " "
            i = j
        else:
            i += 1
    return "".join(out)


def extract(src: str, key: str) -> str:
    """返回 src 里第一个（注释之外的）`key:` 的值；取不到返回空串。"""
    # 键前面不能是字母/数字/下划线，否则 `subtitle:` 会被当成 `title:`；行首（可带缩进）也算。
    keypat = re.compile(r"(?:^|[^A-Za-z0-9_])" + re.escape(key) + r"[ \t]*:")
    masked = _mask_comments(src)          # 注释里的键在这里已经被空格盖掉
    for m in keypat.finditer(masked):
        v = m.end()
        while v < len(src) and src[v] in " \t":
            v += 1
        if v < len(src) and src[v] == "[":
            depth = 0
            j = v
            while j < len(src):
                c = src[j]
                if c == "\\":            # 转义（`\]`、`\\`）：整对跳过，不参与配平
                    j += 2
                    continue
                if c == "[":
                    depth += 1
                elif c == "]":
                    depth -= 1
                    if depth == 0:
                        return re.sub(r"\s+", " ", src[v + 1 : j]).strip()
                j += 1
        elif v < len(src) and src[v] == '"':
            m2 = re.match(r'"((?:[^"\\]|\\.)*)"', src[v:])
            if m2:
                return re.sub(r"\s+", " ", m2.group(1)).strip()
        # 这一处取不到值（例如跨行字符串）：继续找下一个键
    return ""


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[2] not in ("title", "subtitle"):
        sys.stderr.write("用法：deck-meta.py <main.typ> <title|subtitle>\n")
        return 2
    try:
        with open(sys.argv[1], encoding="utf-8") as fh:
            src = fh.read()
    except OSError:
        return 0  # 读不到就输出空：调用方对 title 有「退回文件夹名」的兜底
    sys.stdout.write(extract(src, sys.argv[2]) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())

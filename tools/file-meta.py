#!/usr/bin/env python3
"""从一个成品幻灯片（files/ 下的 PDF / PPT / PPTX）里取标题与说明。

用法：
    python3 tools/file-meta.py <文件路径>

输出两行：第一行标题、第二行说明；取不到的输出空行，退出码 0。
只有参数用法错误才返回 2。

取值优先级（与幻灯片的 deck-meta.py 对齐：显式写出来的 > 文件自带的）：
  1. 同目录的旁车文件 `<主名>.md`：第一个非空行是标题（行首的 `#` 会去掉），
     其余非空行拼起来是说明。这是给「文件名只是代号、想给个正经标题」留的口子，
     也是 PPT（老二进制格式，元数据不在明文里）唯一能配标题的方式。
  2. 文件自带的元数据：PDF 的 /Title（文档信息字典或 XMP），PPTX 的
     docProps/core.xml 里的 dc:title。说明没有对应的通用字段，留空。
  3. 都取不到 → 空：调用方（workflow 导航页步骤）退回用文件名主名当标题、
     不渲染说明行（和 deck 的 title/subtitle 兜底语义一致）。

为什么不用现成的库：CI 里只有 python3 标准库可用，多装一个依赖就多一个
会静默失效的环节。这里是**尽力而为**的提取：PDF 的对象流被压缩时 /Title
可能读不到 —— 那属于「退回文件名」，不是静默截断，所以可接受
（与 deck-meta.py 不同：那边的输入是人手写的 Typst 源码，必须精确配平；
这边的输入是二进制成品文件，元数据本来就可有可无）。
"""

import os
import re
import sys
import zipfile


def from_sidecar(path: str):
    stem = os.path.splitext(path)[0]
    sidecar = stem + ".md"
    try:
        with open(sidecar, encoding="utf-8") as fh:
            lines = [ln.strip() for ln in fh.read().splitlines()]
    except OSError:
        return None
    lines = [ln for ln in lines if ln]
    if not lines:
        return None
    title = re.sub(r"^#+\s*", "", lines[0]).strip()
    desc = " ".join(lines[1:]).strip()
    return title, desc


def _pdf_string(raw: bytes) -> str:
    """解 PDF 字面字符串的字节：处理转义，并按 BOM 判断 UTF-16BE / Latin-1。"""
    if raw.startswith(b"\xfe\xff"):
        try:
            return raw[2:].decode("utf-16-be").strip()
        except UnicodeDecodeError:
            return ""
    out = bytearray()
    i = 0
    while i < len(raw):
        b = raw[i]
        if b == 0x5C and i + 1 < len(raw):  # 反斜杠转义
            nxt = raw[i + 1]
            simple = {0x6E: 10, 0x72: 13, 0x74: 9, 0x28: 0x28, 0x29: 0x29, 0x5C: 0x5C}
            if nxt in simple:
                out.append(simple[nxt])
                i += 2
                continue
            if 0x30 <= nxt <= 0x37:  # 八进制转义，最多 3 位
                j = i + 1
                val = 0
                while j < len(raw) and j < i + 4 and 0x30 <= raw[j] <= 0x37:
                    val = val * 8 + (raw[j] - 0x30)
                    j += 1
                out.append(val & 0xFF)
                i = j
                continue
            out.append(nxt)
            i += 2
            continue
        out.append(b)
        i += 1
    try:
        return bytes(out).decode("utf-8").strip()
    except UnicodeDecodeError:
        return bytes(out).decode("latin-1").strip()


def from_pdf(path: str) -> str:
    try:
        with open(path, "rb") as fh:
            data = fh.read()
    except OSError:
        return ""
    # 文档信息字典：/Title (字面字符串) —— Typst 与多数工具的未压缩输出都在明文里
    m = re.search(rb"/Title\s*\(((?:\\.|[^\\()])*)\)", data)
    if m:
        title = _pdf_string(m.group(1))
        if title:
            return title
    # XMP 元数据包：<dc:title> … <rdf:li …>标题</rdf:li>
    m = re.search(rb"<dc:title>.*?<rdf:li[^>]*>([^<]+)</rdf:li>", data, re.S)
    if m:
        try:
            return m.group(1).decode("utf-8").strip()
        except UnicodeDecodeError:
            return ""
    return ""


def from_pptx(path: str) -> str:
    try:
        with zipfile.ZipFile(path) as zf:
            core = zf.read("docProps/core.xml").decode("utf-8", "replace")
    except (OSError, KeyError, zipfile.BadZipFile):
        return ""
    m = re.search(r"<dc:title>([^<]*)</dc:title>", core)
    return m.group(1).strip() if m else ""


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("用法：file-meta.py <文件路径>\n")
        return 2
    path = sys.argv[1]
    sidecar = from_sidecar(path)
    if sidecar is not None:
        title, desc = sidecar
        sys.stdout.write(title + "\n" + desc + "\n")
        return 0
    ext = os.path.splitext(path)[1].lower()
    title = ""
    if ext == ".pdf":
        title = from_pdf(path)
    elif ext == ".pptx":
        title = from_pptx(path)
    sys.stdout.write(title + "\n\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())

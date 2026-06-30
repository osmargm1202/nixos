#!/usr/bin/env python3
"""Generate ORGM paginated HTML proposals from Markdown content."""
from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

LOGO_URL = "https://r2.or-gm.com/orgm.png"

CSS = r"""
:root{--blue:#0c2538;--accent:#58b8d9;--light:#eaf5f9;--mid:#5e7d8e;--text:#1f2933;--border:#d8e4ea;--white:#fff}
*{box-sizing:border-box}body{margin:0;background:#eef3f6;color:var(--text);font-family:Arial,Helvetica,sans-serif;line-height:1.46}
.sheet{width:8.5in;min-height:11in;margin:28px auto;background:#fff;box-shadow:0 14px 45px rgba(12,37,56,.16);position:relative;padding:.72in .68in .82in;overflow:hidden}
.cover{padding:0;background:var(--blue);color:#fff;display:flex;flex-direction:column;justify-content:space-between;min-height:11in}.cover:after{content:"";position:absolute;right:-125px;bottom:-125px;width:390px;height:390px;border:2px solid rgba(88,184,217,.28);border-radius:50%}
.cover.brand{background:radial-gradient(circle at 28% 18%,#2f6d7f 0,#12384b 42%,#07151f 100%)}.cover.brand:before{content:"";position:absolute;inset:0;background:linear-gradient(135deg,rgba(88,184,217,.18),transparent 42%),linear-gradient(0deg,rgba(255,255,255,.04),transparent);pointer-events:none}.cover.brand:after{border-color:rgba(125,227,255,.32)}
.cover.light-print{background:#f7fbfd;color:var(--blue);border:1px solid #d8e4ea}.cover.light-print:before{content:"";position:absolute;inset:0;background:linear-gradient(135deg,rgba(88,184,217,.16),transparent 48%);pointer-events:none}.cover.light-print:after{border-color:rgba(88,184,217,.30)}
.cover-top{padding:.74in .68in 0}.cover-main{padding:0 .68in}.cover-meta{padding:0 .68in .72in;color:#d7eef6;font-size:15px;display:grid;gap:7px}
.logo{width:170px;display:block}.eyebrow{color:var(--accent);letter-spacing:2.5px;text-transform:uppercase;font-size:14px;font-weight:700;margin-bottom:14px}
h1{font-size:48px;line-height:1.05;margin:0 0 12px;font-weight:800;letter-spacing:-1px}.subtitle{font-size:22px;color:#d7eef6;margin:0 0 28px}.rule{width:92px;height:4px;background:var(--accent);margin:24px 0}.cover.light-print .subtitle{color:#31586c}.cover.light-print .cover-meta{color:#31586c}.cover.light-print .logo{filter:none}.cover.light-print .rule{background:#2b8fb8}
.doc-top{display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid var(--border);padding-bottom:12px;margin-bottom:22px;color:var(--mid);font-size:12px;text-transform:uppercase;letter-spacing:.08em}.doc-top img{width:78px}
h2{font-size:25px;color:var(--blue);margin:0 0 13px;padding-bottom:8px;border-bottom:3px solid var(--accent)}h3{font-size:18px;color:var(--blue);margin:20px 0 8px}p{margin:0 0 11px}ul,ol{margin:7px 0 14px 22px;padding:0}li{margin:5px 0}
.box{background:var(--light);border:1px solid var(--border);border-left:5px solid var(--accent);padding:16px 18px;margin:16px 0}.box h3{margin-top:0}
table{width:100%;border-collapse:collapse;margin:13px 0 17px;font-size:13px}th{background:var(--blue);color:#fff;text-align:left;padding:10px 12px}td{border:1px solid var(--border);padding:10px 12px;vertical-align:top}.price{font-size:26px;color:var(--blue);font-weight:800}
.footer{position:absolute;left:.68in;right:.68in;bottom:.34in;border-top:1px solid var(--border);padding-top:8px;color:var(--mid);font-size:11px;display:flex;justify-content:space-between;gap:16px}.footer span:nth-child(2){text-align:center}.footer span:last-child{text-align:right}
@media print{@page{size:letter;margin:0}body{background:#fff}.sheet{width:8.5in;height:11in;min-height:11in;margin:0;box-shadow:none;page-break-after:always;break-after:page}.sheet:last-child{page-break-after:auto;break-after:auto}h2,h3{break-after:avoid}table,.box{break-inside:avoid;page-break-inside:avoid}tr{break-inside:avoid;page-break-inside:avoid}}
@media(max-width:900px){.sheet{width:100%;min-height:auto;margin:0 0 18px;padding:34px 24px 70px}.cover{min-height:720px}.cover-top,.cover-main,.cover-meta{padding-left:24px;padding-right:24px}h1{font-size:36px}.footer{left:24px;right:24px}}
""".strip()

SECTION_RE = re.compile(r"^#\s+(\d+)\.\s+(.+?)\s*$")


def inline_md(text: str) -> str:
    text = html.escape(text.strip())
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\*(.+?)\*", r"<em>\1</em>", text)
    return text


def blocks_to_html(lines: list[str]) -> str:
    out: list[str] = []
    i = 0
    while i < len(lines):
        raw = lines[i].rstrip()
        line = raw.strip()
        if not line or line == "---":
            i += 1
            continue
        if line.startswith("## "):
            out.append(f"<h3>{inline_md(line[3:])}</h3>"); i += 1; continue
        if line.startswith("### "):
            out.append(f"<h3>{inline_md(line[4:])}</h3>"); i += 1; continue
        if line.startswith(("* ", "- ")):
            items = []
            while i < len(lines) and lines[i].strip().startswith(("* ", "- ")):
                items.append(f"<li>{inline_md(lines[i].strip()[2:])}</li>")
                i += 1
            out.append("<ul>" + "".join(items) + "</ul>")
            continue
        if re.match(r"^\d+\.\s+", line):
            items = []
            while i < len(lines) and re.match(r"^\d+\.\s+", lines[i].strip()):
                items.append(f"<li>{inline_md(re.sub(r'^\d+\.\s+', '', lines[i].strip()))}</li>")
                i += 1
            out.append("<ol>" + "".join(items) + "</ol>")
            continue
        if "|" in line and i + 1 < len(lines) and set(lines[i+1].strip().replace("|", "").replace(" ", "")) <= {"-", ":"}:
            headers = [c.strip() for c in line.strip("|").split("|")]
            i += 2
            rows = []
            while i < len(lines) and "|" in lines[i]:
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            head = "".join(f"<th>{inline_md(h)}</th>" for h in headers)
            body = "".join("<tr>" + "".join(f"<td>{inline_md(c)}</td>" for c in r) + "</tr>" for r in rows)
            out.append(f"<table><tr>{head}</tr>{body}</table>")
            continue
        para = [line]
        i += 1
        while i < len(lines) and lines[i].strip() and not lines[i].strip().startswith(("#", "## ", "### ", "* ", "- ")) and not re.match(r"^\d+\.\s+", lines[i].strip()):
            para.append(lines[i].strip()); i += 1
        out.append(f"<p>{inline_md(' '.join(para))}</p>")
    return "\n".join(out)


def parse_sections(markdown: str) -> list[dict]:
    sections: list[dict] = []
    current = None
    for line in markdown.splitlines():
        m = SECTION_RE.match(line.strip())
        if m:
            if current:
                sections.append(current)
            current = {"num": int(m.group(1)), "title": m.group(2), "lines": []}
        elif current:
            current["lines"].append(line)
    if current:
        sections.append(current)
    return sections


def parse_layout(layout: str, sections: list[dict]) -> list[list[int]]:
    if layout:
        return [[int(x.strip()) for x in group.split(",") if x.strip()] for group in layout.split("|") if group.strip()]
    return [[s["num"]] for s in sections]


def render_page(group: list[int], by_num: dict[int, dict], page_num: int, proposal_name: str, company: str) -> str:
    parts = [f'<section class="sheet">', f'<div class="doc-top"><span>Propuesta Comercial</span><img src="{LOGO_URL}" alt="ORGM logo"></div>']
    for n in group:
        sec = by_num.get(n)
        if not sec:
            continue
        parts.append(f'<h2>{sec["num"]}. {inline_md(sec["title"])}</h2>')
        parts.append(blocks_to_html(sec["lines"]))
    parts.append(f'<div class="footer"><span>{html.escape(proposal_name)}</span><span>{html.escape(company)}</span><span>Página {page_num}</span></div>')
    parts.append('</section>')
    return "\n".join(parts)


def build(args) -> str:
    md = Path(args.input).read_text(encoding="utf-8")
    sections = parse_sections(md)
    if not sections:
        raise SystemExit("No numbered sections found. Use headings like '# 1. Presentación Ejecutiva'.")
    by_num = {s["num"]: s for s in sections}
    groups = parse_layout(args.layout, sections)
    pages = [render_page(g, by_num, i + 1, args.proposal_name, args.company) for i, g in enumerate(groups)]
    cover_theme = args.cover_theme if args.cover_theme in {"dark", "brand", "light-print"} else "dark"
    cover_class = "sheet cover" if cover_theme == "dark" else f"sheet cover {cover_theme}"
    cover = f'''<section class="{cover_class}">
  <div class="cover-top"><img class="logo" src="{LOGO_URL}" alt="ORGM logo"></div>
  <div class="cover-main"><div class="eyebrow">{html.escape(args.eyebrow)}</div><h1>{html.escape(args.title).replace(' | ', '<br>')}</h1><p class="subtitle">{html.escape(args.parties)}</p><div class="rule"></div><p class="subtitle">{html.escape(args.subtitle)}</p></div>
  <div class="cover-meta"><span><strong>Preparado por:</strong> {html.escape(args.prepared_by)}</span><span><strong>Fecha:</strong> {html.escape(args.date)}</span><span><strong>Vigencia:</strong> {html.escape(args.validity)}</span></div>
</section>'''
    return f'''<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{html.escape(args.proposal_name)} | {html.escape(args.parties)}</title><style>{CSS}</style></head>
<body>
{cover}
{chr(10).join(pages)}
</body></html>
'''


def main():
    ap = argparse.ArgumentParser(description="Generate ORGM paginated proposal HTML from numbered Markdown sections.")
    ap.add_argument("--input", required=True, help="Markdown file with numbered '# N. Title' sections")
    ap.add_argument("--output", required=True, help="HTML output path")
    ap.add_argument("--layout", default="", help="Page groups, e.g. '1,2|3|4,5|6|7,8,9|10,11,12'")
    ap.add_argument("--proposal-name", default="Strategic Local Partner Program")
    ap.add_argument("--company", default="ORGM")
    ap.add_argument("--title", default="Strategic Local | Partner Program")
    ap.add_argument("--parties", default="ORGM + Energy Asset")
    ap.add_argument("--subtitle", default="República Dominicana | Entrada Estratégica al Mercado Energético")
    ap.add_argument("--prepared-by", default="ORGM")
    ap.add_argument("--date", default="30 de abril de 2026")
    ap.add_argument("--validity", default="30 días")
    ap.add_argument("--eyebrow", default="Propuesta Comercial")
    ap.add_argument("--cover-theme", choices=["dark", "brand", "light-print"], default="dark", help="Cover visual style: dark, brand, or light-print")
    args = ap.parse_args()
    output = build(args)
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(output, encoding="utf-8")
    print(args.output)

if __name__ == "__main__":
    main()

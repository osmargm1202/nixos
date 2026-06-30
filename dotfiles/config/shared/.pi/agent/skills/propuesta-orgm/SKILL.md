---
name: propuesta-orgm
description: Use when generating ORGM-branded commercial proposals in paginated HTML from raw notes, existing proposal text, or Markdown content, especially proposals that need cover page, separate printable sheets, ORGM logo, page footers, and fixed print layout.
---

# Propuesta ORGM

## Overview

Generate ORGM commercial proposals as paginated HTML using the established ORGM format: dark corporate cover, ORGM logo, Letter-size sheets, sectioned pages, internal headers, and footers with proposal name, company, and page number.

Accept either raw proposal text or already structured Markdown. Preserve meaning and wording. Only restructure for formatting: headings, page separation, tables, bullets, and visual flow. Do not add commercial/legal content.

## Inputs Needed

Ask for missing values only when needed:

- Raw notes/proposal text OR Markdown content file with numbered sections: `# 1. ...`, `# 2. ...`
- Output HTML path
- Cover title, parties, subtitle, date, validity
- Cover theme: `dark`, `brand`, or `light-print`
- Page layout groups, e.g. `1,2|3|4,5|6|7,8,9|10,11,12`

## Workflow

1. Inspect input content.
2. If content is not already numbered Markdown, create a formatting-only source file first.
3. Choose page layout groups based on section count and content density.
4. Run generator script.
5. Verify HTML structure and print rules.

## Formatting Step for Raw Content

When source content is unstructured, convert it into `proposal-source.md` before generating HTML. This is formatting-only: preserve user content and do not add new business terms.

Required formatted shape:

```markdown
# 1. Presentación Ejecutiva
[Original executive opening text]

# 2. Objetivo del Servicio
[Original objective text]

# 3. Alcance del Servicio
## A. [Workstream]
* [Scope item]
* [Scope item]

# 4. Modelo / Metodología / Pipeline
[Original methodology/model/pipeline text]

# 5. Entregables
[Original deliverables text]

# 6. Honorarios / Inversión
[Original pricing/investment text]

# 7. Términos Clave
[Original terms text, only if provided]

# 8. Próximos Pasos
[Original next-steps text]

# 9. Cierre Ejecutivo
[Original closing/contact text]
```

Section names may change only when needed to reflect existing content. Top-level headings MUST remain numbered as `# N. Title`.

Formatting-only rules:

- Preserve all commercial meaning and commitments.
- Do not add new obligations, legal clauses, pricing, success fees, terms, disclaimers, or strategy.
- Do not remove content unless user explicitly asks.
- May fix typos, capitalization, spacing, and Markdown structure.
- May split long text into bullets when wording is preserved.
- May convert existing lists into tables when content maps cleanly.
- May create simple flow/order sections only from existing process steps.
- If important content seems missing, ask user; do not fill it in.

## Generator

Use bundled script:

```bash
python ~/.pi/skills/propuesta-orgm/scripts/generate_proposal_orgm.py \
  --input propuesta.md \
  --output output/propuesta.html \
  --layout '1,2|3|4,5|6|7,8,9|10,11,12' \
  --proposal-name 'Strategic Local Partner Program' \
  --company 'ORGM' \
  --title 'Strategic Local | Partner Program' \
  --parties 'ORGM + Energy Asset' \
  --subtitle 'República Dominicana | Entrada Estratégica al Mercado Energético' \
  --prepared-by 'ORGM' \
  --date '30 de abril de 2026' \
  --validity '30 días' \
  --cover-theme 'brand'
```

`--title` uses ` | ` as manual line break on cover.

## Cover Themes

Use `--cover-theme` to choose the portada:

| Theme | Use when | Ink use | Look |
|---|---|---:|---|
| `dark` | Premium digital PDF/proposal | High | Dark navy corporate cover |
| `brand` | Default ORGM branded cover | High/medium | Teal-navy gradient better matched to ORGM logo |
| `light-print` | Client will print proposal | Low | White/light cover with subtle cyan effects |

If user asks for print-friendly version, use `--cover-theme light-print`. If user asks for ORGM-branded polished version, use `--cover-theme brand`.

## Content Format for Generator

Generator input must use top-level numbered headings. If original content does not, format it first without changing business substance:

```markdown
# 1. Presentación Ejecutiva
Texto...

## Subtema
* Bullet
* Bullet

# 2. Objetivo del Servicio
Texto...
```

Supported Markdown:

| Element | Syntax |
|---|---|
| Main section | `# 1. Título` |
| Subheading | `## Título` or `### Título` |
| Bullets | `* item` or `- item` |
| Numbered lists | `1. item` |
| Tables | Pipe Markdown tables |
| Bold/italic | `**bold**`, `*italic*` |

## Choosing Page Layout

Use `--layout` to map sections to sheets:

- Short proposal: `1,2|3|4,5|6|7,8,9`
- Standard ORGM partner proposal: `1,2|3|4,5|6|7,8,9|10,11,12`
- If a section is long, put it alone: `1|2|3|4|5|6|7`

Never let page grouping imply content order changes. Renumber formatted content only if user asks to move sections.

## Page Layout Rules

- Cover is always separate and has no footer.
- Cover theme can be changed without changing proposal content.
- Every internal page is one `.sheet` section.
- Every internal page has top mini-header with ORGM logo.
- Every internal page has footer: proposal name, company, page number.
- Print CSS uses US Letter with `@page { size: letter; margin: 0 }`.
- Page grouping is controlled by `--layout`.

## Quality Checks

After generation, verify:

```bash
test -s output/propuesta.html
python - <<'PY'
from pathlib import Path
s = Path('output/propuesta.html').read_text()
assert '<section class="sheet cover">' in s
assert 'https://r2.or-gm.com/orgm.png' in s
assert '<div class="footer">' in s
assert '@page{size:letter;margin:0}' in s
print('OK')
PY
```

## Common Mistakes

- Running script on raw notes → format to numbered Markdown first, without adding new content.
- Missing numbered `# N. Title` sections → script cannot paginate.
- Putting all content in one section → only one internal sheet.
- Forgetting `--layout` → script creates one page per section.
- Overfilling a sheet → adjust `--layout` or shorten content; generator does not auto-flow across pages.
- Adding fixed logo CSS → do not use fixed logos; each sheet owns its own header.

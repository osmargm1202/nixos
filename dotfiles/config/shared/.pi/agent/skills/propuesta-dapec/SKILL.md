---
name: propuesta-dapec
description: This skill should be used when generating DAPEC SRL-branded commercial proposals for any service, including scanning/digitalization, civil works, electromechanical design/advisory, documentation, construction, renovation, repair, technical studies, or project support. It creates reusable proposal content and printable HTML templates using DAPEC SRL company data and RNC 131351247.
---

# Propuesta DAPEC

## Purpose

Generate professional DAPEC SRL proposals for any service using a reusable structure, DAPEC company identity, Spanish Dominican business tone, and printable Letter-size HTML output when requested.

Load `references/company-profile.md` when company legal details, RNC, business activity, or recommended wording are needed.

## Core Company Data

Use these values consistently:

- Short brand: **DAPEC SRL**
- Legal name: **DISEÑO Y ASESORIA DE PROYECTOS ELECTROMECANICOS Y CIVILES DAPEC SRL**
- RNC: **131351247**
- Status: **ACTIVO**
- Business orientation: diseño y asesoría de proyectos electromecánicos y civiles; construcción, reforma y reparación de edificios residenciales.

## When to Use

Use this skill for requests such as:

- Crear una propuesta para DAPEC SRL.
- Crear un template de propuesta DAPEC.
- Preparar propuesta de escaneo, digitalización, planos, memorias, cartas o documentos.
- Preparar propuesta para servicios civiles, electromecánicos, diseño, asesoría, construcción, reforma, reparación, documentación o gestión técnica.
- Convertir notas de un servicio en una propuesta formal DAPEC.
- Generar HTML imprimible de una propuesta DAPEC.

## Required Inputs

Proceed with placeholders when minor values are missing. Ask only when a missing value blocks the proposal.

Collect or infer:

- Client name.
- Service title.
- Service objective.
- Scope / activities.
- Deliverables.
- Execution time.
- Price / fees, or placeholder if not provided.
- Payment terms, or placeholder if not provided.
- Validity date/period, or placeholder if not provided.
- Output format: Markdown, HTML, PDF-ready HTML, or both.
- Logo preference: use `dapec_orgm.png` as the main DAPEC logo when the file is available in the proposal folder; otherwise ask for the DAPEC logo or use the provided logo path.
- Do not include the ORGM logo in DAPEC proposals unless the user explicitly requests it.

## Standard Proposal Structure

Create numbered Markdown first, using this structure:

1. Presentación Ejecutiva
2. Objetivo del Servicio
3. Alcance del Servicio
4. Metodología de Trabajo
5. Tiempo de Ejecución Estimado
6. Entregables
7. Supuestos y Requerimientos
8. Inversión / Honorarios
9. Próximos Pasos
10. Cierre

Use `assets/proposal-template.md` as the generic content skeleton.
Use `assets/scanning-service-example.md` when the service is escaneo/digitalización of documents.

## Writing Rules

- Write in formal Dominican Spanish.
- Keep tone technical, clear, commercial, and direct.
- Preserve user-provided service terms and prices.
- Do not invent prices, legal clauses, certifications, warranties, insurance terms, or binding commitments.
- Use placeholders like `[Completar monto]` when a value is unknown.
- Make the template reusable for any service, not only scanning.
- Adapt section titles only when it improves clarity while preserving the numbered structure.
- Mention DAPEC SRL and RNC on the cover or company data area.

## Scanning / Digitalization Proposal Pattern

For document scanning proposals, include:

- Manejo, organización y escaneo de documentos.
- Escaneo de planos, memorias, memorándums, cartas y documentos aprobados.
- Color or black-and-white scanning according to requirement.
- Physical sizes such as 8.5 x 11 inches and 11 x 17 inches when relevant.
- Quality control for legibility, orientation, complete pages, seals, signatures, and approvals.
- Digital delivery in PDF and organized folders.
- Minimum estimated execution time of **1.5 work days** for mainly 8.5 x 11 and 11 x 17 documents, subject to volume, physical condition, and classification requirements.
- Execution timing may be written as **a solicitud del cliente** and delivery **según requerimiento**, when requested.
- For the current scanning proposal, use service cost **US$10,250.00** and **40% avance de trabajos** unless the user changes these terms.

## Visual Form

Use **only lightmode** for all DAPEC proposals: portada clara, fondo blanco, detalles azul/teal, menor consumo de tinta, recomendado para impresión y envío formal.

Do not create, mention, or offer any alternate visual mode.

## Printable HTML Generation

When a polished printable proposal is requested, generate Markdown first and then run:

```bash
python /home/osmarg/.pi/agent/skills/propuesta-dapec/scripts/generate_dapec_proposal.py \
  --input propuesta.md \
  --output propuesta-dapec.html \
  --layout '1,2|3|4|5,6|7,8,9,10' \
  --proposal-name 'Propuesta de Servicio' \
  --title 'Propuesta de Servicio' \
  --subtitle 'Diseño y Asesoría de Proyectos Electromecánicos y Civiles' \
  --client 'Nombre del Cliente' \
  --date 'Fecha' \
  --validity 'Vigencia' \
  --logo-url 'dapec_orgm.png'
```

Adjust `--layout` to avoid overfilled pages:

- Short proposal: `1,2|3|4,5,6|7,8,9,10`
- Standard proposal: `1,2|3|4|5,6|7,8,9,10`
- Long proposal: `1|2|3|4|5|6|7|8,9,10`

## Quality Checks

After generating files:

- Verify the Markdown has numbered `# N. Title` headings.
- Verify HTML contains `DAPEC SRL`, `RNC 131351247`, `dapec_orgm.png`, and `@page{size:letter;margin:0}`.
- Verify the generated proposal uses **lightmode only**.
- Verify HTML does not contain `orgm.png` unless explicitly requested.
- Open or preview the HTML before final delivery when possible.
- If the client provides a different DAPEC logo later, pass it with `--logo-url` or update the generator default.

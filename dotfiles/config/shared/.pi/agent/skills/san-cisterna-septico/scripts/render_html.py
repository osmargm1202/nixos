#!/usr/bin/env python3
"""Render HTML para resultado.json de san-cisterna-septico."""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
from typing import Any, Iterable

M3_TO_GAL = 264.172052
L_PER_M3 = 1000.0


def e(value: Any) -> str:
    return html.escape("" if value is None else str(value), quote=True)


def fmt(value: Any, dec: int = 2) -> str:
    if value is None:
        return "—"
    try:
        n = float(value)
    except (TypeError, ValueError):
        return e(value)
    if abs(n - round(n)) < 10 ** (-(dec + 1)):
        return f"{n:,.0f}"
    return f"{n:,.{dec}f}"


def volume_text(volumen_m3: Any, volumen_l: Any = None, volumen_gal: Any = None) -> str:
    if volumen_m3 is None:
        return "—"
    try:
        m3 = float(volumen_m3)
    except (TypeError, ValueError):
        return e(volumen_m3)
    litros = float(volumen_l) if volumen_l is not None else m3 * L_PER_M3
    gal = float(volumen_gal) if volumen_gal is not None else m3 * M3_TO_GAL
    return f"{fmt(m3,2)} m³ ({fmt(litros,0)} L / {fmt(gal,0)} gal)"


def volume_text_from_obj(obj: dict | None, key: str = "volumen_m3") -> str:
    if not obj:
        return "—"
    return volume_text(obj.get(key), obj.get("volumen_l"), obj.get("volumen_gal"))


def table(headers: list[str], rows: Iterable[Iterable[Any]], cls: str = "") -> str:
    head = "".join(f"<th>{e(h)}</th>" for h in headers)
    body = []
    for row in rows:
        body.append("<tr>" + "".join(f"<td>{cell}</td>" for cell in row) + "</tr>")
    return f'<table class="{e(cls)}"><thead><tr>{head}</tr></thead><tbody>{"".join(body)}</tbody></table>'


def mini_header(project: dict, right: str) -> str:
    return f"""
    <div class="header-mini">
      <div>
        <div class="header-mini-title">{e(project.get('titulo_memoria','Memoria de Cálculo'))}</div>
        <div>{e(project.get('nombre',''))} | {e(project.get('cliente',''))}</div>
      </div>
      <div class="header-mini-meta">{e(right)}<br>{e(project.get('ubicacion',''))}</div>
    </div>
    """


def css() -> str:
    # Basado en referencia/base.html: carta, portada, header-mini, tablas, tarjetas y KaTeX.
    return r"""
@page { size: letter; margin: 0.35in; }
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: Arial, Helvetica, sans-serif; font-size: 9.2pt; line-height: 1.28; color: #202020; background: #fff; counter-reset: page; }
.page { page-break-after: always; min-height: 10in; display: flex; flex-direction: column; position: relative; padding: 0.15in; counter-increment: page; }
.page:last-child { page-break-after: auto; }
.page.no-page-number { counter-increment: none; }
h1 { font-size: 14pt; font-weight: 700; text-transform: uppercase; letter-spacing: .5px; margin-bottom: .15in; color: #1a1a1a; border-bottom: 2px solid #333; padding-bottom: .08in; }
h2 { font-size: 11pt; font-weight: 700; text-transform: uppercase; letter-spacing: .3px; margin-top: .18in; margin-bottom: .10in; border-bottom: 1px solid #555; padding-bottom: .04in; }
h3 { font-size: 10pt; font-weight: 700; margin-top: .15in; margin-bottom: .08in; }
h4 { font-size: 9.2pt; font-weight: 700; margin-top: .12in; margin-bottom: .06in; color: #333; }
p { margin-bottom: .1in; text-align: justify; }
ul, ol { margin-left: .28in; margin-top: .06in; margin-bottom: .08in; }
li { margin-bottom: .04in; }
table { width: 100%; border-collapse: collapse; margin: .08in 0 .12in 0; font-size: 7.8pt; line-height: 1.12; page-break-inside: auto; }
th, td { border: 1px solid #b9b9b9; padding: 4px 5px; text-align: left; vertical-align: top; }
th { background: #eee; font-weight: 700; text-transform: uppercase; font-size: 7.2pt; border-bottom: 2px solid #777; }
tbody tr:nth-child(even) { background: #fafafa; }
.compact-table { font-size: 7.6pt; }
.wide-table { font-size: 7pt; }
.result-table td:last-child { font-weight: 700; text-align: right; }
.header-mini { display: grid; grid-template-columns: 1fr 1fr; gap: .12in; border-bottom: 2px solid #333; padding-bottom: .08in; margin-bottom: .12in; font-size: 8pt; }
.header-mini-title { font-weight: 700; text-transform: uppercase; font-size: 10pt; }
.header-mini-meta { text-align: right; }
.footer { margin-top: auto; border-top: 1px solid #ccc; padding-top: .06in; font-size: 7.5pt; text-align: center; color: #666; }
.footer::after { content: " | Pág. " counter(page); }
.page.no-page-number .footer::after { content: ""; }
.infobox { border: 1px solid #999; padding: .1in; margin: .12in 0; background: #fafafa; border-radius: 3px; }
.infobox.note { border-style: dashed; background: #f9f9f9; }
.infobox.result { background: #eee; border: 2px solid #666; }
.infobox-title { font-weight: 700; text-transform: uppercase; font-size: 8.4pt; margin-bottom: .06in; }
.teoria-formula-block { background: #f8f8f8; border: 1px solid #ccc; border-left: 4px solid #0b5cad; padding: .1in; margin: .12in 0; text-align: center; page-break-inside: avoid; }
.teoria-definiciones { font-size: 7.8pt; margin-top: .06in; color: #555; text-align: left; }
.grid-two { display: grid; grid-template-columns: 1fr 1fr; gap: .16in; }
.metric-card { border: 2px solid #333; padding: .12in; margin: .08in 0; text-align: center; background: #f5f5f5; }
.metric-label { font-size: 8pt; text-transform: uppercase; color: #555; margin-bottom: .04in; }
.metric-value { font-size: 15pt; font-weight: 800; }
.metric-sub { font-size: 8pt; color: #444; margin-top: .03in; }
.resultados-summary { background: #f0f0f0; border: 2px solid #666; padding: .15in; margin-bottom: .18in; }
.resultados-summary-title { font-size: 11pt; font-weight: 700; margin-bottom: .1in; }
.resultados-summary-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: .08in; }
.resultados-summary-item { padding: .08in; background: #fff; border: 1px solid #ccc; text-align: center; }
.resultados-summary-label { font-weight: 700; color: #555; display: block; font-size: 7.5pt; text-transform: uppercase; }
.resultados-summary-value { font-size: 12pt; font-weight: 800; display: block; margin-top: .03in; }
.resultados-area { margin-bottom: .28in; border: 1px solid #999; padding: .15in; background: #fff; page-break-inside: avoid; }
.resultados-area-header { background: #e5e5e5; padding: .08in .1in; margin: -.15in -.15in .12in -.15in; border-bottom: 2px solid #666; }
.resultados-area-title { font-size: 10pt; font-weight: 800; color: #111; }
.equipment-subtitle { font-size: 7.8pt; margin-top: .03in; color: #555; }
.muted { color: #777; font-style: italic; font-size: 8pt; }
.avoid-break { break-inside: avoid; page-break-inside: avoid; }
.portada { display: flex; flex-direction: column; justify-content: flex-start; align-items: center; min-height: 9.2in; text-align: center; padding-top: .35in; }
.portada-logos { display: flex; justify-content: center; align-items: center; gap: 1in; margin-bottom: .55in; }
.portada-logo-slot { width: 2.5in; height: 1.5in; display: flex; align-items: center; justify-content: center; }
.portada-logo { max-width: 2.5in; max-height: 1.5in; object-fit: contain; }
.portada-titulo { font-size: 20pt; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin-bottom: .32in; border-top: 2px solid #333; border-bottom: 2px solid #333; padding: .22in .5in; color: #1a1a1a; }
.portada-proyecto { font-size: 16pt; font-weight: 600; margin-bottom: .22in; color: #333; }
.portada-info { font-size: 11pt; line-height: 1.35; margin-bottom: .42in; }
.portada-info div { margin-bottom: .08in; }
.portada-firma { margin-top: .25in; font-size: 10pt; color: #555; }
.portada-firma-line { border-top: 1px solid #333; width: 3in; margin-left: auto; margin-right: auto; padding-top: .1in; }
.fin { display: flex; flex-direction: column; justify-content: center; align-items: center; min-height: 8in; text-align: center; }
.fin-titulo { font-size: 18pt; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin-bottom: .5in; border-top: 2px solid #333; border-bottom: 2px solid #333; padding: .2in .5in; }
.fin-nota { font-size: 10pt; line-height: 1.6; max-width: 6in; margin-bottom: .5in; color: #555; text-align: center; }
@media print { body { margin: 0; padding: 0; } .page { margin: 0; padding: .15in; } .resultados-area { page-break-inside: avoid; } }
"""


def render_portada(project: dict, resumen: dict) -> str:
    logos = project.get("logos") or []
    logo_html = "".join(
        f'<div class="portada-logo-slot"><img src="{e(l.get("url", ""))}" class="portada-logo" alt="{e(l.get("alt", "logo"))}"></div>'
        for l in logos if l.get("url")
    )
    ing = project.get("ingeniero") or {}
    return f"""
<section class="page no-page-number">
  <div class="portada">
    <div class="portada-logos">{logo_html}</div>
    <div class="portada-titulo">{e(project.get('titulo_memoria', 'Memoria de Cálculo'))}</div>
    <div class="portada-proyecto">{e(project.get('nombre',''))}</div>
    <div class="portada-info">
      <div><strong>ID DEL PROYECTO:</strong> {e(project.get('id',''))}</div>
      <div><strong>CLIENTE:</strong> {e(project.get('cliente',''))}</div>
      <div><strong>EMPRESA:</strong> {e(project.get('empresa',''))}</div>
      <div><strong>INGENIERO:</strong> {e(ing.get('nombre',''))}</div>
      <div><strong>CÓDIGO:</strong> {e(ing.get('codia',''))}</div>
      <div><strong>UBICACIÓN:</strong> {e(project.get('ubicacion',''))}</div>
      <div><strong>FECHA:</strong> {e(project.get('fecha',''))}</div>
    </div>
    <div class="infobox result" style="width: 5.8in; text-align: left;">
      <div class="infobox-title">Resultado general</div>
      <strong>Consumo diario:</strong> {fmt(resumen.get('consumo_total_l_dia'), 1)} L/día<br>
      <strong>Caudal máximo horario:</strong> {fmt(resumen.get('qmax_horario_lps'), 3)} L/s ({fmt(resumen.get('qmax_horario_gpm'), 2)} GPM)<br>
      <strong>Cisterna requerida:</strong> {fmt(resumen.get('volumen_cisternas_requerido_m3'), 2)} m³<br>
      <strong>Séptico requerido:</strong> {fmt(resumen.get('volumen_septicos_requerido_m3'), 2)} m³
    </div>
    <div class="portada-firma"><div class="portada-firma-line"></div>{e(ing.get('nombre',''))}<br>{e(project.get('empresa',''))}</div>
  </div>
</section>
"""


def render_intro(result: dict) -> str:
    p = result["project"]
    r = result["resumen"]
    rows = [
        ["Tipo de proyecto", e(p.get("tipo_proyecto", ""))],
        ["Normativa", e(p.get("normativa", ""))],
        ["Suministros", fmt(r.get("suministros"), 0)],
        ["Viviendas", fmt(r.get("viviendas"), 0)],
        ["Habitantes de diseño", fmt(r.get("habitantes_diseno"), 0)],
        ["Cisternas calculadas", fmt(r.get("cisternas"), 0)],
        ["Sépticos calculados", fmt(r.get("septicos"), 0)],
    ]
    return f"""
<section class="page">
{mini_header(p, 'Introducción')}
<h1>1. Introducción</h1>
<p>La presente memoria documenta el dimensionamiento hidráulico preliminar para cisternas de almacenamiento de agua potable y cámaras sépticas asociadas a los suministros declarados del proyecto <strong>{e(p.get('nombre',''))}</strong>.</p>
<p>El cálculo se desarrolla por suministros y por grupos de diseño. Cada cisterna o séptico puede atender un suministro individual, todos los suministros, o un subconjunto definido por el usuario.</p>
<h2>1.1 Datos generales</h2>
{table(['Concepto','Valor'], rows, 'compact-table')}
<div class="infobox note"><div class="infobox-title">Nota de alcance</div>La memoria no sustituye validaciones de campo, permisos, estudio de suelo, infiltración, estructural, ni revisión final contra planos definitivos.</div>
<div class="footer">{e(p.get('titulo_memoria','Memoria'))} | {e(p.get('nombre',''))}</div>
</section>
"""


def render_teoria(result: dict) -> str:
    p = result["project"]
    c = result["criterios"]
    return f"""
<section class="page">
{mini_header(p, 'Teoría del cálculo')}
<h1>2. Teoría del cálculo</h1>
<p>Los consumos se calculan con dotaciones unitarias por habitante, vivienda, área o unidad de uso. Las dotaciones base provienen del R-008 y pueden ser sobrescritas por el usuario en el archivo de entrada.</p>
<h2>2.1 Consumo medio diario</h2>
<div class="teoria-formula-block">$$QMD = \\sum(Cantidad_i \\times Dotación_i)$$<div class="teoria-definiciones">QMD en L/día.</div></div>
<h2>2.2 Caudales de diseño</h2>
<div class="teoria-formula-block">$$Q_{{maxD}} = QMD \\times K_d$$ $$q_{{maxH}} = \\frac{{Base \\times K_h}}{{86400}}$$<div class="teoria-definiciones">Kd={fmt(c.get('kd'),2)}, Kh={fmt(c.get('kh'),2)}, base QMH={e(c.get('qmh_base'))}.</div></div>
<h2>2.3 Volumen de cisterna</h2>
<div class="teoria-formula-block">$$V_{{cisterna}} = \\frac{{QMD \\times Días}}{{1000}} + V_{{incendio}}$$<div class="teoria-definiciones">R-008 Art. 55: mínimo 2 días de consumo medio diario; 1.5 días permitido para más de 16 viviendas o equivalente.</div></div>
<h2>2.4 Volumen de séptico por fórmula</h2>
<div class="teoria-formula-block">$$Q_{{AR}} = QMD \\times F_{{AR}}$$ $$V_{{séptico}} = \\frac{{Q_{{AR}} \\times T_R}}{{1000}} + \\frac{{Hab_{{eq}} \\times Lodos \\times Años}}{{1000}}$$<div class="teoria-definiciones">Factor AR={fmt(c.get('factor_aguas_residuales'),2)}, retención={fmt(c.get('retencion_septico_dias'),2)} días, lodos={fmt(c.get('lodos_l_hab_anio'),0)} L/hab·año.</div></div>
<h2>2.5 Criterios normativos destacados</h2>
<ul><li>R-008 Art. 310: población mínima residencial de 6 habitantes por vivienda si aplica.</li><li>R-008 Art. 273: cámara séptica rectangular, largo 2 a 3 veces ancho, altura útil 1.00 a 1.60 m.</li><li>R-008 Art. 274: dos compartimientos con 2/3 y 1/3 de volumen.</li><li>R-008 Art. 281: viviendas usan Tablas 32/33; otras edificaciones usan Tabla 34.</li><li>R-008 Art. 282: dimensiones recomendables de cámaras sépticas en viviendas según Tablas 32/33.</li><li>R-008 Art. 283: separación mínima cisterna-cámara séptica de 5.00 m.</li></ul>
<div class="footer">{e(p.get('titulo_memoria','Memoria'))} | {e(p.get('nombre',''))}</div>
</section>
"""


def render_referencias_normativas(result: dict) -> str:
    p = result["project"]
    refs = result.get("referencias_normativas_usadas") or []
    if refs:
        rows = [[e(ref.get("referencia", "")), e(ref.get("uso", ""))] for ref in refs]
        body = table(["Referencia", "Uso aplicado"], rows, "compact-table")
    else:
        body = '<div class="infobox note">No se declararon referencias normativas específicas para las dotaciones del proyecto.</div>'
    return f"""
<section class="page">
{mini_header(p, 'Referencias normativas')}
<h1>3. Referencias normativas aplicadas</h1>
<p>Esta tabla lista únicamente las referencias usadas por los datos y métodos aplicados en este cálculo.</p>
{body}
<div class="footer">{e(p.get('titulo_memoria','Memoria'))} | {e(p.get('nombre',''))}</div>
</section>
"""


def render_resumen(result: dict) -> str:
    p = result["project"]
    r = result["resumen"]
    suministro_rows = []
    for s in result["suministros"]:
        suministro_rows.append([
            e(s["id"]), e(s["nombre"]), e(s["tipo"]), fmt(s["viviendas"], 0), fmt(s["personas_diseno"], 0),
            fmt(s["consumo_total_l_dia"], 1), fmt(s["qmax_horario_lps"], 3), fmt(s["qmax_horario_gpm"], 2)
        ])
    return f"""
<section class="page">
{mini_header(p, 'Resumen de resultados')}
<h1>3. Resumen general</h1>
<div class="resultados-summary"><div class="resultados-summary-title">Resultado general</div><div class="resultados-summary-grid">
  <div class="resultados-summary-item"><span class="resultados-summary-label">Consumo diario</span><span class="resultados-summary-value">{fmt(r.get('consumo_total_l_dia'),0)}</span><span>L/día</span></div>
  <div class="resultados-summary-item"><span class="resultados-summary-label">Q máx horario</span><span class="resultados-summary-value">{fmt(r.get('qmax_horario_lps'),3)}</span><span>L/s</span></div>
  <div class="resultados-summary-item"><span class="resultados-summary-label">Cisternas</span><span class="resultados-summary-value">{fmt(r.get('volumen_cisternas_requerido_m3'),2)}</span><span>m³ req.</span></div>
  <div class="resultados-summary-item"><span class="resultados-summary-label">Sépticos</span><span class="resultados-summary-value">{fmt(r.get('volumen_septicos_requerido_m3'),2)}</span><span>m³ req.</span></div>
</div></div>
<h2>3.1 Suministros</h2>
{table(['ID','Nombre','Tipo','Viv.','Hab. diseño','L/día','QMH L/s','QMH GPM'], suministro_rows, 'compact-table')}
<div class="footer">{e(p.get('titulo_memoria','Memoria'))} | {e(p.get('nombre',''))}</div>
</section>
"""


def render_suministros(result: dict) -> str:
    p = result["project"]
    blocks = []
    for s in result["suministros"]:
        rows = [[e(i["concepto"]), fmt(i["cantidad"], 2), e(i["unidad"]), fmt(i["dotacion_l_unidad_dia"], 2), fmt(i["consumo_l_dia"], 1), e(i.get("fuente", ""))] for i in s["consumos"]]
        blocks.append(f"""
<section class="resultados-area avoid-break">
  <div class="resultados-area-header"><div class="resultados-area-title">{e(s['id'])} — {e(s['nombre'])}</div><div class="equipment-subtitle">Tipo: {e(s['tipo'])} | Viviendas: {fmt(s['viviendas'],0)} | Habitantes diseño: {fmt(s['personas_diseno'],0)}</div></div>
  <div class="grid-two"><div>
    <h4>Datos y consumos</h4>{table(['Concepto','Cantidad','Unidad','Dotación','Consumo L/día','Fuente'], rows, 'compact-table')}
  </div><div>
    <h4>Resultado hidráulico</h4><div class="metric-card"><div class="metric-label">Consumo total</div><div class="metric-value">{fmt(s['consumo_total_l_dia'],0)} L/día</div><div class="metric-sub">QMH {fmt(s['qmax_horario_lps'],3)} L/s | {fmt(s['qmax_horario_gpm'],2)} GPM</div></div>
    {table(['Parámetro','Valor'], [['QMD', fmt(s['qmd_lps'],5)+' L/s'], ['Qmax diario', fmt(s['qmax_diario_l_dia'],1)+' L/día'], ['Qmax horario', fmt(s['qmax_horario_lps'],3)+' L/s']], 'compact-table result-table')}
  </div></div>
  <p class="muted">{e(s.get('notas',''))}</p>
</section>
""")
    return f"""
<section class="page">
{mini_header(p, 'Detalle de suministros')}
<h1>4. Cálculo por suministros</h1>
{''.join(blocks)}
<div class="footer">{e(p.get('titulo_memoria','Memoria'))} | {e(p.get('nombre',''))}</div>
</section>
"""


def dims_text(d: dict, kind: str) -> str:
    if not d:
        return "—"
    vol = volume_text_from_obj(d)
    if kind == "cisterna":
        return f"{fmt(d.get('largo_m'),2)} × {fmt(d.get('ancho_m'),2)} × {fmt(d.get('alto_util_m', d.get('alto_m')),2)} m = {vol}"
    if d.get("compartimientos") == 2 and d.get("largo_1_m"):
        return f"L1 {fmt(d.get('largo_1_m'),2)} + L2 {fmt(d.get('largo_2_m'),2)} × {fmt(d.get('ancho_m'),2)} × {fmt(d.get('profundidad_util_m'),2)} m = {vol}"
    return f"{fmt(d.get('largo_m'),2)} × {fmt(d.get('ancho_m'),2)} × {fmt(d.get('profundidad_util_m'),2)} m = {vol}"


def catalogo_guia_table(options: list[dict], kind: str) -> str:
    rows = []
    for opt in options or []:
        rows.append([
            e(opt.get("nombre", f"Opción {opt.get('opcion', '')}")),
            e(dims_text(opt, kind)),
            volume_text_from_obj(opt),
            fmt(opt.get("margen_m3"), 2) + " m³",
            "Sí" if opt.get("cumple") else "No",
        ])
    return table(["Opción", "Dimensiones", "Volumen", "Margen", "Cumple"], rows, "compact-table")


def render_cisternas(result: dict) -> str:
    p = result["project"]
    blocks = []
    for c in result["cisternas"]:
        rows = [
            ["Suministros", e(", ".join(c["suministros"]))],
            ["Consumo grupo", fmt(c["consumo_total_l_dia"],1)+" L/día"],
            ["Base cálculo", e(c.get("base_calculo_descripcion", "Caudal medio diario"))],
            ["Días abastecimiento", fmt(c["dias_abastecimiento"],2)],
            ["Volumen incendio", fmt(c["volumen_incendio_m3"],2)+" m³"],
            ["Volumen requerido", volume_text(c["volumen_requerido_m3"], c.get("volumen_requerido_l"), c.get("volumen_requerido_gal"))],
            ["Dimensión propuesta", e(dims_text(c["dimension_propuesta"], "cisterna"))],
            ["Cumplimiento", "CUMPLE" if c["cumple"] else "NO CUMPLE"],
            ["Factor diseño", fmt(c.get("factor_seguridad"),2)],
            ["Factor cumplimiento", fmt(c.get("factor_cumplimiento"),2)],
            ["Caudal llenado", fmt(c.get("caudal_llenado_lps"),4)+" L/s"],
            ["Acometida aprox.", fmt((c.get("acometida_aproximada") or {}).get("diametro_pulg"),2)+'"'],
            ["Rebose recomendado", e((c.get("rebose_recomendado") or {}).get("diametro_rebose_pulg", "—"))],
        ]
        blocks.append(f"""
<section class="resultados-area avoid-break"><div class="resultados-area-header"><div class="resultados-area-title">{e(c['id'])} — {e(c['nombre'])}</div><div class="equipment-subtitle">{e(c['criterio_dias'])}</div></div>
<div class="grid-two"><div><h4>Datos de grupo</h4>{table(['Parámetro','Valor'], rows[:4], 'compact-table')}</div><div><h4>Resultado cisterna</h4><div class="metric-card"><div class="metric-label">Volumen requerido</div><div class="metric-value">{fmt(c['volumen_requerido_m3'],2)} m³</div><div class="metric-sub">{fmt(c.get('volumen_requerido_l'),0)} L | {fmt(c['volumen_requerido_gal'],0)} galones</div></div>{table(['Parámetro','Valor'], rows[4:], 'compact-table result-table')}</div></div><h4>Opciones guía de dimensiones</h4>{catalogo_guia_table(c.get('opciones_dimensionamiento', []), 'cisterna')}</section>
""")
    return f"""
<section class="page">
{mini_header(p, 'Diseño de cisternas')}
<h1>5. Diseño de cisternas</h1>
<p>El volumen requerido se calcula con el consumo medio diario del grupo de suministros y los días de abastecimiento definidos.</p>
{''.join(blocks)}
<div class="footer">{e(p.get('titulo_memoria','Memoria'))} | {e(p.get('nombre',''))}</div>
</section>
"""


def tabla_r008_vivienda_html(ref: dict | None) -> str:
    if not ref:
        return ""
    rows = [
        ["Tabla", e(ref.get("tabla", ""))],
        ["Personas equivalentes", fmt(ref.get("personas_equivalentes"), 0)],
        ["Rango de personas", e(ref.get("rango_personas", ""))],
        ["Compartimientos", e(ref.get("tipo_camara", ""))],
        ["Volumen útil mínimo", volume_text(ref.get("volumen_m3"), ref.get("volumen_l"), ref.get("volumen_gal"))],
        ["Dimensiones normativas", e(dims_text(ref, "septico"))],
    ]
    return f"<h4>Referencia normativa vivienda — Tablas 32/33</h4>{table(['Parámetro','Valor'], rows, 'compact-table')}"


def tabla_34_items_html(items: list[dict]) -> str:
    if not items:
        return ""
    rows = []
    for item in items:
        rows.append([
            e(item.get("concepto", "")),
            e(item.get("tipo_edificacion_tabla_34", item.get("tabla_34_key", ""))),
            fmt(item.get("cantidad"), 2),
            e(item.get("unidad", "")),
            f"{fmt(item.get('volumen_l_unidad'),1)} L / {fmt(item.get('volumen_gal_unidad'),1)} gal",
            volume_text(item.get("volumen_m3"), item.get("volumen_l"), item.get("volumen_gal")),
        ])
    return f"<h4>Tipo edificación Tabla 34</h4>{table(['Concepto','Clave','Cantidad','Unidad','Capacidad unitaria','Volumen mínimo'], rows, 'compact-table')}"


def render_septicos(result: dict) -> str:
    p = result["project"]
    blocks = []
    for s in result["septicos"]:
        comp_rows = [[e(c["concepto"]), volume_text(c.get("volumen_m3"), c.get("volumen_l"), c.get("volumen_gal"))] for c in s.get("componentes", [])]
        vivienda_ref = tabla_r008_vivienda_html(s.get("tabla_r008_vivienda"))
        tabla_34_ref = tabla_34_items_html(s.get("tabla_34_items", []))
        rows = [
            ["Suministros", e(", ".join(s["suministros"]))],
            ["Clasificación de uso", e(s.get("clasificacion_uso", ""))],
            ["Método", e(s["metodo"])],
            ["Fuente", e(s["fuente"])],
            ["Aguas residuales", fmt(s["aguas_residuales_l_dia"],1)+" L/día"],
            ["Habitantes equivalentes", fmt(s["habitantes_equivalentes"],0)],
            ["Volumen fórmula", volume_text(s.get("volumen_formula_m3"), s.get("volumen_formula_l"), s.get("volumen_formula_gal"))],
            ["Volumen Tabla 32/33", volume_text(s.get("volumen_tabla_r008_m3"), s.get("volumen_tabla_r008_l"), s.get("volumen_tabla_r008_gal")) if s.get("volumen_tabla_r008_m3") is not None else "—"],
            ["Volumen Tabla 34", volume_text(s.get("volumen_tabla_34_m3"), s.get("volumen_tabla_34_l"), s.get("volumen_tabla_34_gal")) if s.get("volumen_tabla_34_m3") is not None else "—"],
            ["Volumen requerido", volume_text(s["volumen_requerido_m3"], s.get("volumen_requerido_l"), s.get("volumen_requerido_gal"))],
            ["Método aplicado", e(s.get("metodo_aplicado", s.get("fuente", "")))],
            ["Dimensión propuesta", e(dims_text(s["dimension_propuesta"], "septico"))],
            ["Cumplimiento", "CUMPLE" if s["cumple"] else "NO CUMPLE"],
            ["Factor diseño", fmt(s.get("factor_seguridad"),2)],
            ["Factor cumplimiento", fmt(s.get("factor_cumplimiento"),2)],
        ]
        blocks.append(f"""
<section class="resultados-area avoid-break"><div class="resultados-area-header"><div class="resultados-area-title">{e(s['id'])} — {e(s['nombre'])}</div><div class="equipment-subtitle">Habitantes equiv.: {fmt(s['habitantes_equivalentes'],0)} | Método: {e(s['metodo'])}</div></div>
<div class="grid-two"><div><h4>Datos de grupo</h4>{table(['Parámetro','Valor'], rows[:6], 'compact-table')}<h4>Componentes</h4>{table(['Componente','Volumen'], comp_rows, 'compact-table')}{vivienda_ref}{tabla_34_ref}</div><div><h4>Resultado séptico</h4><div class="metric-card"><div class="metric-label">Volumen requerido</div><div class="metric-value">{fmt(s['volumen_requerido_m3'],2)} m³</div><div class="metric-sub">{fmt(s.get('volumen_requerido_l'),0)} L | {fmt(s['volumen_requerido_gal'],0)} galones</div></div>{table(['Parámetro','Valor'], rows[6:], 'compact-table result-table')}</div></div><h4>Opciones guía de dimensiones</h4>{catalogo_guia_table(s.get('opciones_dimensionamiento', []), 'septico')}</section>
""")
    return f"""
<section class="page">
{mini_header(p, 'Diseño de sistemas sépticos')}
<h1>6. Diseño de sistemas sépticos</h1>
<p>Los sistemas sépticos se calculan por grupo de suministros, permitiendo cámaras individuales, comunes o por zonas.</p>
{''.join(blocks)}
<div class="footer">{e(p.get('titulo_memoria','Memoria'))} | {e(p.get('nombre',''))}</div>
</section>
"""


def render_conclusiones(result: dict) -> str:
    p = result["project"]
    obs = result.get("observaciones") or []
    notas = result.get("notas_tecnicas") or []
    li = "".join(f"<li>{e(x)}</li>" for x in obs + notas)
    return f"""
<section class="page">
{mini_header(p, 'Conclusiones')}
<h1>7. Conclusiones y recomendaciones</h1>
<div class="infobox result"><div class="infobox-title">Resumen del sistema diseñado</div>
<strong>Consumo diario total:</strong> {fmt(result['resumen']['consumo_total_l_dia'],1)} L/día<br>
<strong>Caudal máximo horario:</strong> {fmt(result['resumen']['qmax_horario_lps'],3)} L/s<br>
<strong>Volumen total de cisternas requerido:</strong> {fmt(result['resumen']['volumen_cisternas_requerido_m3'],2)} m³<br>
<strong>Volumen total de sépticos requerido:</strong> {fmt(result['resumen']['volumen_septicos_requerido_m3'],2)} m³
</div>
<h2>7.1 Recomendaciones técnicas</h2><ul>{li}</ul>
<p>Los resultados deben verificarse contra planos finales, condiciones de suelo, ubicación real de cisternas y cámaras sépticas, permisos aplicables y criterios de la autoridad competente.</p>
<div class="footer">{e(p.get('titulo_memoria','Memoria'))} | {e(p.get('nombre',''))}</div>
</section>
<section class="page no-page-number"><div class="fin"><div class="fin-titulo">Fin de la memoria</div><div class="fin-nota">Documento generado desde resultado.json por la skill san-cisterna-septico.</div></div></section>
"""


def render(result: dict) -> str:
    project = result["project"]
    title = f"{project.get('titulo_memoria','Memoria')} - {project.get('nombre','')}"
    return f"""<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>{e(title)}</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body, {{delimiters:[{{left:'$$',right:'$$',display:true}},{{left:'$',right:'$',display:false}},{{left:'\\(',right:'\\)',display:false}},{{left:'\\[',right:'\\]',display:true}}], throwOnError:false}});"></script>
<style>{css()}</style></head><body>
{render_portada(project, result['resumen'])}
{render_intro(result)}
{render_teoria(result)}
{render_referencias_normativas(result)}
{render_resumen(result)}
{render_suministros(result)}
{render_cisternas(result)}
{render_septicos(result)}
{render_conclusiones(result)}
</body></html>"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Renderiza memoria.html desde resultado.json")
    parser.add_argument("--project-id", help="ID dentro de proyectos/[id]")
    parser.add_argument("--resultado", help="Ruta explícita a resultado.json")
    parser.add_argument("--cwd", default=".", help="Raíz del proyecto; default pwd")
    parser.add_argument("--output", help="Ruta de salida HTML")
    args = parser.parse_args()

    cwd = Path(args.cwd).resolve()
    if args.resultado:
        result_path = Path(args.resultado)
        if not result_path.is_absolute():
            result_path = cwd / result_path
    elif args.project_id:
        result_path = cwd / "proyectos" / args.project_id / "resultado.json"
    else:
        raise SystemExit("Use --project-id o --resultado")

    result = json.loads(result_path.read_text(encoding="utf-8"))
    html_text = render(result)
    out = Path(args.output) if args.output else result_path.with_name("memoria.html")
    if not out.is_absolute():
        out = cwd / out
    out.write_text(html_text, encoding="utf-8")
    print(f"OK HTML: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

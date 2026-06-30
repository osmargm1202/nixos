from __future__ import annotations

import argparse
import json
from html import escape
from pathlib import Path
from typing import Any


def render_project(root_dir: str | Path, project_id: str) -> Path:
    root = Path(root_dir)
    project_dir = root / "proyectos" / project_id
    result_path = project_dir / "resultado_perdidas.json"
    if not result_path.exists():
        raise FileNotFoundError(f"No existe {result_path}")
    payload = json.loads(result_path.read_text(encoding="utf-8"))
    html = render_html(payload)
    out = project_dir / "memoria_perdidas.html"
    out.write_text(html, encoding="utf-8")
    return out


BASE_CSS = """
@page { size: letter; margin: 0.35in; }
* { box-sizing: border-box; }
body { font-family: Arial, Helvetica, sans-serif; font-size: 9.4pt; line-height: 1.3; color: #202020; background:#fff; margin:0.25in; }
.page { page-break-after: always; min-height: 10in; display:flex; flex-direction:column; padding:0.12in; }
.page:last-child { page-break-after: auto; }
h1 { font-size: 14pt; text-transform: uppercase; border-bottom: 2px solid #333; padding-bottom: 0.08in; margin:0 0 0.15in 0; }
h2 { font-size: 11pt; text-transform: uppercase; border-bottom: 1px solid #555; padding-bottom: 0.04in; margin:0.18in 0 0.10in 0; }
p { margin:0 0 0.10in 0; text-align:justify; }
table { width:100%; border-collapse: collapse; margin:0.08in 0 0.12in 0; font-size:7.5pt; line-height:1.12; }
th,td { border:1px solid #b9b9b9; padding:4px 5px; vertical-align:top; }
th { background:#eee; font-weight:700; text-transform:uppercase; font-size:7.1pt; border-bottom:2px solid #777; }
tbody tr:nth-child(even) { background:#fafafa; }
.header-mini { display:grid; grid-template-columns:1fr 1fr; gap:0.12in; border-bottom:2px solid #333; padding-bottom:0.08in; margin-bottom:0.12in; font-size:8pt; }
.header-mini-title { font-weight:700; text-transform:uppercase; font-size:10pt; }
.header-mini-meta { text-align:right; }
.footer { margin-top:auto; border-top:1px solid #ccc; padding-top:0.06in; font-size:7.5pt; text-align:center; color:#666; }
.infobox { border:1px solid #999; padding:0.1in; margin:0.12in 0; background:#fafafa; border-radius:3px; }
.infobox.result { background:#eee; border:2px solid #666; }
.infobox-title { font-weight:700; text-transform:uppercase; font-size:8.4pt; margin-bottom:0.06in; }
.formula { background:#f8f8f8; border:1px solid #ccc; border-left:4px solid #0b5cad; padding:0.1in; margin:0.12in 0; text-align:center; font-family: Georgia, serif; }
.summary-grid { display:grid; grid-template-columns: repeat(4, 1fr); gap:0.08in; margin:0.14in 0; }
.metric { border:2px solid #333; padding:0.10in; text-align:center; background:#f5f5f5; }
.metric-label { font-size:7.4pt; text-transform:uppercase; color:#555; display:block; }
.metric-value { font-size:14pt; font-weight:800; display:block; margin-top:0.04in; }
.metric-unit { font-size:8pt; color:#444; }
.portada { display:flex; flex-direction:column; align-items:center; min-height:9.2in; text-align:center; padding-top:0.35in; }
.portada-logos { display:flex; justify-content:center; align-items:center; gap:1in; margin-bottom:0.55in; }
.portada-logo-slot { width:2.5in; height:1.5in; display:flex; align-items:center; justify-content:center; }
.portada-logo { max-width:2.5in; max-height:1.5in; object-fit:contain; }
.portada-titulo { font-size:20pt; font-weight:700; text-transform:uppercase; letter-spacing:1px; margin-bottom:0.32in; border-top:2px solid #333; border-bottom:2px solid #333; padding:0.22in 0.5in; color:#1a1a1a; }
.portada-proyecto { font-size:16pt; font-weight:600; margin-bottom:0.22in; color:#333; }
.portada-info { font-size:11pt; line-height:1.35; margin-bottom:0.42in; }
.portada-firma { margin-top:0.25in; font-size:10pt; color:#555; }
.portada-firma-line { border-top:1px solid #333; width:3in; margin-left:auto; margin-right:auto; padding-top:0.1in; }
.small { font-size:7.2pt; }
@media print { body { margin:0; } .page { margin:0; } }
"""


def render_html(payload: dict[str, Any]) -> str:
    project = payload["project"]
    resumen = payload["resumen"]
    route = payload["ruta_critica"]
    bomba = payload.get("bomba", {})
    tanque = payload.get("tanque_hidroneumatico", {})
    logos = project.get("logos", []) or []
    logo_html = "".join(
        f'<div class="portada-logo-slot"><img src="{h(logo.get("url", ""))}" class="portada-logo" alt="{h(logo.get("alt", "Logo"))}"></div>'
        for logo in logos[:2]
        if logo.get("url")
    )
    if not logo_html:
        logo_html = '<div class="portada-logo-slot"></div><div class="portada-logo-slot"></div>'

    node_rows = [[n["id"], n["nombre"], n["tipo"], fmt(n["elevacion_m"]), "Sí" if n["fuente"] else "", "Sí" if n["critico"] else "", fmt(n["demanda_directa_lps"], 3), fmt(n["demanda_acumulada_lps"], 3)] for n in payload["nodos"]]
    tramo_rows = [[t["id"], t["nombre"], f"{t['desde']} → {t['hasta']}", fmt(t["longitud_m"]), t["material"], fmt(t["diametro_mm"], 0), fmt(t["caudal_lps"], 3), fmt(t["velocidad_m_s"], 3), "Sí" if t["cumple_velocidad"] else "NO", fmt(t["perdida_friccion_m"], 3), fmt(t["perdida_accesorios_m"], 3), fmt(t["perdida_total_m"], 3)] for t in payload["tramos"]]
    accessory_rows = []
    for tramo in payload["tramos"]:
        for item in tramo.get("detalle_accesorios", []) or []:
            accessory_rows.append([
                tramo["id"],
                item.get("accesorio", ""),
                fmt(item.get("cantidad"), 3),
                item.get("metodo", tramo.get("metodo_accesorios", "")),
                fmt(item.get("le_d"), 3),
                fmt(item.get("longitud_equivalente_m"), 3),
                fmt(item.get("k_unitario"), 3),
                fmt(item.get("k_total"), 3),
                fmt(item.get("perdida_fija_m"), 3),
                fmt(item.get("ha_m"), 3),
            ])
    if not accessory_rows:
        accessory_rows = [["", "Sin accesorios declarados", "", "", "", "", "", "", "", ""]]

    route_rows = [[r["nodo_critico"], r["nombre"], " / ".join(r["tramos"]), fmt(r["altura_estatica_m"]), fmt(r["presion_punto_critico_mca"]), fmt(r["perdida_friccion_m"], 3), fmt(r["perdida_accesorios_m"], 3), fmt(r["margen_seguridad_mca"], 3), fmt(r["adt_mca"], 2), fmt(r["adt_psi"], 1)] for r in payload["rutas_criticas"]]
    catalog_rows = [[item.get("capacidad", f"{item.get('hp')} HP"), fmt(item.get("hp"), 2)] for item in payload.get("catalogos_usados", {}).get("catalogo_bombas", [])]
    npsh = payload.get("succion_npsh", {})
    npsh_rows = [["Evaluado", "Sí" if npsh.get("evaluado") else "No"]]
    if npsh.get("evaluado"):
        npsh_rows.extend([
            ["Nodo bomba", npsh.get("nodo_bomba")],
            ["Condición", npsh.get("condicion")],
            ["Tramos de succión", " / ".join(npsh.get("tramos_succion", []))],
            ["Nivel mínimo de agua", f"{fmt(npsh.get('nivel_minimo_agua_m'),3)} m"],
            ["Eje de bomba", f"{fmt(npsh.get('eje_bomba_m'),3)} m"],
            ["Altura estática de succión", f"{fmt(npsh.get('altura_succion_estatica_m'),3)} m"],
            ["Pérdidas de succión", f"{fmt(npsh.get('perdidas_succion_m'),3)} m"],
            ["Presión atmosférica", f"{fmt(npsh.get('presion_atmosferica_mca'),3)} mca"],
            ["Presión de vapor", f"{fmt(npsh.get('presion_vapor_mca'),3)} mca"],
            ["NPSH disponible", f"{fmt(npsh.get('npsh_disponible_m'),2)} m"],
            ["NPSH requerido", "No declarado" if npsh.get("npsh_requerido_m") is None else f"{fmt(npsh.get('npsh_requerido_m'),2)} m"],
            ["Cumplimiento", npsh.get("estado") or ("No evaluable" if npsh.get("cumple") is None else ("Cumple" if npsh.get("cumple") else "No cumple"))],
            ["Nota", npsh.get("nota", "Confirmar NPSHr con curva del fabricante antes de comprar la bomba.")],
        ])

    pmax = payload.get("presion_maxima", {})
    pmax_rows = []
    if pmax.get("evaluado"):
        for row in pmax.get("nodos", []):
            pmax_rows.append([row.get("id"), row.get("nombre"), fmt(row.get("presion_estimada_mca"), 2), fmt(row.get("presion_estimada_psi"), 1), "NO" if row.get("excede") else "Sí"])
    else:
        pmax_rows = [["", "No evaluado", "", "", ""]]
    warnings = payload.get("advertencias") or []
    tanque_html = ""
    if tanque.get("calculado"):
        tanque_html = f"""
<h2>5.2 Tanque hidroneumático</h2>
<div class="formula">{h(tanque.get('formula', 'Litros necesarios = (180 × (Q_lps × 100) / 20) × 0.264'))}</div>
{table(['Concepto','Valor'], [
    ['Caudal base', f"{fmt(tanque.get('caudal_base_lps'),2)} L/s / {fmt(tanque.get('caudal_base_gpm'),1)} GPM"],
    ['Factor de extracción', f"{fmt((tanque.get('factor_extraccion') or 0) * 100,1)}%"],
    ['Volumen necesario', f"{fmt(tanque.get('volumen_necesario_l'),2)} L / {fmt(tanque.get('volumen_necesario_gal'),1)} gal"],
    ['Volumen adoptado', f"{fmt(tanque.get('volumen_adoptado_l'),2)} L / {fmt(tanque.get('volumen_adoptado_gal'),1)} gal"],
    ['Cantidad', f"{h(tanque.get('cantidad'))} tanque(s)"],
    ['Modelo', tanque.get('modelo')],
])}
<div class="infobox"><div class="infobox-title">Observación</div>{h(tanque.get('observacion', 'Verificar presión de trabajo con fabricante.'))}</div>
"""
    warnings_html = "" if not warnings else "<div class='infobox'><div class='infobox-title'>Advertencias</div><ul>" + "".join(f"<li>{h(w)}</li>" for w in warnings) + "</ul></div>"
    engineer = project.get("ingeniero", {}) if isinstance(project.get("ingeniero", {}), dict) else {}

    return f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{h(project['titulo_memoria'])} - {h(project['nombre'])}</title>
<style>{BASE_CSS}</style>
</head>
<body>
<section class="page">
  <div class="portada">
    <div class="portada-logos">{logo_html}</div>
    <div class="portada-titulo">Memoria de Cálculo - Sistema Hidráulico y Pérdidas</div>
    <div class="portada-proyecto">{h(project['nombre'])}</div>
    <div class="portada-info">
      <div><strong>ID:</strong> {h(project['id'])}</div>
      <div><strong>CLIENTE:</strong> {h(project.get('cliente', ''))}</div>
      <div><strong>EMPRESA:</strong> {h(project.get('empresa', ''))}</div>
      <div><strong>INGENIERO:</strong> {h(engineer.get('nombre', ''))}</div>
      <div><strong>CODIA:</strong> {h(project.get('codia', engineer.get('codia', '')))}</div>
      <div><strong>UBICACIÓN:</strong> {h(project.get('ubicacion', ''))}</div>
      <div><strong>FECHA:</strong> {h(project.get('fecha', ''))}</div>
    </div>
    <div class="infobox result" style="width:6.2in;text-align:left;">
      <div class="infobox-title">Resultado general</div>
      <strong>Caudal del sistema:</strong> {fmt(resumen['caudal_total_lps'], 2)} L/s ({fmt(resumen['caudal_total_gpm'], 1)} GPM)<br>
      <strong>Altura Dinámica Total:</strong> {fmt(resumen['adt_critica_mca'], 2)} mca ({fmt(resumen['adt_critica_psi'], 1)} psi)<br>
      <strong>Pérdidas ruta crítica:</strong> {fmt(resumen['perdidas_totales_m'], 2)} m<br>
      <strong>Bomba seleccionada:</strong> {h(resumen['bomba_seleccionada_capacidad'])}
    </div>
    <div class="portada-firma"><div class="portada-firma-line"></div>{h(engineer.get('nombre', ''))}<br>{h(project.get('empresa', ''))}</div>
  </div>
</section>

<section class="page">
{header(project, 'Resumen')}
<h1>1. Resumen del sistema</h1>
<div class="summary-grid">
  <div class="metric"><span class="metric-label">Caudal</span><span class="metric-value">{fmt(resumen['caudal_total_lps'],2)}</span><span class="metric-unit">L/s</span></div>
  <div class="metric"><span class="metric-label">ADT</span><span class="metric-value">{fmt(resumen['adt_critica_mca'],2)}</span><span class="metric-unit">mca / {fmt(resumen['adt_critica_psi'],1)} psi</span></div>
  <div class="metric"><span class="metric-label">Pérdidas</span><span class="metric-value">{fmt(resumen['perdidas_totales_m'],2)}</span><span class="metric-unit">m</span></div>
  <div class="metric"><span class="metric-label">Bomba</span><span class="metric-value">{h(resumen['bomba_seleccionada_capacidad'])}</span><span class="metric-unit">capacidad</span></div>
</div>
{warnings_html}
<h2>1.1 Datos generales</h2>
{table(['Concepto','Valor'], [
    ['Cantidad de nodos', len(payload.get('nodos', []))],
    ['Cantidad de tramos', resumen.get('cantidad_tramos')],
    ['Nodo crítico de control', resumen.get('ruta_critica')],
    ['ADT de control', f"{fmt(resumen.get('adt_critica_mca'),2)} mca / {fmt(resumen.get('adt_critica_psi'),1)} psi"],
    ['Potencia requerida', f"{fmt(resumen.get('hp_requerido'),3)} HP / {fmt(resumen.get('potencia_hidraulica_w'),1)} W"],
    ['Capacidad seleccionada', resumen.get('bomba_seleccionada_capacidad')],
])}
<div class="footer">Memoria de Cálculo Hidráulico y Pérdidas</div>
</section>

<section class="page">
{header(project, 'Teoría de cálculo')}
<h1>2. Teoría de cálculo</h1>
<p>La memoria calcula pérdidas desde la cisterna hasta los puntos críticos. Para cada ruta se suma altura estática, presión mínima, pérdidas por fricción, pérdidas por accesorios y margen de seguridad.</p>
<h2>2.1 Pérdida por fricción</h2>
<div class="formula">hf = 10.674 × L × Q^1.852 / (C^1.852 × D^4.871)</div>
<p><strong>Unidades Hazen-Williams:</strong> Q en m³/s, D en m, L en m, hf en m. La tabla de resultados muestra Q en L/s y D en mm; el motor convierte internamente a unidades SI. Para tubería PPR nueva se adopta C = {fmt(payload['criterios'].get('coeficiente_hazen_default', 150),0)} salvo que el material declare otro coeficiente.</p>
<h2>2.2 Criterio de presión mínima</h2>
<p><strong>Criterio de presión mínima:</strong> {h(payload['criterios'].get('criterio_presion_minima','tabla_4'))}. Para puntos estándar se usa Hpc = {fmt(payload['criterios'].get('presion_critica_default_mca'),2)} mca cuando aplica Tabla 4; para Art. 32 se usa {fmt(payload['criterios'].get('presion_aparato_tanque_mca'),2)} mca en aparatos con tanque y {fmt(payload['criterios'].get('presion_punto_critico_fluxometro_mca'),2)} mca en fluxómetros.</p>
<h2>2.3 Pérdida por accesorios</h2>
<div class="formula">ha = ΣK × V²/(2g) &nbsp; o &nbsp; Le = (Le/D) × D</div>
<p>Los accesorios pueden calcularse por longitud equivalente, por coeficiente K o mediante pérdida fija declarada en metros para equipos especiales.</p>
<h2>2.4 Altura dinámica total</h2>
<div class="formula">ADT = He + Hpc + Hf + Ha + Hs</div>
<p>La bomba se selecciona por capacidad en HP únicamente. Para compra debe verificarse la curva del fabricante para el caudal y ADT calculados.</p>
<div class="footer">Memoria de Cálculo Hidráulico y Pérdidas</div>
</section>

<section class="page">
{header(project, 'Datos de entrada')}
<h1>3. Datos de entrada del sistema</h1>
<h2>3.1 Nodos</h2>
{table(['ID','Nombre','Tipo','Elev. (m)','Fuente','Crítico','Demanda (L/s)','Demanda acum. (L/s)'], node_rows)}
<h2>3.2 Catálogo de bomba</h2>
{table(['Capacidad','HP'], catalog_rows, 'small')}
<div class="footer">Memoria de Cálculo Hidráulico y Pérdidas</div>
</section>

<section class="page">
{header(project, 'Pérdidas por tramos')}
<h1>4. Cálculo de pérdidas por tramos</h1>
{table(['Tramo','Descripción','Ruta','Long. (m)','Material','D (mm)','Q (L/s)','V (m/s)','Cumple V','Hf (m)','Ha (m)','Total (m)'], tramo_rows, 'small')}
<h2>4.1 Detalle de accesorios</h2>
{table(['Tramo','Accesorio','Cant.','Método','Le/D','Le (m)','K unit.','K total','Pérdida fija (m)','Ha (m)'], accessory_rows, 'small')}
<div class="footer">Memoria de Cálculo Hidráulico y Pérdidas</div>
</section>

<section class="page">
{header(project, 'Ruta crítica y bomba')}
<h1>5. Ruta crítica y selección de bomba</h1>
{table(['Nodo crítico','Nombre','Tramos','He (m)','Hpc (mca)','Hf (m)','Ha (m)','Hs (m)','ADT (mca)','ADT (psi)'], route_rows, 'small')}
<h2>5.1 Bomba seleccionada</h2>
{table(['Concepto','Valor'], [
    ['Caudal de selección', f"{fmt(bomba.get('caudal_lps'),2)} L/s / {fmt(bomba.get('caudal_gpm'),1)} GPM"],
    ['Altura dinámica total', f"{fmt(bomba.get('adt_mca'),2)} mca / {fmt(bomba.get('adt_ft'),1)} pies / {fmt(bomba.get('adt_psi'),1)} psi"],
    ['Eficiencia asumida', fmt(bomba.get('eficiencia'),2)],
    ['Potencia requerida', f"{fmt(bomba.get('potencia_requerida_hp'),3)} HP / {fmt(bomba.get('potencia_requerida_w'),1)} W"],
    ['Margen de selección de bomba', f"{fmt((bomba.get('margen_seleccion_porcentaje') or 0) * 100,1)}%"],
    ['Potencia mínima con margen', f"{fmt(bomba.get('potencia_seleccion_minima_hp'),3)} HP"],
    ['Punto de operación', f"{fmt(bomba.get('caudal_gpm'),1)} GPM @ {fmt(bomba.get('adt_ft'),1)} pies ({fmt(bomba.get('adt_mca'),2)} mca)"],
    ['Bomba seleccionada', bomba.get('capacidad_seleccionada',{}).get('capacidad')],
])}
<div class="infobox"><div class="infobox-title">Nota de especificación</div>Bomba seleccionada solo por capacidad HP. Curva, tensión, fase, succión y descarga deben verificarse con fabricante.</div>
{tanque_html}
<h2>5.3 Succión y NPSH</h2>
{table(['Concepto','Valor'], npsh_rows)}
<h2>5.4 Presión máxima</h2>
<p>Límite de referencia: {fmt(pmax.get('limite_mca'),2)} mca / {fmt(pmax.get('limite_psi'),1)} psi. Esta verificación es preliminar porque no sustituye curva certificada de bomba.</p>
{table(['Nodo','Nombre','Presión estimada (mca)','Presión estimada (psi)','Cumple'], pmax_rows, 'small')}
<div class="footer">Memoria de Cálculo Hidráulico y Pérdidas</div>
</section>
</body>
</html>
"""


def header(project: dict[str, Any], right: str) -> str:
    return f"""
    <div class="header-mini">
        <div>
            <div class="header-mini-title">Memoria de Cálculo Hidráulico y Pérdidas</div>
            <div>{h(project.get('nombre','PROYECTO'))} | {h(project.get('cliente',''))}</div>
        </div>
        <div class="header-mini-meta">{h(right)}<br>Código: {h(project.get('codigo',''))}</div>
    </div>"""


def table(headers: list[str], rows: list[list[Any]], klass: str = "") -> str:
    head = "".join(f"<th>{h(item)}</th>" for item in headers)
    body = "".join("<tr>" + "".join(f"<td>{h(cell)}</td>" for cell in row) + "</tr>" for row in rows)
    return f'<table class="{h(klass)}"><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>'


def h(value: Any) -> str:
    return escape(str(value if value is not None else ""))


def fmt(value: Any, nd: int = 2) -> str:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return h(value)
    if abs(number - round(number)) < 10 ** (-(nd + 1)):
        return f"{number:,.0f}"
    return f"{number:,.{nd}f}".rstrip("0").rstrip(".")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Renderiza memoria HTML de san-perdidas.")
    parser.add_argument("--project-id", required=True, help="ID del proyecto")
    parser.add_argument("--root", default=".", help="Directorio base con proyectos/")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    out = render_project(args.root, args.project_id)
    print(f"OK HTML: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

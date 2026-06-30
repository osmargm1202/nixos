from __future__ import annotations

import argparse
import json
import math
import shutil
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from typing import Any

M3S_TO_LPS = 1000.0
LPS_TO_GPM = 15.850323141489
M_TO_FT = 3.280839895
MCA_TO_PSI = 1.421970206
G = 9.80665
HP_WATT = 745.699872

DEFAULT_MATERIAL_C = {
    "ppr": 150,
    "pvc": 150,
    "cpvc": 150,
    "hdpe": 150,
    "cobre": 140,
    "acero": 120,
    "acero_galv": 120,
    "hierro": 110,
    "hierro_fundido": 100,
}
DEFAULT_DIAMETERS = [13, 19, 20, 25, 32, 40, 50, 63, 75, 90, 110, 125, 150]
DEFAULT_ACCESSORY_LE_D = {
    "codo_45": 16,
    "codo_90": 30,
    "tee_paso": 20,
    "tee_derivacion": 60,
    "valvula_compuerta": 8,
    "valvula_compuerta_abierta": 8,
    "valvula_check": 100,
    "valvula_bola": 3,
    "valvula_bola_abierta": 3,
    "valvula_globo_abierta": 340,
    "reduccion": 15,
    "reduccion_gradual": 15,
    "entrada_tanque": 25,
    "salida_tanque": 20,
    "medidor": 250,
    "filtro_y": 100,
    "union_universal": 3,
    "filtro_succion": 100,
    "colador": 75,
    "valvula_pie": 150,
    "check_succion": 100,
}
DEFAULT_ACCESSORY_K = {
    "codo_90": {"k": 0.90, "descripcion": "Codo 90° estándar"},
    "codo_45": {"k": 0.40, "descripcion": "Codo 45° estándar"},
    "tee_paso": {"k": 0.60, "descripcion": "Tee en paso"},
    "tee_derivacion": {"k": 1.80, "descripcion": "Tee en derivación"},
    "valvula_compuerta": {"k": 0.20, "descripcion": "Válvula de compuerta abierta"},
    "valvula_compuerta_abierta": {"k": 0.20, "descripcion": "Válvula de compuerta abierta"},
    "valvula_bola": {"k": 0.05, "descripcion": "Válvula de bola abierta"},
    "valvula_bola_abierta": {"k": 0.05, "descripcion": "Válvula de bola abierta"},
    "valvula_check": {"k": 2.00, "descripcion": "Válvula check genérica"},
    "valvula_globo_abierta": {"k": 10.00, "descripcion": "Válvula globo abierta"},
    "reduccion": {"k": 0.20, "descripcion": "Reducción gradual"},
    "reduccion_gradual": {"k": 0.20, "descripcion": "Reducción gradual"},
    "entrada_tanque": {"k": 0.50, "descripcion": "Entrada desde tanque/cisterna"},
    "salida_tanque": {"k": 1.00, "descripcion": "Salida hacia tanque/descarga"},
    "medidor": {"k": 7.00, "descripcion": "Medidor de agua genérico"},
    "filtro_y": {"k": 2.00, "descripcion": "Filtro tipo Y limpio"},
    "union_universal": {"k": 0.08, "descripcion": "Unión universal"},
    "filtro_succion": {"k": 2.0, "descripcion": "Filtro de succión limpio"},
    "colador": {"k": 1.5, "descripcion": "Colador de succión limpio"},
    "valvula_pie": {"k": 2.5, "descripcion": "Válvula de pie con colador"},
    "check_succion": {"k": 2.0, "descripcion": "Check en succión"},
}
DEFAULT_APPLIANCE_LPS = {
    "lps_010": 0.10,
    "lps_015": 0.15,
    "lps_020": 0.20,
    "lps_025": 0.25,
    "lps_030": 0.30,
    "g_010": 0.10,
    "g_015": 0.15,
    "g_020": 0.20,
    "especial": 1.00,
    "especiales": 1.00,
}
DEFAULT_PUMPS_HP = [0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 7.5, 10, 15, 20, 25, 30, 40, 50]

DEFAULT_CRITERIA = {
    "metodo_perdidas": "hazen_williams_le",
    "metodo_accesorios": "longitud_equivalente",
    "material_default": "ppr",
    "coeficiente_hazen_default": 150,
    "velocidad_min_m_s": 0.6,
    "velocidad_max_m_s": 2.5,
    "presion_critica_default_mca": 5.7,
    "presion_punto_critico_fluxometro_mca": 10.55,
    "usar_presion_fluxometro": False,
    "factor_simultaneidad_global": 1.0,
    "mostrar_simultaneidad": True,
    "margen_seleccion_bomba_porcentaje": 0.20,
    "criterio_presion_minima": "tabla_4",
    "presion_aparato_tanque_mca": 7.03,
    "presion_maxima_red_mca": 42.2,
    "verificar_presion_maxima": True,
    "diametro_modo": "hidraulico",
    "ppr_serie_default": "SDR11",
    "ppr_sdr": {
        "SDR11": {"20": 16.36, "25": 20.45, "32": 26.18, "40": 32.72, "50": 40.90, "63": 51.54, "75": 61.36, "90": 73.64, "110": 90.00},
    },
    "evaluar_npsh": False,
    "nodo_bomba": None,
    "presion_atmosferica_mca": 10.33,
    "presion_vapor_mca": 0.32,
    "npsh_requerido_m": None,
    "margen_npsh_m": 1.0,
    "margen_seguridad_tipo": "porcentaje_sobre_adt_sin_margen",
    "margen_seguridad_porcentaje": 0.15,
    "margen_seguridad_mca": None,
    "eficiencia_bomba": 0.65,
    "peso_especifico_agua_n_m3": 9800.0,
    "diametros_mm": DEFAULT_DIAMETERS,
    "bombas_hp": DEFAULT_PUMPS_HP,
    "catalogo_bombas": [{"capacidad": f"{hp:g} HP", "hp": hp} for hp in DEFAULT_PUMPS_HP],
    "materiales_hazen": DEFAULT_MATERIAL_C,
    "accesorios_le_d": DEFAULT_ACCESSORY_LE_D,
    "accesorios_k": DEFAULT_ACCESSORY_K,
    "aparatos_lps": DEFAULT_APPLIANCE_LPS,
    "nodo_cisterna": None,
    "nodos_criticos": [],
}


def run_calculation(input_path: str | Path, root_dir: str | Path | None = None, *, force: bool = False) -> dict[str, Any]:
    input_path = Path(input_path)
    root = Path(root_dir) if root_dir is not None else Path.cwd()
    payload = json.loads(input_path.read_text(encoding="utf-8"))

    criteria = merge_criteria(payload.get("criterios") or {}, payload)
    project = normalize_project(payload.get("project") or payload.get("proyecto") or {}, payload.get("workspace") or {})
    nodes = normalize_nodes(payload.get("nodos") or [])
    tramos = normalize_tramos(payload.get("tramos") or [], criteria)

    validate_network(nodes, tramos, criteria)
    source = find_source(nodes, criteria)
    children, incoming, tramo_by_id = build_graph(tramos)
    order = topological_order(source["id"], children, nodes)
    criticals = find_criticals(nodes, source["id"], order, criteria)

    node_totals_lps, tramo_flows_lps = accumulate_flows(nodes, tramos, order, incoming, criteria)
    warnings: list[str] = []
    calculated_tramos = calculate_tramos(tramos, tramo_flows_lps, criteria, warnings)
    calculated_by_id = {tramo["id"]: tramo for tramo in calculated_tramos}
    routes = calculate_routes(
        source,
        criticals,
        incoming,
        calculated_by_id,
        criteria,
        node_totals_lps.get(source["id"], 0.0),
        warnings,
    )
    critical_route = max(routes, key=lambda route: route["adt_mca"])
    suction_npsh = build_suction_npsh(source, nodes, calculated_tramos, incoming, criteria, warnings)
    max_pressure = build_max_pressure_check(source, nodes, critical_route, calculated_by_id, incoming, criteria, warnings)

    result = {
        "schema": "san-perdidas.resultado.v1",
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "project": project,
        "criterios": criteria,
        "resumen": build_summary(node_totals_lps.get(source["id"], 0.0), critical_route, calculated_tramos),
        "nodos": build_node_results(nodes, node_totals_lps, criticals, source, criteria),
        "tramos": calculated_tramos,
        "rutas_criticas": routes,
        "ruta_critica": critical_route,
        "bomba": build_pump_result(critical_route, criteria),
        "tanque_hidroneumatico": build_hydropneumatic_tank_result(payload.get("tanque_hidroneumatico") or {}, critical_route, criteria, warnings),
        "succion_npsh": suction_npsh,
        "presion_maxima": max_pressure,
        "catalogos_usados": {
            "materiales_hazen": criteria["materiales_hazen"],
            "diametros_mm": criteria["diametros_mm"],
            "accesorios_le_d": criteria["accesorios_le_d"],
            "accesorios_k": criteria["accesorios_k"],
            "bombas_hp": criteria["bombas_hp"],
            "catalogo_bombas": criteria["catalogo_bombas"],
        },
        "advertencias": warnings,
        "metodologia": {
            "caudales": "Demanda terminal por nodos; acumulación aguas arriba por grafo dirigido desde cisterna.",
            "velocidad": "V = Q/A con Q en m³/s y diámetro interno declarado o seleccionado.",
            "friccion": "Hazen-Williams: hf = 10.674 × L × Q^1.852 / (C^1.852 × D^4.871).",
            "accesorios": "Longitud equivalente Le/D o coeficiente K; también admite pérdida fija por equipo.",
            "adt": "ADT = He + Hpc + Hf + Ha + Hs para cada ruta cisterna-punto crítico.",
            "bomba": "HP = Q × ADT × 9800 / (eficiencia × 745.7); selección por siguiente HP comercial.",
            "tanque_hidroneumatico": "Referencia MDC: Litros necesarios = (180 × (Q_lps × 100) / 20) × 0.264; selección por catálogo o múltiplos del mayor tanque.",
        },
    }

    project_dir = prepare_project_dir(root, project, force)
    (project_dir / "input_perdidas.json").write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    (project_dir / "resultado_perdidas.json").write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return result


def normalize_project(project: dict[str, Any], workspace: dict[str, Any] | None = None) -> dict[str, Any]:
    workspace = workspace or {}
    project_id = str(project.get("id") or workspace.get("project_id") or project.get("project_id") or "san-perdidas-demo").strip()
    if not project_id:
        raise ValueError("project.id es requerido")
    date = project.get("fecha", "auto")
    if date in (None, "", "auto"):
        date = datetime.now().strftime("%d/%m/%Y")
    raw_mode = project.get("mode", project.get("modo", workspace.get("modo", "nuevo")))
    mode_map = {"new": "nuevo", "modify": "modificar", "nuevo": "nuevo", "modificar": "modificar"}
    logos = project.get("logos") or []
    if not logos:
        if project.get("logo_cliente_url"):
            logos.append({"url": project.get("logo_cliente_url"), "alt": project.get("cliente", "Cliente")})
        if project.get("logo_empresa_url"):
            logos.append({"url": project.get("logo_empresa_url"), "alt": project.get("empresa", "Empresa")})
    engineer = project.get("ingeniero", {})
    if isinstance(engineer, str):
        engineer = {"nombre": engineer, "codia": project.get("codia", project.get("codigo", ""))}
    return {
        "id": project_id,
        "mode": mode_map.get(str(raw_mode).lower(), str(raw_mode)),
        "titulo_memoria": project.get("titulo_memoria", "Memoria de Cálculo - Sistema Hidráulico y Pérdidas"),
        "nombre": project.get("nombre", project.get("name", project_id)),
        "cliente": project.get("cliente", ""),
        "empresa": project.get("empresa", ""),
        "ubicacion": project.get("ubicacion", "República Dominicana"),
        "fecha": date,
        "tipo_proyecto": project.get("tipo_proyecto", "Sistema de distribución hidráulica"),
        "normativa": project.get("normativa", "MOPC / R-008 - República Dominicana"),
        "ingeniero": engineer,
        "codia": project.get("codia", engineer.get("codia", "") if isinstance(engineer, dict) else ""),
        "codigo": project.get("codigo", ""),
        "logos": logos,
    }


def number_or_default(value: Any, default: float) -> Any:
    if value is None or value == "":
        return default
    return value


def merge_criteria(overrides: dict[str, Any], payload: dict[str, Any] | None = None) -> dict[str, Any]:
    payload = payload or {}
    criteria = deepcopy(DEFAULT_CRITERIA)
    aliases = {
        "c_hazen_default": "coeficiente_hazen_default",
        "diametros_comerciales_mm": "diametros_mm",
        "presion_punto_critico_mca": "presion_critica_default_mca",
        "catalogo_accesorios": "accesorios_k",
    }
    for key, value in overrides.items():
        key = aliases.get(key, key)
        if key == "catalogos" and isinstance(value, dict):
            merge_catalogs(criteria, value)
            continue
        if key == "accesorios_k" and isinstance(value, dict):
            criteria["accesorios_k"].update(normalize_accessory_k_catalog(value))
            continue
        criteria[key] = value

    if payload.get("catalogo_bombas"):
        criteria["catalogo_bombas"] = normalize_pump_catalog(payload["catalogo_bombas"])
    elif overrides.get("catalogo_bombas"):
        criteria["catalogo_bombas"] = normalize_pump_catalog(overrides["catalogo_bombas"])
    elif overrides.get("bombas_hp"):
        criteria["catalogo_bombas"] = normalize_pump_catalog(overrides["bombas_hp"])

    if str(criteria.get("metodo_perdidas", "")).lower().endswith("_k") and "metodo_accesorios" not in overrides:
        criteria["metodo_accesorios"] = "k"

    criteria["diametros_mm"] = sorted(float(d) for d in criteria.get("diametros_mm", DEFAULT_DIAMETERS) if float(d) > 0)
    criteria["catalogo_bombas"] = normalize_pump_catalog(criteria.get("catalogo_bombas", []))
    criteria["bombas_hp"] = sorted(float(item["hp"]) for item in criteria["catalogo_bombas"] if float(item["hp"]) > 0)
    criteria["material_default"] = str(criteria.get("material_default") or "ppr").lower()
    criteria["eficiencia_bomba"] = float(number_or_default(criteria.get("eficiencia_bomba"), 0.65))
    criteria["peso_especifico_agua_n_m3"] = float(number_or_default(criteria.get("peso_especifico_agua_n_m3"), 9800.0))
    criteria["velocidad_min_m_s"] = float(number_or_default(criteria.get("velocidad_min_m_s"), 0.6))
    criteria["velocidad_max_m_s"] = float(number_or_default(criteria.get("velocidad_max_m_s"), 2.5))
    criteria["presion_critica_default_mca"] = float(number_or_default(criteria.get("presion_critica_default_mca"), 5.7))
    criteria["presion_punto_critico_fluxometro_mca"] = float(number_or_default(criteria.get("presion_punto_critico_fluxometro_mca"), 10.55))
    criteria["factor_simultaneidad_global"] = float(number_or_default(criteria.get("factor_simultaneidad_global"), 1.0))
    criteria["mostrar_simultaneidad"] = coerce_bool(criteria.get("mostrar_simultaneidad"), True)
    criteria["margen_seleccion_bomba_porcentaje"] = float(number_or_default(criteria.get("margen_seleccion_bomba_porcentaje"), 0.0))
    criteria["criterio_presion_minima"] = str(criteria.get("criterio_presion_minima") or "tabla_4").lower()
    criteria["presion_aparato_tanque_mca"] = float(number_or_default(criteria.get("presion_aparato_tanque_mca"), 7.03))
    criteria["presion_maxima_red_mca"] = float(number_or_default(criteria.get("presion_maxima_red_mca"), 42.2))
    criteria["verificar_presion_maxima"] = coerce_bool(criteria.get("verificar_presion_maxima"), True)
    criteria["diametro_modo"] = str(criteria.get("diametro_modo") or "hidraulico").lower()
    criteria["ppr_serie_default"] = str(criteria.get("ppr_serie_default") or "SDR11")
    criteria["evaluar_npsh"] = coerce_bool(criteria.get("evaluar_npsh"), False)
    criteria["nodo_bomba"] = criteria.get("nodo_bomba")
    criteria["presion_atmosferica_mca"] = float(number_or_default(criteria.get("presion_atmosferica_mca"), 10.33))
    criteria["presion_vapor_mca"] = float(number_or_default(criteria.get("presion_vapor_mca"), 0.32))
    criteria["margen_npsh_m"] = float(number_or_default(criteria.get("margen_npsh_m"), 0.0))
    if criteria.get("npsh_requerido_m") is not None:
        criteria["npsh_requerido_m"] = float(criteria["npsh_requerido_m"])
    if criteria.get("margen_seguridad_mca") is not None:
        criteria["margen_seguridad_mca"] = float(criteria["margen_seguridad_mca"])
    criteria["margen_seguridad_porcentaje"] = float(number_or_default(criteria.get("margen_seguridad_porcentaje"), 0))
    criteria["metodo_accesorios"] = str(criteria.get("metodo_accesorios") or "longitud_equivalente").lower()
    criteria["materiales_hazen"] = {str(k).lower(): float(v) for k, v in criteria.get("materiales_hazen", {}).items()}
    criteria["accesorios_le_d"] = {str(k): float(v) for k, v in criteria.get("accesorios_le_d", {}).items()}
    criteria["accesorios_k"] = normalize_accessory_k_catalog(criteria.get("accesorios_k", {}))
    criteria["aparatos_lps"] = {str(k): float(v) for k, v in criteria.get("aparatos_lps", {}).items()}
    criteria["ppr_sdr"] = {
        str(serie): {str(k): float(v) for k, v in diameters.items()}
        for serie, diameters in criteria.get("ppr_sdr", {}).items()
        if isinstance(diameters, dict)
    }
    return criteria


def merge_catalogs(criteria: dict[str, Any], catalogos: dict[str, Any]) -> None:
    if isinstance(catalogos.get("materiales_hazen"), dict):
        criteria["materiales_hazen"].update({str(k).lower(): float(v) for k, v in catalogos["materiales_hazen"].items()})
    if isinstance(catalogos.get("accesorios_le_d"), dict):
        criteria["accesorios_le_d"].update({str(k): float(v) for k, v in catalogos["accesorios_le_d"].items()})
    if isinstance(catalogos.get("accesorios_k"), dict):
        criteria["accesorios_k"].update(normalize_accessory_k_catalog(catalogos["accesorios_k"]))
    if isinstance(catalogos.get("aparatos_lps"), dict):
        criteria["aparatos_lps"].update({str(k): float(v) for k, v in catalogos["aparatos_lps"].items()})
    if isinstance(catalogos.get("ppr_sdr"), dict):
        criteria.setdefault("ppr_sdr", {})
        for serie, diameters in catalogos["ppr_sdr"].items():
            if isinstance(diameters, dict):
                criteria["ppr_sdr"][str(serie)] = {str(k): float(v) for k, v in diameters.items()}


def normalize_accessory_k_catalog(value: dict[str, Any]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for key, item in value.items():
        if isinstance(item, dict):
            out[str(key)] = {"k": float(item.get("k", 0) or 0), "descripcion": str(item.get("descripcion", ""))}
        else:
            out[str(key)] = {"k": float(item or 0), "descripcion": ""}
    return out


def normalize_pump_catalog(value: Any) -> list[dict[str, Any]]:
    if not value:
        return [{"capacidad": f"{hp:g} HP", "hp": float(hp)} for hp in DEFAULT_PUMPS_HP]
    out: list[dict[str, Any]] = []
    for item in value:
        if isinstance(item, dict):
            hp = float(item.get("hp", 0) or 0)
            capacity = str(item.get("capacidad") or f"{hp:g} HP")
        else:
            hp = float(item or 0)
            capacity = f"{hp:g} HP"
        if hp > 0:
            out.append({"capacidad": capacity, "hp": hp})
    return sorted(out, key=lambda item: item["hp"])


def normalize_nodes(raw_nodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if not raw_nodes:
        raise ValueError("Debe declarar nodos")
    nodes: list[dict[str, Any]] = []
    for raw in raw_nodes:
        node_id = str(raw.get("id") or raw.get("id_nodo") or "").strip()
        if not node_id:
            raise ValueError("Nodo sin id")
        tipo = str(raw.get("tipo") or "generico").strip().lower()
        nodes.append({
            "id": node_id,
            "nombre": raw.get("nombre", raw.get("descripcion", node_id)),
            "tipo": tipo,
            "elevacion_m": require_number(raw.get("elevacion_m", raw.get("altura_m")), f"nodo {node_id}.elevacion_m"),
            "critico": bool(raw.get("critico", False)) or tipo in {"critico", "punto_critico"},
            "presion_min_mca": optional_number(raw.get("presion_min_mca", raw.get("presion_mca", raw.get("presion_requerida_mca")))),
            "equipo_presion_mca": optional_number(raw.get("equipo_presion_mca", raw.get("presion_equipo_mca"))),
            "tipo_equipo": str(raw.get("tipo_equipo", raw.get("equipo", ""))).lower(),
            "usa_fluxometro": bool(raw.get("usa_fluxometro", raw.get("fluxometro", False))),
            "demanda_lps": optional_number(raw.get("demanda_lps", raw.get("caudal_lps"))) or 0.0,
            "factor_simultaneidad": optional_number(raw.get("factor_simultaneidad")),
            "aparatos": normalize_mapping(raw.get("aparatos", {}), f"nodo {node_id}.aparatos"),
            "grupos_aparatos": normalize_group_appliances(raw.get("grupos_aparatos", []), node_id),
            "raw": raw,
        })
    return nodes


def normalize_tramos(raw_tramos: list[dict[str, Any]], criteria: dict[str, Any]) -> list[dict[str, Any]]:
    if not raw_tramos:
        raise ValueError("Debe declarar tramos")
    tramos: list[dict[str, Any]] = []
    for raw in raw_tramos:
        tramo_id = str(raw.get("id") or raw.get("id_tramo") or "").strip()
        if not tramo_id:
            raise ValueError("Tramo sin id")
        length = require_number(raw.get("longitud_m"), f"tramo {tramo_id}.longitud_m")
        if length <= 0:
            raise ValueError(f"tramo {tramo_id}.longitud_m debe ser mayor que 0")
        tramos.append({
            "id": tramo_id,
            "nombre": raw.get("nombre", raw.get("descripcion", tramo_id)),
            "desde": str(raw.get("desde") or raw.get("nodo_inicio") or "").strip(),
            "hasta": str(raw.get("hasta") or raw.get("nodo_fin") or "").strip(),
            "longitud_m": float(length),
            "material": str(raw.get("material") or criteria["material_default"]).lower(),
            "diametro_mm": optional_number(raw.get("diametro_mm", raw.get("diametro_interno_mm"))),
            "tipo_tramo": str(raw.get("tipo_tramo") or raw.get("tipo") or "").lower(),
            "ppr_serie": str(raw.get("ppr_serie") or raw.get("serie") or criteria.get("ppr_serie_default", "SDR11")),
            "accesorios": normalize_accessories(raw.get("accesorios", {})),
            "raw": raw,
        })
    return tramos


def validate_network(nodes: list[dict[str, Any]], tramos: list[dict[str, Any]], criteria: dict[str, Any]) -> None:
    node_ids: set[str] = set()
    for node in nodes:
        if node["id"] in node_ids:
            raise ValueError(f"Nodo repetido: {node['id']}")
        node_ids.add(node["id"])

    tramo_ids: set[str] = set()
    parent_count = {node["id"]: 0 for node in nodes}
    for tramo in tramos:
        if tramo["id"] in tramo_ids:
            raise ValueError(f"Tramo repetido: {tramo['id']}")
        tramo_ids.add(tramo["id"])
        if tramo["desde"] not in node_ids:
            raise ValueError(f"Nodo '{tramo['desde']}' no existe para tramo '{tramo['id']}'")
        if tramo["hasta"] not in node_ids:
            raise ValueError(f"Nodo '{tramo['hasta']}' no existe para tramo '{tramo['id']}'")
        parent_count[tramo["hasta"]] += 1

    source_id = criteria.get("nodo_cisterna")
    sources = [node for node in nodes if is_source(node, criteria)]
    if source_id:
        sources = [node for node in nodes if node["id"] == source_id]
    if len(sources) != 1:
        raise ValueError("Debe existir exactamente un nodo fuente/cisterna")
    configured_criticals = set(str(x) for x in criteria.get("nodos_criticos", []) or [])
    if not configured_criticals and not any(node["critico"] for node in nodes if node["id"] != sources[0]["id"]):
        raise ValueError("Debe existir al menos un nodo crítico")
    for node in nodes:
        if node["id"] != sources[0]["id"] and parent_count[node["id"]] > 1:
            raise ValueError(f"Nodo '{node['id']}' tiene más de un padre; mallas cerradas no soportadas")


def find_source(nodes: list[dict[str, Any]], criteria: dict[str, Any]) -> dict[str, Any]:
    source_id = criteria.get("nodo_cisterna")
    if source_id:
        return next(node for node in nodes if node["id"] == source_id)
    return next(node for node in nodes if is_source(node, criteria))


def is_source(node: dict[str, Any], criteria: dict[str, Any] | None = None) -> bool:
    return bool(node["raw"].get("fuente", False)) or node["tipo"] in {"cisterna", "fuente", "entrada"}


def find_criticals(nodes: list[dict[str, Any]], source_id: str, reachable_order: list[str], criteria: dict[str, Any]) -> list[dict[str, Any]]:
    reachable = set(reachable_order)
    configured = [str(x) for x in criteria.get("nodos_criticos", []) or []]
    if configured:
        by_id = {node["id"]: node for node in nodes}
        criticals = [by_id[node_id] for node_id in configured if node_id in by_id and node_id != source_id]
    else:
        criticals = [node for node in nodes if node["id"] != source_id and node["critico"]]
    missing = [node["id"] for node in criticals if node["id"] not in reachable]
    if missing:
        raise ValueError(f"Nodo crítico no alcanzable desde cisterna: {', '.join(missing)}")
    return criticals


def build_graph(tramos: list[dict[str, Any]]) -> tuple[dict[str, list[dict[str, Any]]], dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    children: dict[str, list[dict[str, Any]]] = {}
    incoming: dict[str, dict[str, Any]] = {}
    by_id: dict[str, dict[str, Any]] = {}
    for tramo in tramos:
        children.setdefault(tramo["desde"], []).append(tramo)
        incoming[tramo["hasta"]] = tramo
        by_id[tramo["id"]] = tramo
    return children, incoming, by_id


def topological_order(source_id: str, children: dict[str, list[dict[str, Any]]], nodes: list[dict[str, Any]]) -> list[str]:
    state: dict[str, str] = {}
    order: list[str] = []

    def visit(node_id: str) -> None:
        if state.get(node_id) == "visiting":
            raise ValueError("La red contiene un ciclo")
        if state.get(node_id) == "done":
            return
        state[node_id] = "visiting"
        order.append(node_id)
        for tramo in children.get(node_id, []):
            visit(tramo["hasta"])
        state[node_id] = "done"

    visit(source_id)
    critical_ids = {node["id"] for node in nodes if node["critico"]}
    unreachable_criticals = critical_ids - set(order)
    if unreachable_criticals:
        raise ValueError(f"Nodo crítico no alcanzable desde cisterna: {', '.join(sorted(unreachable_criticals))}")
    return order


def accumulate_flows(
    nodes: list[dict[str, Any]],
    tramos: list[dict[str, Any]],
    order: list[str],
    incoming: dict[str, dict[str, Any]],
    criteria: dict[str, Any],
) -> tuple[dict[str, float], dict[str, float]]:
    by_id = {node["id"]: node for node in nodes}
    totals = {node_id: node_demand_lps(by_id[node_id], criteria) for node_id in order}
    tramo_flows = {tramo["id"]: 0.0 for tramo in tramos}
    for node_id in reversed(order):
        tramo = incoming.get(node_id)
        if not tramo:
            continue
        flow = totals.get(node_id, 0.0)
        tramo_flows[tramo["id"]] = flow
        totals[tramo["desde"]] = totals.get(tramo["desde"], 0.0) + flow
    return totals, tramo_flows


def node_demand_components(node: dict[str, Any], criteria: dict[str, Any]) -> dict[str, float]:
    direct = float(node.get("demanda_lps") or 0.0)
    appliances = appliance_demand_lps(node.get("aparatos") or {}, criteria)
    groups = group_appliance_demand_lps(node.get("grupos_aparatos") or [], criteria)
    raw_total = direct + appliances + groups
    factor = node.get("factor_simultaneidad")
    if factor is None:
        factor = criteria.get("factor_simultaneidad_global", 1.0)
    factor = float(factor if factor is not None else 1.0)
    return {
        "demanda_base_lps": direct,
        "demanda_aparatos_lps": appliances,
        "demanda_grupos_lps": groups,
        "demanda_sin_simultaneidad_lps": raw_total,
        "factor_simultaneidad_aplicado": factor,
        "demanda_lps": raw_total * factor,
    }


def node_demand_lps(node: dict[str, Any], criteria: dict[str, Any]) -> float:
    return node_demand_components(node, criteria)["demanda_lps"]


def appliance_demand_lps(aparatos: dict[str, Any], criteria: dict[str, Any]) -> float:
    total = 0.0
    catalog = criteria.get("aparatos_lps", {})
    for key, value in aparatos.items():
        unit = float(catalog.get(key, 0.0))
        if isinstance(value, dict):
            qty = float(value.get("cantidad", 0) or 0)
            factor = float(value.get("factor", value.get("factor_simultaneidad", 1)) or 1)
            custom_unit = value.get("caudal_lps")
            if custom_unit is not None:
                unit = float(custom_unit)
        else:
            qty = float(value or 0)
            factor = 1.0
        total += qty * factor * unit
    return total


def group_appliance_demand_lps(grupos: list[dict[str, Any]], criteria: dict[str, Any]) -> float:
    total = 0.0
    catalog = criteria.get("aparatos_lps", {})
    for group in grupos:
        key = str(group.get("grupo", group.get("key", "")))
        unit = float(group.get("caudal_lps", catalog.get(key, 0.0)) or 0.0)
        qty = float(group.get("cantidad", 0) or 0)
        factor = float(group.get("factor_simultaneidad", group.get("factor", 1)) or 1)
        total += qty * factor * unit
    return total


def calculate_tramos(
    tramos: list[dict[str, Any]],
    tramo_flows_lps: dict[str, float],
    criteria: dict[str, Any],
    warnings: list[str],
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for tramo in tramos:
        q_lps = float(tramo_flows_lps.get(tramo["id"], 0.0))
        diameter_mm, diameter_source = select_diameter(tramo, q_lps, criteria, warnings)
        hydraulic_diameter, diameter_meta = hydraulic_diameter_mm(tramo, diameter_mm, criteria, warnings)
        velocity = velocity_m_s(q_lps, hydraulic_diameter)
        c = hazen_c(tramo["material"], criteria)
        friction = hazen_williams_loss_m(q_lps, tramo["longitud_m"], hydraulic_diameter, c)
        accessory_result = calculate_accessory_loss(tramo["accesorios"], q_lps, velocity, hydraulic_diameter, c, criteria)
        accessory_loss = accessory_result["perdida_accesorios_m"]
        if q_lps > 0 and (velocity > criteria["velocidad_max_m_s"] or velocity < criteria["velocidad_min_m_s"]):
            warnings.append(
                f"Tramo '{tramo['id']}' velocidad {round(velocity, 3)} m/s fuera de rango "
                f"{criteria['velocidad_min_m_s']}-{criteria['velocidad_max_m_s']} m/s"
            )
        out.append({
            "id": tramo["id"],
            "nombre": tramo["nombre"],
            "desde": tramo["desde"],
            "hasta": tramo["hasta"],
            "longitud_m": round(tramo["longitud_m"], 3),
            "material": tramo["material"],
            "coeficiente_hazen": c,
            "caudal_lps": round(q_lps, 6),
            "caudal_gpm": round(q_lps * LPS_TO_GPM, 3),
            "diametro_mm": round(float(hydraulic_diameter), 6),
            "diametro_declarado_mm": round(float(diameter_mm), 6),
            **diameter_meta,
            "tipo_tramo": tramo.get("tipo_tramo", ""),
            "fuente_diametro": diameter_source,
            "velocidad_m_s": round(velocity, 6),
            "perdida_unitaria_m_m": round(friction / tramo["longitud_m"], 6) if tramo["longitud_m"] else 0,
            "perdida_friccion_m": round(friction, 6),
            "accesorios": tramo["accesorios"],
            "metodo_accesorios": accessory_result["metodo_accesorios"],
            "detalle_accesorios": accessory_result["detalle_accesorios"],
            "longitud_equivalente_accesorios_m": round(accessory_result["longitud_equivalente_accesorios_m"], 6),
            "k_accesorios_total": round(accessory_result["k_accesorios_total"], 6),
            "perdida_accesorios_k_m": round(accessory_result["perdida_accesorios_k_m"], 6),
            "perdida_accesorios_fija_m": round(accessory_result["perdida_accesorios_fija_m"], 6),
            "perdida_accesorios_m": round(accessory_loss, 6),
            "perdida_total_m": round(friction + accessory_loss, 6),
            "cumple_velocidad": q_lps <= 0 or (criteria["velocidad_min_m_s"] <= velocity <= criteria["velocidad_max_m_s"]),
        })
    return out


def hydraulic_diameter_mm(tramo: dict[str, Any], diameter_mm: float, criteria: dict[str, Any], warnings: list[str]) -> tuple[float, dict[str, Any]]:
    mode = str(criteria.get("diametro_modo") or "hidraulico").lower()
    nominal = float(diameter_mm)
    if mode != "ppr_nominal":
        return nominal, {
            "diametro_modo": "hidraulico",
            "diametro_nominal_mm": nominal,
            "diametro_hidraulico_mm": nominal,
            "ppr_serie": "",
            "diametro_fuente": "Diámetro hidráulico declarado",
        }
    serie = str(tramo.get("ppr_serie") or criteria.get("ppr_serie_default") or "SDR11")
    catalog = criteria.get("ppr_sdr", {})
    serie_catalog = catalog.get(serie, {}) if isinstance(catalog, dict) else {}
    internal = serie_catalog.get(str(int(nominal)), serie_catalog.get(str(nominal))) if isinstance(serie_catalog, dict) else None
    if internal is None:
        warnings.append(f"Tramo '{tramo['id']}' sin diámetro interno PPR para {nominal:g} mm {serie}; se usa diámetro declarado")
        internal = nominal
    return float(internal), {
        "diametro_modo": "ppr_nominal",
        "diametro_nominal_mm": nominal,
        "diametro_hidraulico_mm": float(internal),
        "ppr_serie": serie,
        "diametro_fuente": f"PPR nominal {nominal:g} mm {serie}",
    }


def select_diameter(tramo: dict[str, Any], q_lps: float, criteria: dict[str, Any], warnings: list[str]) -> tuple[float, str]:
    declared = tramo.get("diametro_mm")
    if declared is not None:
        if declared <= 0:
            raise ValueError(f"tramo {tramo['id']}.diametro_mm debe ser mayor que 0")
        return float(declared), "Entrada del usuario"

    diameters = [float(d) for d in criteria["diametros_mm"]]
    if not diameters:
        raise ValueError("criterios.diametros_mm no contiene diámetros válidos")
    if q_lps <= 0:
        warnings.append(f"Tramo '{tramo['id']}' sin caudal; se usa diámetro mínimo del catálogo")
        return diameters[0], "Auto mínimo sin caudal"

    candidates = []
    for diameter in diameters:
        hydraulic_diameter, _ = hydraulic_diameter_mm(tramo, diameter, criteria, [])
        candidates.append((diameter, velocity_m_s(q_lps, hydraulic_diameter)))
    for diameter, velocity in candidates:
        if criteria["velocidad_min_m_s"] <= velocity <= criteria["velocidad_max_m_s"]:
            return diameter, "Auto por velocidad"
    low_velocity = [item for item in candidates if item[1] < criteria["velocidad_min_m_s"]]
    if low_velocity:
        warnings.append(f"Tramo '{tramo['id']}' caudal bajo; ningún diámetro alcanza velocidad mínima")
        return low_velocity[0][0], "Auto por caudal bajo"
    warnings.append(f"Tramo '{tramo['id']}' caudal alto; diámetro máximo no cumple velocidad máxima")
    return diameters[-1], "Auto máximo fuera de rango"


def velocity_m_s(q_lps: float, diameter_mm: float) -> float:
    area = math.pi * (float(diameter_mm) / 1000.0) ** 2 / 4.0
    return (float(q_lps) / 1000.0) / area if area > 0 else 0.0


def hazen_williams_loss_m(q_lps: float, length_m: float, diameter_mm: float, c: float) -> float:
    q = float(q_lps) / 1000.0
    d = float(diameter_mm) / 1000.0
    if q <= 0 or length_m <= 0 or d <= 0 or c <= 0:
        return 0.0
    return 10.674 * float(length_m) * (q**1.852) / ((float(c) ** 1.852) * (d**4.871))


def hazen_c(material: str, criteria: dict[str, Any]) -> float:
    materials = {str(k).lower(): float(v) for k, v in criteria.get("materiales_hazen", {}).items()}
    return materials.get(str(material).lower(), float(criteria.get("coeficiente_hazen_default", 150)))


def calculate_accessory_loss(
    accesorios: dict[str, Any] | list[Any],
    q_lps: float,
    velocity: float,
    diameter_mm: float,
    c: float,
    criteria: dict[str, Any],
) -> dict[str, Any]:
    method = str(criteria.get("metodo_accesorios") or "longitud_equivalente").lower()
    if method == "hazen_williams_k":
        method = "k"
    items = accessory_items(accesorios)
    le_length, le_detail = equivalent_accessory_length(items, diameter_mm, criteria)
    le_loss = hazen_williams_loss_m(q_lps, le_length, diameter_mm, c)
    k_total, fixed_loss, k_detail = k_accessory_loss(items, velocity, criteria)
    k_loss = k_total * (velocity**2) / (2.0 * G) if k_total > 0 and velocity > 0 else 0.0

    if method in {"k", "coeficiente_k", "hazen_williams_k"}:
        loss = k_loss + fixed_loss
        detail = k_detail
        normalized_method = "k"
    elif method == "mixto":
        loss = k_loss + le_loss + fixed_loss
        detail = le_detail + [row for row in k_detail if "perdida_fija_m" not in row]
        normalized_method = "mixto"
    else:
        loss = le_loss + fixed_loss
        detail = le_detail
        normalized_method = "longitud_equivalente"

    detail = accessory_detail_with_losses(detail, q_lps, velocity, diameter_mm, c, normalized_method, criteria)

    return {
        "metodo_accesorios": normalized_method,
        "detalle_accesorios": detail,
        "longitud_equivalente_accesorios_m": le_length,
        "k_accesorios_total": k_total,
        "perdida_accesorios_k_m": k_loss,
        "perdida_accesorios_fija_m": fixed_loss,
        "perdida_accesorios_m": loss,
    }


def accessory_items(accesorios: dict[str, Any] | list[Any]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    if isinstance(accesorios, list):
        for item in accesorios:
            if isinstance(item, dict):
                tipo = str(item.get("tipo", item.get("accesorio", ""))).strip()
                qty = float(item.get("cantidad", item.get("qty", 1)) or 0)
                items.append({**item, "tipo": tipo or "perdida_fija", "cantidad": max(0.0, qty)})
            else:
                items.append({"tipo": str(item), "cantidad": 1.0})
        return items
    for key, value in accesorios.items():
        if isinstance(value, bool):
            qty = 1.0 if value else 0.0
            items.append({"tipo": str(key), "cantidad": qty})
        elif isinstance(value, dict):
            qty = float(value.get("cantidad", value.get("qty", 0)) or 0)
            items.append({**value, "tipo": str(key), "cantidad": max(0.0, qty)})
        else:
            qty = float(value or 0)
            items.append({"tipo": str(key), "cantidad": max(0.0, qty)})
    return items


def accessory_detail_with_losses(detail: list[dict[str, Any]], q_lps: float, velocity: float, diameter_mm: float, c: float, method: str, criteria: dict[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in detail:
        item = dict(row)
        fixed = float(item.get("perdida_fija_m", 0.0) or 0.0)
        if method == "k":
            kt = float(item.get("k_total", 0.0) or 0.0)
            ha = (kt * (velocity ** 2) / (2.0 * G) if kt > 0 and velocity > 0 else 0.0) + fixed
            item["metodo"] = "k" if kt > 0 else "perdida_fija"
        elif method == "mixto":
            le = float(item.get("longitud_equivalente_m", 0.0) or 0.0)
            kt = float(item.get("k_total", 0.0) or 0.0)
            ha = hazen_williams_loss_m(q_lps, le, diameter_mm, c)
            if kt > 0 and velocity > 0:
                ha += kt * (velocity ** 2) / (2.0 * G)
            ha += fixed
            item["metodo"] = "perdida_fija" if fixed > 0 and le == 0 and kt == 0 else "mixto"
        else:
            le = float(item.get("longitud_equivalente_m", 0.0) or 0.0)
            ha = hazen_williams_loss_m(q_lps, le, diameter_mm, c) + fixed
            item["metodo"] = "longitud_equivalente" if le > 0 else "perdida_fija"
        item["ha_m"] = round(ha, 6)
        out.append(item)
    return out


def k_accessory_loss(items: list[dict[str, Any]], velocity: float, criteria: dict[str, Any]) -> tuple[float, float, list[dict[str, Any]]]:
    catalog = criteria.get("accesorios_k", {})
    k_total = 0.0
    fixed_loss = 0.0
    detail: list[dict[str, Any]] = []
    for item in items:
        tipo = str(item.get("tipo", ""))
        qty = float(item.get("cantidad", 0) or 0)
        if "perdida_m" in item:
            loss = qty * float(item.get("perdida_m") or 0)
            fixed_loss += loss
            detail.append({"accesorio": tipo or "perdida_fija", "cantidad": round(qty, 3), "perdida_fija_m": round(loss, 6)})
            continue
        catalog_item = catalog.get(tipo, {}) if isinstance(catalog, dict) else {}
        k_unit = float(item.get("k", catalog_item.get("k", 0.0)) or 0.0)
        kt = qty * k_unit
        k_total += kt
        detail.append({
            "accesorio": tipo,
            "cantidad": round(qty, 3),
            "k_unitario": round(k_unit, 6),
            "k_total": round(kt, 6),
            "descripcion": catalog_item.get("descripcion", "") if isinstance(catalog_item, dict) else "",
        })
    return k_total, fixed_loss, detail


def equivalent_accessory_length(accesorios: dict[str, Any] | list[Any], diameter_mm: float, criteria: dict[str, Any]) -> tuple[float, list[dict[str, Any]]]:
    catalog = {str(k): float(v) for k, v in criteria.get("accesorios_le_d", {}).items()}
    diameter_m = float(diameter_mm) / 1000.0
    items = accesorios if isinstance(accesorios, list) and all(isinstance(item, dict) and "tipo" in item for item in accesorios) else accessory_items(accesorios)
    total = 0.0
    breakdown: list[dict[str, Any]] = []
    for item in items:
        tipo = str(item.get("tipo", ""))
        qty = float(item.get("cantidad", 0) or 0)
        if "perdida_m" in item:
            loss = qty * float(item.get("perdida_m") or 0.0)
            breakdown.append({"accesorio": tipo or "perdida_fija", "cantidad": round(qty, 3), "longitud_equivalente_m": 0.0, "perdida_fija_m": round(loss, 6)})
            continue
        le_d = float(item.get("le_d", catalog.get(tipo, 30.0)) or 0.0)
        length = qty * le_d * diameter_m
        total += length
        breakdown.append({
            "accesorio": tipo,
            "cantidad": round(qty, 3),
            "le_d": round(le_d, 3),
            "longitud_equivalente_m": round(length, 6),
        })
    return total, breakdown


def calculate_routes(
    source: dict[str, Any],
    criticals: list[dict[str, Any]],
    incoming: dict[str, dict[str, Any]],
    calculated_by_id: dict[str, dict[str, Any]],
    criteria: dict[str, Any],
    total_flow_lps: float,
    warnings: list[str],
) -> list[dict[str, Any]]:
    routes: list[dict[str, Any]] = []
    for critical in criticals:
        tramo_ids = path_tramo_ids(source["id"], critical["id"], incoming)
        route_tramos = [calculated_by_id[tid] for tid in tramo_ids]
        h_friction = sum(float(tramo["perdida_friccion_m"]) for tramo in route_tramos)
        h_accessories = sum(float(tramo["perdida_accesorios_m"]) for tramo in route_tramos)
        static = max(0.0, float(critical["elevacion_m"]) - float(source["elevacion_m"]))
        pressure_info = critical_pressure_info(critical, criteria)
        pressure = float(pressure_info["presion_mca"])
        base = static + pressure + h_friction + h_accessories
        safety = safety_margin_mca(static, pressure, h_friction, h_accessories, criteria)
        adt = base + float(safety)
        hp_required = pump_hp_required(total_flow_lps, adt, criteria["eficiencia_bomba"], criteria["peso_especifico_agua_n_m3"])
        pump_margin = float(criteria.get("margen_seleccion_bomba_porcentaje") or 0.0)
        hp_selection_min = hp_required * (1.0 + pump_margin)
        pump = select_pump(hp_selection_min, criteria["catalogo_bombas"], warnings)
        routes.append({
            "nodo_critico": critical["id"],
            "nombre": critical["nombre"],
            "tramos": tramo_ids,
            "caudal_sistema_lps": round(total_flow_lps, 6),
            "caudal_sistema_gpm": round(total_flow_lps * LPS_TO_GPM, 3),
            "altura_estatica_m": round(static, 6),
            "presion_punto_critico_mca": round(pressure, 6),
            "criterio_presion_minima": pressure_info["criterio"],
            "fuente_presion_minima": pressure_info["fuente"],
            "perdida_friccion_m": round(h_friction, 6),
            "perdida_accesorios_m": round(h_accessories, 6),
            "perdida_total_m": round(h_friction + h_accessories, 6),
            "margen_seguridad_mca": round(float(safety), 6),
            "adt_mca": round(adt, 6),
            "adt_ft": round(adt * M_TO_FT, 3),
            "adt_psi": round(adt * MCA_TO_PSI, 3),
            "hp_requerido": round(hp_required, 6),
            "hp_requerido_hidraulico": round(hp_required, 6),
            "margen_seleccion_bomba_porcentaje": round(pump_margin, 6),
            "hp_seleccion_minimo": round(hp_selection_min, 6),
            "factor_simultaneidad_global": round(float(criteria.get("factor_simultaneidad_global", 1.0)), 6),
            "potencia_hidraulica_w": round(hp_required * HP_WATT, 3),
            "bomba_seleccionada_hp": pump["hp"],
            "bomba_seleccionada_capacidad": pump["capacidad"],
        })
    return routes


def path_tramo_ids(source_id: str, target_id: str, incoming: dict[str, dict[str, Any]]) -> list[str]:
    tramos: list[str] = []
    current = target_id
    seen: set[str] = set()
    while current != source_id:
        if current in seen:
            raise ValueError("La red contiene un ciclo")
        seen.add(current)
        tramo = incoming.get(current)
        if not tramo:
            raise ValueError(f"Nodo crítico '{target_id}' no está conectado a fuente")
        tramos.append(tramo["id"])
        current = tramo["desde"]
    tramos.reverse()
    return tramos


def critical_pressure_info(node: dict[str, Any], criteria: dict[str, Any]) -> dict[str, Any]:
    for key in ("presion_min_mca", "equipo_presion_mca"):
        if node.get(key) is not None:
            return {
                "presion_mca": float(node[key]),
                "criterio": "custom",
                "fuente": f"Valor declarado en nodo ({key})",
            }
    tipo_equipo = str(node.get("tipo_equipo") or "").lower()
    is_flux = node.get("usa_fluxometro") or tipo_equipo in {"fluxometro", "fluxómetro"} or criteria.get("usar_presion_fluxometro")
    if is_flux:
        return {
            "presion_mca": float(criteria.get("presion_punto_critico_fluxometro_mca", 10.55)),
            "criterio": "fluxometro",
            "fuente": "R-008 Art. 32: fluxómetros 15 psi",
        }
    mode = str(criteria.get("criterio_presion_minima") or "tabla_4").lower()
    if mode == "art_32":
        return {
            "presion_mca": float(criteria.get("presion_aparato_tanque_mca", 7.03)),
            "criterio": "art_32",
            "fuente": "R-008 Art. 32: aparatos con tanque 10 psi",
        }
    return {
        "presion_mca": float(criteria.get("presion_critica_default_mca", 5.7)),
        "criterio": "tabla_4" if mode != "custom" else "custom",
        "fuente": "R-008 Tabla 4: presión mínima por aparato",
    }


def critical_pressure_mca(node: dict[str, Any], criteria: dict[str, Any]) -> float:
    return float(critical_pressure_info(node, criteria)["presion_mca"])


def safety_margin_mca(static: float, pressure: float, h_friction: float, h_accessories: float, criteria: dict[str, Any]) -> float:
    margin_type = str(criteria.get("margen_seguridad_tipo") or "porcentaje_sobre_adt_sin_margen").lower()
    pct = float(criteria.get("margen_seguridad_porcentaje") or 0.0)
    fixed = criteria.get("margen_seguridad_mca")
    if margin_type == "fijo_mca":
        return float(fixed or 0.0)
    if fixed is not None and margin_type in {"fijo", "entrada_usuario"}:
        return float(fixed)
    if margin_type == "porcentaje_sobre_perdidas":
        return (h_friction + h_accessories) * pct
    return (static + pressure + h_friction + h_accessories) * pct


def pump_hp_required(q_lps: float, adt_m: float, efficiency: float, gamma: float = 9800.0) -> float:
    if q_lps <= 0 or adt_m <= 0:
        return 0.0
    return (float(q_lps) / 1000.0) * float(adt_m) * float(gamma) / (max(float(efficiency), 0.01) * HP_WATT)


def select_pump(required_hp: float, catalog: list[dict[str, Any]], warnings: list[str]) -> dict[str, Any]:
    ordered = normalize_pump_catalog(catalog)
    for item in ordered:
        if float(item["hp"]) + 1e-12 >= required_hp:
            return {"capacidad": item["capacidad"], "hp": float(item["hp"]), "cumple_catalogo": True}
    if ordered:
        warnings.append("HP requerido supera catálogo de bombas; se adopta mayor capacidad disponible")
        item = ordered[-1]
        return {"capacidad": item["capacidad"], "hp": float(item["hp"]), "cumple_catalogo": False}
    raise ValueError("criterios.catalogo_bombas no contiene capacidades válidas")


def build_summary(total_flow_lps: float, critical_route: dict[str, Any], tramos: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "caudal_total_lps": round(total_flow_lps, 6),
        "caudal_total_gpm": round(total_flow_lps * LPS_TO_GPM, 3),
        "cantidad_tramos": len(tramos),
        "perdidas_friccion_totales_m": round(sum(float(t["perdida_friccion_m"]) for t in tramos), 6),
        "perdidas_accesorios_totales_m": round(sum(float(t["perdida_accesorios_m"]) for t in tramos), 6),
        "perdidas_totales_red_m": round(sum(float(t["perdida_total_m"]) for t in tramos), 6),
        "ruta_critica": critical_route["nodo_critico"],
        "adt_critica_mca": round(critical_route["adt_mca"], 6),
        "adt_critica_ft": round(critical_route["adt_ft"], 3),
        "adt_critica_psi": round(critical_route["adt_psi"], 3),
        "perdidas_totales_m": round(critical_route["perdida_total_m"], 6),
        "hp_requerido": round(critical_route["hp_requerido"], 6),
        "hp_requerido_hidraulico": critical_route["hp_requerido_hidraulico"],
        "margen_seleccion_bomba_porcentaje": critical_route["margen_seleccion_bomba_porcentaje"],
        "hp_seleccion_minimo": critical_route["hp_seleccion_minimo"],
        "factor_simultaneidad_global": round(float(critical_route.get("factor_simultaneidad_global", 1.0)), 6) if "factor_simultaneidad_global" in critical_route else None,
        "potencia_hidraulica_w": round(critical_route["potencia_hidraulica_w"], 3),
        "bomba_seleccionada_hp": critical_route["bomba_seleccionada_hp"],
        "bomba_seleccionada_capacidad": critical_route["bomba_seleccionada_capacidad"],
    }


def build_pump_result(critical_route: dict[str, Any], criteria: dict[str, Any]) -> dict[str, Any]:
    return {
        "caudal_lps": critical_route["caudal_sistema_lps"],
        "caudal_gpm": critical_route["caudal_sistema_gpm"],
        "adt_mca": critical_route["adt_mca"],
        "adt_ft": critical_route["adt_ft"],
        "adt_psi": critical_route["adt_psi"],
        "eficiencia": criteria["eficiencia_bomba"],
        "potencia_requerida_hp": critical_route["hp_requerido"],
        "potencia_requerida_w": critical_route["potencia_hidraulica_w"],
        "margen_seleccion_porcentaje": critical_route["margen_seleccion_bomba_porcentaje"],
        "potencia_seleccion_minima_hp": critical_route["hp_seleccion_minimo"],
        "capacidad_seleccionada": {
            "capacidad": critical_route["bomba_seleccionada_capacidad"],
            "hp": critical_route["bomba_seleccionada_hp"],
        },
    }


def build_hydropneumatic_tank_result(config: dict[str, Any], critical_route: dict[str, Any], criteria: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    if not coerce_bool(config.get("calcular"), False):
        return {"calculado": False, "mensaje": "Cálculo de tanque hidroneumático no solicitado"}

    q_lps = float(number_or_default(config.get("caudal_lps") or criteria.get("caudal_bomba_lps"), critical_route["caudal_sistema_lps"]))
    q_gpm = q_lps * LPS_TO_GPM
    factor_extraccion = float(number_or_default(config.get("factor_extraccion"), 0.38))
    volumen_l = (180.0 * (q_lps * 100.0) / 20.0) * 0.264
    volumen_gal = volumen_l / 3.78541
    catalog = normalize_tank_catalog(config.get("catalogo") or config.get("catalogo_tanques") or [])
    selected = select_tank(volumen_l, catalog, warnings)

    return {
        "calculado": True,
        "metodo": str(config.get("metodo") or "referencia_mdc"),
        "formula": "Litros necesarios = (180 × (Q_lps × 100) / 20) × 0.264",
        "caudal_base_lps": round(q_lps, 6),
        "caudal_base_gpm": round(q_gpm, 3),
        "factor_extraccion": round(factor_extraccion, 6),
        "volumen_necesario_l": round(volumen_l, 2),
        "volumen_necesario_gal": round(volumen_gal, 2),
        "volumen_adoptado_l": round(selected["volumen_adoptado_l"], 2),
        "volumen_adoptado_gal": round(selected["volumen_adoptado_gal"], 2),
        "cantidad": selected["cantidad"],
        "modelo": selected["modelo"],
        "catalogo_cumple": selected["catalogo_cumple"],
        "observacion": "El tanque debe instalarse con presión de trabajo adecuada según especificaciones del fabricante.",
    }


def normalize_tank_catalog(catalog: Any) -> list[dict[str, Any]]:
    if not isinstance(catalog, list):
        return []
    normalized: list[dict[str, Any]] = []
    for item in catalog:
        if not isinstance(item, dict):
            continue
        liters = item.get("litros", item.get("volumen_l"))
        gallons = item.get("gal", item.get("galones", item.get("volumen_gal")))
        if liters is None and gallons is not None:
            liters = float(gallons) * 3.78541
        if gallons is None and liters is not None:
            gallons = float(liters) / 3.78541
        if liters is None or float(liters) <= 0:
            continue
        normalized.append({"modelo": str(item.get("modelo") or item.get("capacidad") or f"{float(gallons or 0):g} gal"), "litros": float(liters), "gal": float(gallons or 0)})
    return sorted(normalized, key=lambda item: item["litros"])


def select_tank(volumen_l: float, catalog: list[dict[str, Any]], warnings: list[str]) -> dict[str, Any]:
    if not catalog:
        warnings.append("Tanque hidroneumático solicitado sin catálogo; se reporta volumen necesario sin selección comercial")
        return {"modelo": "NO DEFINIDO", "cantidad": 0, "volumen_adoptado_l": 0.0, "volumen_adoptado_gal": 0.0, "catalogo_cumple": False}
    for item in catalog:
        if item["litros"] >= volumen_l:
            return {"modelo": item["modelo"], "cantidad": 1, "volumen_adoptado_l": item["litros"], "volumen_adoptado_gal": item["gal"], "catalogo_cumple": True}
    largest = catalog[-1]
    qty = max(1, math.ceil(volumen_l / largest["litros"]))
    warnings.append("Volumen de tanque hidroneumático supera catálogo unitario; se adoptan múltiples tanques del mayor modelo")
    return {"modelo": largest["modelo"], "cantidad": qty, "volumen_adoptado_l": largest["litros"] * qty, "volumen_adoptado_gal": largest["gal"] * qty, "catalogo_cumple": False}


def atmospheric_head_m(altitude_m: float = 0.0) -> float:
    p0 = 101325.0
    rho = 1000.0
    p = p0 * (1 - 2.25577e-5 * altitude_m) ** 5.25588
    return p / (rho * G)


def water_vapor_head_m(temp_c: float = 25.0) -> float:
    rho = 1000.0
    pv_kpa = 0.61078 * math.exp((17.27 * temp_c) / (temp_c + 237.3))
    return (pv_kpa * 1000.0) / (rho * G)


def npsh_condition(static_suction_m: float) -> str:
    if static_suction_m > 0:
        return "succion_inundada"
    if static_suction_m < 0:
        return "succion_negativa"
    return "succion_al_mismo_nivel"


def build_suction_npsh(source: dict[str, Any], nodes: list[dict[str, Any]], calculated_tramos: list[dict[str, Any]], incoming: dict[str, dict[str, Any]], criteria: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    if not criteria.get("evaluar_npsh"):
        return {"evaluado": False, "mensaje": "Verificación NPSH no solicitada"}
    pump_id = criteria.get("nodo_bomba")
    if not pump_id:
        warnings.append("NPSH solicitado sin criterios.nodo_bomba; no se verifica succión")
        return {"evaluado": False, "mensaje": "Falta nodo_bomba"}
    by_node = {node["id"]: node for node in nodes}
    if pump_id not in by_node:
        warnings.append(f"NPSH solicitado con nodo_bomba '{pump_id}' inexistente")
        return {"evaluado": False, "mensaje": "Nodo bomba inexistente", "nodo_bomba": pump_id}
    try:
        tramo_ids = path_tramo_ids(source["id"], str(pump_id), incoming)
    except ValueError as exc:
        warnings.append(f"NPSH solicitado pero nodo_bomba '{pump_id}' no está conectado a la fuente: {exc}")
        return {"evaluado": False, "mensaje": "Nodo bomba no conectado a fuente", "nodo_bomba": pump_id}
    by_tramo = {tramo["id"]: tramo for tramo in calculated_tramos}
    suction_tramos = [by_tramo[tid] for tid in tramo_ids]
    losses = sum(float(t["perdida_total_m"]) for t in suction_tramos)
    pump_node = by_node[str(pump_id)]
    npsh_config = criteria.get("npsh") if isinstance(criteria.get("npsh"), dict) else {}
    water_level = float(number_or_default(npsh_config.get("nivel_minimo_agua_m"), source["elevacion_m"]))
    pump_axis = float(number_or_default(npsh_config.get("eje_bomba_m"), pump_node["elevacion_m"]))
    static_suction = water_level - pump_axis
    altitude_m = float(number_or_default(npsh_config.get("altitud_m"), 0.0))
    water_temp_c = float(number_or_default(npsh_config.get("temperatura_agua_c"), 25.0))
    tank_pressure = float(number_or_default(npsh_config.get("presion_tanque_mca"), 0.0))
    if "presion_atmosferica_mca" in npsh_config:
        h_atm = float(npsh_config["presion_atmosferica_mca"])
    elif "altitud_m" in npsh_config:
        h_atm = atmospheric_head_m(altitude_m)
    else:
        h_atm = float(criteria.get("presion_atmosferica_mca") or atmospheric_head_m(altitude_m))
    if "presion_vapor_mca" in npsh_config:
        h_vapor = float(npsh_config["presion_vapor_mca"])
    elif "temperatura_agua_c" in npsh_config:
        h_vapor = water_vapor_head_m(water_temp_c)
    else:
        h_vapor = float(criteria.get("presion_vapor_mca") or water_vapor_head_m(water_temp_c))
    npsha = h_atm + tank_pressure + static_suction - h_vapor - losses
    npshr = npsh_config.get("npsh_requerido_m", criteria.get("npsh_requerido_m"))
    margin_m = float(number_or_default(npsh_config.get("margen_npsh_m", criteria.get("margen_npsh_m")), 1.0))
    required_with_margin = None
    margin_available = None
    cumple = None
    estado = "No evaluable"
    nota = "Falta NPSH requerido de la bomba según curva del fabricante; confirmar con la selección de la bomba antes de comprar."
    if npshr is None:
        warnings.append("NPSH disponible calculado, pero falta NPSHr del fabricante; no se puede verificar cavitación")
    else:
        required_with_margin = float(npshr) + margin_m
        margin_available = npsha - float(npshr)
        cumple = npsha >= required_with_margin
        estado = "Cumple" if cumple else "No cumple"
        nota = "Verificación preliminar; confirmar NPSHr con curva del fabricante antes de comprar la bomba."
        if not cumple:
            warnings.append(f"NPSH disponible {npsha:.2f} m menor que NPSHr+margen {required_with_margin:.2f} m")
    return {
        "evaluado": True,
        "nodo_bomba": pump_id,
        "tramos_succion": tramo_ids,
        "condicion": npsh_condition(static_suction),
        "nivel_minimo_agua_m": round(water_level, 6),
        "eje_bomba_m": round(pump_axis, 6),
        "altura_succion_estatica_m": round(static_suction, 6),
        "perdidas_succion_m": round(losses, 6),
        "presion_atmosferica_mca": round(h_atm, 6),
        "presion_vapor_mca": round(h_vapor, 6),
        "temperatura_agua_c": round(water_temp_c, 3),
        "altitud_m": round(altitude_m, 3),
        "presion_tanque_mca": round(tank_pressure, 6),
        "npsh_disponible_m": round(npsha, 6),
        "npsh_requerido_m": None if npshr is None else round(float(npshr), 6),
        "margen_npsh_m": round(margin_m, 6),
        "npsh_requerido_con_margen_m": None if required_with_margin is None else round(required_with_margin, 6),
        "margen_disponible_m": None if margin_available is None else round(margin_available, 6),
        "cumple": cumple,
        "estado": estado,
        "nota": nota,
    }


def build_max_pressure_check(source: dict[str, Any], nodes: list[dict[str, Any]], critical_route: dict[str, Any], calculated_by_id: dict[str, dict[str, Any]], incoming: dict[str, dict[str, Any]], criteria: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    if not criteria.get("verificar_presion_maxima", True):
        return {"evaluado": False, "mensaje": "Verificación de presión máxima no solicitada"}
    limit = float(criteria.get("presion_maxima_red_mca", 42.2))
    adt = float(critical_route["adt_mca"])
    rows = []
    for node in nodes:
        if node["id"] == source["id"]:
            upstream_loss = 0.0
        else:
            try:
                tramo_ids = path_tramo_ids(source["id"], node["id"], incoming)
                upstream_loss = sum(float(calculated_by_id[tid]["perdida_total_m"]) for tid in tramo_ids)
            except ValueError:
                upstream_loss = 0.0
        static = float(node["elevacion_m"]) - float(source["elevacion_m"])
        pressure = max(0.0, adt - static - upstream_loss)
        exceeds = pressure > limit
        if exceeds:
            warnings.append(f"Nodo '{node['id']}' presión máxima estimada {pressure:.2f} mca supera límite {limit:.2f} mca")
        rows.append({
            "id": node["id"],
            "nombre": node["nombre"],
            "elevacion_m": round(float(node["elevacion_m"]), 6),
            "perdidas_aguas_arriba_m": round(upstream_loss, 6),
            "presion_estimada_mca": round(pressure, 6),
            "presion_estimada_psi": round(pressure * MCA_TO_PSI, 3),
            "excede": exceeds,
        })
    return {"evaluado": True, "limite_mca": round(limit, 6), "limite_psi": round(limit * MCA_TO_PSI, 3), "nodos": rows}


def build_node_results(nodes: list[dict[str, Any]], totals: dict[str, float], criticals: list[dict[str, Any]], source: dict[str, Any], criteria: dict[str, Any]) -> list[dict[str, Any]]:
    critical_ids = {node["id"] for node in criticals}
    out = []
    for node in nodes:
        components = node_demand_components(node, criteria)
        out.append({
            "id": node["id"],
            "nombre": node["nombre"],
            "tipo": node["tipo"],
            "elevacion_m": node["elevacion_m"],
            "fuente": node["id"] == source["id"],
            "critico": node["id"] in critical_ids,
            "presion_min_mca": node["presion_min_mca"],
            "equipo_presion_mca": node["equipo_presion_mca"],
            "tipo_equipo": node["tipo_equipo"],
            "usa_fluxometro": node["usa_fluxometro"],
            "demanda_base_lps": round(components["demanda_base_lps"], 6),
            "demanda_aparatos_lps": round(components["demanda_aparatos_lps"], 6),
            "demanda_grupos_lps": round(components["demanda_grupos_lps"], 6),
            "demanda_sin_simultaneidad_lps": round(components["demanda_sin_simultaneidad_lps"], 6),
            "factor_simultaneidad_aplicado": round(components["factor_simultaneidad_aplicado"], 6),
            "demanda_directa_lps": round(components["demanda_lps"], 6),
            "demanda_acumulada_lps": round(totals.get(node["id"], 0.0), 6),
            "aparatos": node["aparatos"],
            "grupos_aparatos": node["grupos_aparatos"],
        })
    return out


def prepare_project_dir(root: Path, project: dict[str, Any], force: bool) -> Path:
    project_dir = root / "proyectos" / project["id"]
    if project_dir.exists() and project.get("mode") == "nuevo" and force:
        shutil.rmtree(project_dir)
    if project_dir.exists() and project.get("mode") == "nuevo" and not force:
        existing = project_dir / "resultado_perdidas.json"
        if existing.exists():
            raise ValueError(f"Proyecto '{project['id']}' ya existe; use mode=modificar o --force")
    project_dir.mkdir(parents=True, exist_ok=True)
    return project_dir


def normalize_mapping(value: Any, field_name: str) -> dict[str, Any]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise ValueError(f"{field_name} debe ser objeto JSON")
    return dict(value)


def normalize_group_appliances(value: Any, node_id: str) -> list[dict[str, Any]]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError(f"nodo {node_id}.grupos_aparatos debe ser lista JSON")
    out: list[dict[str, Any]] = []
    for item in value:
        if not isinstance(item, dict):
            raise ValueError(f"nodo {node_id}.grupos_aparatos debe contener objetos")
        out.append(dict(item))
    return out


def normalize_accessories(value: Any) -> dict[str, Any] | list[Any]:
    if value is None:
        return {}
    if isinstance(value, dict):
        return dict(value)
    if isinstance(value, list):
        return list(value)
    raise ValueError("accesorios debe ser objeto o lista JSON")


def require_number(value: Any, field_name: str) -> float:
    if isinstance(value, bool) or value is None or not isinstance(value, int | float):
        raise ValueError(f"{field_name} debe ser numérico")
    return float(value)


def optional_number(value: Any) -> float | None:
    if value in (None, ""):
        return None
    if isinstance(value, bool) or not isinstance(value, int | float):
        raise ValueError("valor numérico inválido")
    return float(value)


def coerce_bool(value: Any, default: bool = False) -> bool:
    if value in (None, ""):
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "si", "sí", "on"}
    return bool(value)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Calcula pérdidas hidráulicas y bomba por HP comercial.")
    parser.add_argument("--input", required=True, help="Ruta a input.json")
    parser.add_argument("--root", default=".", help="Directorio base con proyectos/")
    parser.add_argument("--force", action="store_true", help="Recrear salida si project.mode=nuevo")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = run_calculation(args.input, args.root, force=args.force)
    project_dir = Path(args.root) / "proyectos" / result["project"]["id"]
    print(f"OK cálculo: {project_dir / 'resultado_perdidas.json'}")
    print(json.dumps(result["resumen"], indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

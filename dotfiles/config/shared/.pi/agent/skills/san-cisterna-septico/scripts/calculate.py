#!/usr/bin/env python3
"""Engine de cálculo para memoria cisterna/séptico.

Uso:
    python3 calculate.py --input input.json [--force]
"""
from __future__ import annotations

import argparse
import json
import math
import re
import shutil
import unicodedata
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

LPS_TO_GPM = 15.850323141489
M3_TO_GAL = 264.172052
L_PER_M3 = 1000.0

DOTACIONES_AGUA = {
    # R-008 Tabla 2 — consumos por tipo o uso de edificación.
    "viviendas_250": (250.0, "hab", "R-008 Tabla 2: viviendas 250-300 L/hab/día"),
    "viviendas_300": (300.0, "hab", "R-008 Tabla 2: viviendas 250-300 L/hab/día"),
    "industria_empleado": (80.0, "empleado", "R-008 Tabla 2: industrias 80 L/día·empleado por turno de 8 h + proceso"),
    "deposito_empleado": (80.0, "empleado", "R-008 Tabla 2: depósitos de materiales/equipos 80 L/día·empleado por turno"),
    "comercio_seco_local_hasta_50": (500.0, "local", "R-008 Tabla 2: comercio seco ≤50 m², 500 L/día"),
    "comercio_seco_m2_51_100": (10.0, "m²", "R-008 Tabla 2: comercio seco 51-100 m², 10 L/día·m²"),
    "comercio_seco_m2_mayor_100": (8.0, "m²", "R-008 Tabla 2: comercio seco >100 m², 8 L/día·m²"),
    "oficinas_m2": (6.0, "m²", "R-008 Tabla 2: oficinas comerciales 6 L/día·m²"),
    "oficinas_publicas_empleado": (40.0, "empleado", "R-008 Tabla 2: oficinas públicas 40 L/día·empleado"),
    "oficinas_publicas_visitante": (1.0, "visitante", "R-008 Tabla 2: oficinas públicas 1 L/día·visitante"),
    "centro_educativo_externo_estudiante": (40.0, "estudiante", "R-008 Tabla 2: centros educativos externos 40 L/día·estudiante"),
    "centro_educativo_semi_interno_estudiante": (70.0, "estudiante", "R-008 Tabla 2: centros educativos semi-internos 70 L/día·estudiante"),
    "centro_educativo_interno_estudiante": (200.0, "estudiante", "R-008 Tabla 2: centros educativos internos 200 L/día·estudiante"),
    "centro_educativo_personal_no_residente": (50.0, "persona", "R-008 Tabla 2: centros educativos personal no residente 50 L/día·persona"),
    "centro_educativo_personal_residente": (200.0, "persona", "R-008 Tabla 2: centros educativos personal residente 200 L/día·persona"),
    "hotel_cama": (250.0, "cama", "R-008 Tabla 2: hoteles 250 L/día·cama"),
    "motel_cama": (500.0, "cama", "R-008 Tabla 2: moteles 500 L/día·cama"),
    "pension_cama": (175.0, "cama", "R-008 Tabla 2: pensión 175 L/día·cama"),
    "restaurante_local_hasta_40": (2000.0, "local", "R-008 Tabla 2: restaurantes ≤40 m², 2,000 L/día"),
    "restaurante_m2_41_100": (50.0, "m²", "R-008 Tabla 2: restaurantes 41-100 m², 50 L/día·m²"),
    "restaurante_m2_mayor_100": (40.0, "m²", "R-008 Tabla 2: restaurantes >100 m², 40 L/día·m²"),
    "cafeteria_local_hasta_30": (1500.0, "local", "R-008 Tabla 2: cafeterías/bares ≤30 m², 1,500 L/día"),
    "cafeteria_m2_31_60": (60.0, "m²", "R-008 Tabla 2: cafeterías/bares 31-60 m², 60 L/día·m²"),
    "cafeteria_m2_61_100": (50.0, "m²", "R-008 Tabla 2: cafeterías/bares 61-100 m², 50 L/día·m²"),
    "cafeteria_m2_mayor_100": (40.0, "m²", "R-008 Tabla 2: cafeterías/bares >100 m², 40 L/día·m²"),
    "mercado_m2": (25.0, "m²", "R-008 Tabla 2: mercados 25 L/día·m²"),
    "hospital_cama": (800.0, "cama", "R-008 Tabla 2: hospitales y clínicas 800 L/día·cama"),
    "consultorio": (500.0, "consultorio", "R-008 Tabla 2: consultorios médicos 500 L/día·consultorio"),
    "clinica_dental": (1000.0, "unidad dental", "R-008 Tabla 2: clínicas dentales 1,000 L/día·unidad dental"),
    "lavanderia_agua_kg": (40.0, "kg ropa", "R-008 Tabla 2: lavanderías con agua 40 L/día·kg de ropa"),
    "lavanderia_seco_kg": (30.0, "kg ropa", "R-008 Tabla 2: lavanderías en seco 30 L/día·kg de ropa"),
    "lavado_auto_automatico": (12800.0, "unidad de lavado", "R-008 Tabla 2: lavaderos de autos automático 12,800 L/día·unidad"),
    "lavado_auto_no_automatico": (8000.0, "unidad de lavado", "R-008 Tabla 2: lavaderos de autos no automático 8,000 L/día·unidad"),
    "estacion_gasolina_bomba": (300.0, "bomba", "R-008 Tabla 2: estaciones de gasolina 300 L/día·bomba"),
    "parqueo_cubierto": (2.0, "m²", "R-008 Tabla 2: garajes y estacionamientos cubiertos 2 L/día·m²"),
    "auditorio_asiento": (3.0, "asiento", "R-008 Tabla 2: cines, teatros y auditorios 3 L/día·asiento"),
    "discoteca_m2": (30.0, "m²", "R-008 Tabla 2: discotecas/casinos/salas de baile 30 L/día·m²"),
    "circo_espectador": (1.0, "espectador", "R-008 Tabla 2: circos/hipódromos/parques de atracciones 1 L/día·espectador"),
    "estadio_espectador": (1.0, "espectador", "R-008 Tabla 2: estadios/velódromos/autódromos 1 L/día·espectador"),
    "areas_verdes": (2.0, "m²", "R-008 Tabla 2: áreas verdes, parques y jardines 2 L/día·m²"),
    "piscina_recirc": (10.0, "m²", "R-008 Tabla 2: piscinas 10 L/día·m² con recirculación"),
    "piscina_sin_recirc": (25.0, "m²", "R-008 Tabla 2: piscinas 25 L/día·m² sin recirculación"),
    "vestidores_piscina": (30.0, "m²", "R-008 Tabla 2: vestidores anexos a piscina 30 L/día·m²"),
    # Criterios custom frecuentes: sin fuente normativa automática; la columna Fuente queda en blanco.
    "poblacion_flotante_90": (90.0, "persona", ""),
    "oficinas_persona_50": (50.0, "persona", ""),
    "comedor_puesto_15": (15.0, "puesto", ""),
    "limpieza_mantenimiento_1_25": (1.25, "m²", ""),
}

REBOSE_TANQUE = [
    (0.0, 3.0, '2"'),
    (3.0, 9.5, '2 1/2"'),
    (9.5, 12.6, '3"'),
    (12.6, 25.2, '4"'),
    (25.2, 44.2, '5"'),
    (44.2, 63.0, '6"'),
    (63.0, float("inf"), '8"'),
]

DIAMETROS_COMERCIALES = [
    (0.75, 19.0),
    (1.0, 25.0),
    (1.25, 32.0),
    (1.5, 40.0),
    (2.0, 50.0),
    (2.5, 65.0),
    (3.0, 80.0),
    (4.0, 100.0),
]

CATALOGO_CISTERNAS_GUIA = [
    {"nombre": "Cisterna 4.5 m³", "largo_m": 2.00, "ancho_m": 1.50, "alto_util_m": 1.50},
    {"nombre": "Cisterna 8.1 m³", "largo_m": 2.50, "ancho_m": 1.80, "alto_util_m": 1.80},
    {"nombre": "Cisterna 12.0 m³", "largo_m": 3.00, "ancho_m": 2.00, "alto_util_m": 2.00},
    {"nombre": "Cisterna 18.5 m³", "largo_m": 3.70, "ancho_m": 2.50, "alto_util_m": 2.00},
    {"nombre": "Cisterna 27.0 m³", "largo_m": 4.50, "ancho_m": 3.00, "alto_util_m": 2.00},
    {"nombre": "Cisterna 36.3 m³", "largo_m": 5.50, "ancho_m": 3.00, "alto_util_m": 2.20},
    {"nombre": "Cisterna 46.2 m³", "largo_m": 6.00, "ancho_m": 3.50, "alto_util_m": 2.20},
    {"nombre": "Cisterna 70.0 m³", "largo_m": 7.00, "ancho_m": 4.00, "alto_util_m": 2.50},
]

CATALOGO_SEPTICOS_GUIA = [
    {"nombre": "Séptico 3.0 m³", "largo_m": 2.30, "ancho_m": 1.10, "profundidad_util_m": 1.20, "camara_aire_m": 0.30, "compartimientos": 1},
    {"nombre": "Séptico 4.5 m³", "largo_m": 2.90, "ancho_m": 1.30, "profundidad_util_m": 1.20, "camara_aire_m": 0.30, "compartimientos": 1},
    {"nombre": "Séptico 6.0 m³", "largo_m": 3.10, "ancho_m": 1.50, "profundidad_util_m": 1.30, "camara_aire_m": 0.30, "compartimientos": 1},
    {"nombre": "Séptico 7.5 m³", "largo_m": 3.40, "ancho_m": 1.70, "profundidad_util_m": 1.30, "camara_aire_m": 0.30, "compartimientos": 1},
    {"nombre": "Séptico 9.3 m³", "largo_m": 3.65, "ancho_m": 1.70, "profundidad_util_m": 1.50, "camara_aire_m": 0.40, "compartimientos": 2},
    {"nombre": "Séptico 12.5 m³", "largo_m": 4.15, "ancho_m": 2.00, "profundidad_util_m": 1.50, "camara_aire_m": 0.40, "compartimientos": 2},
    {"nombre": "Séptico 15.5 m³", "largo_m": 4.70, "ancho_m": 2.20, "profundidad_util_m": 1.50, "camara_aire_m": 0.40, "compartimientos": 2},
    {"nombre": "Séptico 18.6 m³", "largo_m": 4.85, "ancho_m": 2.40, "profundidad_util_m": 1.60, "camara_aire_m": 0.40, "compartimientos": 2},
    {"nombre": "Séptico 21.6 m³", "largo_m": 5.20, "ancho_m": 2.60, "profundidad_util_m": 1.60, "camara_aire_m": 0.40, "compartimientos": 2},
    {"nombre": "Séptico 30.0 m³", "largo_m": 6.40, "ancho_m": 3.00, "profundidad_util_m": 1.60, "camara_aire_m": 0.40, "compartimientos": 2},
]

DOTACION_DOMESTICA = [
    (150, 250),
    (250, 275),
    (400, 300),
    (500, 325),
    (600, 350),
    (700, 375),
    (float("inf"), 400),
]

SEPTICO_TABLA = [
    {"min": 1, "max": 2, "volumen_m3": 0.80, "largo_m": 1.20, "ancho_m": 0.60, "profundidad_util_m": 1.20, "camara_aire_m": 0.30, "compartimientos": 1},
    {"min": 3, "max": 4, "volumen_m3": 1.50, "largo_m": 1.60, "ancho_m": 0.80, "profundidad_util_m": 1.20, "camara_aire_m": 0.30, "compartimientos": 1},
    {"min": 5, "max": 7, "volumen_m3": 2.10, "largo_m": 1.95, "ancho_m": 0.90, "profundidad_util_m": 1.20, "camara_aire_m": 0.30, "compartimientos": 1},
    {"min": 8, "max": 10, "volumen_m3": 3.00, "largo_m": 2.30, "ancho_m": 1.10, "profundidad_util_m": 1.20, "camara_aire_m": 0.30, "compartimientos": 1},
    {"min": 11, "max": 15, "volumen_m3": 4.50, "largo_m": 2.90, "ancho_m": 1.30, "profundidad_util_m": 1.20, "camara_aire_m": 0.30, "compartimientos": 1},
    {"min": 16, "max": 20, "volumen_m3": 6.00, "largo_m": 3.10, "ancho_m": 1.50, "profundidad_util_m": 1.30, "camara_aire_m": 0.30, "compartimientos": 1},
    {"min": 21, "max": 25, "volumen_m3": 7.50, "largo_m": 3.40, "ancho_m": 1.70, "profundidad_util_m": 1.30, "camara_aire_m": 0.30, "compartimientos": 1},
    {"min": 26, "max": 30, "volumen_m3": 9.00, "largo_1_m": 2.45, "largo_2_m": 1.20, "ancho_m": 1.70, "profundidad_util_m": 1.50, "camara_aire_m": 0.40, "compartimientos": 2},
    {"min": 31, "max": 35, "volumen_m3": 10.50, "largo_1_m": 2.75, "largo_2_m": 1.30, "ancho_m": 1.80, "profundidad_util_m": 1.50, "camara_aire_m": 0.40, "compartimientos": 2},
    {"min": 36, "max": 40, "volumen_m3": 12.00, "largo_1_m": 2.80, "largo_2_m": 1.35, "ancho_m": 2.00, "profundidad_util_m": 1.50, "camara_aire_m": 0.40, "compartimientos": 2},
    {"min": 41, "max": 50, "volumen_m3": 15.00, "largo_1_m": 3.15, "largo_2_m": 1.55, "ancho_m": 2.20, "profundidad_util_m": 1.50, "camara_aire_m": 0.40, "compartimientos": 2},
    {"min": 51, "max": 60, "volumen_m3": 18.00, "largo_1_m": 3.25, "largo_2_m": 1.60, "ancho_m": 2.40, "profundidad_util_m": 1.60, "camara_aire_m": 0.40, "compartimientos": 2},
    {"min": 61, "max": 70, "volumen_m3": 21.00, "largo_1_m": 3.50, "largo_2_m": 1.70, "ancho_m": 2.60, "profundidad_util_m": 1.60, "camara_aire_m": 0.40, "compartimientos": 2},
    {"min": 71, "max": 80, "volumen_m3": 24.00, "largo_1_m": 3.85, "largo_2_m": 1.85, "ancho_m": 2.70, "profundidad_util_m": 1.60, "camara_aire_m": 0.40, "compartimientos": 2},
    {"min": 81, "max": 90, "volumen_m3": 27.00, "largo_1_m": 4.20, "largo_2_m": 2.00, "ancho_m": 2.80, "profundidad_util_m": 1.60, "camara_aire_m": 0.40, "compartimientos": 2},
    {"min": 91, "max": 100, "volumen_m3": 30.00, "largo_1_m": 4.30, "largo_2_m": 2.10, "ancho_m": 3.00, "profundidad_util_m": 1.60, "camara_aire_m": 0.40, "compartimientos": 2},
]

SEPTICO_TABLA_34 = {
    "bares_cliente": (34.0, "espacio cliente", "R-008 Tabla 34: bares 34 L/espacio de cliente"),
    "campamento_empleado": (113.6, "empleado", "R-008 Tabla 34: campamento obra 113.6 L/empleado"),
    "clinica_medico_persona": (283.9, "persona", "R-008 Tabla 34: consultorios/clínicas, médicos/enfermeras/staff 283.9 L/persona"),
    "clinica_administrativo_persona": (75.7, "persona", "R-008 Tabla 34: consultorios/clínicas, personal administrativo 75.7 L/persona"),
    "clinica_paciente_persona": (37.9, "persona", "R-008 Tabla 34: consultorios/clínicas, pacientes 37.9 L/persona"),
    "escuela_aula_40_estudiantes": (2000.0, "aula", "R-008 Tabla 34: escuelas 2,000 L/aula de 40 estudiantes"),
    "guarderia_persona": (91.0, "persona", "R-008 Tabla 34: guarderías 91 L/persona"),
    "hospital_cama": (757.0, "cama", "R-008 Tabla 34: hospitales 757 L/cama"),
    "hotel_habitacion": (378.5, "habitación", "R-008 Tabla 34: hoteles 378.5 L/habitación"),
    "motel_habitacion": (756.0, "habitación", "R-008 Tabla 34: moteles 756 L/habitación"),
    "iglesia_persona": (11.4, "persona", "R-008 Tabla 34: iglesias 11.4 L/persona"),
    "lavadero_carro_servicio": (189.3, "unidad de servicio", "R-008 Tabla 34: lavaderos de carro 189.3 L/unidad de servicio"),
    "drenaje_garaje": (378.5, "drenaje", "R-008 Tabla 34: drenaje de garajes/estaciones 378.5 L/drenaje"),
    "lavanderia_auto_servicio_maquina": (189.3, "máquina", "R-008 Tabla 34: lavanderías autoservicio 189.3 L/máquina"),
    "asilo_cama": (378.5, "cama", "R-008 Tabla 34: asilos/casas de reposo sin lavandería 378.5 L/cama"),
    "parque_duchas_banos_persona": (37.9, "persona", "R-008 Tabla 34: parques con duchas y baños 37.9 L/persona"),
    "parque_banos_persona": (18.9, "persona", "R-008 Tabla 34: parques con baños 18.9 L/persona"),
    "restaurante_banos_cocina_asiento": (113.6, "asiento", "R-008 Tabla 34: restaurantes - baños y cocina 113.6 L/asiento"),
    "restaurante_lavaplatos_triturador_asiento": (11.4, "asiento", "R-008 Tabla 34: restaurantes - lavaplatos/triturador 11.4 L/asiento"),
    "restaurante_cocina_sin_lavaplatos_asiento": (34.1, "asiento", "R-008 Tabla 34: restaurantes - sólo desperdicio de cocina 34.1 L/asiento"),
    "restaurante_solo_banos_asiento": (79.5, "asiento", "R-008 Tabla 34: restaurantes - sólo baños 79.5 L/asiento"),
    "restaurante_24h_banos_cocina_asiento": (227.1, "asiento", "R-008 Tabla 34: restaurantes 24h - baños y cocina 227.1 L/asiento"),
    "restaurante_24h_lavaplatos_triturador_asiento": (22.7, "asiento", "R-008 Tabla 34: restaurantes 24h - lavaplatos/triturador 22.7 L/asiento"),
    "restaurante_comida_rapida_asiento": (56.8, "asiento", "R-008 Tabla 34: restaurantes comida rápida utensilios desechables 56.8 L/asiento"),
    "salon_reuniones_persona": (7.6, "persona", "R-008 Tabla 34: salón de reuniones sin cocina 7.6 L/persona"),
    "salon_baile_persona": (11.4, "persona", "R-008 Tabla 34: salones de baile 11.4 L/persona"),
    "salon_belleza_estacion": (529.9, "estación", "R-008 Tabla 34: salones de belleza 529.9 L/estación"),
    "salon_banquetes_cocina_comida": (11.4, "comida servida", "R-008 Tabla 34: salones de banquetes sólo cocina 11.4 L/comida servida"),
    "salon_banquetes_cocina_banos_comida": (41.6, "comida servida", "R-008 Tabla 34: salones de banquetes cocina y baños 41.6 L/comida servida"),
}

SEPTICO_TABLA_34_GAL = {
    "bares_cliente": 9.0,
    "campamento_empleado": 30.0,
    "clinica_medico_persona": 75.0,
    "clinica_administrativo_persona": 20.0,
    "clinica_paciente_persona": 10.0,
    "escuela_aula_40_estudiantes": 528.0,
    "guarderia_persona": 24.0,
    "hospital_cama": 200.0,
    "hotel_habitacion": 100.0,
    "motel_habitacion": 200.0,
    "iglesia_persona": 3.0,
    "lavadero_carro_servicio": 50.0,
    "drenaje_garaje": 100.0,
    "lavanderia_auto_servicio_maquina": 50.0,
    "asilo_cama": 100.0,
    "parque_duchas_banos_persona": 10.0,
    "parque_banos_persona": 5.0,
    "restaurante_banos_cocina_asiento": 30.0,
    "restaurante_lavaplatos_triturador_asiento": 3.0,
    "restaurante_cocina_sin_lavaplatos_asiento": 9.0,
    "restaurante_solo_banos_asiento": 21.0,
    "restaurante_24h_banos_cocina_asiento": 60.0,
    "restaurante_24h_lavaplatos_triturador_asiento": 6.0,
    "restaurante_comida_rapida_asiento": 15.0,
    "salon_reuniones_persona": 2.0,
    "salon_baile_persona": 3.0,
    "salon_belleza_estacion": 140.0,
    "salon_banquetes_cocina_comida": 3.0,
    "salon_banquetes_cocina_banos_comida": 11.0,
}

RESIDENTIAL_TYPES = {
    "residencial",
    "vivienda",
    "viviendas",
    "villa",
    "villas",
    "casa",
    "casas",
    "apartamento",
    "apartamentos",
    "apto",
    "aptos",
    "edificio residencial",
    "edificio de apartamentos",
    "torre residencial",
    "condominio",
    "duplex",
}

REFERENCE_PLACEHOLDERS = {"", "template", "plantilla", "entrada del usuario", "criterio de memoria"}

DEFAULT_CRITERIOS = {
    "kd": 1.5,
    "kh": 2.0,
    "qmh_base": "qmax_diario",
    "aplicar_minimo_6_hab_vivienda": True,
    "habitantes_minimos_por_vivienda": 6,
    "dias_cisterna_default": 2.0,
    "permitir_1_5_dias_mas_16_viviendas": True,
    "factor_aguas_residuales": 0.8,
    "dotacion_septico_l_hab_dia": 200,
    "retencion_septico_dias": 1.5,
    "lodos_l_hab_anio": 40,
    "periodo_limpieza_anios": 2,
    "metodo_septico_default": "max_formula_tabla_r008",
    "base_calculo_cisterna_default": "qmd",
    "factor_seguridad_cisterna_default": 1.0,
    "tiempo_llenado_h_default": 8.0,
    "factor_acometida_default": 1.5,
    "cantidad_opciones_guia": 3,
    "dimension_cisterna": {"relacion_largo_ancho": 2.0, "altura_util_m": 2.0, "borde_libre_m": 0.3},
    "dimension_septico": {"relacion_largo_ancho": 2.5, "profundidad_util_m": 1.5, "camara_aire_m": 0.4},
}


def deep_merge(base: dict, override: dict) -> dict:
    out = deepcopy(base)
    for k, v in (override or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def slug(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9._-]+", "-", value)
    return value.strip("-") or "proyecto"


def today_es() -> str:
    return datetime.now().strftime("%d/%m/%Y")


def round_up(value: float, step: float = 0.05) -> float:
    return round(math.ceil((value - 1e-9) / step) * step, 2)


def dotacion_domestica(area_solar_m2: Optional[float]) -> Tuple[float, str]:
    if area_solar_m2 is None:
        return 250.0, "R-008 Tabla 37 default sin área solar"
    for limit, dot in DOTACION_DOMESTICA:
        if area_solar_m2 <= limit:
            return float(dot), f"R-008 Tabla 37 área solar ≤ {limit if math.isfinite(limit) else '701+'} m²"
    return 400.0, "R-008 Tabla 37 área solar ≥ 701 m²"


def dotacion_por_key(key: str) -> Tuple[float, str, str]:
    if key not in DOTACIONES_AGUA:
        disponibles = ", ".join(sorted(DOTACIONES_AGUA))
        raise KeyError(f"dotacion_key no encontrada: {key}. Disponibles: {disponibles}")
    dotacion, unidad, fuente = DOTACIONES_AGUA[key]
    return float(dotacion), unidad, fuente


def volumen_litros(volumen_m3: float) -> float:
    return round(float(volumen_m3) * L_PER_M3, 1)


def volumen_galones(volumen_m3: float) -> float:
    return round(float(volumen_m3) * M3_TO_GAL, 1)


def add_volume_units(item: dict, key: str = "volumen_m3") -> dict:
    if item.get(key) is None:
        return item
    volumen_m3 = float(item[key])
    item["volumen_l"] = volumen_litros(volumen_m3)
    item["volumen_gal"] = volumen_galones(volumen_m3)
    return item


def tabla_34_por_key(key: str) -> Tuple[float, str, str, float]:
    if key not in SEPTICO_TABLA_34:
        disponibles = ", ".join(sorted(SEPTICO_TABLA_34))
        raise KeyError(f"tabla_34_key no encontrada: {key}. Disponibles: {disponibles}")
    volumen_l, unidad, fuente = SEPTICO_TABLA_34[key]
    return float(volumen_l), unidad, fuente, float(SEPTICO_TABLA_34_GAL.get(key, volumen_l / 3.785411784))


def normalized_text(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or "").strip().lower())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", text)


def fuente_normativa(*values: Any) -> str:
    for value in values:
        text = str(value or "").strip()
        if normalized_text(text) in REFERENCE_PLACEHOLDERS:
            continue
        if "R-008" in text.upper():
            return text
    return ""


def infer_uso_residencial(s: dict, viviendas: int) -> bool:
    for key in ("uso_residencial", "es_residencial", "residencial"):
        if key in s and s[key] is not None:
            return bool(s[key])
    tipo = normalized_text(s.get("tipo", ""))
    return viviendas > 0 or tipo in RESIDENTIAL_TYPES


def calc_tabla_34_item(item: dict) -> Optional[dict]:
    key = item.get("tabla_34_key") or item.get("tipo_edificacion_tabla_34")
    if not key:
        return None
    volumen_l, unidad_default, fuente, volumen_gal = tabla_34_por_key(str(key))
    cantidad = float(item.get("tabla_34_cantidad", item.get("cantidad_tabla_34", item.get("cantidad", 0))) or 0)
    factor = float(item.get("tabla_34_factor", item.get("factor_tabla_34", item.get("factor", 1))) or 1)
    volumen_total_l = cantidad * factor * volumen_l
    volumen_total_gal = cantidad * factor * volumen_gal
    return {
        "concepto": item.get("concepto", item.get("nombre", str(key))),
        "tipo_edificacion_tabla_34": str(key),
        "tabla_34_key": str(key),
        "cantidad": cantidad,
        "unidad": item.get("tabla_34_unidad") or unidad_default,
        "factor": factor,
        "volumen_l_unidad": volumen_l,
        "volumen_gal_unidad": round(volumen_gal, 1),
        "volumen_l": round(volumen_total_l, 1),
        "volumen_gal": round(volumen_total_gal, 1),
        "volumen_m3": round(volumen_total_l / L_PER_M3, 3),
        "fuente": fuente,
    }


def calc_consumo_item(item: dict) -> dict:
    cantidad = float(item.get("cantidad") or 0)
    factor = float(item.get("factor") or 1)
    if item.get("dotacion_key"):
        dot, unidad_default, fuente_default = dotacion_por_key(str(item["dotacion_key"]))
        unidad = item.get("unidad") or unidad_default
        fuente = fuente_normativa(item.get("fuente"), item.get("referencia"), fuente_default)
    else:
        dot = float(item.get("dotacion_l_unidad_dia") or 0)
        unidad = item.get("unidad", "unidad")
        fuente = fuente_normativa(item.get("fuente"), item.get("referencia"))
    consumo = cantidad * dot * factor
    return {
        "concepto": item.get("concepto", item.get("nombre", "Consumo adicional")),
        "cantidad": cantidad,
        "unidad": unidad,
        "factor": factor,
        "dotacion_l_unidad_dia": dot,
        "consumo_l_dia": round(consumo, 3),
        "fuente": fuente,
        "dotacion_key": item.get("dotacion_key"),
        "tabla_34_key": item.get("tabla_34_key"),
    }


def seleccionar_rebose(q_lps: float) -> dict:
    for q_min, q_max, diam in REBOSE_TANQUE:
        if q_min <= q_lps <= q_max:
            return {"q_min_lps": q_min, "q_max_lps": q_max, "diametro_rebose_pulg": diam}
    q_min, q_max, diam = REBOSE_TANQUE[-1]
    return {"q_min_lps": q_min, "q_max_lps": q_max, "diametro_rebose_pulg": diam}


def seleccionar_acometida(q_lps: float, velocidad_max_m_s: float = 2.5) -> dict:
    for pulg, mm in DIAMETROS_COMERCIALES:
        diam_m = mm / 1000
        area_m2 = math.pi * diam_m ** 2 / 4
        velocidad = (q_lps / 1000) / area_m2 if area_m2 else float("inf")
        if velocidad <= velocidad_max_m_s:
            return {"diametro_pulg": pulg, "diametro_mm": mm, "velocidad_m_s": round(velocidad, 3), "cumple_velocidad": True}
    pulg, mm = DIAMETROS_COMERCIALES[-1]
    return {"diametro_pulg": pulg, "diametro_mm": mm, "velocidad_m_s": None, "cumple_velocidad": False}


def volume_from_dims(dims: Optional[dict], kind: str) -> Optional[dict]:
    if not dims:
        return None
    if kind == "cisterna":
        l = float(dims.get("largo_m", 0) or 0)
        w = float(dims.get("ancho_m", 0) or 0)
        h = float(dims.get("alto_util_m", dims.get("altura_util_m", dims.get("alto_m", 0))) or 0)
        vol = l * w * h
        return add_volume_units({"largo_m": l, "ancho_m": w, "alto_util_m": h, "alto_m": h, "volumen_m3": round(vol, 3)})
    l = float(dims.get("largo_m", 0) or 0)
    w = float(dims.get("ancho_m", 0) or 0)
    h = float(dims.get("profundidad_util_m", dims.get("alto_util_m", 0)) or 0)
    vol = l * w * h
    return add_volume_units({"largo_m": l, "ancho_m": w, "profundidad_util_m": h, "volumen_m3": round(vol, 3)})


def auto_rectangular(required_m3: float, ratio: float, height_m: float, air_m: float = 0.0, two_compartments: bool = False) -> dict:
    height_m = max(height_m, 0.1)
    ratio = max(ratio, 1.0)
    width = math.sqrt(required_m3 / (ratio * height_m))
    length = ratio * width
    width = round_up(width, 0.05)
    length = round_up(length, 0.05)
    vol = length * width * height_m
    out = {
        "largo_m": length,
        "ancho_m": width,
        "volumen_m3": round(vol, 3),
    }
    if two_compartments:
        out["profundidad_util_m"] = height_m
        out["camara_aire_m"] = air_m
        out["largo_1_m"] = round_up(length * 2 / 3, 0.05)
        out["largo_2_m"] = round_up(length / 3, 0.05)
        out["compartimientos"] = 2
    else:
        out["alto_util_m"] = height_m
    return add_volume_units(out)


def catalogo_entry_with_volume(entry: dict, kind: str) -> dict:
    item = deepcopy(entry)
    if kind == "cisterna":
        item.setdefault("alto_m", item.get("alto_util_m"))
        item["volumen_m3"] = round(float(item["largo_m"]) * float(item["ancho_m"]) * float(item.get("alto_util_m", item.get("alto_m"))), 3)
    else:
        item["volumen_m3"] = round(float(item["largo_m"]) * float(item["ancho_m"]) * float(item["profundidad_util_m"]), 3)
    return add_volume_units(item)


def opciones_catalogo_guia(required_m3: float, kind: str, criterios: dict, group_cfg: dict) -> List[dict]:
    custom_key = "catalogo_cisternas_guia" if kind == "cisterna" else "catalogo_septicos_guia"
    default_catalog = CATALOGO_CISTERNAS_GUIA if kind == "cisterna" else CATALOGO_SEPTICOS_GUIA
    catalog = group_cfg.get("catalogo_guia") or criterios.get(custom_key) or default_catalog
    limit = int(group_cfg.get("cantidad_opciones_guia", criterios.get("cantidad_opciones_guia", 3)) or 3)
    normalized = [catalogo_entry_with_volume(entry, kind) for entry in catalog]
    normalized.sort(key=lambda x: x["volumen_m3"])
    cumplen = [item for item in normalized if item["volumen_m3"] + 1e-9 >= required_m3]
    selected = cumplen[:limit] if cumplen else normalized[-limit:]
    out = []
    for idx, item in enumerate(selected, 1):
        item = deepcopy(item)
        item["opcion"] = idx
        item["cumple"] = item["volumen_m3"] + 1e-9 >= required_m3
        item["margen_m3"] = round(item["volumen_m3"] - required_m3, 3)
        item["uso"] = "guía; ajustar a arquitectura, estructura y obra"
        out.append(item)
    return out


def calc_suministro(s: dict, criterios: dict) -> dict:
    viviendas = int(s.get("viviendas", s.get("unidades", 0)) or 0)
    uso_residencial = infer_uso_residencial(s, viviendas)
    personas_decl = s.get("personas")
    personas_por_viv = float(s.get("personas_por_vivienda", s.get("habitantes_por_unidad", 0)) or 0)
    if personas_decl is None:
        personas_base = viviendas * personas_por_viv if viviendas else 0
    else:
        personas_base = float(personas_decl)

    if s.get("factor_ocupacion") is not None and personas_decl is None:
        personas_base *= float(s.get("factor_ocupacion") or 1)

    min_hab = int(criterios["habitantes_minimos_por_vivienda"])
    aplicar_min = bool(criterios["aplicar_minimo_6_hab_vivienda"]) and viviendas > 0
    personas_min = viviendas * min_hab if aplicar_min else 0
    personas_diseno = max(personas_base, personas_min)

    items = []
    consumo_res = 0.0
    has_explicit_consumos = bool(s.get("consumos"))
    if personas_diseno > 0 and not has_explicit_consumos:
        dotacion_key = s.get("dotacion_residencial_key")
        if dotacion_key:
            dotacion, _, fuente_dot = dotacion_por_key(str(dotacion_key))
        else:
            dotacion = s.get("dotacion_l_hab_dia")
            if dotacion is None:
                dotacion, fuente_dot = dotacion_domestica(s.get("area_solar_m2"))
            else:
                dotacion = float(dotacion)
                fuente_dot = fuente_normativa(s.get("fuente"), s.get("referencia"))
        consumo_res = personas_diseno * dotacion
        items.append({
            "concepto": "Habitantes",
            "cantidad": personas_diseno,
            "unidad": "hab",
            "factor": 1.0,
            "dotacion_l_unidad_dia": dotacion,
            "consumo_l_dia": round(consumo_res, 3),
            "fuente": fuente_dot,
            "dotacion_key": dotacion_key,
        })
    else:
        dotacion = s.get("dotacion_l_hab_dia") or None

    total = consumo_res
    tabla_34_items = []
    consumo_items = []
    consumo_items.extend(s.get("consumos", []) or [])
    consumo_items.extend(s.get("consumos_adicionales", []) or [])
    for item in consumo_items:
        calc = calc_consumo_item(item)
        total += calc["consumo_l_dia"]
        items.append(calc)
        tabla_34_item = calc_tabla_34_item(item)
        if tabla_34_item:
            tabla_34_items.append(tabla_34_item)

    if s.get("tipo_edificacion_tabla_34") or s.get("tabla_34_key"):
        tabla_34_item = calc_tabla_34_item({
            "concepto": s.get("concepto_tabla_34") or s.get("nombre") or s.get("id"),
            "tipo_edificacion_tabla_34": s.get("tipo_edificacion_tabla_34") or s.get("tabla_34_key"),
            "cantidad_tabla_34": s.get("cantidad_tabla_34", s.get("tabla_34_cantidad", 0)),
            "factor_tabla_34": s.get("factor_tabla_34", s.get("tabla_34_factor", 1)),
            "tabla_34_unidad": s.get("tabla_34_unidad"),
        })
        if tabla_34_item:
            tabla_34_items.append(tabla_34_item)

    for item in (s.get("tabla_34_items") or s.get("septico_tabla_34") or []):
        tabla_34_item = calc_tabla_34_item(item)
        if tabla_34_item:
            tabla_34_items.append(tabla_34_item)

    if personas_diseno == 0:
        unidades_persona = {"hab", "habitante", "habitantes", "persona", "personas", "empleado", "empleados", "visitante", "visitantes"}
        personas_diseno = sum(i["cantidad"] * i.get("factor", 1.0) for i in items if str(i.get("unidad", "")).lower() in unidades_persona)

    qmd_lps = total / 86400
    qmaxd_ld = total * float(criterios["kd"])
    qmaxd_lps = qmaxd_ld / 86400
    qmh_base = criterios.get("qmh_base", "qmax_diario")
    base_ld = qmaxd_ld if qmh_base == "qmax_diario" else total
    qmh_lps = base_ld * float(criterios["kh"]) / 86400

    return {
        "id": s["id"],
        "nombre": s.get("nombre", s["id"]),
        "tipo": s.get("tipo", "suministro"),
        "viviendas": viviendas,
        "uso_residencial": uso_residencial,
        "clasificacion_uso": "residencial" if uso_residencial else "no_residencial",
        "personas_declaradas": personas_decl,
        "personas_diseno": round(personas_diseno, 3),
        "area_solar_m2": s.get("area_solar_m2"),
        "dotacion_residencial_l_hab_dia": dotacion,
        "consumos": items,
        "tabla_34_items": tabla_34_items,
        "consumo_total_l_dia": round(total, 3),
        "qmd_lps": round(qmd_lps, 5),
        "qmax_diario_l_dia": round(qmaxd_ld, 3),
        "qmax_diario_lps": round(qmaxd_lps, 5),
        "qmax_horario_lps": round(qmh_lps, 5),
        "qmax_horario_gpm": round(qmh_lps * LPS_TO_GPM, 3),
        "notas": s.get("notas", ""),
    }


def require_ids(group: dict, suministros: Dict[str, dict], collection: str) -> List[dict]:
    ids = group.get("suministros") or []
    if not ids:
        raise ValueError(f"{collection} {group.get('id')} no contiene suministros")
    missing = [sid for sid in ids if sid not in suministros]
    if missing:
        raise ValueError(f"{collection} {group.get('id')} referencia suministros inexistentes: {missing}")
    return [suministros[sid] for sid in ids]


def calc_cisterna(c: dict, suministros: Dict[str, dict], criterios: dict) -> dict:
    members = require_ids(c, suministros, "cisterna")
    qmd = sum(m["consumo_total_l_dia"] for m in members)
    qmaxd = sum(m["qmax_diario_l_dia"] for m in members)
    viviendas = sum(m["viviendas"] for m in members)
    dias = c.get("dias_abastecimiento", c.get("dias_reserva"))
    criterio_dias = "Entrada del usuario"
    if dias is None:
        if viviendas > 16 and criterios.get("permitir_1_5_dias_mas_16_viviendas"):
            dias = 1.5
            criterio_dias = "R-008 Art. 55: >16 viviendas permite 1.5 días"
        else:
            dias = criterios["dias_cisterna_default"]
            criterio_dias = "R-008 Art. 55: default 2 días"
    dias = float(dias)
    base_calculo = c.get("base_calculo", criterios.get("base_calculo_cisterna_default", "qmd"))
    if base_calculo == "qmax_diario":
        base_l_dia = qmaxd
        base_desc = "Caudal máximo diario"
    else:
        base_calculo = "qmd"
        base_l_dia = qmd
        base_desc = "Caudal medio diario"
    incendio = float(c.get("volumen_incendio_m3") or 0)
    factor_seguridad_diseno = float(c.get("factor_seguridad", criterios.get("factor_seguridad_cisterna_default", 1.0)) or 1.0)
    requerido = ((base_l_dia * dias / 1000) + incendio) * factor_seguridad_diseno

    propuesta = volume_from_dims(c.get("dimension_propuesta", c.get("dimensiones_propuestas")), "cisterna")
    if propuesta is None:
        cfg = deep_merge(criterios["dimension_cisterna"], c.get("dimensionamiento") or {})
        altura = float(cfg.get("altura_util_m", cfg.get("alto_m", 2.0)))
        propuesta = auto_rectangular(requerido, float(cfg["relacion_largo_ancho"]), altura)
        propuesta["borde_libre_m"] = float(cfg.get("borde_libre_m", 0.3))
        propuesta["alto_m"] = propuesta["alto_util_m"]
        fuente_dim = "Auto-dimensionamiento"
    else:
        fuente_dim = "Entrada del usuario"

    volumen_propuesto = float(propuesta.get("volumen_m3") or 0)
    tiempo_llenado_h = float(c.get("tiempo_llenado_h", criterios.get("tiempo_llenado_h_default", 8.0)) or 8.0)
    caudal_llenado_lps = requerido * 1000 / (tiempo_llenado_h * 3600) if tiempo_llenado_h else 0.0
    factor_acometida = float(c.get("factor_acometida", criterios.get("factor_acometida_default", 1.5)) or 1.0)
    return {
        "id": c["id"],
        "nombre": c.get("nombre", c["id"]),
        "suministros": [m["id"] for m in members],
        "consumo_total_l_dia": round(qmd, 3),
        "qmax_diario_l_dia": round(qmaxd, 3),
        "viviendas": viviendas,
        "base_calculo": base_calculo,
        "base_calculo_descripcion": base_desc,
        "dias_abastecimiento": dias,
        "criterio_dias": criterio_dias,
        "volumen_incendio_m3": incendio,
        "factor_seguridad_diseno": factor_seguridad_diseno,
        "volumen_requerido_m3": round(requerido, 3),
        "volumen_requerido_l": volumen_litros(requerido),
        "volumen_requerido_gal": volumen_galones(requerido),
        "dimension_propuesta": add_volume_units(propuesta),
        "fuente_dimension": fuente_dim,
        "cumple": volumen_propuesto + 1e-9 >= requerido,
        "factor_seguridad": factor_seguridad_diseno,
        "factor_cumplimiento": round(volumen_propuesto / requerido, 3) if requerido else None,
        "tiempo_llenado_h": tiempo_llenado_h,
        "caudal_llenado_lps": round(caudal_llenado_lps, 4),
        "factor_acometida": factor_acometida,
        "acometida_aproximada": seleccionar_acometida(caudal_llenado_lps * factor_acometida),
        "rebose_recomendado": seleccionar_rebose(caudal_llenado_lps),
        "opciones_dimensionamiento": opciones_catalogo_guia(requerido, "cisterna", criterios, c),
    }


def septic_table_for_people(people: int, criterios: dict) -> dict:
    people = max(1, int(math.ceil(people)))
    for row in SEPTICO_TABLA:
        if row["min"] <= people <= row["max"]:
            out = deepcopy(row)
            if out.get("compartimientos") == 2:
                out["largo_m"] = round(out["largo_1_m"] + out["largo_2_m"], 2)
            return add_volume_units(out)
    # Escala sobre último rango: 0.30 m3/hab aprox.; dos compartimientos 2/3 + 1/3.
    cfg = criterios["dimension_septico"]
    required = people * 0.30
    dims = auto_rectangular(required, float(cfg["relacion_largo_ancho"]), float(cfg["profundidad_util_m"]), float(cfg.get("camara_aire_m", 0.4)), True)
    dims.update({"min": 101, "max": people, "volumen_m3": round(required, 3)})
    return add_volume_units(dims)


def septic_component(concepto: str, volumen_m3: float) -> dict:
    return add_volume_units({"concepto": concepto, "volumen_m3": round(volumen_m3, 3)})


def tabla_vivienda_referencia(row: Optional[dict], personas: float) -> Optional[dict]:
    if not row:
        return None
    ref = add_volume_units(deepcopy(row))
    compartimientos = int(ref.get("compartimientos") or 1)
    tabla = "Tabla 33" if compartimientos == 2 else "Tabla 32"
    ref.update({
        "tabla": tabla,
        "personas_equivalentes": int(math.ceil(personas)),
        "rango_personas": f"{int(ref.get('min', 1))}-{int(ref.get('max', int(math.ceil(personas))))}",
        "tipo_camara": f"{compartimientos} {'cámara' if compartimientos == 1 else 'cámaras'}",
        "dimensiones": {k: v for k, v in ref.items() if k not in {"min", "max", "tabla", "personas_equivalentes", "rango_personas", "tipo_camara"}},
    })
    return ref


def calc_septico(spt: dict, suministros: Dict[str, dict], criterios: dict) -> dict:
    members = require_ids(spt, suministros, "septico")
    qmd = sum(m["consumo_total_l_dia"] for m in members)
    viviendas = sum(m["viviendas"] for m in members)
    personas_estimadas = sum(m["personas_diseno"] for m in members)
    residenciales = [m for m in members if m.get("uso_residencial")]
    no_residenciales = [m for m in members if not m.get("uso_residencial")]
    if residenciales and no_residenciales:
        clasificacion_uso = "mixto"
    elif residenciales:
        clasificacion_uso = "residencial"
    else:
        clasificacion_uso = "no_residencial"

    factor_ar = float(spt.get("factor_aguas_residuales", criterios["factor_aguas_residuales"]))
    wastewater = qmd * factor_ar
    metodo = spt.get("metodo") or criterios.get("metodo_septico_default") or "max_formula_tabla_r008"
    metodo_calc = metodo
    if metodo_calc == "tabla_r008":
        metodo_calc = "tabla_r008_vivienda"
    if metodo_calc in {"max_formula_tabla_r008", "tabla_r008_contextual", "max_contextual_r008"}:
        metodo_calc = "tabla_r008_contextual"

    dot_sept = float(spt.get("dotacion_aguas_residuales_l_hab_dia", criterios["dotacion_septico_l_hab_dia"]))
    habitantes_eq = max(personas_estimadas, math.ceil(wastewater / dot_sept) if dot_sept else personas_estimadas)
    v_liq = wastewater * float(spt.get("tiempo_retencion_dias", criterios["retencion_septico_dias"])) / 1000
    v_lodos = habitantes_eq * float(spt.get("lodos_l_hab_anio", criterios["lodos_l_hab_anio"])) * float(spt.get("periodo_limpieza_anios", criterios["periodo_limpieza_anios"])) / 1000
    v_formula = v_liq + v_lodos

    row_forced = septic_table_for_people(int(math.ceil(habitantes_eq)), criterios)
    personas_residenciales = sum(m["personas_diseno"] for m in residenciales)
    row_residencial = septic_table_for_people(int(math.ceil(personas_residenciales)), criterios) if personas_residenciales > 0 else None
    v_tabla_residencial = float(row_residencial["volumen_m3"]) if row_residencial else None
    tabla_r008_vivienda_ref = tabla_vivienda_referencia(row_residencial, personas_residenciales) if row_residencial else None

    tabla_34_items = []
    for member in members:
        tabla_34_items.extend(deepcopy(member.get("tabla_34_items") or []))
    for item in (spt.get("tabla_34_items") or spt.get("septico_tabla_34") or []):
        tabla_34_item = calc_tabla_34_item(item)
        if tabla_34_item:
            tabla_34_items.append(tabla_34_item)
    tabla_34_l = sum(float(item.get("volumen_l") or 0) for item in tabla_34_items) or None
    tabla_34_gal = sum(float(item.get("volumen_gal") or 0) for item in tabla_34_items) or None
    v_tabla_34 = (tabla_34_l / L_PER_M3) if tabla_34_l is not None else None

    componentes = [
        septic_component("Volumen para líquidos", v_liq),
        septic_component("Volumen para lodos", v_lodos),
    ]

    dim_base = None
    v_tabla_report = None
    if metodo_calc == "tabla_r008_vivienda":
        v_tabla_forced = float(row_forced["volumen_m3"]) if row_forced else None
        requerido = v_tabla_forced if v_tabla_forced is not None else v_formula
        fuente = "R-008 Tablas 32/33 para cámaras sépticas de viviendas"
        metodo_aplicado = "Tabla 32/33 R-008"
        v_tabla_report = v_tabla_forced
        tabla_r008_vivienda_ref = tabla_vivienda_referencia(row_forced, habitantes_eq) if row_forced else tabla_r008_vivienda_ref
        dim_base = deepcopy(row_forced) if row_forced else None
    elif metodo_calc == "tabla_34":
        if v_tabla_34 is None:
            requerido = v_formula
            fuente = "Fórmula; R-008 Tabla 34 no declarada"
            metodo_aplicado = "Fórmula por uso no residencial sin Tabla 34 declarada"
        else:
            requerido = v_tabla_34
            fuente = "R-008 Tabla 34 para cámaras sépticas de otras edificaciones"
            metodo_aplicado = "Tabla 34 R-008"
    elif metodo_calc == "formula":
        requerido = v_formula
        fuente = "Fórmula: retención hidráulica + acumulación de lodos"
        metodo_aplicado = fuente
    elif metodo_calc == "tabla_r008_contextual":
        if clasificacion_uso == "residencial":
            v_tabla_report = v_tabla_residencial
            requerido = max(v_formula, v_tabla_residencial or 0.0)
            fuente = "Mayor entre fórmula de retención/lodos y Tabla 32/33 R-008 para uso residencial"
            metodo_aplicado = "Mayor entre fórmula y Tabla 32/33 R-008"
            if v_tabla_residencial is not None and v_tabla_residencial >= v_formula:
                dim_base = deepcopy(row_residencial)
        elif clasificacion_uso == "no_residencial":
            if v_tabla_34 is None:
                requerido = v_formula
                fuente = "Fórmula; R-008 Tabla 34 no declarada para uso no residencial"
                metodo_aplicado = "Fórmula por uso no residencial sin Tabla 34 declarada"
            else:
                requerido = max(v_formula, v_tabla_34)
                fuente = "Mayor entre fórmula de retención/lodos y R-008 Tabla 34 para otras edificaciones"
                metodo_aplicado = "Mayor entre fórmula y Tabla 34 R-008"
        else:
            v_tabla_report = v_tabla_residencial
            v_contextual = (v_tabla_residencial or 0.0) + (v_tabla_34 or 0.0)
            requerido = max(v_formula, v_contextual)
            fuente = "Mayor entre fórmula y tablas R-008 aplicables: 32/33 residencial + 34 no residencial"
            metodo_aplicado = "Mayor entre fórmula y tablas R-008 aplicables (32/33 + 34)"
            if v_tabla_residencial is not None and v_contextual >= v_formula and v_tabla_34 is None:
                dim_base = deepcopy(row_residencial)
    else:
        raise ValueError(f"Método de séptico no soportado: {metodo}")

    if v_tabla_report is not None:
        componentes.append(septic_component("Volumen mínimo Tabla 32/33 R-008", v_tabla_report))
    if v_tabla_34 is not None:
        componentes.append(septic_component("Volumen mínimo Tabla 34 R-008", v_tabla_34))

    factor_seguridad_diseno = float(spt.get("factor_seguridad", 1.0) or 1.0)
    requerido *= factor_seguridad_diseno

    propuesta = volume_from_dims(spt.get("dimension_propuesta", spt.get("dimensiones_propuestas")), "septico")
    if propuesta is None:
        if dim_base:
            propuesta = {k: v for k, v in dim_base.items() if k not in {"min", "max"}}
            if propuesta.get("compartimientos") == 2:
                propuesta["largo_m"] = round(propuesta["largo_1_m"] + propuesta["largo_2_m"], 2)
            propuesta["volumen_m3"] = round(float(dim_base["volumen_m3"]), 3)
        else:
            cfg = deep_merge(criterios["dimension_septico"], spt.get("dimensionamiento") or {})
            propuesta = auto_rectangular(requerido, float(cfg["relacion_largo_ancho"]), float(cfg["profundidad_util_m"]), float(cfg.get("camara_aire_m", 0.4)), int(math.ceil(habitantes_eq)) >= 26)
            if "alto_util_m" in propuesta and "profundidad_util_m" not in propuesta:
                propuesta["profundidad_util_m"] = propuesta.pop("alto_util_m")
            propuesta.setdefault("camara_aire_m", float(cfg.get("camara_aire_m", 0.4)))
        fuente_dim = "Auto-dimensionamiento"
    else:
        fuente_dim = "Entrada del usuario"

    volumen_propuesto = float(propuesta.get("volumen_m3") or 0)
    return {
        "id": spt["id"],
        "nombre": spt.get("nombre", spt["id"]),
        "suministros": [m["id"] for m in members],
        "metodo": metodo,
        "metodo_aplicado": metodo_aplicado,
        "fuente": fuente,
        "clasificacion_uso": clasificacion_uso,
        "suministros_residenciales": [m["id"] for m in residenciales],
        "suministros_no_residenciales": [m["id"] for m in no_residenciales],
        "factor_aguas_residuales": factor_ar,
        "consumo_total_l_dia": round(qmd, 3),
        "aguas_residuales_l_dia": round(wastewater, 3),
        "viviendas": viviendas,
        "habitantes_equivalentes": int(math.ceil(habitantes_eq)),
        "habitantes_residenciales": int(math.ceil(personas_residenciales)) if personas_residenciales else 0,
        "componentes": componentes,
        "tabla_r008_vivienda": tabla_r008_vivienda_ref,
        "tabla_34_items": tabla_34_items,
        "volumen_liquidos_m3": round(v_liq, 3),
        "volumen_liquidos_l": volumen_litros(v_liq),
        "volumen_liquidos_gal": volumen_galones(v_liq),
        "volumen_lodos_m3": round(v_lodos, 3),
        "volumen_lodos_l": volumen_litros(v_lodos),
        "volumen_lodos_gal": volumen_galones(v_lodos),
        "volumen_formula_m3": round(v_formula, 3),
        "volumen_formula_l": volumen_litros(v_formula),
        "volumen_formula_gal": volumen_galones(v_formula),
        "volumen_tabla_r008_m3": round(v_tabla_report, 3) if v_tabla_report is not None else None,
        "volumen_tabla_r008_l": volumen_litros(v_tabla_report) if v_tabla_report is not None else None,
        "volumen_tabla_r008_gal": volumen_galones(v_tabla_report) if v_tabla_report is not None else None,
        "volumen_tabla_34_m3": round(v_tabla_34, 3) if v_tabla_34 is not None else None,
        "volumen_tabla_34_l": round(tabla_34_l, 1) if tabla_34_l is not None else None,
        "volumen_tabla_34_gal": round(tabla_34_gal, 1) if tabla_34_gal is not None else None,
        "factor_seguridad_diseno": factor_seguridad_diseno,
        "volumen_requerido_m3": round(requerido, 3),
        "volumen_requerido_l": volumen_litros(requerido),
        "volumen_requerido_gal": volumen_galones(requerido),
        "dimension_propuesta": add_volume_units(propuesta),
        "fuente_dimension": fuente_dim,
        "cumple": volumen_propuesto + 1e-9 >= requerido,
        "factor_seguridad": factor_seguridad_diseno,
        "factor_cumplimiento": round(volumen_propuesto / requerido, 3) if requerido else None,
        "opciones_dimensionamiento": opciones_catalogo_guia(requerido, "septico", criterios, spt),
    }


def collect_referencias_normativas(suministros: list[dict], cisternas: list[dict], septicos: list[dict]) -> list[dict]:
    refs: list[dict] = []
    seen: set[tuple[str, str]] = set()

    def add(referencia: str, uso: str) -> None:
        referencia = fuente_normativa(referencia)
        if not referencia:
            return
        key = (referencia, uso)
        if key in seen:
            return
        seen.add(key)
        refs.append({"referencia": referencia, "uso": uso})

    for suministro in suministros:
        for item in suministro.get("consumos", []):
            add(item.get("fuente", ""), f"Dotación: {item.get('concepto', '')}")

    if cisternas:
        add("R-008 Art. 55", "Volumen mínimo de cisterna por días de abastecimiento")
        add("R-008 Tabla 9", "Rebose recomendado para tanques de almacenamiento")

    for septico in septicos:
        add("R-008 Art. 281", f"Selección de tabla séptica según uso: {septico.get('clasificacion_uso', '')}")
        if septico.get("volumen_tabla_r008_m3") is not None:
            add("R-008 Art. 282", "Dimensionamiento de cámara séptica para viviendas")
            add("R-008 Tablas 32/33", "Cámara séptica para viviendas")
        if septico.get("volumen_tabla_34_m3") is not None:
            add("R-008 Tabla 34", "Cámara séptica para otras edificaciones")
        for item in septico.get("tabla_34_items", []):
            add(item.get("fuente", ""), f"Tabla 34: {item.get('concepto', '')}")

    return refs


def normalize_input(data: dict) -> dict:
    data = deepcopy(data)
    if "project" not in data and "proyecto" in data:
        p = data["proyecto"]
        data["project"] = {
            "id": p.get("id") or (data.get("workspace") or {}).get("project_id"),
            "mode": {"new": "nuevo", "modify": "modificar"}.get((data.get("workspace") or {}).get("modo"), p.get("mode", "nuevo")),
            "titulo_memoria": p.get("titulo_memoria", "Memoria de Cálculo - Cisterna y Sistema Séptico"),
            "nombre": p.get("nombre", ""),
            "cliente": p.get("cliente", ""),
            "empresa": p.get("empresa", ""),
            "ubicacion": p.get("ubicacion", ""),
            "fecha": p.get("fecha", "auto"),
            "tipo_proyecto": p.get("tipo_proyecto", "Sistema de abastecimiento, cisterna y séptico"),
            "normativa": p.get("normativa", "R-008 / MOPC - República Dominicana"),
            "ingeniero": {"nombre": p.get("ingeniero", ""), "codia": p.get("codia", p.get("codigo", ""))},
            "logos": [
                {"url": p.get("logo_cliente_url", ""), "alt": "Cliente"},
                {"url": p.get("logo_empresa_url", ""), "alt": "Empresa"},
            ],
        }

    aliases = {
        "coeficiente_variacion_diaria_kd": "kd",
        "coeficiente_variacion_horaria_kh": "kh",
        "dias_reserva_cisterna": "dias_cisterna_default",
        "base_calculo_cisterna": "base_calculo_cisterna_default",
        "dotacion_aguas_residuales_l_hab_dia": "dotacion_septico_l_hab_dia",
        "tiempo_retencion_septico_dias": "retencion_septico_dias",
        "metodo_septico": "metodo_septico_default",
    }
    criterios = data.get("criterios") or {}
    for old, new in aliases.items():
        if old in criterios and new not in criterios:
            criterios[new] = criterios[old]
    data["criterios"] = criterios
    return data


def validate_input(data: dict) -> None:
    if "project" not in data:
        raise ValueError("Falta project")
    if not data["project"].get("id"):
        raise ValueError("Falta project.id")
    ids = [s.get("id") for s in data.get("suministros", [])]
    if not ids:
        raise ValueError("Debe declarar al menos un suministro")
    if any(not sid for sid in ids):
        raise ValueError("Todo suministro requiere id")
    duplicates = sorted({sid for sid in ids if ids.count(sid) > 1})
    if duplicates:
        raise ValueError(f"IDs de suministros repetidos: {duplicates}")


def calculate(data: dict, cwd: Path, force: bool = False) -> Tuple[dict, Path]:
    data = normalize_input(data)
    validate_input(data)
    project = deepcopy(data["project"])
    project["id"] = slug(project["id"])
    if project.get("fecha", "auto") in (None, "", "auto"):
        project["fecha"] = today_es()
    mode = project.get("mode", "nuevo")
    if mode not in {"nuevo", "modificar"}:
        raise ValueError("project.mode debe ser 'nuevo' o 'modificar'")

    project_dir = cwd / "proyectos" / project["id"]
    if project_dir.exists() and mode == "nuevo" and not force:
        raise FileExistsError(f"Proyecto ya existe: {project_dir}. Use mode='modificar' o --force.")
    project_dir.mkdir(parents=True, exist_ok=True)

    criterios = deep_merge(DEFAULT_CRITERIOS, data.get("criterios") or {})
    suministros_list = [calc_suministro(s, criterios) for s in data.get("suministros", [])]
    suministros = {s["id"]: s for s in suministros_list}
    suministro_ids = [s["id"] for s in suministros_list]

    cisternas_cfg = data.get("cisternas", []) or [{"id": "CIS-01", "nombre": "Cisterna general", "suministros": suministro_ids}]
    septicos_cfg = data.get("septicos", []) or [{"id": "SEP-01", "nombre": "Séptico general", "suministros": suministro_ids, "metodo": criterios.get("metodo_septico_default", "formula")}]
    cisternas = [calc_cisterna(c, suministros, criterios) for c in cisternas_cfg]
    septicos = [calc_septico(s, suministros, criterios) for s in septicos_cfg]

    total_qmd = sum(s["consumo_total_l_dia"] for s in suministros_list)
    total_qmaxd = total_qmd * float(criterios["kd"])
    base_ld = total_qmaxd if criterios.get("qmh_base") == "qmax_diario" else total_qmd
    total_qmh_lps = base_ld * float(criterios["kh"]) / 86400

    referencias_normativas = collect_referencias_normativas(suministros_list, cisternas, septicos)

    resultado = {
        "schema": "san-cisterna-septico.resultado.v1",
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "project": project,
        "criterios": criterios,
        "resumen": {
            "suministros": len(suministros_list),
            "cisternas": len(cisternas),
            "septicos": len(septicos),
            "viviendas": sum(s["viviendas"] for s in suministros_list),
            "habitantes_diseno": round(sum(s["personas_diseno"] for s in suministros_list), 3),
            "consumo_total_l_dia": round(total_qmd, 3),
            "qmd_lps": round(total_qmd / 86400, 5),
            "qmax_diario_l_dia": round(total_qmaxd, 3),
            "qmax_diario_lps": round(total_qmaxd / 86400, 5),
            "qmax_horario_lps": round(total_qmh_lps, 5),
            "qmax_horario_gpm": round(total_qmh_lps * LPS_TO_GPM, 3),
            "volumen_cisternas_requerido_m3": round(sum(c["volumen_requerido_m3"] for c in cisternas), 3),
            "volumen_septicos_requerido_m3": round(sum(s["volumen_requerido_m3"] for s in septicos), 3),
        },
        "suministros": suministros_list,
        "cisternas": cisternas,
        "septicos": septicos,
        "referencias_normativas_usadas": referencias_normativas,
        "observaciones": data.get("observaciones", []),
        "notas_tecnicas": [
            "Cisterna calculada según R-008 Art. 55: consumo medio diario por días de abastecimiento.",
            "Separación mínima recomendada entre cisterna y cámara séptica: 5.00 m.",
            "El sistema séptico debe validarse contra condiciones locales de suelo e infiltración.",
        ],
    }

    input_copy = deepcopy(data)
    input_copy["project"] = project
    (project_dir / "input.json").write_text(json.dumps(input_copy, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (project_dir / "resultado.json").write_text(json.dumps(resultado, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return resultado, project_dir


def main() -> int:
    parser = argparse.ArgumentParser(description="Calcula cisternas y sépticos desde input.json")
    parser.add_argument("--input", required=True, help="Ruta del input.json")
    parser.add_argument("--cwd", default=".", help="Raíz del proyecto; default pwd")
    parser.add_argument("--force", action="store_true", help="Permite sobrescribir proyecto nuevo existente")
    args = parser.parse_args()

    cwd = Path(args.cwd).resolve()
    input_path = Path(args.input)
    if not input_path.is_absolute():
        candidate = cwd / input_path
        input_path = candidate if candidate.exists() else input_path.resolve()
    data = json.loads(input_path.read_text(encoding="utf-8"))
    resultado, project_dir = calculate(data, cwd, force=args.force)
    print(f"OK cálculo: {project_dir / 'resultado.json'}")
    print(json.dumps(resultado["resumen"], ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

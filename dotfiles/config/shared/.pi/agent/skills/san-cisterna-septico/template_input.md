# Formato de entrada — san-cisterna-septico

Archivo recomendado: `input.json` en raíz del proyecto o `proyectos/[id]/input.json`.

## Regla de ubicación

Los scripts usan `pwd` como raíz. Con `project.id = "mi-proyecto"`, se escriben:

```text
proyectos/mi-proyecto/input.json
proyectos/mi-proyecto/resultado.json
proyectos/mi-proyecto/memoria.html
```

## project

| Campo | Requerido | Descripción |
|---|---:|---|
| `id` | Sí | ID de carpeta. |
| `mode` | Sí | `nuevo` o `modificar`. |
| `titulo_memoria` | Sí | Título de portada. |
| `nombre` | Sí | Nombre del proyecto. |
| `cliente` | Sí | Cliente/propietario. |
| `empresa`, `ubicacion`, `fecha`, `tipo_proyecto`, `normativa` | No | Metadatos visibles. |
| `ingeniero.nombre`, `ingeniero.codia` | Sí/No | Firma y CODIA. |
| `logos[]` | No | Lista `{url, alt}`. |

## criterios principales

- `kd`, `kh`, `qmh_base`: caudales de diseño.
- `aplicar_minimo_6_hab_vivienda`: R-008 Art. 310.
- `dias_cisterna_default`: R-008 Art. 55, usual 2 días.
- `metodo_septico_default`: recomendado `max_formula_tabla_r008`; ahora es contextual por tipo de uso.
- `factor_aguas_residuales`, `retencion_septico_dias`, `lodos_l_hab_anio`, `periodo_limpieza_anios`: fórmula séptica.

## suministros[]

Cada suministro es una unidad de demanda: villa, apartamento, edificio, local, área común, restaurante, tienda, oficina, industria, etc.

Campos clave:

| Campo | Uso |
|---|---|
| `tipo` | Ayuda a inferir si es residencial o no residencial. |
| `uso_residencial` | `true` para vivienda/villa/casa/apartamento/residencial; `false` para comercio/oficina/restaurante/tienda/industria. Si se omite, se infiere por `tipo` o `viviendas > 0`. |
| `viviendas`, `personas`, `personas_por_vivienda`, `area_solar_m2` | Base residencial. |
| `dotacion_l_hab_dia` | Si `null`, usa R-008 Tabla 37 por área solar. |
| `consumos[]` / `consumos_adicionales[]` | Ítems por `dotacion_key` o custom. |
| `tipo_edificacion_tabla_34` | Recomendado para no residencial: clave de R-008 Tabla 34 para comparar volumen mínimo séptico. |
| `cantidad_tabla_34`, `factor_tabla_34` | Cantidad del tipo de edificación Tabla 34 y factor opcional. |
| `tabla_34_items[]` | Ítems sépticos no residenciales sin consumo de agua asociado; alternativa/extra al campo recomendado. |

## Fuente en tabla de consumos

La columna **Fuente** solo muestra referencias R-008. Si el ítem es custom o no tiene referencia R-008, queda en blanco.

No usar `fuente: "template"`. Si hay referencia R-008, usar `referencia`; si no, dejar `referencia: ""`.

### Dotación R-008 por `dotacion_key`

```json
{
  "concepto": "Parqueo cubierto",
  "cantidad": 75.5,
  "unidad": "m²",
  "dotacion_key": "parqueo_cubierto"
}
```

### Custom sin R-008

```json
{
  "concepto": "Custom sin R-008",
  "cantidad": 12,
  "unidad": "unidad",
  "dotacion_l_unidad_dia": 35,
  "referencia": ""
}
```

### Custom con referencia R-008

```json
{
  "concepto": "Uso especial documentado",
  "cantidad": 4,
  "unidad": "unidad",
  "dotacion_l_unidad_dia": 9,
  "referencia": "R-008 Tabla 2: referencia custom"
}
```

## Catálogo R-008 Tabla 2 — `dotacion_key`

| Clave | Dotación |
|---|---:|
| `viviendas_250` | 250 L/hab/día |
| `viviendas_300` | 300 L/hab/día |
| `industria_empleado` | 80 L/día·empleado por turno |
| `deposito_empleado` | 80 L/día·empleado por turno |
| `comercio_seco_local_hasta_50` | 500 L/día si área ≤50 m² |
| `comercio_seco_m2_51_100` | 10 L/día·m² |
| `comercio_seco_m2_mayor_100` | 8 L/día·m² |
| `oficinas_m2` | 6 L/día·m² |
| `oficinas_publicas_empleado` | 40 L/día·empleado |
| `oficinas_publicas_visitante` | 1 L/día·visitante |
| `centro_educativo_externo_estudiante` | 40 L/día·estudiante |
| `centro_educativo_semi_interno_estudiante` | 70 L/día·estudiante |
| `centro_educativo_interno_estudiante` | 200 L/día·estudiante |
| `centro_educativo_personal_no_residente` | 50 L/día·persona |
| `centro_educativo_personal_residente` | 200 L/día·persona |
| `hotel_cama` | 250 L/día·cama |
| `motel_cama` | 500 L/día·cama |
| `pension_cama` | 175 L/día·cama |
| `restaurante_local_hasta_40` | 2,000 L/día si área ≤40 m² |
| `restaurante_m2_41_100` | 50 L/día·m² |
| `restaurante_m2_mayor_100` | 40 L/día·m² |
| `cafeteria_local_hasta_30` | 1,500 L/día si área ≤30 m² |
| `cafeteria_m2_31_60` | 60 L/día·m² |
| `cafeteria_m2_61_100` | 50 L/día·m² |
| `cafeteria_m2_mayor_100` | 40 L/día·m² |
| `mercado_m2` | 25 L/día·m² |
| `hospital_cama` | 800 L/día·cama |
| `consultorio` | 500 L/día·consultorio |
| `clinica_dental` | 1,000 L/día·unidad dental |
| `lavanderia_agua_kg` | 40 L/día·kg ropa |
| `lavanderia_seco_kg` | 30 L/día·kg ropa |
| `lavado_auto_automatico` | 12,800 L/día·unidad |
| `lavado_auto_no_automatico` | 8,000 L/día·unidad |
| `estacion_gasolina_bomba` | 300 L/día·bomba |
| `parqueo_cubierto` | 2 L/día·m² |
| `auditorio_asiento` | 3 L/día·asiento |
| `discoteca_m2` | 30 L/día·m² |
| `circo_espectador` | 1 L/día·espectador |
| `estadio_espectador` | 1 L/día·espectador |
| `areas_verdes` | 2 L/día·m² |
| `piscina_recirc` | 10 L/día·m² |
| `piscina_sin_recirc` | 25 L/día·m² |
| `vestidores_piscina` | 30 L/día·m² |

## Dotaciones custom frecuentes sin R-008

Estas claves quedan con Fuente en blanco salvo que el usuario indique `referencia` R-008 explícita:

| Clave | Dotación |
|---|---:|
| `poblacion_flotante_90` | 90 L/persona/día |
| `oficinas_persona_50` | 50 L/persona/día |
| `comedor_puesto_15` | 15 L/puesto/día |
| `limpieza_mantenimiento_1_25` | 1.25 L/m²/día |

## cisternas[]

```json
{
  "id": "CIS-01",
  "nombre": "Cisterna general",
  "suministros": ["V1", "REST-01"],
  "dias_abastecimiento": 2,
  "base_calculo": "qmd",
  "factor_seguridad": 1.0,
  "tiempo_llenado_h": 8,
  "volumen_incendio_m3": 0,
  "dimension_propuesta": null
}
```

Si `dimension_propuesta` es `null`, engine propone dimensiones rectangulares y opciones guía.

## septicos[]

Métodos:

| Método | Uso |
|---|---|
| `max_formula_tabla_r008` | Recomendado. Contextual: residencial usa Tabla 32/33; no residencial usa Tabla 34 si declarada; si no, fórmula; mixto combina tablas aplicables. |
| `tabla_r008_vivienda` | Fuerza Tabla 32/33 para viviendas. |
| `tabla_34` | Fuerza Tabla 34 para otras edificaciones si hay `tabla_34_key`. |
| `formula` | Solo retención hidráulica + lodos. |

```json
{
  "id": "SEP-REST",
  "nombre": "Séptico no residencial Restaurante",
  "suministros": ["REST-01"],
  "metodo": "max_formula_tabla_r008",
  "dimension_propuesta": null
}
```

## Tabla 34 — séptico no residencial

Si el suministro **no** es vivienda/residencial/villa/casa/apartamento, declarar el tipo de edificación de R-008 Tabla 34 en el suministro. El engine compara la fórmula contra el volumen mínimo normativo en m³, litros y galones.

Ejemplo recomendado en suministro:

```json
{
  "id": "REST-01",
  "nombre": "Restaurante",
  "tipo": "restaurante",
  "uso_residencial": false,
  "tipo_edificacion_tabla_34": "restaurante_banos_cocina_asiento",
  "cantidad_tabla_34": 40,
  "factor_tabla_34": 1,
  "consumos": [
    {"concepto": "Área restaurante", "cantidad": 60, "unidad": "m²", "dotacion_key": "restaurante_m2_41_100"}
  ]
}
```

Alternativas compatibles:

```json
{
  "concepto": "Restaurante baños y cocina",
  "cantidad": 40,
  "unidad": "asiento",
  "dotacion_l_unidad_dia": 50,
  "referencia": "",
  "tabla_34_key": "restaurante_banos_cocina_asiento"
}
```

```json
"tabla_34_items": [
  {"concepto": "Iglesia", "cantidad": 120, "tabla_34_key": "iglesia_persona"}
]
```

Claves Tabla 34 disponibles:

- `bares_cliente`
- `campamento_empleado`
- `clinica_medico_persona`, `clinica_administrativo_persona`, `clinica_paciente_persona`
- `escuela_aula_40_estudiantes`, `guarderia_persona`
- `hospital_cama`, `hotel_habitacion`, `motel_habitacion`
- `iglesia_persona`
- `lavadero_carro_servicio`, `drenaje_garaje`, `lavanderia_auto_servicio_maquina`
- `asilo_cama`, `parque_duchas_banos_persona`, `parque_banos_persona`
- `restaurante_banos_cocina_asiento`, `restaurante_lavaplatos_triturador_asiento`, `restaurante_cocina_sin_lavaplatos_asiento`, `restaurante_solo_banos_asiento`
- `restaurante_24h_banos_cocina_asiento`, `restaurante_24h_lavaplatos_triturador_asiento`, `restaurante_comida_rapida_asiento`
- `salon_reuniones_persona`, `salon_baile_persona`, `salon_belleza_estacion`
- `salon_banquetes_cocina_comida`, `salon_banquetes_cocina_banos_comida`

## Compatibilidad

También se acepta estilo referencia:

```json
{
  "proyecto": {"id":"villa-demo", "nombre":"VILLA DEMO"},
  "workspace": {"modo":"new"},
  "criterios": {"metodo_septico":"max_formula_tabla_r008"},
  "suministros": []
}
```

## Salidas

- `resultado.json`: cálculos detallados, `referencias_normativas_usadas`, capacidades en `m³`, `L` y `gal`.
- `memoria.html`: memoria imprimible con tabla “Referencias normativas aplicadas”, capacidad de cisterna/séptico en m³-L-gal, y referencia séptica de Tabla 32/33 o Tabla 34.

## Defaults automáticos

Si `cisternas` está vacío, se crea `CIS-01` con todos los suministros. Si `septicos` está vacío, se crea `SEP-01` con todos los suministros.

# Guía de `input.json` para `san-perdidas`

## Estructuras aceptadas

Estilo actual recomendado:

```json
{
  "project": {"id": "mi-proyecto", "mode": "nuevo", "nombre": "Mi Proyecto"},
  "criterios": {},
  "nodos": [],
  "tramos": []
}
```

Estilo referencia compatible:

```json
{
  "proyecto": {"id": "mi-proyecto", "nombre": "Mi Proyecto"},
  "workspace": {"modo": "new", "project_id": "mi-proyecto"},
  "criterios": {},
  "nodos": [],
  "tramos": [],
  "catalogo_bombas": [{"capacidad": "1 HP", "hp": 1.0}]
}
```

Alias soportados:

| Actual | Referencia compatible |
|---|---|
| `project` | `proyecto` |
| `project.mode: nuevo/modificar` | `workspace.modo: new/modify` |
| `elevacion_m` | `altura_m` |
| `nombre` | `descripcion` |
| `aparatos` | `grupos_aparatos` |
| `diametros_mm` | `diametros_comerciales_mm` |
| `coeficiente_hazen_default` | `c_hazen_default` |
| `presion_critica_default_mca` | `presion_punto_critico_mca` |

## `project` / `proyecto`

- `id`: carpeta bajo `proyectos/`.
- `mode`: `nuevo` o `modificar`.
- `nombre`, `cliente`, `empresa`, `ubicacion`, `fecha`, `tipo_proyecto`, `normativa`, `ingeniero`, `logos`: metadatos de memoria.
- También acepta `logo_cliente_url`, `logo_empresa_url`, `codia`, `codigo` del estilo referencia.

## `criterios`

Campos principales:

| Campo | Default | Uso |
|---|---:|---|
| `metodo_accesorios` | `longitud_equivalente` | `longitud_equivalente`, `k` o `mixto`. |
| `nodo_cisterna` | `null` | ID fuente si se quiere forzar. |
| `nodos_criticos` | `[]` | Lista explícita de puntos críticos. |
| `material_default` | `ppr` | Material si tramo no lo declara. |
| `velocidad_min_m_s` | `0.6` | Velocidad mínima objetivo. |
| `velocidad_max_m_s` | `2.5` | Velocidad máxima objetivo. |
| `presion_critica_default_mca` | `5.7` | Presión mínima estándar según Tabla 4. |
| `presion_punto_critico_fluxometro_mca` | `10.55` | 15 psi expresado en mca para nodo fluxómetro. |
| `factor_simultaneidad_global` | `1.0` | Factor global aplicado a demanda terminal si nodo no declara factor propio. |
| `mostrar_simultaneidad` | `true` | Mantiene reporte de factores/demanda auditada en salidas. |
| `margen_seguridad_tipo` | `porcentaje_sobre_adt_sin_margen` | `porcentaje_sobre_perdidas`, `porcentaje_sobre_adt_sin_margen` o `fijo_mca`. |
| `margen_seguridad_porcentaje` | `0.15` | Margen decimal de ADT. |
| `margen_seguridad_mca` | `null` | Usado con `fijo_mca`. |
| `margen_seleccion_bomba_porcentaje` | `0.20` | Margen adicional sobre HP hidráulico para seleccionar HP comercial. |
| `criterio_presion_minima` | `tabla_4` | `tabla_4`, `art_32` o `custom`. |
| `presion_aparato_tanque_mca` | `7.03` | 10 psi para aparatos con tanque si se adopta Art. 32. |
| `verificar_presion_maxima` | `true` | Verifica presión máxima preliminar en nodos. |
| `presion_maxima_red_mca` | `42.2` | Límite preliminar de presión máxima en red. |
| `eficiencia_bomba` | `0.65` | Eficiencia para HP requerido. |
| `peso_especifico_agua_n_m3` | `9800` | Peso específico del agua. |
| `diametro_modo` | `hidraulico` | `hidraulico` usa diámetro interno; `ppr_nominal` convierte nominal PPR por SDR. |
| `ppr_serie_default` | `SDR11` | Serie usada cuando `diametro_modo=ppr_nominal`. |
| `diametros_mm` | `[13,...,150]` | Diámetros comerciales. |
| `bombas_hp` | `[0.5,...,50]` | Capacidades comerciales si no se usa `catalogo_bombas`. |
| `evaluar_npsh` | `false` | Activa verificación preliminar NPSH. |
| `nodo_bomba` | `null` | ID de nodo bomba para ruta de succión/NPSH. |
| `presion_atmosferica_mca` | `10.33` | Cabeza atmosférica usada en NPSHa. |
| `presion_vapor_mca` | `0.32` | Cabeza de vapor usada en NPSHa. |
| `npsh_requerido_m` | `null` | NPSHr declarado por fabricante. |
| `margen_npsh_m` | `1.0` | Margen adicional sobre NPSHr. |

### Catálogos nuevos

- `criterios.catalogos.ppr_sdr`: catálogo nominal exterior → diámetro interno por serie PPR.
- `criterios.catalogos.accesorios_le_d` y `accesorios_k`: pueden incluir accesorios de succión como `filtro_succion` y `valvula_pie`.

## `nodos`

Punto estándar:

```json
{
  "id": "PC01",
  "nombre": "Punto crítico",
  "tipo": "critico",
  "elevacion_m": 8.0,
  "presion_min_mca": null,
  "demanda_lps": 1.0,
  "factor_simultaneidad": 0.85,
  "aparatos": {}
}
```

Fluxómetro opcional:

```json
{
  "id": "FL01",
  "tipo": "critico",
  "tipo_equipo": "fluxometro",
  "elevacion_m": 6.0,
  "demanda_lps": 0.4
}
```

Equipo especial con presión propia:

```json
{
  "id": "EQ01",
  "tipo": "critico",
  "equipo_presion_mca": 22.0,
  "elevacion_m": 4.0,
  "demanda_lps": 0.2
}
```

Prioridad de presión en nodo crítico:

1. `presion_min_mca` o `equipo_presion_mca`.
2. Si `tipo_equipo="fluxometro"` o `usa_fluxometro=true`, usar presión propia de fluxómetro.
3. Si `criterio_presion_minima=art_32`, usar `presion_aparato_tanque_mca` para aparatos con tanque.
4. Si no, usar `presion_critica_default_mca`.

Demanda por grupos estilo referencia:

```json
"grupos_aparatos": [
  {"grupo": "g_010", "cantidad": 3, "factor_simultaneidad": 0.8},
  {"grupo": "g_020", "cantidad": 4, "factor_simultaneidad": 0.8}
]
```

## `tramos`

```json
{
  "id": "T01",
  "nombre": "Impulsión o succión",
  "desde": "CIS",
  "hasta": "PC01",
  "longitud_m": 50,
  "material": "ppr",
  "tipo_tramo": "succion",
  "diametro_mm": 40,
  "ppr_serie": "SDR11",
  "accesorios": {"filtro_succion": 1, "valvula_pie": 1, "codo_90": 2}
}
```

Accesorios como lista de objetos:

```json
"accesorios": [
  {"tipo": "codo_90", "cantidad": 2},
  {"tipo": "equipo_especial", "cantidad": 1, "perdida_m": 2.5}
]
```

Reglas:

- `desde` y `hasta` deben existir en `nodos`.
- `longitud_m` debe ser mayor que cero.
- Si `diametro_mm` es `null` o falta, se selecciona automáticamente por velocidad.
- Si `diametro_mm` se declara, se respeta y se emite advertencia si velocidad no cumple.
- `diametro_modo=ppr_nominal` interpreta `diametro_mm` como nominal exterior PPR y usa `ppr_serie` / `ppr_serie_default` para convertir a diámetro hidráulico.
- `tipo_tramo=succion` ayuda a documentar tramos previos a bomba y accesorios de succión.

## `catalogo_bombas`

Solo capacidad:

```json
"catalogo_bombas": [
  {"capacidad": "1 HP", "hp": 1.0},
  {"capacidad": "2 HP", "hp": 2.0}
]
```

## Ejemplos rápidos

### Simultaneidad por nodo

```json
{
  "criterios": {"factor_simultaneidad_global": 0.5},
  "nodos": [
    {"id": "A", "tipo": "critico", "demanda_lps": 1.0},
    {"id": "B", "tipo": "critico", "demanda_lps": 1.0, "factor_simultaneidad": 0.25}
  ]
}
```

### PPR nominal por SDR

```json
{
  "criterios": {
    "diametro_modo": "ppr_nominal",
    "ppr_serie_default": "SDR11",
    "catalogos": {"ppr_sdr": {"SDR11": {"40": 32.72}}}
  },
  "tramos": [{"id": "T1", "desde": "A", "hasta": "B", "longitud_m": 12, "diametro_mm": 40}]
}
```

### Succión y NPSH

```json
{
  "criterios": {
    "evaluar_npsh": true,
    "nodo_bomba": "BOMBA",
    "npsh_requerido_m": 3.0,
    "margen_npsh_m": 1.0
  },
  "tramos": [
    {"id": "TS", "desde": "CIS", "hasta": "BOMBA", "longitud_m": 8, "diametro_mm": 40, "tipo_tramo": "succion", "accesorios": {"filtro_succion": 1, "valvula_pie": 1}}
  ]
}
```

## Ejecución

```bash
python3 .pi/skills/san-perdidas/scripts/run.py --input input.json
```

Forzar recreación si `mode=nuevo`:

```bash
python3 .pi/skills/san-perdidas/scripts/run.py --input input.json --force
```

# Metodología técnica `san-perdidas`

## Referencias de criterio

- `referencia/MDC - HIDRÁULICO Y PÉRDIDAS.pdf`: estructura de memoria, velocidad `0.6–2.5 m/s`, Hazen-Williams, ADT, HP y presentación de resultados.
- `referencia/hidrosanitario/`: modelo previo de nodos/tramos y motor MVP de pérdidas/bomba.

## Caudales

La demanda se declara en nodos terminales:

```json
{"id": "PC01", "tipo": "critico", "demanda_lps": 1.0}
```

También se acepta `aparatos`:

```json
{"aparatos": {"lps_010": 4, "lps_020": {"cantidad": 2, "factor": 0.8}}}
```

Demanda base de nodo:

```text
Qn = demanda_lps + Σ(cantidad × factor × caudal_unitario_lps)
```

## Simultaneidad

Demanda terminal auditada:

```text
Qn = (demanda_lps + Σ aparatos + Σ grupos) × factor_simultaneidad
```

- Si nodo declara `factor_simultaneidad`, prevalece.
- Si no, usa `criterios.factor_simultaneidad_global`.
- Caudal de tramo = suma de demandas simultáneas aguas abajo.

## Velocidad

```text
V = Q / A
A = πD² / 4
```

- `Q` en m³/s.
- `D` en m.
- Rango objetivo: `0.6–2.5 m/s`.

## Hazen-Williams

```text
hf = 10.674 × L × Q^1.852 / (C^1.852 × D^4.871)
```

- `hf`: pérdida en m.
- `L`: longitud en m.
- `Q`: caudal en m³/s.
- `C`: coeficiente Hazen-Williams.
- `D`: diámetro interno en m.

Coeficientes iniciales:

| Material | C |
|---|---:|
| PPR | 150 |
| PVC | 140 |
| Cobre | 130 |
| Acero | 120 |
| Hierro | 110 |

## Accesorios

La skill soporta tres modos:

| `metodo_accesorios` | Criterio |
|---|---|
| `longitud_equivalente` | Convierte accesorios a longitud equivalente y calcula Hazen-Williams. |
| `k` | Usa `ha = ΣK × V²/(2g)`. |
| `mixto` | Combina longitud equivalente, K y pérdida fija. |

También se permite pérdida fija:

```json
{"tipo": "equipo_especial", "cantidad": 1, "perdida_m": 2.5}
```

### Longitud equivalente

Cada accesorio aporta `Le/D`. La longitud equivalente es:

```text
Le = (Le/D) × D × cantidad
```

Luego se calcula pérdida con Hazen-Williams usando `Le`.

### Coeficiente K

```text
ha = ΣK × V² / (2g)
```

## Diámetro PPR

- `diametro_modo=hidraulico`: interpreta `diametro_mm` como diámetro interno.
- `diametro_modo=ppr_nominal`: interpreta `diametro_mm` como diámetro nominal exterior PPR y convierte a diámetro interno con `catalogos.ppr_sdr`.
- `ppr_serie` por tramo sobrescribe `ppr_serie_default`.
- Si catálogo no tiene serie/diámetro, cálculo cae a diámetro declarado y emite advertencia.

## ADT

Para cada ruta cisterna → punto crítico:

```text
ADT = He + Hpc + Hf + Ha + Hs
```

- `He`: diferencia positiva de elevación entre cisterna y punto crítico.
- `Hpc`: presión mínima en punto crítico.
- `Hf`: pérdidas por fricción.
- `Ha`: pérdidas por accesorios.
- `Hs`: margen de seguridad fijo o porcentaje.

### Criterio de presión mínima

- `tabla_4`: usa `presion_critica_default_mca` para punto estándar.
- `art_32`: usa `presion_aparato_tanque_mca` para aparatos con tanque.
- `custom`: respeta `presion_min_mca` / `equipo_presion_mca` cuando nodo lo declara.
- Fluxómetros mantienen presión propia por `presion_punto_critico_fluxometro_mca`.

## Potencia de bomba

```text
HP = Q × ADT × γ / (η × 745.7)
```

- `Q`: caudal total del sistema en m³/s.
- `ADT`: altura dinámica total crítica en m.
- `γ`: peso específico del agua.
- `η`: eficiencia de bomba.

## Selección de bomba con margen

Selección comercial:

```text
HP_selección = HP × (1 + margen_seleccion_bomba_porcentaje)
```

- `HP` = HP hidráulico calculado.
- `HP_selección` = mínimo comercial a cubrir antes de redondear a catálogo.
- Compra final requiere curva del fabricante para punto `Q @ ADT`.

## Tanque hidroneumático

Dimensionamiento opcional según referencia MDC:

```text
V_L = (180 × (Q_lps × 100) / 20) × 0.264
V_gal = V_L / 3.78541
```

- `Q_lps`: caudal base de bomba; usa `tanque_hidroneumatico.caudal_lps`, luego `criterios.caudal_bomba_lps`, luego caudal de ruta crítica.
- `factor_extraccion`: se reporta para auditoría; valor por defecto `0.38` según ejemplo de referencia.
- `catalogo`: lista de tanques con `modelo`, `gal` y/o `litros`.
- Selección: menor tanque con `litros >= V_L`; si ninguno cumple, usa múltiplos del mayor tanque.
- Compra final requiere confirmar presión de trabajo, precarga y curva/ajustes del fabricante.

Ejemplo:

```json
"tanque_hidroneumatico": {
  "calcular": true,
  "factor_extraccion": 0.38,
  "catalogo": [{"modelo": "WM-6 / WM0300", "gal": 300, "litros": 1136}]
}
```

## Succión y NPSH

Verificación preliminar para cisterna abierta:

```text
NPSHa = Patm + Ptanque + Hs_estática - Hvapor - Hperdidas_succión
Hs_estática = Z_agua_mín - Z_eje_bomba
```

- `Patm`: `npsh.presion_atmosferica_mca`; si no se declara y hay `npsh.altitud_m`, se calcula con atmósfera estándar; si no, usa `criterios.presion_atmosferica_mca`.
- `Ptanque`: `npsh.presion_tanque_mca`; para cisterna abierta usar `0`.
- `Z_agua_mín`: `npsh.nivel_minimo_agua_m`; si falta, usa elevación del nodo fuente.
- `Z_eje_bomba`: `npsh.eje_bomba_m`; si falta, usa elevación del nodo bomba.
- `Hvapor`: `npsh.presion_vapor_mca`; si no se declara y hay `npsh.temperatura_agua_c`, se calcula por aproximación Tetens; si no, usa `criterios.presion_vapor_mca`.
- `Hperdidas_succión`: pérdidas en tramos desde fuente hasta `nodo_bomba`.

Condición:

- `Hs_estática > 0`: `succion_inundada`.
- `Hs_estática = 0`: `succion_al_mismo_nivel`.
- `Hs_estática < 0`: `succion_negativa`.

Cumplimiento:

```text
NPSHa >= NPSHr + margen_npsh_m
```

- Si falta `npsh_requerido_m`, estado = `No evaluable`; falta NPSH requerido de la bomba según curva del fabricante.
- Aun con `npsh_requerido_m`, verificación sigue preliminar. Confirmar con la selección de la bomba antes de comprar.

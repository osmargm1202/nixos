---
name: san-perdidas
description: Use when creating Dominican Spanish hydraulic-loss and pump-pressure memorias for potable-water systems with cisterns, nodes, pipe runs, elevations, terminal demands, fittings, critical points, ADT, and pump HP capacity selection.
---

# San Pérdidas

## Propósito

Generar memoria de cálculo de pérdidas hidráulicas en sistemas de agua potable desde cisterna/fuente hasta puntos críticos. Calcula caudales acumulados, diámetros, velocidades, pérdidas por fricción, pérdidas por accesorios, ADT, potencia de bomba seleccionada por capacidad HP comercial y tanque hidroneumático opcional.

## Flujo obligatorio

1. Trabajar desde el `pwd` del proyecto.
2. Preparar `input.json` según `template_input.json` o `template_input.md`.
3. Definir `project.id` y `project.mode`:
   - `nuevo`: crea `proyectos/[id]/`; falla si ya existe salvo `--force`.
   - `modificar`: usa `proyectos/[id]/`; crea si no existe.
4. Ejecutar cálculo y HTML:
   ```bash
   python3 .pi/skills/san-perdidas/scripts/run.py --input input.json
   ```

Salidas esperadas:

```text
proyectos/[id]/
  input_perdidas.json
  resultado_perdidas.json
  memoria_perdidas.html
```

## Modelo mental

- **Nodo** = cisterna, punto de distribución o punto de consumo.
- **Tramo** = tubería dirigida `desde` → `hasta` con longitud, material, diámetro opcional y accesorios.
- **Punto crítico** = nodo marcado `tipo: critico` o `critico: true`; requiere presión mínima.
- **Bomba** = seleccionada solo por potencia comercial HP, no por marca/modelo/curva.
- **Tanque hidroneumático** = dimensionamiento opcional por fórmula de referencia MDC y selección por catálogo/múltiplos.

## Criterios principales

- Entrada compatible con estilo actual (`project`, `elevacion_m`, `nombre`) y estilo referencia (`proyecto`, `workspace`, `altura_m`, `descripcion`, `grupos_aparatos`, `catalogo_bombas`).
- Simultaneidad: `factor_simultaneidad_global` y `nodos[].factor_simultaneidad`; factores por grupo/aparato se conservan.
- Presión mínima: `criterio_presion_minima=tabla_4|art_32|custom`; fluxómetros usan presión propia.
- Equipos especiales: declarar `equipo_presion_mca` o `presion_min_mca`.
- Velocidad admisible: `0.6–2.5 m/s`.
- Diámetro automático: menor diámetro comercial que cumpla velocidad; diámetro declarado se respeta y se advierte si no cumple.
- PPR: `diametro_modo=hidraulico|ppr_nominal`; modo nominal usa `ppr_serie` o `ppr_serie_default`.
- Fricción: Hazen-Williams.
- Accesorios: `metodo_accesorios` puede ser `longitud_equivalente`, `k` o `mixto`; HTML incluye detalle por tramo.
- Margen ADT: `porcentaje_sobre_perdidas`, `porcentaje_sobre_adt_sin_margen` o `fijo_mca`.
- Bomba: HP hidráulico + `margen_seleccion_bomba_porcentaje` para elegir HP comercial; HTML muestra punto `GPM @ ADT`.
- Tanque hidroneumático: si `tanque_hidroneumatico.calcular=true`, calcula `V_L=(180×(Q_lps×100)/20)×0.264`, usa `criterios.caudal_bomba_lps` o caudal crítico, y selecciona menor tanque de `catalogo` o múltiplos del mayor.
- Succión/NPSH: `evaluar_npsh=true`, `nodo_bomba` y tramos `tipo_tramo=succion`; usar `criterios.npsh.nivel_minimo_agua_m` y `criterios.npsh.eje_bomba_m` para `Hs=Z_agua_min-Z_bomba`; sin `npsh_requerido_m` reporta `No evaluable` y exige confirmar NPSHr con selección de bomba antes de comprar.
- Presión máxima: verificación preliminar contra `presion_maxima_red_mca`.

## Comandos útiles

Ejecutar ejemplo:

```bash
python3 .pi/skills/san-perdidas/scripts/run.py \
  --input .pi/skills/san-perdidas/examples/input.example.json \
  --force
```

Solo cálculo:

```bash
python3 .pi/skills/san-perdidas/scripts/calculate.py --input input.json
```

Solo render:

```bash
python3 .pi/skills/san-perdidas/scripts/render_html.py --project-id mi-proyecto
```

## Errores comunes

| Error | Corrección |
|---|---|
| Falta nodo cisterna/fuente | Declarar exactamente un nodo `tipo: cisterna`, `fuente` o `entrada`. |
| Sin nodo crítico | Marcar al menos un nodo `tipo: critico` o `critico: true`. |
| Tramo referencia nodo inexistente | Revisar `desde` y `hasta`. |
| Red con ciclo o malla | Convertir a árbol dirigido para cálculo inicial. |
| Velocidad fuera de rango | Ajustar diámetro declarado o dejar auto-dimensionamiento. |
| HP requerido supera catálogo | Ampliar `criterios.bombas_hp` o `catalogo_bombas`. |
| Input referencia falla por nombres | Usar alias compatibles: `altura_m`, `descripcion`, `proyecto`, `workspace`. |
| Punto con fluxómetro | Declarar `tipo_equipo: "fluxometro"` o `usa_fluxometro: true`. |
| Equipo con presión especial | Declarar `equipo_presion_mca` o `presion_min_mca`. |
| NPSH solicitado sin nodo bomba | Definir `criterios.nodo_bomba` y ruta de succión coherente. |
| PPR nominal sin catálogo SDR | Declarar `catalogos.ppr_sdr` o usar `diametro_modo=hidraulico`. |
| Tanque hidroneumático sin selección | Agregar `tanque_hidroneumatico.catalogo` con `modelo`, `gal` y/o `litros`. |

## Referencia detallada

Leer `references/metodologia.md` cuando necesites fórmulas, catálogos iniciales o criterios técnicos.

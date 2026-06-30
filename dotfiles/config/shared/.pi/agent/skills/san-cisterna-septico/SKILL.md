---
name: san-cisterna-septico
description: Use when creating Dominican Spanish memorias de cálculo for potable-water cisterns and septic tanks from project inputs, supplies, villas, apartments, buildings, grouped cisterns, grouped septic systems, or existing project revisions.
---

# San Cisterna Séptico

## Propósito

Generar memorias de cálculo de cisterna de agua potable y cámara séptica para uno o varios **suministros** (apartamento, villa, edificio, local o grupo). El flujo produce `resultado.json` primero y luego renderiza `memoria.html` desde ese resultado.

## Flujo obligatorio

1. Trabajar siempre desde el `pwd` del proyecto.
2. Preparar `input.json` según `template_input.json` o `template_input.md`.
3. Definir `project.id` y `project.mode`:
   - `nuevo`: crea `proyectos/[id]/`; falla si ya existe salvo `--force`.
   - `modificar`: usa `proyectos/[id]/`; crea si no existe.
4. Ejecutar cálculo:
   ```bash
   python3 .pi/skills/san-cisterna-septico/scripts/calculate.py --input input.json
   ```
5. Renderizar HTML:
   ```bash
   python3 .pi/skills/san-cisterna-septico/scripts/render_html.py --project-id ID
   ```
6. O ejecutar ambos:
   ```bash
   python3 .pi/skills/san-cisterna-septico/scripts/run.py --input input.json
   ```

Salidas esperadas:

```text
proyectos/[id]/
  input.json
  resultado.json
  memoria.html
```

## Archivos de la skill

| Archivo | Uso |
|---|---|
| `template_input.json` | Plantilla JSON editable para proyecto real. |
| `template_input.md` | Guía humana de campos, agrupaciones y ejemplos. |
| `README.md` | Guía rápida para humanos y compatibilidad con input de referencia. |
| `examples/input.example.json` | Ejemplo tipo memoria de agua potable con `dotacion_key`. |
| `calc.py` | Wrapper compatible con `--root`, `--mode`, `--overwrite`. |
| `scripts/calculate.py` | Engine de cálculo: suministros, consumos, caudales, cisternas, sépticos, dimensiones. |
| `scripts/render_html.py` | Engine HTML: portada estilo `referencia/base.html`, teoría, tablas, resultados, conclusiones. |
| `scripts/run.py` | Orquestador cálculo + render. |
| `references/normativa.md` | Resumen R-008 y criterios usados. |

## Modelo mental

- **Suministro** = unidad fuente de demanda: villa, apartamento, edificio, local, área común.
- **Cisterna** = grupo de uno o varios suministros.
- **Séptico** = grupo de uno o varios suministros.
- Un suministro puede alimentar una cisterna individual, una cisterna común, o ambos si el usuario lo modela como grupos distintos.
- Lo mismo aplica a sépticos: individual, global, por subconjuntos o mixto.

## Criterios principales

Ver `references/normativa.md` para detalle. Defaults del engine:

- Dotación residencial por área solar según R-008 Tabla 37; si no hay área, 250 L/hab/día.
- Población residencial: si hay `viviendas`, se respeta mínimo de 6 hab/vivienda cuando `criterios.aplicar_minimo_6_hab_vivienda=true`.
- `dotacion_key` permite usar catálogo de dotaciones R-008 Tabla 2 y custom frecuentes; custom sin referencia R-008 deja `Fuente` en blanco.
- Cisterna: R-008 Art. 55, volumen mínimo = consumo base × días de abastecimiento. `base_calculo` puede ser `qmd` o `qmax_diario`; soporta `factor_seguridad`, `tiempo_llenado_h`, acometida aproximada y rebose recomendado.
- Séptico: `max_formula_tabla_r008` es contextual. Residencial/vivienda/villa/casa/apartamento usa Tabla 32/33 y reporta personas equivalentes + una/dos cámaras; no residencial usa Tabla 34 si hay `tipo_edificacion_tabla_34`/`cantidad_tabla_34` o `tabla_34_key`; si no hay Tabla 34 declarada usa fórmula hidráulica+lodos; mixto combina tablas aplicables.
- Si no se declaran cisternas o sépticos, se generan `CIS-01` y `SEP-01` con todos los suministros.
- Separación recomendada cisterna-séptico: 5 m.
- Acepta input propio (`project`) y estilo referencia (`proyecto` + `workspace`) sin romper compatibilidad.
- Incluye catálogo guía de dimensiones (`opciones_dimensionamiento`) para cisternas y sépticos; sale en la memoria y no reemplaza `dimension_propuesta`.
- La memoria incluye `referencias_normativas_usadas`, tabla “Referencias normativas aplicadas” y capacidades de cisterna/séptico en m³, litros y galones.

## Comandos útiles

Crear desde plantilla:

```bash
cp .pi/skills/san-cisterna-septico/template_input.json input.json
python3 .pi/skills/san-cisterna-septico/scripts/run.py --input input.json --force
```

Ejecutar ejemplo compatible:

```bash
python3 .pi/skills/san-cisterna-septico/calc.py \
  --input .pi/skills/san-cisterna-septico/examples/input.example.json \
  --root "$(pwd)" \
  --mode new \
  --overwrite
```

Modificar proyecto existente:

```bash
python3 .pi/skills/san-cisterna-septico/scripts/run.py --input proyectos/mi-proyecto/input.json
```

Renderizar sin recalcular:

```bash
python3 .pi/skills/san-cisterna-septico/scripts/render_html.py --project-id mi-proyecto
```

## Errores comunes

| Error | Corrección |
|---|---|
| IDs repetidos en `suministros` | Cada suministro necesita `id` único. |
| Grupo referencia suministro inexistente | Revisar `cisternas[].suministros` y `septicos[].suministros`. |
| Proyecto existente con `mode=nuevo` | Cambiar a `modificar` o usar `--force`. |
| Dimensiones propuestas menores al volumen requerido | Ajustar `dimension_propuesta` o dejar auto-dimensionamiento. |
| HTML sin logos | Verificar URLs o usar rutas relativas accesibles desde `memoria.html`. |

# san-cisterna-septico

Skill para generar memoria de cálculo sanitaria de cisterna y cámara séptica desde datos principales de entrada.

## Qué calcula

- Dotación de agua por suministro.
- Caudal medio diario, máximo diario y máximo horario.
- Volumen de cisterna por grupos de suministros.
- Caudal de llenado, acometida aproximada y rebose recomendado.
- Volumen de cámara séptica por fórmula, Tabla 32/33 residencial, Tabla 34 no residencial, o método contextual R-008.
- Dimensiones propuestas, cumplimiento, capacidades en m³/L/gal, `resultado.json` y `memoria.html`.

## Entrada compatible

La skill acepta dos estilos:

1. Estilo propio actual: `project`, `criterios`, `suministros`, `cisternas`, `septicos`.
2. Estilo referencia: `proyecto`, `workspace`, `criterios`, `suministros`, `cisternas`, `septicos`.

El estilo propio sigue siendo el recomendado para proyectos nuevos.

## Ejecución rápida

```bash
python3 .pi/skills/san-cisterna-septico/scripts/run.py \
  --input .pi/skills/san-cisterna-septico/template_input.json \
  --force
```

Wrapper compatible:

```bash
python3 .pi/skills/san-cisterna-septico/calc.py \
  --input .pi/skills/san-cisterna-septico/examples/input.example.json \
  --root "$(pwd)" \
  --mode new \
  --overwrite
```

## Salidas

```text
proyectos/[id]/input.json
proyectos/[id]/resultado.json
proyectos/[id]/memoria.html
```

## Mejoras integradas desde referencia

- Catálogo `dotacion_key` para dotaciones comunes.
- Ejemplos en `examples/`.
- Cisternas/sépticos por defecto si no se declaran.
- `base_calculo` para cisterna: `qmd` o `qmax_diario`.
- `factor_seguridad`, `tiempo_llenado_h`, `factor_acometida`.
- Acometida aproximada por velocidad máxima 2.5 m/s.
- Rebose recomendado según R-008 Tabla 9.
- Método séptico `max_formula_tabla_r008` contextual: residencial → Tabla 32/33; no residencial → Tabla 34 si declarada; si no, fórmula.
- Catálogo ampliado R-008 Tabla 2 y Tabla 34.
- Columna `Fuente` solo muestra referencias R-008; custom sin norma queda en blanco.
- Tabla “Referencias normativas aplicadas” en memoria.

## Clasificación para séptico

Declarar `uso_residencial=true` en villas/casas/apartamentos/residencial. Declarar `uso_residencial=false` en comercio, oficina, tienda, restaurante, industria, etc. Si se omite, el engine infiere por `tipo` o por `viviendas > 0`.

Para otras edificaciones usar `tipo_edificacion_tabla_34` y `cantidad_tabla_34` en el suministro cuando aplique, por ejemplo `restaurante_banos_cocina_asiento`. También se acepta `tabla_34_key` en consumos o `tabla_34_items[]`.

## Nota técnica

La memoria no sustituye verificación de infiltración, pozo filtrante/campo de absorción, revisión estructural, permisos ni aprobación de autoridad competente.

## Catálogo guía de dimensiones

Cada cisterna y séptico incluye `opciones_dimensionamiento`: hasta 3 opciones del catálogo que cumplen el volumen requerido. La memoria las imprime como **Opciones guía de dimensiones**. No reemplazan `dimension_propuesta`; sirven para mostrar alternativas constructivas preliminares.

Puede ajustarse `criterios.cantidad_opciones_guia` o declarar `catalogo_guia` dentro de una cisterna/séptico.

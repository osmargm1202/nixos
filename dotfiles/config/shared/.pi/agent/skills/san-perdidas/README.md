# san-perdidas

Skill para calcular pérdidas hidráulicas y presión/capacidad de bomba en sistemas de agua potable desde cisterna hasta puntos críticos.

## Qué calcula

- Caudal acumulado por tramos desde demandas en nodos terminales.
- Selección automática de diámetro por velocidad `0.6–2.5 m/s`.
- Velocidad por tramo.
- Pérdidas por fricción con Hazen-Williams.
- Pérdidas por accesorios mediante longitud equivalente, coeficiente K o pérdida fija.
- Rutas desde cisterna hasta puntos críticos explícitos o marcados por tipo.
- Presión por punto: default `5.7 mca`, fluxómetro `10.55 mca` (15 psi), Art. 32 o valor especial por nodo.
- ADT por ruta: `He + Hpc + Hf + Ha + Hs`.
- HP hidráulico, margen de selección y bomba comercial seleccionada por HP/capacidad.
- Revisión preliminar de simultaneidad, NPSH y presión máxima.
- Unidades de salida en L/s, GPM, mca, pies, psi, HP y W.
- `resultado_perdidas.json` y `memoria_perdidas.html`.

## Ejecución rápida

```bash
python3 .pi/skills/san-perdidas/scripts/run.py \
  --input .pi/skills/san-perdidas/examples/input.example.json \
  --force
```

## Entrada

Ver:

- `template_input.json`
- `template_input.md`

Acepta estilo actual (`project`, `elevacion_m`, `nombre`) y estilo referencia (`proyecto`, `workspace`, `altura_m`, `descripcion`, `grupos_aparatos`, accesorios como lista de objetos y `catalogo_bombas`).

## Salidas

```text
proyectos/[id]/input_perdidas.json
proyectos/[id]/resultado_perdidas.json
proyectos/[id]/memoria_perdidas.html
```

## Auditoría hidráulica

Memoria renderiza criterio de presión mínima, unidades Hazen-Williams, factor de simultaneidad, detalle de accesorios, margen de selección de bomba, NPSH preliminar y presión máxima. Bomba sigue siendo selección por HP comercial; compra requiere curva del fabricante para punto `Q @ ADT`.

## Nota técnica

Selección de bomba es solo por potencia HP comercial. No sustituye curva de fabricante, revisión de NPSH, cavitación, golpe de ariete, balance en mallas ni verificación de instalación eléctrica.

Para fluxómetros usar `tipo_equipo: "fluxometro"`; para equipos especiales usar `equipo_presion_mca` o `presion_min_mca`.

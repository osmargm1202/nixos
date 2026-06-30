# Referencia normativa y criterios de cálculo

Base: Reglamento R-008 dominicano para instalaciones sanitarias en edificaciones y ejemplos en `referencia/`.

## Dotaciones de agua potable

R-008 Tabla 2 — consumos por tipo/uso:

| Uso | Dotación |
|---|---:|
| Viviendas | 250–300 L/hab/día |
| Industrias | 80 L/día·empleado por turno de 8 h + proceso |
| Comercio seco / casa abasto / pulpería / carnicería / pescadería | 500 L/día si área ≤50 m²; 10 L/día·m² de 51–100 m²; 8 L/día·m² si >100 m² |
| Depósitos de materiales/equipos/artículos manufacturados | 80 L/día·empleado por turno |
| Oficinas comerciales/ventas | 6 L/día·m² |
| Oficinas públicas | 40 L/día·empleado + 1 L/día·visitante |
| Centros educativos | 40 externo; 70 semi-interno; 200 interno L/día·estudiante; 50 personal no residente; 200 personal residente |
| Hoteles / moteles / pensiones | 250 / 500 / 175 L/día·cama |
| Restaurantes | 2,000 L/día si área ≤40 m²; 50 L/día·m² de 41–100 m²; 40 L/día·m² si >100 m² |
| Cafeterías/bares | 1,500 L/día si área ≤30 m²; 60 L/día·m² de 31–60 m²; 50 L/día·m² de 61–100 m²; 40 L/día·m² si >100 m² |
| Mercados | 25 L/día·m² |
| Hospitales/clínicas | 800 L/día·cama |
| Consultorios médicos | 500 L/día·consultorio |
| Clínicas dentales | 1,000 L/día·unidad dental |
| Lavanderías | 40 L/día·kg con agua; 30 L/día·kg en seco |
| Lavaderos de autos | 12,800 L/día·unidad automática; 8,000 L/día·unidad no automática |
| Estaciones de gasolina | 300 L/día·bomba |
| Garajes/estacionamientos cubiertos | 2 L/día·m² |
| Cines/teatros/auditorios | 3 L/día·asiento |
| Discotecas/casinos/salas de baile | 30 L/día·m² |
| Circos/hipódromos/parques atracciones | 1 L/día·espectador + animales si aplica |
| Estadios/velódromos/autódromos | 1 L/día·espectador |
| Áreas verdes/parques/jardines | 2 L/día·m² |
| Piscinas | 10 L/día·m² con recirculación; 25 sin recirculación; 30 L/día·m² vestidores/anexos |

R-008 Tabla 37 — uso doméstico por área solar:

| Área solar | Dotación |
|---|---:|
| Hasta 150 m² | 250 L/hab/día |
| 151–250 m² | 275 L/hab/día |
| 251–400 m² | 300 L/hab/día |
| 401–500 m² | 325 L/hab/día |
| 501–600 m² | 350 L/hab/día |
| 601–700 m² | 375 L/hab/día |
| 701 m² o más | 400 L/hab/día |

## Población residencial

R-008 Art. 310: considerar al menos 6 habitantes por vivienda. El engine permite desactivar este mínimo si se requiere población exacta.

La skill clasifica séptico como:

- `residencial`: `uso_residencial=true`, `viviendas > 0`, o `tipo` vivienda/villa/casa/apartamento/residencial.
- `no_residencial`: comercio, oficina, tienda, restaurante, industria, etc.
- `mixto`: mezcla de suministros residenciales y no residenciales.

## Caudales

- Consumo medio diario: `QMD = Σ(cantidad × dotación)` en L/día.
- Caudal medio: `q = QMD / 86400` en L/s.
- Caudal máximo diario: `QmaxD = QMD × Kd`.
- Caudal máximo horario: default `QMH = QmaxD × Kh / 86400`; configurable con `qmh_base`.
- GPM: `L/s × 15.8503`.

## Cisterna

R-008 Art. 54: proyectar cisterna cuando edificio tenga más de 2 pisos, supere 7 m, o red pública no sea permanente/no tenga presión suficiente.

R-008 Art. 55: volumen mínimo = consumo de 2 días del caudal medio diario. Si edificación tiene más de 16 viviendas o equivalente, puede reducirse a 1.5 días. Incluir incendio si aplica.

```text
V_cisterna_m3 = (QMD_grupo × días_abastecimiento / 1000) + volumen_incendio_m3
```

R-008 Tabla 9 se usa para rebose recomendado.

## Séptico

R-008 Art. 273: cámaras de uno o dos compartimientos según cantidad de personas; rectangular, largo 2 a 3 veces ancho, altura útil 1.00–1.60 m.

R-008 Art. 274: en dos compartimientos, entrada ocupa al menos 2/3 del volumen; secundario no mayor de 1/3.

R-008 Art. 281: capacidad según personas y tipo de desecho. **Viviendas usan Tablas 32/33; otros tipos de edificaciones usan Tabla 34.**

### Tabla 32 — un compartimiento

La memoria reporta la referencia normativa con personas equivalentes, rango aplicado, volumen útil en m³/L/gal y una cámara.

| Personas | Volumen útil m³ | Largo m | Ancho m | Prof. útil m | Aire m |
|---:|---:|---:|---:|---:|---:|
| 1–2 | 0.80 | 1.20 | 0.60 | 1.20 | 0.30 |
| 3–4 | 1.50 | 1.60 | 0.80 | 1.20 | 0.30 |
| 5–7 | 2.10 | 1.95 | 0.90 | 1.20 | 0.30 |
| 8–10 | 3.00 | 2.30 | 1.10 | 1.20 | 0.30 |
| 11–15 | 4.50 | 2.90 | 1.30 | 1.20 | 0.30 |
| 16–20 | 6.00 | 3.10 | 1.50 | 1.30 | 0.30 |
| 21–25 | 7.50 | 3.40 | 1.70 | 1.30 | 0.30 |

### Tabla 33 — dos compartimientos

La memoria reporta dos cámaras, largo de primera/segunda cámara, volumen útil en m³/L/gal y personas equivalentes.

| Personas | Vol. útil m³ | Largo 1era m | Largo 2da m | Ancho m | Prof. útil m | Aire m |
|---:|---:|---:|---:|---:|---:|---:|
| 26–30 | 9.00 | 2.45 | 1.20 | 1.70 | 1.50 | 0.40 |
| 31–35 | 10.50 | 2.75 | 1.30 | 1.80 | 1.50 | 0.40 |
| 36–40 | 12.00 | 2.80 | 1.35 | 2.00 | 1.50 | 0.40 |
| 41–50 | 15.00 | 3.15 | 1.55 | 2.20 | 1.50 | 0.40 |
| 51–60 | 18.00 | 3.25 | 1.60 | 2.40 | 1.60 | 0.40 |
| 61–70 | 21.00 | 3.50 | 1.70 | 2.60 | 1.60 | 0.40 |
| 71–80 | 24.00 | 3.85 | 1.85 | 2.70 | 1.60 | 0.40 |
| 81–90 | 27.00 | 4.20 | 2.00 | 2.80 | 1.60 | 0.40 |
| 91–100 | 30.00 | 4.30 | 2.10 | 3.00 | 1.60 | 0.40 |

### Tabla 34 — otras edificaciones

La forma recomendada es declarar `tipo_edificacion_tabla_34` y `cantidad_tabla_34` en el suministro no residencial. También se soporta `tabla_34_key` en consumos o `tabla_34_items[]` para casos especiales. La memoria reporta m³/L/gal.

| Clave | Capacidad mínima |
|---|---:|
| `bares_cliente` | 34 L / 9 gal por espacio cliente |
| `campamento_empleado` | 113.6 L / 30 gal por empleado |
| `clinica_medico_persona` | 283.9 L / 75 gal por persona |
| `clinica_administrativo_persona` | 75.7 L / 20 gal por persona |
| `clinica_paciente_persona` | 37.9 L / 10 gal por persona |
| `escuela_aula_40_estudiantes` | 2,000 L / 528 gal por aula |
| `guarderia_persona` | 91 L / 24 gal por persona |
| `hospital_cama` | 757 L / 200 gal por cama |
| `hotel_habitacion` | 378.5 L / 100 gal por habitación |
| `motel_habitacion` | 756 L / 200 gal por habitación |
| `iglesia_persona` | 11.4 L / 3 gal por persona |
| `lavadero_carro_servicio` | 189.3 L / 50 gal por unidad servicio |
| `drenaje_garaje` | 378.5 L / 100 gal por drenaje |
| `restaurante_banos_cocina_asiento` | 113.6 L / 30 gal por asiento |
| `restaurante_solo_banos_asiento` | 79.5 L / 21 gal por asiento |
| `restaurante_comida_rapida_asiento` | 56.8 L / 15 gal por asiento |
| `salon_reuniones_persona` | 7.6 L / 2 gal por persona |
| `salon_baile_persona` | 11.4 L / 3 gal por persona |
| `salon_belleza_estacion` | 529.9 L / 140 gal por estación |

Ver `template_input.md` para lista completa de claves.

## Fórmula séptica

```text
Q_AR = QMD × factor_aguas_residuales
V_liquidos = Q_AR × tiempo_retencion_dias / 1000
V_lodos = habitantes_equivalentes × lodos_L_hab_anio × periodo_limpieza_anios / 1000
V_formula = V_liquidos + V_lodos
```

Defaults: factor aguas residuales 0.80, retención 1.5 días, lodos 40 L/hab·año, limpieza cada 2 años.

## Método contextual recomendado

`max_formula_tabla_r008` ahora aplica R-008 según clasificación:

- Residencial: `max(V_formula, Tabla 32/33)`.
- No residencial con `tabla_34_key`: `max(V_formula, Tabla 34)`.
- No residencial sin `tabla_34_key`: `V_formula` y memoria indica que no se declaró Tabla 34.
- Mixto: compara fórmula contra suma de mínimos aplicables (32/33 residencial + 34 no residencial declarado).

## Catálogo `dotacion_key`

El engine incluye claves estables para todos los usos de R-008 Tabla 2 listados arriba, más Tabla 37 doméstica por área solar.

Claves custom frecuentes sin fuente R-008 automática: `poblacion_flotante_90`, `oficinas_persona_50`, `comedor_puesto_15`, `limpieza_mantenimiento_1_25`. Si no se especifica `referencia` R-008, la columna Fuente queda en blanco.

## Acometida y rebose

Para cisternas se calcula caudal de llenado:

```text
q_llenado = V_cisterna / tiempo_llenado
q_acometida = q_llenado × factor_acometida
```

La acometida aproximada se selecciona por velocidad máxima 2.5 m/s entre diámetros comerciales. El rebose se selecciona con R-008 Tabla 9.

## Catálogo guía de dimensiones

La lista de opciones de cisterna/séptico es guía constructiva preliminar. El volumen requerido calculado manda. La dimensión final debe validarse contra arquitectura, estructura, niveles, operación, ubicación y permisos.

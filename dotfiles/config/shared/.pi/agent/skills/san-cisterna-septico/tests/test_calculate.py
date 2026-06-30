import importlib.util
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "calculate.py"
spec = importlib.util.spec_from_file_location("san_calc", MODULE_PATH)
san_calc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(san_calc)

RENDER_PATH = Path(__file__).resolve().parents[1] / "scripts" / "render_html.py"
render_spec = importlib.util.spec_from_file_location("san_render", RENDER_PATH)
san_render = importlib.util.module_from_spec(render_spec)
render_spec.loader.exec_module(san_render)


def base_project(project_id="test-proj"):
    return {
        "project": {
            "id": project_id,
            "mode": "nuevo",
            "titulo_memoria": "Memoria",
            "nombre": "Proyecto Test",
            "cliente": "Cliente",
            "empresa": "ORGM",
            "ubicacion": "RD",
            "fecha": "auto",
            "ingeniero": {"nombre": "Ing. Test", "codia": "CODIA-1"},
        }
    }


class CalculateFeatureTests(unittest.TestCase):
    def test_reference_style_input_is_accepted(self):
        with TemporaryDirectory() as tmp:
            data = {
                "proyecto": {"id": "ref-style", "nombre": "Ref", "cliente": "Cliente", "ingeniero": "Ing", "codia": "CODIA-1"},
                "workspace": {"modo": "new"},
                "criterios": {
                    "coeficiente_variacion_diaria_kd": 1.5,
                    "coeficiente_variacion_horaria_kh": 2.0,
                    "dias_reserva_cisterna": 2,
                    "base_calculo_cisterna": "qmd",
                    "metodo_septico": "max_formula_tabla_r008",
                },
                "suministros": [{"id": "V-01", "nombre": "Villa", "personas": 6, "dotacion_residencial_key": "viviendas_250"}],
            }

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)

            self.assertEqual(resultado["project"]["id"], "ref-style")
            self.assertEqual(resultado["resumen"]["consumo_total_l_dia"], 1500.0)
            self.assertEqual(resultado["septicos"][0]["metodo"], "max_formula_tabla_r008")

    def test_dotacion_key_consumos_and_default_groups(self):
        with TemporaryDirectory() as tmp:
            data = base_project("dotaciones")
            data.update({
                "criterios": {"metodo_septico_default": "max_formula_tabla_r008"},
                "suministros": [{
                    "id": "ALM-01",
                    "nombre": "Almacén",
                    "tipo": "almacen",
                    "consumos": [
                        {"concepto": "Habitantes", "cantidad": 1, "unidad": "hab", "dotacion_key": "viviendas_250"},
                        {"concepto": "Población flotante", "cantidad": 20, "unidad": "personas", "dotacion_key": "poblacion_flotante_90"},
                        {"concepto": "Parqueo", "cantidad": 272, "unidad": "m2", "dotacion_key": "parqueo_cubierto"},
                    ],
                }],
            })

            resultado, project_dir = san_calc.calculate(data, Path(tmp), force=True)

            suministro = resultado["suministros"][0]
            self.assertEqual(suministro["consumo_total_l_dia"], 2594.0)
            self.assertEqual(len(resultado["cisternas"]), 1)
            self.assertEqual(resultado["cisternas"][0]["id"], "CIS-01")
            self.assertEqual(len(resultado["septicos"]), 1)
            self.assertEqual(resultado["septicos"][0]["id"], "SEP-01")
            self.assertIn("resultado.json", str(project_dir / "resultado.json"))

    def test_cisterna_supports_qmax_base_factor_acometida_and_rebose(self):
        with TemporaryDirectory() as tmp:
            data = base_project("cisterna-qmax")
            data.update({
                "criterios": {"kd": 1.5, "kh": 2.0},
                "suministros": [{"id": "V1", "nombre": "Villa", "personas": 1, "dotacion_l_hab_dia": 250}],
                "cisternas": [{
                    "id": "C1",
                    "nombre": "Cisterna",
                    "suministros": ["V1"],
                    "dias_reserva": 2,
                    "base_calculo": "qmax_diario",
                    "factor_seguridad": 1.05,
                    "tiempo_llenado_h": 8,
                    "factor_acometida": 1.5,
                }],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["V1"], "metodo": "formula"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)

            cis = resultado["cisternas"][0]
            self.assertEqual(cis["base_calculo"], "qmax_diario")
            self.assertEqual(cis["volumen_requerido_m3"], 0.788)
            self.assertEqual(cis["factor_seguridad"], 1.05)
            self.assertGreater(cis["caudal_llenado_lps"], 0)
            self.assertGreaterEqual(cis["acometida_aproximada"]["diametro_pulg"], 0.75)
            self.assertEqual(cis["rebose_recomendado"]["diametro_rebose_pulg"], '2"')

    def test_dimension_catalog_guidance_is_output_and_rendered(self):
        with TemporaryDirectory() as tmp:
            data = base_project("catalogo-guia")
            data.update({
                "suministros": [{"id": "V1", "nombre": "Villa", "personas": 6, "dotacion_l_hab_dia": 250}],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["V1"], "dimension_propuesta": {"largo_m": 10, "ancho_m": 10, "alto_util_m": 1}}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["V1"], "metodo": "formula", "dimension_propuesta": {"largo_m": 10, "ancho_m": 10, "profundidad_util_m": 1}}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)
            cis = resultado["cisternas"][0]
            sep = resultado["septicos"][0]
            html = san_render.render(resultado)

            self.assertEqual(cis["fuente_dimension"], "Entrada del usuario")
            self.assertGreaterEqual(len(cis["opciones_dimensionamiento"]), 1)
            self.assertGreaterEqual(cis["opciones_dimensionamiento"][0]["volumen_m3"], cis["volumen_requerido_m3"])
            self.assertGreaterEqual(len(sep["opciones_dimensionamiento"]), 1)
            self.assertGreaterEqual(sep["opciones_dimensionamiento"][0]["volumen_m3"], sep["volumen_requerido_m3"])
            self.assertIn("Opciones guía", html)

    def test_septico_max_formula_tabla_uses_larger_value(self):
        with TemporaryDirectory() as tmp:
            data = base_project("septico-max")
            data.update({
                "suministros": [{"id": "V1", "nombre": "Villa", "tipo": "villa", "personas": 6, "dotacion_l_hab_dia": 250}],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["V1"]}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["V1"], "metodo": "max_formula_tabla_r008"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)

            sep = resultado["septicos"][0]
            # Fórmula: 1500*0.8*1.5/1000 + 6*40*2/1000 = 2.28 m3; tabla 5-7 = 2.10 m3
            self.assertEqual(sep["clasificacion_uso"], "residencial")
            self.assertEqual(sep["volumen_formula_m3"], 2.28)
            self.assertEqual(sep["volumen_tabla_r008_m3"], 2.1)
            self.assertEqual(sep["volumen_requerido_m3"], 2.28)
            self.assertEqual(sep["metodo_aplicado"], "Mayor entre fórmula y Tabla 32/33 R-008")

    def test_fuente_prefers_r008_reference_or_blank(self):
        with TemporaryDirectory() as tmp:
            data = base_project("fuentes")
            data.update({
                "suministros": [{
                    "id": "L1",
                    "nombre": "Local",
                    "tipo": "local",
                    "consumos": [
                        {"concepto": "Parqueo", "cantidad": 10, "unidad": "m²", "dotacion_key": "parqueo_cubierto", "fuente": "template"},
                        {"concepto": "Población flotante", "cantidad": 2, "unidad": "persona", "dotacion_key": "poblacion_flotante_90"},
                        {"concepto": "Custom sin norma", "cantidad": 3, "unidad": "unidad", "dotacion_l_unidad_dia": 7},
                        {"concepto": "Custom con norma", "cantidad": 4, "unidad": "unidad", "dotacion_l_unidad_dia": 9, "referencia": "R-008 Tabla 2: referencia custom"},
                    ],
                }],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["L1"]}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["L1"], "metodo": "formula"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)

            fuentes = [item["fuente"] for item in resultado["suministros"][0]["consumos"]]
            self.assertEqual(fuentes[0], "R-008 Tabla 2: garajes y estacionamientos cubiertos 2 L/día·m²")
            self.assertEqual(fuentes[1], "")
            self.assertEqual(fuentes[2], "")
            self.assertEqual(fuentes[3], "R-008 Tabla 2: referencia custom")
            self.assertNotIn("template", fuentes)

    def test_non_residential_contextual_septic_uses_formula_without_table_34(self):
        with TemporaryDirectory() as tmp:
            data = base_project("septico-no-res")
            data.update({
                "suministros": [{
                    "id": "T1",
                    "nombre": "Tienda",
                    "tipo": "tienda",
                    "consumos": [
                        {"concepto": "Personal", "cantidad": 20, "unidad": "persona", "dotacion_key": "oficinas_persona_50"},
                        {"concepto": "Visitantes", "cantidad": 20, "unidad": "persona", "dotacion_key": "poblacion_flotante_90"},
                        {"concepto": "Parqueo", "cantidad": 75.5, "unidad": "m²", "dotacion_key": "parqueo_cubierto"},
                    ],
                }],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["T1"]}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["T1"], "metodo": "max_formula_tabla_r008"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)

            sep = resultado["septicos"][0]
            self.assertEqual(sep["clasificacion_uso"], "no_residencial")
            self.assertIsNone(sep["volumen_tabla_r008_m3"])
            self.assertIsNone(sep["volumen_tabla_34_m3"])
            self.assertEqual(sep["volumen_requerido_m3"], sep["volumen_formula_m3"])
            self.assertEqual(sep["metodo_aplicado"], "Fórmula por uso no residencial sin Tabla 34 declarada")

    def test_non_residential_contextual_septic_uses_table_34_when_declared(self):
        with TemporaryDirectory() as tmp:
            data = base_project("septico-tabla34")
            data.update({
                "suministros": [{
                    "id": "R1",
                    "nombre": "Restaurante",
                    "tipo": "restaurante",
                    "consumos": [
                        {
                            "concepto": "Restaurante baños y cocina",
                            "cantidad": 10,
                            "unidad": "asiento",
                            "dotacion_l_unidad_dia": 50,
                            "tabla_34_key": "restaurante_banos_cocina_asiento",
                        }
                    ],
                }],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["R1"]}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["R1"], "metodo": "max_formula_tabla_r008"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)

            sep = resultado["septicos"][0]
            self.assertEqual(sep["clasificacion_uso"], "no_residencial")
            self.assertEqual(sep["volumen_formula_m3"], 0.76)
            self.assertEqual(sep["volumen_tabla_34_m3"], 1.136)
            self.assertEqual(sep["volumen_requerido_m3"], 1.136)
            self.assertIn("R-008 Tabla 34", sep["fuente"])
            self.assertEqual(sep["tabla_34_items"][0]["fuente"], "R-008 Tabla 34: restaurantes - baños y cocina 113.6 L/asiento")

    def test_dotacion_catalog_includes_fuller_r008_table_2_keys(self):
        checks = {
            "comercio_seco_local_hasta_50": (500.0, "local"),
            "centro_educativo_interno_estudiante": (200.0, "estudiante"),
            "restaurante_m2_41_100": (50.0, "m²"),
            "cafeteria_m2_31_60": (60.0, "m²"),
            "lavado_auto_automatico": (12800.0, "unidad de lavado"),
            "discoteca_m2": (30.0, "m²"),
        }
        for key, expected in checks.items():
            with self.subTest(key=key):
                dotacion, unidad, fuente = san_calc.dotacion_por_key(key)
                self.assertEqual((dotacion, unidad), expected)
                self.assertIn("R-008 Tabla 2", fuente)

    def test_render_includes_only_applied_normative_references(self):
        with TemporaryDirectory() as tmp:
            data = base_project("referencias-usadas")
            data.update({
                "suministros": [{
                    "id": "R1",
                    "nombre": "Restaurante",
                    "tipo": "restaurante",
                    "consumos": [
                        {"concepto": "Parqueo", "cantidad": 10, "unidad": "m²", "dotacion_key": "parqueo_cubierto"},
                        {"concepto": "Custom", "cantidad": 1, "unidad": "unidad", "dotacion_l_unidad_dia": 99},
                    ],
                }],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["R1"]}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["R1"], "metodo": "formula"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)
            html = san_render.render(resultado)

            referencias = resultado["referencias_normativas_usadas"]
            self.assertTrue(any(ref["referencia"].startswith("R-008 Tabla 2") for ref in referencias))
            self.assertTrue(any(ref["referencia"] == "R-008 Art. 55" for ref in referencias))
            self.assertIn("Referencias normativas aplicadas", html)
            self.assertIn("R-008 Tabla 2", html)
            self.assertNotIn("Custom sin norma", html)

    def test_templates_document_custom_dotation_and_table_34(self):
        skill_dir = Path(__file__).resolve().parents[1]
        template_json = (skill_dir / "template_input.json").read_text(encoding="utf-8")
        template_md = (skill_dir / "template_input.md").read_text(encoding="utf-8")
        normativa_md = (skill_dir / "references" / "normativa.md").read_text(encoding="utf-8")

        self.assertIn("dotacion_l_unidad_dia", template_json)
        self.assertIn('"referencia": ""', template_json)
        self.assertIn("tipo_edificacion_tabla_34", template_json)
        self.assertIn("cantidad_tabla_34", template_json)
        self.assertIn("restaurante_banos_cocina_asiento", template_json)
        self.assertIn("comercio_seco_local_hasta_50", template_md)
        self.assertIn("centro_educativo_interno_estudiante", template_md)
        self.assertIn("Custom sin R-008", template_md)
        self.assertIn("Tabla 34", normativa_md)
        self.assertNotIn('"fuente": "Criterio de memoria"', template_json)

    def test_auto_septic_dimensions_render_depth(self):
        with TemporaryDirectory() as tmp:
            data = base_project("septico-depth")
            data.update({
                "suministros": [{"id": "L1", "nombre": "Local", "tipo": "local", "consumos": [{"concepto": "Uso", "cantidad": 1, "unidad": "unidad", "dotacion_l_unidad_dia": 99}]}],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["L1"]}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["L1"], "metodo": "formula"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)
            sep_dim = resultado["septicos"][0]["dimension_propuesta"]
            html = san_render.render(resultado)

            self.assertIn("profundidad_util_m", sep_dim)
            self.assertNotIn("× — m", html)

    def test_render_septic_shows_contextual_classification_and_table_34(self):
        with TemporaryDirectory() as tmp:
            data = base_project("render-tabla34")
            data.update({
                "suministros": [{
                    "id": "R1",
                    "nombre": "Restaurante",
                    "tipo": "restaurante",
                    "consumos": [{"concepto": "Restaurante baños y cocina", "cantidad": 10, "unidad": "asiento", "dotacion_l_unidad_dia": 50, "tabla_34_key": "restaurante_banos_cocina_asiento"}],
                }],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["R1"]}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["R1"], "metodo": "max_formula_tabla_r008"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)
            html = san_render.render(resultado)

            self.assertIn("Clasificación de uso", html)
            self.assertIn("no_residencial", html)
            self.assertIn("Volumen Tabla 34", html)
            self.assertIn("1.14 m³", html)

    def test_cisternas_and_septicos_report_liters_and_gallons(self):
        with TemporaryDirectory() as tmp:
            data = base_project("volumen-unidades")
            data.update({
                "suministros": [{"id": "V1", "nombre": "Villa", "tipo": "villa", "personas": 6, "dotacion_l_hab_dia": 250}],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["V1"], "dimension_propuesta": {"largo_m": 2, "ancho_m": 2, "alto_util_m": 1}}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["V1"], "metodo": "formula", "dimension_propuesta": {"largo_m": 2, "ancho_m": 2, "profundidad_util_m": 1}}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)
            cis = resultado["cisternas"][0]
            sep = resultado["septicos"][0]
            html = san_render.render(resultado)

            self.assertEqual(cis["volumen_requerido_l"], 3000.0)
            self.assertAlmostEqual(cis["dimension_propuesta"]["volumen_gal"], 1056.7)
            self.assertEqual(sep["volumen_requerido_l"], 2280.0)
            self.assertAlmostEqual(sep["dimension_propuesta"]["volumen_gal"], 1056.7)
            self.assertIn("3,000 L", html)
            self.assertIn("2,280 L", html)

    def test_supply_level_table_34_building_type_sets_minimum(self):
        with TemporaryDirectory() as tmp:
            data = base_project("tipo-edificacion-tabla34")
            data.update({
                "suministros": [{
                    "id": "R1",
                    "nombre": "Restaurante",
                    "tipo": "restaurante",
                    "uso_residencial": False,
                    "tipo_edificacion_tabla_34": "restaurante_banos_cocina_asiento",
                    "cantidad_tabla_34": 10,
                    "consumos": [{"concepto": "Área restaurante", "cantidad": 10, "unidad": "asiento", "dotacion_l_unidad_dia": 50}],
                }],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["R1"]}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["R1"], "metodo": "max_formula_tabla_r008"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)
            sep = resultado["septicos"][0]
            item = sep["tabla_34_items"][0]
            html = san_render.render(resultado)

            self.assertEqual(sep["volumen_tabla_34_l"], 1136.0)
            self.assertEqual(item["tipo_edificacion_tabla_34"], "restaurante_banos_cocina_asiento")
            self.assertEqual(item["volumen_gal_unidad"], 30.0)
            self.assertIn("Tipo edificación Tabla 34", html)
            self.assertIn("Restaurante", html)
            self.assertIn("1,136 L", html)

    def test_residential_septic_reports_table_reference_people_and_chambers(self):
        with TemporaryDirectory() as tmp:
            data = base_project("tabla-vivienda-camaras")
            data.update({
                "suministros": [{"id": "V1", "nombre": "Villas", "tipo": "villa", "personas": 40, "dotacion_l_hab_dia": 250}],
                "cisternas": [{"id": "C1", "nombre": "Cisterna", "suministros": ["V1"]}],
                "septicos": [{"id": "S1", "nombre": "Séptico", "suministros": ["V1"], "metodo": "max_formula_tabla_r008"}],
            })

            resultado, _ = san_calc.calculate(data, Path(tmp), force=True)
            ref = resultado["septicos"][0]["tabla_r008_vivienda"]
            html = san_render.render(resultado)

            self.assertEqual(ref["personas_equivalentes"], 40)
            self.assertEqual(ref["tabla"], "Tabla 33")
            self.assertEqual(ref["compartimientos"], 2)
            self.assertEqual(ref["volumen_l"], 12000.0)
            self.assertAlmostEqual(ref["volumen_gal"], 3170.1)
            self.assertIn("Tabla 33", html)
            self.assertIn("2 cámaras", html)
            self.assertIn("12,000 L", html)


if __name__ == "__main__":
    unittest.main()

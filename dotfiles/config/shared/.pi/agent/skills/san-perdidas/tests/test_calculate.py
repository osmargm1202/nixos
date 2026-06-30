import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
CALC_PATH = SKILL_DIR / "scripts" / "calculate.py"
RUN_PATH = SKILL_DIR / "scripts" / "run.py"
TEMPLATE_PATH = SKILL_DIR / "template_input.json"
EXAMPLE_PATH = SKILL_DIR / "examples" / "input.example.json"
REFERENCE_INPUT_PATH = SKILL_DIR / "tests" / "fixtures" / "reference_input.json"


def load_calculate():
    spec = importlib.util.spec_from_file_location("san_perdidas_calculate", CALC_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class SanPerdidasCalculateTests(unittest.TestCase):
    def run_calc(self, payload, *, root=None):
        calc = load_calculate()
        if root is None:
            tmp = tempfile.TemporaryDirectory()
            self.addCleanup(tmp.cleanup)
            root_path = Path(tmp.name)
        else:
            root_path = Path(root)
        input_path = root_path / "input.json"
        input_path.write_text(json.dumps(payload), encoding="utf-8")
        result = calc.run_calculation(input_path, root_path)
        return root_path, result

    def base_payload(self):
        return {
            "project": {"id": "demo", "mode": "nuevo", "nombre": "Demo Perdidas"},
            "nodos": [
                {"id": "CIS", "nombre": "Cisterna", "tipo": "cisterna", "elevacion_m": -2.0},
                {"id": "P1", "nombre": "Punto crítico", "tipo": "critico", "elevacion_m": 8.0, "demanda_lps": 1.0},
            ],
            "tramos": [
                {"id": "T1", "nombre": "Impulsión", "desde": "CIS", "hasta": "P1", "longitud_m": 50, "accesorios": {"codo_90": 2}},
            ],
        }

    def test_linear_system_generates_result_json(self):
        root, result = self.run_calc(self.base_payload())

        self.assertEqual(result["project"]["id"], "demo")
        self.assertEqual(result["resumen"]["ruta_critica"], "P1")
        self.assertGreater(result["resumen"]["adt_critica_mca"], 0)
        self.assertTrue((root / "proyectos" / "demo" / "input_perdidas.json").exists())
        self.assertTrue((root / "proyectos" / "demo" / "resultado_perdidas.json").exists())

    def test_validation_rejects_bad_networks(self):
        cases = []
        duplicate = self.base_payload()
        duplicate["nodos"].append({"id": "P1", "tipo": "critico", "elevacion_m": 9})
        cases.append((duplicate, "Nodo repetido"))

        no_source = self.base_payload()
        no_source["nodos"][0]["tipo"] = "distribucion"
        cases.append((no_source, "un nodo fuente"))

        no_critical = self.base_payload()
        no_critical["nodos"][1]["tipo"] = "consumo"
        no_critical["nodos"][1]["critico"] = False
        cases.append((no_critical, "nodo crítico"))

        missing_node = self.base_payload()
        missing_node["tramos"][0]["hasta"] = "NOPE"
        cases.append((missing_node, "no existe"))

        cycle = self.base_payload()
        cycle["tramos"].append({"id": "T2", "desde": "P1", "hasta": "CIS", "longitud_m": 1})
        cases.append((cycle, "ciclo"))

        calc = load_calculate()
        for payload, message in cases:
            with self.subTest(message=message):
                with tempfile.TemporaryDirectory() as tmp:
                    input_path = Path(tmp) / "input.json"
                    input_path.write_text(json.dumps(payload), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, message):
                        calc.run_calculation(input_path, Path(tmp))

    def test_accumulates_terminal_demands_upstream(self):
        payload = {
            "project": {"id": "branch", "mode": "nuevo", "nombre": "Branch"},
            "nodos": [
                {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
                {"id": "D1", "tipo": "distribucion", "elevacion_m": 1},
                {"id": "P1", "tipo": "critico", "elevacion_m": 3, "demanda_lps": 0.4},
                {"id": "P2", "tipo": "critico", "elevacion_m": 2, "demanda_lps": 0.6},
            ],
            "tramos": [
                {"id": "T0", "desde": "CIS", "hasta": "D1", "longitud_m": 10},
                {"id": "T1", "desde": "D1", "hasta": "P1", "longitud_m": 5},
                {"id": "T2", "desde": "D1", "hasta": "P2", "longitud_m": 5},
            ],
        }

        _, result = self.run_calc(payload)
        tramos = {t["id"]: t for t in result["tramos"]}
        self.assertAlmostEqual(tramos["T0"]["caudal_lps"], 1.0)
        self.assertAlmostEqual(tramos["T1"]["caudal_lps"], 0.4)
        self.assertAlmostEqual(tramos["T2"]["caudal_lps"], 0.6)

    def test_selects_diameter_and_calculates_accessory_loss(self):
        _, result = self.run_calc(self.base_payload())
        tramo = result["tramos"][0]

        self.assertIn(tramo["diametro_mm"], [20, 25, 32, 40, 50, 63, 75, 90, 110])
        self.assertGreaterEqual(tramo["velocidad_m_s"], 0.6)
        self.assertLessEqual(tramo["velocidad_m_s"], 2.5)
        self.assertAlmostEqual(tramo["longitud_equivalente_accesorios_m"], (30 * 2) * (tramo["diametro_mm"] / 1000), places=6)
        self.assertGreater(tramo["perdida_accesorios_m"], 0)

    def test_declared_diameter_is_respected_and_warns_when_velocity_high(self):
        payload = self.base_payload()
        payload["tramos"][0]["diametro_mm"] = 20
        _, result = self.run_calc(payload)
        tramo = result["tramos"][0]

        self.assertEqual(tramo["diametro_mm"], 20)
        self.assertGreater(tramo["velocidad_m_s"], 2.5)
        self.assertTrue(any("velocidad" in warning.lower() for warning in result["advertencias"]))

    def test_selects_critical_route_and_next_commercial_hp(self):
        payload = {
            "project": {"id": "critical", "mode": "nuevo", "nombre": "Critical"},
            "criterios": {"margen_seguridad_porcentaje": 0, "bombas_hp": [0.5, 1, 1.5, 2, 3]},
            "nodos": [
                {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
                {"id": "A", "tipo": "critico", "elevacion_m": 2, "demanda_lps": 0.2},
                {"id": "B", "tipo": "critico", "elevacion_m": 20, "demanda_lps": 1.0, "presion_min_mca": 8},
            ],
            "tramos": [
                {"id": "TA", "desde": "CIS", "hasta": "A", "longitud_m": 5},
                {"id": "TB", "desde": "CIS", "hasta": "B", "longitud_m": 40},
            ],
        }

        _, result = self.run_calc(payload)
        resumen = result["resumen"]
        self.assertEqual(resumen["ruta_critica"], "B")
        self.assertGreater(resumen["adt_critica_mca"], 28)
        self.assertGreater(resumen["hp_requerido"], 0)
        self.assertIn(resumen["bomba_seleccionada_hp"], [0.5, 1, 1.5, 2, 3])
        self.assertGreaterEqual(resumen["bomba_seleccionada_hp"], resumen["hp_requerido"])

    def test_reference_style_input_is_supported(self):
        payload = json.loads(REFERENCE_INPUT_PATH.read_text(encoding="utf-8"))
        root, result = self.run_calc(payload)

        self.assertEqual(result["project"]["id"], "nave-demo")
        self.assertEqual(result["project"]["mode"], "nuevo")
        self.assertEqual(result["nodos"][0]["elevacion_m"], -2.0)
        self.assertEqual(result["nodos"][0]["nombre"], "Cisterna principal")
        self.assertAlmostEqual(next(n for n in result["nodos"] if n["id"] == "N5")["demanda_directa_lps"], 0.64)
        self.assertEqual({r["nodo_critico"] for r in result["rutas_criticas"]}, {"N6", "N8"})
        self.assertEqual(result["resumen"]["bomba_seleccionada_capacidad"], "1 HP")
        self.assertTrue((root / "proyectos" / "nave-demo" / "resultado_perdidas.json").exists())

    def test_k_accessory_method_and_fixed_losses_are_supported(self):
        payload = self.base_payload()
        payload["criterios"] = {
            "metodo_accesorios": "k",
            "margen_seguridad_porcentaje": 0,
            "catalogo_accesorios": {"codo_90": {"k": 0.9, "descripcion": "Codo 90"}},
        }
        payload["tramos"][0]["diametro_mm"] = 32
        payload["tramos"][0]["accesorios"] = [
            {"tipo": "codo_90", "cantidad": 2},
            {"tipo": "equipo_especial", "cantidad": 1, "perdida_m": 2.5},
        ]

        _, result = self.run_calc(payload)
        tramo = result["tramos"][0]
        velocity = tramo["velocidad_m_s"]
        expected_k_loss = (2 * 0.9) * (velocity ** 2) / (2 * 9.80665)
        self.assertEqual(tramo["metodo_accesorios"], "k")
        self.assertAlmostEqual(tramo["k_accesorios_total"], 1.8)
        self.assertAlmostEqual(tramo["perdida_accesorios_k_m"], expected_k_loss, places=5)
        self.assertAlmostEqual(tramo["perdida_accesorios_fija_m"], 2.5)
        self.assertAlmostEqual(tramo["perdida_accesorios_m"], expected_k_loss + 2.5, places=5)

    def test_margin_types_and_point_pressure_overrides(self):
        payload = {
            "project": {"id": "pressure", "mode": "nuevo", "nombre": "Pressure"},
            "criterios": {
                "margen_seguridad_tipo": "porcentaje_sobre_perdidas",
                "margen_seguridad_porcentaje": 0.10,
                "presion_critica_default_mca": 5.7,
                "presion_punto_critico_fluxometro_mca": 15,
                "bombas_hp": [0.5, 1, 2, 3, 5]
            },
            "nodos": [
                {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
                {"id": "STD", "tipo": "critico", "elevacion_m": 1, "demanda_lps": 0.2},
                {"id": "FLUX", "tipo": "critico", "tipo_equipo": "fluxometro", "elevacion_m": 2, "demanda_lps": 0.2},
                {"id": "EQUIPO", "tipo": "critico", "equipo_presion_mca": 22, "elevacion_m": 3, "demanda_lps": 0.2}
            ],
            "tramos": [
                {"id": "TSTD", "desde": "CIS", "hasta": "STD", "longitud_m": 5},
                {"id": "TFLUX", "desde": "CIS", "hasta": "FLUX", "longitud_m": 5},
                {"id": "TEQ", "desde": "CIS", "hasta": "EQUIPO", "longitud_m": 5}
            ]
        }

        _, result = self.run_calc(payload)
        routes = {r["nodo_critico"]: r for r in result["rutas_criticas"]}
        self.assertAlmostEqual(routes["STD"]["presion_punto_critico_mca"], 5.7)
        self.assertAlmostEqual(routes["FLUX"]["presion_punto_critico_mca"], 15.0)
        self.assertAlmostEqual(routes["EQUIPO"]["presion_punto_critico_mca"], 22.0)
        self.assertAlmostEqual(
            routes["STD"]["margen_seguridad_mca"],
            (routes["STD"]["perdida_friccion_m"] + routes["STD"]["perdida_accesorios_m"]) * 0.10,
            places=5,
        )
        self.assertEqual(result["resumen"]["ruta_critica"], "EQUIPO")

    def test_expanded_catalogs_and_units_are_reported(self):
        payload = self.base_payload()
        payload["criterios"] = {"material_default": "cpvc", "bombas_hp": [0.5, 1, 1.5, 2, 3, 5, 10, 20, 30, 50]}
        payload["tramos"][0].pop("material", None)

        _, result = self.run_calc(payload)
        self.assertIn(13.0, result["catalogos_usados"]["diametros_mm"])
        self.assertIn(150.0, result["catalogos_usados"]["diametros_mm"])
        self.assertIn("cpvc", result["catalogos_usados"]["materiales_hazen"])
        self.assertIn(50.0, result["catalogos_usados"]["bombas_hp"])
        self.assertGreater(result["resumen"]["adt_critica_psi"], 0)
        self.assertGreater(result["resumen"]["potencia_hidraulica_w"], 0)
        self.assertIn("bomba", result)
        self.assertIn("capacidad_seleccionada", result["bomba"])

    def test_hydropneumatic_tank_uses_reference_formula_and_selects_catalog_tank(self):
        payload = self.base_payload()
        payload["criterios"] = {"caudal_bomba_lps": 4.2, "margen_seguridad_porcentaje": 0}
        payload["tanque_hidroneumatico"] = {
            "calcular": True,
            "factor_extraccion": 0.38,
            "catalogo": [{"modelo": "WM-6 / WM0300", "gal": 300, "litros": 1136}],
        }

        _, result = self.run_calc(payload)

        tanque = result["tanque_hidroneumatico"]
        self.assertTrue(tanque["calculado"])
        self.assertEqual(tanque["metodo"], "referencia_mdc")
        self.assertAlmostEqual(tanque["caudal_base_gpm"], 66.6, places=1)
        self.assertAlmostEqual(tanque["volumen_necesario_l"], 997.92, places=2)
        self.assertAlmostEqual(tanque["volumen_necesario_gal"], 263.62, places=2)
        self.assertEqual(tanque["volumen_adoptado_l"], 1136.0)
        self.assertEqual(tanque["volumen_adoptado_gal"], 300.0)
        self.assertEqual(tanque["cantidad"], 1)
        self.assertEqual(tanque["modelo"], "WM-6 / WM0300")

    def test_hydropneumatic_tank_uses_multiple_catalog_units_when_one_is_insufficient(self):
        payload = self.base_payload()
        payload["criterios"] = {"caudal_bomba_lps": 4.2, "margen_seguridad_porcentaje": 0}
        payload["tanque_hidroneumatico"] = {
            "calcular": True,
            "catalogo": [{"modelo": "WM-100", "gal": 100, "litros": 378.5}],
        }

        _, result = self.run_calc(payload)

        tanque = result["tanque_hidroneumatico"]
        self.assertEqual(tanque["cantidad"], 3)
        self.assertEqual(tanque["modelo"], "WM-100")
        self.assertAlmostEqual(tanque["volumen_adoptado_l"], 1135.5, places=1)
        self.assertAlmostEqual(tanque["volumen_adoptado_gal"], 300.0, places=1)

    def test_hydropneumatic_tank_is_not_calculated_when_disabled(self):
        payload = self.base_payload()
        payload["tanque_hidroneumatico"] = {"calcular": False}

        _, result = self.run_calc(payload)

        self.assertEqual(result["tanque_hidroneumatico"], {"calculado": False, "mensaje": "Cálculo de tanque hidroneumático no solicitado"})

    def test_pump_selection_uses_20_percent_selection_margin(self):
        payload = self.base_payload()
        payload["criterios"] = {
            "margen_seguridad_porcentaje": 0,
            "margen_seleccion_bomba_porcentaje": 0.20,
            "bombas_hp": [0.5, 1.0, 1.5],
        }
        payload["nodos"][0]["elevacion_m"] = 0
        payload["nodos"][1]["elevacion_m"] = 28
        payload["nodos"][1]["demanda_lps"] = 2.12
        payload["nodos"][1]["presion_min_mca"] = 5.7
        payload["tramos"][0]["longitud_m"] = 20
        payload["tramos"][0]["diametro_mm"] = 40

        _, result = self.run_calc(payload)
        bomba = result["bomba"]

        self.assertAlmostEqual(bomba["margen_seleccion_porcentaje"], 0.20)
        self.assertAlmostEqual(
            bomba["potencia_seleccion_minima_hp"],
            bomba["potencia_requerida_hp"] * 1.20,
            places=6,
        )
        self.assertGreater(bomba["potencia_seleccion_minima_hp"], 1.0)
        self.assertEqual(bomba["capacidad_seleccionada"]["capacidad"], "1.5 HP")
        self.assertEqual(result["resumen"]["bomba_seleccionada_capacidad"], "1.5 HP")

    def test_global_and_node_simultaneity_are_reported_and_accumulated(self):
        payload = {
            "project": {"id": "sim", "mode": "nuevo", "nombre": "Sim"},
            "criterios": {"factor_simultaneidad_global": 0.50, "margen_seguridad_porcentaje": 0},
            "nodos": [
                {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
                {"id": "D1", "tipo": "distribucion", "elevacion_m": 0},
                {"id": "A", "tipo": "critico", "elevacion_m": 1, "demanda_lps": 1.0},
                {"id": "B", "tipo": "critico", "elevacion_m": 1, "demanda_lps": 1.0, "factor_simultaneidad": 0.25},
            ],
            "tramos": [
                {"id": "T0", "desde": "CIS", "hasta": "D1", "longitud_m": 5},
                {"id": "T1", "desde": "D1", "hasta": "A", "longitud_m": 5},
                {"id": "T2", "desde": "D1", "hasta": "B", "longitud_m": 5},
            ],
        }

        _, result = self.run_calc(payload)
        nodes = {n["id"]: n for n in result["nodos"]}
        tramos = {t["id"]: t for t in result["tramos"]}

        self.assertAlmostEqual(nodes["A"]["demanda_sin_simultaneidad_lps"], 1.0)
        self.assertAlmostEqual(nodes["A"]["factor_simultaneidad_aplicado"], 0.50)
        self.assertAlmostEqual(nodes["A"]["demanda_directa_lps"], 0.5)
        self.assertAlmostEqual(nodes["B"]["factor_simultaneidad_aplicado"], 0.25)
        self.assertAlmostEqual(nodes["B"]["demanda_directa_lps"], 0.25)
        self.assertAlmostEqual(tramos["T0"]["caudal_lps"], 0.75)
        self.assertAlmostEqual(result["resumen"]["factor_simultaneidad_global"], 0.50)

    def test_pressure_modes_table_4_and_art_32(self):
        payload = {
            "project": {"id": "pressure-modes", "mode": "nuevo", "nombre": "Pressure Modes"},
            "criterios": {
                "criterio_presion_minima": "art_32",
                "margen_seguridad_porcentaje": 0,
                "presion_critica_default_mca": 5.7,
                "presion_aparato_tanque_mca": 7.03,
                "presion_punto_critico_fluxometro_mca": 10.55,
            },
            "nodos": [
                {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
                {"id": "STD", "tipo": "critico", "elevacion_m": 1, "demanda_lps": 0.2},
                {"id": "FLUX", "tipo": "critico", "tipo_equipo": "fluxometro", "elevacion_m": 1, "demanda_lps": 0.2},
            ],
            "tramos": [
                {"id": "TSTD", "desde": "CIS", "hasta": "STD", "longitud_m": 5},
                {"id": "TFLUX", "desde": "CIS", "hasta": "FLUX", "longitud_m": 5},
            ],
        }

        _, result = self.run_calc(payload)
        routes = {r["nodo_critico"]: r for r in result["rutas_criticas"]}

        self.assertAlmostEqual(routes["STD"]["presion_punto_critico_mca"], 7.03)
        self.assertEqual(routes["STD"]["criterio_presion_minima"], "art_32")
        self.assertAlmostEqual(routes["FLUX"]["presion_punto_critico_mca"], 10.55)
        self.assertIn("Art. 32", routes["STD"]["fuente_presion_minima"])

        payload["project"]["id"] = "pressure-table-4"
        payload["criterios"]["criterio_presion_minima"] = "tabla_4"
        _, result_table = self.run_calc(payload)
        routes_table = {r["nodo_critico"]: r for r in result_table["rutas_criticas"]}
        self.assertAlmostEqual(routes_table["STD"]["presion_punto_critico_mca"], 5.7)
        self.assertIn("Tabla 4", routes_table["STD"]["fuente_presion_minima"])

    def test_ppr_nominal_mode_uses_internal_diameter_from_sdr_catalog(self):
        payload = self.base_payload()
        payload["criterios"] = {
            "diametro_modo": "ppr_nominal",
            "ppr_serie_default": "SDR11",
            "margen_seguridad_porcentaje": 0,
            "catalogos": {"ppr_sdr": {"SDR11": {"40": 32.72}}},
        }
        payload["tramos"][0]["diametro_mm"] = 40

        _, result = self.run_calc(payload)
        tramo = result["tramos"][0]

        self.assertEqual(tramo["diametro_nominal_mm"], 40)
        self.assertAlmostEqual(tramo["diametro_hidraulico_mm"], 32.72)
        self.assertEqual(tramo["diametro_modo"], "ppr_nominal")
        self.assertEqual(tramo["ppr_serie"], "SDR11")
        self.assertAlmostEqual(tramo["diametro_mm"], 32.72)

    def test_ppr_nominal_auto_selection_checks_internal_velocity(self):
        payload = self.base_payload()
        payload["criterios"] = {
            "diametro_modo": "ppr_nominal",
            "ppr_serie_default": "SDR11",
            "margen_seguridad_porcentaje": 0,
            "diametros_mm": [40, 50],
            "catalogos": {"ppr_sdr": {"SDR11": {"40": 32.72, "50": 40.90}}},
        }
        payload["nodos"][1]["demanda_lps"] = 2.5

        _, result = self.run_calc(payload)
        tramo = result["tramos"][0]

        self.assertEqual(tramo["diametro_declarado_mm"], 50)
        self.assertEqual(tramo["diametro_nominal_mm"], 50)
        self.assertAlmostEqual(tramo["diametro_hidraulico_mm"], 40.90)
        self.assertAlmostEqual(tramo["diametro_mm"], 40.90)
        self.assertLessEqual(tramo["velocidad_m_s"], result["criterios"]["velocidad_max_m_s"])
        self.assertFalse(any("sin diámetro interno PPR" in warning for warning in result["advertencias"]))
        self.assertFalse(any("velocidad" in warning.lower() for warning in result["advertencias"]))

    def test_accessory_detail_reports_row_level_losses(self):
        payload = self.base_payload()
        payload["criterios"] = {"metodo_accesorios": "longitud_equivalente", "margen_seguridad_porcentaje": 0}
        payload["tramos"][0]["diametro_mm"] = 32
        payload["tramos"][0]["accesorios"] = {
            "codo_90": 2,
            "valvula_check": 1,
            "equipo_especial": {"cantidad": 1, "perdida_m": 0.75},
        }

        _, result = self.run_calc(payload)
        tramo = result["tramos"][0]
        detail = tramo["detalle_accesorios"]

        self.assertGreaterEqual(len(detail), 3)
        self.assertTrue(all("ha_m" in row for row in detail))
        self.assertTrue(all("metodo" in row for row in detail))
        self.assertAlmostEqual(sum(row["ha_m"] for row in detail), tramo["perdida_accesorios_m"], places=5)
        self.assertTrue(any(row["accesorio"] == "valvula_check" for row in detail))

    def test_npsh_uses_declared_minimum_water_level_and_reports_not_evaluable_without_required_value(self):
        payload = self.base_payload()
        payload["criterios"] = {
            "evaluar_npsh": True,
            "nodo_bomba": "BOMBA",
            "margen_seguridad_porcentaje": 0,
            "npsh": {
                "nivel_minimo_agua_m": -1.5,
                "eje_bomba_m": 0.0,
                "temperatura_agua_c": 25.0,
                "altitud_m": 0.0,
                "margen_npsh_m": 1.0,
            },
        }
        payload["nodos"] = [
            {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
            {"id": "BOMBA", "tipo": "distribucion", "elevacion_m": 0},
            {"id": "P1", "tipo": "critico", "elevacion_m": 2, "demanda_lps": 0.4},
        ]
        payload["tramos"] = [
            {"id": "TS", "desde": "CIS", "hasta": "BOMBA", "longitud_m": 2, "diametro_mm": 40, "tipo_tramo": "succion"},
            {"id": "TD", "desde": "BOMBA", "hasta": "P1", "longitud_m": 4, "diametro_mm": 32},
        ]

        _, result = self.run_calc(payload)
        npsh = result["succion_npsh"]

        self.assertTrue(npsh["evaluado"])
        self.assertEqual(npsh["condicion"], "succion_negativa")
        self.assertEqual(npsh["nivel_minimo_agua_m"], -1.5)
        self.assertEqual(npsh["eje_bomba_m"], 0.0)
        self.assertAlmostEqual(npsh["altura_succion_estatica_m"], -1.5)
        self.assertIsNone(npsh["cumple"])
        self.assertEqual(npsh["estado"], "No evaluable")
        self.assertIn("confirmar con la selección de la bomba antes de comprar", npsh["nota"])

    def test_npsh_classifies_same_level_separately_from_flooded_suction(self):
        payload = self.base_payload()
        payload["criterios"] = {"evaluar_npsh": True, "nodo_bomba": "BOMBA", "margen_seguridad_porcentaje": 0}
        payload["nodos"] = [
            {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
            {"id": "BOMBA", "tipo": "distribucion", "elevacion_m": 0},
            {"id": "P1", "tipo": "critico", "elevacion_m": 2, "demanda_lps": 0.4},
        ]
        payload["tramos"] = [
            {"id": "TS", "desde": "CIS", "hasta": "BOMBA", "longitud_m": 2, "diametro_mm": 40, "tipo_tramo": "succion"},
            {"id": "TD", "desde": "BOMBA", "hasta": "P1", "longitud_m": 4, "diametro_mm": 32},
        ]

        _, result = self.run_calc(payload)

        self.assertEqual(result["succion_npsh"]["condicion"], "succion_al_mismo_nivel")
        self.assertEqual(result["succion_npsh"]["estado"], "No evaluable")

    def test_suction_npsh_reports_available_head_and_missing_npshr_warning(self):
        payload = {
            "project": {"id": "npsh", "mode": "nuevo", "nombre": "NPSH"},
            "criterios": {"evaluar_npsh": True, "nodo_bomba": "BOMBA", "margen_seguridad_porcentaje": 0},
            "nodos": [
                {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
                {"id": "BOMBA", "tipo": "distribucion", "elevacion_m": 1},
                {"id": "P1", "tipo": "critico", "elevacion_m": 5, "demanda_lps": 0.5},
            ],
            "tramos": [
                {"id": "TS", "desde": "CIS", "hasta": "BOMBA", "longitud_m": 8, "diametro_mm": 40, "tipo_tramo": "succion", "accesorios": {"filtro_succion": 1, "valvula_pie": 1}},
                {"id": "TI", "desde": "BOMBA", "hasta": "P1", "longitud_m": 10, "diametro_mm": 32},
            ],
        }

        _, result = self.run_calc(payload)
        npsh = result["succion_npsh"]

        self.assertTrue(npsh["evaluado"])
        self.assertEqual(npsh["nodo_bomba"], "BOMBA")
        self.assertGreater(npsh["perdidas_succion_m"], 0)
        self.assertGreater(npsh["npsh_disponible_m"], 0)
        self.assertIsNone(npsh["npsh_requerido_m"])
        self.assertTrue(any("NPSHr" in warning for warning in result["advertencias"]))

    def test_suction_npsh_verifies_required_head_with_margin(self):
        payload = self.base_payload()
        payload["project"]["id"] = "npsh-ok"
        payload["criterios"] = {"evaluar_npsh": True, "nodo_bomba": "PUMP", "npsh_requerido_m": 3.0, "margen_npsh_m": 1.0, "margen_seguridad_porcentaje": 0}
        payload["nodos"] = [
            {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
            {"id": "PUMP", "tipo": "distribucion", "elevacion_m": 0},
            {"id": "P1", "tipo": "critico", "elevacion_m": 2, "demanda_lps": 0.4},
        ]
        payload["tramos"] = [
            {"id": "TS", "desde": "CIS", "hasta": "PUMP", "longitud_m": 2, "diametro_mm": 40, "tipo_tramo": "succion"},
            {"id": "TD", "desde": "PUMP", "hasta": "P1", "longitud_m": 4, "diametro_mm": 32},
        ]

        _, result = self.run_calc(payload)
        self.assertTrue(result["succion_npsh"]["cumple"])
        self.assertGreaterEqual(result["succion_npsh"]["margen_disponible_m"], 1.0)

    def test_maximum_pressure_check_flags_nodes_above_limit(self):
        payload = {
            "project": {"id": "pmax", "mode": "nuevo", "nombre": "Pmax"},
            "criterios": {
                "verificar_presion_maxima": True,
                "presion_maxima_red_mca": 20,
                "margen_seguridad_porcentaje": 0,
                "bombas_hp": [0.5, 1, 2, 3, 5],
            },
            "nodos": [
                {"id": "CIS", "tipo": "cisterna", "elevacion_m": 0},
                {"id": "LOW", "tipo": "critico", "elevacion_m": 1, "demanda_lps": 0.2, "presion_min_mca": 25},
                {"id": "HIGH", "tipo": "critico", "elevacion_m": 10, "demanda_lps": 0.2, "presion_min_mca": 5.7},
            ],
            "tramos": [
                {"id": "TLOW", "desde": "CIS", "hasta": "LOW", "longitud_m": 5},
                {"id": "THIGH", "desde": "CIS", "hasta": "HIGH", "longitud_m": 5},
            ],
        }

        _, result = self.run_calc(payload)
        pmax = result["presion_maxima"]

        self.assertTrue(pmax["evaluado"])
        self.assertEqual(pmax["limite_mca"], 20)
        self.assertTrue(any(row["excede"] for row in pmax["nodos"]))
        self.assertTrue(any("presión máxima" in warning.lower() for warning in result["advertencias"]))

    def test_runner_generates_json_and_html(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            input_path = root / "input.json"
            payload = self.base_payload()
            payload["criterios"] = {"caudal_bomba_lps": 4.2, "margen_seguridad_porcentaje": 0}
            payload["tanque_hidroneumatico"] = {
                "calcular": True,
                "catalogo": [{"modelo": "WM-6 / WM0300", "gal": 300, "litros": 1136}],
            }
            input_path.write_text(json.dumps(payload), encoding="utf-8")

            completed = subprocess.run(
                [sys.executable, str(RUN_PATH), "--input", str(input_path), "--root", str(root)],
                check=True,
                text=True,
                capture_output=True,
            )

            html_path = root / "proyectos" / "demo" / "memoria_perdidas.html"
            self.assertIn("OK cálculo", completed.stdout)
            self.assertTrue(html_path.exists())
            html = html_path.read_text(encoding="utf-8")
            self.assertIn("Memoria de Cálculo - Sistema Hidráulico y Pérdidas", html)
            self.assertIn("Altura Dinámica Total", html)
            self.assertIn("Bomba seleccionada", html)
            self.assertIn("Impulsión", html)
            self.assertIn("Teoría de cálculo", html)
            self.assertIn("Catálogo de bomba", html)
            self.assertIn("Nota de especificación", html)
            self.assertIn("psi", html)
            self.assertIn("Criterio de presión mínima", html)
            self.assertIn("Unidades Hazen-Williams", html)
            self.assertIn("Detalle de accesorios", html)
            self.assertIn("Margen de selección de bomba", html)
            self.assertIn("Succión y NPSH", html)
            self.assertIn("Presión máxima", html)
            self.assertIn("Tanque hidroneumático", html)
            self.assertIn("WM-6 / WM0300", html)

    def test_docs_templates_and_example_are_valid(self):
        skill_md = (SKILL_DIR / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("name: san-perdidas", skill_md)
        self.assertRegex(skill_md, r"description: Use when")
        json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))
        example = json.loads(EXAMPLE_PATH.read_text(encoding="utf-8"))
        root, result = self.run_calc(example)
        self.assertEqual(result["project"]["id"], example["project"]["id"])
        self.assertTrue((root / "proyectos" / example["project"]["id"] / "resultado_perdidas.json").exists())


if __name__ == "__main__":
    unittest.main()

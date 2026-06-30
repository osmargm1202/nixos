#!/usr/bin/env python3
"""Orquesta cálculo + render HTML para san-cisterna-septico."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Calcula resultado.json y renderiza memoria.html")
    parser.add_argument("--input", required=True, help="Ruta del input.json")
    parser.add_argument("--cwd", default=".", help="Raíz del proyecto; default pwd")
    parser.add_argument("--force", action="store_true", help="Permite sobrescribir proyecto nuevo existente")
    args = parser.parse_args()

    here = Path(__file__).resolve().parent
    cwd = Path(args.cwd).resolve()

    calc_cmd = [sys.executable, str(here / "calculate.py"), "--input", args.input, "--cwd", str(cwd)]
    if args.force:
        calc_cmd.append("--force")
    subprocess.run(calc_cmd, check=True)

    # Leer project.id desde copia normalizada que calculate.py escribe no es necesario; extraer del input original basta
    import json, re
    input_path = Path(args.input)
    if not input_path.is_absolute():
        candidate = cwd / input_path
        input_path = candidate if candidate.exists() else input_path.resolve()
    data = json.loads(input_path.read_text(encoding="utf-8"))
    raw_project_id = (data.get("project") or {}).get("id") or (data.get("workspace") or {}).get("project_id") or (data.get("proyecto") or {}).get("id")
    project_id = re.sub(r"[^a-z0-9._-]+", "-", str(raw_project_id).strip().lower()).strip("-") or "proyecto"

    render_cmd = [sys.executable, str(here / "render_html.py"), "--project-id", project_id, "--cwd", str(cwd)]
    subprocess.run(render_cmd, check=True)
    print(f"OK memoria completa: {cwd / 'proyectos' / project_id / 'memoria.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

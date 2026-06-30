#!/usr/bin/env python3
"""Wrapper compatible para ejecutar la skill desde la raíz de la carpeta."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Calcula memoria sanitaria de cisterna y séptico.")
    parser.add_argument("--input", required=True, help="Ruta del input JSON.")
    parser.add_argument("--root", "--cwd", dest="cwd", default=".", help="Raíz de trabajo. Usar $(pwd).")
    parser.add_argument("--mode", choices=["new", "modify", "nuevo", "modificar"], help="Modo del proyecto.")
    parser.add_argument("--overwrite", "--force", dest="force", action="store_true", help="Permite sobrescribir proyecto nuevo existente.")
    args = parser.parse_args()

    skill_dir = Path(__file__).resolve().parent
    cwd = Path(args.cwd).resolve()
    input_path = Path(args.input)
    if not input_path.is_absolute():
        candidate = cwd / input_path
        input_path = candidate if candidate.exists() else input_path.resolve()

    run_input = input_path
    temp_dir = None
    if args.mode:
        data = json.loads(input_path.read_text(encoding="utf-8"))
        mode = {"new": "nuevo", "modify": "modificar"}.get(args.mode, args.mode)
        if "project" in data:
            data["project"]["mode"] = mode
        else:
            data.setdefault("workspace", {})["modo"] = {"nuevo": "new", "modificar": "modify"}[mode]
        temp_dir = tempfile.TemporaryDirectory()
        run_input = Path(temp_dir.name) / "input.json"
        run_input.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    cmd = [sys.executable, str(skill_dir / "scripts" / "run.py"), "--input", str(run_input), "--cwd", str(cwd)]
    if args.force:
        cmd.append("--force")
    try:
        subprocess.run(cmd, check=True)
    finally:
        if temp_dir:
            temp_dir.cleanup()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

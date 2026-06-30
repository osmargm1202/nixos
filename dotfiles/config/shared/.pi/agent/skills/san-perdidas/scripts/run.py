from __future__ import annotations

import argparse
from pathlib import Path

from calculate import run_calculation
from render_html import render_project


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Ejecuta cálculo y render HTML de san-perdidas.")
    parser.add_argument("--input", required=True, help="Ruta a input.json")
    parser.add_argument("--root", default=".", help="Directorio base con proyectos/")
    parser.add_argument("--force", action="store_true", help="Recrear salida si project.mode=nuevo")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = run_calculation(args.input, args.root, force=args.force)
    project_dir = Path(args.root) / "proyectos" / result["project"]["id"]
    html_path = render_project(args.root, result["project"]["id"])
    print(f"OK cálculo: {project_dir / 'resultado_perdidas.json'}")
    print(f"OK HTML: {html_path}")
    print(f"OK memoria completa: {html_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

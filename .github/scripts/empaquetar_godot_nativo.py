import argparse
import json
from pathlib import Path
import zipfile

import preparar_godot_nativo as nativo


def empaquetar(carpeta: Path, salida: Path, plataforma: str) -> dict:
    datos = nativo.validar(carpeta, nativo.RAIZ, plataforma)
    salida.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(salida, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as paquete:
        for nombre in sorted([*datos["archivos"], nativo.MANIFIESTO]):
            paquete.write(carpeta / nombre, nombre)
    resultado = {
        "receta_sha256": datos["receta_sha256"],
        "archivo_sha256": nativo.sha256(salida),
        "manifiesto_sha256": nativo.sha256(carpeta / nativo.MANIFIESTO),
    }
    salida.with_suffix(".json").write_text(
        json.dumps(resultado, indent=2) + "\n", encoding="utf-8",
    )
    return resultado


def main() -> None:
    parser = argparse.ArgumentParser(description="Empaquetar un motor nativo validado para publicar.")
    parser.add_argument("--plataforma", choices=nativo.PLATAFORMAS, required=True)
    parser.add_argument("--destino", type=Path)
    parser.add_argument("--salida", type=Path, required=True)
    opciones = parser.parse_args()
    carpeta = opciones.destino or nativo.RAIZ / "build/godot-native" / opciones.plataforma
    print(json.dumps(empaquetar(carpeta, opciones.salida, opciones.plataforma)))


if __name__ == "__main__":
    main()

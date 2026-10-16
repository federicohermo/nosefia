"""Regenera los dos glifos portables del guion; requiere fonttools==4.60.0.

    python -m pip install fonttools==4.60.0
    python assets/ui/manada/celular/generar_simbolos_de_chat.py

La fuente y su licencia se descargan de una revisión fija y se comprueban antes de
escribir. --fuente y --licencia permiten usar copias locales con los mismos hashes.
Es una dependencia del generador de este asset, no del harness ni del juego.
"""
from argparse import ArgumentParser
from hashlib import sha256
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen
import json

import fontTools
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

REVISION = "8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5"
BASE = f"https://raw.githubusercontent.com/google/fonts/{REVISION}/ofl/notoemoji/"
FUENTE = "NotoEmoji%5Bwght%5D.ttf"
FUENTE_SHA = "de6c18832938afc99caf132b39d6a30a19bac7f2e812e28db2535b4608d27551"
LICENCIA_SHA = "500bb1ccf43df7bbb522112f9133a52b16e1c35e809632f5d8609b179152de5b"
GLIFOS = {0x2728, 0x1F4AA}
FAMILIA = "No se fia Chat Symbols"


def leer(ruta: Path | None, nombre: str, esperado: str) -> bytes:
    datos = ruta.read_bytes() if ruta else urlopen(BASE + nombre, timeout=30).read()
    if sha256(datos).hexdigest() != esperado:
        raise ValueError(f"La fuente o licencia no coincide con la revisión fijada: {nombre}")
    return datos


def generar(datos: bytes, licencia: bytes) -> bytes:
    if fontTools.__version__ != "4.60.0":
        raise RuntimeError("Usar fonttools==4.60.0 para reproducir el binario versionado")
    fuente = TTFont(BytesIO(datos), recalcTimestamp=False)
    instantiateVariableFont(fuente, {"wght": 400}, inplace=True)
    opciones = subset.Options()
    opciones.name_IDs = ["*"]
    opciones.name_legacy = True
    opciones.name_languages = ["*"]
    recorte = subset.Subsetter(options=opciones)
    recorte.populate(unicodes=GLIFOS)
    recorte.subset(fuente)
    nombres = {
        1: FAMILIA,
        2: "Regular",
        3: "NoSeFiaChatSymbols-" + FUENTE_SHA[:12],
        4: FAMILIA + " Regular",
        6: "NoSeFiaChatSymbols-Regular",
        16: FAMILIA,
        17: "Regular",
        25: "NoSeFiaChatSymbols",
    }
    for registro in fuente["name"].names:
        if registro.nameID in nombres:
            registro.string = nombres[registro.nameID].encode(registro.getEncoding())
    # all_resources no incluye el TXT: la licencia completa viaja también dentro del TTF.
    fuente["name"].setName(licencia.decode("utf-8"), 13, 3, 1, 0x409)
    fuente.recalcTimestamp = False
    if set(fuente.getBestCmap()) != GLIFOS:
        raise ValueError("El recorte debe contener exactamente los dos caracteres del guion")
    salida = BytesIO()
    fuente.save(salida)
    return salida.getvalue()


def main() -> None:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--fuente", type=Path)
    parser.add_argument("--licencia", type=Path)
    parser.add_argument("--directorio", type=Path, default=Path(__file__).parent)
    args = parser.parse_args()
    datos = leer(args.fuente, FUENTE, FUENTE_SHA)
    licencia = leer(args.licencia, "OFL.txt", LICENCIA_SHA)
    resultado = generar(datos, licencia)
    args.directorio.mkdir(parents=True, exist_ok=True)
    (args.directorio / "simbolos_de_chat.ttf").write_bytes(resultado)
    (args.directorio / "LICENSE-simbolos_de_chat.txt").write_bytes(licencia)
    print(json.dumps({
        "revision": REVISION,
        "fuente_sha256": FUENTE_SHA,
        "licencia_sha256": LICENCIA_SHA,
        "resultado_sha256": sha256(resultado).hexdigest(),
        "bytes": len(resultado),
        "glifos": [f"U+{c:04X}" for c in sorted(GLIFOS)],
        "familia": FAMILIA,
    }, indent=2))


if __name__ == "__main__":
    main()

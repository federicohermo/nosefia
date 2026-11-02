"""Empaqueta las texturas que el juego ya lleva comprimidas (BC) para los visores de prueba.

Lee los `.ctex` que Godot importó (los mismos bytes que viajan en el .pck de la web de hoy) y
escribe `datos/texturas.bin` (todos los niveles, uno tras otro) y `datos/texturas.json`
(formato, tamaño y lugar de cada nivel). Así el visor sube a la GPU los mismos bytes que Godot.
El lightmap sale de la capa 0 del `.ctexarray` (BC6H), recortada a las filas usadas.

Uso: python empaquetar_texturas.py <proyecto-importado> <salida>
"""
import json
import struct
import sys
from pathlib import Path

FORMATOS = {17: ("bc1", 8), 19: ("bc3", 16), 21: ("bc5", 16), 22: ("bc7", 16), 24: ("bc6hu", 16)}


def tamano_nivel(w, h, bloque):
    return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * bloque


def leer_2d(ruta):
    b = ruta.read_bytes()
    assert b[:4] == b"GST2", ruta
    ancho, alto = struct.unpack_from("<HH", b, 0x28)
    mips, fmt = struct.unpack_from("<II", b, 0x2C)
    nombre, bloque = FORMATOS[fmt]
    niveles = []
    w, h = ancho, alto
    for _ in range(mips + 1):
        niveles.append((w, h, tamano_nivel(w, h, bloque)))
        w, h = max(1, w // 2), max(1, h // 2)
    total = sum(n[2] for n in niveles)
    inicio = len(b) - total
    assert inicio in (0x30, 0x34), (ruta.name, inicio)
    return nombre, ancho, alto, niveles, b[inicio:]


def main():
    proyecto = Path(sys.argv[1])
    salida = Path(sys.argv[2])
    escena = json.loads((salida / "escena.json").read_text(encoding="utf-8"))
    importado = proyecto / ".godot" / "imported"
    indice = {}
    piezas = []
    cursor = 0
    faltan = []
    for ruta, info in escena["texturas"].items():
        archivo = info["archivo"]
        candidatos = sorted(importado.glob(glob_escapado(archivo) + "-*.s3tc.ctex")) or sorted(
            importado.glob(glob_escapado(archivo) + "-*.bptc.ctex")
        )
        if not candidatos:
            faltan.append(archivo)
            continue
        nombre, ancho, alto, niveles, datos = leer_2d(candidatos[0])
        lista = []
        pos = 0
        for w, h, n in niveles:
            lista.append({"w": w, "h": h, "o": cursor + pos, "n": n})
            pos += n
        piezas.append(datos[:pos])
        cursor += pos
        indice[ruta] = {"f": nombre, "w": ancho, "h": alto, "niveles": lista}
    # Lightmap: capa 0 del BC6H, recortada a las filas que usan los rectángulos.
    lm = json.loads((salida / "lightmap.json").read_text(encoding="utf-8"))
    mapa = next(importado.glob("almacen.exr-*.bptc.ctexarray"))
    b = mapa.read_bytes()
    assert b[:4] == b"GSTL"
    filas = (lm["alto"] + 3) // 4
    for k in range(4):
        inicio = 52 + k * (2048 * 2048 + 16)
        capa = b[inicio : inicio + 2048 * 2048]
        recorte = capa[: filas * (2048 // 4) * 16]
        indice["__lightmap%d__" % k] = {
            "f": "bc6hu",
            "w": 2048,
            "h": filas * 4,
            "niveles": [{"w": 2048, "h": filas * 4, "o": cursor, "n": len(recorte)}],
        }
        piezas.append(recorte)
        cursor += len(recorte)
    (salida / "texturas.bin").write_bytes(b"".join(piezas))
    (salida / "texturas.json").write_text(json.dumps(indice), encoding="utf-8")
    print("texturas", len(indice) - 4, "bytes", cursor, "faltan", faltan)


def glob_escapado(nombre):
    return nombre.replace("[", "[[]")


if __name__ == "__main__":
    main()

"""Recorta el atlas del lightmap y arma el manifiesto que lee el visor.

Entradas: `datos/lightmap.bin` (la pÃ¡gina 0 del EXR en RGBAH, tal cual la volcÃ³ `volcar.gd`)
y `src/escenas/almacen.lmbake` (los rectÃ¡ngulos por nodo y las sondas del horneado).

Salidas: `datos/lightmap.bin` recortado a las filas usadas, `datos/lightmap.json` con el
tamaÃ±o y el rectÃ¡ngulo de cada nodo, `datos/sondas.bin` con las sondas y los tetraedros, y
`datos/atlas_previa.png` para mirar el atlas antes de creerle.
"""

import json
import struct
import sys
import zlib
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
DATOS = RAIZ / "build" / "motor-web" / "datos"
LMBAKE = RAIZ / "src" / "escenas" / "almacen.lmbake"


def leer_nombres(b):
    i = 24
    largo = struct.unpack_from("<I", b, i)[0]
    i += 4 + largo
    i += 8
    banderas = struct.unpack_from("<I", b, i)[0]
    i += 4
    if banderas & 2:
        i += 8
    if banderas & 4:
        largo = struct.unpack_from("<I", b, i)[0]
        i += 4 + largo
    i += 44
    cuantos = struct.unpack_from("<I", b, i)[0]
    i += 4
    lista = []
    for _ in range(cuantos):
        largo = struct.unpack_from("<I", b, i)[0]
        i += 4
        lista.append(b[i : i + largo - 1].decode("utf-8", "replace"))
        i += largo
    return lista, i


def buscar_inicio(b, nombres):
    """El primer registro de `user_data`: el desplazamiento cambia con cada horneado."""
    for o in range(0, len(b) - 64):
        tipo, cuantos = struct.unpack_from("<2I", b, o)
        if tipo != 22 or not 1 <= cuantos <= 24:
            continue
        indices = struct.unpack_from("<%dI" % cuantos, b, o + 8)
        if any(x >= len(nombres) for x in indices):
            continue
        if struct.unpack_from("<I", b, o + 8 + 4 * cuantos)[0] != 11:
            continue
        rect = struct.unpack_from("<4f", b, o + 12 + 4 * cuantos)
        if all(0 <= v <= 1.01 for v in rect) and rect[2] > 0 and rect[3] > 0:
            return o
    raise ValueError("no encontré user_data")


def rectangulos(b, nombres):
    """Los registros de `user_data`: un camino de nodo y su rectÃ¡ngulo en la pÃ¡gina."""
    o = buscar_inicio(b, nombres)
    salida = {}
    while o + 8 < len(b):
        tipo, cuantos = struct.unpack_from("<2I", b, o)
        if tipo != 22 or cuantos > 24:
            break
        camino = [nombres[x] for x in struct.unpack_from("<%dI" % cuantos, b, o + 8)]
        marca = struct.unpack_from("<I", b, o + 8 + 4 * cuantos)[0]
        rect = struct.unpack_from("<4f", b, o + 12 + 4 * cuantos)
        if marca != 11:
            break
        o += 4 * cuantos + 44
        salida["/".join(camino)] = [round(v, 8) for v in rect]
    return salida


def sondas(b, nombres):
    """El diccionario `probe_data`: puntos, tetraedros y coeficientes de armÃ³nicos."""
    i = b.find(struct.pack("<II", nombres.index("probe_data"), 26))
    if i < 0:
        return None
    i += 12
    cuantas = struct.unpack_from("<I", b, i)[0]

    def variante(pos):
        tipo = struct.unpack_from("<I", b, pos)[0]
        pos += 4
        if tipo == 5:
            largo = struct.unpack_from("<I", b, pos)[0]
            return b[pos + 4 : pos + 4 + largo - 1].decode(), pos + 4 + largo
        if tipo == 2:
            return bool(struct.unpack_from("<I", b, pos)[0]), pos + 4
        if tipo == 15:
            return struct.unpack_from("<6f", b, pos), pos + 24
        if tipo == 32:
            n = struct.unpack_from("<I", b, pos)[0]
            return list(struct.unpack_from("<%di" % n, b, pos + 4)), pos + 4 + 4 * n
        if tipo == 35:
            n = struct.unpack_from("<I", b, pos)[0]
            return list(struct.unpack_from("<%df" % (3 * n), b, pos + 4)), pos + 4 + 12 * n
        if tipo == 36:
            n = struct.unpack_from("<I", b, pos)[0]
            return list(struct.unpack_from("<%df" % (4 * n), b, pos + 4)), pos + 4 + 16 * n
        raise ValueError("tipo %d en %d" % (tipo, pos))

    salida = {}
    for _ in range(cuantas):
        clave, i = variante(i)
        valor, i = variante(i)
        salida[clave] = valor
    return salida


def png(ruta, ancho, alto, pixeles_rgb):
    crudo = b"".join(b"\x00" + pixeles_rgb[y * ancho * 3 : (y + 1) * ancho * 3] for y in range(alto))

    def trozo(tipo, datos):
        return (
            struct.pack(">I", len(datos))
            + tipo
            + datos
            + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF)
        )

    with open(ruta, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0)))
        f.write(trozo(b"IDAT", zlib.compress(crudo, 6)))
        f.write(trozo(b"IEND", b""))


def main():
    b = LMBAKE.read_bytes()
    nombres, _ = leer_nombres(b)
    rects = rectangulos(b, nombres)
    print("rectangulos:", len(rects))
    paginas = {}
    for camino, r in rects.items():
        # El atlas es una sola pÃ¡gina usada; se guarda el rectÃ¡ngulo tal cual.
        paginas[camino] = r
    alto_usado = max(int((r[1] + r[3]) * 2048) for r in paginas.values()) + 2
    print("filas usadas:", alto_usado)

    crudo = (DATOS / "lightmap.bin").read_bytes()
    ancho = 2048
    assert len(crudo) >= ancho * alto_usado * 8, len(crudo)

    # Half float a media, en RGBA separado para mirarlo. La previa lleva un mapeo simple.
    def a_float(h):
        return struct.unpack("<e", struct.pack("<H", h))[0]

    previa = bytearray(ancho * alto_usado * 3)
    for y in range(alto_usado):
        base = y * ancho * 8
        fila = y * ancho * 3
        for x in range(0, ancho):
            r, g, bb = struct.unpack_from("<3e", crudo, base + x * 8)
            for c, v in enumerate((r, g, bb)):
                v = max(0.0, v)
                v = v / (1.0 + v)
                v = min(1.0, max(0.0, v)) ** (1 / 2.2)
                previa[fila + x * 3 + c] = int(v * 255 + 0.5)
    png(DATOS / "atlas_previa.png", ancho, alto_usado, bytes(previa))

    recortado = crudo[: ancho * alto_usado * 8]
    (DATOS / "lightmap.bin").write_bytes(recortado)

    manifiesto = {
        "ancho": ancho,
        "alto": alto_usado,
        "alto_pagina": 2048,
        "rectangulos": paginas,
    }
    (DATOS / "lightmap.json").write_text(json.dumps(manifiesto), encoding="utf-8")

    s = sondas(b, nombres)
    if s:
        puntos = s.get("points") or []
        tetraedros = s.get("tetrahedra") or []
        sh = s.get("sh") or []
        print("sondas:", len(puntos) // 3, "tetraedros:", len(tetraedros) // 4, "sh:", len(sh) // 4)
        with open(DATOS / "sondas.bin", "wb") as f:
            f.write(struct.pack("<3I", len(puntos) // 3, len(tetraedros) // 4, len(sh) // 4))
            f.write(struct.pack("<%df" % len(puntos), *puntos))
            f.write(struct.pack("<%di" % len(tetraedros), *tetraedros))
            f.write(struct.pack("<%df" % len(sh), *sh))
        (DATOS / "sondas.json").write_text(
            json.dumps(
                {
                    "puntos": len(puntos) // 3,
                    "tetraedros": len(tetraedros) // 4,
                    "coeficientes": len(sh) // 4,
                    "claves": sorted(s.keys()),
                    "bounds": s.get("bounds"),
                }
            ),
            encoding="utf-8",
        )
    print("listo")


if __name__ == "__main__":
    sys.exit(main())


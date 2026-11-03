"""Lo que decide `volcar_almacen.py`: leer el horneado, recortar el atlas y empaquetar las texturas.

Todo lo de acá es puro: recibe bytes y devuelve bytes o diccionarios. El disco, Godot y la
consola los toca el script.

## Qué lee

- `almacen.lmbake`: el recurso binario del horneado. Trae, por nodo, su rectángulo en el atlas
  y las sondas con sus tetraedros. El desplazamiento de cada bloque cambia con cada horneado, y
  por eso `buscar_inicio` lo encuentra en vez de suponerlo.
- Los `.ctex` que Godot importó: son los bytes que ya viajan en el `.pck` de la web (BC1, BC3,
  BC5 y BC6H). El visor los sube a la GPU tal cual y no recomprime nada.
- El `.ctexarray` del lightmap: cuatro capas BC6H (L0 y la dirección L1 en y, z y x).
"""

import json
import struct
import zlib

LADO_DEL_ATLAS = 2048
CAPAS_DEL_LIGHTMAP = 4
TIPO_DE_REGISTRO = 22
MARCA_DE_RECTANGULO = 11
MAXIMO_DE_ANIDADO = 24

# Formato de Godot en la cabecera del `.ctex` -> (nombre en el visor, bytes por bloque de 4x4).
FORMATOS = {17: ("bc1", 8), 19: ("bc3", 16), 21: ("bc5", 16), 22: ("bc7", 16), 24: ("bc6hu", 16)}


def leer_nombres(b: bytes) -> tuple[list[str], int]:
    """La tabla de nombres del recurso y el desplazamiento donde termina."""
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


def _es_registro_valido(b: bytes, o: int, nombres: list[str]) -> bool:
    tipo, cuantos = struct.unpack_from("<2I", b, o)
    if tipo != TIPO_DE_REGISTRO or not 1 <= cuantos <= MAXIMO_DE_ANIDADO:
        return False
    indices = struct.unpack_from("<%dI" % cuantos, b, o + 8)
    if any(x >= len(nombres) for x in indices):
        return False
    if struct.unpack_from("<I", b, o + 8 + 4 * cuantos)[0] != MARCA_DE_RECTANGULO:
        return False
    rect = struct.unpack_from("<4f", b, o + 12 + 4 * cuantos)
    return all(0 <= v <= 1.01 for v in rect) and rect[2] > 0 and rect[3] > 0


def buscar_inicio(b: bytes, nombres: list[str]) -> int:
    """El primer registro de `user_data`, que no está alineado."""
    for o in range(0, len(b) - 64):
        if _es_registro_valido(b, o, nombres):
            return o
    raise ValueError("no encontré el primer registro de user_data en el horneado")


def rectangulos(b: bytes, nombres: list[str]) -> dict[str, list[float]]:
    """Camino de cada nodo -> su rectángulo `[x, y, ancho, alto]` en el atlas, de 0 a 1."""
    o = buscar_inicio(b, nombres)
    salida: dict[str, list[float]] = {}
    while o + 8 < len(b):
        tipo, cuantos = struct.unpack_from("<2I", b, o)
        if tipo != TIPO_DE_REGISTRO or cuantos > MAXIMO_DE_ANIDADO:
            break
        camino = [nombres[x] for x in struct.unpack_from("<%dI" % cuantos, b, o + 8)]
        marca = struct.unpack_from("<I", b, o + 8 + 4 * cuantos)[0]
        if marca != MARCA_DE_RECTANGULO:
            break
        rect = struct.unpack_from("<4f", b, o + 12 + 4 * cuantos)
        o += 4 * cuantos + 44
        salida["/".join(camino)] = [round(v, 8) for v in rect]
    return salida


def _variante(b: bytes, pos: int):
    """Un valor del diccionario de sondas y el desplazamiento donde sigue."""
    tipo = struct.unpack_from("<I", b, pos)[0]
    pos += 4
    if tipo == 5:
        largo = struct.unpack_from("<I", b, pos)[0]
        return b[pos + 4 : pos + 4 + largo - 1].decode(), pos + 4 + largo
    if tipo == 2:
        return bool(struct.unpack_from("<I", b, pos)[0]), pos + 4
    if tipo == 15:
        return struct.unpack_from("<6f", b, pos), pos + 24
    if tipo in (32, 35, 36):
        componentes = {32: 1, 35: 3, 36: 4}[tipo]
        n = struct.unpack_from("<I", b, pos)[0]
        letra = "i" if tipo == 32 else "f"
        valores = list(struct.unpack_from("<%d%s" % (componentes * n, letra), b, pos + 4))
        return valores, pos + 4 + 4 * componentes * n
    raise ValueError("tipo de variante %d en %d" % (tipo, pos))


def sondas(b: bytes, nombres: list[str]) -> dict | None:
    """El diccionario `probe_data`: puntos, tetraedros y coeficientes de armónicos esféricos."""
    i = b.find(struct.pack("<II", nombres.index("probe_data"), 26))
    if i < 0:
        return None
    i += 12
    cuantas = struct.unpack_from("<I", b, i)[0]
    salida = {}
    for _ in range(cuantas):
        clave, i = _variante(b, i)
        valor, i = _variante(b, i)
        salida[clave] = valor
    return salida


def sondas_a_bytes(s: dict) -> tuple[bytes, dict]:
    """`sondas.bin` (cabecera de tres enteros, puntos, tetraedros y coeficientes) y su resumen."""
    puntos = s.get("points") or []
    tetraedros = s.get("tetrahedra") or []
    sh = s.get("sh") or []
    cuerpo = (
        struct.pack("<3I", len(puntos) // 3, len(tetraedros) // 4, len(sh) // 4)
        + struct.pack("<%df" % len(puntos), *puntos)
        + struct.pack("<%di" % len(tetraedros), *tetraedros)
        + struct.pack("<%df" % len(sh), *sh)
    )
    resumen = {
        "puntos": len(puntos) // 3,
        "tetraedros": len(tetraedros) // 4,
        "coeficientes": len(sh) // 4,
        "claves": sorted(s.keys()),
        "bounds": s.get("bounds"),
    }
    return cuerpo, resumen


def filas_usadas(rects: dict[str, list[float]]) -> int:
    """Hasta qué fila del atlas llega algún rectángulo, con dos de margen."""
    return max(int((r[1] + r[3]) * LADO_DEL_ATLAS) for r in rects.values()) + 2


def manifiesto_del_lightmap(rects: dict[str, list[float]]) -> dict:
    return {
        "ancho": LADO_DEL_ATLAS,
        "alto": filas_usadas(rects),
        "alto_pagina": LADO_DEL_ATLAS,
        "rectangulos": rects,
    }


def recortar_lightmap(crudo: bytes, alto: int) -> bytes:
    """Las filas usadas del atlas RGBA en medias flotantes (ocho bytes por píxel)."""
    necesarios = LADO_DEL_ATLAS * alto * 8
    if len(crudo) < necesarios:
        raise ValueError("el atlas tiene %d bytes y pide %d" % (len(crudo), necesarios))
    return crudo[:necesarios]


def previa_del_atlas(crudo: bytes, alto: int) -> bytes:
    """Un PNG para mirar el atlas antes de creerle: Reinhard y gamma 2,2."""
    previa = bytearray(LADO_DEL_ATLAS * alto * 3)
    for y in range(alto):
        base = y * LADO_DEL_ATLAS * 8
        fila = y * LADO_DEL_ATLAS * 3
        for x in range(LADO_DEL_ATLAS):
            for c, v in enumerate(struct.unpack_from("<3e", crudo, base + x * 8)):
                v = max(0.0, v)
                v = min(1.0, max(0.0, v / (1.0 + v))) ** (1 / 2.2)
                previa[fila + x * 3 + c] = int(v * 255 + 0.5)
    return png(LADO_DEL_ATLAS, alto, bytes(previa))


def png(ancho: int, alto: int, pixeles_rgb: bytes) -> bytes:
    filas = (pixeles_rgb[y * ancho * 3 : (y + 1) * ancho * 3] for y in range(alto))
    crudo = b"".join(b"\x00" + fila for fila in filas)

    def trozo(tipo: bytes, datos: bytes) -> bytes:
        crc = zlib.crc32(tipo + datos) & 0xFFFFFFFF
        return struct.pack(">I", len(datos)) + tipo + datos + struct.pack(">I", crc)

    return (
        b"\x89PNG\r\n\x1a\n"
        + trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0))
        + trozo(b"IDAT", zlib.compress(crudo, 6))
        + trozo(b"IEND", b"")
    )


def bytes_de_un_nivel(ancho: int, alto: int, bloque: int) -> int:
    return max(1, (ancho + 3) // 4) * max(1, (alto + 3) // 4) * bloque


Nivel = tuple[int, int, int]


def leer_ctex(b: bytes, nombre: str = "") -> tuple[str, int, int, list[Nivel], bytes]:
    """`(formato, ancho, alto, niveles, datos)` de un `.ctex`. Un nivel: `(ancho, alto, bytes)`."""
    if b[:4] != b"GST2":
        raise ValueError("%s no es un .ctex" % nombre)
    ancho, alto = struct.unpack_from("<HH", b, 0x28)
    mips, formato = struct.unpack_from("<II", b, 0x2C)
    if formato not in FORMATOS:
        raise ValueError("%s: el formato %d no es de los que sube el visor" % (nombre, formato))
    clave, bloque = FORMATOS[formato]
    niveles = []
    w, h = ancho, alto
    for _ in range(mips + 1):
        niveles.append((w, h, bytes_de_un_nivel(w, h, bloque)))
        w, h = max(1, w // 2), max(1, h // 2)
    total = sum(n[2] for n in niveles)
    inicio = len(b) - total
    if inicio not in (0x30, 0x34):
        raise ValueError("%s: los datos empiezan en %d y no en 0x30 ni 0x34" % (nombre, inicio))
    return clave, ancho, alto, niveles, b[inicio:]


def capas_del_lightmap(b: bytes, filas: int) -> list[bytes]:
    """Las cuatro capas BC6H del `.ctexarray`, recortadas a las filas de bloques usadas."""
    if b[:4] != b"GSTL":
        raise ValueError("el lightmap no es un .ctexarray")
    por_fila = LADO_DEL_ATLAS // 4 * 16
    capas = []
    for k in range(CAPAS_DEL_LIGHTMAP):
        inicio = 52 + k * (LADO_DEL_ATLAS * LADO_DEL_ATLAS + 16)
        capas.append(b[inicio : inicio + filas * por_fila])
    return capas


class Paquete:
    """Las texturas una tras otra en un solo binario, con el índice de dónde empieza cada nivel."""

    def __init__(self) -> None:
        self.piezas: list[bytes] = []
        self.indice: dict[str, dict] = {}
        self.cursor = 0

    def agregar_textura(self, clave: str, ctex: bytes, nombre: str = "") -> None:
        formato, ancho, alto, niveles, datos = leer_ctex(ctex, nombre)
        lista, pos = [], 0
        for w, h, n in niveles:
            lista.append({"w": w, "h": h, "o": self.cursor + pos, "n": n})
            pos += n
        self.piezas.append(datos[:pos])
        self.cursor += pos
        self.indice[clave] = {"f": formato, "w": ancho, "h": alto, "niveles": lista}

    def agregar_lightmap(self, capas: list[bytes], filas: int) -> None:
        for k, capa in enumerate(capas):
            self.indice["__lightmap%d__" % k] = {
                "f": "bc6hu",
                "w": LADO_DEL_ATLAS,
                "h": filas * 4,
                "niveles": [
                    {"w": LADO_DEL_ATLAS, "h": filas * 4, "o": self.cursor, "n": len(capa)}
                ],
            }
            self.piezas.append(capa)
            self.cursor += len(capa)

    def binario(self) -> bytes:
        return b"".join(self.piezas)

    def manifiesto(self) -> str:
        return json.dumps(self.indice)


def glob_escapado(nombre: str) -> str:
    """Los corchetes de un nombre de archivo no son un conjunto para `glob`."""
    return nombre.replace("[", "[[]")

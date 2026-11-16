"""Deja listo todo lo que hace falta para pintar la textura de Oremos y de Pepito. Corre en Blender.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/preparar_para_codex.py

No toca el `.blend` ni nada del juego: escribe todo en `reports/paquetes-de-galletitas/para-codex/`.
Por cada paquete deja una carpeta con:

- `plantilla_<producto>.png`: del tamaño exacto de la textura final, con cada zona rotulada y su
  contorno: el frente, el dorso, los dos cantos, las aletas, los afinados, la zona segura del arte
  y el sangrado.
- `zonas_<producto>.json`: el rectángulo en píxeles de cada zona, y las medidas del paquete.
- `piezas/`: las piezas del arte actual recortadas, con transparencia, a su resolución original.
- `hoja_de_piezas.png`: todas las piezas juntas, para mirarlas de una vez.
- `referencia_arte_actual.png`: el arte actual entero, tal como lo dejó el artista.

Y en la carpeta de arriba, `LEEME.md` con las reglas. Las zonas salen de
`lib/paquete_de_galletitas.py`,
la misma fuente que arma la UV: la plantilla y la malla no se pueden desfasar.
"""

import json
import math
import shutil
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import armar_paquetes_de_galletitas as armado  # noqa: E402
from arte_de_los_paquetes import (  # noqa: E402
    ORIGINALES,
    Fuente,
    copos_de,
    dilatar,
    es_de_galleta,
    es_fondo_de_pepito,
    escalar,
    escribir,
    leer,
    pieza_en,
)
from lib import paquete_de_galletitas as forma  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

DESTINO = RAIZ / "reports/paquetes-de-galletitas/para-codex"

#: Las letras de 5 x 7 con las que se rotula la plantilla. Sin acentos.
LETRAS = {
    "A": "01110 10001 10001 11111 10001 10001 10001",
    "B": "11110 10001 10001 11110 10001 10001 11110",
    "C": "01110 10001 10000 10000 10000 10001 01110",
    "D": "11110 10001 10001 10001 10001 10001 11110",
    "E": "11111 10000 10000 11110 10000 10000 11111",
    "F": "11111 10000 10000 11110 10000 10000 10000",
    "G": "01110 10001 10000 10111 10001 10001 01111",
    "H": "10001 10001 10001 11111 10001 10001 10001",
    "I": "01110 00100 00100 00100 00100 00100 01110",
    "J": "00111 00010 00010 00010 00010 10010 01100",
    "K": "10001 10010 10100 11000 10100 10010 10001",
    "L": "10000 10000 10000 10000 10000 10000 11111",
    "M": "10001 11011 10101 10101 10001 10001 10001",
    "N": "10001 11001 10101 10011 10001 10001 10001",
    "O": "01110 10001 10001 10001 10001 10001 01110",
    "P": "11110 10001 10001 11110 10000 10000 10000",
    "Q": "01110 10001 10001 10001 10101 10010 01101",
    "R": "11110 10001 10001 11110 10100 10010 10001",
    "S": "01111 10000 10000 01110 00001 00001 11110",
    "T": "11111 00100 00100 00100 00100 00100 00100",
    "U": "10001 10001 10001 10001 10001 10001 01110",
    "V": "10001 10001 10001 10001 10001 01010 00100",
    "W": "10001 10001 10001 10101 10101 10101 01010",
    "X": "10001 10001 01010 00100 01010 10001 10001",
    "Y": "10001 10001 01010 00100 00100 00100 00100",
    "Z": "11111 00001 00010 00100 01000 10000 11111",
    "0": "01110 10001 10011 10101 11001 10001 01110",
    "1": "00100 01100 00100 00100 00100 00100 01110",
    "2": "01110 10001 00001 00010 00100 01000 11111",
    "3": "11110 00001 00001 01110 00001 00001 11110",
    "4": "00010 00110 01010 10010 11111 00010 00010",
    "5": "11111 10000 11110 00001 00001 10001 01110",
    "6": "00110 01000 10000 11110 10001 10001 01110",
    "7": "11111 00001 00010 00100 01000 01000 01000",
    "8": "01110 10001 10001 01110 10001 10001 01110",
    "9": "01110 10001 10001 01111 00001 00010 01100",
    " ": "00000 00000 00000 00000 00000 00000 00000",
    ".": "00000 00000 00000 00000 00000 00110 00110",
    ",": "00000 00000 00000 00000 00110 00100 01000",
    ":": "00000 00110 00110 00000 00110 00110 00000",
    "(": "00010 00100 01000 01000 01000 00100 00010",
    ")": "01000 00100 00010 00010 00010 00100 01000",
    "/": "00001 00010 00010 00100 01000 01000 10000",
    "-": "00000 00000 00000 11111 00000 00000 00000",
    "+": "00000 00100 00100 11111 00100 00100 00000",
    "=": "00000 00000 11111 00000 11111 00000 00000",
    "^": "00100 01110 10101 00100 00100 00100 00100",
    "v": "00100 00100 00100 00100 10101 01110 00100",
}

NEGRO = (0.05, 0.05, 0.05)
VERDE = (0.0, 0.62, 0.2)
ROJO = (0.85, 0.1, 0.1)
NARANJA = (0.95, 0.55, 0.05)
AZUL = (0.1, 0.3, 0.85)
VIOLETA = (0.6, 0.15, 0.7)
TINTAS = {
    forma.ARRIBA: (0.80, 0.90, 1.00),
    forma.FRENTE: (0.82, 1.00, 0.84),
    forma.ABAJO: (1.00, 0.92, 0.78),
    forma.DORSO: (1.00, 0.85, 0.88),
}
NOMBRES = {
    forma.ARRIBA: "CANTO DE ARRIBA",
    forma.FRENTE: "FRENTE",
    forma.ABAJO: "CANTO DE ABAJO",
    forma.DORSO: "DORSO",
}


def texto(lienzo: np.ndarray, x: int, y: int, cadena: str, escala: int, color) -> int:
    """Escribe `cadena` con las letras de 5 x 7 y devuelve el ancho que ocupó."""
    cursor = x
    for letra in cadena.upper():
        filas = LETRAS.get(letra, LETRAS[" "]).split()
        for j, fila in enumerate(filas):
            for i, punto in enumerate(fila):
                if punto == "1":
                    lienzo[
                        y + j * escala : y + (j + 1) * escala,
                        cursor + i * escala : cursor + (i + 1) * escala,
                        :3,
                    ] = color
        cursor += 6 * escala
    return cursor - x


def texto_centrado(lienzo, rect, cadena, escala, color, dy=0) -> None:
    x, y, w, h = rect
    ancho = len(cadena) * 6 * escala - escala
    texto(lienzo, x + (w - ancho) // 2, y + (h - 7 * escala) // 2 + dy, cadena, escala, color)


def borde(lienzo, rect, grosor, color, discontinuo=False) -> None:
    x, y, w, h = rect
    alto, ancho = lienzo.shape[:2]
    for k in range(grosor):
        for xs in range(max(0, x), min(ancho, x + w)):
            if discontinuo and (xs // 16) % 2:
                continue
            for ys in (y + k, y + h - 1 - k):
                if 0 <= ys < alto:
                    lienzo[ys, xs, :3] = color
        for ys in range(max(0, y), min(alto, y + h)):
            if discontinuo and (ys // 16) % 2:
                continue
            for xs in (x + k, x + w - 1 - k):
                if 0 <= xs < ancho:
                    lienzo[ys, xs, :3] = color


def rayado(lienzo, rect, color, paso=14, opacidad=0.55) -> None:
    x, y, w, h = rect
    ys, xs = np.mgrid[0:h, 0:w]
    marca = ((xs + ys) % paso) < 4
    zona = lienzo[y : y + h, x : x + w, :3]
    zona[marca] = zona[marca] * (1 - opacidad) + np.array(color) * opacidad


def pintar(lienzo, rect, color) -> None:
    x, y, w, h = rect
    lienzo[y : y + h, x : x + w, :3] = color


def plantilla(caja, zonas: dict, nombre: str) -> np.ndarray:
    """La plantilla del tamaño de la textura final, con cada zona rotulada."""
    lienzo = np.ones((forma.LIENZO_ALTO, forma.LIENZO_ANCHO, 4), dtype=np.float32)
    lienzo[..., :3] = 0.62
    ys, xs = np.mgrid[0 : forma.LIENZO_ALTO, 0 : forma.LIENZO_ANCHO]
    lienzo[..., :3] = np.where(((xs // 32 + ys // 32) % 2)[..., None] == 0, 0.58, 0.66)
    for panel, z in zonas.items():
        pintar(lienzo, z["sangrado"], tuple(c * 0.75 for c in TINTAS[panel]))
        pintar(lienzo, z["panel"], TINTAS[panel])
    for panel, z in zonas.items():
        x, y, w, h = z["panel"]
        xs0, ys0, ws, hs = z["zona_segura"]
        izquierda = z["afinado_izquierdo"]
        derecha = z["afinado_derecho"]
        for r in (izquierda, derecha):
            rayado(lienzo, r, VIOLETA)
        if panel in (forma.FRENTE, forma.DORSO):
            for r in (z["aleta_izquierda"], z["aleta_derecha"]):
                rayado(lienzo, r, NARANJA, paso=10, opacidad=0.7)
            cuerpo_x0 = z["aleta_izquierda"][0] + z["aleta_izquierda"][2]
            cuerpo_x1 = z["aleta_derecha"][0]
        else:
            cuerpo_x0, cuerpo_x1 = x, x + w
        ancho_cuerpo = cuerpo_x1 - cuerpo_x0
        rayado(lienzo, [cuerpo_x0, y, ancho_cuerpo, ys0 - y], VIOLETA, 22, 0.35)
        rayado(lienzo, [cuerpo_x0, ys0 + hs, ancho_cuerpo, y + h - (ys0 + hs)], VIOLETA, 22, 0.35)
    for panel, z in zonas.items():
        borde(lienzo, z["sangrado"], 3, ROJO, discontinuo=True)
        borde(lienzo, z["panel"], 4, NEGRO)
        borde(lienzo, z["zona_segura"], 4, VERDE)
        for k in ("aleta_izquierda", "aleta_derecha"):
            if k in z:
                borde(lienzo, z[k], 3, NARANJA)
        for k in ("afinado_izquierdo", "afinado_derecho"):
            borde(lienzo, z[k], 2, VIOLETA)
    for panel, z in zonas.items():
        x, y, w, h = z["panel"]
        xs0, ys0, ws, hs = z["zona_segura"]
        texto_centrado(lienzo, z["zona_segura"], NOMBRES[panel], 7, NEGRO, dy=-24)
        texto_centrado(lienzo, z["zona_segura"], "ZONA SEGURA DEL ARTE", 3, VERDE, dy=22)
        medida = f"{ws} X {hs} PX"
        texto_centrado(lienzo, z["zona_segura"], medida, 3, VERDE, dy=58)
        if panel in (forma.FRENTE, forma.DORSO):
            for lado, clave in (("IZQ", "aleta_izquierda"), ("DER", "aleta_derecha")):
                ax, ay, aw, ah = z[clave]
                for j, linea in enumerate(("ALETA", lado)):
                    texto(lienzo, ax + 6, ay + ah // 2 - 30 + j * 24, linea, 2, NEGRO)
            for clave in ("afinado_izquierdo", "afinado_derecho"):
                ax, ay, aw, ah = z[clave]
                texto(lienzo, ax + 6, ay + 10, "AFINADO", 3, VIOLETA)
                texto(lienzo, ax + 6, ay + 36, "SIN ARTE", 3, VIOLETA)
            texto(lienzo, xs0 + 12, y + 8, "HOMBRO DE ARRIBA: SIN ARTE", 3, VIOLETA)
            texto(lienzo, xs0 + 12, y + h - 30, "HOMBRO DE ABAJO: SIN ARTE", 3, VIOLETA)
        else:
            texto(lienzo, xs0 + 12, y + 8, "SIN ARTE", 3, VIOLETA)
        arriba = {
            forma.ARRIBA: "^ ARRIBA DEL PAQUETE. BORDE DE ABAJO = FRENTE",
            forma.FRENTE: "^ ARRIBA DEL PAQUETE",
            forma.ABAJO: "^ BORDE DE ARRIBA = FRENTE. ABAJO DEL PAQUETE",
            forma.DORSO: "^ ARRIBA DEL PAQUETE (SE LEE DESDE ATRAS)",
        }[panel]
        texto(lienzo, x + 8, y + h + 10, arriba, 2, NEGRO)
    titulo = f"{nombre.upper()}  {forma.LIENZO_ANCHO} X {forma.LIENZO_ALTO} PX"
    texto(lienzo, 30, 8, titulo, 3, NEGRO)
    leyenda = "NEGRO=PANEL  VERDE=ZONA SEGURA  NARANJA=ALETA  VIOLETA=AFINADO/HOMBRO  ROJO=SANGRADO"
    texto(lienzo, 30, forma.LIENZO_ALTO - 30, leyenda, 2, NEGRO)
    return lienzo


# ---------------------------------------------------------------------------------------------
# Las piezas


def _roja(rgb):
    return (rgb[..., 0] > 0.6) & (rgb[..., 1] < 0.3) & (rgb[..., 2] < 0.3)


def piezas_de_oremos():
    fuente = Fuente(
        ORIGINALES / "oremos.png",
        (
            (220, 213, 1035, 700),
            (220, 745, 1035, 1030),
            (190, 34, 1062, 167),
            (191, 1071, 1055, 1225),
        ),
        margen=16,
    )

    def arriba_de_la_base(rgb, alfa, x0, y0):
        ys, xs = np.mgrid[0 : alfa.shape[0], 0 : alfa.shape[1]]
        dentro = ((ys + y0) < 575 - (xs + x0 - 300) * 0.25) & ((xs + x0) < 760)
        return (dentro & ~dilatar(es_de_galleta(rgb), 3)).astype(np.float32)

    logo = fuente.pieza("logo", (268, 380, 760, 585), arriba_de_la_base)
    ocupado = np.zeros((694 - 380, 1024 - 268), bool)
    lx, ly = logo.origen
    ocupado[ly - 380 : ly - 380 + logo.alto, lx - 268 : lx - 268 + logo.ancho] = logo.alfa > 0.3
    ocupado = dilatar(ocupado, 1)

    def lo_que_no_es_logo(rgb, alfa, x0, y0):
        alto, ancho = alfa.shape
        tapado = pieza_en(ocupado, (268, 380, 1024, 694), (x0, y0, x0 + ancho, y0 + alto))
        salida = (~tapado).astype(np.float32)
        ys, xs = np.mgrid[0:alto, 0:ancho]
        salida[((xs + x0) >= 792) & ((ys + y0) >= 654)] = 0.0
        return salida

    piezas = [
        ("logo", logo, "El nombre. Siempre entero y sin deformar.", ["frente"]),
        (
            "galleta_con_leche",
            fuente.pieza("galleta", (525, 380, 1008, 694), lo_que_no_es_logo),
            "La galleta con la salpicadura de leche.",
            ["frente"],
        ),
        (
            "fila_de_sellos",
            fuente.pieza("sellos", (372, 221, 994, 376)),
            "Los cuatro sellos de advertencia en fila, juntos.",
            ["frente"],
        ),
    ]
    for i, (a, b) in enumerate(((374, 526), (526, 680), (678, 832), (830, 990)), 1):
        piezas.append(
            (
                f"sello_{i}",
                fuente.pieza(f"sello_{i}", (a, 221, b, 376)),
                "Un sello suelto.",
                ["frente"],
            )
        )
    piezas += [
        (
            "texto_del_sabor",
            fuente.pieza("texto", (262, 640, 520, 696)),
            "Galletitas de cacao con relleno sabor vainilla.",
            ["frente"],
        ),
        (
            "peso_neto",
            fuente.pieza("peso", (792, 654, 1000, 694)),
            "Peso neto 354 g, abajo a la derecha.",
            ["frente"],
        ),
        (
            "dorso_ingredientes",
            fuente.pieza("ingredientes", (533, 775, 812, 910)),
            "Texto de ingredientes.",
            ["dorso"],
        ),
        ("dorso_lema", fuente.pieza("lema", (835, 765, 985, 885)), "El lema del dorso.", ["dorso"]),
        (
            "dorso_tabla_nutricional",
            fuente.pieza("tabla", (275, 770, 515, 985)),
            "Tabla nutricional.",
            ["dorso"],
        ),
        (
            "dorso_codigo_de_barras",
            fuente.pieza("barras", (825, 900, 995, 1008)),
            "Codigo de barras.",
            ["dorso"],
        ),
        (
            "dorso_industria_argentina",
            fuente.pieza("industria", (530, 940, 830, 992)),
            "Bandera, industria argentina y reciclado.",
            ["dorso"],
        ),
        (
            "logo_del_canto",
            fuente.pieza("logo_canto", (422, 48, 725, 150)),
            "El logo como lo dibujo el artista en el canto.",
            ["referencia"],
        ),
        (
            "salpicadura",
            fuente.pieza("salpicadura", (298, 52, 410, 145)),
            "Salpicadura de leche suelta, para el fondo.",
            ["motivo"],
        ),
    ]
    fondos = [
        ("motivo_degrade_azul", fuente.fondo_de_la_zona((220, 213, 1035, 700)), "El degradé del fondo del frente."),
    ]
    prensado = fuente.todo[300:600, 186:226]
    return fuente, piezas, fondos, prensado


def piezas_de_pepito():
    fuente = Fuente(
        ORIGINALES / "pepito.png",
        (
            (212, 248, 1040, 806),
            (140, 840, 1130, 1040),
            (154, 35, 1099, 197),
            (134, 1080, 1119, 1229),
        ),
        criterio=es_fondo_de_pepito,
    )
    region_roja = np.zeros((806 - 248, 1040 - 212), bool)

    def roja_cerca(rgb, alfa, x0, y0):
        alto, ancho = alfa.shape
        roja = dilatar(_roja(rgb), 10)
        return roja.astype(np.float32)

    def sin_lo_rojo(rgb, alfa, x0, y0):
        ys, xs = np.mgrid[0 : alfa.shape[0], 0 : alfa.shape[1]]
        del_cartel = dilatar(_roja(rgb) & (ys + y0 > 636), 12)
        del_logo = ((xs + x0) > 540) & ((ys + y0) < 556)
        return (~(del_cartel | del_logo)).astype(np.float32)

    def logo_mask(rgb, alfa, x0, y0):
        ys, xs = np.mgrid[0 : alfa.shape[0], 0 : alfa.shape[1]]
        linea = 592 - np.maximum(0, (xs + x0) - 590) * 0.17
        no_galleta = ~dilatar(es_de_galleta(rgb) & ~_roja(rgb), 3)
        return (((ys + y0) < linea) & no_galleta).astype(np.float32)

    def cartel_mask(rgb, alfa, x0, y0):
        ys, xs = np.mgrid[0 : alfa.shape[0], 0 : alfa.shape[1]]
        linea = 592 - np.maximum(0, (xs + x0) - 590) * 0.17 - 6
        return (((ys + y0) >= linea) & ~dilatar(es_de_galleta(rgb), 3)).astype(np.float32)

    def galleta_mask(rgb, alfa, x0, y0):
        return dilatar(es_de_galleta(rgb) & ~_roja(rgb), 3).astype(np.float32)

    piezas = [
        ("logo", fuente.pieza("logo", (545, 388, 1012, 596), logo_mask), "El nombre con su subrayado rojo.", ["frente"]),
        (
            "fila_de_sellos",
            fuente.pieza("sellos", (636, 262, 1012, 384)),
            "Los tres sellos de advertencia en fila, juntos.",
            ["frente"],
        ),
        ("sello_1", fuente.pieza("sello_1", (640, 262, 758, 384)), "Un sello suelto.", ["frente"]),
        ("sello_2", fuente.pieza("sello_2", (766, 262, 884, 384)), "Un sello suelto.", ["frente"]),
        ("sello_3", fuente.pieza("sello_3", (892, 262, 1010, 384)), "Un sello suelto.", ["frente"]),
        (
            "personaje",
            fuente.pieza("personaje", (250, 262, 592, 790), sin_lo_rojo),
            "El personaje del paquete, sin el cartel rojo.",
            ["frente"],
        ),
        (
            "cartel_rojo",
            fuente.pieza("cartel_rojo", (252, 636, 508, 775), roja_cerca),
            "Cartel rojo: el sabor de siempre con buena onda.",
            ["frente"],
        ),
        (
            "cartel_de_sabor",
            fuente.pieza("cartel", (588, 552, 825, 705), cartel_mask),
            "Cartel azul oscuro: galletas con chispas de chocolate.",
            ["frente"],
        ),
        (
            "galleta_con_chispas",
            fuente.pieza("galleta", (795, 540, 1004, 738), galleta_mask),
            "La galleta con chispas y las chispas sueltas.",
            ["frente"],
        ),
        ("x3_unidades", fuente.pieza("x3", (900, 650, 1014, 762)), "x3 unidades individuales.", ["frente"]),
        ("peso_neto", fuente.pieza("peso", (822, 728, 905, 790)), "Peso neto 357 g.", ["frente"]),
        (
            "dorso_tarjeta",
            fuente.pieza("tarjeta", (145, 865, 345, 1025)),
            "Tarjeta del dorso con el logo chico.",
            ["dorso"],
        ),
        (
            "dorso_lista",
            fuente.pieza("lista", (415, 843, 695, 1030)),
            "Papel con la lista de ventajas.",
            ["dorso"],
        ),
        (
            "dorso_tabla_nutricional",
            fuente.pieza("tabla", (708, 845, 925, 1025)),
            "Tabla nutricional.",
            ["dorso"],
        ),
        ("dorso_lema", fuente.pieza("lema", (935, 845, 1085, 945)), "El lema del dorso.", ["dorso"]),
        (
            "dorso_codigo_de_barras",
            fuente.pieza("barras", (948, 948, 1112, 1012)),
            "Codigo de barras.",
            ["dorso"],
        ),
        (
            "logo_del_canto",
            fuente.pieza("logo_canto", (385, 50, 610, 160)),
            "El logo como lo dibujo el artista en el canto.",
            ["referencia"],
        ),
        (
            "galleta_del_canto_izquierda",
            fuente.pieza("galleta_i", (228, 60, 340, 180)),
            "Galleta suelta, para el fondo.",
            ["motivo"],
        ),
        (
            "galleta_del_canto_derecha",
            fuente.pieza("galleta_d", (618, 68, 740, 165)),
            "Galleta suelta, para el fondo.",
            ["motivo"],
        ),
    ]
    for i, copo in enumerate(
        copos_de(fuente, ((555, 314, 609, 369), (570, 702, 620, 754), (714, 729, 744, 759), (541, 543, 570, 571))),
        1,
    ):
        piezas.append((f"copo_{i}", copo, "Copo de nieve suelto, motivo del fondo.", ["motivo"]))
    fondos = [
        ("motivo_azul_con_copos", fuente.fondo_de_la_zona((212, 248, 1040, 806)), "El azul con copos del fondo."),
    ]
    prensado = fuente.todo[320:700, 174:212]
    return fuente, piezas, fondos, prensado


def con_alfa(pieza) -> np.ndarray:
    return np.dstack([pieza.rgb, pieza.alfa]).astype(np.float32)


def hoja_de_piezas(entradas, destino: Path) -> None:
    """Todas las piezas juntas, sobre un damero, con su nombre."""
    celda = 300
    columnas = 5
    filas = math.ceil(len(entradas) / columnas)
    hoja = np.ones((filas * (celda + 40) + 10, columnas * (celda + 10) + 10, 4), dtype=np.float32)
    ys, xs = np.mgrid[0 : hoja.shape[0], 0 : hoja.shape[1]]
    hoja[..., :3] = np.where(((xs // 20 + ys // 20) % 2)[..., None] == 0, 0.30, 0.38)
    for i, (nombre, matriz) in enumerate(entradas):
        f, c = divmod(i, columnas)
        x0, y0 = 10 + c * (celda + 10), 10 + f * (celda + 40)
        alto, ancho = matriz.shape[:2]
        escala = min(celda / ancho, celda / alto, 1.0)
        nuevo_ancho, nuevo_alto = max(1, round(ancho * escala)), max(1, round(alto * escala))
        premultiplicada = matriz.copy()
        premultiplicada[..., :3] *= premultiplicada[..., 3:4]
        chica = escalar(premultiplicada, nuevo_ancho, nuevo_alto)
        a = chica[..., 3:4]
        rgb = np.where(a > 1e-4, chica[..., :3] / np.maximum(a, 1e-4), 0)
        zona = hoja[y0 : y0 + nuevo_alto, x0 : x0 + nuevo_ancho, :3]
        zona[...] = zona * (1 - a) + rgb * a
        texto(hoja, x0, y0 + celda + 6, nombre[:24], 2, (1, 1, 1))
        texto(hoja, x0, y0 + celda + 22, f"{ancho} X {alto}", 2, (0.8, 0.9, 1.0))
    escribir(hoja, destino)


def preparar(clave: str, objeto: str, caja, piezas_de) -> dict:
    carpeta = DESTINO / clave.lower()
    (carpeta / "piezas").mkdir(parents=True, exist_ok=True)
    (carpeta / "entrega").mkdir(parents=True, exist_ok=True)
    zonas = forma.zonas(caja)
    imagen = plantilla(caja, zonas, f"{clave}_PAQUETE.PNG")
    escribir(imagen, carpeta / f"plantilla_{clave.lower()}.png")
    fuente, piezas, fondos, prensado = piezas_de()
    registro = []
    para_la_hoja = []
    for nombre, pieza, descripcion, uso in piezas:
        matriz = con_alfa(pieza)
        escribir(matriz, carpeta / "piezas" / f"{nombre}.png")
        para_la_hoja.append((nombre, matriz))
        registro.append(
            {
                "archivo": f"piezas/{nombre}.png",
                "ancho": pieza.ancho,
                "alto": pieza.alto,
                "descripcion": descripcion,
                "uso": uso,
                "origen_en_el_arte_actual": list(pieza.origen),
            }
        )
    for nombre, fondo, descripcion in fondos:
        matriz = np.dstack([fondo, np.ones(fondo.shape[:2], np.float32)])
        escribir(matriz, carpeta / "piezas" / f"{nombre}.png")
        para_la_hoja.append((nombre, matriz))
        registro.append(
            {
                "archivo": f"piezas/{nombre}.png",
                "ancho": fondo.shape[1],
                "alto": fondo.shape[0],
                "descripcion": descripcion + " Sin piezas: sólo el fondo.",
                "uso": ["fondo"],
                "origen_en_el_arte_actual": None,
            }
        )
    matriz = np.dstack([prensado, np.ones(prensado.shape[:2], np.float32)])
    escribir(matriz, carpeta / "piezas" / "prensado_de_la_aleta.png")
    para_la_hoja.append(("prensado_de_la_aleta", matriz))
    registro.append(
        {
            "archivo": "piezas/prensado_de_la_aleta.png",
            "ancho": prensado.shape[1],
            "alto": prensado.shape[0],
            "descripcion": "El prensado de la aleta como lo dibujó el artista: surcos paralelos a "
            "la costura, de afuera hacia adentro.",
            "uso": ["aleta"],
            "origen_en_el_arte_actual": None,
        }
    )
    hoja_de_piezas(para_la_hoja, carpeta / "hoja_de_piezas.png")
    original = "oremos" if clave == "OREMOS" else "pepito"
    shutil.copyfile(ORIGINALES / f"{original}.png", carpeta / "referencia_arte_actual.png")
    datos = {
        "producto": clave,
        "archivo_de_salida": f"{'oremos' if clave == 'OREMOS' else 'pepito'}_paquete.png",
        "lienzo_px": [forma.LIENZO_ANCHO, forma.LIENZO_ALTO],
        "tamano_en_el_juego_px": [forma.LIENZO_ANCHO // 4, forma.LIENZO_ALTO // 4],
        "formato": "PNG RGB de 8 bits, sRGB, sin transparencia",
        "densidad_px_por_metro": forma.densidad(caja),
        "sangrado_px": forma.SANGRADO,
        "separacion_entre_paneles_px": forma.CALLE,
        "paquete_m": {"ancho": round(caja.ancho, 4), "alto": caja.alto, "fondo": round(caja.fondo, 4)},
        "formato_de_cada_rect": "[x, y, ancho, alto] en píxeles, con el origen arriba a la izquierda",
        "zonas": zonas,
        "piezas": registro,
    }
    (carpeta / f"zonas_{clave.lower()}.json").write_text(
        json.dumps(datos, indent=1, ensure_ascii=False), encoding="utf-8"
    )
    return datos


def leeme(datos: dict) -> str:
    o, p = datos["OREMOS"], datos["PEPITO"]

    def tabla(d):
        z = d["zonas"]
        filas = []
        for panel, nombre in (("arriba", "canto de arriba"), ("frente", "frente"), ("abajo", "canto de abajo"), ("dorso", "dorso")):
            s = z[panel]["zona_segura"]
            filas.append(f"| {nombre} | {z[panel]['panel']} | {s} |")
        return "\n".join(filas)

    return f"""# Textura de los paquetes de Oremos y de Pepito

Pintá la textura nueva de los dos paquetes. Hay una carpeta por paquete: `oremos/` y `pepito/`.

## Qué tenés que entregar

| | Oremos | Pepito |
|---|---|---|
| Archivo | `oremos_paquete.png` | `pepito_paquete.png` |
| Dónde | `oremos/entrega/` | `pepito/entrega/` |
| Tamaño | **{o['lienzo_px'][0]} x {o['lienzo_px'][1]} px** | **{p['lienzo_px'][0]} x {p['lienzo_px'][1]} px** |
| Formato | PNG RGB de 8 bits, sRGB, sin transparencia | igual |

El tamaño es exacto. Con otra medida la UV no cae donde tiene que caer y el script de
comprobación se corta. En el juego la textura viaja a {o['tamano_en_el_juego_px'][0]} x
{o['tamano_en_el_juego_px'][1]} px: un cuarto de lado. **Un texto tiene que medir al menos 40 px de alto
en la hoja** para leerse a ese tamaño.

## Qué es cada archivo

- `plantilla_<producto>.png`: la hoja vacía, del tamaño exacto, con cada zona rotulada y su contorno.
  Ponela en una capa de guía. **No va en la entrega.**
- `zonas_<producto>.json`: el rectángulo `[x, y, ancho, alto]` de cada zona, en píxeles, con el origen
  arriba a la izquierda.
- `piezas/`: el arte actual recortado, con transparencia, a su resolución original. Hay una
  `hoja_de_piezas.png` con todas juntas.
- `referencia_arte_actual.png`: el arte que dejó el artista, entero. Es la referencia de marca,
  colores e ilustración.

## La hoja

Cuatro paneles en una columna: **canto de arriba, frente, canto de abajo, dorso**. Todos tienen
**la misma densidad: Oremos {o['densidad_px_por_metro']:.0f} px por metro y Pepito
{p['densidad_px_por_metro']:.0f}**. Un píxel mide lo mismo a lo ancho y a lo alto.

El paquete real mide {o['paquete_m']['ancho']} m de ancho, {o['paquete_m']['fondo']} m de fondo y
{o['paquete_m']['alto']} m (Oremos) o {p['paquete_m']['alto']} m (Pepito) de alto.

Zonas de Oremos, en píxeles:

| Panel | Rectángulo | Zona segura del arte |
|---|---|---|
{tabla(o)}

Zonas de Pepito, en píxeles:

| Panel | Rectángulo | Zona segura del arte |
|---|---|---|
{tabla(p)}

Dentro del **frente** y del **dorso** el JSON da también `aleta_izquierda`, `aleta_derecha`,
`afinado_izquierdo` y `afinado_derecho`. Cada panel tiene su `sangrado`.

- **Zona segura del arte (verde).** Es plana y recta. Todo el arte, el texto, el logo y los sellos
  van acá y nada se corta. Es apaisada, como el envase real.
- **Afinado y hombros (violeta).** El cuerpo se cierra hacia las costuras y se curva arriba y abajo.
  Acá **no va arte**: va el fondo, que sigue sin cortes.
- **Aletas (naranja).** Son los dos cierres, uno a cada lado. La del frente es la franja de cada
  punta del panel del frente, y la del dorso es la de cada punta del panel del dorso.
- **Sangrado (rojo, discontinuo).** Pintá 24 px de más alrededor de cada panel, con el fondo del
  panel. Sirve para que el filtro no mezcle paneles. No va arte importante.
- **Orientación.** Todo panel va con el arriba del paquete hacia arriba de la hoja. El dorso se lee
  desde atrás. El canto de arriba toca el frente por su borde de abajo, y el de abajo toca el frente
  por su borde de arriba: el fondo tiene que seguir de uno a otro sin corte.

## Reglas

1. **Marca de parodia y arte del juego.** Los paquetes son Oremos y Pepito. Mantené el logo, los
   colores y la ilustración del arte actual. **No copies el arte, el logo ni la marca de los
   paquetes reales.** Las dos fotos de `C:/Users/fede_/orca/workspaces/nosefia/referencias/`
   (`paquete_real_galletitas_rellenas.png` y `paquete_real_galletitas_con_chispas.png`) sirven sólo
   para la forma y la composición.
2. **Composición apaisada.** Sellos octogonales negros arriba, en fila, que ocupan el ancho de la zona
   segura. El nombre grande, a la izquierda o centrado. La galleta o el personaje a un costado. El peso
   neto abajo a la derecha. Que acompañe la forma de un paquete apaisado: las piezas no van
   pegadas sobre un plano, van integradas al fondo.
3. **Nada estirado.** Cualquier pieza se escala con **la misma escala en x y en y**. La relación de
   aspecto de cada elemento tiene que ser la del arte actual, con 2 % de tolerancia.
4. **Fondo continuo.** El fondo (el degradé azul de Oremos; el azul con copos y chispas de Pepito) cubre
   toda la hoja y sigue sin cortes de frente a aletas, afinados, hombros, cantos y sangrado. Nada de
   planos lisos ni de bordes de pieza.
5. **Los cantos llevan sólo fondo y motivo.** Se ven de costado, y cualquier pieza se vería cortada.
   Sin logo ni texto.
6. **Prensado recto en las aletas.** Surcos rectos, paralelos a la costura, y el borde de afuera
   recto. **Sin dientes de sierra, sin letras.** Mirá `piezas/prensado_de_la_aleta.png`.
7. **Sin luz pintada.** No pintes sombras, brillos ni degradados de volumen: la luz la pone el juego.
8. **Sin transparencia.** Cada píxel de la hoja es opaco, también las calles entre paneles.

## Cómo se comprueba

Guardá cada PNG en su carpeta `entrega/` y corré, con el `.blend` del juego:

```text
blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 --python .claude/scripts/blender/comprobar_textura_de_paquetes.py
```

Sin argumentos toma `oremos/entrega/oremos_paquete.png` y `pepito/entrega/pepito_paquete.png`.
Arma los renders de comprobación en `comprobacion/`: **de frente, de tres cuartos, en la mano y en
el estante**, a la altura de los ojos del jugador. No cambia el `.blend` del juego.
"""


def main() -> None:
    configurar()
    if not bpy.data.filepath:
        raise SystemExit("falta el .blend: se mide el paquete en su malla")
    DESTINO.mkdir(parents=True, exist_ok=True)
    # La carpeta está dentro del proyecto de Godot: sin esto el editor importa cada PNG y deja un
    # `.import` al lado, que es ruido para quien recibe la carpeta.
    (DESTINO / ".gdignore").write_text("", encoding="utf-8")
    for sobra in DESTINO.rglob("*.import"):
        sobra.unlink()
    datos = {}
    for objeto, (clave, _) in armado.PAQUETES.items():
        caja = armado.caja_del_paquete(bpy.data.objects[objeto], clave)
        piezas = piezas_de_oremos if clave == "OREMOS" else piezas_de_pepito
        datos[clave] = preparar(clave, objeto, caja, piezas)
        d = datos[clave]
        print(f"{clave}: {len(d['piezas'])} piezas, densidad {d['densidad_px_por_metro']}")
    (DESTINO / "LEEME.md").write_text(leeme(datos), encoding="utf-8")
    print(f"listo en {DESTINO}")


if __name__ == "__main__":
    main()

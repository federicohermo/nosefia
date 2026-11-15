"""Pinta la textura de los paquetes de Oremos y de Pepito para su forma de flow pack.

    blender --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_paquetes_de_galletitas.py -- [--aplicar]

Sin `--aplicar` escribe en `reports/paquetes-de-galletitas/`. Con `--aplicar`, en
`assets/source/products-textured/galletitas/`, donde la lee el atlas y la cadena. Es determinista:
las mismas fuentes dan los mismos píxeles. **No toca el arte del artista**: `oremos.png` y
`pepito.png` quedan como están, y son la entrada.

## Qué hace

El arte del artista es un desplegado de caja: un frente apaisado, un dorso, cuatro caras más. El
paquete es un flow pack de frente casi cuadrado, y su UV sale de `lib/paquete_de_galletitas.py`.
Esta herramienta rearma el desplegado para esa forma, con el mismo logo, los mismos colores y la
misma ilustración:

- **El frente** se compone para el cuadrado: los sellos de advertencia arriba en fila, el nombre y
  la galletita, y el peso neto abajo. Cada pieza sale del arte original, recortada contra un fondo
  que se rehace estirando el degradé del original.
- **Los cierres** repiten el prensado de los extremos del frente: franjas de surcos sin letras.
- **El dorso y los cantos** reacomodan los del original a la mitad de densidad: es lo que menos se
  ve.

La hoja sale de 1024 x 576 y viaja a 512 x 288.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import armar_paquetes_de_galletitas as armado  # noqa: E402
from lib import paquete_de_galletitas as forma  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

Rect = tuple[int, int, int, int]

ORIGINALES = RAIZ / "assets/source/products-textured/galletitas"

#: Los píxeles de la hoja que no cubre ningún panel.
FONDO_DE_LA_HOJA = (0.0, 0.12, 0.45)


def leer(ruta: Path) -> np.ndarray:
    """Los píxeles RGBA de un PNG, de arriba a abajo, en 0..1."""
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    try:
        ancho, alto = imagen.size
        datos = np.empty(ancho * alto * 4, dtype=np.float32)
        imagen.pixels.foreach_get(datos)
        return np.ascontiguousarray(datos.reshape(alto, ancho, 4)[::-1])
    finally:
        bpy.data.images.remove(imagen)


def escribir(matriz: np.ndarray, ruta: Path) -> None:
    """Escribe con `Image.save`, que no aplica la transformación de vista de la escena."""
    alto, ancho = matriz.shape[:2]
    imagen = bpy.data.images.new(ruta.name, ancho, alto, alpha=True)
    try:
        imagen.colorspace_settings.name = "sRGB"
        imagen.alpha_mode = "STRAIGHT"
        imagen.pixels.foreach_set(np.ascontiguousarray(matriz[::-1]).reshape(-1))
        imagen.file_format = "PNG"
        imagen.filepath_raw = str(ruta)
        imagen.save()
    finally:
        bpy.data.images.remove(imagen)


def escalar(matriz: np.ndarray, ancho: int, alto: int) -> np.ndarray:
    """Cambia el tamaño de una imagen RGBA con el filtro de Blender, que promedia al achicar."""
    if matriz.shape[1] == ancho and matriz.shape[0] == alto:
        return matriz.copy()
    imagen = bpy.data.images.new("escala", matriz.shape[1], matriz.shape[0], alpha=True)
    try:
        imagen.pixels.foreach_set(np.ascontiguousarray(matriz[::-1]).reshape(-1))
        imagen.scale(ancho, alto)
        datos = np.empty(ancho * alto * 4, dtype=np.float32)
        imagen.pixels.foreach_get(datos)
        return np.ascontiguousarray(datos.reshape(alto, ancho, 4)[::-1])
    finally:
        bpy.data.images.remove(imagen)


def recortar(matriz: np.ndarray, rect: Rect) -> np.ndarray:
    x0, y0, x1, y1 = rect
    return matriz[y0:y1, x0:x1].copy()


def difuminar(matriz: np.ndarray, radio: int) -> np.ndarray:
    """Un promedio móvil separable, con el borde repetido."""
    salida = matriz
    for eje in (0, 1):
        relleno = [(0, 0)] * matriz.ndim
        relleno[eje] = (radio, radio)
        p = np.pad(salida, relleno, mode="edge")
        acumulado = np.cumsum(p, axis=eje, dtype=np.float64)
        cero = np.zeros_like(np.take(acumulado, [0], axis=eje))
        acumulado = np.concatenate([cero, acumulado], axis=eje)
        n = salida.shape[eje]
        salida = (
            np.take(acumulado, range(2 * radio + 1, 2 * radio + 1 + n), axis=eje)
            - np.take(acumulado, range(0, n), axis=eje)
        ) / (2 * radio + 1)
    return salida.astype(np.float32)


def dilatar(mascara: np.ndarray, radio: int) -> np.ndarray:
    salida = mascara.copy()
    alto, ancho = mascara.shape
    p = np.pad(mascara, radio, mode="constant")
    for dy in range(-radio, radio + 1):
        for dx in range(-radio, radio + 1):
            salida |= p[radio + dy : radio + dy + alto, radio + dx : radio + dx + ancho]
    return salida


def es_fondo(rgb: np.ndarray) -> np.ndarray:
    """El azul liso del envase: sin rojo, mucho azul y más azul que verde."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r < 0.06) & (b > 0.35) & (b > g * 1.25)


def rellenar(rgb: np.ndarray, vacio: np.ndarray, paso: int = 4, vueltas: int = 400) -> np.ndarray:
    """Rellena lo marcado en `vacio` con el degradé de lo que lo rodea, difundiéndolo desde el
    borde. Trabaja a 1/`paso` de la resolución, y sube el resultado sin detalle fino."""
    alto, ancho = rgb.shape[:2]
    h, w = alto // paso, ancho // paso
    chica = rgb[: h * paso, : w * paso].reshape(h, paso, w, paso, 3)
    mascara = vacio[: h * paso, : w * paso].reshape(h, paso, w, paso)
    validos = (~mascara).astype(np.float32)
    suma = (chica * validos[..., None]).sum(axis=(1, 3))
    cuenta = validos.sum(axis=(1, 3))
    sabido = cuenta > 0
    valores = np.where(sabido[..., None], suma / np.maximum(cuenta, 1)[..., None], 0.0)
    media = valores[sabido].mean(axis=0)
    valores = np.where(sabido[..., None], valores, media)
    for _ in range(vueltas):
        p = np.pad(valores, ((1, 1), (1, 1), (0, 0)), mode="edge")
        promedio = (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]) / 4
        valores = np.where(sabido[..., None], valores, promedio)
    base = np.zeros((alto, ancho, 4), dtype=np.float32)
    base[..., 3] = 1.0
    grande = escalar(np.dstack([valores, np.ones((h, w), np.float32)]), w * paso, h * paso)
    base[: h * paso, : w * paso] = grande
    base[h * paso :, :] = base[h * paso - 1 : h * paso, :]
    base[:, w * paso :] = base[:, w * paso - 1 : w * paso]
    return base[..., :3]


class Fuente:
    """Un arte original y el fondo sin piezas de cada una de sus zonas, para recortar piezas con
    su transparencia."""

    def __init__(self, ruta: Path, zonas: tuple[Rect, ...]):
        self.todo = leer(ruta)[..., :3]
        self.zonas = {}
        for zona in zonas:
            x0, y0, x1, y1 = zona
            region = self.todo[y0:y1, x0:x1]
            self.zonas[zona] = rellenar(region, dilatar(~es_fondo(region), 10))

    def fondo(self, rect: Rect) -> np.ndarray:
        x0, y0, x1, y1 = rect
        for (zx0, zy0, zx1, zy1), fondo in self.zonas.items():
            if zx0 <= x0 and zy0 <= y0 and x1 <= zx1 and y1 <= zy1:
                return fondo[y0 - zy0 : y1 - zy0, x0 - zx0 : x1 - zx0]
        raise ValueError(f"el recorte {rect} no cae en ninguna zona de fondo")

    def pieza(self, rect: Rect, borrar: tuple[Rect, ...] = ()) -> np.ndarray:
        """El recorte RGBA: opaco donde hay dibujo, transparente donde sólo hay fondo."""
        x0, y0, x1, y1 = rect
        rgb = self.todo[y0:y1, x0:x1].copy()
        fondo = self.fondo(rect)
        alfa = np.clip((np.abs(rgb - fondo).max(axis=2) - 0.07) / 0.14, 0.0, 1.0)
        alfa = np.maximum(alfa, 0.7 * difuminar(alfa, 1))
        for bx0, by0, bx1, by1 in borrar:
            alfa[max(by0 - y0, 0) : max(by1 - y0, 0), max(bx0 - x0, 0) : max(bx1 - x0, 0)] = 0.0
        return np.dstack([rgb, alfa])


def pegar(lienzo: np.ndarray, pieza: np.ndarray, x: int, y: int, escala: float) -> None:
    """Pega una pieza RGBA sobre el lienzo, escalada, con su transparencia."""
    alto, ancho = pieza.shape[:2]
    nuevo_ancho, nuevo_alto = max(1, round(ancho * escala)), max(1, round(alto * escala))
    premultiplicada = pieza.copy()
    premultiplicada[..., :3] *= premultiplicada[..., 3:4]
    chica = escalar(premultiplicada, nuevo_ancho, nuevo_alto)
    alfa = chica[..., 3:4]
    rgb = np.where(alfa > 1e-4, chica[..., :3] / np.maximum(alfa, 1e-4), 0.0)
    destino = lienzo[y : y + nuevo_alto, x : x + nuevo_ancho]
    h, w = destino.shape[:2]
    destino[..., :3] = destino[..., :3] * (1 - alfa[:h, :w]) + rgb[:h, :w] * alfa[:h, :w]


def franja_de_cierre(fuente: Fuente, columnas: tuple[int, int], filas: tuple[int, int],
                     ancho: int, alto: int) -> np.ndarray:
    """La franja prensada de un cierre: el promedio vertical de los surcos del original, de
    afuera hacia adentro, repetido a lo alto con un leve moteado."""
    perfil = fuente.todo[filas[0] : filas[1], columnas[0] : columnas[1]].mean(axis=0)
    perfil = np.dstack([perfil[None], np.ones((1, perfil.shape[0], 1), np.float32)])
    franja = escalar(perfil, ancho, 1)
    franja = np.repeat(franja, alto, axis=0)
    azar = np.random.default_rng(7).normal(0.0, 0.012, (alto, 1, 1)).astype(np.float32)
    franja[..., :3] = np.clip(franja[..., :3] + azar, 0, 1)
    return franja


def franja_del_dorso(fuente: Fuente, columnas: tuple[int, int], filas: tuple[int, int],
                     rects: dict[str, Rect]) -> np.ndarray:
    _, _, ancho, alto = rects[forma.DORSO]
    return franja_de_cierre(fuente, columnas, filas, round(ancho * forma.FRANJA_DEL_CIERRE), alto)


def panel_base(ancho: int, alto: int, fondo: np.ndarray) -> np.ndarray:
    base = np.zeros((alto, ancho, 4), dtype=np.float32)
    base[..., 3] = 1.0
    opaco = np.dstack([fondo, np.ones(fondo.shape[:2], np.float32)])
    base[..., :3] = escalar(opaco, ancho, alto)[..., :3]
    return base


def con_cierres(
    panel: np.ndarray, franja_izquierda: np.ndarray, franja_derecha: np.ndarray
) -> None:
    ancho_izq, ancho_der = franja_izquierda.shape[1], franja_derecha.shape[1]
    panel[:, :ancho_izq] = franja_izquierda
    panel[:, panel.shape[1] - ancho_der :] = franja_derecha


def poner_el_panel(hoja: np.ndarray, panel: np.ndarray, rect: Rect) -> None:
    """Pone un panel en la hoja y repite sus bordes `CALLE / 2` píxeles hacia afuera: el filtro y
    los primeros mips no mezclan el panel con el de al lado."""
    x, y, ancho, alto = rect
    margen = forma.CALLE // 2
    relleno = np.pad(panel, ((margen, margen), (margen, margen), (0, 0)), mode="edge")
    hoja[y - margen : y + alto + margen, x - margen : x + ancho + margen] = relleno


def estirar_el_degrade(fuente: Fuente, rect: Rect, ancho: int, alto: int) -> np.ndarray:
    return escalar(
        np.dstack([fuente.fondo(rect), np.ones(fuente.fondo(rect).shape[:2], np.float32)]),
        ancho,
        alto,
    )[..., :3]


def paneles_secundarios(fuente: Fuente, dorso: dict, arriba: tuple, abajo: tuple,
                        rects: dict[str, Rect], franjas: dict[str, np.ndarray]) -> dict:
    """El dorso y los cantos, a la mitad de densidad, como piezas del original."""
    paneles = {}
    _, _, ancho, alto = rects[forma.DORSO]
    cierre = franjas[forma.DORSO]
    panel = panel_base(ancho, alto, estirar_el_degrade(fuente, dorso["fondo"], ancho, alto))
    for rect, escala, (x, y) in dorso["piezas"]:
        pegar(panel, fuente.pieza(rect), x, y, escala)
    con_cierres(panel, cierre, cierre[:, ::-1])
    paneles[forma.DORSO] = panel
    for nombre, (rect, escala, desfase) in ((forma.ARRIBA, arriba), (forma.ABAJO, abajo)):
        _, _, ancho, alto = rects[nombre]
        x0, y0, x1, y1 = rect
        tira = np.dstack([fuente.todo[y0:y1, x0:x1], np.ones((y1 - y0, x1 - x0), np.float32)])
        chica = escalar(tira, round((x1 - x0) * escala), round((y1 - y0) * escala))
        panel = np.zeros((alto, ancho, 4), dtype=np.float32)
        arriba_o_abajo = (alto - chica.shape[0]) // 2 + desfase
        sobra_arriba = max(arriba_o_abajo, 0)
        sobra_abajo = max(alto - chica.shape[0] - arriba_o_abajo, 0)
        sobra_a_la_derecha = max(ancho - chica.shape[1], 0)
        panel[...] = np.pad(
            chica[:, :ancho],
            ((sobra_arriba, sobra_abajo), (0, sobra_a_la_derecha), (0, 0)),
            mode="edge",
        )[:alto, :ancho]
        paneles[nombre] = panel
    return paneles


def oremos(rects: dict[str, Rect]) -> dict[str, np.ndarray]:
    fuente = Fuente(ORIGINALES / "oremos.png", ((220, 213, 1035, 700), (220, 745, 1035, 1030)))
    _, _, ancho, alto = rects[forma.FRENTE]
    cierre_ancho = round(ancho * forma.FRANJA_DEL_CIERRE)
    cuerpo = ancho - 2 * cierre_ancho
    franja = franja_de_cierre(fuente, (186, 226), (300, 600), cierre_ancho, alto)
    panel = panel_base(ancho, alto, estirar_el_degrade(fuente, (220, 213, 1035, 700), ancho, alto))
    sellos = (370, 214, 994, 380)
    heroe = (268, 380, 1024, 694)
    texto = (262, 640, 520, 696)
    peso = (786, 654, 1002, 698)
    margen = 26
    escala_sellos = 0.84
    ancho_sellos = round((sellos[2] - sellos[0]) * escala_sellos)
    alto_sellos = round((sellos[3] - sellos[1]) * escala_sellos)
    x_sellos = cierre_ancho + (cuerpo - ancho_sellos) // 2
    pegar(panel, fuente.pieza(sellos), x_sellos, margen, escala_sellos)
    escala_heroe = cuerpo / (heroe[2] - heroe[0])
    pegar(panel, fuente.pieza(heroe, borrar=(texto, peso)), cierre_ancho,
          margen + alto_sellos + 30, escala_heroe)
    alto_peso = round((peso[3] - peso[1]) * 0.9)
    alto_texto = round((texto[3] - texto[1]) * 0.8)
    pegar(panel, fuente.pieza(texto), cierre_ancho + 14, alto - margen - alto_texto, 0.8)
    pegar(panel, fuente.pieza(peso), ancho - cierre_ancho - 14 - round((peso[2] - peso[0]) * 0.9),
          alto - margen - alto_peso, 0.9)
    con_cierres(panel, franja, franja[:, ::-1])
    secundarios = paneles_secundarios(
        fuente,
        {
            "fondo": (220, 745, 1035, 1030),
            "piezas": (
                ((533, 775, 812, 910), 0.5, (34, 14)),
                ((835, 765, 985, 885), 0.5, (184, 12)),
                ((275, 770, 515, 985), 0.5, (34, 96)),
                ((825, 900, 995, 1008), 0.5, (164, 96)),
                ((530, 940, 830, 992), 0.4, (150, 152)),
            ),
        },
        ((400, 48, 755, 158), 0.75, 0),
        ((395, 1086, 750, 1212), 0.75, 0),
        rects,
        {forma.DORSO: franja_del_dorso(fuente, (186, 226), (300, 600), rects)},
    )
    secundarios[forma.FRENTE] = panel
    return secundarios


def pepito(rects: dict[str, Rect]) -> dict[str, np.ndarray]:
    fuente = Fuente(ORIGINALES / "pepito.png", ((212, 248, 1040, 806), (140, 840, 1130, 1040)))
    _, _, ancho, alto = rects[forma.FRENTE]
    cierre_ancho = round(ancho * forma.FRANJA_DEL_CIERRE)
    cuerpo = ancho - 2 * cierre_ancho
    franja = franja_de_cierre(fuente, (174, 212), (320, 700), cierre_ancho, alto)
    heroe = (270, 248, 1020, 788)
    escala = cuerpo / (heroe[2] - heroe[0])
    alto_heroe = round((heroe[3] - heroe[1]) * escala)
    arriba = (alto - alto_heroe) // 2
    panel = np.zeros((alto, ancho, 4), dtype=np.float32)
    panel[..., 3] = 1.0
    imagen = np.dstack([fuente.todo[heroe[1] : heroe[3], heroe[0] : heroe[2]],
                        np.ones((heroe[3] - heroe[1], heroe[2] - heroe[0]), np.float32)])
    chica = escalar(imagen, cuerpo, alto_heroe)
    panel[arriba : arriba + alto_heroe, cierre_ancho : cierre_ancho + cuerpo] = chica
    for desde, hasta, fila in ((0, arriba, 0), (arriba + alto_heroe, alto, alto_heroe - 1)):
        borde = difuminar(chica[fila : fila + 1, :, :3].astype(np.float32), 12)
        panel[desde:hasta, cierre_ancho : cierre_ancho + cuerpo, :3] = borde
    panel[:, :cierre_ancho, :3] = panel[:, cierre_ancho : cierre_ancho + 1, :3]
    borde = ancho - cierre_ancho
    panel[:, borde:, :3] = panel[:, borde - 1 : borde, :3]
    con_cierres(panel, franja, franja[:, ::-1])
    secundarios = paneles_secundarios(
        fuente,
        {
            "fondo": (140, 840, 1130, 1040),
            "piezas": (
                ((145, 865, 345, 1025), 0.42, (34, 14)),
                ((415, 843, 695, 1030), 0.42, (122, 12)),
                ((708, 845, 925, 1025), 0.42, (34, 110)),
                ((935, 845, 1085, 945), 0.42, (130, 110)),
                ((948, 948, 1112, 1012), 0.42, (130, 160)),
            ),
        },
        ((305, 48, 660, 190), 0.75, 0),
        ((270, 1095, 625, 1215), 0.75, 0),
        rects,
        {forma.DORSO: franja_del_dorso(fuente, (174, 212), (320, 700), rects)},
    )
    secundarios[forma.FRENTE] = panel
    return secundarios


def nombre_del_original(objeto: str) -> str:
    return {"oremos-col": "oremos.png", "pepitos2-col.025": "pepito.png"}[objeto]


PRODUCTOS = {
    "oremos-col": ("oremos_paquete.png", oremos),
    "pepitos2-col.025": ("pepito_paquete.png", pepito),
}


def hoja_comparativa(filas: list[tuple[np.ndarray, np.ndarray]], destino: Path) -> None:
    """La textura de hoy a la izquierda y la nueva a la derecha, una fila por paquete."""
    alto = 600
    calle = 24
    anchos = [
        (round(a.shape[1] * alto / a.shape[0]), round(b.shape[1] * alto / b.shape[0]))
        for a, b in filas
    ]
    ancho = max(x + y for x, y in anchos) + 3 * calle
    hoja = np.zeros((len(filas) * (alto + calle) + calle, ancho, 4), dtype=np.float32)
    hoja[..., :3] = 0.08
    hoja[..., 3] = 1.0
    for i, ((actual, nueva), (ancho_a, ancho_n)) in enumerate(zip(filas, anchos)):
        y = calle + i * (alto + calle)
        hoja[y : y + alto, calle : calle + ancho_a] = escalar(actual, ancho_a, alto)
        x = 2 * calle + ancho_a
        hoja[y : y + alto, x : x + ancho_n] = escalar(nueva, ancho_n, alto)
    escribir(hoja, destino)


def main() -> None:
    configurar()
    aplicar = "--aplicar" in sys.argv
    carpeta = ORIGINALES if aplicar else RAIZ / "reports/paquetes-de-galletitas"
    carpeta.mkdir(parents=True, exist_ok=True)
    if bpy.data.filepath:
        cajas = {n: armado.caja_del_cubo(bpy.data.objects[n]) for n in PRODUCTOS}
    else:
        raise SystemExit("falta el .blend: se mide el tamaño de cada paquete en su malla")
    comparadas: list[tuple[np.ndarray, np.ndarray]] = []
    for nombre, (archivo, componer) in PRODUCTOS.items():
        objeto = bpy.data.objects[nombre]
        x0, x1, y0, y1, z0, z1 = cajas[nombre]
        caja = forma.Caja(
            (y1 - y0) * objeto.scale.y, (x1 - x0) * objeto.scale.x, (z1 - z0) * objeto.scale.z
        )
        rects = forma.desplegado(caja)
        paneles = componer(rects)
        hoja = np.zeros((forma.LIENZO_ALTO, forma.LIENZO_ANCHO, 4), dtype=np.float32)
        hoja[..., :3] = FONDO_DE_LA_HOJA
        hoja[..., 3] = 1.0
        for panel, rect in rects.items():
            poner_el_panel(hoja, paneles[panel], rect)
        escribir(hoja, carpeta / archivo)
        print(f"{archivo}: {hoja.shape[1]}x{hoja.shape[0]} en {carpeta}")
        original = nombre_del_original(nombre)
        comparadas.append((leer(ORIGINALES / original), hoja))
    reporte = RAIZ / "reports/paquetes-de-galletitas"
    reporte.mkdir(parents=True, exist_ok=True)
    hoja_comparativa(comparadas, reporte / "hoja_de_texturas.png")


if __name__ == "__main__":
    main()

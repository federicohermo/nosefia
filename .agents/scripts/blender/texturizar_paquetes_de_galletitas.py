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

- **El frente** se compone para el cuadrado: los sellos de advertencia arriba en una fila, el
  nombre y la galletita, y el peso neto abajo. Cada pieza (sellos, logo, galletita, personaje,
  cartel, peso) se recorta del arte original con su transparencia y se pone **con una sola escala
  en x y en y**: nada se estira. El fondo es el del propio arte, el degradé de Oremos o el azul con
  copos y chispas de Pepito, repetido en espejo: nunca un plano liso.
- **Los cierres** repiten el prensado de los extremos del frente: franjas de surcos sin letras.
- **El dorso** reacomoda sus piezas con el mismo criterio, a la mitad de densidad. **Los cantos**
  llevan sólo el fondo: se ven de costado, y cualquier pieza se vería cortada.
- **`composicion_<producto>.json`**, en `reports/`, dice dónde cayó cada pieza. Lo lee
  `verificar_paquetes_de_galletitas.py`, que mide sobre la malla que nada quedó estirado.

La hoja sale de 1024 x 576 y viaja a 512 x 288.
"""

import json
import math
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


def es_fondo_de_pepito(rgb: np.ndarray) -> np.ndarray:
    """El azul de Pepito, con sus copos: claro y verdoso a veces, nunca rojo ni oscuro."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (b > 0.55) & (b > g * 1.1) & (b > r * 1.4)


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


class Pieza:
    """Un recorte del arte original: sus píxeles, su transparencia y de dónde salió."""

    def __init__(self, nombre: str, rgb: np.ndarray, alfa: np.ndarray, origen: tuple[int, int]):
        self.nombre = nombre
        self.rgb = rgb
        self.alfa = alfa
        self.origen = origen

    @property
    def alto(self) -> int:
        return self.rgb.shape[0]

    @property
    def ancho(self) -> int:
        return self.rgb.shape[1]


class Fuente:
    """Un arte original y el fondo sin piezas de cada una de sus zonas, para recortar piezas con
    su transparencia."""

    def __init__(self, ruta: Path, zonas: tuple[Rect, ...], criterio=es_fondo, margen: int = 10):
        self.todo = leer(ruta)[..., :3]
        self.zonas = {}
        self.vacios = {}
        for zona in zonas:
            x0, y0, x1, y1 = zona
            region = self.todo[y0:y1, x0:x1]
            vacio = dilatar(~criterio(region), margen)
            self.vacios[zona] = vacio
            self.zonas[zona] = rellenar(region, vacio)

    def zona_de(self, rect: Rect) -> tuple[Rect, np.ndarray]:
        x0, y0, x1, y1 = rect
        for zona, fondo in self.zonas.items():
            zx0, zy0, zx1, zy1 = zona
            if zx0 <= x0 and zy0 <= y0 and x1 <= zx1 and y1 <= zy1:
                return zona, fondo
        raise ValueError(f"el recorte {rect} no cae en ninguna zona de fondo")

    def fondo_de_la_zona(self, zona: Rect) -> np.ndarray:
        return self.zonas[zona]

    def fondo(self, rect: Rect) -> np.ndarray:
        x0, y0, x1, y1 = rect
        (zx0, zy0, _, _), fondo = self.zona_de(rect)
        return fondo[y0 - zy0 : y1 - zy0, x0 - zx0 : x1 - zx0]

    def alfa(self, rect: Rect) -> np.ndarray:
        """Qué tanto dibujo hay en cada píxel: la diferencia contra el fondo sin piezas."""
        x0, y0, x1, y1 = rect
        rgb = self.todo[y0:y1, x0:x1]
        diferencia = np.abs(rgb - self.fondo(rect)).max(axis=2)
        alfa = np.clip((diferencia - 0.07) / 0.14, 0.0, 1.0)
        return np.maximum(alfa, 0.7 * difuminar(alfa, 1))

    def pieza(self, nombre: str, rect: Rect, mascara=None) -> Pieza:
        """El recorte de `rect`, ajustado a lo que tiene dibujo. `mascara(rgb, alfa, x0, y0)` puede
        apagar los píxeles que son de otra pieza."""
        x0, y0, x1, y1 = rect
        rgb = self.todo[y0:y1, x0:x1].copy()
        alfa = self.alfa(rect)
        if mascara is not None:
            alfa = alfa * mascara(rgb, alfa, x0, y0)
        filas = np.where(alfa.max(axis=1) > 0.05)[0]
        columnas = np.where(alfa.max(axis=0) > 0.05)[0]
        if not len(filas):
            raise ValueError(f"la pieza {nombre} no tiene dibujo")
        arriba, abajo = filas[0], filas[-1] + 1
        izquierda, derecha = columnas[0], columnas[-1] + 1
        return Pieza(
            nombre,
            rgb[arriba:abajo, izquierda:derecha],
            alfa[arriba:abajo, izquierda:derecha],
            (x0 + int(izquierda), y0 + int(arriba)),
        )


def reflejar(indices: np.ndarray, largo: int) -> np.ndarray:
    resto = np.mod(indices, 2 * largo)
    return np.where(resto >= largo, 2 * largo - 1 - resto, resto)


def tapizar(fondo: np.ndarray, escala: float, ancho: int, alto: int) -> np.ndarray:
    """El fondo de un panel: el de la zona del original, con su motivo, a una sola escala y
    repetido en espejo hasta cubrirlo. Nunca un plano liso."""
    h, w = fondo.shape[:2]
    chico = escalar(
        np.dstack([fondo, np.ones((h, w), np.float32)]), round(w * escala), round(h * escala)
    )[..., :3]
    h, w = chico.shape[:2]
    columnas = reflejar(np.arange(ancho) - (ancho - w) // 2, w)
    filas = reflejar(np.arange(alto) - (alto - h) // 2, h)
    return chico[np.ix_(filas, columnas)]


class Lienzo:
    """Un panel en construcción y el registro de dónde cayó cada pieza."""

    def __init__(self, panel: str, fondo: np.ndarray, rect: Rect, escala_del_fondo: float,
                 registro: list):
        self.panel = panel
        self.rect = rect
        self.ancho, self.alto = rect[2], rect[3]
        self.rgba = np.ones((self.alto, self.ancho, 4), dtype=np.float32)
        self.rgba[..., :3] = tapizar(fondo, escala_del_fondo, self.ancho, self.alto)
        self.registro = registro

    @staticmethod
    def tamano(pieza: Pieza, escala: float) -> tuple[int, int]:
        """El tamaño en píxeles que más se acerca a la escala sin deformar la pieza: de los cuatro
        redondeos posibles, el de relación de aspecto más parecida a la del recorte."""
        aspecto = pieza.ancho / pieza.alto
        candidatos = [
            (max(1, ancho), max(1, alto))
            for ancho in (math.floor(pieza.ancho * escala), math.ceil(pieza.ancho * escala))
            for alto in (math.floor(pieza.alto * escala), math.ceil(pieza.alto * escala))
        ]
        return min(candidatos, key=lambda c: abs(c[0] / c[1] / aspecto - 1))

    def poner(self, pieza: Pieza, x: int, y: int, escala: float) -> tuple[int, int, int, int]:
        """Pone la pieza con una sola escala en x y en y. Devuelve el rectángulo que ocupa."""
        ancho, alto = self.tamano(pieza, escala)
        if x < 0 or y < 0 or x + ancho > self.ancho or y + alto > self.alto:
            raise ValueError(
                f"{pieza.nombre} se sale del panel {self.panel}: {(x, y, ancho, alto)} en "
                f"{self.ancho}x{self.alto}"
            )
        premultiplicada = np.dstack([pieza.rgb * pieza.alfa[..., None], pieza.alfa])
        chica = escalar(premultiplicada, ancho, alto)
        alfa = chica[..., 3:4]
        rgb = np.where(alfa > 1e-4, chica[..., :3] / np.maximum(alfa, 1e-4), 0.0)
        destino = self.rgba[y : y + alto, x : x + ancho, :3]
        destino[...] = destino * (1 - alfa) + rgb * alfa
        self.registro.append(
            {
                "panel": self.panel,
                "pieza": pieza.nombre,
                "rect_en_el_panel": [x, y, ancho, alto],
                "rect_en_la_hoja": [self.rect[0] + x, self.rect[1] + y, ancho, alto],
                "tamano_original": [pieza.ancho, pieza.alto],
                "escala": escala,
            }
        )
        return x, y, ancho, alto

    def con_cierres(
        self, fuente: "Fuente", columnas: tuple[int, int], filas: tuple[int, int]
    ) -> None:
        """Pone en los extremos las franjas prensadas, del ancho que mide el cierre."""
        ancho_del_cierre = round(forma.FRANJA_DEL_CIERRE * self.ancho)
        franja = franja_de_cierre(fuente, columnas, filas, ancho_del_cierre, self.alto)
        self.rgba[:, :ancho_del_cierre] = franja
        self.rgba[:, self.ancho - ancho_del_cierre :] = franja[:, ::-1]


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


def poner_el_panel(hoja: np.ndarray, panel: np.ndarray, rect: Rect) -> None:
    """Pone un panel en la hoja y repite sus bordes `CALLE / 2` píxeles hacia afuera: el filtro y
    los primeros mips no mezclan el panel con el de al lado."""
    x, y, ancho, alto = rect
    margen = forma.CALLE // 2
    relleno = np.pad(panel, ((margen, margen), (margen, margen), (0, 0)), mode="edge")
    hoja[y - margen : y + alto + margen, x - margen : x + ancho + margen] = relleno


def copos_de(fuente: Fuente, rects: tuple[Rect, ...]) -> list[Pieza]:
    """Los copos de nieve del original: celeste claro, sin nada alrededor."""
    copos = []
    for i, rect in enumerate(rects):
        x0, y0, x1, y1 = rect
        rgb = fuente.todo[y0:y1, x0:x1].copy()
        copo = (rgb[..., 0] < 0.43) & (rgb[..., 1] > 0.5) & (rgb[..., 2] > 0.85)
        alfa = np.maximum(copo.astype(np.float32), 0.6 * difuminar(copo.astype(np.float32), 1))
        copos.append(Pieza(f"copo_{i}", rgb, alfa, (x0, y0)))
    return copos


def sembrar(lienzo: Lienzo, copos: list[Pieza], cantidad: int, escala: float, semilla: int) -> None:
    """Reparte copos por el fondo del panel, parejos y sin repetir el mismo en fila. No entran en
    el registro: son fondo, no piezas de arte."""
    azar = np.random.default_rng(semilla)
    for i in range(cantidad):
        copo = copos[i % len(copos)]
        factor = escala * azar.uniform(0.8, 1.25)
        ancho, alto = round(copo.ancho * factor), round(copo.alto * factor)
        x = int(azar.integers(4, max(5, lienzo.ancho - ancho - 4)))
        y = int(azar.integers(4, max(5, lienzo.alto - alto - 4)))
        rgb = copo.rgb if azar.random() < 0.5 else copo.rgb[:, ::-1]
        alfa = copo.alfa if (rgb is copo.rgb) else copo.alfa[:, ::-1]
        premultiplicada = np.dstack([rgb * alfa[..., None], alfa])
        chica = escalar(premultiplicada, ancho, alto)
        a = chica[..., 3:4]
        destino = lienzo.rgba[y : y + alto, x : x + ancho, :3]
        destino[...] = destino * (1 - a * 0.85) + chica[..., :3] * 0.85


def centrada(contenedor: int, pieza: int) -> int:
    return (contenedor - pieza) // 2


def es_de_galleta(rgb: np.ndarray) -> np.ndarray:
    """Marrón y tostado: no el azul, el blanco ni el rojo."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    tostado = (r > 0.12) & (r > b + 0.04) & ~((r > 0.6) & (g < 0.3) & (b < 0.3))
    return tostado | (rgb.max(axis=2) < 0.2)


def pieza_en(registro_zona: np.ndarray, zona: Rect, rect: Rect) -> np.ndarray:
    x0, y0, x1, y1 = rect
    return registro_zona[y0 - zona[1] : y1 - zona[1], x0 - zona[0] : x1 - zona[0]]


def oremos(rects: dict[str, Rect], registro: list) -> dict[str, np.ndarray]:
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
        """El logo es lo que queda sobre la recta que roza su base, sin la galleta."""
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
        ys, xs = np.mgrid[0 : alfa.shape[0], 0 : alfa.shape[1]]
        salida[((xs + x0) >= 792) & ((ys + y0) >= 654)] = 0.0
        return salida

    galleta = fuente.pieza("galleta", (525, 380, 1024, 694), lo_que_no_es_logo)
    sellos = fuente.pieza("sellos", (370, 214, 994, 380))
    texto = fuente.pieza("texto", (262, 640, 520, 696))
    peso = fuente.pieza("peso", (792, 654, 1000, 694))

    fondo = fuente.fondo_de_la_zona((220, 213, 1035, 700))
    frente = Lienzo(forma.FRENTE, fondo, rects[forma.FRENTE], 0.8, registro)
    centro = frente.ancho // 2
    util = 430
    izquierda = centro - util // 2
    escala_de_los_sellos = util / sellos.ancho
    y = 14
    _, y_sellos, _, alto_sellos = frente.poner(
        sellos, centro - round(sellos.ancho * escala_de_los_sellos) // 2, y, escala_de_los_sellos
    )
    y = y_sellos + alto_sellos + 12
    _, y_logo, _, alto_logo = frente.poner(logo, izquierda, y, 0.82)
    escala_galleta = 0.62
    frente.poner(
        galleta, izquierda + util - round(galleta.ancho * escala_galleta), y_logo + alto_logo - 38,
        escala_galleta,
    )
    base = frente.alto - 16
    frente.poner(texto, izquierda, base - round(texto.alto * 0.6), 0.6)
    x_peso = izquierda + util - round(peso.ancho * 0.75)
    frente.poner(peso, x_peso, base - round(peso.alto * 0.75), 0.75)
    frente.con_cierres(fuente, (186, 226), (300, 600))
    paneles = {forma.FRENTE: frente.rgba}

    fondo = fuente.fondo_de_la_zona((220, 745, 1035, 1030))
    dorso = Lienzo(forma.DORSO, fondo, rects[forma.DORSO], 0.5, registro)
    ingredientes = fuente.pieza("ingredientes", (533, 775, 812, 910))
    lema = fuente.pieza("lema", (835, 765, 985, 885))
    tabla = fuente.pieza("tabla_nutricional", (275, 770, 515, 985))
    barras = fuente.pieza("codigo_de_barras", (825, 900, 995, 1008))
    sello = fuente.pieza("industria", (530, 940, 830, 992))
    e = 0.45
    x0 = centrada(dorso.ancho, 232)
    dorso.poner(ingredientes, x0, 18, e)
    dorso.poner(lema, x0 + round(ingredientes.ancho * e) + 14, 18, e)
    y2 = 18 + round(ingredientes.alto * e) + 14
    dorso.poner(tabla, x0, y2, e)
    dorso.poner(barras, x0 + round(tabla.ancho * e) + 14, y2, e)
    dorso.poner(sello, x0, y2 + round(tabla.alto * e) + 10, e)
    dorso.con_cierres(fuente, (186, 226), (300, 600))
    paneles[forma.DORSO] = dorso.rgba

    # Los cantos llevan el degradé y nada más: se ven de costado, y una pieza se vería cortada.
    zonas = {forma.ARRIBA: (190, 34, 1062, 167), forma.ABAJO: (191, 1071, 1055, 1225)}
    for nombre, zona in zonas.items():
        fondo = fuente.fondo_de_la_zona(zona)
        paneles[nombre] = Lienzo(nombre, fondo, rects[nombre], 0.5, registro).rgba
    return paneles


def pepito(rects: dict[str, Rect], registro: list) -> dict[str, np.ndarray]:
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

    def sin_el_logo(rgb, alfa, x0, y0):
        ys, xs = np.mgrid[0 : alfa.shape[0], 0 : alfa.shape[1]]
        return (~(((xs + x0) > 540) & ((ys + y0) < 560))).astype(np.float32)

    def sin_el_retrato(rgb, alfa, x0, y0):
        ys, xs = np.mgrid[0 : alfa.shape[0], 0 : alfa.shape[1]]
        return (~(((xs + x0) < 592) & ((ys + y0) >= 560))).astype(np.float32)

    sellos = fuente.pieza("sellos", (636, 256, 1014, 392))
    retrato = fuente.pieza("personaje", (250, 262, 592, 790), sin_el_logo)
    resto = fuente.pieza("logo_galleta_y_peso", (540, 390, 1012, 790), sin_el_retrato)

    fondo = fuente.fondo_de_la_zona((212, 248, 1040, 806))
    frente = Lienzo(forma.FRENTE, fondo, rects[forma.FRENTE], 0.55, registro)
    copos = copos_de(
        fuente,
        ((555, 314, 609, 369), (570, 702, 620, 754), (714, 729, 744, 759), (541, 543, 570, 571)),
    )
    sembrar(frente, copos, 70, 0.55, 3)
    centro = frente.ancho // 2
    util = 430
    escala_de_los_sellos = util / sellos.ancho
    _, y_sellos, _, alto_sellos = frente.poner(
        sellos, centro - round(sellos.ancho * escala_de_los_sellos) // 2, 14, escala_de_los_sellos
    )
    # El personaje y el resto del arte siguen en su lugar uno del otro, a una sola escala.
    escala = 0.55
    x_base = centro - round((1012 - 250) * escala) // 2
    y_base = y_sellos + alto_sellos + 12
    for pieza in (retrato, resto):
        frente.poner(
            pieza,
            x_base + round((pieza.origen[0] - 250) * escala),
            y_base + round((pieza.origen[1] - 262) * escala),
            escala,
        )
    frente.con_cierres(fuente, (174, 212), (320, 700))
    paneles = {forma.FRENTE: frente.rgba}

    fondo = fuente.fondo_de_la_zona((140, 840, 1130, 1040))
    dorso = Lienzo(forma.DORSO, fondo, rects[forma.DORSO], 0.45, registro)
    sembrar(dorso, copos, 22, 0.45, 5)
    tarjeta = fuente.pieza("tarjeta", (145, 865, 345, 1025))
    papel = fuente.pieza("lista", (415, 843, 695, 1030))
    tabla = fuente.pieza("tabla_nutricional", (708, 845, 925, 1025))
    lema = fuente.pieza("lema", (935, 845, 1085, 945))
    barras = fuente.pieza("codigo_de_barras", (948, 948, 1112, 1012))
    e = 0.45
    x0 = centrada(dorso.ancho, 232)
    dorso.poner(tarjeta, x0, 20, e)
    dorso.poner(papel, x0 + round(tarjeta.ancho * e) + 10, 20, e)
    y2 = 20 + round(papel.alto * e) + 16
    dorso.poner(tabla, x0, y2, e)
    x_derecha = x0 + round(tabla.ancho * e) + 14
    dorso.poner(lema, x_derecha, y2, e)
    dorso.poner(barras, x_derecha, y2 + round(lema.alto * e) + 12, e)
    dorso.con_cierres(fuente, (174, 212), (320, 700))
    paneles[forma.DORSO] = dorso.rgba

    # Los cantos llevan el azul con copos y solo: se ven de costado y una pieza queda cortada.
    zonas = {forma.ARRIBA: (154, 35, 1099, 197), forma.ABAJO: (134, 1080, 1119, 1229)}
    for nombre, zona in zonas.items():
        canto = Lienzo(nombre, fuente.fondo_de_la_zona(zona), rects[nombre], 0.5, registro)
        sembrar(canto, copos, 9, 0.45, 7)
        paneles[nombre] = canto.rgba
    return paneles


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
    reporte = RAIZ / "reports/paquetes-de-galletitas"
    carpeta = ORIGINALES if aplicar else reporte
    carpeta.mkdir(parents=True, exist_ok=True)
    reporte.mkdir(parents=True, exist_ok=True)
    if not bpy.data.filepath:
        raise SystemExit("falta el .blend: se mide el tamaño de cada paquete en su malla")
    cajas = {n: armado.caja_del_cubo(bpy.data.objects[n]) for n in PRODUCTOS}
    comparadas: list[tuple[np.ndarray, np.ndarray]] = []
    for nombre, (archivo, componer) in PRODUCTOS.items():
        objeto = bpy.data.objects[nombre]
        x0, x1, y0, y1, z0, z1 = cajas[nombre]
        caja = forma.Caja(
            (y1 - y0) * objeto.scale.y, (x1 - x0) * objeto.scale.x, (z1 - z0) * objeto.scale.z
        )
        rects = forma.desplegado(caja)
        registro: list = []
        paneles = componer(rects, registro)
        hoja = np.zeros((forma.LIENZO_ALTO, forma.LIENZO_ANCHO, 4), dtype=np.float32)
        hoja[..., :3] = FONDO_DE_LA_HOJA
        hoja[..., 3] = 1.0
        for panel, rect in rects.items():
            poner_el_panel(hoja, paneles[panel], rect)
        escribir(hoja, carpeta / archivo)
        (reporte / f"composicion_{archivo.removesuffix('.png')}.json").write_text(
            json.dumps({"producto": nombre, "piezas": registro}, indent=1), encoding="utf-8"
        )
        print(f"{archivo}: {hoja.shape[1]}x{hoja.shape[0]} en {carpeta}, {len(registro)} piezas")
        comparadas.append((leer(ORIGINALES / nombre_del_original(nombre)), hoja))
    hoja_comparativa(comparadas, reporte / "hoja_de_texturas.png")


if __name__ == "__main__":
    main()

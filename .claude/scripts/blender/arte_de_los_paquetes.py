"""El arte actual de Oremos y de Pepito, recortado en piezas con su transparencia. Corre en Blender.

Lo usan `preparar_para_codex.py`, que deja las piezas sueltas para quien pinte la textura nueva, y
nadie más: es una biblioteca de recortes, no un script. Lee `oremos.png` y `pepito.png` de
`assets/source/products-textured/galletitas/`, que son el arte del artista y no se tocan.

## Cómo se recorta

Cada arte se divide en zonas (el frente, el dorso, los cantos). De cada zona se rehace el fondo sin
piezas: lo que no es el azul liso del envase se borra y se rellena con el degradé de sus
alrededores. Una pieza es la diferencia entre el arte y ese fondo, así que sale con transparencia
y sin el azul que la rodeaba. Donde dos piezas se tocan (el logo y la galleta de Oremos) una
máscara decide de cuál es cada píxel.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.repo import RAIZ  # noqa: E402

Rect = tuple[int, int, int, int]

ORIGINALES = RAIZ / "assets/source/products-textured/galletitas"


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

def es_de_galleta(rgb: np.ndarray) -> np.ndarray:
    """Marrón y tostado: no el azul, el blanco ni el rojo."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    tostado = (r > 0.12) & (r > b + 0.04) & ~((r > 0.6) & (g < 0.3) & (b < 0.3))
    return tostado | (rgb.max(axis=2) < 0.2)


def pieza_en(registro_zona: np.ndarray, zona: Rect, rect: Rect) -> np.ndarray:
    x0, y0, x1, y1 = rect
    return registro_zona[y0 - zona[1] : y1 - zona[1], x0 - zona[0] : x1 - zona[0]]

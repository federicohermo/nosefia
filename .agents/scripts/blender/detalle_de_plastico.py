"""Lo que comparten la silla, los tachos y los bidones para pintar uso en el plástico.

Lo usan `texturizar_silla_del_salon.py`, `texturizar_tachos_del_salon.py` y
`texturizar_bidones.py`. Se suma a `detalle_horneado.py`, que da la oclusión, el desgaste de las
aristas y las manchas horneadas desde la malla.

## Qué hay

- **Desde la malla** (Blender): `cobertura` dice dónde pinta la UV, y `altura_del_mundo` da la
  altura de cada punto. `copia_aparte` deja afuera de la imagen las caras que comparten lugar
  de la UV con las que importan.
- **En la imagen** (numpy): `ruido`, `rayones`, `distancia_al_borde` y `desenfocar`. Pintan
  rápido y se iteran sin volver a hornear.
- **Entrada y salida**: `leer_png` y `escribir_png` guardan el valor tal cual, sin pasar por
  sRGB. `salida` manda el resultado a `build/plastico/` salvo con `--aplicar`.

## Qué se hornea y qué se pinta

Dos islas de la UV que se tocan en la malla no se tocan en la imagen. Un ruido pintado en la UV
corta en seco en cada costura. Lo que tiene que seguir de una franja a otra, como la suciedad de
un quiebre, se hornea de las coordenadas del objeto. Lo que no, como un rayón suelto, se pinta.
Un ruido horneado de las coordenadas generadas, estirado para dar rayones, salió como telaraña:
por eso los rayones se pintan.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from detalle_horneado import (  # noqa: E402
    color_base,
    copia_con_color,
    descartar,
    forma,
    hornear,
    preparar_cycles,
    restaurar,
    uso,
)

__all__ = [
    "altura_del_mundo",
    "cobertura",
    "copia_aparte",
    "copia_con_color",
    "descartar",
    "desenfocar",
    "distancia_al_borde",
    "escribir_png",
    "forma",
    "hornear",
    "leer_png",
    "preparar_cycles",
    "rayones",
    "restaurar",
    "ruido",
    "salida",
    "suave",
    "uso",
]


def _matematica(nodos, enlaces, operacion, a, b=None, limitar=False):
    nodo = nodos.new("ShaderNodeMath")
    nodo.operation = operacion
    nodo.use_clamp = limitar
    for entrada, valor in ((0, a), (1, b)):
        if valor is None:
            continue
        if isinstance(valor, (int, float)):
            nodo.inputs[entrada].default_value = valor
        else:
            enlaces.new(valor, nodo.inputs[entrada])
    return nodo.outputs["Value"]


def altura_del_mundo(objeto):
    """La capa de altura: 0 en el punto más bajo del objeto en el mundo y 1 en el más alto."""
    puntos = [(objeto.matrix_world @ v.co).z for v in objeto.data.vertices]
    abajo, arriba = min(puntos), max(puntos)

    def armar(nodos, enlaces):
        geometria = nodos.new("ShaderNodeNewGeometry")
        separar = nodos.new("ShaderNodeSeparateXYZ")
        enlaces.new(geometria.outputs["Position"], separar.inputs["Vector"])
        sobre_el_piso = _matematica(nodos, enlaces, "SUBTRACT", separar.outputs["Z"], abajo)
        return _matematica(
            nodos, enlaces, "MULTIPLY", sobre_el_piso, 1.0 / (arriba - abajo), limitar=True
        )

    return armar


def copia_aparte(objeto, caras_fuera: set[int], color_de_cada_cara=None):
    """Una copia suelta para hornear, con la UV de `caras_fuera` movida afuera de la imagen.

    Sirve cuando dos partes de una malla comparten el mismo lugar de la UV: lo que queda afuera
    se ve en la oclusión pero no se hornea sobre la parte que importa.
    """
    colores = color_de_cada_cara or [(0.0, 0.0, 0.0)] * len(objeto.data.polygons)
    copia = copia_con_color(objeto, colores)
    capa = copia.data.uv_layers[0].data
    for cara in copia.data.polygons:
        if cara.index in caras_fuera:
            for lazo in cara.loop_indices:
                capa[lazo].uv = (capa[lazo].uv[0] + 5.0, capa[lazo].uv[1] + 5.0)
    return copia


#: Dónde quedan las imágenes sin `--aplicar`, para mirarlas sin tocar la fuente.
PRUEBA = Path(__file__).resolve().parents[3] / "build" / "plastico"


def salida(fuente: Path) -> Path:
    """La fuente con `--aplicar`, y una copia en `build/plastico/` sin él."""
    if "--aplicar" in sys.argv:
        return fuente
    PRUEBA.mkdir(parents=True, exist_ok=True)
    return PRUEBA / fuente.name


def cobertura(objeto, caras_marcadas: set[int], lado: int) -> np.ndarray:
    """Un 1 donde la UV de las caras marcadas pinta, y un 0 donde no. Sin margen."""
    color = [(1.0, 1.0, 1.0) if cara.index in caras_marcadas else (0.0, 0.0, 0.0)
             for cara in objeto.data.polygons]
    copia = copia_aparte(objeto, set(range(len(color))) - caras_marcadas, color)
    try:
        pixeles = hornear(copia, color_base, lado, 0)
    finally:
        descartar(copia)
    return pixeles[..., 0]


def ruido(
    alto: int, ancho: int, celda: float, semilla: int, octavas: int = 4, estirado: float = 1.0
) -> np.ndarray:
    """Ruido de valor 0..1 con celdas de `celda` píxeles. Cada octava achica la celda a la mitad.

    Con `estirado` mayor que 1 la celda es más larga en vertical: da vetas de arriba abajo.
    """
    azar = np.random.default_rng(semilla)
    suma = np.zeros((alto, ancho), dtype=np.float32)
    peso, total = 1.0, 0.0
    for octava in range(octavas):
        lado = max(celda / (2**octava), 1.0)
        lado_y = lado * estirado
        grilla = azar.random((int(alto / lado_y) + 3, int(ancho / lado) + 3)).astype(np.float32)
        ys, xs = np.arange(alto) / lado_y, np.arange(ancho) / lado
        y0, x0 = ys.astype(int), xs.astype(int)
        fy, fx = ys - y0, xs - x0
        fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
        filas = grilla[y0] * (1 - fy)[:, None] + grilla[y0 + 1] * fy[:, None]
        suma += peso * (filas[:, x0] * (1 - fx) + filas[:, x0 + 1] * fx)
        total += peso
        peso *= 0.5
    return suma / total


def rayones(
    alto: int,
    ancho: int,
    cantidad: int,
    largo: float,
    semilla: int,
    grosor: int = 1,
    angulo: float | None = None,
    dispersion: float = 0.35,
    curvatura: float = 0.06,
    peso: np.ndarray | None = None,
) -> np.ndarray:
    """Segmentos finos y casi rectos, de fuerza distinta, 0..1.

    Con `angulo` salen casi paralelos; sin él, en cualquier dirección. `peso` es un mapa 0..1
    que deja más rayones donde vale más.
    """
    azar = np.random.default_rng(semilla)
    lienzo = np.zeros((alto, ancho), dtype=np.float32)
    for _ in range(cantidad):
        x0, y0 = azar.uniform(0, ancho), azar.uniform(0, alto)
        if peso is not None and azar.random() > peso[int(y0), int(x0)]:
            continue
        rumbo = azar.uniform(0, np.pi) if angulo is None else angulo + azar.normal(0, dispersion)
        longitud = largo * azar.uniform(0.3, 1.6)
        pasos = int(longitud * 2) + 2
        t = np.linspace(0.0, 1.0, pasos)
        curva = azar.normal(0, curvatura) * longitud * t * (1 - t)
        xs = x0 + np.cos(rumbo) * longitud * t - np.sin(rumbo) * curva
        ys = y0 + np.sin(rumbo) * longitud * t + np.cos(rumbo) * curva
        fuerza = azar.uniform(0.35, 1.0) * np.sin(np.pi * t) ** 0.5
        for dy in range(grosor):
            for dx in range(grosor):
                yi = np.clip(ys.astype(int) + dy, 0, alto - 1)
                xi = np.clip(xs.astype(int) + dx, 0, ancho - 1)
                np.maximum.at(lienzo, (yi, xi), fuerza)
    return lienzo


def distancia_al_borde(cobertura_: np.ndarray, maximo: int) -> np.ndarray:
    """Cuántos píxeles hacia adentro está cada uno del borde de la mancha, hasta `maximo`."""
    dentro = cobertura_ > 0.5
    distancia = np.zeros(dentro.shape, dtype=np.float32)
    for _ in range(maximo):
        vecinos = dentro.copy()
        vecinos[1:] &= dentro[:-1]
        vecinos[:-1] &= dentro[1:]
        vecinos[:, 1:] &= dentro[:, :-1]
        vecinos[:, :-1] &= dentro[:, 1:]
        dentro = vecinos
        distancia += dentro
    return distancia


def suave(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def desenfocar(imagen: np.ndarray, radio: int) -> np.ndarray:
    """Un promedio de caja por eje, con los bordes repetidos."""
    if radio <= 0:
        return imagen
    salida = imagen
    for eje in (0, 1):
        relleno = [(0, 0)] * salida.ndim
        relleno[eje] = (radio + 1, radio)
        suma = np.cumsum(np.pad(salida, relleno, mode="edge"), axis=eje)
        largo = salida.shape[eje]
        corte = [slice(None)] * salida.ndim
        otro = list(corte)
        corte[eje], otro[eje] = slice(2 * radio + 1, 2 * radio + 1 + largo), slice(0, largo)
        salida = (suma[tuple(corte)] - suma[tuple(otro)]) / (2 * radio + 1)
    return salida


def leer_png(ruta: Path) -> np.ndarray:
    """Los píxeles tal como están en el archivo, 0..1, con la fila 0 abajo y sin alfa."""
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    imagen.colorspace_settings.name = "Non-Color"
    alto, ancho = imagen.size[1], imagen.size[0]
    pixeles = np.empty(alto * ancho * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    bpy.data.images.remove(imagen)
    return pixeles.reshape(alto, ancho, 4)[..., :3].copy()


def escribir_png(color: np.ndarray, destino: Path) -> None:
    """El inverso de `leer_png`: guarda el valor tal cual, sin pasar por sRGB."""
    alto, ancho = color.shape[:2]
    imagen = bpy.data.images.new("plastico_con_detalle", ancho, alto, alpha=False)
    imagen.colorspace_settings.name = "Non-Color"
    rgba = np.ones((alto, ancho, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(color, 0.0, 1.0)
    imagen.pixels.foreach_set(rgba.ravel())
    imagen.filepath_raw = str(destino)
    imagen.file_format = "PNG"
    imagen.save()
    bpy.data.images.remove(imagen)

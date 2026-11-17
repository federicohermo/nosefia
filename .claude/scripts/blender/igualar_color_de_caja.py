"""Lleva el color de una caja nueva al de su original. Corre adentro de Blender.

    blender --background --python-exit-code 1 \
        --python .claude/scripts/blender/igualar_color_de_caja.py -- <nueva> <original> <salida>

Lo lanza `igualar_color_de_caja.py` de la raíz. **No se corre a mano.** El método y por qué es así
están en `lib/color_de_caja.py`. Acá es el mismo método sobre arreglos de numpy, porque una caja
tiene millones de píxeles y la biblioteca estándar los recorre de a uno. Un test compara las dos
implementaciones sobre una imagen chica.

Imprime una línea `color: g=… dl=… saturacion=… brillo=…` con lo que se midió sobre la salida,
sobre el contenido y a 256 píxeles.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import color_de_caja as modelo  # noqa: E402

#: Cuántas filas se convierten por vez: acota la memoria de una imagen de millones de píxeles.
FILAS_POR_TANDA = 512

_A_XYZ = np.array(modelo._A_XYZ)
_DE_XYZ = np.array(modelo._DE_XYZ)
_BLANCO = np.array(modelo._BLANCO)


def _leer(ruta: str) -> np.ndarray:
    imagen = bpy.data.images.load(ruta, check_existing=False)
    ancho, alto = imagen.size
    datos = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(datos)
    bpy.data.images.remove(imagen)
    return datos.reshape(alto, ancho, 4)


def _a_lab(rgb: np.ndarray) -> np.ndarray:
    rgb = rgb.astype(np.float64)
    lineal = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    xyz = (lineal @ _A_XYZ.T) / _BLANCO
    f = np.where(xyz > modelo._EPSILON, np.cbrt(xyz), (modelo._KAPPA * xyz + 16) / 116)
    return np.stack(
        [116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])],
        axis=-1,
    )


def _a_srgb(lab: np.ndarray) -> np.ndarray:
    fy = (lab[..., 0] + 16) / 116
    f = np.stack([fy + lab[..., 1] / 500, fy, fy - lab[..., 2] / 200], axis=-1)
    cubo = f**3
    xyz = np.where(cubo > modelo._EPSILON, cubo, (116 * f - 16) / modelo._KAPPA) * _BLANCO
    lineal = np.clip(xyz @ _DE_XYZ.T, 0.0, 1.0)
    return np.where(
        lineal <= 0.0031308, 12.92 * lineal, 1.055 * np.maximum(lineal, 1e-12) ** (1 / 2.4) - 0.055
    )


def _niveles(valores: np.ndarray) -> np.ndarray:
    return np.clip(np.round(255 * valores), 0, 255) / 255


def _contenido(rgb: np.ndarray) -> np.ndarray:
    return np.round(255 * rgb.max(axis=-1)) > modelo.NEGRO


def _estadisticas(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Media y desvío de Lab por canal, sobre el contenido y por tandas."""
    suma = np.zeros(3)
    suma2 = np.zeros(3)
    total = 0
    for fila in range(0, rgb.shape[0], FILAS_POR_TANDA):
        tanda = rgb[fila : fila + FILAS_POR_TANDA]
        lab = _a_lab(tanda)[_contenido(tanda)]
        suma += lab.sum(axis=0)
        suma2 += (lab * lab).sum(axis=0)
        total += len(lab)
    media = suma / total
    return media, np.sqrt(np.maximum(suma2 / total - media * media, 0.0))


def _matriz(entrada: int, salida: int) -> np.ndarray:
    matriz = np.zeros((salida, entrada))
    for k, (inicio, ps) in enumerate(modelo.pesos(entrada, salida)):
        matriz[k, inicio : inicio + len(ps)] = ps
    return matriz


def _muestra(rgb: np.ndarray) -> np.ndarray:
    """`reducir` de la biblioteca: Lanczos de PIL, redondeando a 8 bits en cada pasada."""
    lado = modelo.LADO_DE_LA_MUESTRA
    alto, ancho = rgb.shape[:2]
    columnas, filas = min(ancho, lado), min(alto, lado)
    reducida = rgb.astype(np.float64)
    if columnas < ancho:
        horizontal = reducida.transpose(0, 2, 1) @ _matriz(ancho, columnas).T
        reducida = _niveles(horizontal.transpose(0, 2, 1))
    if filas < alto:
        reducida = _niveles(np.tensordot(_matriz(alto, filas), reducida, axes=([1], [0])))
    return reducida


def _saturacion_y_brillo(rgb: np.ndarray, mascara: np.ndarray) -> tuple[float, float]:
    niveles = np.round(255 * rgb[mascara])
    maximo = niveles.max(axis=-1)
    minimo = niveles.min(axis=-1)
    saturacion = np.where(
        maximo > 0, np.floor(255 * (maximo - minimo) / np.where(maximo > 0, maximo, 1)), 0
    )
    return float(saturacion.mean()), float(maximo.mean())


def _bisecar(medida, objetivo: float, rango: tuple[float, float]) -> float:
    bajo, alto = rango
    for _ in range(modelo.VUELTAS):
        medio = (bajo + alto) / 2
        if medida(medio) < objetivo:
            bajo = medio
        else:
            alto = medio
    return (bajo + alto) / 2


def _transformar(lab: np.ndarray, base, g: float, dl: float) -> np.ndarray:
    """`lib.transformar` sobre un arreglo de colores Lab."""
    media_n, desvio_n, media_o, desvio_o = base
    seguro = np.where(desvio_n > 0, desvio_n, 1.0)
    llevado = np.where(desvio_n > 0, (lab - media_n) / seguro * desvio_o + media_o, media_o)
    llevado = llevado * np.array([1.0, g, g]) + np.array([dl, 0.0, 0.0])
    peso = np.clip(lab[..., :1] / modelo.PIE_DE_LUZ, 0.0, 1.0)
    return lab + peso * (llevado - lab)


def _aplicar(nueva: np.ndarray, base, g: float, dl: float) -> np.ndarray:
    salida = np.empty_like(nueva, dtype=np.float32)
    for fila in range(0, nueva.shape[0], FILAS_POR_TANDA):
        lab = _transformar(_a_lab(nueva[fila : fila + FILAS_POR_TANDA]), base, g, dl)
        salida[fila : fila + FILAS_POR_TANDA] = _niveles(_a_srgb(lab))
    return salida


def igualar(nueva: np.ndarray, original: np.ndarray):
    """La caja nueva, de `alto x ancho x 3`, con el color del original: `lib.ajustar` en numpy."""
    media_n, desvio_n = _estadisticas(nueva)
    media_o, desvio_o = _estadisticas(original)
    base = (media_n, desvio_n, media_o, desvio_o)
    muestra_o, muestra_n = _muestra(original), _muestra(nueva)
    meta = _saturacion_y_brillo(muestra_o, _contenido(muestra_o))
    mascara = _contenido(muestra_n)
    chica = _a_lab(muestra_n)

    def medir(g: float, dl: float) -> tuple[float, float]:
        return _saturacion_y_brillo(_a_srgb(_transformar(chica, base, g, dl)), mascara)

    def fino(objetivo: tuple[float, float]) -> tuple[float, float]:
        def dl_para(g: float) -> float:
            return _bisecar(lambda dl: medir(g, dl)[1], objetivo[1], modelo.RANGO_DE_DL)

        g = _bisecar(lambda g: medir(g, dl_para(g))[0], objetivo[0], modelo.RANGO_DE_G)
        return g, dl_para(g)

    objetivo = meta
    for _ in range(modelo.RONDAS):
        g, dl = fino(objetivo)
        salida = _aplicar(nueva, base, g, dl)
        medido = _saturacion_y_brillo(_muestra(salida), mascara)
        faltante = (meta[0] - medido[0], meta[1] - medido[1])
        if max(abs(faltante[0]), abs(faltante[1])) <= modelo.PRECISION:
            break
        objetivo = (objetivo[0] + faltante[0], objetivo[1] + faltante[1])
    return salida, g, dl, medido


def _escribir(ruta: str, rgb: np.ndarray, alfa: np.ndarray | None) -> None:
    """`Image.save` y no `save_render`: éste aplica la transformación de vista y oscurece."""
    alto, ancho = rgb.shape[:2]
    imagen = bpy.data.images.new("caja", ancho, alto, alpha=alfa is not None)
    imagen.colorspace_settings.name = "sRGB"
    imagen.alpha_mode = "STRAIGHT"
    opaco = np.ones((alto, ancho), dtype=np.float32) if alfa is None else alfa
    cuatro = np.concatenate([rgb, opaco[..., None]], axis=-1).astype(np.float32)
    imagen.pixels.foreach_set(cuatro.reshape(-1))
    imagen.file_format = "PNG"
    imagen.filepath_raw = ruta
    imagen.save()
    bpy.data.images.remove(imagen)


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    nueva_ruta, original_ruta, salida = sys.argv[sys.argv.index("--") + 1 :]
    nueva = _leer(nueva_ruta)
    original = _leer(original_ruta)
    resultado, g, dl, (saturacion, brillo) = igualar(nueva[..., :3], original[..., :3])
    alfa = nueva[..., 3] if nueva[..., 3].min() < 0.999 else None
    _escribir(salida, resultado, alfa)
    print(f"color: g={g:.4f} dl={dl:.3f} saturacion={saturacion:.2f} brillo={brillo:.2f}")


if __name__ == "__main__":
    main()

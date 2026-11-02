"""Aplica una capa de desgaste sobre una etiqueta. Corre adentro de Blender.

    blender --background --python-exit-code 1 --python .claude/scripts/blender/aplicar_desgaste.py \
        -- <etiqueta> <capa> <salida> <fuerza> <giro> <espejo 0|1> <dx> <dy>

Lo lanza `aplicar_desgaste.py` de la raíz. **No se corre a mano.** La fórmula es la de
`lib/desgaste.py`: acá se lee y se escribe el PNG, y se la aplica sobre arreglos de numpy porque
una fuente llega a 90 millones de píxeles, que en listas de Python no entran en memoria. Un test
compara las dos implementaciones.

La capa se escala, sin deformarla, hasta cubrir el lado mayor de la etiqueta, y recién entonces se
gira, se desplaza y se recorta. Una capa cuadrada sirve así a una etiqueta de cualquier forma.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import desgaste  # noqa: E402

#: Cuántas filas se mezclan por vez: acota la memoria de las temporarias.
FILAS_POR_TANDA = 256


def _leer(ruta: str):
    imagen = bpy.data.images.load(ruta, check_existing=False)
    ancho, alto = imagen.size
    datos = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(datos)
    bpy.data.images.remove(imagen)
    return ancho, alto, datos.reshape(alto, ancho, 4)


def _escribir(ruta: str, pixeles: np.ndarray, con_alfa: bool) -> None:
    """`Image.save` y no `save_render`: éste aplica la transformación de vista y oscurece."""
    alto, ancho = pixeles.shape[:2]
    imagen = bpy.data.images.new("desgaste", ancho, alto, alpha=con_alfa)
    imagen.colorspace_settings.name = "sRGB"
    imagen.alpha_mode = "STRAIGHT"
    imagen.pixels.foreach_set(pixeles.reshape(-1))
    imagen.file_format = "PNG"
    imagen.filepath_raw = ruta
    imagen.save()
    bpy.data.images.remove(imagen)


def _gris_de_la_capa(ruta: str, lado: int) -> np.ndarray:
    """La capa escalada a `lado` x `lado`, de arriba hacia abajo y en 0..255. Toma el rojo."""
    imagen = bpy.data.images.load(ruta, check_existing=False)
    imagen.scale(lado, lado)
    datos = np.empty(lado * lado * 4, dtype=np.float32)
    imagen.pixels.foreach_get(datos)
    bpy.data.images.remove(imagen)
    return datos.reshape(lado, lado, 4)[::-1, :, 0] * 255


def preparar_capa(
    capa: np.ndarray, ancho: int, alto: int, giro: int, espejo: bool, desplazamiento
) -> np.ndarray:
    """`lib.desgaste.preparar_capa` sobre un arreglo: gira, espeja, desplaza y recorta."""
    lado = capa.shape[0]
    if espejo:
        capa = capa[:, ::-1]
    capa = np.rot90(capa, k=-(giro // 90))
    corrida_x = round(desplazamiento[0] * lado) % lado
    corrida_y = round(desplazamiento[1] * lado) % lado
    capa = np.roll(capa, (-corrida_y, -corrida_x), axis=(0, 1))
    return capa[:alto, :ancho]


def aplicar(pixeles: np.ndarray, capa: np.ndarray, fuerza: float) -> None:
    """`lib.desgaste.aplicar` sobre un arreglo de `alto x ancho x 4`, en el lugar.

    `capa` va de arriba hacia abajo y `pixeles` de abajo hacia arriba, como las guarda Blender.
    """
    diferencia = (capa - desgaste.GRIS_NEUTRO) / desgaste.ESCALA_DE_LA_CAPA
    diferencia = (diferencia - np.median(diferencia))[::-1] * fuerza
    for fila in range(0, pixeles.shape[0], FILAS_POR_TANDA):
        tanda = pixeles[fila : fila + FILAS_POR_TANDA, :, :3]
        d = diferencia[fila : fila + FILAS_POR_TANDA, :, None]
        luz = desgaste.luminancia(tanda[..., 0], tanda[..., 1], tanda[..., 2])
        mezclado = np.clip(desgaste.mezclar(tanda, d), 0.0, 1.0)
        tanda[...] = np.where((luz > desgaste.UMBRAL_DE_BRILLO)[..., None], mezclado, tanda)


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    etiqueta, capa, salida, fuerza, giro, espejo, dx, dy = sys.argv[sys.argv.index("--") + 1 :]
    ancho, alto, pixeles = _leer(etiqueta)
    if int(giro) not in desgaste.GIROS:
        raise ValueError(f"el giro es uno de {desgaste.GIROS}, y llegó {giro}")
    gris = _gris_de_la_capa(capa, max(ancho, alto))
    preparada = preparar_capa(gris, ancho, alto, int(giro), espejo == "1", (float(dx), float(dy)))
    del gris
    con_alfa = bool(pixeles[..., 3].min() < 0.999)
    aplicar(pixeles, preparada, float(fuerza))
    _escribir(salida, pixeles, con_alfa)
    print(f"desgaste: {salida} {ancho}x{alto}")


if __name__ == "__main__":
    main()

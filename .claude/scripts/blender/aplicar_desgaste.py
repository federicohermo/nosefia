"""Aplica una capa de desgaste sobre una etiqueta. Corre adentro de Blender.

    blender --background --python-exit-code 1 --python .claude/scripts/blender/aplicar_desgaste.py \
        -- <etiqueta> <capa> <salida> <fuerza> <giro> <espejo 0|1> <dx> <dy>

Lo lanza `aplicar_desgaste.py` de la raíz. **No se corre a mano.** La matemática es de
`lib/desgaste.py`: acá sólo se leen y se escriben los PNG.

La capa se escala, sin deformarla, hasta cubrir el lado mayor de la etiqueta, y recién entonces se
gira, se desplaza y se recorta. Una capa cuadrada sirve así a una etiqueta de cualquier forma.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import desgaste  # noqa: E402


def _leer(ruta: str):
    imagen = bpy.data.images.load(ruta, check_existing=False)
    ancho, alto = imagen.size
    datos = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(datos)
    return imagen, ancho, alto, datos


def _escribir(ruta: str, ancho: int, alto: int, datos: list[float], con_alfa: bool) -> None:
    """`Image.save` y no `save_render`: éste aplica la transformación de vista y oscurece."""
    imagen = bpy.data.images.new("desgaste", ancho, alto, alpha=con_alfa)
    imagen.colorspace_settings.name = "sRGB"
    imagen.alpha_mode = "STRAIGHT"
    imagen.pixels.foreach_set(np.asarray(datos, dtype=np.float32))
    imagen.file_format = "PNG"
    imagen.filepath_raw = ruta
    imagen.save()
    bpy.data.images.remove(imagen)


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    etiqueta, capa, salida, fuerza, giro, espejo, dx, dy = sys.argv[sys.argv.index("--") + 1 :]
    imagen, ancho, alto, pixeles = _leer(etiqueta)
    cubierta, _, _, _ = _leer(capa)
    lado = max(ancho, alto)
    cubierta.scale(lado, lado)
    datos = np.empty(lado * lado * 4, dtype=np.float32)
    cubierta.pixels.foreach_get(datos)
    # El gris se toma del canal rojo: la capa es de escala de grises.
    gris = (datos.reshape(lado, lado, 4)[::-1, :, 0] * 255).reshape(-1).tolist()
    preparada = desgaste.preparar_capa(
        gris, lado, ancho, alto, int(giro), espejo == "1", (float(dx), float(dy))
    )
    # Las filas de `pixels` van de abajo hacia arriba: la capa se lee del revés, y se la da vuelta.
    filas = np.asarray(preparada, dtype=np.float32).reshape(alto, ancho)[::-1].reshape(-1)
    con_alfa = bool(pixeles.reshape(-1, 4)[:, 3].min() < 0.999)
    resultado = desgaste.aplicar(pixeles.tolist(), filas.tolist(), float(fuerza))
    _escribir(salida, ancho, alto, resultado, con_alfa)
    print(f"desgaste: {salida} {ancho}x{alto}")


if __name__ == "__main__":
    main()

"""Agranda las baldosas del piso del salón, sólo mediante su UV.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/agrandar_baldosas_del_salon.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después van `exportar_modelo.py` y `hornear.py`.

## Qué cambia

La UV principal de las caras del piso con `local_ceramica`, que sale de la posición de cada
vértice. La textura trae las baldosas a 45 grados y tres por diagonal: el giro las deja paralelas
a las paredes, como estaban. La junta que llega al encuentro con el baño se conserva. El zócalo,
UV2 y la geometría no se tocan.

Es idempotente: correrlo dos veces deja la misma UV.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

OBJETO = "almacen-col"
PISO = "local_ceramica"
VECINO = "bano_piso_gris"
LADO_DE_LA_BALDOSA = 0.80
BALDOSAS_POR_DIAGONAL = 3


def agrandar() -> int:
    objeto = bpy.data.objects[OBJETO]
    malla = objeto.data
    mundo = objeto.matrix_world
    nombres = [material.name for material in malla.materials]
    encuentro = min(
        (mundo @ malla.vertices[i].co).x
        for cara in malla.polygons
        if nombres[cara.material_index] == VECINO
        for i in cara.vertices
    )
    fase = encuentro % LADO_DE_LA_BALDOSA
    repeticion = LADO_DE_LA_BALDOSA * BALDOSAS_POR_DIAGONAL * math.sqrt(2)
    capa = malla.uv_layers[0].data
    caras = 0
    for cara in malla.polygons:
        if nombres[cara.material_index] != PISO:
            continue
        caras += 1
        for lazo in cara.loop_indices:
            punto = mundo @ malla.vertices[malla.loops[lazo].vertex_index].co
            x, y = punto.x - fase, punto.y
            capa[lazo].uv = ((x + y) / repeticion, (y - x) / repeticion)
    if caras == 0:
        raise ValueError(f"{OBJETO} no tiene caras con {PISO}")
    return caras


def main() -> None:
    configurar()
    print(f"caras del piso: {agrandar()}, baldosa de {LADO_DE_LA_BALDOSA} m")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()

"""Suaviza el cilindro cromado de la base de las mesas del salón.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/suavizar_base_de_mesas.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después va `exportar_modelo.py`.

## Por qué

Las caras del costado del pie y del disco tenían sombreado plano. El cromo refleja la sonda, y
con caras planas cada gajo reflejaba otra cosa: el pie se veía pixelado.

## Qué cambia

Las caras de cuatro lados del cromo pasan a sombreado suave, y toda arista entre dos caras que
doblan más de `ANGULO` queda viva. Así se suavizan el pie y el disco, y el canto del tablero, que
también es de cromo, conserva sus esquinas. Las tapas siguen planas. La malla y la UV no cambian.
Es idempotente.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

MALLA = "salon_mesa"
CROMO = "MESA | Base cromada"
ANGULO = math.radians(30)


def main() -> None:
    configurar()
    malla = bpy.data.meshes[MALLA]
    costados = 0
    for cara in malla.polygons:
        if malla.materials[cara.material_index].name == CROMO and cara.loop_total == 4:
            cara.use_smooth = True
            costados += 1
    for arista in malla.edges:
        caras = [c for c in malla.polygons if arista.key in c.edge_keys]
        if len(caras) == 2 and caras[0].normal.angle(caras[1].normal) > ANGULO:
            arista.use_edge_sharp = True
    if costados == 0:
        raise ValueError(f"{MALLA} no tiene costados de {CROMO}")
    print(f"{MALLA}: {costados} caras del cromo suavizadas, en {malla.users} mesas")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()

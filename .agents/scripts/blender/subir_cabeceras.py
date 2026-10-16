"""Sube la bandeja del medio de las cabeceras. Edición de un paso sobre el `.blend`.

    blender <fuente>.blend --background --python .claude/scripts/blender/subir_cabeceras.py

Las dos góndolas comparten la malla: subirla en una la sube en las cuatro cabeceras. Correrlo
otra vez no cambia nada. Después van `acomodar.py`, `exportar_modelo.py`, `disponer.py`,
`actualizar_apoyos.py` y `hornear.py`.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from acomodar import _islas, medir  # noqa: E402

#: La altura de la chapa de la bandeja del medio, en metros. A 1,288, Fernet God (40,5 cm) y
#: Amargadito (35,5 cm) no entraban en dos filas en la bandeja de abajo: la de atrás tocaba la
#: cara de abajo de esta.
ALTURA = 1.358

#: Lo que la bandeja lleva colgado y no es parte de su isla: las ménsulas y las etiquetas del
#: labio. Son islas chicas que caen dentro de su planta y cerca de su alto.
CERCA = 0.06


def _lo_que_lleva(bm, bandeja):
    """La isla de la bandeja y las islas chicas que viajan con ella."""
    puntos = [v.co for cara in bandeja.isla for v in cara.verts]
    x0, x1 = min(p.x for p in puntos), max(p.x for p in puntos)
    y0, y1 = min(p.y for p in puntos), max(p.y for p in puntos)
    z0, z1 = min(p.z for p in puntos), max(p.z for p in puntos)
    salida = {v.index for p in [bandeja.isla] for cara in p for v in cara.verts}
    for isla in _islas(bm):
        vs = {v for cara in isla for v in cara.verts}
        if (
            min(v.co.x for v in vs) >= x0 - 0.02 and max(v.co.x for v in vs) <= x1 + 0.02
            and min(v.co.y for v in vs) >= y0 - 0.02 and max(v.co.y for v in vs) <= y1 + 0.02
            and min(v.co.z for v in vs) >= z0 - CERCA and max(v.co.z for v in vs) <= z1 + CERCA
        ):
            salida |= {v.index for v in vs}
    return salida


def principal():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    objeto, bm, estantes = medir("A")
    bandejas = [
        e for clave, e in estantes.items()
        if clave.split(".")[1] in ("norte", "sur") and clave.endswith(".2")
    ]
    assert len(bandejas) == 2, [e.clave for e in bandejas]
    subida = ALTURA - bandejas[0].origen.z
    indices = set().union(*(_lo_que_lleva(bm, e) for e in bandejas))
    bm.free()
    if abs(subida) < 1e-4:
        print("ya estaba a su altura")
        return
    corrimiento = objeto.matrix_world.inverted().to_3x3() @ Vector((0.0, 0.0, subida))
    for i in indices:
        objeto.data.vertices[i].co += corrimiento
    objeto.data.update()
    bpy.ops.wm.save_mainfile()
    print(f"subidas {len(bandejas)} bandejas con {len(indices)} vértices, {subida * 100:.1f} cm")


if __name__ == "__main__":
    principal()

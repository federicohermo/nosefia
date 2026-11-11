"""Quita los marcos en relieve del friso de las heladeras: queda una pared plana.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/quitar_molduras_del_friso.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente. Después va
`listonar_frente_de_madera.py`, que le da los listones al friso, y después `exportar_modelo.py`
y `hornear.py`: la malla cambia de forma y su luz horneada ya no sirve.

## Por qué

El friso (`mueble_continuo`) llevaba un aro en relieve por cada cara frontal de 50 cm o más, con
anchos distintos según el hueco: 38 cm en las jambas, 1,1 m sobre las heladeras, 72 cm sobre el
exhibidor. Los marcos se cruzaban con los cortes de las tablas pintadas en la textura. El resultado
era una pared con cuatro lógicas de división a la vez. Una pared moderna lleva una sola: listones
del mismo ancho, con una buña.

## Qué cambia

Se borran las caras que salen del plano del frente (las del marco) y los vértices que quedan
sueltos. El frente conserva sus caras originales. **Las divisiones ya no son geometría:** las
hace `listonar_frente_de_madera.py`, con listones y buñas.

## Lo que cuesta

Resta 270 triángulos, ningún material ni dibujo. Es idempotente: sin caras en relieve no hace
nada.
"""

import sys
from collections import defaultdict
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
from mathutils import Matrix  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

OBJETO = "mueble_continuo"
MARCA = "molduras_del_friso_v1"
TOLERANCIA = 1e-3


def _plano_del_frente(bm) -> float:
    """La `y` donde más área mira al salón: el plano de la pared, no el de un marco."""
    area_por_plano: dict[float, float] = defaultdict(float)
    for cara in bm.faces:
        if cara.normal.y < -0.99:
            area_por_plano[round(cara.verts[0].co.y, 3)] += cara.calc_area()
    return max(area_por_plano, key=lambda y: area_por_plano[y])


def main() -> None:
    configurar()
    objeto = bpy.data.objects[OBJETO]
    malla = objeto.data
    assert objeto.matrix_world == Matrix.Identity(4), "El friso ya no está en el origen."
    antes = sum(len(p.vertices) - 2 for p in malla.polygons)
    bm = bmesh.new()
    bm.from_mesh(malla)
    frente = _plano_del_frente(bm)
    # Un marco sale hacia el salón: sus caras tienen algún vértice delante del plano de la pared.
    marcos = [c for c in bm.faces if any(v.co.y < frente - TOLERANCIA for v in c.verts)]
    bmesh.ops.delete(bm, geom=marcos, context="FACES")
    sueltos = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=sueltos, context="VERTS")
    bm.to_mesh(malla)
    bm.free()
    if MARCA in malla:
        del malla[MARCA]
    malla.update()
    despues = sum(len(p.vertices) - 2 for p in malla.polygons)
    print(f"{OBJETO}: {len(marcos)} caras de marco quitadas, {antes} -> {despues} triángulos "
          f"({despues - antes:+d})")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()

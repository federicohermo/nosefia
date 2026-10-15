"""Cuelga una segunda nota de «no tirar papel» arriba del segundo inodoro del baño.

    blender --background --python-exit-code 1 --python \\
        .claude/scripts/blender/nota_del_segundo_inodoro.py -- --aplicar
    python .claude/scripts/exportar_modelo.py
    python .claude/scripts/hornear.py

Sin `--aplicar` guarda en `reports/nota-del-segundo-inodoro.blend` y el `.blend` del repo queda
como estaba. El orden de la cadena es ése: este script, exportar y hornear.

**La copia comparte la malla de la primera nota**, y con ella el material y la imagen que pintó
el artista: no hay una hoja nueva que mantener, y un retoque a la nota llega a las dos.

**El corrimiento sale de los dos inodoros, no de un número.** `renovar_bano.py` puso el segundo
a 1,61 m del primero, y `refinar_artefactos.py` los vuelve a ubicar. Copiar esa cifra acá deja la
nota colgando en el lugar viejo el día que alguien corra un inodoro. Se mide la diferencia en X
entre los centros de sus cajas en el mundo.

**Es idempotente.** Si la copia ya existe, se borra y se vuelve a hacer: correrlo dos veces deja
una sola, en el mismo lugar. Si falta la nota o un inodoro, termina con un error que nombra el
objeto y no guarda nada.

No rehace la colección del baño: eso es `renovar_bano.py`, que pisaría los arreglos que vinieron
después.
"""

import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
NOTA = "nota baño inodoro-col"
COPIA = "nota baño inodoro 2-col"
PRIMER_INODORO = "inodoro-convcol"
SEGUNDO_INODORO = "bano_inodoro_2-convcol"


def _objeto(nombre: str) -> bpy.types.Object:
    objeto = bpy.data.objects.get(nombre)
    if objeto is None:
        raise SystemExit(f"Falta el objeto «{nombre}» en {FUENTE.name}; no se guardó nada.")
    return objeto


def _centro(objeto: bpy.types.Object) -> Vector:
    return sum((objeto.matrix_world @ Vector(v) for v in objeto.bound_box), Vector()) / 8


def colgar() -> bpy.types.Object:
    nota = _objeto(NOTA)
    primero = _objeto(PRIMER_INODORO)
    segundo = _objeto(SEGUNDO_INODORO)
    anterior = bpy.data.objects.get(COPIA)
    if anterior is not None:
        bpy.data.objects.remove(anterior, do_unlink=True)
    corrimiento = _centro(segundo).x - _centro(primero).x
    copia = nota.copy()
    copia.name = COPIA
    for coleccion in nota.users_collection:
        coleccion.objects.link(copia)
    copia.matrix_world = Matrix.Translation((corrimiento, 0, 0)) @ nota.matrix_world
    print(f"Corrimiento entre inodoros: {corrimiento:.6f} m")
    print(f"{COPIA}: {tuple(round(c, 6) for c in copia.matrix_world.translation)}")
    return copia


if __name__ == "__main__":
    configurar()
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    colgar()
    prueba = RAIZ / "reports/nota-del-segundo-inodoro.blend"
    destino = FUENTE if "--aplicar" in sys.argv else prueba
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print("Nota del segundo inodoro colgada:", destino)

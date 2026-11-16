"""Separa el freezer de helados del mostrador: deja `LUZ` m de aire entre su costado y la madera.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/despegar_freezer_del_mostrador.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/despegar-freezer-del-mostrador.blend` y no modifica el `.blend`
del repo. Con `--aplicar`, guarda la fuente canónica en su lugar. Después va la cadena:
`exportar_modelo.py`, `integrar_modelo.py`, `actualizar_apoyos.py` y `hornear.py`.

## Por qué

El costado sur del freezer, el azul, tocaba el frente de madera del mostrador: sin luz entre los
dos, el borde de la mesada y el marco del freezer se leían como una sola pieza.

## Qué cambia

- **`freezer_helados-col` se corre hacia el norte** hasta que entre su costado sur y lo más al
  norte del mostrador (`EscritorioComputadora-col`) haya `LUZ`. Ningún script lo ubicaba: el
  freezer viene del `.blend` del artista, así que acá se mide y se mueve.
- **Todo lo que cuelga de él viaja con él**, porque es hijo suyo: los 22 productos exhibidos
  (`exhibido_*`), el vidrio (`freezer_helados_vidrio`) y el cartel (`freezer_aviso_*`). El script
  falla si alguno no se movió igual.
- **La colisión** sale de la malla del freezer: `descomponer_modelo.gd` la rehace en la cadena y
  acompaña el corrimiento sin tocar nada a mano.
- El mostrador, el exhibidor de golosinas y el resto no se mueven.

## Lo que cuesta

0 triángulos, 0 materiales y 0 texturas. Es idempotente: si la luz ya es `LUZ`, no cambia nada.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

FREEZER = "freezer_helados-col"
MOSTRADOR = "EscritorioComputadora-col"
#: El aire que se ve entre el freezer y el mostrador, en metros.
LUZ = 0.05
#: Dos medidas a menos de esto son la misma.
IGUAL = 1e-3


def _objeto(nombre: str):
    objeto = bpy.data.objects.get(nombre)
    if objeto is None:
        raise SystemExit(f"falta el objeto {nombre}; no se guardó nada")
    return objeto


def _vertices(objeto) -> list[Vector]:
    return [objeto.matrix_world @ v.co for v in objeto.data.vertices]


def _luz_actual() -> float:
    """Lo que separa el costado sur del freezer de lo más al norte del mostrador bajo él."""
    freezer = _vertices(_objeto(FREEZER))
    mostrador = _vertices(_objeto(MOSTRADOR))
    desde = min(v.x for v in freezer) - IGUAL
    hasta = max(v.x for v in freezer) + IGUAL
    sur = min(v.y for v in freezer)
    pegado = [v.y for v in mostrador if desde <= v.x <= hasta and v.y < sur + 0.2]
    if not pegado:
        raise SystemExit("el mostrador no llega al freezer; no se guardó nada")
    return sur - max(pegado)


def despegar() -> bool:
    freezer = _objeto(FREEZER)
    if freezer.parent is not None:
        raise SystemExit(f"{FREEZER} tiene padre; no se guardó nada")
    luz = _luz_actual()
    print(f"luz entre el freezer y el mostrador: {luz:.4f} m")
    if abs(luz - LUZ) < IGUAL:
        print("el freezer ya está despegado; no cambia nada")
        return False
    corrimiento = LUZ - luz
    hijos = freezer.children_recursive
    antes = {h.name: h.matrix_world.translation.copy() for h in hijos}
    freezer.location.y += corrimiento
    bpy.context.view_layer.update()
    for hijo in hijos:
        movio = hijo.matrix_world.translation - antes[hijo.name]
        if abs(movio.y - corrimiento) > IGUAL or abs(movio.x) > IGUAL or abs(movio.z) > IGUAL:
            raise SystemExit(f"{hijo.name} no viajó con el freezer: {tuple(movio)}")
    print(f"freezer y sus {len(hijos)} hijos corridos {corrimiento:+.4f} m en Y")
    return True


def verificar() -> None:
    luz = _luz_actual()
    if abs(luz - LUZ) > IGUAL:
        raise SystemExit(f"la luz quedó en {luz:.4f} m, no en {LUZ} m")
    print(f"el freezer queda a {luz:.3f} m del mostrador")


def main() -> None:
    configurar()
    despegar()
    verificar()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/despegar-freezer-del-mostrador.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()

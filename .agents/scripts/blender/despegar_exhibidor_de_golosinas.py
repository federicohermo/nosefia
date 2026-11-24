"""Separa el exhibidor de golosinas del mostrador y del freezer: `LUZ` m de aire contra cada uno.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/despegar_exhibidor_de_golosinas.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/despegar-exhibidor-de-golosinas.blend` y no modifica el
`.blend` del repo. Con `--aplicar`, guarda la fuente canónica en su lugar. Después va la cadena:
`exportar_modelo.py`, `integrar_modelo.py`, `actualizar_apoyos.py` y `hornear.py`.

## Por qué

El costado del exhibidor tocaba la tapa y la madera del mostrador, y su otro costado tocaba el
freezer: sin luz entre los tres, los encuentros se leían como una sola pieza. El freezer ya se
separó del mostrador (`despegar_freezer_del_mostrador.py`); este deja los tres encuentros parejos.

## Qué cambia

- **`exhibidor_golosinas-col` se corre hacia el norte** hasta que entre su costado sur y lo más
  al norte del mostrador haya `LUZ`, y **hacia el oeste** hasta que entre su costado este y el
  freezer haya `LUZ`. Se leen las tres posiciones del `.blend`: ningún número es fijo.
- **Lo que cuelga de él viaja con él**: es hijo suyo, y el script falla si alguno no se movió
  igual. Las golosinas son una malla suelta (`exhibido_golosinas`), sin separadores aparte.
- **La colisión** sale de su malla: `descomponer_modelo.gd` la rehace en la cadena.
- El mostrador, el freezer y `estante_mesada` no se mueven.

## Lo que cuesta

0 triángulos, 0 materiales y 0 texturas. Es idempotente: si las dos luces ya son `LUZ`, no cambia
nada.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

EXHIBIDOR = "exhibidor_golosinas-col"
FREEZER = "freezer_helados-col"
MOSTRADOR = "EscritorioComputadora-col"
#: El aire que se ve entre el exhibidor y cada vecino, en metros.
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


def _luces() -> tuple[float, float]:
    """La luz con el mostrador, al sur, y con el freezer, al este."""
    exhibidor = _vertices(_objeto(EXHIBIDOR))
    mostrador = _vertices(_objeto(MOSTRADOR))
    freezer = _vertices(_objeto(FREEZER))
    x0, x1 = min(v.x for v in exhibidor) - IGUAL, max(v.x for v in exhibidor) + IGUAL
    y0, y1 = min(v.y for v in exhibidor) - IGUAL, max(v.y for v in exhibidor) + IGUAL
    sur = min(v.y for v in exhibidor)
    este = max(v.x for v in exhibidor)
    bajo = [v.y for v in mostrador if x0 <= v.x <= x1 and v.y < sur + 0.2]
    al_lado = [v.x for v in freezer if y0 <= v.y <= y1 and v.x > este - 0.2]
    if not bajo or not al_lado:
        raise SystemExit("el exhibidor no tiene mostrador o freezer al lado; no se guardó nada")
    return sur - max(bajo), min(al_lado) - este


def despegar() -> bool:
    exhibidor = _objeto(EXHIBIDOR)
    if exhibidor.parent is not None:
        raise SystemExit(f"{EXHIBIDOR} tiene padre; no se guardó nada")
    con_el_mostrador, con_el_freezer = _luces()
    print(f"luz con el mostrador: {con_el_mostrador:.4f} m; con el freezer: {con_el_freezer:.4f} m")
    al_norte = LUZ - con_el_mostrador
    al_oeste = LUZ - con_el_freezer
    if abs(al_norte) < IGUAL and abs(al_oeste) < IGUAL:
        print("el exhibidor ya está despegado; no cambia nada")
        return False
    hijos = exhibidor.children_recursive
    antes = {h.name: h.matrix_world.translation.copy() for h in hijos}
    exhibidor.location.y += al_norte
    exhibidor.location.x -= al_oeste
    bpy.context.view_layer.update()
    for hijo in hijos:
        movio = hijo.matrix_world.translation - antes[hijo.name]
        if (
            abs(movio.y - al_norte) > IGUAL
            or abs(movio.x + al_oeste) > IGUAL
            or abs(movio.z) > IGUAL
        ):
            raise SystemExit(f"{hijo.name} no viajó con el exhibidor: {tuple(movio)}")
    print(
        f"exhibidor y sus {len(hijos)} hijos corridos {al_norte:+.4f} en Y y {-al_oeste:+.4f} en X"
    )
    return True


def verificar() -> None:
    con_el_mostrador, con_el_freezer = _luces()
    for nombre, luz in (("el mostrador", con_el_mostrador), ("el freezer", con_el_freezer)):
        if abs(luz - LUZ) > IGUAL:
            raise SystemExit(f"la luz con {nombre} quedó en {luz:.4f} m, no en {LUZ} m")
    print(
        f"el exhibidor queda a {con_el_mostrador:.3f} m del mostrador y {con_el_freezer:.3f} del "
        "freezer"
    )


def main() -> None:
    configurar()
    despegar()
    verificar()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/despegar-exhibidor-de-golosinas.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()

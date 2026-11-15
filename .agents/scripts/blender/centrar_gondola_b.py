"""Corre la góndola isla (`B`) a lo largo hasta que su centro quede en el de la mesa del medio.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/centrar_gondola_b.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/centrar-gondola-b.blend` y no modifica el `.blend` del repo.
Con `--aplicar`, guarda la fuente canónica en su lugar. Después va la cadena entera, igual que para
`acortar_gondola_b.py`.

## Por qué

`acortar_gondola_b.py` dejó el extremo sur de la isla donde estaba y le quitó todo por el norte, así
que la isla quedó corrida hacia la entrada respecto de la fila de mesas. Con esto se alinea con la
mesa del medio.

## Qué cambia

- **Las cuatro piezas de `B` y sus bandejas viajan rígidas** a lo largo del eje Y de Blender, el de
  la fila de mesas, la distancia entre su centro y el de `MESA`. Se leen las dos cajas del `.blend`:
  ningún número es fijo. No cambia ni su ancho, ni su largo, ni su posición en X.
- **Las unidades de `B` viajan rígidas**, con las de la partida de prueba que se arman después.
- **El grupo de la pared este NO se mueve.** Ya no queda alineado con el extremo sur de `B`: esa
  alineación era del paso anterior y `gondola_a_la_pared.py` no se vuelve a correr.

## Por qué sólo se mueven los `-noimp`

Igual que en `acortar_gondola_b.py`: el modificador `Muebles` arma la geometría que ve Godot con
los cuatro `-noimp`, y la malla propia de `B` no entra en el resultado.

## Lo que cuesta

0 triángulos, 0 materiales y 0 texturas. Es idempotente: si los centros ya coinciden, no cambia
nada.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Matrix  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(RAIZ / ".claude/scripts/blender"))
import acortar_gondola_b as isla  # noqa: E402
import gondola_a_la_pared as pared  # noqa: E402
from lib.consola import configurar  # noqa: E402

B = isla.B
PREFIJO = isla.PREFIJO
PIEZAS = isla.PIEZAS
MESA = "salon_mesa_2-col"
#: Dos medidas a menos de esto son la misma.
IGUAL = 1e-3


def _centro_de_la_isla(piezas) -> float:
    ys = [p.y for nombre in PIEZAS for p in pared._puntos(piezas[nombre].cuerpo)]
    return (min(ys) + max(ys)) / 2


def _centro_de_la_mesa() -> float:
    ys = [p.y for p in pared._puntos(pared._objeto(MESA))]
    return (min(ys) + max(ys)) / 2


def centrar() -> bool:
    bpy.context.view_layer.update()
    piezas = pared._piezas(B, PREFIJO, PIEZAS, False)
    corrimiento = _centro_de_la_mesa() - _centro_de_la_isla(piezas)
    if abs(corrimiento) < IGUAL:
        print("B ya está centrada con la mesa del medio; no cambia nada")
        return False
    gondola = pared._objeto(B)
    matriz = Matrix.Translation((0.0, corrimiento, 0.0))
    for pieza in piezas.values():
        pared._mover_pieza(pieza, matriz, gondola)
    movidas = pared._mover_unidades(("B.",), matriz)
    bpy.context.view_layer.update()
    print(f"B corrida {corrimiento:+.4f} m a lo largo con {movidas} unidades")
    return True


def verificar() -> None:
    piezas = pared._piezas(B, PREFIJO, PIEZAS, False)
    diferencia = _centro_de_la_isla(piezas) - _centro_de_la_mesa()
    if abs(diferencia) > IGUAL:
        raise SystemExit(f"la isla quedó a {diferencia:+.4f} m del centro de la mesa del medio")
    prefijos = tuple(f"B.{cara}." for cara in PIEZAS)
    _, bm, estantes = isla.medir_la_union("B")
    bm.free()
    pared._verificar_apoyos(
        {c: None for c in estantes if c.startswith(prefijos)}, "B", prefijos, isla.medir_la_union
    )
    print(f"B queda con su centro en el de {MESA}")


def main() -> None:
    configurar()
    centrar()
    verificar()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/centrar-gondola-b.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()

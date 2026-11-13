"""Acerca a la puerta blanca el tacho del salón, a lo largo de la pared este.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/mover_tacho_del_salon.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/mover-tacho-del-salon.blend` y no modifica el `.blend` del
repo. Con `--aplicar`, guarda la fuente canónica en su lugar. Después corren `exportar_modelo.py`,
`disponer.py`, `integrar_modelo.py`, `actualizar_apoyos.py` y `hornear.py`.

## Qué cambia

El tacho del salón (`tachitobasura-col`, con su bisagra y su tapa) se corre sólo en `y`, hacia la
puerta blanca de la pared este. No cambia su distancia a la pared ni su giro. Es idempotente: el
destino es una posición absoluta del centro, no un corrimiento.

## Lo que cuesta

0 triángulos, 0 materiales y 0 texturas adicionales.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Matrix, Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

TACHO = "tachitobasura-col"
#: Donde queda el centro del cuerpo en `y`. Antes estaba en -4,840: el corrimiento es de 1,0 m,
#: casi una baldosa del salón (1,011 m en este sentido).
CENTRO_Y = -3.84


def _centro_del_cuerpo(objeto) -> Vector:
    puntos = [objeto.matrix_world @ Vector(v) for v in objeto.bound_box]
    return sum(puntos, Vector()) / 8.0


def mover() -> None:
    tacho = bpy.data.objects.get(TACHO)
    if tacho is None:
        raise ValueError(f"falta el objeto {TACHO}")
    corrimiento = CENTRO_Y - _centro_del_cuerpo(tacho).y
    tacho.matrix_world = Matrix.Translation(Vector((0.0, corrimiento, 0.0))) @ tacho.matrix_world
    bpy.context.view_layer.update()
    print(f"{TACHO}: corrido {corrimiento:+.3f} m en y")


def main() -> None:
    configurar()
    mover()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/mover-tacho-del-salon.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()

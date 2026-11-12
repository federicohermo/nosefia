"""Suaviza las esquinas redondeadas de los lavatorios del baño.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/suavizar_lavatorios.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después van `exportar_modelo.py`, `hornear.py` y `hornear.py --sin-luz`.

## Por qué

Las esquinas redondeadas del lavatorio son pocas caras, que doblan de 30 a 50 grados entre sí, y
esas aristas estaban marcadas como filosas: cada cara se sombreaba plana. Y el frente plano
tomaba en sus bordes la normal promediada con la esquina, inclinada: la porcelana brillante
reflejaba esa inclinación como franjas verticales. El usuario lo vio como un problema de
normales.

## Qué cambia

- Cada arista filosa de menos de `ANGULO` grados queda suave. Las aristas vivas, de 60 grados o
  más (el borde de la mesada, el frente con la base), siguen filosas.
- El modificador `Normales de caras y biseles` pesa las normales sólo por el área de cada cara,
  con el peso al máximo: las caras grandes y planas mandan, y el frente queda plano hasta su
  borde. La curva queda en las caras chicas de la esquina.

## Lo que cuesta

Ningún triángulo, material ni dibujo más. Es idempotente.
"""

import math
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

LAVATORIOS = ("vanitory-convcol", "bano_lavatorio_2-convcol")
#: El modificador que les puso `refinar_artefactos.py`.
NORMALES = "Normales de caras y biseles"
#: Las esquinas redondeadas doblan hasta 50 grados por arista; las aristas vivas, desde 60.
ANGULO = 55.0


def suavizar(objeto) -> int:
    bm = bmesh.new()
    bm.from_mesh(objeto.data)
    suavizadas = 0
    for arista in bm.edges:
        if not arista.smooth and arista.is_manifold and math.degrees(arista.calc_face_angle(0)) < ANGULO:
            arista.smooth = True
            suavizadas += 1
    bm.to_mesh(objeto.data)
    bm.free()
    objeto.data.update()
    pesar_normales(objeto)
    return suavizadas


def pesar_normales(objeto) -> None:
    modificador = objeto.modifiers[NORMALES]
    modificador.mode = "FACE_AREA"
    modificador.weight = 100


def main() -> None:
    configurar()
    for nombre in LAVATORIOS:
        print(f"{nombre}: {suavizar(bpy.data.objects[nombre])} aristas suavizadas")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()

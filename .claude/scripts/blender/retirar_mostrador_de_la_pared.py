"""Retira el extremo sur del mostrador de la pared del frente y del marco del ventanal.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/retirar_mostrador_de_la_pared.py -- [--aplicar]

Sin `--aplicar` guarda en `reports/retirar-mostrador-de-la-pared.blend` y no toca el `.blend` del
repo. Con `--aplicar` lo guarda en su lugar. Va antes de `armar_atlas.py`, `exportar_modelo.py` e
`integrar_modelo.py`, y las colisiones de `EscritorioComputadora-col` se regeneran con ellos.

## Por qué

El brazo largo del mostrador llegaba a `y = -6,28`, el plano de la pared del frente. Su esquina
este (`x = 1,677`) pasaba además por detrás de la cara interior de `local_marco_frente-col`
(`y = -6,26`, desde `x = 1,625`). La tapa de mármol se veía pegada a la pared y al marco.

## Qué cambia

Los vértices del extremo sur de `EscritorioComputadora-col` suben juntos hacia el norte hasta que
el extremo queda a `LUZ` de la cara interior del marco. El mostrador no se mueve: la compuerta, la
computadora, el lector y la ventanilla quedan donde están, porque están en el otro extremo. Sólo
se acorta el brazo en unos 7 cm. La UV no se toca: esos 7 cm estiran la textura un 3 %.

## Lo que cuesta

0 triángulos, 0 materiales, 0 texturas. Es idempotente: la distancia al marco sale de la escena, y
con la luz ya puesta no mueve nada.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
PRUEBA = RAIZ / "reports/retirar-mostrador-de-la-pared.blend"
MOSTRADOR = "EscritorioComputadora-col"
MARCO = "local_marco_frente-col"
#: Luz visible entre el extremo del mostrador y la cara interior del marco.
LUZ = 0.05
#: Un vértice más al sur que esto es del extremo; el resto del mostrador queda a más de 2 m.
LIMITE_DEL_EXTREMO = -5.5


def _caja(objeto) -> tuple[Vector, Vector]:
    puntos = [objeto.matrix_world @ Vector(c) for c in objeto.bound_box]
    return (
        Vector([min(p[i] for p in puntos) for i in range(3)]),
        Vector([max(p[i] for p in puntos) for i in range(3)]),
    )


def aplicar() -> dict:
    mostrador = bpy.data.objects[MOSTRADOR]
    assert mostrador.data.users == 1, "la malla del mostrador es compartida"
    marco = bpy.data.objects[MARCO]
    cara_del_marco = _caja(marco)[1].y
    antes = _caja(mostrador)[0].y
    desvio = cara_del_marco + LUZ - antes
    if abs(desvio) > 1e-6:
        inversa = mostrador.matrix_world.inverted().to_3x3()
        local = inversa @ Vector((0.0, desvio, 0.0))
        movidos = 0
        for vertice in mostrador.data.vertices:
            if (mostrador.matrix_world @ vertice.co).y < LIMITE_DEL_EXTREMO:
                vertice.co += local
                movidos += 1
        assert movidos, "el mostrador no tiene vértices en el extremo"
        mostrador.data.update()
        bpy.context.view_layer.update()
    despues = _caja(mostrador)[0].y
    assert abs(despues - (cara_del_marco + LUZ)) < 1e-4, despues
    return {
        "cara_del_marco_y": round(cara_del_marco, 4),
        "extremo_antes_y": round(antes, 4),
        "extremo_despues_y": round(despues, 4),
        "luz_al_marco": round(despues - cara_del_marco, 4),
    }


def main() -> None:
    configurar()
    modo_aplicar = "--aplicar" in (sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])
    resultado = aplicar()
    if modo_aplicar:
        bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE), check_existing=False)
    else:
        PRUEBA.parent.mkdir(exist_ok=True)
        bpy.ops.wm.save_as_mainfile(
            filepath=str(PRUEBA), check_existing=False, relative_remap=True
        )
    print(resultado)


if __name__ == "__main__":
    main()

"""Tapa la tira de pared beige que asoma junto al marco, adentro del cuartito de limpieza.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/tapar_tira_del_cuartito.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/tapar-tira-del-cuartito.blend` y no modifica el `.blend` del
repo. Con `--aplicar`, guarda la fuente canónica en su lugar. Después corren
`exportar_modelo.py`, `integrar_modelo.py` y `hornear.py`.

## Por qué

El revestimiento de bloques del cuartito son tres franjas pegadas a la pared del depósito, una a
cada lado del hueco y otra sobre el dintel. Cada franja nace con el borde pegado al hueco, pero en
el modelo ese borde quedó inclinado: abajo toca el hueco y arriba se aparta unos 5 cm. Entre el
borde y el hueco queda a la vista la cara de la pared, que es beige, como una cuña que crece hacia
el techo. De pie adentro y mirando la puerta se lee como una tira beige entre el rincón de bloques
y el marco.

## Qué cambia

- **`cuartito_revestimiento`**: los vértices de los dos bordes que dan al hueco vuelven a la y del
  hueco, que sale de la caja del marco. Las franjas del lado izquierdo y derecho quedan verticales
  y la del dintel, rectangular. No cambia la cantidad de vértices ni de caras, ni la UV.

## Lo lejos que busca

Sólo mueve los vértices que están a menos de `MARGEN` del hueco, del lado de afuera. Un vértice del
rincón o del techo queda donde está.

## Lo que cuesta

0 triángulos, 0 materiales y 0 texturas. Es idempotente: si los bordes ya están sobre el hueco, no
mueve nada.
"""

import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
REVESTIMIENTO = "cuartito_revestimiento"
MARCO = "cuartito_marco_puerta"
#: Hasta dónde un borde inclinado cuenta como borde del hueco.
MARGEN = 0.1
TOLERANCIA = 1e-6


def _hueco():
    caja = [bpy.data.objects[MARCO].matrix_world @ Vector(c)
            for c in bpy.data.objects[MARCO].bound_box]
    return min(p.y for p in caja), max(p.y for p in caja)


def aplicar():
    objeto = bpy.data.objects[REVESTIMIENTO]
    y0, y1 = _hueco()
    matriz = objeto.matrix_world
    inversa = matriz.inverted()
    movidos = []
    for vertice in objeto.data.vertices:
        punto = matriz @ vertice.co
        if y0 - MARGEN < punto.y < y0 - TOLERANCIA:
            destino = y0
        elif y1 + TOLERANCIA < punto.y < y1 + MARGEN:
            destino = y1
        else:
            continue
        movidos.append({"vertice": vertice.index, "y_antes": round(punto.y, 4),
                        "y_despues": round(destino, 4), "z": round(punto.z, 3)})
        vertice.co = inversa @ Vector((punto.x, destino, punto.z))
    objeto.data.update()
    for vertice in objeto.data.vertices:
        punto = matriz @ vertice.co
        assert not (y0 - MARGEN < punto.y < y0 - TOLERANCIA), vertice.index
        assert not (y1 + TOLERANCIA < punto.y < y1 + MARGEN), vertice.index
    return {"hueco_y": [round(y0, 4), round(y1, 4)], "vertices_movidos": movidos}


def main():
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opciones = parser.parse_args(argumentos)
    resultado = aplicar()
    (RAIZ / "reports").mkdir(exist_ok=True)
    destino = FUENTE if opciones.aplicar else RAIZ / "reports/tapar-tira-del-cuartito.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False,
                                relative_remap=True)
    print(json.dumps(resultado, default=float))


if __name__ == "__main__":
    main()

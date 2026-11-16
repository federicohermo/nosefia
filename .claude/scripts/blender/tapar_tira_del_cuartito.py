"""Tapa la tira de pared beige junto al marco del cuartito de limpieza y alinea sus bloques.

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

Al mover esos vértices la UV se quedó como estaba, y la textura quedó sesgada en las tres
franjas: las hiladas se inclinaban junto al marco y la traba de los bloques cortaba sobre el
dintel.

## Qué cambia

- **`cuartito_revestimiento`, geometría**: los vértices de los dos bordes que dan al hueco vuelven
  a la y del hueco, que sale de la caja del marco. Las franjas de los lados y la del dintel quedan
  rectángulos de bordes verticales y horizontales. No cambia la cantidad de vértices ni de caras.
- **`cuartito_revestimiento`, UV**: las tres franjas toman la proyección plana del depósito,
  `ladrillos_del_deposito._reproyectar`: u y v salen de la posición del mundo, con el mismo
  origen y la misma cobertura de 2,4 × 3,6 m que el resto de la pared. Las hiladas y la traba
  siguen de largo de una franja a la otra, sin salto.

## Lo lejos que busca

Sólo mueve los vértices que están a menos de `MARGEN` del hueco, del lado de afuera. Un vértice del
rincón o del techo queda donde está.

## Lo que cuesta

0 triángulos, 0 materiales y 0 texturas. Es idempotente: si los bordes ya están sobre el hueco, no
los mueve, y la UV sale siempre de la posición del mundo.
"""

import argparse
import importlib.util
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
REVESTIMIENTO = "cuartito_revestimiento"
MARCO = "cuartito_marco_puerta"
EDIFICIO = "almacen-col"
#: Hasta dónde un borde inclinado cuenta como borde del hueco.
MARGEN = 0.1
TOLERANCIA = 1e-6


def _bloques_del_deposito():
    ruta = Path(__file__).with_name("ladrillos_del_deposito.py")
    spec = importlib.util.spec_from_file_location("ladrillos_del_deposito", ruta)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


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
    for cara in objeto.data.polygons:
        puntos = [matriz @ objeto.data.vertices[i].co for i in cara.vertices]
        assert len({round(p.x, 4) for p in puntos}) == 1, cara.index
        assert len({round(p.y, 4) for p in puntos}) == 2, cara.index
        assert len({round(p.z, 4) for p in puntos}) == 2, cara.index
    bloques = _bloques_del_deposito()
    _, limites = bloques._caras_de_bloques(bpy.data.objects[EDIFICIO])
    bloques._reproyectar(objeto, [c.index for c in objeto.data.polygons], limites)
    objeto.data.update()
    return {"hueco_y": [round(y0, 4), round(y1, 4)], "vertices_movidos": movidos,
            "origen_de_la_uv": [round(limites[0][0], 4), round(limites[0][1], 4)]}


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

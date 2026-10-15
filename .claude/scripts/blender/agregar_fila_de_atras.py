"""Le suma una fila de atrás a la tanda reponible de un producto, si entra en su estante.

    blender <fuente>.blend --background --python .claude/scripts/blender/agregar_fila_de_atras.py -- FERNET_GOD S.sur.0/0

**Cambia el `.blend` y lo guarda en su lugar**, como `compatibilizar_stock.py`: no rehace el
reparto artístico, sólo agrega copias enlazadas detrás de la fila de adelante. Después van
`exportar_modelo.py` y `blender/disponer.py`, en ese orden.

**La fila entra o no entra entera.** Cada copia nueva se tantea contra el mueble y contra las
demás unidades: si alguna choca o queda sin chapa debajo, el producto queda como estaba y se
dice por qué.

**La unidad pasa a la fila de atrás.** `disponer.py` pide que la tanda arranque en la unidad y
que la fila de atrás vaya primero: la unidad toma el primer lugar de atrás y una copia nueva
ocupa su lugar de adelante.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Vector  # type: ignore[import-not-found]
from mathutils.bvhtree import BVHTree  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.blender import COLECCION_DE_GUIA  # noqa: E402
from lib.gondola import AIRE  # noqa: E402

#: Cuánto puede bajar la chapa debajo de una copia de atrás: la de una cabecera es una rampa.
CAIDA_DEL_APOYO = 0.06

#: Desde qué altura sobre el pie se tantea el fondo. Más abajo, en una rampa, el rayo choca con
#: la propia chapa que sube a unos centímetros y la fila parece cortada por el mueble.
SOBRE_EL_PIE = 0.05


def esquinas(objeto, corrimiento=Vector()):
    """Los vértices del envase en el mundo. La caja de `bound_box` gira con la unidad, y una
    botella puesta en diagonal mide de fondo hasta un 30 % más que de verdad."""
    return [objeto.matrix_world @ v.co + corrimiento for v in objeto.data.vertices]


def extension(puntos, eje):
    valores = [p.dot(eje) for p in puntos]
    return min(valores), max(valores)


def se_pisan(a, b, holgura=0.002):
    for eje in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        a0, a1 = extension(a, eje)
        b0, b1 = extension(b, eje)
        if a1 - holgura <= b0 or b1 - holgura <= a0:
            return False
    return True


def arbol_del_mueble(mueble):
    malla = mueble.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    vertices = [mueble.matrix_world @ v.co for v in malla.vertices]
    caras = [tuple(p.vertices) for p in malla.polygons]
    return BVHTree.FromPolygons(vertices, caras)


def copias_de(clave):
    """Las copias de la tanda: la reponible de un producto (`FERNET_GOD`) o una tanda por su
    rótulo (`S.sur.0/0`), que puede ser fija."""
    if "/" in clave:
        return [o for o in bpy.context.scene.objects if o.get("tanda") == clave]
    return [
        o for o in bpy.context.scene.objects
        if o.get("producto") == clave and not o.get("fija", True)
    ]


def fila_de_atras(clave):
    """Las copias nuevas de `clave`, o el motivo por el que no entran."""
    copias = copias_de(clave)
    if not copias:
        return None, "no hay una tanda con ese nombre"
    if any(o["fila"] == "atras" for o in copias):
        return None, "ya tiene fila de atrás"
    frente = sorted(copias, key=lambda o: int(o["orden"]))
    if len(frente) < 2:
        return None, "una sola copia: no hay hacia dónde medir el fondo"
    mueble = frente[0].parent
    lateral = frente[-1].matrix_world.translation - frente[0].matrix_world.translation
    lateral.z = 0.0
    fondo = lateral.normalized().cross(Vector((0, 0, 1))).normalized()
    centro = sum((Vector(c) for c in mueble.bound_box), Vector()) / 8
    centro = mueble.matrix_world @ centro
    if (centro - frente[0].matrix_world.translation).dot(fondo) < 0:
        fondo = -fondo
    hondo = extension(esquinas(frente[0]), fondo)
    corrimiento = fondo * (hondo[1] - hondo[0] + AIRE)
    arbol = arbol_del_mueble(mueble)
    vecinas = [
        o for o in bpy.context.scene.objects
        if "tanda" in o and o.get("tanda") != frente[0]["tanda"] and o.parent == mueble
    ]
    for copia in frente:
        nuevas = esquinas(copia, corrimiento)
        abajo = min(p.z for p in nuevas)
        arriba = max(p.z for p in nuevas)
        origen = copia.matrix_world.translation
        for altura in (abajo + SOBRE_EL_PIE, (abajo + arriba) / 2, arriba - 0.01):
            desde = Vector((origen.x, origen.y, altura))
            golpe = arbol.ray_cast(desde, fondo, corrimiento.length + (hondo[1] - hondo[0]) / 2)
            if golpe[0] is not None:
                return None, f"el mueble corta la fila a {golpe[3]:.3f} m de {copia.name}"
        medio = sum(nuevas, Vector()) / len(nuevas)
        apoyo = arbol.ray_cast(medio, Vector((0, 0, -1)), (arriba - abajo) / 2 + CAIDA_DEL_APOYO)
        if apoyo[0] is None:
            return None, f"detrás de {copia.name} no hay chapa"
        for vecina in vecinas:
            if se_pisan(nuevas, esquinas(vecina)):
                return None, f"detrás de {copia.name} está {vecina.name}"
    return (frente, corrimiento), None


#: Desde cuánto más arriba de cada vértice del pie se busca la chapa. Mucho más alto encuentra el
#: estante de arriba.
DESDE_ARRIBA = 0.03


def hueco(objeto, arbol):
    """Cuánto le falta al pie para tocar la chapa; negativo si se mete adentro."""
    puntos = [objeto.matrix_world @ v.co for v in objeto.data.vertices]
    abajo = min(p.z for p in puntos)
    menor = None
    for punto in (p for p in puntos if p.z < abajo + 0.02):
        golpe = arbol.ray_cast(punto + Vector((0, 0, DESDE_ARRIBA)), Vector((0, 0, -1)), 0.5)
        if golpe[0] is not None:
            distancia = punto.z - golpe[0].z
            menor = distancia if menor is None else min(menor, distancia)
    return menor


def agregar(frente, corrimiento):
    """Pone la fila nueva y deja la unidad primera: atrás de izquierda a derecha, después adelante.
    Una tanda fija no tiene unidad: sus copias nuevas salen de la primera."""
    unidad = frente[0]
    fija = bool(unidad.get("fija", False))
    cantidad = len(frente)
    nuevas = []
    arbol = arbol_del_mueble(unidad.parent)
    for copia in frente:
        nueva = unidad.copy()
        for coleccion in list(nueva.users_collection):
            coleccion.objects.unlink(nueva)
        bpy.data.collections[COLECCION_DE_GUIA].objects.link(nueva)
        nueva.parent = unidad.parent
        nueva.matrix_world = copia.matrix_world.copy()
        nueva.matrix_world.translation += corrimiento
        # En la rampa de una cabecera la chapa de atrás está a otra altura: se apoya igual.
        antes, despues = hueco(copia, arbol), hueco(nueva, arbol)
        if antes is not None and despues is not None:
            nueva.matrix_world.translation.z -= despues - antes
        nuevas.append(nueva)
    atras, adelante = nuevas, frente
    if not fija:
        # La unidad toma el primer lugar de atrás; la primera copia nueva, el suyo de adelante.
        pose_de_la_unidad = unidad.matrix_world.copy()
        unidad.matrix_world = nuevas[0].matrix_world.copy()
        nuevas[0].matrix_world = pose_de_la_unidad
        atras = [unidad] + nuevas[1:]
        adelante = [nuevas[0]] + frente[1:]
    for orden, objeto in enumerate(atras + adelante):
        objeto["tanda"] = unidad["tanda"]
        objeto["producto"] = unidad["producto"]
        objeto["fija"] = fija
        objeto["fila"] = "atras" if orden < cantidad else "adelante"
        objeto["orden"] = orden


def principal():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    claves = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not claves:
        raise SystemExit("falta el producto: -- FERNET_GOD S.sur.0/0")
    cambios = 0
    for clave in claves:
        lugar, motivo = fila_de_atras(clave)
        if lugar is None:
            print(f"{clave}: no se agrega, {motivo}")
            continue
        agregar(*lugar)
        cambios += 1
        print(f"{clave}: fila de atrás de {len(lugar[0])}")
    if cambios:
        bpy.ops.wm.save_mainfile()
        print(f"guardado: {bpy.data.filepath}")


if __name__ == "__main__":
    principal()

"""Corrige dos rótulos del reparto artístico sin rehacerlo. Edición de un paso sobre el `.blend`.

    blender <fuente>.blend --background --python .claude/scripts/blender/corregir_tandas.py

1. **Una tanda de dos filas sin fila de adelante** —todas sus copias rotuladas `atras`— pierde sus
   casilleros. La fila más cercana al pasillo pasa a ser la de adelante. Lo mismo con una tanda
   cuya fila de adelante no es la del pasillo.
2. **Lo echado hacia el pasillo se echa hacia atrás.** En una rampa la unidad se apoya contra el
   fondo; inclinada hacia adelante parece caerse. Se espeja la inclinación y se la vuelve a
   apoyar en la chapa.
"""

import math
import sys
from collections import defaultdict
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Matrix, Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parent))

from agregar_fila_de_atras import arbol_del_mueble  # noqa: E402

#: Desde cuántos grados una inclinación cuenta: menos es el temblor del modelo.
INCLINACION_MINIMA = 2.0

#: Los productos que se echan hacia atrás: los que se pidieron, y ningún otro.
A_ECHAR = ("DURONGA", "DUREXTRA")

#: Desde cuánto más arriba de cada vértice del pie se busca la chapa. Mucho más alto encuentra el
#: estante de arriba, y la unidad queda flotando.
DESDE_ARRIBA = 0.03

#: Cuánto más al fondo puede estar una copia y seguir en la fila del pasillo. Una unidad mide
#: más de 6 cm de profundidad: menos es el temblor del reparto.
SEPARACION_DE_FILAS = 0.06


def fondo_de(copia):
    """Hacia el centro del mueble, en horizontal: el lado contrario al pasillo."""
    mueble = copia.parent
    centro = mueble.matrix_world @ (sum((Vector(c) for c in mueble.bound_box), Vector()) / 8)
    fondo = centro - copia.matrix_world.translation
    fondo.z = 0.0
    return fondo.normalized()


def arriba_de(copia):
    rotacion = copia.matrix_world.to_3x3().normalized()
    eje = max((rotacion.col[i] for i in range(3)), key=lambda v: abs(v.z))
    return eje if eje.z > 0 else -eje


def eje_de_profundidad(copias):
    """La horizontal perpendicular a la fila, hacia el fondo. El centro del mueble no sirve como
    eje: en una heladera queda corrido de costado, y mezcla lo lateral con la profundidad."""
    puntos = [o.matrix_world.translation for o in copias]
    medio = sum(puntos, Vector()) / len(puntos)
    xx = sum((p.x - medio.x) ** 2 for p in puntos)
    yy = sum((p.y - medio.y) ** 2 for p in puntos)
    xy = sum((p.x - medio.x) * (p.y - medio.y) for p in puntos)
    angulo = 0.5 * math.atan2(2.0 * xy, xx - yy)
    profundidad = Vector((-math.sin(angulo), math.cos(angulo), 0.0))
    return profundidad if profundidad.dot(hacia_el_fondo(copias)) > 0 else -profundidad


def hacia_el_fondo(copias):
    """De la fila de adelante hacia la de atrás, según los rótulos que ya tiene. Si todas están
    en una sola fila, hacia el centro del mueble."""
    adelante = [o.matrix_world.translation for o in copias if str(o["fila"]) == "adelante"]
    atras = [o.matrix_world.translation for o in copias if str(o["fila"]) != "adelante"]
    if not adelante or not atras:
        return fondo_de(copias[0])
    return sum(atras, Vector()) / len(atras) - sum(adelante, Vector()) / len(adelante)


def fila_del_pasillo(copias):
    """Las copias de la fila más cercana al pasillo: las que están a menos de media unidad de la
    primera."""
    eje = eje_de_profundidad(copias)
    profundidades = [o.matrix_world.translation.dot(eje) for o in copias]
    primera = min(profundidades)
    return {o.name for o, d in zip(copias, profundidades) if d < primera + SEPARACION_DE_FILAS}


def mal_rotulada(copias):
    adelante = fila_del_pasillo(copias)
    return len(adelante) < len(copias) and adelante != {
        o.name for o in copias if str(o["fila"]) == "adelante"
    }


def rotular_adelante(copias):
    del_pasillo = fila_del_pasillo(copias)
    eje = eje_de_profundidad(copias)
    fila = Vector((eje.y, -eje.x, 0.0))
    a_lo_largo = lambda o: (o.matrix_world.translation.dot(fila), o.matrix_world.translation.dot(eje))
    adelante = sorted((o for o in copias if o.name in del_pasillo), key=a_lo_largo)
    atras = sorted((o for o in copias if o.name not in del_pasillo), key=a_lo_largo)
    for orden, objeto in enumerate(atras + adelante):
        objeto["fila"] = "atras" if orden < len(atras) else "adelante"
        objeto["orden"] = orden


def pie(copia):
    """Los vértices de más abajo, en el mundo: los que pueden tocar la chapa."""
    puntos = [copia.matrix_world @ v.co for v in copia.data.vertices]
    abajo = min(p.z for p in puntos)
    return [p for p in puntos if p.z < abajo + 0.02]


def hueco(copia, arbol):
    """Cuánto le falta al pie para tocar la chapa; negativo si se mete adentro."""
    menor = None
    for punto in pie(copia):
        golpe = arbol.ray_cast(punto + Vector((0, 0, DESDE_ARRIBA)), Vector((0, 0, -1)), 0.5)
        if golpe[0] is not None:
            distancia = punto.z - golpe[0].z
            menor = distancia if menor is None else min(menor, distancia)
    return menor


def echar_hacia_atras(copia, arbol):
    antes = hueco(copia, arbol)
    arriba = arriba_de(copia)
    horizontal = Vector((arriba.x, arriba.y, 0.0))
    angulo = math.asin(min(1.0, horizontal.length))
    eje = arriba.cross(Vector((0, 0, 1))).normalized()
    giro = Matrix.Rotation(2.0 * angulo, 4, eje)
    puntos = pie(copia)
    base = sum(puntos, Vector()) / len(puntos)
    copia.matrix_world = (
        Matrix.Translation(base) @ giro @ Matrix.Translation(-base) @ copia.matrix_world
    )
    despues = hueco(copia, arbol)
    if antes is not None and despues is not None:
        copia.matrix_world.translation.z -= despues - antes


def principal():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    tandas = defaultdict(list)
    for objeto in bpy.context.scene.objects:
        if "tanda" in objeto and objeto.get("producto"):
            tandas[str(objeto["tanda"])].append(objeto)
    arboles = {}
    cambios = 0
    for clave, copias in sorted(tandas.items()):
        filas = {str(c["fila"]) for c in copias}
        if (filas == {"atras"} and len(copias) % 2 == 0) or mal_rotulada(copias):
            rotular_adelante(copias)
            cambios += 1
            print(f"{clave}: fila de adelante rotulada")
        arriba = arriba_de(copias[0])
        horizontal = Vector((arriba.x, arriba.y, 0.0))
        grados = math.degrees(math.asin(min(1.0, horizontal.length)))
        echable = str(copias[0]["producto"]) in A_ECHAR
        if echable and grados >= INCLINACION_MINIMA and horizontal.dot(fondo_de(copias[0])) < 0:
            mueble = copias[0].parent
            if mueble.name not in arboles:
                arboles[mueble.name] = arbol_del_mueble(mueble)
            for copia in copias:
                echar_hacia_atras(copia, arboles[mueble.name])
            cambios += 1
            print(f"{clave}: echada hacia atrás, {grados:.1f} grados")
    if cambios:
        bpy.ops.wm.save_mainfile()
        print(f"guardado: {bpy.data.filepath}")


if __name__ == "__main__":
    principal()

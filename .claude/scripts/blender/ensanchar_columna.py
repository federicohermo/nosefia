"""Ensancha la columna del medio de las islas A y B. Edición de un solo paso sobre el `.blend`.

    blender <fuente>.blend --background --python .claude/scripts/blender/ensanchar_columna.py

Con una sola fila por tanda, los estantes de lado quedaban con el doble de fondo que lo que
ocupa la mercadería, y desde la cabecera la columna se veía como un hueco. La columna es la isla
de la malla que va del zócalo al techo del mueble; sus caras de los costados se corren hacia
afuera, simétricas, hasta `ANCHO`. Lo que el acomodador palpa después ya ve los estantes nuevos.
"""

import bmesh
import bpy

ANCHO = 0.40
MUEBLES = ("gondolanueva-col", "gondolanueva2-col")


def _islas(bm):
    vistas, islas = set(), []
    for cara in bm.faces:
        if cara.index in vistas:
            continue
        pila, isla = [cara], []
        while pila:
            c = pila.pop()
            if c.index in vistas:
                continue
            vistas.add(c.index)
            isla.append(c)
            pila.extend(h for e in c.edges for h in e.link_faces if h.index not in vistas)
        islas.append(isla)
    return islas


def ensanchar(objeto):
    bm = bmesh.new()
    bm.from_mesh(objeto.data)
    alto = max(v.co.z for v in bm.verts) - min(v.co.z for v in bm.verts)
    columna = None
    for isla in _islas(bm):
        zs = [v.co.z for c in isla for v in c.verts]
        if max(zs) - min(zs) > 0.9 * alto:
            columna = {v for c in isla for v in c.verts}
    if columna is None:
        raise SystemExit(f"{objeto.name}: no tiene columna")
    xs = [v.co.x for v in columna]
    medio, mitad = (min(xs) + max(xs)) / 2, ANCHO / 2
    for v in columna:
        v.co.x = medio + (mitad if v.co.x > medio else -mitad)
    bm.to_mesh(objeto.data)
    bm.free()
    objeto.data.update()
    return max(xs) - min(xs)


def principal():
    for nombre in MUEBLES:
        antes = ensanchar(bpy.data.objects[nombre])
        print(f"{nombre}: columna de {antes:.3f} a {ANCHO:.3f} m")
    if bpy.app.background:
        bpy.ops.wm.save_mainfile()


if __name__ == "__main__":
    principal()

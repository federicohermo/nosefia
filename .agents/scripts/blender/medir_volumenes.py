"""Mide las piezas sólidas de los muebles vigentes sin guardar cambios en el blend."""

import json
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.artefactos_del_bano import componentes
from lib.gondola import nombre_en_godot, punto_en_godot
from lib.volumen_rectilineo import agrupar
from lib.recorte_convexo import recortar

RAIZ = Path(__file__).resolve().parents[3]
NOMBRES = {
    'almacen-col', 'EscritorioComputadora-col', 'heladeranueva-col',
    'heladeranueva-col.001', 'heladera_fuera_de_servicio-col',
    'marco_puerta_deposito-col', 'puerta_limpieza-col',
    'gondola_deposito03-col', 'gondola_deposito03-col.001',
    'gondola_deposito_central_izquierda-col', 'local_marco_frente-col',
    'local_marco_ventanal-col',
    'deposito_contenedor_grande_cuerpo-col',
}


def convexos(puntos):
    if len(puntos) < 4 or min(max(p[i] for p in puntos) - min(p[i] for p in puntos)
                             for i in range(3)) < 0.00001:
        return []
    bm = bmesh.new()
    vertices = [bm.verts.new(punto) for punto in puntos]
    casco = bmesh.ops.convex_hull(bm, input=vertices)
    usados = {v for cara in casco['geom'] if isinstance(cara, bmesh.types.BMFace)
              for v in cara.verts}
    resultado = sorted(tuple(v.co) for v in usados)
    bm.free()
    return resultado


def recipiente(malla):
    # Las normales de las caras interiores apuntan al hueco, las exteriores se alejan.
    puntos = [tuple(v.co) for v in malla.vertices]
    centro = Vector([(min(p[i] for p in puntos) + max(p[i] for p in puntos)) / 2
                     for i in range(3)])
    planos = {}
    bvh = BVHTree.FromPolygons(puntos, [list(p.vertices) for p in malla.polygons])
    for cara in malla.polygons:
        if cara.normal.dot(centro - cara.center) <= 0.0001:
            continue
        impacto, _, _, _ = bvh.ray_cast(centro, (cara.center - centro).normalized())
        if impacto is None or (impacto - cara.center).length > 0.0001:
            continue
        n = tuple(cara.normal)
        d = cara.normal.dot(cara.center)
        planos[tuple(round(c, 6) for c in (*n, d))] = (n, d)
    restante = convexos(puntos)
    partes = []
    for normal, distancia in planos.values():
        pared = convexos(recortar(restante, normal, distancia, False))
        if pared:
            partes.append([punto_en_godot(p) for p in pared])
        restante = convexos(recortar(restante, normal, distancia))
    print('Recipiente:', len(planos), 'planos interiores,', len(partes), 'sólidos')
    return partes


def edificio(malla):
    # Los cortes son planos de la malla, no una cuadrícula aproximada como la de VHACD.
    puntos = [punto_en_godot(tuple(v.co)) for v in malla.vertices]
    planos = [sorted({round(p[i], 5) for p in puntos}) for i in range(3)]
    bvh = BVHTree.FromPolygons(puntos, [list(p.vertices) for p in malla.polygons])
    ocupadas = set()
    direccion = Vector((1, 0.00013, 0.00017)).normalized()
    for x in range(len(planos[0]) - 1):
        for y in range(len(planos[1]) - 1):
            for z in range(len(planos[2]) - 1):
                celda = (x, y, z)
                centro = Vector([(planos[i][j] + planos[i][j + 1]) / 2
                                 for i, j in enumerate(celda)])
                cruces = 0
                while True:
                    punto, _, _, _ = bvh.ray_cast(centro, direccion)
                    if punto is None:
                        break
                    cruces += 1
                    centro = punto + direccion * 0.00001
                if cruces % 2:
                    ocupadas.add(celda)
    partes = []
    for inicio, fin in agrupar(ocupadas):
        partes.append([[planos[0][x], planos[1][y], planos[2][z]]
                       for x in (inicio[0], fin[0]) for y in (inicio[1], fin[1])
                       for z in (inicio[2], fin[2])])
    print('Edificio:', len(ocupadas), 'celdas,', len(partes), 'sólidos')
    return partes


def principal():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    resultado = {}
    for objeto in bpy.context.scene.objects:
        if objeto.type != 'MESH' or objeto.name not in NOMBRES:
            continue
        nombres = []
        padre = objeto
        while padre is not None:
            nombres.append(nombre_en_godot(padre.name))
            padre = padre.parent
        ruta = '/'.join(reversed(nombres))
        partes = []
        malla = objeto.to_mesh()
        if objeto.name in ('almacen-col', 'EscritorioComputadora-col'):
            resultado[ruta] = edificio(malla)
            objeto.to_mesh_clear()
            continue
        if objeto.name == 'deposito_contenedor_grande_cuerpo-col':
            resultado[ruta] = recipiente(malla)
            objeto.to_mesh_clear()
            continue
        aristas = [tuple(arista.vertices) for arista in malla.edges]
        for indices in componentes(len(malla.vertices), aristas):
            puntos = [punto_en_godot(tuple(malla.vertices[i].co)) for i in indices]
            if len(puntos) < 4:
                continue
            lados = [max(p[i] for p in puntos) - min(p[i] for p in puntos) for i in range(3)]
            if min(lados) < 0.00001:
                continue
            bm = bmesh.new()
            vertices = [bm.verts.new(punto) for punto in puntos]
            casco = bmesh.ops.convex_hull(bm, input=vertices)
            usados = {v for cara in casco['geom'] if isinstance(cara, bmesh.types.BMFace)
                      for v in cara.verts}
            partes.append(sorted(tuple(v.co) for v in usados))
            bm.free()
        objeto.to_mesh_clear()
        resultado[ruta] = partes
    destino = RAIZ / 'build/volumenes_modelo.json'
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(resultado), encoding='utf-8')
    print('Muebles:', len(resultado), 'volúmenes:', sum(map(len, resultado.values())))


if __name__ == '__main__':
    principal()

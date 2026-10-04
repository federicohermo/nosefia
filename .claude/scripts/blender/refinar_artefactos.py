"""Porcelana con cavidades reales y perfiles cerrados, en los objetos existentes del baño."""

import math

import bmesh
import bpy
from mathutils import Vector


def material(nombre, color, rugosidad, metal=0.0):
    mat = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = rugosidad
    shader.inputs["Metallic"].default_value = metal
    return mat


def rectangulo(ancho, fondo, bisel):
    x, y = ancho / 2, fondo / 2
    return [(x-bisel, -y), (x, -y+bisel), (x, y-bisel), (x-bisel, y),
            (-x+bisel, y), (-x, y-bisel), (-x, -y+bisel), (-x+bisel, -y)]


def ovalo(ancho, fondo):
    return [(ancho / 2 * math.cos(i * math.tau / 16),
             fondo / 2 * math.sin(i * math.tau / 16)) for i in range(16)]


class Malla:
    def __init__(self):
        self.vertices = []
        self.caras = []
        self.materiales = []

    def cara(self, indices, mat):
        self.caras.append(tuple(indices))
        self.materiales.append(mat)

    def perfil(self, capas, mat=0, cerrar=False):
        inicio = len(self.vertices)
        cantidad = len(capas[0])
        assert all(len(capa) == cantidad for capa in capas)
        for capa in capas:
            self.vertices.extend(capa)
        for nivel in range(len(capas) if cerrar else len(capas)-1):
            siguiente = (nivel+1) % len(capas)
            for i in range(cantidad):
                j = (i+1) % cantidad
                self.cara((inicio+nivel*cantidad+i, inicio+nivel*cantidad+j,
                           inicio+siguiente*cantidad+j, inicio+siguiente*cantidad+i), mat)
        if not cerrar:
            self.cara(reversed(range(inicio, inicio+cantidad)), mat)
            fin = inicio + (len(capas)-1) * cantidad
            self.cara(range(fin, fin+cantidad), mat)

    def caja(self, centro, tamano, mat=0):
        x, y, z = centro
        ancho, fondo, alto = tamano
        perfil = rectangulo(ancho, fondo, min(ancho, fondo) * 0.04)
        self.perfil([[(x+u, y+v, z-alto/2) for u, v in perfil],
                     [(x+u, y+v, z+alto/2) for u, v in perfil]], mat)

    def extruir(self, contorno, y, espesor, mat):
        self.perfil([[(x, y-espesor/2, z) for x, z in contorno],
                     [(x, y+espesor/2, z) for x, z in contorno]], mat)

    def asignar(self, objeto, materiales):
        inversa = objeto.matrix_world.inverted()
        malla = bpy.data.meshes.new(objeto.name + " porcelana")
        malla.from_pydata([inversa @ Vector(v) for v in self.vertices], [], self.caras)
        for mat in materiales:
            malla.materials.append(mat)
        for cara, mat in zip(malla.polygons, self.materiales):
            cara.material_index = mat
            cara.use_smooth = True
        bm = bmesh.new()
        bm.from_mesh(malla)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        assert all(len(arista.link_faces) == 2 for arista in bm.edges), objeto.name
        assert all(cara.calc_area() > 1e-8 for cara in bm.faces), objeto.name
        bm.to_mesh(malla)
        bm.free()
        objeto.data = malla
        # El mismo objeto contiene las piezas funcionales. Los cantos de porcelana tienen
        # un bisel corto; la separación de normales conserva las caras planas y el borde.
        bpy.ops.object.select_all(action="DESELECT")
        objeto.select_set(True)
        bpy.context.view_layer.objects.active = objeto
        bisel = objeto.modifiers.new("Borde de porcelana", "BEVEL")
        bisel.width = 0.006 / objeto.matrix_world.to_scale().x
        bisel.segments = 1
        bisel.limit_method = "ANGLE"
        bisel.angle_limit = math.radians(40)
        bpy.ops.object.modifier_apply(modifier=bisel.name)
        # El bisel puede colapsar los chaflanes mínimos de la palanca del grifo.
        # Soldar sus extremos evita caras de área cero antes de calcular las UV.
        bm = bmesh.new()
        bm.from_mesh(objeto.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
        bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        assert all(len(arista.link_faces) == 2 for arista in bm.edges), objeto.name
        assert all(cara.calc_area() > 1e-8 for cara in bm.faces), objeto.name
        bm.to_mesh(objeto.data)
        bm.free()
        uv = objeto.data.uv_layers.new(name="UVMap")
        for cara in objeto.data.polygons:
            normal = (objeto.matrix_world.to_3x3().inverted().transposed() @ cara.normal).normalized()
            for indice in cara.loop_indices:
                vertice = objeto.data.loops[indice].vertex_index
                punto = objeto.matrix_world @ objeto.data.vertices[vertice].co
                if abs(normal.z) > .5:
                    uv.data[indice].uv = (punto.x, punto.y)
                elif abs(normal.x) > .5:
                    uv.data[indice].uv = (punto.y, punto.z)
                else:
                    uv.data[indice].uv = (punto.x, punto.z)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50), keep_sharp_edges=True)
        objeto.data.update()


def refinar_artefactos():
    porcelana = material("bano_porcelana", (.84, .85, .82), .28)
    asiento = material("bano_asiento_marfil", (.78, .80, .77), .34)
    acero = material("bano_griferia", (.36, .40, .40), .22, .75)
    desague = material("bano_desague", (.08, .10, .10), .5)
    materiales = [porcelana, asiento, acero, desague]

    for nombre, y in (("vanitory-convcol", 5.30), ("bano_lavatorio_2-convcol", 6.92)):
        malla = Malla()
        capas = []
        # El perfil recorre exterior, borde e interior. La cubeta y la base comparten aristas.
        for ancho, fondo, z, bisel in ((.42, .74, .865, .035), (.64, .98, 1.055, .04),
                                      (.64, .98, 1.085, .04), (.44, .76, 1.085, .045),
                                      (.32, .62, .955, .05), (.18, .40, .895, .04)):
            capas.append([(13.02+x, y+v, z) for x, v in rectangulo(ancho, fondo, bisel)])
        malla.perfil(capas)
        malla.extruir([(13.25, 1.084), (13.30, 1.084), (13.30, 1.27),
                      (13.27, 1.30), (13.15, 1.30), (13.13, 1.27),
                      (13.13, 1.188), (13.19, 1.188), (13.19, 1.24), (13.25, 1.24)], y, .055, 2)
        malla.caja((13.273, y, 1.317), (.09, .035, .018), 2)
        malla.perfil([[(13.02+x, y+v, z) for x, v in ovalo(.045, .045)]
                      for z in (.59, .864)], 2)
        malla.perfil([[(13.02+x, y+v, z) for x, v in ovalo(.055, .055)]
                      for z in (.897, .901)], 3)
        malla.asignar(bpy.data.objects[nombre], materiales)

    for nombre, x in (("inodoro-convcol", 10.945), ("bano_inodoro_2-convcol", 12.555)):
        malla = Malla()
        capas = []
        for ancho, fondo, z in ((.29, .38, .105), (.30, .39, .135),
                                (.23, .27, .42), (.36, .50, .49),
                                (.45, .64, .60), (.43, .62, .617),
                                (.29, .42, .617), (.25, .35, .48), (.15, .21, .35)):
            capas.append([(x+u, 1.79+v, z) for u, v in ovalo(ancho, fondo)])
        malla.perfil(capas)
        malla.perfil([[(x+u, 1.79+v, z) for u, v in ovalo(ancho, fondo)]
                      for ancho, fondo, z in ((.44, .62, .622), (.44, .62, .642),
                                              (.30, .43, .642), (.30, .43, .622))], 1, True)
        malla.caja((x, 1.45, .80), (.39, .18, .42))
        malla.caja((x, 1.45, 1.02), (.41, .20, .025))
        malla.caja((x+.10, 1.45, 1.038), (.065, .035, .013), 2)
        malla.extruir([(x+u, .876+v) for u, v in ovalo(.40, .47)], 1.605, .028, 1)
        malla.asignar(bpy.data.objects[nombre], materiales)

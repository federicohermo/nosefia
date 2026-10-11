"""Porcelana con cavidades reales y perfiles cerrados, en los objetos existentes del baño."""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.artefactos_del_bano import grilla_del_fondo  # noqa: E402


def material(nombre, color, rugosidad, metal=0.0, ceramica=False):
    mat = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = rugosidad
    shader.inputs["Metallic"].default_value = metal
    if ceramica:
        ruta = Path(bpy.data.filepath).parent / "../source/textures/props/porcelana_atlas.png"
        imagen = bpy.data.images.load(str(ruta.resolve()), check_existing=True)
        imagen.filepath = "//../source/textures/props/porcelana_atlas.png"
        textura = mat.node_tree.nodes.get("Porcelana del artista")
        if textura is None:
            textura = mat.node_tree.nodes.new("ShaderNodeTexImage")
            textura.name = "Porcelana del artista"
        textura.image = imagen
        mat.node_tree.links.new(textura.outputs["Color"], shader.inputs["Base Color"])
    return mat


def rectangulo(ancho, fondo, bisel):
    x, y = ancho / 2, fondo / 2
    return [(x-bisel, -y), (x, -y+bisel), (x, y-bisel), (x-bisel, y),
            (-x+bisel, y), (-x, y-bisel), (-x, -y+bisel), (-x+bisel, -y)]


def ovalo(ancho, fondo, cantidad=24):
    return [(ancho / 2 * math.cos(i * math.tau / cantidad),
             fondo / 2 * math.sin(i * math.tau / cantidad)) for i in range(cantidad)]


def redondeado(ancho, fondo, radio):
    x, y = ancho / 2, fondo / 2
    puntos = []
    for cx, cy, inicio in ((x-radio, y-radio, 0), (-x+radio, y-radio, 90),
                           (-x+radio, -y+radio, 180), (x-radio, -y+radio, 270)):
        for paso in range(4):
            angulo = math.radians(inicio + paso * 30)
            puntos.append((cx + radio * math.cos(angulo), cy + radio * math.sin(angulo)))
    return puntos


class Malla:
    def __init__(self):
        self.vertices = []
        self.caras = []
        self.materiales = []
        self.sin_bisel = set()

    def cara(self, indices, mat):
        self.caras.append(tuple(indices))
        self.materiales.append(mat)

    def perfil(self, capas, mat=0, cerrar=False, tapar_final=True):
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
            if tapar_final:
                self.cara(range(fin, fin+cantidad), mat)

    def fondo_cubeta(self, borde):
        puntos = [self.vertices[i] for i in borde]
        vertices, caras, indices_del_borde = grilla_del_fondo(puntos)
        mapa = dict(zip(indices_del_borde, borde))
        for i, punto in enumerate(vertices):
            if i not in mapa:
                mapa[i] = len(self.vertices)
                self.vertices.append(punto)
        for cara in caras:
            self.cara([mapa[i] for i in cara], 0)

    def caja(self, centro, tamano, mat=0):
        x, y, z = centro
        ancho, fondo, alto = tamano
        perfil = rectangulo(ancho, fondo, min(ancho, fondo) * 0.04)
        self.perfil([[(x+u, y+v, z-alto/2) for u, v in perfil],
                     [(x+u, y+v, z+alto/2) for u, v in perfil]], mat)

    def extruir(self, contorno, y, espesor, mat):
        self.perfil([[(x, y-espesor/2, z) for x, z in contorno],
                     [(x, y+espesor/2, z) for x, z in contorno]], mat)

    def tubo(self, puntos, radio, mat):
        inicio = len(self.vertices)
        puntos = [Vector(p) for p in puntos]
        capas = []
        for i, punto in enumerate(puntos):
            tangente = (puntos[min(i+1, len(puntos)-1)] - puntos[max(0, i-1)]).normalized()
            lateral = Vector((0, 1, 0))
            normal = tangente.cross(lateral).normalized()
            capas.append([punto + lateral*u + normal*v for u, v in ovalo(radio*2, radio*2, 12)])
        self.perfil(capas, mat)
        self.sin_bisel.update(range(inicio, len(self.vertices)))

    def asignar(self, objeto, materiales, editable=False):
        objeto.modifiers.clear()
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
        pesos = bm.edges.layers.float.new("bevel_weight_edge")
        for arista in bm.edges:
            protegida = any(v.index in self.sin_bisel for v in arista.verts)
            arista[pesos] = float(not protegida and arista.calc_face_angle() > math.radians(40))
        bm.to_mesh(malla)
        bm.free()
        objeto.data = malla
        # El mismo objeto contiene las piezas funcionales. Los cantos de porcelana tienen
        # un bisel corto; la separación de normales conserva las caras planas y el borde.
        bpy.ops.object.select_all(action="DESELECT")
        objeto.select_set(True)
        bpy.context.view_layer.objects.active = objeto
        bisel = objeto.modifiers.new("Borde de porcelana", "BEVEL")
        bisel.width = 0.002 / objeto.matrix_world.to_scale().x
        bisel.segments = 1
        bisel.limit_method = "WEIGHT"
        bisel.harden_normals = True
        if not editable:
            bpy.ops.object.modifier_apply(modifier=bisel.name)
        # El bisel puede colapsar los chaflanes mínimos de la palanca del grifo.
        # Soldar sus extremos evita caras de área cero antes de calcular las UV.
        bm = bmesh.new()
        bm.from_mesh(objeto.data)
        if not editable:
            bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
            bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        assert all(len(arista.link_faces) == 2 for arista in bm.edges), objeto.name
        assert all(cara.calc_area() > 1e-8 for cara in bm.faces), objeto.name
        # La triangulación se resuelve antes de las normales, también en quads alabeados.
        if not editable:
            bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="BEAUTY")
        assert all(cara.calc_area() > 1e-8 for cara in bm.faces), objeto.name
        bm.to_mesh(objeto.data)
        bm.free()
        uv = objeto.data.uv_layers.new(name="UVMap")
        centro = sum((objeto.matrix_world @ Vector(p) for p in objeto.bound_box), Vector()) / 8
        for cara in objeto.data.polygons:
            matriz_normal = objeto.matrix_world.to_3x3().inverted().transposed()
            normal = (matriz_normal @ cara.normal).normalized()
            for indice in cara.loop_indices:
                vertice = objeto.data.loops[indice].vertex_index
                punto = objeto.matrix_world @ objeto.data.vertices[vertice].co - centro
                if abs(normal.z) > .5:
                    coordenada = Vector((punto.x, punto.y))
                elif abs(normal.x) > .5:
                    coordenada = Vector((punto.y, punto.z))
                else:
                    coordenada = Vector((punto.x, punto.z))
                # Este sector del atlas es porcelana, sin las siluetas ni sombras de sus piezas.
                uv.data[indice].uv = Vector((.80, .80)) + coordenada * .04
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(32), keep_sharp_edges=True)
        if editable:
            triangulos = objeto.modifiers.new("Triángulos para exportación", "TRIANGULATE")
            triangulos.quad_method = "SHORTEST_DIAGONAL"
            triangulos.keep_custom_normals = True
            triangulos.show_in_editmode = False
        normales = objeto.modifiers.new("Normales de caras y biseles", "WEIGHTED_NORMAL")
        normales.mode = "FACE_AREA_WITH_ANGLE"
        normales.keep_sharp = True
        if not editable:
            bpy.ops.object.modifier_apply(modifier=normales.name)
        objeto.data.update()


def refinar_artefactos(solo=None):
    porcelana = material("bano_porcelana", (.95, .95, .93), .38, ceramica=True)
    asiento = material("bano_asiento_marfil", (.88, .89, .86), .38, ceramica=True)
    acero = material("bano_griferia", (.16, .18, .19), .34, .65)
    desague = material("bano_desague", (.08, .10, .10), .5)
    caliente = material("bano_grifo_caliente", (.38, .025, .018), .45)
    fria = material("bano_grifo_frio", (.025, .07, .26), .45)
    materiales = [porcelana, asiento, acero, desague, caliente, fria]

    for nombre, y in (("vanitory-convcol", 5.30), ("bano_lavatorio_2-convcol", 6.92)):
        if solo is not None and nombre not in solo:
            continue
        malla = Malla()
        capas = []
        original = redondeado(.55, .90, .115)
        contorno = []
        # Los puntos nuevos caen sobre las aristas existentes: conservan la silueta,
        # pero dividen los lados largos y ofrecen cuatro bordes compatibles para la grilla.
        for esquina in range(4):
            a, b, c, d = [Vector(original[esquina*4+i]) for i in range(4)]
            siguiente = Vector(original[(esquina*4+4) % 16])
            contorno.extend([a, b, (b+c)/2, c, d])
            contorno.extend(d.lerp(siguiente, paso/4) for paso in (1, 2, 3))
        # La esquina debe ser un vértice con giro, no el punto collineal añadido al arco.
        contorno = contorno[1:] + contorno[:1]
        # Secciones homotéticas: cada lateral del cuerpo es plano antes del bisel.
        # El respaldo llega a la pared; el frente redondeado conserva el borde grueso del cartel.
        for factor, z in ((.76, .925), (.96, .953), (1.0, 1.05), (1.0, 1.085),
                           (.79, 1.085), (.74, 1.04), (.56, .994)):
            capas.append([(13.159+x*factor, y+v*factor, z) for x, v in contorno])
        malla.perfil(capas, tapar_final=False)
        inicio_fondo = len(malla.vertices) - len(contorno)
        malla.fondo_cubeta(list(range(inicio_fondo, len(malla.vertices))))
        malla.extruir([(13.385, 1.085), (13.429, 1.085), (13.429, 1.222),
                      (13.412, 1.24), (13.412, 1.249), (13.425, 1.249),
                      (13.425, 1.261), (13.333, 1.261), (13.333, 1.249),
                      (13.397, 1.249), (13.397, 1.24), (13.37, 1.24), (13.16, 1.212),
                      (13.137, 1.19), (13.137, 1.165), (13.181, 1.165),
                      (13.181, 1.18), (13.385, 1.196)], y, .055, 2)
        malla.tubo([(13.159, y, .924), (13.159, y, .80), (13.159, y, .73),
                    (13.18, y, .69), (13.22, y, .677), (13.265, y, .69),
                    (13.286, y, .73), (13.31, y, .75), (13.434, y, .75)], .0225, 2)
        inicio_desague = len(malla.vertices)
        malla.perfil([[(13.159+x, y+v, z) for x, v in ovalo(.043, .043, 12)]
                      for z in (.994, .995)], 2)
        malla.perfil([[(13.159+x, y+v, z) for x, v in ovalo(.021, .021, 12)]
                      for z in (.995, .996)], 3)
        malla.sin_bisel.update(range(inicio_desague, len(malla.vertices)))
        malla.asignar(bpy.data.objects[nombre], materiales, editable=True)

    for nombre, x in (("inodoro-convcol", 10.945), ("bano_inodoro_2-convcol", 12.555)):
        if solo is not None and nombre not in solo:
            continue
        malla = Malla()
        capas = []
        for ancho, fondo, z, y in ((.34, .44, .105, 1.72), (.35, .45, .12, 1.72),
                                   (.31, .37, .30, 1.69), (.34, .43, .40, 1.72),
                                   (.44, .59, .49, 1.77), (.49, .67, .575, 1.79),
                                   (.49, .67, .604, 1.79), (.32, .46, .604, 1.79),
                                   (.25, .34, .44, 1.79), (.15, .22, .37, 1.78)):
            capas.append([(x+u, y+v, z) for u, v in ovalo(ancho, fondo)])
        malla.perfil(capas)
        malla.perfil([[(x+u, 1.79+v, z) for u, v in ovalo(ancho, fondo)]
                      for ancho, fondo, z in ((.51, .695, .610), (.51, .695, .63),
                                              (.325, .47, .63), (.325, .47, .610))], 1, True)
        malla.perfil([[(x+u, 1.455+v, z) for u, v in redondeado(ancho, fondo, radio)]
                      for ancho, fondo, radio, z in ((.37, .15, .018, .584),
                          (.42, .195, .024, .98), (.42, .195, .024, 1.015),
                          (.435, .205, .027, 1.023), (.435, .205, .027, 1.031))])
        malla.perfil([[(x+.10+u, 1.455+v, z) for u, v in ovalo(.045, .035, 12)]
                      for z in (1.033, 1.04)], 2)
        tapa = redondeado(.415, .44, .065)
        malla.perfil([[(x+u*factor, 1.622 + desplazamiento - (.865+v-.65)*.07,
                       .865+v*factor) for u, v in tapa]
                      for factor, desplazamiento in ((.98, -.016), (1.0, -.013),
                          (1.0, .008), (.91, .012))], 1)
        for lado in (-1, 1):
            malla.perfil([[(x+lado*.13+paso, 1.622+u, .64+v)
                          for u, v in ovalo(.038, .038, 12)] for paso in (-.023, .023)], 2)
        malla.perfil([[(x+u, 1.78+v, z) for u, v in ovalo(.035, .045, 12)]
                      for z in (.371, .373)], 3)
        malla.asignar(bpy.data.objects[nombre], materiales)

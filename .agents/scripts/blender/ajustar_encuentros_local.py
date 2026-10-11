"""Corregir encuentros del salón sin reemplazar el techo ni el arte del depósito.

Edición de un paso sobre los acabados v2. Conserva las placas originales y cambia
sus UV sólo en las celdas que dejarían luminarias recortadas contra el perímetro.
"""

import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar

configurar()
spec = importlib.util.spec_from_file_location(
    "local", Path(__file__).with_name("reformular_local.py"))
local = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local)


def edificio():
    objeto = bpy.data.objects["almacen-col"]
    mesh = objeto.data
    pared = bpy.data.materials["local_pared_pintada"]
    p = pared.node_tree.nodes.get("Principled BSDF")
    for enlace in list(p.inputs["Base Color"].links):
        pared.node_tree.links.remove(enlace)
    p.inputs["Base Color"].default_value = (.62, .64, .60, 1)
    deposito = next(i for i, m in enumerate(mesh.materials)
                    if m.name == "deposito_revestimiento_bloques")
    techo = next(i for i, m in enumerate(mesh.materials) if m.name == "local_cielorraso")
    vertices, caras, uvs, indices, smooth = [], [], [], [], []
    inv = objeto.matrix_world.inverted()
    for poligono in mesh.polygons:
        if poligono.material_index == techo:
            continue
        puntos = [objeto.matrix_world @ mesh.vertices[i].co for i in poligono.vertices]
        mi = poligono.material_index
        datos = [[tuple(c.data[i].uv) for i in poligono.loop_indices]
                 for c in mesh.uv_layers]
        # Sólo la cara que mira al depósito recupera su revestimiento.
        if all(abs(v.y - 8.25329) < .001 for v in puntos):
            mi = deposito
            datos = [[(v.x / 2, v.z / 2) for v in puntos] for _ in mesh.uv_layers]
        elif mesh.materials[mi].name == "local_ceramica":
            # El mapa contiene un tendido diagonal: 45 grados en UV lo enderezan.
            datos = [[((v.x + v.y) / (2 * math.sqrt(2)),
                       (v.y - v.x) / (2 * math.sqrt(2))) for v in puntos]
                     for _ in mesh.uv_layers]
        caras.append(list(range(len(vertices), len(vertices) + len(puntos))))
        vertices.extend(inv @ v for v in puntos)
        uvs.append(datos)
        indices.append(mi)
        smooth.append(poligono.use_smooth)
    # Placas planas con el atlas original. No hay perfiles ni cajas por baldosa.
    for fila in range(math.ceil((local.Y1 - local.Y0) / .6)):
        for columna in range(math.ceil((local.X1 - local.X0) / .6)):
            x, y = local.X0 + columna * .6, local.Y0 + fila * .6
            ancho, largo = min(.6, local.X1 - x), min(.6, local.Y1 - y)
            u, v = columna % 4, fila % 4
            luminoso = (u, v) in [(1, 2), (3, 0)]
            cerca = min(x - local.X0, local.X1 - x - ancho,
                        y - local.Y0, local.Y1 - y - largo) < .8
            if luminoso and (cerca or ancho < .599 or largo < .599):
                u, v = 0, 0
            puntos = [(x, y, local.TECHO), (x, y + largo, local.TECHO),
                      (x + ancho, y + largo, local.TECHO), (x + ancho, y, local.TECHO)]
            datos = [(u / 4, v / 4), (u / 4, v / 4 + largo / 2.4),
                     (u / 4 + ancho / 2.4, v / 4 + largo / 2.4),
                     (u / 4 + ancho / 2.4, v / 4)]
            caras.append(list(range(len(vertices), len(vertices) + 4)))
            vertices.extend(inv @ Vector(p) for p in puntos)
            uvs.append([datos for _ in mesh.uv_layers])
            indices.append(techo)
            smooth.append(False)
    nuevo = bpy.data.meshes.new("almacen_encuentros_corregidos")
    nuevo.from_pydata(vertices, [], caras)
    for material in mesh.materials:
        nuevo.materials.append(material)
    for k, capa in enumerate(mesh.uv_layers):
        uv = nuevo.uv_layers.new(name=capa.name)
        for poligono, datos in zip(nuevo.polygons, uvs):
            for i, coordenada in zip(poligono.loop_indices, datos[k]):
                uv.data[i].uv = coordenada
    for p, mi, s in zip(nuevo.polygons, indices, smooth):
        p.material_index, p.use_smooth = mi, s
    objeto.data = nuevo


def techo():
    mat = bpy.data.materials["local_cielorraso"]
    p = mat.node_tree.nodes.get("Principled BSDF")
    nodo = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
    nodo.image = bpy.data.images.load(str(local.TEXTURAS / "cielorraso_placas.png"),
                                    check_existing=True)
    emision = mat.node_tree.nodes.new("ShaderNodeTexImage")
    emision.image = bpy.data.images.load(str(local.TEXTURAS / "cielorraso_emision.png"),
                                       check_existing=True)
    mat.node_tree.links.new(emision.outputs["Color"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = .6
    for objeto in list(bpy.data.objects):
        if objeto.name.startswith("local_luminaria_"):
            bpy.data.objects.remove(objeto, do_unlink=True)


def puertas():
    for numero in range(3):
        hoja = bpy.data.objects[f"puerta_heladera_{numero}"]
        cristal = bpy.data.objects[f"local_vidrio_heladera_{numero}"]
        # Hueco medido en los vértices de frente del gabinete, no en su caja completa.
        ancho, z0, z1 = 1.17696, .66307, 2.50416
        viejo = hoja.matrix_world.translation.copy()
        nuevo = Vector((viejo.x, 6.62482, (z0 + z1) / 2))
        for objeto in [hoja, cristal]:
            inv = objeto.matrix_world.inverted()
            for vertice in objeto.data.vertices:
                mundo = objeto.matrix_world @ vertice.co
                mundo.x = viejo.x + (mundo.x - viejo.x) * ancho / 1.2210763
                mundo.z = nuevo.z + (mundo.z - viejo.z) * (z1 - z0) / 2.05
                mundo.y += nuevo.y - viejo.y
                vertice.co = inv @ mundo
        # Se actualiza el pivote conservando el lugar mundial del vidrio.
        hijos = [(h, h.matrix_world.copy()) for h in hoja.children]
        for vertice in hoja.data.vertices:
            vertice.co += viejo - nuevo
        hoja.matrix_world.translation = nuevo
        bpy.context.view_layer.update()
        for hijo, matriz in hijos:
            hijo.matrix_world = matriz


def exterior():
    concreto = bpy.data.materials["deposito_concreto"]
    mat = concreto.copy()
    mat.name = "local_vereda_exterior"
    p = mat.node_tree.nodes.get("Principled BSDF")
    p.inputs["Roughness"].default_value = .65
    # Vereda física junto al edificio: el fondo deja de ocupar también el primer plano.
    for nombre, a, b in [
        ("local_vereda_lateral", (-4.08, -7.88, -.04), (-2.48, 7.87, .075)),
        ("local_vereda_frente", (-2.48, -7.88, -.04), (7.87, -6.40, .075)),
    ]:
        o = local.caja(nombre, a, b, mat)
        for cara in o.data.polygons:
            for i in cara.loop_indices:
                v = o.data.vertices[o.data.loops[i].vertex_index].co
                o.data.uv_layers.active.data[i].uv = (v.x / 3, v.y / 3)


if __name__ == "__main__":
    if "--aplicar" not in sys.argv:
        raise SystemExit("Pasar --aplicar para guardar la fuente.")
    if bpy.context.scene.get("local_encuentros_v3"):
        raise SystemExit("Los encuentros v3 ya están aplicados.")
    edificio()
    techo()
    puertas()
    exterior()
    bpy.context.scene["local_encuentros_v3"] = True
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)

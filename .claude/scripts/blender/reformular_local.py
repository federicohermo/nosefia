"""Aplicar el plano de arte al salón y trasladar el baño sin editar sus muebles.

Corre sobre la fuente actual, una sola vez. Conserva los nombres de los puestos,
las mallas de productos y el depósito. Después van acomodar, exportar y disponer.
El informe compara geometría, UV y materiales de todos los objetos preexistentes.
"""

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar

configurar()

X0, X1 = -2.48, 7.87
Y0, Y1 = -6.28, 7.87
PISO, TECHO = 0.10223747, 4.26
DESPLAZAMIENTO_BANO = -7.556
TEXTURAS = RAIZ / "assets/source/textures/store"
INFORME = RAIZ / ".git/revision_almacen/reformulacion.json"


def huella_malla(objeto):
    if objeto.type != "MESH":
        return None
    datos = ([tuple(v.co) for v in objeto.data.vertices],
             [tuple(p.vertices) for p in objeto.data.polygons],
             [[tuple(v.uv) for v in c.data] for c in objeto.data.uv_layers],
             [m.name if m else None for m in objeto.data.materials],
             [p.material_index for p in objeto.data.polygons])
    return hashlib.sha256(json.dumps(datos).encode()).hexdigest()


def material(nombre, color, metal=0.0, rugosidad=0.7):
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = color
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rugosidad
    return mat


def con_textura(nombre, archivo, emision=False):
    mat = material(nombre, (1, 1, 1, 1))
    imagen = bpy.data.images.load(str(TEXTURAS / archivo), check_existing=True)
    imagen.filepath = bpy.path.relpath(str(TEXTURAS / archivo))
    nodo = mat.node_tree.nodes.new("ShaderNodeTexImage")
    nodo.image = imagen
    p = mat.node_tree.nodes.get("Principled BSDF")
    mat.node_tree.links.new(nodo.outputs["Color"], p.inputs["Base Color"])
    if emision:
        mat.node_tree.links.new(nodo.outputs["Color"], p.inputs["Emission Color"])
        p.inputs["Emission Strength"].default_value = 1
    return mat


def caras_de_caja(desde, hasta):
    x0, y0, z0 = desde
    x1, y1, z1 = hasta
    v = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
         (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    return [[v[i] for i in cara] for cara in
            [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]]


def malla_de_caras(nombre, caras, mat, padre=None, uv=None):
    vertices, indices = [], []
    for cara in caras:
        indices.append(tuple(range(len(vertices), len(vertices) + len(cara))))
        vertices.extend(cara)
    mesh = bpy.data.meshes.new(nombre)
    mesh.from_pydata(vertices, [], indices)
    mesh.materials.append(mat)
    capa = mesh.uv_layers.new(name="UVMap")
    for p in mesh.polygons:
        for i, li in enumerate(p.loop_indices):
            capa.data[li].uv = uv[i] if uv else [(0,0),(1,0),(1,1),(0,1)][i % 4]
    objeto = bpy.data.objects.new(nombre, mesh)
    bpy.context.scene.collection.objects.link(objeto)
    if padre:
        objeto.parent = padre
        objeto.matrix_parent_inverse = padre.matrix_world.inverted()
    return objeto


def caja(nombre, desde, hasta, mat, padre=None):
    return malla_de_caras(nombre, caras_de_caja(desde, hasta), mat, padre)


def mover_centro(objeto, x, y, giro=0):
    bb = [objeto.matrix_world @ Vector(v) for v in objeto.bound_box]
    centro = sum(bb, Vector()) / 8
    rotacion = Matrix.Rotation(giro, 4, "Z")
    objeto.matrix_world = (Matrix.Translation(Vector((x,y,centro.z))) @ rotacion
                          @ Matrix.Translation(-centro) @ objeto.matrix_world)


def revisar_edificio(edificio, mat_techo):
    """Cada cara que queda conserva coordenadas, UV, material y sombreado originales."""
    caras, vertices, indices, datos_uv, materiales, smooth = [], [], {}, [], [], []
    inv = edificio.matrix_world.inverted()
    eliminadas, trasladadas, intactas = 0, 0, 0
    capas = list(edificio.data.uv_layers)
    for p in edificio.data.polygons:
        mundo = [edificio.matrix_world @ edificio.data.vertices[i].co for i in p.vertices]
        minx, maxx = min(v.x for v in mundo), max(v.x for v in mundo)
        miny, maxy = min(v.y for v in mundo), max(v.y for v in mundo)
        mat = edificio.data.materials[p.material_index].name
        delta = Vector()
        if mat.startswith("bano_") or (minx >= 8.07 and miny >= 1.10 and maxy <= 8.10):
            delta.y = DESPLAZAMIENTO_BANO
            trasladadas += 1
        elif minx >= 7.84 and maxx > 8.09 and miny >= 1.10 and maxy <= 8.26:
            delta.y = DESPLAZAMIENTO_BANO
            trasladadas += 1
        elif miny >= 7.86 and maxy <= 8.26 and maxx <= 8.09:
            # Se reconstruye el tabique entero: conservar su otro lado deja el vano viejo.
            eliminadas += 1
            continue
        elif maxx <= 8.09 and maxy < 8.253 - .002:
            eliminadas += 1
            continue
        else:
            intactas += 1
        cara = []
        for i, v in zip(p.vertices, mundo):
            clave = (i, tuple(delta))
            if clave not in indices:
                indices[clave] = len(vertices)
                vertices.append(inv @ (v + delta))
            cara.append(indices[clave])
        caras.append(cara)
        datos_uv.append([[tuple(c.data[li].uv) for li in p.loop_indices] for c in capas])
        materiales.append(p.material_index)
        smooth.append(p.use_smooth)
    mats = list(edificio.data.materials)
    mats.append(mat_techo)

    def agregar(puntos, indice, escala=.5):
        caras.append(list(range(len(vertices), len(vertices) + len(puntos))))
        vertices.extend(inv @ Vector(v) for v in puntos)
        normal = (Vector(puntos[1])-Vector(puntos[0])).cross(
            Vector(puntos[2])-Vector(puntos[0]))
        eje = max(range(3), key=lambda i: abs(normal[i]))
        planos = [(1,2),(0,2),(0,1)][eje]
        datos_uv.append([[(v[planos[0]]*escala, v[planos[1]]*escala)
                          for v in puntos] for _ in capas])
        materiales.append(indice)
        smooth.append(False)

    def bloque(desde, hasta, indice):
        for cara in caras_de_caja(desde, hasta):
            agregar(cara, indice)

    pared = next(i for i,m in enumerate(mats) if m.name == "pared nueva")
    piso = next(i for i,m in enumerate(mats) if m.name == "piso")
    bloque((X0-.12,Y0-.12,-.104),(X1+.12,Y1+.02,PISO),piso)
    # El ventanal ocupa el lateral. Su zócalo y dintel cierran el volumen del salón.
    bloque((X0-.12,Y0,PISO),(X0,-1.5,4.38),pared)
    bloque((X0-.12,6.10,PISO),(X0,Y1,4.38),pared)
    bloque((X0-.12,-1.50,PISO),(X0,6.10,.48),pared)
    bloque((X0-.12,-1.50,4.16),(X0,6.10,4.38),pared)
    # Frente de caja con ventanilla. La fachada de acceso es vidriada a su derecha.
    bloque((X0,Y0-.12,PISO),(-1.50,Y0,4.38),pared)
    bloque((-.10,Y0-.12,PISO),(1.65,Y0,4.38),pared)
    bloque((-1.50,Y0-.12,PISO),(-.10,Y0,1.04),pared)
    bloque((-1.50,Y0-.12,2.44),(-.10,Y0,4.38),pared)
    bloque((1.65,Y0-.12,4.16),(X1,Y0,4.38),pared)
    # La puerta del baño viaja junto con su cuarto y conserva el ancho del vano.
    puerta_y = 6.82 + DESPLAZAMIENTO_BANO
    bloque((X1,Y0,PISO),(X1+.21,puerta_y-.84,4.38),pared)
    bloque((X1,puerta_y+.84,PISO),(X1+.21,Y1,4.38),pared)
    bloque((X1,puerta_y-.84,2.85),(X1+.21,puerta_y+.84,4.38),pared)
    # El acceso al depósito queda en la esquina derecha del fondo, como en el plano.
    bloque((-4.594,Y1,PISO),(5.882,8.25329,7.09332),pared)
    bloque((7.606,Y1,PISO),(8.08,8.25329,7.09332),pared)
    bloque((5.882,Y1,2.886),(7.606,8.25329,7.09332),pared)
    # Una cara inferior; las juntas y luminarias ya son parte de los mapas.
    agregar([(X0,Y0,TECHO),(X0,Y1,TECHO),(X1,Y1,TECHO),(X1,Y0,TECHO)],len(mats)-1)
    datos_uv[-1] = [[((v[0]-X0)/2.4,(v[1]-Y0)/2.4) for v in
                     [(X0,Y0),(X0,Y1),(X1,Y1),(X1,Y0)]] for _ in capas]
    bloque((X0,Y0,4.37),(X1,Y1,4.40),pared)
    mesh = bpy.data.meshes.new("almacen_plano_arte")
    mesh.from_pydata(vertices, [], caras)
    for m in mats:
        mesh.materials.append(m)
    for k, capa in enumerate(capas):
        nueva = mesh.uv_layers.new(name=capa.name)
        for p, uvs in zip(mesh.polygons, datos_uv):
            for li, uv in zip(p.loop_indices,uvs[k]):
                nueva.data[li].uv = uv
    for p, mi, s in zip(mesh.polygons,materiales,smooth):
        p.material_index, p.use_smooth = mi, s
    edificio.data = mesh
    return dict(caras_ajenas_conservadas=intactas, caras_trasladadas=trasladadas,
                caras_del_salon_retiradas=eliminadas, caras_finales=len(caras))


def perfiles_del_bano():
    objeto = bpy.data.objects["Cielorraso perfiles y paneles"]
    caras, vertices, materiales, uvs = [], [], [], []
    for p in objeto.data.polygons:
        puntos = [objeto.matrix_world @ objeto.data.vertices[i].co for i in p.vertices]
        if not all(v.x > 8.1 for v in puntos):
            continue
        caras.append(list(range(len(vertices),len(vertices)+len(puntos))))
        vertices.extend(v + Vector((0,DESPLAZAMIENTO_BANO,0)) for v in puntos)
        materiales.append(p.material_index)
        capa = objeto.data.uv_layers.active
        uvs.append([tuple(capa.data[i].uv) for i in p.loop_indices] if capa else
                   [(0,0),(1,0),(1,1),(0,1)])
    mesh = bpy.data.meshes.new("perfileria_ajena_al_salon")
    mesh.from_pydata(vertices, [], caras)
    for m in objeto.data.materials:
        mesh.materials.append(m)
    uv = mesh.uv_layers.new(name="UVMap")
    for p, indice, coords in zip(mesh.polygons,materiales,uvs):
        p.material_index = indice
        for li, coord in zip(p.loop_indices,coords):
            uv.data[li].uv = coord
    objeto.data = mesh


def vidrio_y_marcos(mat_vidrio, mat_marco):
    for i in range(4):
        a = -1.5 + i*1.9
        b = a + 1.9
        malla_de_caras(f"local_vidrio_ventanal_{i}",
                      [[(X0-.045,a,.50),(X0-.045,b,.50),
                        (X0-.045,b,4.14),(X0-.045,a,4.14)]],mat_vidrio)
    for i in range(5):
        y = -1.5 + i*1.9
        caja(f"local_marco_ventanal_{i}-col",(X0-.09,y-.025,.48),
             (X0+.02,y+.025,4.16),mat_marco)
    for z in [.48,3.05,4.16]:
        caja(f"local_travesano_ventanal_{z}-col",(X0-.09,-1.5,z-.025),
             (X0+.02,6.1,z+.025),mat_marco)
    for i,(a,b) in enumerate([(1.65,4.85),(6.57,X1)]):
        malla_de_caras(f"local_vidrio_frente_{i}",
                      [[(a,Y0-.045,PISO),(b,Y0-.045,PISO),
                        (b,Y0-.045,4.14),(a,Y0-.045,4.14)]],mat_vidrio)
    for x in [1.65,3.25,4.85,5.71,6.57,X1]:
        caja(f"local_marco_frente_{x}-col",(x-.025,Y0-.09,PISO),
             (x+.025,Y0+.02,4.16),mat_marco)
    for z in [PISO,2.886,4.16]:
        caja(f"local_travesano_frente_{z}-col",(1.65,Y0-.09,z-.025),
             (X1,Y0+.02,z+.025),mat_marco)
    malla_de_caras("local_vidrio_sobre_entrada",
                  [[(4.85,Y0-.045,2.886),(6.57,Y0-.045,2.886),
                    (6.57,Y0-.045,4.14),(4.85,Y0-.045,4.14)]],mat_vidrio)
    malla_de_caras("local_vidrio_ventanilla",
                  [[(-1.50,Y0-.04,1.10),(-.10,Y0-.04,1.10),
                    (-.10,Y0-.04,2.44),(-1.50,Y0-.04,2.44)]],mat_vidrio)


def puertas_de_heladera(mat_vidrio, mat_marco):
    for i,nombre in enumerate(["heladeranueva-col","heladeranueva-col.001",
                              "heladera_fuera_de_servicio-col"]):
        objeto = bpy.data.objects[nombre]
        bb = [objeto.matrix_world @ Vector(v) for v in objeto.bound_box]
        x0,x1 = min(v.x for v in bb)+.06,max(v.x for v in bb)-.06
        y = min(v.y for v in bb)-.025
        z0,z1 = .31,2.36
        malla_de_caras(f"local_vidrio_heladera_{i}",
                      [[(x0+.04,y,z0+.04),(x1-.04,y,z0+.04),
                        (x1-.04,y,z1-.04),(x0+.04,y,z1-.04)]],mat_vidrio,objeto)
        for j,(a,b) in enumerate([
            ((x0,y-.025,z0),(x0+.045,y+.025,z1)),
            ((x1-.045,y-.025,z0),(x1,y+.025,z1)),
            ((x0,y-.025,z0),(x1,y+.025,z0+.045)),
            ((x0,y-.025,z1-.045),(x1,y+.025,z1)),
            ((x1-.15,y-.11,1.08),(x1-.115,y-.08,1.54)),
        ]):
            caja(f"local_marco_heladera_{i}_{j}-col",a,b,mat_marco,objeto)


def eliminar_reflejo_de_transformacion(objeto):
    """Hornea el reflejo en la malla: el lightmap de Godot requiere una base positiva."""
    if objeto.matrix_world.determinant() >= 0:
        return
    hijos = [(hijo, hijo.matrix_world.copy()) for hijo in objeto.children]
    reflejo = Matrix.Diagonal(Vector((-1, 1, 1, 1)))
    objeto.data = objeto.data.copy()
    objeto.data.transform(reflejo)
    objeto.data.flip_normals()
    objeto.matrix_world = objeto.matrix_world @ reflejo
    bpy.context.view_layer.update()
    for hijo, matriz in hijos:
        hijo.matrix_world = matriz


def aplicar():
    if bpy.context.scene.get("local_plano_arte_v1"):
        raise SystemExit("El plano ya está aplicado. No volver a mover sus objetos.")
    antes = {o.name: dict(malla=huella_malla(o), matriz=[tuple(f) for f in o.matrix_world])
             for o in bpy.data.objects}
    mat_marco = material("local_aluminio",(.33,.36,.34,1),.55,.43)
    mat_vidrio = material("local_vidrio",(.58,.72,.71,.09),.05,.18)
    mat_vidrio.node_tree.nodes.get("Principled BSDF").inputs["Alpha"].default_value = .09
    mat_vidrio.surface_render_method = "BLENDED"
    mat_vidrio.use_backface_culling = False
    mat_techo = con_textura("local_cielorraso", "cielorraso_placas.png")
    # El mapa de emisión deriva de las dos celdas luminosas, sin iluminar las placas opacas.
    imagen = bpy.data.images.load(str(TEXTURAS / "cielorraso_placas.png"))
    imagen.scale(512,512)
    pixeles = list(imagen.pixels)
    for y in range(512):
        for x in range(512):
            panel = (132<x<250 and 260<y<378) or (388<x<506 and 4<y<122)
            i = (y*512+x)*4
            for c in range(3):
                pixeles[i+c] = pixeles[i+c] if panel else 0
    imagen.pixels = pixeles
    imagen.name = "cielorraso_emision"
    imagen.filepath_raw = str(TEXTURAS / "cielorraso_emision.png")
    imagen.file_format = "PNG"
    imagen.save()
    imagen.filepath = bpy.path.relpath(imagen.filepath_raw)
    nodo = mat_techo.node_tree.nodes.new("ShaderNodeTexImage")
    nodo.image = imagen
    p = mat_techo.node_tree.nodes.get("Principled BSDF")
    mat_techo.node_tree.links.new(nodo.outputs["Color"],p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = .6
    edificio = revisar_edificio(bpy.data.objects["almacen-col"], mat_techo)
    perfiles_del_bano()
    for nombre,x in [("gondolanueva-col",.67),("gondolanueva2-col",4.72)]:
        mover_centro(bpy.data.objects[nombre],x,2.00)
    for nombre,x in [("gondolanueva-col.001",2.95),("gondolanueva-col.002",4.82)]:
        o = bpy.data.objects[nombre]
        bb = [o.matrix_world @ Vector(v) for v in o.bound_box]
        centro_y = (min(v.y for v in bb)+max(v.y for v in bb))/2
        inv = o.matrix_world.inverted()
        for v in o.data.vertices:
            mundo = o.matrix_world @ v.co
            mundo.y = centro_y + (mundo.y-centro_y)*.482
            v.co = inv @ mundo
        mover_centro(o,x,7.25,-math.pi/2)
    for nombre,x in [("heladeranueva-col",-1.43),("heladeranueva-col.001",-.05)]:
        mover_centro(bpy.data.objects[nombre],x,7.18,-math.pi/2)
    fuente = bpy.data.objects["heladeranueva-col.001"]
    vacia = fuente.copy()
    vacia.data = fuente.data.copy()
    vacia.name = "heladera_fuera_de_servicio-col"
    bpy.context.scene.collection.objects.link(vacia)
    mover_centro(vacia,1.33,7.18)
    # Las instancias de productos de las dos heladeras activas conservan su catálogo.
    for o in list(bpy.data.objects):
        if o.parent is None and (o.name.startswith("bano_") or o.name in [
            "inodoro-convcol","vanitory-convcol","balde-col","mopa-col",
            "bidón jabon01-col","bidón jabon01-col.001","bidón jabon01-col.002",
            "nota baño inodoro-col","nota instrucciones-col","nota productos-col",
            "tachitobasura-col.002","puerta2-col"]):
            o.location.y += DESPLAZAMIENTO_BANO
    escritorio = ["EscritorioComputadora-col","base compu-col","teclado-col",
                  "mouse-col","cajaregistradora-col","reloj-col","tachitobasura-col.001"]
    reflejo = Matrix.Diagonal(Vector((-1,1,1,1)))
    transformacion = Matrix.Translation(Vector((4.43,1.532,0))) @ reflejo
    for nombre in escritorio:
        o = bpy.data.objects[nombre]
        o.matrix_world = transformacion @ o.matrix_world
        eliminar_reflejo_de_transformacion(o)
    board = bpy.data.objects["board tareas-col"]
    mover_centro(board,X0+.04,-4.05,math.pi)
    mover_centro(bpy.data.objects["tachitobasura-col"],7.28,-5.25)
    bpy.data.objects["puerta-col"].location.x += 1.25
    entrada = bpy.data.objects["puertaentrada-col"]
    entrada.location.x += 5.71 - entrada.location.x
    entrada.location.y += Y0 - entrada.location.y
    bpy.context.view_layer.update()
    partes = []
    for a,b in [((4.85,Y0-.04,PISO),(4.90,Y0+.04,2.886)),
                ((6.52,Y0-.04,PISO),(6.57,Y0+.04,2.886)),
                ((4.85,Y0-.04,PISO),(6.57,Y0+.04,.18)),
                ((4.85,Y0-.04,2.82),(6.57,Y0+.04,2.886)),
                ((6.36,Y0-.14,1.12),(6.40,Y0-.11,1.63))]:
        partes.extend(caras_de_caja(a,b))
    marco = malla_de_caras("marco_temporal",partes,mat_marco)
    inv = entrada.matrix_world.inverted()
    for v in marco.data.vertices:
        v.co = inv @ v.co
    entrada.data = marco.data
    bpy.data.objects.remove(marco,do_unlink=True)
    malla_de_caras("local_vidrio_puerta_entrada",
                  [[(4.90,Y0-.02,.18),(6.52,Y0-.02,.18),
                    (6.52,Y0-.02,2.82),(4.90,Y0-.02,2.82)]],mat_vidrio,entrada)
    puertas_de_heladera(mat_vidrio,mat_marco)
    vidrio_y_marcos(mat_vidrio,mat_marco)
    mat_exterior = con_textura("local_exterior_nocturno", "exterior_nocturno.png",True)
    malla_de_caras("local_exterior_frente",[[(X0-10,Y0-12,-5),(X1+10,Y0-12,-5),
                    (X1+10,Y0-12,10),(X0-10,Y0-12,10)]],mat_exterior)
    malla_de_caras("local_exterior_lateral",[[(X0-12,Y0-8,-5),(X0-12,Y1+8,-5),
                    (X0-12,Y1+8,10),(X0-12,Y0-8,10)]],mat_exterior)
    alfombra = material("local_alfombra_entrada",(.085,.10,.095,1),0,.95)
    caja("local_alfombra_entrada-col",(3.0,Y0+.12,PISO+.003),
         (7.05,Y0+1.92,PISO+.005),alfombra)
    aviso = material("local_aviso_fuera_de_servicio",(.74,.61,.30,1))
    caja("local_aviso_fuera_de_servicio",(1.04,6.58,1.35),(1.62,6.60,1.64),aviso,vacia)
    bpy.context.view_layer.update()
    bpy.context.scene["local_plano_arte_v1"] = True
    bpy.context.scene["local_ancho_de_isla"] = 1.8
    cambios = {}
    for nombre, datos in antes.items():
        o = bpy.data.objects.get(nombre)
        if o is not None:
            malla = huella_malla(o)
            matriz = [tuple(f) for f in o.matrix_world]
            if malla != datos["malla"] or matriz != datos["matriz"]:
                cambios[nombre] = dict(malla_conservada=malla == datos["malla"],
                                       matriz_conservada=matriz == datos["matriz"])
    informe = dict(salon=dict(x0=X0,x1=X1,y0=Y0,y1=Y1),edificio=edificio,
                   desplazamiento_bano=DESPLAZAMIENTO_BANO,cambios=cambios,
                   objetos_nuevos=sorted(set(bpy.data.objects.keys())-set(antes)))
    INFORME.parent.mkdir(parents=True,exist_ok=True)
    INFORME.write_text(json.dumps(informe,indent=2,ensure_ascii=False),encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    print("PLANO APLICADO",INFORME)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--aplicar",action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    if not args.aplicar:
        raise SystemExit("Pasar --aplicar para escribir la fuente actual, después de respaldarla.")
    aplicar()

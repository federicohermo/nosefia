"""Cerrar el acceso al depósito y terminar superficies y puertas del salón reformulado.

Edición de un paso, después de reformular_local.py. --aplicar guarda la fuente.
Las caras del baño y del fondo del depósito conservan sus materiales y UV.
"""

import argparse
import importlib.util
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar

configurar()
spec = importlib.util.spec_from_file_location(
    "local", Path(__file__).with_name("reformular_local.py"))
local = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local)


def textura(nombre, archivo):
    return local.con_textura(nombre, archivo)


def edificio(pared, piso):
    objeto = bpy.data.objects["almacen-col"]
    anterior = objeto.data
    vertices, caras, uvs, materiales, smooth = [], [], [], [], []
    capas = list(anterior.uv_layers)
    mats = list(anterior.materials) + [pared, piso]
    inv = objeto.matrix_world.inverted()
    indice_pared, indice_piso = len(mats)-2, len(mats)-1
    for p in anterior.polygons:
        puntos = [objeto.matrix_world @ anterior.vertices[i].co for i in p.vertices]
        miny, maxy = min(v.y for v in puntos), max(v.y for v in puntos)
        maxx = max(v.x for v in puntos)
        if miny >= 7.86 and maxy <= 8.26 and maxx <= 8.09:
            continue
        mi = p.material_index
        mat = mats[mi].name
        nueva = mat == "pared nueva" and miny >= -6.41 and maxy <= 7.88
        if nueva:
            mi = indice_pared
        elif mat == "piso" and maxy <= 7.90 and min(v.x for v in puntos) >= -2.61:
            mi = indice_piso
            nueva = True
        caras.append(list(range(len(vertices),len(vertices)+len(puntos))))
        vertices.extend(inv @ v for v in puntos)
        materiales.append(mi)
        smooth.append(p.use_smooth)
        if nueva:
            normal = (puntos[1]-puntos[0]).cross(puntos[2]-puntos[0])
            eje = max(range(3),key=lambda i: abs(normal[i]))
            plano = [(1,2),(0,2),(0,1)][eje]
            uvs.append([[(v[plano[0]]/2,v[plano[1]]/2) for v in puntos] for _ in capas])
        else:
            uvs.append([[tuple(c.data[i].uv) for i in p.loop_indices] for c in capas])
    for a,b in [((-4.594,7.87,.10223747),(5.882,8.25329,7.09332)),
                ((7.606,7.87,.10223747),(8.08,8.25329,7.09332)),
                ((5.882,7.87,2.886),(7.606,8.25329,7.09332))]:
        for puntos in local.caras_de_caja(a,b):
            caras.append(list(range(len(vertices),len(vertices)+len(puntos))))
            vertices.extend(inv @ Vector(v) for v in puntos)
            materiales.append(indice_pared)
            smooth.append(False)
            normal = (Vector(puntos[1])-Vector(puntos[0])).cross(
                Vector(puntos[2])-Vector(puntos[0]))
            eje = max(range(3),key=lambda i: abs(normal[i]))
            plano = [(1,2),(0,2),(0,1)][eje]
            uvs.append([[(v[plano[0]]/2,v[plano[1]]/2) for v in puntos] for _ in capas])
    mesh = bpy.data.meshes.new("almacen_acabados_finales")
    mesh.from_pydata(vertices,[],caras)
    for mat in mats:
        mesh.materials.append(mat)
    for k,capa in enumerate(capas):
        uv = mesh.uv_layers.new(name=capa.name)
        for p,datos in zip(mesh.polygons,uvs):
            for i,coord in zip(p.loop_indices,datos[k]):
                uv.data[i].uv = coord
    for p,mi,s in zip(mesh.polygons,materiales,smooth):
        p.material_index,p.use_smooth = mi,s
    objeto.data = mesh


def techo():
    mat = bpy.data.materials["local_cielorraso"]
    mat.node_tree.nodes.clear()
    p = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    salida = mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(p.outputs["BSDF"],salida.inputs["Surface"])
    nodo = mat.node_tree.nodes.new("ShaderNodeTexImage")
    imagen = bpy.data.images.load(str(local.TEXTURAS / "cielorraso_sin_luces.png"),
                                  check_existing=True)
    imagen.filepath = bpy.path.relpath(str(local.TEXTURAS / "cielorraso_sin_luces.png"))
    nodo.image = imagen
    mat.node_tree.links.new(nodo.outputs["Color"],p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = .85
    luminaria = local.material("local_luminaria",(.68,.83,.77,1),0,.6)
    lp = luminaria.node_tree.nodes.get("Principled BSDF")
    lp.inputs["Emission Color"].default_value = (.68,.83,.77,1)
    lp.inputs["Emission Strength"].default_value = .7
    centros = [(x,y) for x in [.2,4.9] for y in [-3,1,4.8]] + [(2.7,-5.1)]
    for i,(x,y) in enumerate(centros):
        z = local.TECHO-.002
        local.malla_de_caras(f"local_luminaria_{i}",
                            [[(x-.6,y-.3,z),(x-.6,y+.3,z),
                              (x+.6,y+.3,z),(x+.6,y-.3,z)]],luminaria)


def puertas():
    negro = local.material("local_marco_heladera",(.012,.015,.016,1),.6,.35)
    vidrio = bpy.data.materials["local_vidrio"]
    for i,nombre in enumerate(["heladeranueva-col","heladeranueva-col.001",
                              "heladera_fuera_de_servicio-col"]):
        gabinete = bpy.data.objects[nombre]
        puntos = [gabinete.matrix_world @ Vector(v) for v in gabinete.bound_box]
        x0,x1 = min(v.x for v in puntos)+.06,max(v.x for v in puntos)-.06
        y = min(v.y for v in puntos)-.025
        z0,z1 = .31,2.36
        for objeto in list(bpy.data.objects):
            if objeto.name.startswith(f"local_marco_heladera_{i}_"):
                bpy.data.objects.remove(objeto,do_unlink=True)
        anterior = bpy.data.objects.get(f"local_vidrio_heladera_{i}")
        if anterior:
            bpy.data.objects.remove(anterior,do_unlink=True)
        caras = []
        for a,b in [((x0,y-.018,z0),(x0+.035,y+.018,z1)),
                    ((x1-.035,y-.018,z0),(x1,y+.018,z1)),
                    ((x0,y-.018,z0),(x1,y+.018,z0+.035)),
                    ((x0,y-.018,z1-.035),(x1,y+.018,z1)),
                    ((x0+.11,y-.10,1.08),(x0+.145,y-.07,1.54))]:
            caras.extend(local.caras_de_caja(a,b))
        hoja = local.malla_de_caras(f"puerta_heladera_{i}",caras,negro)
        centro = Vector(((x0+x1)/2,y,(z0+z1)/2))
        for v in hoja.data.vertices:
            v.co -= centro
        hoja.matrix_world = Matrix.Translation(centro)
        hoja.parent = gabinete
        hoja.matrix_parent_inverse = gabinete.matrix_world.inverted()
        bpy.context.view_layer.update()
        local.malla_de_caras(f"local_vidrio_heladera_{i}",
                            [[(x0+.035,y,z0+.035),(x1-.035,y,z0+.035),
                              (x1-.035,y,z1-.035),(x0+.035,y,z1-.035)]],vidrio,hoja)


def aplicar():
    if bpy.context.scene.get("local_acabados_v2"):
        raise SystemExit("Los acabados v2 ya están aplicados.")
    pared = textura("local_pared_pintada","painted_plaster_wall_diff_1k.jpg")
    piso = textura("local_ceramica","interior_tiles_diff_1k.jpg")
    edificio(pared,piso)
    techo()
    puertas()
    for nombre in ["local_exterior_frente","local_exterior_lateral"]:
        objeto = bpy.data.objects.get(nombre)
        if objeto:
            bpy.data.objects.remove(objeto,do_unlink=True)
    bpy.context.scene["local_acabados_v2"] = True
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--aplicar",action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    if not args.aplicar:
        raise SystemExit("Pasar --aplicar para guardar la fuente.")
    aplicar()

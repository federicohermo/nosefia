"""Incorpora el sector cerrado al baño. Ejecutar con Blender y --aplicar para guardar."""

import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar

configurar()
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)

anterior = bpy.data.collections.get("Bano publico")
if anterior:
    for objeto in list(anterior.objects):
        bpy.data.objects.remove(objeto, do_unlink=True)
    bpy.data.collections.remove(anterior)
coleccion = bpy.data.collections.new("Bano publico")
bpy.context.scene.collection.children.link(coleccion)


def material(nombre, color, rugosidad=0.6, metal=0.0):
    mat = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = rugosidad
    shader.inputs["Metallic"].default_value = metal
    return mat


def ceramica(nombre, color, junta):
    mat = material(nombre, color, 0.43)
    imagen = bpy.data.images.get(nombre) or bpy.data.images.new(nombre, width=256, height=256)
    rng = random.Random(73)
    pixeles = []
    for y in range(256):
        for x in range(256):
            borde = min(x, y, 255-x, 255-y)
            ruido = rng.uniform(-0.008, 0.008)
            tono = junta if borde < 2 else color
            factor = 0.94 if borde == 2 else 1.0
            pixeles.extend([max(0, min(1, c * factor + ruido)) for c in tono] + [1])
    imagen.pixels.foreach_set(pixeles)
    imagen.filepath_raw = str(RAIZ / "assets/source/textures/props" / (nombre + ".png"))
    imagen.file_format = "PNG"
    imagen.save()
    imagen.pack()
    nodo = mat.node_tree.nodes.get("Ceramica") or mat.node_tree.nodes.new("ShaderNodeTexImage")
    nodo.name = "Ceramica"
    nodo.image = imagen
    mat.node_tree.links.new(
        nodo.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"]
    )
    return mat


piso = ceramica("bano_piso_gris", (.45, .49, .48), (.23, .26, .25))
pared = bpy.data.materials.get("bano_pared_clara") or bpy.data.materials.get("bano_azulejo_claro")
if pared:
    pared.name = "bano_pared_clara"
pared = material("bano_pared_clara", (.78, .81, .79), .87)
for enlace in list(pared.node_tree.nodes["Principled BSDF"].inputs["Base Color"].links):
    pared.node_tree.links.remove(enlace)
techo = material("bano_cielorraso_blanco", (.84, .86, .84), .88)
panel = material("bano_panel_verde_gris", (.32, .43, .39), .56)
marco = material("bano_marco_pintado", (.16, .22, .20), .65)
metal = material("bano_acero", (.52, .57, .57), .3, .75)
luz = material("bano_difusor", (.94, .97, .95), .4)
shader = luz.node_tree.nodes["Principled BSDF"]
shader.inputs["Emission Color"].default_value = (.94, .97, .95, 1)
shader.inputs["Emission Strength"].default_value = 1.4

edificio = bpy.data.objects["almacen-col"]
malla = edificio.data
# Se elimina el tabique que cerraba el cuarto delantero. Las cabinas nuevas
# quedan contra la pared exterior y el espacio de circulación es continuo.
bm = bmesh.new()
bm.from_mesh(malla)
tabique = []
for cara in bm.faces:
    puntos = [edificio.matrix_world @ v.co for v in cara.verts]
    if min(v.x for v in puntos) > 8.28 and all(abs(v.y - 3.593783) < .002 for v in puntos):
        tabique.append(cara)
bmesh.ops.delete(bm, geom=tabique, context="FACES")
bm.to_mesh(malla)
bm.free()
malla.update()
# Se desplaza el hueco existente con sus jambas, conservando el muro del artista.
if not edificio.get("bano_acceso_reubicado", False):
    antes = [edificio.matrix_world @ v.co for v in malla.vertices]
    cambios = {}
    for vertice, punto in zip(malla.vertices, antes):
        if 7.86 < punto.x < 8.31 and any(
            abs(punto.y - valor) < .003 for valor in (3.7416, 3.8209, 5.5037, 5.6032)
        ):
            nuevo = punto.copy()
            nuevo.y += 6.82 - (3.820949 + 5.503817) / 2
            cambios[vertice.index] = nuevo
    uv_original = malla.uv_layers.active
    for cara in malla.polygons:
        if not any(i in cambios for i in cara.vertices):
            continue
        puntos = [antes[i] for i in cara.vertices]
        ejes = sorted(range(3), key=lambda eje: max(v[eje] for v in puntos)
                      - min(v[eje] for v in puntos), reverse=True)[:2]
        matriz = None
        indices = None
        for i in range(1, len(puntos)-1):
            candidatos = (0, i, i+1)
            prueba = Matrix([(puntos[j][ejes[0]], puntos[j][ejes[1]], 1)
                             for j in candidatos])
            if abs(prueba.determinant()) > 1e-8:
                matriz, indices = prueba.inverted(), candidatos
                break
        if matriz is None:
            continue
        bucles = list(cara.loop_indices)
        u = matriz @ Vector([uv_original.data[bucles[i]].uv.x for i in indices])
        v = matriz @ Vector([uv_original.data[bucles[i]].uv.y for i in indices])
        for indice in bucles:
            vertice = malla.loops[indice].vertex_index
            if vertice in cambios:
                punto = cambios[vertice]
                coords = Vector((punto[ejes[0]], punto[ejes[1]], 1))
                uv_original.data[indice].uv = (u.dot(coords), v.dot(coords))
    inversa = edificio.matrix_world.inverted()
    for indice, punto in cambios.items():
        malla.vertices[indice].co = inversa @ punto
    edificio["bano_acceso_reubicado"] = True
    malla.update()
# El antiguo cuarto cerrado compartía dos caras coplanares, de orientación
# opuesta, con el muro oeste. Al abrirlo quedan ambas visibles y compiten
# por profundidad y por el mapa de iluminación. Se conserva la piel interior.
bm = bmesh.new()
bm.from_mesh(malla)
duplicadas = []
for cara in bm.faces:
    puntos = [edificio.matrix_world @ v.co for v in cara.verts]
    if (cara.normal.x < -.9
            and all(abs(v.x - 8.077575) < .003 for v in puntos)
            and all(1.11 < v.y < 5.99 and .1 < v.z < 2.86 for v in puntos)):
        duplicadas.append(cara)
assert len(duplicadas) in (0, 2), "Cantidad inesperada de caras duplicadas"
print("Caras internas superpuestas eliminadas:", len(duplicadas))
bmesh.ops.delete(bm, geom=duplicadas, context="FACES")
bm.to_mesh(malla)
bm.free()
malla.update()
slots = {}
for mat in (piso, pared, techo):
    if mat.name not in [m.name for m in malla.materials]:
        malla.materials.append(mat)
    slots[mat.name] = list(malla.materials).index(mat)
uv = malla.uv_layers.active
for cara in malla.polygons:
    centro = edificio.matrix_world @ cara.center
    puntos = [edificio.matrix_world @ malla.vertices[i].co for i in cara.vertices]
    en_acceso = all(7.86 < v.x < 8.31 for v in puntos)
    jamba = en_acceso and any(
        all(abs(v.y - limite) < .003 for v in puntos) for limite in (5.977485, 7.662353)
    )
    dintel = en_acceso and all(abs(v.z - 2.851981) < .003 for v in puntos)
    umbral = (
        en_acceso and all(abs(v.z - .102237) < .003 for v in puntos)
        and 5.974 < centro.y < 7.665
    )
    interior_oeste = en_acceso and centro.x > 8.0 and abs(cara.normal.x) > .9
    if jamba or dintel:
        cara.material_index = slots[pared.name]
        continue
    if not (interior_oeste or umbral or centro.x > 8.28) or not 1.11 < centro.y < 7.89:
        continue
    es_piso = cara.normal.z > .9 and abs(centro.z - .102237) < .002
    es_pared = abs(cara.normal.z) < .01 and .1 < centro.z < 4.9
    if not (es_piso or es_pared):
        continue
    cara.material_index = slots[(piso if es_piso else pared).name]
    for indice in cara.loop_indices:
        v = edificio.matrix_world @ malla.vertices[malla.loops[indice].vertex_index].co
        if es_piso:
            uv.data[indice].uv = (v.x / .6, v.y / .6)
        else:
            uv.data[indice].uv = ((v.y if abs(cara.normal.x) > .5 else v.x) / .5, v.z / .25)


def vincular(objeto):
    for grupo in list(objeto.users_collection):
        grupo.objects.unlink(objeto)
    coleccion.objects.link(objeto)


def caja(nombre, centro, tamano, mat, colision=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centro)
    objeto = bpy.context.object
    objeto.name = nombre + ("-convcol" if colision else "")
    objeto.dimensions = tamano
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    objeto.data.materials.append(mat)
    if mat in (piso, pared):
        uv_caja = objeto.data.uv_layers.active
        for cara in objeto.data.polygons:
            for indice in cara.loop_indices:
                vertice = objeto.data.loops[indice].vertex_index
                v = objeto.matrix_world @ objeto.data.vertices[vertice].co
                if abs(cara.normal.z) > .5:
                    uv_caja.data[indice].uv = (v.x / .6, v.y / .6)
                else:
                    horizontal = v.y if abs(cara.normal.x) > .5 else v.x
                    uv_caja.data[indice].uv = (horizontal / .5, v.z / .25)
    vincular(objeto)
    return objeto


def cilindro(nombre, centro, radio, profundidad, mat):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16, radius=radio, depth=profundidad, location=centro
    )
    objeto = bpy.context.object
    objeto.name = nombre
    objeto.data.materials.append(mat)
    vincular(objeto)
    return objeto


# El perímetro exterior se conserva. El piso suma 12 m² antes inaccesibles.
caja("bano_cielorraso", (10.86, 4.58, 3.18), (5.13, 6.61, .08), techo, True)
caja("bano_piso_ampliado", (10.86326, 2.43573, .052237), (5.1428, 2.31611, .1), piso)
caja("bano_pared_delantera", (10.86326, 1.28768, 1.62), (5.1428, .02, 3.03553), pared, True)
# Una única terminación interior cubre el cambio de espesor del cuarto antiguo.
# Termina en la jamba del hueco; no corta ni sustituye el muro estructural.
caja("bano_revestimiento_oeste", (8.29, 3.62748, 1.62112),
     (.04, 4.70001, 3.03776), pared)
for x in (13.424,):
    caja("bano_revestimiento_ampliado", (x, 2.43573, 1.62), (.02, 2.31611, 3.03553), pared)

# El acceso queda frente a los lavatorios. La cara del local conserva su material.
for x in (9.1, 11.0, 12.8):
    for y in (4.7, 6.9):
        cilindro("bano_aro_luminaria", (x, y, 3.126), .14, .027, metal)
        cilindro("bano_luminaria", (x, y, 3.107), .113, .012, luz)
for x in (9.1, 10.945, 12.555):
    cilindro("bano_aro_luminaria", (x, 2.35, 3.126), .14, .027, metal)
    cilindro("bano_luminaria", (x, 2.35, 3.107), .113, .012, luz)

# Las cabinas ocupan el extremo delantero, dejando un salón continuo desde la entrada.
for x in (10.2, 11.81):
    caja("bano_mampara_lateral", (x, 2.32, 1.30), (.055, 2.04, 2.0), panel, True)
for x, ancho in ((10.32, .24), (11.685, .25), (11.935, .25), (13.255, .35)):
    caja("bano_mampara_frontal", (x, 3.35, 1.30), (ancho, .055, 2.0), panel, True)
for numero, x in enumerate((10.945, 12.555), 1):
    # El sufijo no genera un cuerpo estático: Godot conecta el cuerpo animable de la hoja.
    hoja = caja("bano_puerta_" + str(numero), (x, 3.35, 1.25), (1.0, .048, 1.9), panel)
    hoja.rotation_euler.z = math.pi
    partes = [hoja]
    for z in (.59, 1.95):
        partes.append(caja("bisagra", (x+.48, 3.315, z), (.06, .065, .11), metal))
    partes.append(caja("pestillo", (x-.34, 3.31, 1.20), (.11, .035, .045), metal))
    bpy.ops.object.select_all(action="DESELECT")
    for objeto in partes:
        objeto.select_set(True)
    bpy.context.view_layer.objects.active = hoja
    bpy.ops.object.join()
for x in (10.2, 11.81, 13.40):
    caja("bano_pata_mampara", (x, 3.35, .22), (.035, .035, .24), metal)
    caja("bano_riel_superior", (x, 2.32, 2.34), (.06, 2.10, .06), metal)
caja("bano_riel_frontal", (11.81, 3.35, 2.34), (3.25, .06, .06), metal)


def original(objeto):
    clave = "bano_transform_original"
    if clave not in objeto:
        objeto[clave] = [valor for fila in objeto.matrix_world for valor in fila]
    valores = objeto[clave]
    objeto.matrix_world = Matrix([valores[i:i+4] for i in range(0, 16, 4)])
    return objeto.matrix_world.copy()


def duplicar(objeto, nombre):
    copia = objeto.copy()
    copia.data = objeto.data.copy()
    copia.name = nombre
    coleccion.objects.link(copia)
    return copia


# Una hoja opaca con panel, manija y rejilla, con pocos polígonos como el resto del local.
puerta_entrada = bpy.data.objects["puerta2-col"]
centro = Vector((7.974, 6.82, .127237 + 2.70 / 2))
vertices = []
for profundidad, ancho, abajo, arriba in (
    (-.0375, .83, -1.35, 1.35), (.0375, .83, -1.35, 1.35),
    (-.0285, .71, -1.16, 1.16), (.0285, .71, -1.16, 1.16),
):
    vertices.extend([(-ancho, profundidad, abajo), (ancho, profundidad, abajo),
                     (ancho, profundidad, arriba), (-ancho, profundidad, arriba)])
caras = []
for i in range(4):
    j = (i+1) % 4
    caras.extend([(i, j, 8+j, 8+i), (4+j, 4+i, 12+i, 12+j), (j, i, 4+i, 4+j)])
caras.extend([(8, 9, 10, 11), (15, 14, 13, 12)])
malla_hoja = bpy.data.meshes.new("Hoja del baño con panel integrado")
malla_hoja.from_pydata(vertices, [], caras)
malla_hoja.materials.append(panel)
bm = bmesh.new()
bm.from_mesh(malla_hoja)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(malla_hoja)
bm.free()
puerta_entrada.data = malla_hoja
puerta_entrada.matrix_world = Matrix.Translation(centro) @ Matrix.Rotation(-math.pi/2, 4, "Z")
# Los herrajes forman parte del mismo objeto y giran con la hoja.
partes = [puerta_entrada]
for x in (7.89, 8.058):
    partes.append(caja("manija del baño", (x, 6.22, 1.32), (.09, .16, .04), metal))
for z in (.35, .41, .47, .53):
    partes.append(caja("rejilla del baño", (7.9435, 6.82, z), (.003, .46, .022), marco))
bpy.ops.object.select_all(action="DESELECT")
for objeto in partes:
    objeto.select_set(True)
bpy.context.view_layer.objects.active = puerta_entrada
bpy.ops.object.join()
# Un perfil de U extruido comparte vértices en las esquinas del marco.
perfil = [(-.907, .102237), (-.907, 2.937237), (.907, 2.937237), (.907, .102237),
          (.847, .102237), (.847, 2.877237), (-.847, 2.877237), (-.847, .102237)]
vertices = [(x, 6.82+y, z) for x in (7.843, 7.906) for y, z in perfil]
caras = [(0, 1, 6, 7), (1, 2, 5, 6), (2, 3, 4, 5)]
caras += [tuple(i+8 for i in reversed(cara)) for cara in caras[:]]
caras += [(i, (i+1) % 8, (i+1) % 8+8, i+8) for i in range(8)]
malla_marco = bpy.data.meshes.new("Marco continuo del baño")
malla_marco.from_pydata(vertices, [], caras)
malla_marco.materials.append(marco)
bm = bmesh.new()
bm.from_mesh(malla_marco)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(malla_marco)
bm.free()
objeto = bpy.data.objects.new("bano_marco_entrada", malla_marco)
coleccion.objects.link(objeto)


inodoro = bpy.data.objects["inodoro-convcol"]
base = original(inodoro)
centro = sum((base @ Vector(v) for v in inodoro.bound_box), Vector()) / 8
giro = Matrix.Rotation(-math.pi / 2, 4, "Z")
destino = Vector((10.945, 1.73, centro.z))
movimiento = Matrix.Translation(destino) @ giro @ Matrix.Translation(-centro)
inodoro.matrix_world = movimiento @ base
segundo = duplicar(inodoro, "bano_inodoro_2-convcol")
segundo.location.x += 1.61

lavatorio = bpy.data.objects["vanitory-convcol"]
base = original(lavatorio)
centro = sum((base @ Vector(v) for v in lavatorio.bound_box), Vector()) / 8
destino = Vector((13.02, 5.70, .282 + (centro.z - .102) * .8))
mov_lavatorio = Matrix.Translation(destino) @ Matrix.Scale(.8, 4) @ Matrix.Translation(-centro)
lavatorio.matrix_world = mov_lavatorio @ base
duplicar(lavatorio, "bano_lavatorio_2-convcol").location.y += 1.62

# La papelera y la nota del inodoro salen de las cabinas y siguen siendo accesibles.
papelera = bpy.data.objects["tachitobasura-col.002"]
base = original(papelera)
centro = sum((base @ Vector(v) for v in papelera.bound_box), Vector()) / 8
papelera.matrix_world = Matrix.Translation(Vector((9.15, 2.1, centro.z)) - centro) @ base
nota = bpy.data.objects["nota baño inodoro-col"]
base = original(nota)
centro = sum((base @ Vector(v) for v in nota.bound_box), Vector()) / 8
nota.matrix_world = (
    Matrix.Translation((10.945, 1.335, 1.52)) @ giro @ Matrix.Translation(-centro) @ base
)

# Coordenadas de las superficies de agua, calculadas por el mismo movimiento que el artefacto.
agua_inodoro = movimiento @ Vector((13.009, 4.185, .549))
agua_lavatorio = mov_lavatorio @ Vector((13.11, 6.567, .828))
gota = mov_lavatorio @ Vector((13.193, 6.567, 1.084))
print("AGUA_INODORO", tuple(agua_inodoro))
print("AGUA_LAVATORIO", tuple(agua_lavatorio))
print("GOTA", tuple(gota))
destino = FUENTE if "--aplicar" in sys.argv else RAIZ / "reports/bano-publico.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
print("Baño público preparado:", destino)

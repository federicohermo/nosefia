"""Hornea Ivory con el tono existente y alinea piso y zócalo antes del flip V de glTF.

Sin --aplicar guarda una copia en reports. La receta editable queda en un material
sin usuarios; el material visible sólo tiene mapas PBR compatibles con glTF.
"""

import array
import hashlib
import json
import shutil
import sys
from pathlib import Path

import bpy

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402
from lib.piso_del_bano import coordenada_del_piso, coordenada_del_zocalo  # noqa: E402

configurar()
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
ORIGEN = RAIZ / "assets/source/textures/bathroom/poliigon/6956-ivory/1K"
DESTINO = RAIZ / "assets/source/textures/bathroom/final"
bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)


def huellas(excepciones):
    resultado = {}
    for objeto in bpy.data.objects:
        if objeto.type != "MESH":
            continue
        malla = objeto.data
        posiciones = array.array("f", [0]) * (len(malla.vertices) * 3)
        malla.vertices.foreach_get("co", posiciones)
        topologia = [tuple(p.vertices) for p in malla.polygons]
        geometria = hashlib.sha256(posiciones.tobytes())
        geometria.update(repr(topologia).encode())
        geometria.update(repr([p.material_index for p in malla.polygons]).encode())
        uv = hashlib.sha256()
        for capa in malla.uv_layers:
            uv.update(capa.name.encode())
            for poligono in malla.polygons:
                if capa == malla.uv_layers.active and poligono.index in excepciones.get(
                    objeto.name, set()
                ):
                    continue
                for i in poligono.loop_indices:
                    uv.update(repr(tuple(capa.data[i].uv)).encode())
        resultado[objeto.name] = {
            "geometria": geometria.hexdigest(), "uv_ajena": uv.hexdigest(),
            "matriz": repr(tuple(tuple(fila) for fila in objeto.matrix_world)),
            "materiales": [m.name if m else None for m in malla.materials],
        }
    return resultado


material = bpy.data.materials["bano_piso_gris"]
edificio = bpy.data.objects["almacen-col"]
zocalo = bpy.data.objects["bano_zocalo_perimetral"]
caras_del_piso = {
    p.index for p in edificio.data.polygons
    if edificio.data.materials[p.material_index] == material
}
excepciones = {
    edificio.name: caras_del_piso,
    zocalo.name: {p.index for p in zocalo.data.polygons},
}
antes = huellas(excepciones)
vieja = bpy.data.images.get("bano_piso_gris")
assert vieja is not None, "Debe existir la textura gris original para conservar su tono."


def nodo(arbol, tipo, nombre, **atributos):
    nuevo = arbol.nodes.new(tipo)
    nuevo.name = nombre
    nuevo.label = nombre
    for clave, valor in atributos.items():
        setattr(nuevo, clave, valor)
    return nuevo


def imagen(nombre, archivo, color=False):
    im = bpy.data.images.get(nombre)
    if im is None:
        im = bpy.data.images.load(str(archivo), check_existing=False)
        im.name = nombre
    im.colorspace_settings.name = "sRGB" if color else "Non-Color"
    im.filepath = bpy.path.relpath(str(archivo), start=str(FUENTE.parent))
    return im


def textura(arbol, im, coords, nombre):
    tex = nodo(arbol, "ShaderNodeTexImage", nombre, image=im, interpolation="Linear")
    arbol.links.new(coords, tex.inputs["Vector"])
    return tex.outputs["Color"]


def math(arbol, operacion, a, b=None):
    n = nodo(arbol, "ShaderNodeMath", operacion, operation=operacion)
    for i, valor in enumerate((a, b)):
        if valor is None:
            continue
        if isinstance(valor, (int, float)):
            n.inputs[i].default_value = valor
        else:
            arbol.links.new(valor, n.inputs[i])
    return n.outputs[0]


def vector(arbol, operacion, a, b=None):
    n = nodo(arbol, "ShaderNodeVectorMath", operacion, operation=operacion)
    arbol.links.new(a, n.inputs[0])
    if isinstance(b, tuple):
        n.inputs[1].default_value = b
    elif b is not None:
        arbol.links.new(b, n.inputs[1])
    return n.outputs[0]


def mezcla(arbol, a, b, factor, operacion="MIX"):
    n = nodo(arbol, "ShaderNodeMixRGB", operacion, blend_type=operacion)
    if isinstance(factor, (int, float)):
        n.inputs[0].default_value = factor
    else:
        arbol.links.new(factor, n.inputs[0])
    for i, valor in enumerate((a, b), 1):
        if isinstance(valor, tuple):
            n.inputs[i].default_value = (*valor[:3], 1)
        else:
            arbol.links.new(valor, n.inputs[i])
    return n.outputs[0]


def lineal(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4


receta = bpy.data.materials.get("bano_ivory_oscuro_receta")
receta = receta or bpy.data.materials.new("bano_ivory_oscuro_receta")
receta.use_nodes = True
receta.use_fake_user = True
arbol = receta.node_tree
arbol.nodes.clear()
coords = nodo(arbol, "ShaderNodeTexCoord", "UV del mapa de cinco cerámicas").outputs["UV"]
albedo = imagen(
    "ivory_6956_color_1k", ORIGEN / "Poliigon_TilesCeramicWhite_6956_BaseColor.jpg", True
)
rough = imagen("ivory_6956_roughness_1k", ORIGEN / "Poliigon_TilesCeramicWhite_6956_Roughness.jpg")
ao = imagen("ivory_6956_ao_1k", ORIGEN / "Poliigon_TilesCeramicWhite_6956_AmbientOcclusion.jpg")
color = textura(arbol, albedo, coords, "Ivory original")
rugosidad = textura(arbol, rough, coords, "Rugosidad Ivory")
mascara = rugosidad
for desplazamiento in ((.0013, 0, 0), (-.0013, 0, 0), (0, .0013, 0), (0, -.0013, 0)):
    vecino = vector(arbol, "ADD", coords, desplazamiento)
    valor = textura(arbol, rough, vecino, "Junta Ivory ensanchada")
    mascara = math(arbol, "MAXIMUM", mascara, valor)
rango = nodo(arbol, "ShaderNodeMapRange", "Única cuadrícula: juntas Ivory")
rango.interpolation_type = "SMOOTHSTEP"
rango.clamp = True
rango.inputs["From Min"].default_value = .20
rango.inputs["From Max"].default_value = .66
arbol.links.new(mascara, rango.inputs["Value"])
mascara = rango.outputs[0]
grano_uv = vector(arbol, "MULTIPLY", coords, (5, 5, 1))
grano_uv = vector(arbol, "FRACTION", grano_uv)
grano_uv = vector(arbol, "MULTIPLY", grano_uv, (.96, .96, 1))
grano_uv = vector(arbol, "ADD", grano_uv, (.02, .02, 0))
grano = textura(arbol, vieja, grano_uv, "Grano interior del piso gris, sin su cuadrícula")

# Las imágenes de 8 bits exponen píxeles sRGB. Los nodos los convierten a lineal.
pixeles = tuple(albedo.pixels)
valores = [0.0, 0.0, 0.0]
cantidad = 0
for y in range(1024):
    if y % 205 < 12 or y % 205 > 192:
        continue
    for x in range(1024):
        if x % 205 < 12 or x % 205 > 192:
            continue
        i = (y * 1024 + x) * 4
        for canal in range(3):
            valores[canal] += lineal(pixeles[i + canal])
        cantidad += 1
media = tuple(v / cantidad for v in valores)
normalizado = mezcla(arbol, color, tuple(1 / v for v in media), 1, "MULTIPLY")
ceramica = mezcla(arbol, grano, normalizado, 1, "MULTIPLY")
indice_junta = (128 * 256 + 1) * 4
color_junta = tuple(lineal(vieja.pixels[indice_junta + i]) for i in range(3))
salida_color = mezcla(arbol, ceramica, color_junta, mascara)
salida_roughness = mezcla(arbol, rugosidad, (.43, .43, .43), .04)
salida_ao = textura(arbol, ao, coords, "Oclusión Ivory")
combinar = nodo(arbol, "ShaderNodeCombineColor", "ORM: oclusión R, rugosidad G, metal B=0")
combinar.inputs[2].default_value = 0
arbol.links.new(salida_ao, combinar.inputs[0])
arbol.links.new(salida_roughness, combinar.inputs[1])
emision = nodo(arbol, "ShaderNodeEmission", "Horneado sin iluminación")
salida = nodo(arbol, "ShaderNodeOutputMaterial", "Salida editable")
arbol.links.new(salida_color, emision.inputs["Color"])
arbol.links.new(emision.outputs[0], salida.inputs["Surface"])

DESTINO.mkdir(parents=True, exist_ok=True)
if "--sin-hornear" not in sys.argv:
    escena_original = bpy.context.window.scene
    escena = bpy.data.scenes.new("Horneado de material Ivory")
    bpy.context.window.scene = escena
    escena.render.engine = "CYCLES"
    escena.cycles.samples = 1
    escena.cycles.device = "CPU"
    bpy.ops.mesh.primitive_plane_add(size=2)
    plano = bpy.context.object
    plano.data.materials.append(receta)
    objetivo = nodo(arbol, "ShaderNodeTexImage", "Destino del horneado")
    for nombre, color_espacio, valor in (
        ("bano_ivory_oscuro_color", "sRGB", salida_color),
        ("bano_ivory_oscuro_orm", "Non-Color", combinar.outputs[0]),
    ):
        for enlace in list(emision.inputs["Color"].links):
            arbol.links.remove(enlace)
        arbol.links.new(valor, emision.inputs["Color"])
        im = bpy.data.images.get(nombre) or bpy.data.images.new(nombre, 1024, 1024)
        im.colorspace_settings.name = color_espacio
        objetivo.image = im
        arbol.nodes.active = objetivo
        bpy.ops.object.bake(type="EMIT", margin=0)
        im.filepath_raw = str(DESTINO / (nombre + ".png"))
        im.file_format = "PNG"
        im.save()
    arbol.nodes.remove(objetivo)
    for enlace in list(emision.inputs["Color"].links):
        arbol.links.remove(enlace)
    arbol.links.new(salida_color, emision.inputs["Color"])
    malla_temporal = plano.data
    bpy.data.objects.remove(plano, do_unlink=True)
    bpy.data.meshes.remove(malla_temporal)
    bpy.context.window.scene = escena_original
    bpy.data.scenes.remove(escena)
    shutil.copy2(
        ORIGEN / "Poliigon_TilesCeramicWhite_6956_Normal.png",
        DESTINO / "bano_ivory_oscuro_normal.png",
    )

# El material usado por la escena es PBR estándar, con UV ya expresadas por mapa.
material.use_nodes = True
arbol_final = material.node_tree
arbol_final.nodes.clear()
uv_final = nodo(arbol_final, "ShaderNodeTexCoord", "UV mundiales compartidas").outputs["UV"]
color_final = imagen("bano_ivory_oscuro_color", DESTINO / "bano_ivory_oscuro_color.png", True)
orm_final = imagen("bano_ivory_oscuro_orm", DESTINO / "bano_ivory_oscuro_orm.png")
normal_final = imagen("bano_ivory_oscuro_normal", DESTINO / "bano_ivory_oscuro_normal.png")
bsdf = nodo(arbol_final, "ShaderNodeBsdfPrincipled", "Cerámica gris Ivory")
arbol_final.links.new(
    textura(arbol_final, color_final, uv_final, "Albedo gris"), bsdf.inputs["Base Color"]
)
canales = nodo(arbol_final, "ShaderNodeSeparateColor", "ORM")
arbol_final.links.new(textura(arbol_final, orm_final, uv_final, "ORM 1K"), canales.inputs[0])
arbol_final.links.new(canales.outputs[1], bsdf.inputs["Roughness"])
bsdf.inputs["Metallic"].default_value = 0
normal = nodo(arbol_final, "ShaderNodeNormalMap", "Normal OpenGL")
arbol_final.links.new(
    textura(arbol_final, normal_final, uv_final, "Normal 1K"), normal.inputs["Color"]
)
arbol_final.links.new(normal.outputs[0], bsdf.inputs["Normal"])
salida_final = nodo(arbol_final, "ShaderNodeOutputMaterial", "Salida PBR glTF")
arbol_final.links.new(bsdf.outputs[0], salida_final.inputs["Surface"])
grupo = bpy.data.node_groups.get("glTF Material Output")
if grupo is None:
    grupo = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
    grupo.interface.new_socket(name="Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
gltf = nodo(arbol_final, "ShaderNodeGroup", "glTF Material Output", node_tree=grupo)
arbol_final.links.new(canales.outputs[0], gltf.inputs["Occlusion"])

suelo = min(
    (edificio.matrix_world @ edificio.data.vertices[i].co).z
    for p in edificio.data.polygons if p.index in caras_del_piso for i in p.vertices
)
for objeto in (edificio, zocalo):
    uv = objeto.data.uv_layers.active
    for p in objeto.data.polygons:
        if p.index not in excepciones[objeto.name]:
            continue
        normal_mundial = (
            objeto.matrix_world.to_3x3().inverted().transposed() @ p.normal
        ).normalized()
        for i in p.loop_indices:
            punto = objeto.matrix_world @ objeto.data.vertices[objeto.data.loops[i].vertex_index].co
            uv.data[i].uv = (
                coordenada_del_piso(punto) if objeto == edificio
                else coordenada_del_zocalo(punto, normal_mundial, suelo)
            )
despues = huellas(excepciones)
assert antes == despues, "Cambió geometría, transformación, material asignado o UV ajena."
informe = {
    "objetos_preservados": len(antes), "geometria_y_uv_ajenas_identicas": True,
    "ceramica_m": .4, "cobertura_m": 2, "resolucion": 1024,
    "albedo_ivory_medio_lineal": media, "junta_original_lineal": color_junta,
    "superficies_recalculadas": {k: len(v) for k, v in excepciones.items()},
    "suelo": suelo, "huellas": despues,
}
(RAIZ / "reports/piso-ivory-auditoria.json").write_text(
    json.dumps(informe, indent=2), encoding="utf-8"
)
salvar = FUENTE if "--aplicar" in sys.argv else RAIZ / "reports/piso-ivory-oscuro.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(salvar), check_existing=False)
print(f"Ivory gris 1K, cerámicas de 40 cm. {len(antes)} objetos conservados. {salvar}")

"""Separar el piso del depósito sin cambiar mallas, colisiones ni UV ajenas.

La fotografía original cubre 1,75 m, sin repartir sus píxeles entre dieciséis parches.
Se conservan los mapas CC0 y la receta alternativa. Sin --aplicar guarda en reports.
--solo-escala conserva los mapas horneados y ajusta únicamente su cobertura física.
--variaciones recupera la mezcla de dieciséis parches para comparar.
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
sys.path.insert(0, str(Path(__file__).resolve().parent))
from mezcla_del_concreto import hornear_variaciones  # noqa: E402

configurar()
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
ORIGEN = RAIZ / "assets/source/textures/warehouse/polyhaven/concrete-floor-worn-001/1K"
DESTINO = RAIZ / "assets/source/textures/warehouse/final"
NOMBRE = "deposito_concreto"
COBERTURA = 7.0 if "--variaciones" in sys.argv else 1.75
# Cycles mezcla en espacio lineal; esta ganancia conserva el gris de la copia anterior.
GANANCIA = 1.9
RELIEVE = 0.45

bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
edificio = bpy.data.objects["almacen-col"]
caras = {
    p.index for p in edificio.data.polygons
    if p.normal.z > .99
    and min((edificio.matrix_world @ edificio.data.vertices[i].co).y
            for i in p.vertices) > 7.87
    and abs((edificio.matrix_world @ p.center).z - .102237) < .001
}
# El corte entre bloques y chapa renumera la ultima cara del piso.
assert caras in ({176, 265, 274, 284, 287}, {176, 265, 274, 284, 286}), (
    "Cambió el piso: revisar antes de aplicar."
)
marco = bpy.data.objects["puerta-col"]
base_del_marco = marco.data.polygons[4]
assert base_del_marco.normal.z < -.99
assert all(abs((marco.matrix_world @ marco.data.vertices[i].co).z - .102237) < .001
           for i in base_del_marco.vertices), "Cambió la base del marco del depósito."
excepciones = {edificio.name: caras, marco.name: {4}}


def huellas():
    resultado = {}
    for objeto in bpy.data.objects:
        if objeto.type != "MESH":
            continue
        malla = objeto.data
        posiciones = array.array("f", [0]) * (len(malla.vertices) * 3)
        malla.vertices.foreach_get("co", posiciones)
        geometria = hashlib.sha256(posiciones.tobytes())
        geometria.update(repr([tuple(p.vertices) for p in malla.polygons]).encode())
        uv = hashlib.sha256()
        materiales = []
        for p in malla.polygons:
            autorizada = p.index in excepciones.get(objeto.name, set())
            material = (malla.materials[p.material_index]
                        if p.material_index < len(malla.materials) else None)
            if not autorizada:
                materiales.append((p.index, material.name if material else None))
            for capa in malla.uv_layers:
                if autorizada and capa == malla.uv_layers.active:
                    continue
                uv.update(capa.name.encode())
                for i in p.loop_indices:
                    uv.update(repr(tuple(capa.data[i].uv)).encode())
        resultado[objeto.name] = {
            "geometria": geometria.hexdigest(), "uv_ajenas": uv.hexdigest(),
            "materiales_ajenos": hashlib.sha256(repr(materiales).encode()).hexdigest(),
            "matriz": [list(fila) for fila in objeto.matrix_world],
            "padre": objeto.parent.name if objeto.parent else None,
            "modificadores": [(m.name, m.type, m.show_viewport, m.show_render)
                              for m in objeto.modifiers],
        }
    return resultado


def imagen(archivo, color):
    im = bpy.data.images.load(str(archivo), check_existing=True)
    im.colorspace_settings.name = "sRGB" if color else "Non-Color"
    im.filepath = bpy.path.relpath(str(archivo), start=str(FUENTE.parent))
    return im


antes = huellas()
imagenes_ajenas = {im.name: im.filepath for im in bpy.data.images
                   if im.name not in {"concrete_floor_worn_001_rough_1k",
                                      "deposito_concreto_color", "deposito_concreto_normal"}}
DESTINO.mkdir(parents=True, exist_ok=True)
color_original = imagen(ORIGEN / "concrete_floor_worn_001_diff_1k.jpg", True)
normal_original = imagen(ORIGEN / "concrete_floor_worn_001_nor_gl_1k.png", False)
roughness = imagen(ORIGEN / "concrete_floor_worn_001_rough_1k.jpg", False)
if "--solo-escala" in sys.argv:
    color = bpy.data.images["deposito_concreto_color"]
    normal = bpy.data.images["deposito_concreto_normal"]
    roughness = bpy.data.images["concrete_floor_worn_001_rough_1k"]
elif "--variaciones" in sys.argv:
    color, normal, roughness = hornear_variaciones(
        color_original, normal_original, roughness, DESTINO, FUENTE, GANANCIA
    )
else:
    mapas = []
    for original, nombre, es_color in (
        (color_original, "deposito_concreto_color", True),
        (normal_original, "deposito_concreto_normal", False),
        (roughness, "concrete_floor_worn_001_rough_1k", False),
    ):
        original.reload()
        pixeles = list(original.pixels)
        anterior = bpy.data.images.get(nombre)
        if anterior is not None:
            anterior.name = nombre + "_atlas_anterior"
        nuevo = bpy.data.images.load(bpy.path.abspath(original.filepath), check_existing=False)
        nuevo.name = nombre
        nuevo.colorspace_settings.name = "sRGB" if es_color else "Non-Color"
        nuevo.filepath_raw = str(DESTINO / (nombre + ".png"))
        nuevo.file_format = "PNG"
        # Cambiar ruta o espacio de color puede recargar el destino existente: copiar después.
        nuevo.pixels[:] = pixeles
        assert nuevo.is_dirty, "La copia debe guardar píxeles, no recargar el atlas anterior."
        nuevo.save()
        nuevo.filepath = bpy.path.relpath(nuevo.filepath_raw, start=str(FUENTE.parent))
        if anterior is not None:
            anterior.user_remap(nuevo)
            bpy.data.images.remove(anterior)
        mapas.append(nuevo)
    color, normal, roughness = mapas

material = bpy.data.materials.get(NOMBRE) or bpy.data.materials.new(NOMBRE)
material.use_nodes = True
material.use_backface_culling = True
arbol = material.node_tree
arbol.nodes.clear()
salida = arbol.nodes.new("ShaderNodeOutputMaterial")
salida.location = (650, 0)
bsdf = arbol.nodes.new("ShaderNodeBsdfPrincipled")
bsdf.location = (350, 0)
bsdf.inputs["Metallic"].default_value = 0.0
arbol.links.new(bsdf.outputs["BSDF"], salida.inputs["Surface"])
for im, entrada, y in ((color, "Base Color", 250), (roughness, "Roughness", 0)):
    tex = arbol.nodes.new("ShaderNodeTexImage")
    tex.image = im
    tex.location = (-350, y)
    arbol.links.new(tex.outputs["Color"], bsdf.inputs[entrada])
tex_normal = arbol.nodes.new("ShaderNodeTexImage")
tex_normal.image = normal
tex_normal.location = (-350, -300)
nodo_normal = arbol.nodes.new("ShaderNodeNormalMap")
nodo_normal.location = (0, -200)
nodo_normal.inputs["Strength"].default_value = RELIEVE
arbol.links.new(tex_normal.outputs["Color"], nodo_normal.inputs["Color"])
arbol.links.new(nodo_normal.outputs["Normal"], bsdf.inputs["Normal"])
material["source"] = "https://polyhaven.com/a/concrete_floor_worn_001"
material["license"] = "CC0-1.0"
material["coverage_m"] = COBERTURA
material["detail_coverage_m"] = COBERTURA / (4 if "--variaciones" in sys.argv else 1)
material["baked_variants"] = 16 if "--variaciones" in sys.argv else 1
material["albedo_gain_linear"] = GANANCIA if "--variaciones" in sys.argv else 1.0

receta_vieja = bpy.data.materials.get(NOMBRE + "_receta")
if receta_vieja is not None:
    bpy.data.materials.remove(receta_vieja)
receta = material.copy()
receta.name = NOMBRE + "_receta"
receta.use_fake_user = True
arbol_receta = receta.node_tree
textura_color = next(n for n in arbol_receta.nodes
                     if n.type == "TEX_IMAGE" and n.image == color)
textura_color.image = color_original
multiplicar = arbol_receta.nodes.new("ShaderNodeMixRGB")
multiplicar.blend_type = "MULTIPLY"
multiplicar.inputs[0].default_value = 1.0
multiplicar.inputs[2].default_value = (GANANCIA, GANANCIA, GANANCIA, 1)
arbol_receta.links.new(textura_color.outputs["Color"], multiplicar.inputs[1])
bsdf_receta = next(n for n in arbol_receta.nodes if n.type == "BSDF_PRINCIPLED")
arbol_receta.links.new(multiplicar.outputs[0], bsdf_receta.inputs["Base Color"])
next(n for n in arbol_receta.nodes if n.type == "TEX_IMAGE" and n.image == normal).image = (
    normal_original
)

for nombre, permitidas in excepciones.items():
    objeto = bpy.data.objects[nombre]
    if material not in list(objeto.data.materials):
        objeto.data.materials.append(material)
    indice_material = list(objeto.data.materials).index(material)
    capa = objeto.data.uv_layers.active
    assert capa is not None, "El piso y el marco deben conservar sus UV originales."
    for poligono in objeto.data.polygons:
        if poligono.index not in permitidas:
            continue
        poligono.material_index = indice_material
        for i in poligono.loop_indices:
            vertice = objeto.data.loops[i].vertex_index
            punto = objeto.matrix_world @ objeto.data.vertices[vertice].co
            capa.data[i].uv = (punto.x / COBERTURA, (punto.y - 7.871065) / COBERTURA)

despues = huellas()
assert antes == despues, "Se modificó geometría, transformaciones, materiales o UV ajenas."
for nombre, ruta in imagenes_ajenas.items():
    assert bpy.data.images[nombre].filepath == ruta, "Se reapuntó una imagen ajena."
assert all((Path(bpy.path.abspath(im.filepath)).is_file() or im.packed_file)
           for im in (color, normal, roughness, color_original, normal_original))
(RAIZ / "reports/deposito-textura-auditoria.json").write_text(
    json.dumps({"caras": sorted(caras), "cara_base_del_marco": 4,
                "cobertura_m": COBERTURA, "detalle_m": material["detail_coverage_m"],
                "variaciones": material["baked_variants"],
                "ganancia": material["albedo_gain_linear"],
                "relieve": RELIEVE, "huellas_antes": antes, "huellas_despues": despues},
               indent=2, ensure_ascii=False), encoding="utf-8"
)
salvar = FUENTE if "--aplicar" in sys.argv else RAIZ / "reports/deposito-concreto.blend"
if salvar == FUENTE:
    respaldo = RAIZ / "reports/deposito-antes.blend"
    if not respaldo.exists():
        shutil.copy2(FUENTE, respaldo)
bpy.ops.wm.save_as_mainfile(filepath=str(salvar), check_existing=False)
print(f"Piso del depósito: {len(caras)} caras, {COBERTURA} m, guardado en {salvar}")

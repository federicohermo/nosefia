"""Remate continuo de las paredes, sin atravesar el umbral ni modificar el edificio."""

import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402
from lib.piso_del_bano import coordenada_del_zocalo  # noqa: E402

configurar()

raiz = Path(__file__).resolve().parents[3]
fuente = raiz / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
bpy.ops.wm.open_mainfile(filepath=str(fuente), load_ui=False)
nombre = "bano_zocalo_perimetral"
anterior = bpy.data.objects.get(nombre)
if anterior is not None:
    bpy.data.objects.remove(anterior, do_unlink=True)

# El remate llega al fondo del marco: una cota fija atravesaría su rebaje al ajustarlo.
marco = bpy.data.objects["bano_marco_entrada"]
fin_del_marco = max((marco.matrix_world @ v.co).x for v in marco.data.vertices)
recorrido = [Vector(p) for p in (
    (fin_del_marco, 5.97848), (8.29186, 5.97848), (8.29186, 1.27768),
    (13.43466, 1.27768), (13.43466, 7.88604), (8.29186, 7.88604),
    (8.29186, 7.66135), (fin_del_marco, 7.66135),
)]
perfil = [(0, 0), (.016, 0), (.016, .102), (.012, .11), (0, .11)]
vertices = []
for i, punto in enumerate(recorrido):
    antes = (punto - recorrido[max(0, i - 1)]).normalized()
    despues = (recorrido[min(i + 1, len(recorrido) - 1)] - punto).normalized()
    if i == 0:
        antes = despues
    elif i == len(recorrido) - 1:
        despues = antes
    normal_antes = Vector((-antes.y, antes.x))
    normal_despues = Vector((-despues.y, despues.x))
    bisectriz = (normal_antes + normal_despues).normalized()
    inglete = bisectriz / bisectriz.dot(normal_antes)
    for espesor, altura in perfil:
        xy = punto + inglete * espesor
        vertices.append((xy.x, xy.y, .10223747 + altura))

cantidad = len(perfil)
caras = [tuple(reversed(range(cantidad)))]
for tramo in range(len(recorrido) - 1):
    for i in range(cantidad):
        j = (i + 1) % cantidad
        caras.append((tramo * cantidad + i, tramo * cantidad + j,
                      (tramo + 1) * cantidad + j, (tramo + 1) * cantidad + i))
caras.append(tuple(range(len(vertices) - cantidad, len(vertices))))
malla = bpy.data.meshes.new(nombre)
malla.from_pydata(vertices, [], caras)
malla.materials.append(bpy.data.materials["bano_piso_gris"])
bm = bmesh.new()
bm.from_mesh(malla)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
assert all(len(arista.link_faces) == 2 for arista in bm.edges)
assert all(cara.calc_area() > 1e-8 for cara in bm.faces)
bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="BEAUTY")
bm.to_mesh(malla)
bm.free()
uv = malla.uv_layers.new(name="UVMap")
for cara in malla.polygons:
    normal = cara.normal
    for indice in cara.loop_indices:
        punto = malla.vertices[malla.loops[indice].vertex_index].co
        uv.data[indice].uv = coordenada_del_zocalo(punto, normal, .10223747)
objeto = bpy.data.objects.new(nombre, malla)
bpy.data.collections["Bano publico"].objects.link(objeto)
destino = fuente if "--aplicar" in sys.argv else raiz / "reports/bano-con-zocalos.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
print(f"Zócalo continuo: {len(vertices)} vértices, altura 11 cm, espesor 16 mm. {destino}")

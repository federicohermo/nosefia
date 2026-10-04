"""Dejar juntas finas de cierre y apoyar las mamparas fijas sobre el suelo.

Editar los extremos existentes conserva el montaje, las hojas y sus bisagras. Las UV
se prolongan desde cada cara, sin estirar sus coordenadas anteriores ni regenerar el baño.
Por defecto guarda una copia; --aplicar integra sobre la fuente actual.
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from ajustar_marco_bano import huella  # noqa: E402
from lib.consola import configurar  # noqa: E402

configurar()
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
FIJAS = (
    "bano_mampara_frontal-convcol", "bano_mampara_frontal-convcol.001",
    "bano_mampara_frontal-convcol.003", "bano_mampara_lateral-convcol",
    "bano_mampara_lateral-convcol.001", "bano_perfil_encuentro_1",
    "bano_perfil_encuentro_2",
)
PATAS = ("bano_pata_mampara", "bano_pata_mampara.001", "bano_pata_mampara.002")
HOLGURA = 0.008


def prolongar_uv(objeto, previos):
    for capa in objeto.data.uv_layers:
        for cara in objeto.data.polygons:
            bucles = list(cara.loop_indices)
            a, b, c = [previos[objeto.data.loops[i].vertex_index] for i in bucles[:3]]
            u, v = b - a, c - a
            uu, uv, vv = u.dot(u), u.dot(v), v.dot(v)
            determinante = uu * vv - uv * uv
            if determinante <= 0:
                raise RuntimeError(f"Cara degenerada antes de editar {objeto.name}")
            ua, ub, uc = [capa.data[i].uv.copy() for i in bucles[:3]]
            for indice in bucles:
                vertice = objeto.data.loops[indice].vertex_index
                delta = objeto.data.vertices[vertice].co - previos[vertice]
                if delta.length_squared == 0:
                    continue
                alfa = (delta.dot(u) * vv - delta.dot(v) * uv) / determinante
                beta = (delta.dot(v) * uu - delta.dot(u) * uv) / determinante
                capa.data[indice].uv += alfa * (ub - ua) + beta * (uc - ua)


def arbol(objeto, giro=Matrix.Identity(4)):
    matriz = giro @ objeto.matrix_world
    return BVHTree.FromPolygons(
        [matriz @ v.co for v in objeto.data.vertices],
        [tuple(p.vertices) for p in objeto.data.polygons], epsilon=0.000001,
    )


def aplicar():
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    ajenos = {o.name: huella(o) for o in bpy.data.objects
              if o.type == "MESH" and o.name not in (*FIJAS, *PATAS)}
    edificio = bpy.data.objects["almacen-col"]
    material = list(edificio.data.materials).index(bpy.data.materials["bano_piso_gris"])
    piso = max((edificio.matrix_world @ edificio.data.vertices[i].co).z
               for cara in edificio.data.polygons if cara.material_index == material
               and abs(cara.normal.z) > 0.9 for i in cara.vertices)
    cierres = {}
    for numero, poste in enumerate(FIJAS[:2], 1):
        hoja = bpy.data.objects[f"bano_puerta_{numero}"]
        canto = min((hoja.matrix_world @ v.co).x for v in hoja.data.vertices)
        cierres[poste] = canto - HOLGURA
    for nombre in FIJAS:
        objeto = bpy.data.objects[nombre]
        previos = [v.co.copy() for v in objeto.data.vertices]
        puntos = [objeto.matrix_world @ v for v in previos]
        inferior = min(p.z for p in puntos)
        extremo = max(p.x for p in puntos)
        inversa = objeto.matrix_world.inverted()
        for vertice, punto in zip(objeto.data.vertices, puntos):
            cambiado = False
            if abs(punto.z - inferior) < 0.000001:
                punto.z = piso
                cambiado = True
            if nombre in cierres and abs(punto.x - extremo) < 0.000001:
                punto.x = cierres[nombre]
                cambiado = True
            if cambiado:
                vertice.co = inversa @ punto
        prolongar_uv(objeto, previos)
        objeto.data.update()
        editable = bmesh.new()
        editable.from_mesh(objeto.data)
        bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
        assert all(e.is_manifold for e in editable.edges), nombre
        assert all(f.calc_area() > 0 for f in editable.faces), nombre
        editable.to_mesh(objeto.data)
        editable.free()
        assert abs(min((objeto.matrix_world @ v.co).z
                       for v in objeto.data.vertices) - piso) < 0.000001, nombre
    for nombre in PATAS:
        objeto = bpy.data.objects.get(nombre)
        if objeto is not None:
            bpy.data.objects.remove(objeto, do_unlink=True)
    assert all(huella(bpy.data.objects[n]) == firma for n, firma in ajenos.items())
    fijas = [o for o in bpy.data.collections["Bano publico"].objects
             if o.type == "MESH" and o.name.startswith(("bano_mampara", "bano_perfil",
                                                       "bano_riel", "bano_anclaje"))]
    arboles = [(o.name, arbol(o)) for o in fijas]
    for numero in (1, 2):
        hoja = bpy.data.objects[f"bano_puerta_{numero}"]
        eje = hoja.matrix_world @ Vector(hoja["eje_de_bisagra_local"])
        for grados in range(0, 91, 5):
            giro = Matrix.Translation(eje) @ Matrix.Rotation(math.radians(grados), 4, "Z")
            movil = arbol(hoja, giro @ Matrix.Translation(-eje))
            assert all(not movil.overlap(fijo) for _, fijo in arboles), (hoja.name, grados)
    informe = {"piso_z": piso, "holgura_cierre_mm": HOLGURA * 1000,
               "piezas_apoyadas": FIJAS, "patas_eliminadas": PATAS,
               "mallas_ajenas_identicas": len(ajenos), "barrido_sin_choques": True}
    informes = RAIZ / "reports"
    informes.mkdir(exist_ok=True)
    (informes / "cabinas-terminadas.json").write_text(
        json.dumps(informe, indent=2), encoding="utf-8")
    destino = FUENTE if "--aplicar" in sys.argv else informes / "cabinas-terminadas.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(informe, indent=2))


if __name__ == "__main__":
    aplicar()

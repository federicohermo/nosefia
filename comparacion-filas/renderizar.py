"""Comparación externa de candidatos medidos; no guarda ningún .blend."""
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

base = Path(__file__).resolve().parent
pins = json.loads((base / "sourcepins.json").read_text(encoding="utf-8"))
for rel, sha in pins["inputs"].items():
    assert hashlib.sha256((base / rel).read_bytes()).hexdigest() == sha, rel
sys.path.insert(0, str(base / "helpers"))
spec = importlib.util.spec_from_file_location("acomodador", base / "helpers/blender/acomodar.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
from lib.blender import es_un_array

for o in bpy.data.objects:
    for mod in o.modifiers:
        if es_un_array(mod.name):
            mod.show_render = False
            mod.show_viewport = False
    o.hide_render = True
for c in bpy.data.collections:
    c.hide_render = False

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "OBJECT"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = "BOTH"
scene.display.shading.background_type = "WORLD"
scene.world.color = (.12, .12, .12)
scene.render.resolution_x = 1600
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
collection = bpy.data.collections.new("Comparacion434_externa")
scene.collection.children.link(collection)
camera = bpy.data.objects.new("Comparacion434_camara", bpy.data.cameras.new("Comparacion434_camara"))
scene.collection.objects.link(camera)
camera.data.type = "ORTHO"
camera.data.clip_start = .01
scene.camera = camera
report = {"sourcepins": pins, "leyenda": {"dorado": "fila de adelante", "azul": "fila de atras",
          "gris": "mueble y referencia vecina sin cambios"}, "productos": {}}

for target, key, products in (("ACTRONCITO", "N.sur.2", ("ACTRONCITO", "DUREXTRA")),
                              ("PRONGLES", "B.oeste.2", ("DONSATURADOS", "PRONGLES"))):
    furniture, bm, shelves = m.medir(key.split(".")[0])
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    e = shelves[key]
    envases = [m.envase_de(m.producto(p), bpy.data.objects[m.producto(p).objeto]) for p in products]
    tilt = m.inclinacion_de(e)
    high = max(m.alto_en_la_rampa(envase, tilt) for envase in envases) - m.ROCE_DE_ARRIBA
    start, end = m.franja_del_estante(e, tree, high)
    left, right = m.tramo_util(e, tree, start, end)
    counts = m.repartir(right-left, envases)
    positions = m.centros(right-left, envases, counts)
    variants = {}
    supporting = {i for i in e.caras if all(abs((v.co-e.origen).dot(e.normal)) <= .002
                                           for v in bm.faces[i].verts)}
    for rows in (1, 2):
        copies, records = [], []
        for product, package, centers in zip(products, envases, positions):
            p = m.producto(product)
            source = bpy.data.objects[p.objeto]
            for place in m.tanda(package, [left+u for u in centers], tilt, rows if product == target else 2):
                matrix = m.matriz_de(p, source, e, place.u, start+place.v)
                points = [matrix @ v.co for v in source.data.vertices]
                feet = [v-e.origen for v in points if abs((v-e.origen).dot(e.normal)) <= .002]
                assert feet and all(-.000001 <= v.dot(e.u) <= e.largo+.000001 and
                                   -.000001 <= v.dot(e.v) <= e.fondo+.000001 for v in feet)
                body = BVHTree.FromPolygons(points, [list(p.vertices) for p in source.data.polygons])
                assert not [i for i, _ in tree.overlap(body) if i not in supporting], (target, rows, product)
                copy = source.copy()
                copy.parent = None
                collection.objects.link(copy)
                copy.matrix_world = matrix
                copy.hide_render = True
                copy.color = ((.95, .55, .12, 1) if place.fila == "adelante" else (.12, .55, .95, 1)) \
                    if product == target else (.31, .34, .37, 1)
                copies.append(copy)
                records.append({"producto": product, "fila": place.fila, "columna": place.columna,
                                "matrix_world": [list(r) for r in matrix], "contactos": len(feet),
                                "intersecciones_obstaculos": 0})
        variants[rows] = (copies, records)
    target_points = [o.matrix_world @ v.co for o, r in zip(*variants[2]) if r["producto"] == target
                     for v in o.data.vertices]
    low = Vector(tuple(min(v[i] for v in target_points) for i in range(3)))
    high = Vector(tuple(max(v[i] for v in target_points) for i in range(3)))
    center = (low+high)/2
    # El encuadre se calcula una sola vez desde la alternativa doble y se comparte sin cambios.
    bounds = [Vector((x,y,z)) for x in (low.x-.06,high.x+.06)
              for y in (low.y-.06,high.y+.06) for z in (low.z-.075,high.z+.04)]
    furniture.hide_render = False
    furniture.color = (.45, .49, .53, 1)
    report["productos"][target] = {"estante": key, "desplazamiento": 0,
                                   "variantes": {}, "camaras": {}}
    for view, direction in (("frontal", e.mira*1.0+e.u*.24+Vector((0,0,.55))),
                            ("lateral-alta", e.mira*.85+e.u*.95+Vector((0,0,1.15)))):
        camera.location = center + direction.normalized()*4
        camera.rotation_euler = (center-camera.location).to_track_quat("-Z", "Y").to_euler()
        inv = camera.rotation_euler.to_matrix().transposed()
        projected = [inv @ (v-center) for v in bounds]
        camera.data.ortho_scale = max((max(v.y for v in projected)-min(v.y for v in projected))*1.6,
                                      max(v.x for v in projected)-min(v.x for v in projected))*1.15
        report["productos"][target]["camaras"][view] = {"location": list(camera.location),
            "rotation_euler": list(camera.rotation_euler), "ortho_scale": camera.data.ortho_scale}
        for rows, (copies, records) in variants.items():
            for o in copies:
                o.hide_render = False
            filename = f"{target.lower()}-{rows}-fila{'s' if rows == 2 else ''}-{view}.png"
            scene.render.filepath = str(base/filename)
            bpy.ops.render.render(write_still=True)
            for o in copies:
                o.hide_render = True
            report["productos"][target]["variantes"][str(rows)] = records
    furniture.hide_render = True
    for copies, _ in variants.values():
        for o in copies:
            bpy.data.objects.remove(o, do_unlink=True)
    bm.free()

(base/"render.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("434_COMPARACION_REAL_1_2_FILAS_OK", flush=True)

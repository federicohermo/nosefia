"""Tres fuentes, sólo memoria: mide descomposición y alternativas sin guardar arte."""
import ast
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

base = Path(__file__).resolve().parent
pins = json.loads((base/"sourcepins.json").read_text(encoding="utf-8"))
for path, sha in pins["inputs"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path
raiz = Path(pins["wt"])
sys.path.insert(0, str(raiz/".claude/scripts"))
path = raiz/".claude/scripts/blender/acomodar.py"
spec = importlib.util.spec_from_file_location("acomodador434_sonda", path)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
from lib.reparto import SOLO_DEPOSITO
puntos_original, matriz_original = m._puntos, m.matriz_de


def escala_estable(unidad):
    heredada = (unidad.parent.matrix_world @ unidad.matrix_parent_inverse) if unidad.parent else Matrix.Identity(4)
    factor = heredada.to_scale()
    return Vector(tuple(unidad.scale[i]*factor[i] for i in range(3)))


class EscalaEstable(ast.NodeTransformer):
    def visit_Assign(self, node):
        if (len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)
                and node.targets[0].id == "escala" and isinstance(node.value, ast.Call)
                and isinstance(node.value.func, ast.Attribute) and node.value.func.attr == "to_scale"):
            node.value = ast.Call(func=ast.Name(id="escala_estable", ctx=ast.Load()),
                                  args=[ast.Name(id="unidad", ctx=ast.Load())], keywords=[])
        return node


tree = ast.parse(path.read_text(encoding="utf-8"))
functions = [copy.deepcopy(n) for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in ("_puntos", "matriz_de")]
patched = ast.fix_missing_locations(EscalaEstable().visit(ast.Module(body=functions, type_ignores=[])))


def configure(stable):
    if stable:
        m.__dict__["escala_estable"] = escala_estable
        exec(compile(patched, str(path)+":candidato_memoria", "exec"), m.__dict__)
    else:
        m._puntos, m.matriz_de = puntos_original, matriz_original


def matrix(value):
    return [list(row) for row in value]


def state(obj):
    inherited = (obj.parent.matrix_world @ obj.matrix_parent_inverse) if obj.parent else Matrix.Identity(4)
    return {"world": matrix(obj.matrix_world), "local": matrix(obj.matrix_local),
            "basis": matrix(obj.matrix_basis), "scale_local": list(obj.scale),
            "world_to_scale": list(obj.matrix_world.to_scale()), "escala_estable": list(escala_estable(obj)),
            "parent": obj.parent.name if obj.parent else None,
            "parent_world": matrix(obj.parent.matrix_world) if obj.parent else None,
            "matrix_parent_inverse": matrix(obj.matrix_parent_inverse),
            "heredada": matrix(inherited), "rotation_mode": obj.rotation_mode}


def assign(obj, target, variant, original_scale):
    if variant == "actual":
        obj.matrix_world = target
    elif variant == "world_y_escala_local":
        obj.matrix_world = target
        obj.scale = original_scale
    else:
        local = target
        if obj.parent:
            local = obj.matrix_parent_inverse.inverted() @ obj.parent.matrix_world.inverted() @ target
        location, rotation, _ = local.decompose()
        obj.location = location
        if obj.rotation_mode == "QUATERNION":
            obj.rotation_quaternion = rotation
        elif obj.rotation_mode == "AXIS_ANGLE":
            axis, angle = rotation.to_axis_angle()
            obj.rotation_axis_angle = (angle, *axis)
        else:
            obj.rotation_euler = rotation.to_euler(obj.rotation_mode)
        obj.scale = original_scale
    # La evaluación explicita la descomposición que también ocurre al guardar/reabrir.
    bpy.context.view_layer.update()


out = {"pins": pins, "fuentes": {}, "limite": "Ensayos aislados de lectura/escritura RNA por unidad; no guardan .blend, no reconstruyen textos originales ni prueban por sí solos toda la regeneración."}
for label, source in pins["fuentes"].items():
    bpy.ops.wm.open_mainfile(filepath=source)
    bpy.context.view_layer.update()
    measurements = {}
    shelves = {}
    for letter in m.MUEBLES:
        obj, bm, measured = m.medir(letter)
        shelves[letter] = (obj, bm, BVHTree.FromBMesh(bm), measured)
    for product in m.PRODUCTOS:
        source_obj = bpy.data.objects[product.objeto]
        record = {"fuente": state(source_obj), "variantes": {}}
        if product.clave in SOLO_DEPOSITO:
            measurements[product.clave] = record
            continue
        key, partition = next((key, partition) for key, tandas in m.ESTANTES.items()
                              for partition, t in enumerate(tandas) if t.producto == product.clave and not t.fija)
        letter = key.split(".")[0]
        record["tandas_de_la_unidad"] = [
            {"estante": k, "particion": i, "fija": t.fija,
             "filas": t.cantidad_de_filas,
             "padre_de_copias": shelves[k.split(".")[0]][0].name,
             "matriz_padre_de_copias": matrix(shelves[k.split(".")[0]][0].matrix_world)}
            for k, ts in m.ESTANTES.items() for i, t in enumerate(ts)
            if t.producto == product.clave
        ]
        _, bm, tree, measured = shelves[letter]
        e = measured[key]
        for variant in ("actual", "world_y_escala_local", "componentes_y_escala_local"):
            configure(variant != "actual")
            obj = source_obj.copy()
            bpy.context.scene.collection.objects.link(obj)
            bpy.context.view_layer.update()
            original_scale = obj.scale.copy()
            envases = [m.envase_de(m.producto(t.producto), bpy.data.objects[m.producto(t.producto).objeto])
                       for t in m.ESTANTES[key]]
            tilt = m.inclinacion_de(e)
            height = max(m.alto_en_la_rampa(x, tilt) for x in envases)-m.ROCE_DE_ARRIBA
            start, end = m.franja_del_estante(e, tree, height)
            left, right = m.tramo_util(e, tree, start, end)
            counts = m.repartir(right-left, envases)
            centers = m.centros(right-left, envases, counts)[partition]
            places = list(m.tanda(envases[partition], [left+u for u in centers], tilt,
                                  m.ESTANTES[key][partition].cantidad_de_filas))
            cycles = []
            for cycle in range(3):
                targets, resulting = [], []
                for place in places:
                    target = m.matriz_de(product, obj, e, place.u, start+place.v)
                    targets.append(matrix(target))
                    assign(obj, target, variant, original_scale)
                    resulting.append(matrix(obj.matrix_world))
                cycles.append({"estado_final": state(obj), "objetivos": targets,
                               "rna_resultante": resulting,
                               "serializado6": [[format(value, ".6f") for row in mat for value in row]
                                                for mat in resulting]})
            record["variantes"][variant] = {"estante": key, "columnas": len(centers),
                "copias": len(places), "ciclos": cycles,
                "objetivos_identicos_1_2": cycles[0]["objetivos"] == cycles[1]["objetivos"],
                "rna_identica_1_2": cycles[0]["rna_resultante"] == cycles[1]["rna_resultante"],
                "texto6_identico_1_2": cycles[0]["serializado6"] == cycles[1]["serializado6"],
                "escala_local_original_conservada": all(c["estado_final"]["scale_local"] == list(original_scale) for c in cycles)}
            bpy.data.objects.remove(obj, do_unlink=True)
        measurements[product.clave] = record
    for _, bm, _, _ in shelves.values():
        bm.free()
    out["fuentes"][label] = measurements
configure(False)
(base/"medicion.json").write_bytes(json.dumps(out, indent=2).encode("utf-8"))
summary = {label: {variant: {"textos6_inestables": [p for p, data in products.items()
                     if variant in data["variantes"] and not data["variantes"][variant]["texto6_identico_1_2"]],
                           "rna_inestables": [p for p, data in products.items()
                     if variant in data["variantes"] and not data["variantes"][variant]["rna_identica_1_2"]]}
                  for variant in ("actual", "world_y_escala_local", "componentes_y_escala_local")}
           for label, products in out["fuentes"].items()}
(base/"resumen.json").write_bytes(json.dumps(summary, indent=2).encode("utf-8"))
print(json.dumps(summary, indent=2), flush=True)
print("434_SONDA_RNA_READONLY_COMPLETA", flush=True)

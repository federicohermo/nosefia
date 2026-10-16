"""Regresión Blender: código c780 y corregido, misma fuente, sin guardar."""
import importlib.util
import json
from pathlib import Path
import sys
import unittest

import bpy

base = Path(__file__).resolve().parent
pins = json.loads((base / "sourcepins.json").read_text(encoding="utf-8"))
wt = Path(pins["wt"])
sys.path.insert(0, str(wt / ".claude/scripts"))


def cargar(nombre, path):
    spec = importlib.util.spec_from_file_location(nombre, path)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def matriz(objeto):
    return tuple(tuple(fila) for fila in objeto.matrix_world)


class ColocacionRepetida(unittest.TestCase):
    def __init__(self, modulo, producto, muebles):
        super().__init__()
        self.modulo, self.producto, self.muebles = modulo, producto, muebles

    def id(self):
        return self.producto.clave

    def shortDescription(self):
        return self.producto.clave

    def runTest(self):
        m, p = self.modulo, self.producto
        clave = next(k for k, ts in m.ESTANTES.items()
                     if any(t.producto == p.clave and not t.fija for t in ts))
        padre, _, estantes = self.muebles[clave.split(".")[0]]
        estante = estantes[clave]
        original = bpy.data.objects[p.objeto]
        clon = original.copy()
        bpy.context.scene.collection.objects.link(clon)
        bpy.context.view_layer.update()
        escala = tuple(clon.scale)
        copias = []
        try:
            datos = {"tanda": "regresion", "fila": 0, "orden": 0,
                     "producto": p.clave, "fija": False}
            objetivo = m.matriz_de(p, clon, estante, estante.largo / 2, 0.05)
            m.poner(clon, padre, objetivo, datos, copia=False)
            bpy.context.view_layer.update()
            self.assertEqual(tuple(clon.scale), escala, "La colocación cambió escala artística")
            primera = matriz(clon)
            objetivo = m.matriz_de(p, clon, estante, estante.largo / 2, 0.05)
            m.poner(clon, padre, objetivo, datos, copia=False)
            bpy.context.view_layer.update()
            self.assertEqual(tuple(clon.scale), escala)
            self.assertEqual(matriz(clon), primera, "Realimentación de la colocación anterior")
            antes = set(bpy.data.objects)
            m.poner(clon, padre, objetivo, datos | {"fija": True}, copia=True)
            copias = list(set(bpy.data.objects) - antes)
            self.assertEqual(len(copias), 1)
            bpy.context.view_layer.update()
            self.assertEqual(tuple(copias[0].scale), escala, "La copia cambió escala artística")
            self.assertEqual(copias[0].parent, padre)
        finally:
            for obj in [*copias, clon]:
                bpy.data.objects.remove(obj, do_unlink=True)


resultados = {}
for etiqueta, archivo in (
    ("viejo", pins["snapshot_c780"]),
    ("nuevo", str(wt / ".claude/scripts/blender/acomodar.py")),
):
    bpy.ops.wm.open_mainfile(filepath=pins["fuente_original"])
    bpy.context.view_layer.update()
    m = cargar("acomodar_" + etiqueta, archivo)
    muebles = {letra: m.medir(letra) for letra in m.MUEBLES}
    originales = {p.clave: (matriz(bpy.data.objects[p.objeto]),
                            tuple(bpy.data.objects[p.objeto].scale)) for p in m.PRODUCTOS}
    suite = unittest.TestSuite(ColocacionRepetida(m, p, muebles) for p in m.PRODUCTOS)
    print("434_TDD_RNA_" + etiqueta.upper(), flush=True)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    resultados[etiqueta] = {"tests": result.testsRun, "failures": len(result.failures),
                            "errors": len(result.errors),
                            "detalle_fallos": [(t.id(), msg) for t, msg in result.failures]}
    for p in m.PRODUCTOS:
        assert originales[p.clave] == (matriz(bpy.data.objects[p.objeto]),
                                        tuple(bpy.data.objects[p.objeto].scale)), p.clave
    for _, bm, _ in muebles.values():
        bm.free()

(base / "tdd-rna-resultado.json").write_bytes(
    (json.dumps(resultados, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
assert resultados["viejo"]["tests"] == 32
assert resultados["viejo"]["failures"] > 0 and resultados["viejo"]["errors"] == 0
assert resultados["nuevo"] == {"tests": 32, "failures": 0, "errors": 0, "detalle_fallos": []}
print("434_TDD_RNA_ROJO_REAL_Y_VERDE_32_COMPLETOS", flush=True)

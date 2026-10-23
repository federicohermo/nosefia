import sys, json
from pathlib import Path
RAIZ = Path(r"C:/Users/fede_/orca/workspaces/nosefia/improvement-espaciado-uniforme-de-los-costados")
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(RAIZ / ".claude/scripts/blender"))
import bpy
import disponer_prueba as dp
import disponer, acomodar
from lib.reparto import PRODUCTOS
from lib.reparto_de_prueba import ESTANTES_DE_PRUEBA
from lib.gondola import MARGEN

texto = dp.generar()
envases = {p.clave: acomodar.envase_de(p, bpy.data.objects[p.objeto]) for p in PRODUCTOS}
tandas = disponer.tandas_del_blend()
salida = {}
for letra in sorted({k.split(".")[0] for k in ESTANTES_DE_PRUEBA}):
    _, bm, estantes = dp.medir(letra, envases)
    for clave, copias in tandas.items():
        estante, col = clave.split("/")
        if estante not in estantes:
            continue
        m = estantes[estante]
        fila = []
        for c in copias:
            if c["fila"] != "adelante":
                continue
            pts = [c.matrix_world @ v.co for v in c.data.vertices]
            us = [(p - m.origen).dot(m.u) for p in pts]
            fila.append((min(us), max(us), str(c["producto"])))
        salida.setdefault(estante, []).extend(fila)
    bm.free()
res = {}
for estante, f in sorted(salida.items()):
    f.sort()
    res[estante] = {
        "largo": estantes_largo if False else None,
        "unidades": [(round(a, 4), round(b, 4), p) for a, b, p in f],
    }
print("@@" + json.dumps(res))

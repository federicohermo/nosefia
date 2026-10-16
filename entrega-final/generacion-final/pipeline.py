"""Una sola reserva del motor para regenerar y contrastar las salidas de #434."""
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path.cwd()
SCRATCH = Path(__file__).resolve().parent
BLENDER = "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
GODOT = os.environ["GODOT_BIN"]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
ESTRUCTURA = RAIZ / "src/escenas/puestos/estructura_del_almacen.tscn"
estructura = ESTRUCTURA.read_bytes()
sys.path.insert(0, str(SCRATCH))
from preservar_salidas import preservar


def correr(nombre, comando):
    print(nombre, flush=True)
    proceso = subprocess.run(comando, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=2100 if comando[0] == sys.executable else 900)
    (SCRATCH / ("434-" + nombre + ".log")).write_bytes(proceso.stdout)
    print(proceso.stdout.decode("utf-8", "replace")[-6000:], flush=True)
    if proceso.returncode:
        raise SystemExit(proceso.returncode)
    if b"SCRIPT ERROR" in proceso.stdout or b"Parse Error" in proceso.stdout:
        raise SystemExit("El motor no parseó el árbol")
    if comando[0] == GODOT and b"ERROR:" in proceso.stdout:
        raise SystemExit("Godot informó un error; ver crudo completo")


def blender(nombre, script, *args):
    correr(nombre, [BLENDER, str(FUENTE), "--background", "--python-exit-code", "1",
                    "--python", str(script), "--", *map(str, args)])


blender("tdd-rna", SCRATCH / "test_rna_funcional.py")
blender("acomodar-final", RAIZ / ".claude/scripts/blender/acomodar.py")
blender("arte-muebles", SCRATCH / "434-inspeccionar.py", Path('C:\\Users\\fede_\\AppData\\Local\\Temp\\nosefia-batch-425-435\\434-base.blend'),
        FUENTE, SCRATCH / "434-arte-muebles.json")
blender("disponer", SCRATCH / "434-preflight-disponer.py")
if ESTRUCTURA.read_bytes() != estructura:
    raise SystemExit("La estructura cambió; no seguir con recursos incoherentes")
correr("exportar", [sys.executable, str(SCRATCH / "exportar_con_crudos.py"), "primera"])
# El exportador ya importa. Esta segunda importación debe ser también fría para conservar
# ambos canales crudos del import real, incluso si Godot devuelve 0 con ERROR.
cache = (RAIZ / ".godot/imported").resolve()
assert cache.is_relative_to(RAIZ.resolve()), "La caché está fuera de este worktree"
borrados = []
for archivo in sorted(cache.glob("SEPT_JUEGOS_PROTOTIPO.glb-*")):
    assert archivo.is_file() and archivo.resolve().parent == cache
    borrados.append(str(archivo))
    archivo.unlink()
(SCRATCH / "434-cache-glb-frio.json").write_text(json.dumps(borrados, indent=2), encoding="utf-8")
correr("import-frio", [GODOT, "--headless", "--path", ".", "--import", "--quit"])
correr("extraer", [GODOT, "--headless", "--path", ".", "--script",
                    "assets/models/extraer_mallas.gd"])


def huellas():
    rutas = [RAIZ / "src/escenas/puestos" / p for p in (
        "disposicion_de_la_gondola.tres", "contenido_del_estante.tscn", "guia_del_estante.tscn",
        "estructura_del_almacen.tscn")]
    rutas += sorted((RAIZ / "assets/models").glob("producto_*.res"))
    return {str(p.relative_to(RAIZ)): hashlib.sha256(p.read_bytes()).hexdigest() for p in rutas}


captura_primera = preservar(RAIZ, SCRATCH / "primera")
antes = huellas()
glb = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.glb"
glb_antes = hashlib.sha256(glb.read_bytes()).hexdigest()
shutil.copy2(glb, SCRATCH / "434-exportacion-primera.glb")
blender("acomodar-repetido", RAIZ / ".claude/scripts/blender/acomodar.py")
blender("arte-muebles-repetido", SCRATCH / "434-inspeccionar.py", Path('C:\\Users\\fede_\\AppData\\Local\\Temp\\nosefia-batch-425-435\\434-base.blend'),
        FUENTE, SCRATCH / "434-arte-muebles-repetido.json")
blender("disponer-repetido", SCRATCH / "434-preflight-disponer.py")
correr("exportar-repetido", [sys.executable, str(SCRATCH / "exportar_con_crudos.py"), "repetida"])
correr("extraer-repetido", [GODOT, "--headless", "--path", ".", "--script",
                             "assets/models/extraer_mallas.gd"])
captura_segunda = preservar(RAIZ, SCRATCH / "segunda")
despues = huellas()
glb_despues = hashlib.sha256(glb.read_bytes()).hexdigest()
shutil.copy2(glb, SCRATCH / "434-exportacion-repetida.glb")
(SCRATCH / "434-reproducibilidad.json").write_text(json.dumps(
    {"antes": antes, "despues": despues, "recursos_identicos": antes == despues,
     "glb_antes": glb_antes, "glb_despues": glb_despues,
     "glb_bytes_identicos": glb_antes == glb_despues,
     "captura_primera": captura_primera, "captura_segunda": captura_segunda}, indent=2), encoding="utf-8")
if antes != despues:
    raise SystemExit("La repetición cambió recursos; ver manifiesto")
if glb_antes != glb_despues:
    raise SystemExit("GLB con bytes distintos: requiere comparación semántica de ambas exportaciones conservadas")
print("434_REGENERACION_IDENTICA_OK", flush=True)

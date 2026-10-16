import collections
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path


carpeta = Path(__file__).parent / "full-01"
base = carpeta.parents[1] / "base-integrada-02/crudo"


def lineas(ruta):
    texto = ruta.read_text(encoding="utf-8", errors="replace")
    return re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", texto).splitlines()


def diagnosticos(ruta):
    return collections.Counter(l.strip() for l in lineas(ruta) if l.strip().startswith(("ERROR:", "WARNING:")))


actuales = diagnosticos(carpeta / "tests.log")
anteriores = diagnosticos(base / "tests.log")
xml = ET.parse(carpeta / "results.xml").getroot()
head = subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip()
estado = subprocess.check_output(["git", "status", "--porcelain"]).decode()
nodos = {}
for nombre in ("lint", "formato", "capas", "tdd", "specs", "harness", "tests", "tests-import"):
    nodos[nombre] = json.loads((carpeta / f"{nombre}.json").read_text(encoding="utf-8"))
incidentes = {}
for log in carpeta.glob("*.log"):
    encontrados = [l for l in lineas(log) if re.search(r"SCRIPT ERROR|Parse Error|leaked|still in use|PagedAllocator|Pages in use", l)]
    if encontrados:
        incidentes[log.name] = encontrados


def sin_ids_generados(contador):
    salida = collections.Counter()
    for linea, cantidad in contador.items():
        salida[re.sub(r"@StaticBody3D@\d+", "@StaticBody3D@<id-generado>", linea)] += cantidad
    return salida


resultado = {
    "head": head,
    "estado": estado,
    "codigo": int((carpeta / "exit-code.txt").read_text()),
    "nodos": nodos,
    "suites": len(xml.findall("testsuite")),
    "casos": len(xml.findall(".//testcase")),
    "xml_atributos": xml.attrib,
    "problemas_xml": {tipo: len(xml.findall(".//" + tipo)) for tipo in ("failure", "error", "skipped")},
    "diagnosticos_completos": dict(actuales),
    "nuevos_literales": dict(actuales - anteriores),
    "retirados_literales": dict(anteriores - actuales),
    "incidentes": incidentes,
    "base": str(base),
    "cotejo_adicional_solo_ids_generados": {
        "iguales": sin_ids_generados(actuales) == sin_ids_generados(anteriores),
        "alcance": "Se reemplaza sólo @StaticBody3D@decimal en este cotejo adicional. Se conservan todos los literales, coordenadas, cuerpos, destinos y cantidades en los mapas anteriores.",
    },
    "limite_cronologia": "El wrapper concatena stdout+stderr; no se atribuye fase por la posición final de esos canales. El cotejo literal y su delta se conservan íntegros.",
}
(carpeta / "revision-carril-C.json").write_text(json.dumps(resultado, ensure_ascii=False, indent=2), encoding="utf-8")
sha = "6d60f82c16bbbc1f7182e656ebead8df8bf5ad87"
remotos = subprocess.check_output(["git", "ls-remote", "--heads", "origin", "improvement/431-separadores-de-jornadas-en-chats", "feature/429-444-contratos-integrados"]).decode().splitlines()
pins = {
    "antes": {"head": sha, "estado_porcelain": "", "fuente": "Lectura git status --short y git rev-parse HEAD en el mismo exec_command que encoló full-01; salida de la conversación y mensaje al padre anteriores a la corrida."},
    "despues": {"head": head, "estado_porcelain": estado, "utc": datetime.now(timezone.utc).isoformat()},
    "base": "e6cc0ac4bff25335c0b6a605d85b70cb9014cab0",
    "remotos_contrastados": remotos,
    "congelado": "Sin ediciones desde enqueue hasta resultado. La captura posterior conservó la misma fuente.",
    "limite": "El wrapper original no mide SHA. Se distingue la lectura previa de la captura posterior; no se inventa un archivo previo del wrapper.",
}
(carpeta / "pins.json").write_text(json.dumps(pins, ensure_ascii=False, indent=2), encoding="utf-8")
assert head == sha and not estado
assert resultado["codigo"] == 0 and not incidentes
assert all(n["codigo"] == 0 and not n["salteado"] for n in nodos.values())
assert resultado["suites"] == 279 and resultado["casos"] == 2147
assert not any(resultado["problemas_xml"].values())
print(json.dumps({k: resultado[k] for k in ("head", "codigo", "suites", "casos", "problemas_xml", "nuevos_literales", "retirados_literales", "incidentes", "cotejo_adicional_solo_ids_generados")}, ensure_ascii=True, indent=2))

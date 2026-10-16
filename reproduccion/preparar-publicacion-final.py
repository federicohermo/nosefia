"""Preparación externa: sólo acepta paquete03/Chrome05 y PCK final sin diagnósticos."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

root = Path(__file__).parent
out = root / "publicable"
web = root / "evidencia-04/web-05"
exportado = Path("D:/nosefia-carril-C-429-444/431-export-03")
control = root / "evidencia-04/control-pck-limpio-02"
head = "6d60f82c16bbbc1f7182e656ebead8df8bf5ad87"
assert subprocess.check_output(["git","rev-parse","improvement/431-separadores-de-jornadas-en-chats"],text=True).strip() == head
huellas = json.loads((exportado / "huellas.json").read_text(encoding="utf-8"))
assert huellas["commit"] == head and huellas["configuracion_identica"] and huellas["guardias"] == {"comprobar":0,"verificar_export":0}
assert huellas["archivos"]["index.wasm"]["sha256"] == "47b267630a0bbfcd0c8a1276a7b8f83adf24c2f1425ee2b83396331aa6e82c61"
consola = json.loads((web / "consola.json").read_text(encoding="utf-8"))
recorrido = json.loads((web / "recorrido.json").read_text(encoding="utf-8"))
assert "CHROME431_FINAL" in (root / "chrome-05-turno.log").read_text(encoding="utf-8",errors="replace")
assert not [x for x in consola if x["type"] in ["error","pageerror","runner-error"]]
assert not [x for x in consola if re.search(r"SCRIPT ERROR|Parse Error|(^|\s)ERROR:",x["text"])]
medidas = [x for x in recorrido if "snapshot" in x and "estado" in x]
assert len(medidas) >= 25
for m in medidas:
    e = m["estado"]
    assert e["visible"] == "visible" and e["aislado"] and m["cuadros"] >= 2
    assert (e["ancho"],e["alto"]) in [(1920,1080),(1280,720)]
    if m["snapshot"].endswith("-mundo"):
        assert e["cursor"]
    elif "-almacen-" not in m["snapshot"]:
        assert not e["cursor"]
pck_log = (control / "sonda-paquete.log").read_text(encoding="utf-8",errors="replace")
assert "PAQUETE431_FINAL fallos=0" in pck_log
assert not re.search(r"SCRIPT ERROR|Parse Error|(^|\n)(ERROR:|WARNING:)|leaked|still in use",pck_log)
dialogos = (control / "dialogos-paquete.log").read_text(encoding="utf-8",errors="replace")
assert not re.search(r"SCRIPT ERROR|Parse Error|(^|\n)(ERROR:|WARNING:)|leaked|still in use",dialogos)
assert hashlib.sha256((control / "checkpoint-jornada-2.guardado").read_bytes()).hexdigest() == recorrido[0]["sha256"]

def copiar(src,rel):
    dest = out / rel
    dest.parent.mkdir(parents=True,exist_ok=True)
    if src.is_dir():
        shutil.copytree(src,dest,dirs_exist_ok=True)
    else:
        shutil.copy2(src,dest)

for nombre in ("web","paquete"):
    previo = out / "incidentes" / (nombre + "-plantilla-anterior")
    if not previo.exists():
        copiar(out / nombre,previo.relative_to(out))
copiar(out / "README.md","incidentes/README-publicacion-parcial.md")
copiar(root / "README-final.md","README.md")
copiar(web,"web")
for nombre in ("huellas.json","exportar.log","importar.log","plantilla-comprobar.log","plantilla-verificar-export.log"):
    copiar(exportado / nombre,"paquete-03/" + nombre)
copiar(exportado / "proyecto/build/templates/web_release.manifiesto.json","paquete-03/web_release.manifiesto.json")
copiar(root / "evidencia-04/sonda-paquete.log","incidentes/sonda-paquete-03-con-retenciones.log")
copiar(root / "evidencia-04/control-pck-verbose-01","incidentes/control-pck-verbose-01")
copiar(control,"paquete-03/control-pck-limpio-02")
for nombre in ("sonda-paquete.log","dialogos-paquete.log","checkpoint-jornada-2.guardado"):
    copiar(control / nombre,"paquete-03/" + nombre)
for nombre in ("paquete431-sin-marco.gd","publicar-blobs-exactos.py","preparar-publicacion-final.py","control-pck-final.py"):
    copiar(root / nombre,"reproduccion/" + nombre)
for p in root.glob("*turno.log"):
    copiar(p,"turnos/" + p.name)
for p in root.parent.glob("capturas-431-*-revision-*.json"):
    copiar(p,"incidentes/" + p.name)
avisos = Counter(x["text"] for x in consola if x["type"] == "warning")
previos = json.loads((out / "incidentes/web-plantilla-anterior/consola.json").read_text(encoding="utf-8"))
avisos_previos = Counter(x["text"] for x in previos if x["type"] == "warning")
normalizar = lambda s: re.sub(r"\[\.WebGL-0x[0-9a-f]+\]","[.WebGL-HANDLE]",s)
audit = {"head":head,"web_definitiva":True,"intento":5,"snapshots":len(medidas),"consola_por_tipo":dict(Counter(x["type"] for x in consola)),
         "avisos_literales":dict(avisos),"base_web04_literales":dict(avisos_previos),
         "coincide_solo_sustituyendo_handle":Counter(normalizar(x["text"]) for x in consola if x["type"] == "warning") == Counter(normalizar(x["text"]) for x in previos if x["type"] == "warning"),
         "fixture":recorrido[0],"inspeccion_visual":"CHATS real debe revisarse antes de enviar comandos4–30; PNG finales revisados en ambas resoluciones.",
         "encuadre_inicial_rechazado":"web-1920-chats.png muestra mundo; validación visual real en web-1920-chats-validado.png antes de acciones6–32.",
         "limite":"Cada advertencia permanece literal en consola.json; no se atribuye su causa por igualdad numérica."}
(out / "web/auditoria.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding="utf-8")
manifest = json.loads((out / "manifiesto.json").read_text(encoding="utf-8"))
manifest.update({"web_definitiva":True,"exportacion":huellas,"web":audit,
                 "orquestador":{"head":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
                                  "rama":subprocess.check_output(["git","branch","--show-current"],text=True).strip(),
                                  "estado_porcelain":subprocess.check_output(["git","status","--porcelain"],text=True),
                                  "limite":"El orquestador trabaja22. Export431 se mide exclusivamente desde archivo Git de6d y copia externa."}})
manifest["archivos"] = {p.relative_to(out).as_posix():{"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
                         for p in sorted(out.rglob("*")) if p.is_file() and p.name not in ("manifiesto.json","manifiesto-local.json")}
(out / "manifiesto.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(audit,ensure_ascii=False,indent=2))

"""Assemble only own small proofs; no project/user-state copy and no engine invocation."""

import hashlib
import json
import shutil
import subprocess
from pathlib import Path

prep = Path(__file__).resolve().parent
out = prep / "evidencia-publica"
repo = Path.cwd().resolve()
shared = Path("C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309")
base = "41f30b0040aa843f45a89c7cee02fbfa08ad8929"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=repo).decode("utf-8").strip()


def copy(source, target):
    destination = out / target
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


out.mkdir(exist_ok=True)
for run in ("nativa-1", "nativa-2"):
    for source in (prep / run).iterdir():
        if source.is_file() and source.suffix in (".png", ".json", ".log"):
            copy(source, Path(run) / source.name)
for source in prep.glob("*.log"):
    copy(source, Path("focales") / source.name)
for source in prep.glob("*-results.xml"):
    copy(source, Path("focales") / source.name)
for source in (repo / "reports/309-focales").glob("report_*/results.xml"):
    copy(source, Path("focales/xml") / source.parent.name / source.name)
for name in ("focales_309.py", "full_y_conteo_309.py", "armar_evidencia.py", "resumen_full.py"):
    copy(prep / name, Path("protocolos") / name)
for name in ("avisos_popup.gd", "avisos_popup.py"):
    copy(prep / "nativa" / name, Path("protocolos/nativa-2") / name)
for name in ("preflight.json", "preflight-fuentes-309.json", "preflight-metodos-41f30b00.json", "preflight-provisional-41f30b00.md", "README.md"):
    copy(prep / name, Path("historico-preflight") / name)
for name in ("notificacion_cliente.svg", "notificacion_lectura.svg", "live_cliente.svg", "live_lectura.svg"):
    copy(prep / "assets" / name, Path("figma") / name)
asset_pairs = (("notificacion_cliente.svg", "live_cliente.svg", "243:150", "213:191", "https://www.figma.com/api/mcp/asset/8a0e9128-9d36-4b5b-b174-b8f129c85937/232cb.svg"),
               ("notificacion_lectura.svg", "live_lectura.svg", "477:243", "480:319", "https://www.figma.com/api/mcp/asset/17e0f09d-310c-4ab8-8e32-33e2c9382449/f4bf6.svg"))
assets = []
for runtime, original, frame, group, url in asset_pairs:
    data = (repo / "assets/ui/manada" / runtime).read_bytes()
    assert data == (prep / "assets" / original).read_bytes(), runtime
    assets.append({"runtime": "assets/ui/manada/" + runtime, "export_original": "figma/" + original,
                   "figma_file": "SQEAfczyRvyOHokmzPOee7", "frame": frame, "grupo": group, "url_export": url,
                   "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
head = git("rev-parse", "HEAD")
diff = git("diff", "--name-only", base, head).splitlines()
metadata = {"base_certificada": base, "head_full": head,
            "head_native_y_focales": "c315ccd5a4db47963c1df2d939f183b37728af84",
            "diferencia_desde_nativa": git("diff", "--stat", "c315ccd5", head),
            "assets_finales": assets, "rutas_cambiadas": diff,
            "hashes_fuentes_finales": {name: hashlib.sha256((repo / name).read_bytes()).hexdigest() for name in diff},
            "suites_propias": {"test/dominio/ambiente/notificaciones_test.gd": {"casos": 12, "publicos_incluyendo_hooks": 12},
                               "test/ui/pila_de_notificaciones_test.gd": {"casos": 6, "publicos_incluyendo_hooks": 7},
                               "test/escenas/notificaciones_en_el_almacen_test.gd": {"casos": 4, "publicos_incluyendo_hooks": 4}},
            "alcance": "Todas las rutas revisadas contra el cuerpo completo de issue309; sin cambios fuera del alcance."}
(out / "metadatos-finales.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
issue = subprocess.check_output(["gh", "issue", "view", "309", "--json", "number,title,body,url,updatedAt"], cwd=repo)
(out / "issue-309-final.json").write_bytes(issue)
for source in shared.glob("c-309*.log"):
    copy(source, Path("registros") / source.name)
reports = [p for p in (repo / "reports").glob("report_*/results.xml")]
full_log = shared / "c-309-full1.log"
full_finished = full_log.is_file() and "COUNT309_EXIT" in full_log.read_text(encoding="utf-8", errors="replace")
if reports and full_finished:
    latest = max(reports, key=lambda p: int(p.parent.name.removeprefix("report_")))
    copy(latest, "registros/full1-results.xml")
    metadata["xml_full_origen"] = latest.relative_to(repo).as_posix()
    (out / "metadatos-finales.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
manifest = []
for p in sorted(out.rglob("*")):
    if not p.is_file() or p.name == "manifest-sha256.json":
        continue
    original = p.read_bytes()
    blob = git("hash-object", "-w", str(p))
    published = subprocess.check_output(["git", "cat-file", "blob", blob], cwd=repo)
    manifest.append({"ruta": p.relative_to(out).as_posix(), "bytes": len(published),
                     "sha256": hashlib.sha256(published).hexdigest(),
                     "bytes_copia_original": len(original), "sha256_copia_original": hashlib.sha256(original).hexdigest(),
                     "nota": "bytes/sha256 del blob publicado; Git normaliza CRLF a LF en archivos de texto"})
(out / "manifest-sha256.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"head": head, "files": len(manifest), "assets": assets}, ensure_ascii=False))

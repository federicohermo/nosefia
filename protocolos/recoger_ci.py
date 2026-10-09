"""Preserve terminal CI logs/artifact XML outside every checkout; no engine invocation."""

import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

folder = Path(__file__).resolve().parent
run_id = "37906851144"
head = "fe620b92a38b556f27fff721d162c466c1e784fb"
run = json.loads(subprocess.check_output(["gh", "run", "view", run_id, "--json", "status,conclusion,headSha,jobs,url,createdAt,updatedAt"]))
assert run["status"] == "completed", "CI is still running"
assert run["headSha"] == head, "Unexpected CI source head"
output = folder / "evidencia-publica/ci" / run_id
output.mkdir(parents=True, exist_ok=True)
(output / "run.json").write_bytes((json.dumps(run, ensure_ascii=False, indent=2) + "\n").encode())
log = subprocess.check_output(["gh", "run", "view", run_id, "--log"])
(output / "verify.log").write_bytes(log)
artifacts = json.loads(subprocess.check_output(["gh", "api", "repos/federicohermo/nosefia/actions/runs/" + run_id + "/artifacts"]))
(output / "artifacts.json").write_bytes((json.dumps(artifacts, ensure_ascii=False, indent=2) + "\n").encode())
download = folder / ("ci-" + run_id + "-artefactos")
if not download.exists():
    subprocess.run(["gh", "run", "download", run_id, "--name", "reports-gdunit4", "--dir", str(download)], check=True)
reports = list(download.rglob("results.xml"))
assert len(reports) == 1, "Inspect artifact layout; expected the clean CI run's single report"
data = reports[0].read_bytes()
(output / "results.xml").write_bytes(data)
xml = ET.fromstring(data)
suites = list(xml.iter("testsuite"))
stats = {"suites": len(suites), "casos": len(list(xml.iter("testcase")))}
for field in ("failures", "errors", "skipped", "flaky"):
    stats[field] = sum(int(s.attrib.get(field, 0)) for s in suites)
summary = {"run": run_id, "head": head, "conclusion": run["conclusion"], "url": run["url"],
           "stats": stats, "xml_sha256": hashlib.sha256(data).hexdigest(),
           "nota": "CI Linux independiente: XML y salida de verificar; el workflow no conserva RAW completo del motor si tests pasa. No se afirma RAW limpio."}
gate = re.findall(r"7/7 nodos en verde, en ([0-9.,]+)s\.", log.decode("utf-8", errors="replace"))
summary["verificar_segundos"] = gate
(output / "resumen.json").write_bytes((json.dumps(summary, ensure_ascii=False, indent=2) + "\n").encode())
print(json.dumps(summary, ensure_ascii=False))
assert run["conclusion"] == "success", "Inspect failed CI before claiming completion"
assert len(gate) == 1, "Inspect actual CI gate summary before claiming seven green nodes"
assert stats == {"suites": 207, "casos": 1632, "failures": 0, "errors": 0, "skipped": 0, "flaky": 0}

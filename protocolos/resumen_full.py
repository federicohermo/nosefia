"""Read finished FULL1 proofs and compare diagnostic categories with certified A304."""

import collections
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

prep = Path(__file__).resolve().parent
out = prep / "evidencia-publica"
shared = Path("C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309")
base_evidence = "ba1af9dfad0c9d5eb17e8cec9e1b6bd071360ae6"
full = (shared / "c-309-full1.log").read_text(encoding="utf-8", errors="replace")
assert "COUNT309_EXIT" in full, "The run has not completed; do not summarize partial output"
raw_path = shared / "c-309-tests-crudo-full1.log"
raw = raw_path.read_text(encoding="utf-8", errors="replace")
clean = re.sub(r"\x1b\[[0-9;]*m", "", raw)
lines = clean.splitlines()
base = json.loads(subprocess.check_output(["git", "show", base_evidence + ":evidencia/a-304-full-raw-diagnosticos.json"]))
base_raw_bytes = subprocess.check_output(["git", "show", base_evidence + ":evidencia/a-304-full-primera-godot-crudo.log"])
base_raw = re.sub(r"\x1b\[[0-9;]*m", "", base_raw_bytes.decode("utf-8", errors="replace"))


def category(line):
    line = re.sub(r"guardado_de_los_tests_\d+", "guardado_de_los_tests_PID", line)
    if line.startswith("ERROR: Delete reports/"):
        return "ERROR: Delete reports/report_N/... failed (relative cleanup inherited)"
    if line.startswith("WARNING: Rescate:"):
        return "WARNING: Rescate (red_de_seguridad; identifiers and coordinates vary)"
    return line.strip()


base_lines = [line.strip() for line in base_raw.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:", "WARNING:"))]
base_counts = collections.Counter(map(category, base_lines))
diagnostics = [(i, line.strip()) for i, line in enumerate(lines)
               if line.startswith(("ERROR:", "SCRIPT ERROR:", "WARNING:"))]
counts = collections.Counter(category(line) for _, line in diagnostics)
first = {}
for i, line in diagnostics:
    key = category(line)
    if key not in first:
        first[key] = {"linea": i + 1, "contexto": lines[max(0, i - 2):min(len(lines), i + 14)]}
report = max(Path("reports").glob("report_*/results.xml"), key=lambda p: int(p.parent.name[7:]))
xml_bytes = report.read_bytes()
xml = ET.fromstring(xml_bytes)
suites = list(xml.iter("testsuite"))
stats = {"suites": len(suites), "casos": len(list(xml.iter("testcase")))}
for field in ("failures", "errors", "skipped", "flaky"):
    stats[field] = sum(int(s.attrib.get(field, 0)) for s in suites)
summary = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip(),
           "full_ordinal": 1, "xml": str(report), "xml_sha256": hashlib.sha256(xml_bytes).hexdigest(),
           "stats": stats, "full_exit": re.findall(r"FULL309_EXIT (\d+)", full),
           "count_exit": re.findall(r"COUNT309_EXIT (\d+)", full),
           "base_evidence_commit": base_evidence,
           "base_raw_sha256": hashlib.sha256(base_raw_bytes).hexdigest(),
           "base_raw_url": "https://raw.githubusercontent.com/federicohermo/nosefia/" + base_evidence + "/evidencia/a-304-full-primera-godot-crudo.log",
           "base_diagnostic_url": "https://raw.githubusercontent.com/federicohermo/nosefia/" + base_evidence + "/evidencia/a-304-full-raw-diagnosticos.json",
           "categorias": [{"diagnostico": key, "conteo_309": count, "conteo_base304": base_counts[key],
                           "presente_en_base304": key in base_counts, "primer_contexto": first[key]}
                          for key, count in sorted(counts.items())],
           "categorias_nuevas": sorted(set(counts) - set(base_counts)),
           "nota": "Heredado significa observado en la cabeza base certificada, no correcto ni salida limpia. HARN/fixtures fixes independientes no se duplican."}
(out / "full1-resumen-y-diagnosticos.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(out / "base304-diagnosticos.json").write_text(json.dumps(base, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"head": summary["head"], "stats": stats, "xml_sha256": summary["xml_sha256"],
                  "categorias_nuevas": summary["categorias_nuevas"],
                  "conteos": [{"tipo": d["diagnostico"], "309": d["conteo_309"], "base304": d["conteo_base304"]} for d in summary["categorias"]]}, ensure_ascii=False, indent=2))

"""Convergencia original y conteo inmediato sobre la cabeza final, dentro de un turno FIFO."""
import hashlib
import json
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
head, output = sys.argv[1:]
out = Path(output).resolve()
scratch = Path(__file__).parent


def git(*args):
    return subprocess.check_output(["git", *args]).decode("utf-8").strip()


assert git("rev-parse", "HEAD") == head, "Wrong integration HEAD"
assert not git("status", "--porcelain", "--untracked-files=no"), "Tracked tree is dirty"
parents = git("show", "-s", "--format=%P", head).split()
assert len(parents) == 2 and parents[1] == "cd9947317ae5489e61b39b795795e059fc4e8f1c", "Unexpected integration parents"
tree = git("rev-parse", head + "^{tree}")
diff_parent1 = git("diff", "--name-only", parents[0], head).splitlines()
assert not out.exists(), "Choose a new evidence directory"
out.mkdir(parents=True)
verify = subprocess.run(
    [sys.executable, str(scratch / "padre-verificar-con-log.py"), str(out / "tests-crudo.log")],
    capture_output=True, encoding="utf-8", errors="replace",
)
# No other engine or focal suite may run between these two commands.
count = subprocess.run(
    [sys.executable, ".claude/skills/implement-batch/scripts/conteo.py"],
    capture_output=True, encoding="utf-8", errors="replace",
)
for name, result in (("verificar", verify), ("conteo", count)):
    log = result.stdout + result.stderr
    (out / f"{name}.log").write_text(log, encoding="utf-8")
    print(log, end="", flush=True)
reports = [p for p in Path("reports").glob("report_*") if (p / "results.xml").is_file()]
report = max(reports, key=lambda p: int(p.name.removeprefix("report_")))
xml = out / "results.xml"
shutil.copy2(report / "results.xml", xml)
root = ET.parse(xml).getroot()
suites = list(root.iter("testsuite"))
committed = git("ls-tree", "-r", "--name-only", head, "--", "test").splitlines()
expected_suites = sum(path.endswith("_test.gd") for path in committed)
summary = re.findall(r"7/7 nodos en verde, en ([0-9.]+)s\.", verify.stdout + verify.stderr)
counts = {k: sum(int(s.attrib.get(k, "0")) for s in suites)
          for k in ("tests", "failures", "errors", "skipped", "flaky")}
record = {"head": head, "parents": parents, "tree": tree, "diff_parent1": diff_parent1,
          "verify_exit": verify.returncode, "count_exit": count.returncode,
          "report": str(report), "suites": len(suites), "files": len(list(Path("test").rglob("*_test.gd"))),
          "committed_suite_files": expected_suites, "seven_node_summaries": summary,
          **counts, "xml_sha256": hashlib.sha256(xml.read_bytes()).hexdigest()}
(out / "manifest.json").write_text(json.dumps(record, indent=2)+"\n", encoding="utf-8")
assert git("rev-parse", "HEAD") == head, "Integration HEAD changed while running"
assert not git("status", "--porcelain", "--untracked-files=no"), "Tracked tree changed while running"
assert len(summary) == 1, "Missing or ambiguous seven-node convergence"
assert len(suites) == expected_suites == record["files"], record
assert counts["tests"] == sum(1 for _ in root.iter("testcase")), record
assert all(counts[k] == 0 for k in ("failures", "errors", "skipped", "flaky")), record
print(json.dumps(record), flush=True)
raise SystemExit(verify.returncode or count.returncode)

"""Convergence and immediate count inside a single FIFO turn; preserve raw output."""

import subprocess
import sys
from pathlib import Path

root = Path.cwd().resolve()
shared = Path("C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309")
attempt = sys.argv[1]
if not attempt.isdigit():
    raise SystemExit("Provide the honest full-run ordinal")
raw = shared / f"c-309-tests-crudo-full{attempt}.log"
wrapper = shared / "padre-verificar-con-log.py"
result = subprocess.run([sys.executable, str(wrapper), str(raw)], cwd=root)
print(f"FULL309_EXIT {result.returncode}", flush=True)
count = subprocess.run([sys.executable, ".claude/skills/implement-batch/scripts/conteo.py"], cwd=root)
print(f"COUNT309_EXIT {count.returncode}", flush=True)
raise SystemExit(result.returncode or count.returncode)

"""Contrasta mensajes, posiciones y causas; conserva ambos crudos completos."""
from collections import Counter
import json
from pathlib import Path
import re
import sys

p = Path(__file__).parent
actual_dir = Path(sys.argv[1])
destino = Path(sys.argv[2])
base_path = Path(sys.argv[3]) if len(sys.argv) > 3 else p/'base/tests.log'
ansi = re.compile(r'\x1b\[[0-9;]*[A-Za-z]')
tag = re.compile(r'^\s*(?:ERROR|WARNING|SCRIPT ERROR|Parse Error):')


def leer(path):
    raw = ansi.sub('', path.read_text(encoding='utf-8', errors='replace'))
    lines = raw.splitlines()
    indices = [i for i, line in enumerate(lines) if tag.match(line)]
    result = []
    for ordinal, i in enumerate(indices):
        end = min(indices[ordinal+1] if ordinal+1 < len(indices) else len(lines), i+17)
        context = lines[i+1:end]
        test = next((line.strip() for line in context if re.match(r'\s*\[\d+\].*res://test/', line)), '')
        cause = test or next((line.strip() for line in context if line.strip().startswith('at:')), '')
        cause = re.sub(r'^\[\d+\]\s*', '', cause)
        cause = re.sub(r':\d+\)', ':LINEA)', cause)
        message = lines[i].strip()
        normalized = message
        if message.startswith('WARNING: Rescate:'):
            normalized = re.sub(r'@([A-Za-z0-9_]+)@\d+', r'@\1@ID', normalized)
            def punto(match):
                return ' en (' + ', '.join(str(round(float(v.strip()), 3)) for v in match.group(1).split(',')) + ')'
            normalized = re.sub(r' en \(([-+0-9.eE, ]+)\)', punto, normalized)
        result.append({'linea': i+1, 'raw': message, 'normalizado': normalized,
                       'causa': cause, 'contexto': context})
    return raw, result


base_raw, base = leer(base_path)
current_raw, current = leer(actual_dir/'tests.log')
before = Counter((item['normalizado'], item['causa']) for item in base)
after = Counter((item['normalizado'], item['causa']) for item in current)
added = [{'diagnostico': k[0], 'causa': k[1], 'cantidad': v} for k, v in (after-before).items()]
removed = [{'diagnostico': k[0], 'causa': k[1], 'cantidad': v} for k, v in (before-after).items()]
bad = {}
for file in sorted(actual_dir.glob('*.log')):
    raw = file.read_text(encoding='utf-8', errors='replace')
    matches = re.findall(r'.*(?:SCRIPT ERROR|Parse Error|leaked at exit|resources still in use|Pages in use exist at exit).*', raw, flags=re.I)
    if matches:
        bad[file.name] = matches
report = {'base_path': str(base_path), 'actual_path': str(actual_dir/'tests.log'),
          'base': len(base), 'actual': len(current),
          'normalizacion': 'Solo Rescate: IDs efimeros y coordenadas redondeadas a milimetros; causas conservan funcion/archivo y normalizan linea e indice del stack.',
          'nuevos': added, 'ausentes': removed, 'aborto_o_fugas': bad,
          'detalle_base': base, 'detalle_actual': current,
          'sumario': re.findall(r'(?:Executed test suites:|Executed test cases :|Total execution time:|Exit code:).*', current_raw)}
destino.write_bytes(json.dumps(report, ensure_ascii=False, indent=2).encode('utf-8'))
print(json.dumps({k: report[k] for k in ['base', 'actual', 'nuevos', 'ausentes', 'aborto_o_fugas', 'sumario']}, ensure_ascii=True, indent=2))
raise SystemExit(1 if added or removed or bad else 0)

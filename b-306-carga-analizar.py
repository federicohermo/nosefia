from pathlib import Path
import json, re, math, hashlib

out = Path(__file__).parent
raw = (out / 'b-306-carga1-carga-raw.log').read_text(encoding='utf-8')
rows = [json.loads(line.split('B306CARGA ', 1)[1]) for line in raw.splitlines() if 'B306CARGA {' in line]
def vector(value):
    return [float(v) for v in value.strip('()').split(',')]
shifted = []
for row in rows:
    if row['etapa'] == 'soltado':
        distance = math.dist(vector(row['previsto']), vector(row['real']))
        shifted.append({'indice': row['indice'], 'id': row['id'], 'distance_from_requested': distance, 'requested': row['previsto'], 'actual': row['real'], 'relative': row['relativo'], 'upright': row['derecho'], 'ray': row['mira']})
proof = {'diagnostico_no_final': True, 'count': re.findall(r'B306CARGA_TOTAL\s+(\d+)', raw), 'rows': rows, 'after_release': shifted, 'raw_sha256': hashlib.sha256((out / 'b-306-carga1-carga-raw.log').read_bytes()).hexdigest()}
(out / 'b-306-carga-analisis.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
print(json.dumps({'count': proof['count'], 'after_release': shifted}, indent=2))

"""Audita los bytes conservados y distingue idempotencia de exportación UV conocida."""
import hashlib
import json
from pathlib import Path
import subprocess

p = Path(__file__).parent
base = p / '434-recursos-escala-local01'
manifiestos = []
for pasada in ('primera', 'segunda'):
    carpeta = base / pasada
    manifest = json.loads((carpeta / 'manifest.json').read_bytes())
    assert len(manifest) == 40
    for ruta, entrada in manifest.items():
        data = (carpeta / ruta).read_bytes()
        assert len(data) == entrada['bytes']
        assert hashlib.sha256(data).hexdigest() == entrada['sha256'], ruta
    manifiestos.append(manifest)
estrictos = [ruta for ruta in manifiestos[0] if ruta.endswith(('.res', '.tscn', '.tres'))]
assert len(estrictos) == 36
for ruta in estrictos:
    assert (base / 'primera' / ruta).read_bytes() == (base / 'segunda' / ruta).read_bytes(), ruta
exportador_base = subprocess.check_output(['git', 'show', '0989ef277e615dc021cdbdf3320ea6c11b727d28:.claude/scripts/blender/exportar.py']).decode('utf-8')
assert 'difieren en el último bit de algunas UV' in exportador_base
delta = json.loads((p / '434-idempotencia/cierre-escala-local01/deltas-glb.json').read_bytes())
assert delta['nodes'] == 255 and not delta['nodes_changed']
assert delta['meshes'] == 222 and delta['materials_identical'] and delta['images_identical']
assert all(c['attribute'].startswith('TEXCOORD_') for m in delta['mesh_attributes_changed'] for c in m['changes'])
informe = {
    'fuente_codigo': '8f0927394645882937e5b59cdec16da8f69af629',
    'capturas_completas': 2, 'archivos_por_captura': 40,
    'blobs_locales_y_hashes_verificados': 80,
    'textos_y_res_bytes_identicos': 36,
    'glb_bytes_identicos': False,
    'clasificacion': 'Sólo UV del exportador, variación ya documentada en la base0989; no nueva tolerancia ni redondeo.',
    'nodos_transformaciones_identicos': 255,
    'mallas_indices_position_normal_identicos': 222,
    'materiales_e_imagenes_identicos': True,
    'limite': 'Se conserva exit1 del pipeline. No se afirma igualdad de todos los binarios: blend, huella, GLB y unwrap se preservan por separado. Los cuarenta outputs de ambas pasadas sí existen.',
    'siguiente': 'Pruebas funcionales y recorrido real; esta auditoría no prueba alcance ni interacción.'
}
(base / 'revision-root.json').write_bytes(json.dumps(informe, ensure_ascii=False, indent=2).encode('utf-8'))
print(json.dumps(informe, ensure_ascii=True, indent=2))

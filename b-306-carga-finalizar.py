from pathlib import Path
import json, hashlib, difflib, subprocess

out = Path(__file__).parent
proof = json.loads((out / 'b-306-carga-manifest.json').read_text())
item = proof['suites'][0]
p = Path(item['copy']); t = p.read_text(encoding='utf-8')
t = t.replace('var ojo: Transform3D = jugador.call', 'var forma: CollisionShape3D = unidad.get_node("Forma")\n\tvar ojo: Transform3D = jugador.call')
t = t.replace('"derecho": unidad.datos.se_apoya_derecho,', '"forma": forma.shape.get_class(), "limites_forma": str(forma.shape.get_debug_mesh().get_aabb()), "basis": str(unidad.global_basis), "layer": unidad.collision_layer, "mask": unidad.collision_mask, "velocity": str(unidad.linear_velocity), "angular_velocity": str(unidad.angular_velocity), "derecho": unidad.datos.se_apoya_derecho,')
p.write_text(t, encoding='utf-8')
subprocess.run(['gdformat', str(p)], check=True)
t = p.read_text(encoding='utf-8')
item['copy_sha256'] = hashlib.sha256(p.read_bytes()).hexdigest()
(out / 'b-306-carga-manifest.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
original = Path(item['original']).read_text(encoding='utf-8')
(out / 'b-306-carga.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True), t.splitlines(True), fromfile='test/escenas/puestos/contenedor_de_basura_test.gd', tofile='res://.godot/b306-diagnostico/carga_test.gd')), encoding='utf-8')
runner = Path('C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309/b-306-trazas-correr.py').read_text(encoding='utf-8')
runner = runner.replace('b-306-trazas-manifest.json', 'b-306-carga-manifest.json').replace('b-306-trazas-', 'b-306-carga1-')
(out / 'b-306-carga-correr.py').write_text(runner, encoding='utf-8')
print(json.dumps(proof, indent=2))

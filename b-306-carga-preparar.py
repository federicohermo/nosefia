from pathlib import Path
import hashlib, re, json, subprocess, difflib

root = Path.cwd(); out = Path(__file__).parent
source = root / 'test/escenas/puestos/contenedor_de_basura_test.gd'
original = source.read_text(encoding='utf-8'); text = original
case = 'test_llenarlo_con_productos_no_los_comprime_a_traves_del_cuerpo_o_la_tapa'
old = '\t\tvar unidad := agarre.soltar(true) as ObjetoAgarrable\n'
assert text.count(old) == 1
text = text.replace(old, '\t\tvar previsto := agarre.punto_de_soltado.global_position\n' + old + '\t\tif unidad != null:\n\t\t\t_b306_carga(jugador, unidad, centro, previsto, indice, "soltado")\n')
old = '\tvar dentro := 0\n'
assert text.count(old) == 1
text = text.replace(old, '\tfor indice: int in unidades.size():\n\t\t_b306_carga(jugador, unidades[indice], centro, Vector3.ZERO, indice, "estable")\n' + old)
text = text.replace('\tassert_int(dentro).override_failure_message("la carga no llegó al tacho").is_greater(6)', '\tprint("B306CARGA_TOTAL ", dentro)\n\tassert_int(dentro).override_failure_message("la carga no llegó al tacho").is_greater(6)')
text += '''

func _b306_carga(jugador: CharacterBody3D, unidad: ObjetoAgarrable, centro: Vector3, previsto: Vector3, indice: int, etapa: String) -> void:
	var ojo: Transform3D = jugador.call("mira")
	var rayo := PhysicsRayQueryParameters3D.create(ojo.origin, ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA)
	rayo.exclude = [jugador.get_rid(), unidad.get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(rayo)
	var mira: Dictionary = {}
	if not golpe.is_empty():
		mira = {"collider": str(golpe.collider.get_path()), "position": str(golpe.position), "normal": str(golpe.normal)}
	print("B306CARGA ", JSON.stringify({"indice": indice, "etapa": etapa, "id": str(unidad.datos.id), "previsto": str(previsto), "real": str(unidad.global_position), "relativo": str(unidad.global_position - centro), "jugador": str(jugador.global_position), "ojo": str(ojo.origin), "derecho": unidad.datos.se_apoya_derecho, "mira": mira}))
'''
dest = root / '.godot/b306-diagnostico/carga_test.gd'
assert not dest.exists(); dest.write_text(text, encoding='utf-8')
actual = dest.relative_to(root).as_posix()
args = ['-a', 'res://' + actual]
for excluded in re.findall(r'^func (test_\w+)\(', original, re.M):
    if excluded != case:
        args += ['-i', actual + ':' + excluded]
proof = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'tracked_diff_sha256': hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary'])).hexdigest(), 'diagnostico_no_final': True, 'timing_perturbado_por_prints': True, 'suites': [{'label': 'carga', 'original': str(source), 'original_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'copy': str(dest), 'copy_sha256': hashlib.sha256(dest.read_bytes()).hexdigest(), 'case': case, 'args': args}]}
(out / 'b-306-carga-manifest.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
(out / 'b-306-carga.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True), text.splitlines(True), fromfile=source.relative_to(root).as_posix(), tofile=actual)), encoding='utf-8')
print(json.dumps(proof, indent=2))

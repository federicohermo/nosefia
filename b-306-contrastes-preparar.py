from pathlib import Path
import hashlib, json, subprocess, difflib

root = Path.cwd(); scratch = Path(__file__).parent
original_proof = json.loads((scratch / 'b-306-trazas-manifest.json').read_text())
proof = dict(original_proof, suites=[])
for mode in ['sin_soporte', 'premisa_valida']:
    for original in original_proof['suites']:
        label = original['label']
        if mode == 'premisa_valida' and label == 'soltado':
            continue
        source = Path(original['copy'])
        text = source.read_text(encoding='utf-8'); before = text
        if mode == 'sin_soporte':
            text = text.replace('\tadd_child(almacen)\n', '\tadd_child(almacen)\n\t_b306_sin_soporte(almacen)\n')
            text += '''

func _b306_sin_soporte(almacen: Node3D) -> void:
	var cuerpos := almacen.get_node("Exterior").find_children("*", "StaticBody3D", true, false)
	assert_int(cuerpos.size()).is_equal(6)
	for cuerpo: StaticBody3D in cuerpos:
		cuerpo.collision_layer = 0
	print("B306SINSOPORTE cuerpos_desactivados=", cuerpos.size())
'''
        elif label == 'notas':
            old = 'if apoyo.name != "SueloSolido" and dueno.name != "VolumenDelPisoDelBano":'
            assert text.count(old) == 1
            text = text.replace(old, 'if not ReglasDeLosObjetos.se_puede_apoyar_en(golpe.normal.y):')
        else:
            old = '''		jugador.global_position = (
			mancha.global_position + desde.normalized() * PARADO_DEL_CHARCO + Vector3.UP * 0.112
		)
		await get_tree().physics_frame
'''
            assert text.count(old) == 1
            text = text.replace(old, '''		var local: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
		var limites_del_piso := local.global_transform * local.shape.get_debug_mesh().get_aabb()
		var parada := mancha.global_position + desde.normalized() * PARADO_DEL_CHARCO
		parada.y = limites_del_piso.end.y + 0.02
		jugador.velocity = Vector3.ZERO
		await _parar_al_jugador_en(jugador, parada)
		var espacio := almacen.get_world_3d().direct_space_state
		var consulta := PhysicsRayQueryParameters3D.create(jugador.global_position + Vector3.UP * 0.05, jugador.global_position + Vector3.DOWN * 0.15)
		consulta.exclude = [jugador.get_rid(), (caja as CollisionObject3D).get_rid()]
		var apoyo := espacio.intersect_ray(consulta)
		print("B306PREMISA suelo=", JSON.stringify(_b306_golpe(apoyo)), " jugador=", jugador.global_position)
		assert_bool(apoyo.is_empty()).is_false()
		if apoyo.is_empty():
			return
		assert_bool(ReglasDeLosObjetos.se_puede_apoyar_en(apoyo.normal.y)).is_true()
		var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
		var capsula := PhysicsShapeQueryParameters3D.new()
		capsula.shape = cuerpo.shape
		capsula.transform = cuerpo.global_transform
		capsula.collision_mask = jugador.collision_mask
		capsula.exclude = [jugador.get_rid(), (caja as CollisionObject3D).get_rid()]
		capsula.margin = 0.0
		assert_array(espacio.intersect_shape(capsula)).is_empty()
''')
        combined = mode + '_' + label
        dest = source.parent / (combined + '_test.gd')
        dest.write_text(text, encoding='utf-8')
        rel = dest.relative_to(root).as_posix()
        args = [arg.replace('.godot/b306-diagnostico/' + label + '_test.gd', rel) for arg in original['args']]
        proof['suites'].append(dict(original, label=combined, copy=str(dest), copy_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(), args=args))
        (scratch / ('b-306-contrastes-' + combined + '.diff')).write_text(''.join(difflib.unified_diff(before.splitlines(True), text.splitlines(True))), encoding='utf-8')
proof['tracked_diff_sha256'] = hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary'])).hexdigest()
(scratch / 'b-306-contrastes-manifest.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
runner = (scratch / 'b-306-trazas-correr.py').read_text()
runner = runner.replace('b-306-trazas-manifest.json', 'b-306-contrastes-manifest.json').replace("label = 'b-306-trazas-'", "label = 'b-306-contrastes-'").replace('b-306-trazas-resultados.json', 'b-306-contrastes-resultados.json')
(scratch / 'b-306-contrastes-correr.py').write_text(runner, encoding='utf-8')
print('Preparadas cinco variantes de diagnóstico; ningún archivo tracked modificado.')

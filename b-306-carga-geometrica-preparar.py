from pathlib import Path
import re, json, hashlib, subprocess

root = Path.cwd()
out = Path(__file__).parent
source = root / 'test/escenas/puestos/contenedor_de_basura_test.gd'
text = source.read_text(encoding='utf-8')
text = text.replace('var unidades: Array[ObjetoAgarrable] = []', 'var unidades: Array[ObjetoAgarrable] = []\n\tvar boca := _boca_interior(almacen, contenedor)\n\tvar tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)\n\tassert_bool(tapa.recibe_objetos()).is_true()\n\tassert_float(tapa.get("_tapa").angulo()).is_equal_approx(TapaDelContenedor.ANGULO_ABIERTA, 0.00001)')
text = text.replace('_dejar_caer_en_la_boca(almacen, contenedor, unidad, unidades, indice)', '_dejar_caer_en_la_boca(almacen, contenedor, unidad, unidades, boca, indice)')
text = text.replace('\tvar tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)\n\ttapa.usar()\n\tfor cuadro in 120:', '\ttapa.usar()\n\tfor cuadro in 120:')
text = text[:text.index('func _dejar_caer_en_la_boca(')] + '''func _boca_interior(almacen: Node3D, contenedor: StaticBody3D) -> AABB:
	var malla := contenedor.get_parent() as MeshInstance3D
	var borde: AABB = malla.global_transform * malla.get_aabb()
	var centro := Vector3(contenedor.global_position.x, borde.get_center().y, contenedor.global_position.z)
	var limites: Array[Vector3] = []
	for direccion: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var golpe := _rayo(almacen, centro, centro + direccion * borde.size.length())
		assert_object(golpe.get("collider")).is_same(contenedor)
		limites.append(golpe.position)
	var minimo := Vector3(limites[0].x, borde.position.y, limites[2].z)
	var maximo := Vector3(limites[1].x, borde.end.y, limites[3].z)
	return AABB(minimo, maximo - minimo)


func _dejar_caer_en_la_boca(
	almacen: Node3D,
	contenedor: StaticBody3D,
	unidad: ObjetoAgarrable,
	cargadas: Array[ObjetoAgarrable],
	boca: AABB,
	indice: int
) -> void:
	var tapa: TapaDelLocal = almacen.get_node(RUTA_DE_LA_TAPA)
	var limites_tapa: AABB = tapa.forma.global_transform * tapa.forma.shape.get_debug_mesh().get_aabb()
	var apoyo := boca.end.y
	for anterior: ObjetoAgarrable in cargadas:
		apoyo = maxf(apoyo, _limites_fisicos(anterior).end.y)
	var limites := _limites_fisicos(unidad)
	var base := limites.position - unidad.global_position
	var fin := limites.end - unidad.global_position
	var desde := boca.position - base + Vector3.ONE * ReglasDeLosObjetos.ROCE
	var hasta := boca.end - fin - Vector3.ONE * ReglasDeLosObjetos.ROCE
	var altura := maxf(apoyo, limites_tapa.end.y) - base.y + ReglasDeLosObjetos.ROCE
	var forma: CollisionShape3D = unidad.get_node("Forma")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.collision_mask = unidad.collision_mask
	consulta.exclude = [unidad.get_rid()]
	var espacio := almacen.get_world_3d().direct_space_state
	var encontrada := false
	# Recorre primero el centro y alterna dentro de la boca erosionada por la forma real.
	for fraccion_z: float in [0.5, 0.75, 1.0, 0.25, 0.0]:
		for fraccion_x: float in [0.5, 0.25, 0.75, 0.0, 1.0]:
			var destino := Vector3(lerpf(desde.x, hasta.x, fraccion_x), altura, lerpf(desde.z, hasta.z, fraccion_z))
			consulta.transform = forma.global_transform
			consulta.transform.origin += destino - unidad.global_position
			consulta.motion = Vector3.ZERO
			if not espacio.intersect_shape(consulta, 32).is_empty():
				continue
			consulta.motion = Vector3.DOWN * maxf(0.0, altura + base.y - apoyo - ReglasDeLosObjetos.ROCE)
			var recorrido := espacio.cast_motion(consulta)
			if recorrido[0] < 1.0:
				continue
			unidad.global_position = destino
			encontrada = true
			break
		if encontrada:
			break
	assert_bool(encontrada).override_failure_message("no hay caída libre por la boca para esta forma").is_true()
	assert_float(hasta.x - desde.x).is_greater(0.0)
	assert_float(hasta.z - desde.z).is_greater(0.0)
	unidad.linear_velocity = Vector3.ZERO
	unidad.angular_velocity = Vector3.ZERO
	unidad.reset_physics_interpolation()
	consulta.transform = forma.global_transform
	consulta.motion = Vector3.ZERO
	assert_array(espacio.intersect_shape(consulta, 32)).is_empty()
	assert_bool(unidad.freeze).is_false()
	assert_float(unidad.gravity_scale).is_greater(0.0)
	assert_int(unidad.collision_layer).is_not_equal(0)
	assert_int(unidad.collision_mask).is_not_equal(0)
'''
(out / 'b-306-contenedor-geometrico-propuesta.gd').write_text(text, encoding='utf-8')
copy = root / '.godot/b306-diagnostico/carga_geometrica_test.gd'
copy.write_text(text.replace('\tunidad.linear_velocity = Vector3.ZERO\n', '\tprint("CARGA_GEOMETRICA ", JSON.stringify({"indice": indice, "boca": str(boca), "posicion": str(unidad.global_position), "tapa": str(limites_tapa), "libre": encontrada, "apoyo": apoyo}))\n\tunidad.linear_velocity = Vector3.ZERO\n'), encoding='utf-8')
subprocess.run(['gdformat', str(copy), str(out / 'b-306-contenedor-geometrico-propuesta.gd')], check=True)
case = 'test_llenarlo_con_productos_no_los_comprime_a_traves_del_cuerpo_o_la_tapa'
args = ['-a', str(copy.relative_to(root)).replace('\\', '/')]
for other in re.findall(r'^func (test_\w+)\(', text, re.M):
    if other != case:
        args += ['-i', str(copy.relative_to(root)).replace('\\', '/') + ':' + other]
proof = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'tracked_diff_sha256': hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary'])).hexdigest(), 'suites': [{'label': 'carga', 'copy': str(copy), 'copy_sha256': hashlib.sha256(copy.read_bytes()).hexdigest(), 'case': case, 'args': args}]}
(out / 'b-306-carga-geometrica-manifest.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
runner = (out / 'b-306-carga-correr.py').read_text(encoding='utf-8').replace('b-306-carga-manifest.json', 'b-306-carga-geometrica-manifest.json').replace('b-306-carga1-', 'b-306-carga-geometrica1-')
(out / 'b-306-carga-geometrica-correr.py').write_text(runner, encoding='utf-8')

from pathlib import Path
import hashlib, difflib, json

root = Path.cwd(); out = Path(__file__).parent
source = root / 'test/escenas/puestos/contenedor_de_basura_test.gd'
original = source.read_text(encoding='utf-8')
old = '\t\tif unidad != null:\n\t\t\tunidades.append(unidad)\n'
assert original.count(old) == 1
text = original.replace(old, '\t\tif unidad != null:\n\t\t\t_dejar_caer_en_la_boca(almacen, contenedor, unidad, unidades, indice)\n\t\t\tunidades.append(unidad)\n')
text += '''

func _limites_fisicos(unidad: ObjetoAgarrable) -> AABB:
	var forma: CollisionShape3D = unidad.get_node("Forma")
	return forma.global_transform * forma.shape.get_debug_mesh().get_aabb()


func _dejar_caer_en_la_boca(
	almacen: Node3D,
	contenedor: StaticBody3D,
	unidad: ObjetoAgarrable,
	cargadas: Array[ObjetoAgarrable],
	indice: int
) -> void:
	var malla := contenedor.get_parent() as MeshInstance3D
	assert_object(malla).is_not_null()
	var borde: AABB = malla.global_transform * malla.get_aabb()
	var alto := borde.end.y
	for anterior: ObjetoAgarrable in cargadas:
		alto = maxf(alto, _limites_fisicos(anterior).end.y)
	var base := _limites_fisicos(unidad).position.y - unidad.global_position.y
	# Cargar por arriba prueba la contención; la mira del jugador apunta al borde delantero
	# y el gesto normal puede recolocar el cuerpo, aunque se mueva su marcador de soltado.
	unidad.global_position = contenedor.global_position + Vector3(
		(indice % 3 - 1) * 0.07,
		alto - base + ReglasDeLosObjetos.ROCE - contenedor.global_position.y,
		(indice % 2 - 0.5) * 0.07
	)
	unidad.linear_velocity = Vector3.ZERO
	unidad.angular_velocity = Vector3.ZERO
	unidad.reset_physics_interpolation()
	var forma: CollisionShape3D = unidad.get_node("Forma")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.collision_mask = unidad.collision_mask
	consulta.exclude = [unidad.get_rid()]
	assert_array(almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 32)).is_empty()
	assert_bool(unidad.freeze).is_false()
	assert_int(unidad.collision_layer).is_not_equal(0)
	assert_int(unidad.collision_mask).is_not_equal(0)
'''
p = out / 'b-306-contenedor-propuesta.gd'
p.write_text(text, encoding='utf-8')
(out / 'b-306-contenedor-propuesta.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True), text.splitlines(True), fromfile='a/test/escenas/puestos/contenedor_de_basura_test.gd', tofile='b/test/escenas/puestos/contenedor_de_basura_test.gd')), encoding='utf-8', newline='\n')
print(json.dumps({'original_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'proposal': str(p)}))

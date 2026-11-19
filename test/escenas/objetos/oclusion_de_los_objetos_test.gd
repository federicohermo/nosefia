## Todo lo que se levanta y se apoya deja su mancha donde queda, y nada que se levante se queda sin
## el efecto. El efecto en sí lo cubre `oclusion_de_contacto_test.gd`.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Oclusion := preload("res://src/escenas/objetos/oclusion_de_contacto.gd")
const UTILES := preload("res://src/escenas/puestos/objetos_del_almacen.tscn")

## Cada escena de lo que se levanta y no vive cableado en el almacén.
const ESCENAS := [
	"res://src/escenas/objetos/objeto_agarrable.tscn",
	"res://src/escenas/objetos/caja_de_productos.tscn",
	"res://src/escenas/objetos/bolsa_de_basura.tscn",
	"res://src/escenas/objetos/colilla.tscn",
	"res://src/escenas/objetos/llave.tscn",
	"res://src/escenas/objetos/palanca.tscn",
	"res://src/escenas/objetos/documento_impreso.tscn",
	"res://src/escenas/objetos/nota_bajo_la_puerta.tscn",
	"res://src/escenas/objetos/ticket.tscn",
]

const GROSOR_DEL_PISO := 0.2

## Desde dónde cae, sobre el piso, y cuántos pasos de la física se espera a que se asiente.
const ALTURA_DE_CAIDA := 0.3
const PASOS_PARA_ASENTARSE := 90


func _piso() -> void:
	var piso: StaticBody3D = auto_free(StaticBody3D.new())
	var forma := CollisionShape3D.new()
	var losa := BoxShape3D.new()
	losa.size = Vector3(10.0, GROSOR_DEL_PISO, 10.0)
	forma.shape = losa
	piso.add_child(forma)
	add_child(piso)
	piso.global_position = Vector3(0.0, -GROSOR_DEL_PISO / 2.0, 0.0)


func _oclusion_de(objeto: Node) -> Node3D:
	for nodo in get_tree().get_nodes_in_group(Oclusion.GRUPO):
		if objeto.is_ancestor_of(nodo):
			return nodo
	return null


func test_cada_escena_de_lo_que_se_levanta_trae_su_oclusion_de_contacto() -> void:
	for ruta: String in ESCENAS:
		var objeto: Node3D = auto_free((load(ruta) as PackedScene).instantiate())
		add_child(objeto)
		(
			assert_object(_oclusion_de(objeto))
			. override_failure_message("%s no lleva la oclusión de contacto" % ruta)
			. is_not_null()
		)


func test_cada_objeto_que_cae_al_piso_deja_su_mancha_ahi_y_no_la_contornea_el_foco() -> void:
	_piso()
	for ruta: String in ESCENAS:
		var objeto: RigidBody3D = auto_free((load(ruta) as PackedScene).instantiate())
		add_child(objeto)
		if objeto.has_method("en_el_tacho"):
			objeto.call("en_el_tacho", false)
		objeto.freeze = false
		objeto.global_position = Vector3.UP * ALTURA_DE_CAIDA
		for _paso in PASOS_PARA_ASENTARSE:
			await get_tree().physics_frame
		var oclusion := _oclusion_de(objeto)
		(
			assert_bool(oclusion.sombra.visible)
			. override_failure_message("%s quieto en el piso no deja mancha" % ruta)
			. is_true()
		)
		assert_bool(oclusion.sombra.is_in_group(ReglasDeLosObjetos.GRUPO_SIN_CONTORNO)).is_true()
		objeto.queue_free()
		await get_tree().process_frame


## El balde y la mopa visten su malla con `ShaderMaterial` después de `_ready`, en un
## `call_deferred`: sólo con los reales se ve que la mancha y la base oscurecida llegan a ellos.
func test_el_balde_y_la_mopa_apoyados_dejan_su_mancha_y_oscurecen_su_base() -> void:
	_piso()
	var objetos: Node3D = auto_free(UTILES.instantiate())
	add_child(objetos)
	var utiles: Array[RigidBody3D] = []
	for nombre: String in ["Balde", "Mopa"]:
		var util := objetos.get_node(nombre) as RigidBody3D
		util.freeze = false
		util.global_position = Vector3(utiles.size() * 3.0 - 1.5, ALTURA_DE_CAIDA, 0.0)
		utiles.append(util)
	for _paso in PASOS_PARA_ASENTARSE:
		await get_tree().physics_frame
	for util: RigidBody3D in utiles:
		var oclusion := _oclusion_de(util)
		(
			assert_bool(oclusion.sombra.visible)
			. override_failure_message("%s quieto en el piso no deja mancha" % util.name)
			. is_true()
		)
		var oscurecidas := 0
		for malla: MeshInstance3D in oclusion.mallas:
			for superficie: int in malla.get_surface_override_material_count():
				var material := malla.get_surface_override_material(superficie) as ShaderMaterial
				if material == null or not _declara(material, Oclusion.SUELO_DE_LA_MALLA):
					continue
				oscurecidas += 1
				var suelo: float = material.get_shader_parameter(Oclusion.SUELO_DE_LA_MALLA)
				assert_float(suelo).is_equal_approx(0.0, 0.001)
				var intensidad: float = material.get_shader_parameter(
					Oclusion.PARAMETRO_DE_LA_MALLA
				)
				assert_float(intensidad).is_greater(0.0)
		(
			assert_int(oscurecidas)
			. override_failure_message("%s no oscurece ninguna superficie de su base" % util.name)
			. is_greater(0)
		)


func _declara(material: ShaderMaterial, uniforme: StringName) -> bool:
	for declarado: Dictionary in material.shader.get_shader_uniform_list():
		if declarado["name"] == uniforme:
			return true
	return false


func test_en_el_almacen_todo_lo_interactuable_que_es_un_cuerpo_lleva_la_oclusion() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2, "medios": 0})
	)
	add_child(almacen)
	await get_tree().physics_frame
	var cuerpos := 0
	for nodo in get_tree().get_nodes_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE):
		if not nodo is RigidBody3D or not nodo.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR):
			continue
		cuerpos += 1
		(
			assert_object(_oclusion_de(nodo))
			. override_failure_message("%s se levanta y no lleva la oclusión" % nodo.name)
			. is_not_null()
		)
	assert_int(cuerpos).is_greater(5)

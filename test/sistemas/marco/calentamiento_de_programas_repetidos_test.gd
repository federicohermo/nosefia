## Dos objetos que compilan el mismo programa no suman copias ni cuadros al calentamiento.
##
## En la web cada cuadro de más es un cuadro con la barra de carga quieta, y cada copia de más se
## dibuja otra vez en todos los cuadros que siguen.
extends GdUnitTestSuite

const ESPERA_MS := 5000
const CAPA_A := 1 << 0
const CAPA_B := 1 << 1
const CAPA_C := 1 << 2


func _escena_con_dos_luces() -> Node3D:
	var escena: Node3D = auto_free(Node3D.new())
	add_child(escena)
	for x: float in [-1.0, 1.0]:
		var omni := OmniLight3D.new()
		omni.position = Vector3(x, 1, 0)
		omni.omni_range = 1.5
		omni.shadow_enabled = x > 0.0
		escena.add_child(omni)
	return escena


## Cada fuente trae su malla y su material: iguales entre sí, pero no la misma instancia.
func _agregar_fuente(escena: Node3D, capa: int, material: StandardMaterial3D) -> void:
	var cuerpo := RigidBody3D.new()
	cuerpo.freeze = true
	cuerpo.position = Vector3(0, 1, 6)
	escena.add_child(cuerpo)
	var instancia := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.1
	instancia.mesh = caja
	instancia.material_override = material
	instancia.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	instancia.layers = capa
	cuerpo.add_child(instancia)


## Cuántas copias distintas se dibujaron, y en cuántos cuadros apareció alguna nueva.
func _calentar(materiales: Array[StandardMaterial3D], capas: Array[int]) -> Dictionary:
	var escena := _escena_con_dos_luces()
	for indice: int in materiales.size():
		_agregar_fuente(escena, capas[indice], materiales[indice])
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	calentamiento.unifica_variantes = func() -> bool: return false
	add_child(calentamiento)
	var vistas: Dictionary[int, bool] = {}
	var cuadros_con_nuevas := [0]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			var antes := vistas.size()
			for muestra: MeshInstance3D in calentamiento.find_children(
				"*", "MeshInstance3D", true, false
			):
				if muestra.visible:
					vistas[muestra.get_instance_id()] = true
			if vistas.size() > antes:
				cuadros_con_nuevas[0] += 1
	)
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	escena.queue_free()
	await get_tree().process_frame
	return {"copias": vistas.size(), "cuadros": cuadros_con_nuevas[0]}


func test_las_fuentes_con_el_mismo_programa_y_el_mismo_lugar_comparten_las_copias() -> void:
	var sola: Dictionary = await _calentar([StandardMaterial3D.new()], [CAPA_A])
	var cinco: Dictionary = await _calentar(
		[
			StandardMaterial3D.new(),
			StandardMaterial3D.new(),
			StandardMaterial3D.new(),
			StandardMaterial3D.new(),
			StandardMaterial3D.new()
		],
		[CAPA_A, CAPA_A, CAPA_A, CAPA_A, CAPA_A]
	)
	assert_int(sola["copias"]).is_greater(1)
	assert_int(cinco["copias"]).is_equal(sola["copias"])


func test_una_fuente_con_otro_programa_conserva_sus_copias() -> void:
	var sola: Dictionary = await _calentar([StandardMaterial3D.new()], [CAPA_A])
	var sin_luz := StandardMaterial3D.new()
	sin_luz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dos: Dictionary = await _calentar([StandardMaterial3D.new(), sin_luz], [CAPA_A, CAPA_A])
	assert_int(dos["copias"]).is_greater(sola["copias"])


func test_los_que_repiten_programa_y_luces_no_suman_cuadros_de_compilacion() -> void:
	var sola: Dictionary = await _calentar([StandardMaterial3D.new()], [CAPA_A])
	var tres: Dictionary = await _calentar(
		[StandardMaterial3D.new(), StandardMaterial3D.new(), StandardMaterial3D.new()],
		[CAPA_A, CAPA_B, CAPA_C]
	)
	# Con varias combinaciones de luces por fuente, que cada instancia cuente como material nuevo
	# sumaba un cuadro por fuente. El cuadro de más es el que destapa lo ya compilado.
	assert_int(sola["copias"]).is_greater(2)
	assert_int(tres["cuadros"]).is_less_equal(sola["cuadros"] + 1)

## Los materiales 2D que la escena trae ocultos también se dibujan detrás de la carga: el celular,
## la computadora y la intro compilaban su shader la primera vez que aparecían.
extends GdUnitTestSuite

const ESPERA_MS := 5000


func _material_2d() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(SCREEN_UV, 0.0, 1.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _muestras_con(material: Material) -> Array[Node]:
	return get_tree().root.find_children("*", "CanvasItem", true, false).filter(
		func(nodo: CanvasItem) -> bool:
			return nodo.material == material and nodo.is_visible_in_tree()
	)


func test_el_material_2d_oculto_se_dibuja_y_su_muestra_se_va_al_terminar() -> void:
	var escena: Node3D = auto_free(Node3D.new())
	var capa := CanvasLayer.new()
	capa.visible = false
	escena.add_child(capa)
	var velo := ColorRect.new()
	velo.material = _material_2d()
	capa.add_child(velo)
	add_child(escena)
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	add_child(calentamiento)
	assert_array(_muestras_con(velo.material)).is_empty()
	calentamiento.calentar(escena)
	assert_array(_muestras_con(velo.material)).has_size(1)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	await get_tree().process_frame
	assert_array(_muestras_con(velo.material)).is_empty()
	assert_bool(capa.visible).is_false()


## Lo que se dibuja en un `SubViewport` de la escena tampoco se ve durante la carga: la escena
## está detenida y su viewport no se actualiza. El agua del baño compilaba al entrar.
func test_el_material_2d_de_un_subviewport_tambien_se_dibuja() -> void:
	var escena: Node3D = auto_free(Node3D.new())
	var ventana := SubViewport.new()
	escena.add_child(ventana)
	var ondas := ColorRect.new()
	ondas.material = _material_2d()
	ventana.add_child(ondas)
	add_child(escena)
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	add_child(calentamiento)
	calentamiento.calentar(escena)
	var muestras := _muestras_con(ondas.material).filter(
		func(nodo: CanvasItem) -> bool: return not escena.is_ancestor_of(nodo)
	)
	assert_array(muestras).has_size(1)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")

extends GdUnitTestSuite

const JUGADOR := preload("res://src/escenas/jugador.tscn")


class TapaTocable:
	extends Node3D
	var usos := 0

	func usar() -> void:
		usos += 1


func test_clic_derecho_usa_el_objetivo_sin_disparar_la_limpieza() -> void:  # AC-CLN-034
	var jugador: CharacterBody3D = auto_free(JUGADOR.instantiate())
	var tapa: TapaTocable = auto_free(TapaTocable.new())
	var avisos: Array[Node3D] = []
	jugador.uso_pedido.connect(func(objetivo: Node3D) -> void: avisos.append(objetivo))
	jugador.set("_enfocado", tapa)
	jugador.call("_unhandled_input", _clic(MOUSE_BUTTON_RIGHT))
	assert_int(tapa.usos).is_equal(1)
	assert_array(avisos).is_empty()


func test_un_objetivo_sin_uso_propio_conserva_el_uso_de_limpieza() -> void:
	var jugador: CharacterBody3D = auto_free(JUGADOR.instantiate())
	var artefacto: Node3D = auto_free(Node3D.new())
	var avisos: Array[Node3D] = []
	jugador.uso_pedido.connect(func(objetivo: Node3D) -> void: avisos.append(objetivo))
	jugador.set("_enfocado", artefacto)
	jugador.call("_unhandled_input", _clic(MOUSE_BUTTON_RIGHT))
	assert_array(avisos).contains_exactly([artefacto])


func test_clic_izquierdo_no_acciona_la_tapa() -> void:  # AC-CLN-034
	var jugador: CharacterBody3D = auto_free(JUGADOR.instantiate())
	var tapa: TapaTocable = auto_free(TapaTocable.new())
	jugador.set("_enfocado", tapa)
	jugador.call("_unhandled_input", _clic(MOUSE_BUTTON_LEFT))
	assert_int(tapa.usos).is_equal(0)


func test_la_pausa_impide_accionar_la_tapa() -> void:  # AC-CLN-034
	var jugador: CharacterBody3D = auto_free(JUGADOR.instantiate())
	var tapa: TapaTocable = auto_free(TapaTocable.new())
	jugador.call("suspender")
	jugador.set("_enfocado", tapa)
	jugador.call("_unhandled_input", _clic(MOUSE_BUTTON_RIGHT))
	assert_int(tapa.usos).is_equal(0)


func _clic(boton: MouseButton) -> InputEventMouseButton:
	var evento := InputEventMouseButton.new()
	evento.button_index = boton
	evento.pressed = true
	return evento

## Con el celular a la vista, el registro ocupa el área libre a su izquierda sin pisarlo.
extends GdUnitTestSuite

const COMPUTADORA := preload("res://src/ui/diegetica/pantalla_de_computadora.tscn")
const CELULAR := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")
const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")
const OCUPACION_MINIMA := 0.85

var _tamano_de_ventana: Vector2i
var _reloj: Array[int] = [0]


func before_test() -> void:
	_tamano_de_ventana = get_window().size


func after_test() -> void:
	get_window().size = _tamano_de_ventana
	await get_tree().process_frame
	await get_tree().process_frame


func _en_pantalla(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _computadora_en(ventana: Vector2i) -> PantallaDeComputadora:
	get_window().size = ventana
	await get_tree().process_frame
	var computadora: PantallaDeComputadora = auto_free(COMPUTADORA.instantiate())
	add_child(computadora)
	await get_tree().process_frame
	return computadora


## Los rectángulos en pantalla del registro y del celular, ya a la vista, en una `ventana`.
func _conjunta_en(ventana: Vector2i) -> Array[Rect2]:
	var computadora := await _computadora_en(ventana)
	var celular: PantallaDelCelular = auto_free(CELULAR.instantiate())
	add_child(celular)
	await get_tree().process_frame
	_reloj[0] = 0
	celular.set("_ahora", func() -> int: return _reloj[0])
	computadora.mostrar_conjunta(true)
	celular.abrir_en_la_conjunta()
	AvanceDeDevolucion.animar_celular(
		celular, _reloj, int(PantallaDelCelular.RECORRIDO_COMPLETO * 1000000.0) + 25000
	)
	return [_en_pantalla(computadora.get("_marco")), _en_pantalla(celular.get("_telefono"))]


func _entra_sin_pisar(rectangulos: Array[Rect2], ventana: Vector2i) -> bool:
	var visible := Rect2(Vector2.ZERO, Vector2(ventana))
	return visible.encloses(rectangulos[0]) and rectangulos[0].end.x < rectangulos[1].position.x


func _ocupa_el_area_libre(rectangulos: Array[Rect2], ventana: Vector2i) -> bool:
	var ancho_libre := rectangulos[1].position.x
	return (
		rectangulos[0].size.x >= ancho_libre * OCUPACION_MINIMA
		or rectangulos[0].size.y >= ventana.y * OCUPACION_MINIMA
	)


func test_a_1920x1080_el_registro_ocupa_el_area_libre_sin_pisar_al_celular() -> void:
	var ventana := Vector2i(1920, 1080)
	var rectangulos := await _conjunta_en(ventana)
	assert_bool(_entra_sin_pisar(rectangulos, ventana)).is_true()
	assert_bool(_ocupa_el_area_libre(rectangulos, ventana)).is_true()


func test_en_una_ventana_mas_ancha_el_registro_ocupa_el_area_libre_sin_pisar_al_celular() -> void:
	var ventana := Vector2i(2560, 1080)
	var rectangulos := await _conjunta_en(ventana)
	assert_bool(_entra_sin_pisar(rectangulos, ventana)).is_true()
	assert_bool(_ocupa_el_area_libre(rectangulos, ventana)).is_true()


func test_en_una_ventana_baja_el_registro_ocupa_el_area_libre_sin_pisar_al_celular() -> void:
	var ventana := Vector2i(1920, 900)
	var rectangulos := await _conjunta_en(ventana)
	assert_bool(_entra_sin_pisar(rectangulos, ventana)).is_true()
	assert_bool(_ocupa_el_area_libre(rectangulos, ventana)).is_true()


func test_con_el_celular_oculto_el_registro_vuelve_a_ocupar_toda_la_ventana() -> void:
	var ventana := Vector2i(1920, 1080)
	var computadora := await _computadora_en(ventana)
	computadora.mostrar_conjunta(true)
	computadora.mostrar_conjunta(false)
	var registro := _en_pantalla(computadora.get("_marco"))
	assert_vector(registro.position).is_equal_approx(Vector2.ZERO, Vector2.ONE)
	assert_vector(registro.size).is_equal_approx(Vector2(ventana), Vector2.ONE)

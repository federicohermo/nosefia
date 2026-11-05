## La barra de estado del celular: la hora de la noche y el ícono de wifi conectado a su derecha.
## Qué hora se lee lo decide `Marcador`; acá, que la barra la muestre en cada vista del celular.
extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")

var _tamano_de_ventana: Vector2i


func before_test() -> void:
	_tamano_de_ventana = get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame


func after_test() -> void:
	get_window().size = _tamano_de_ventana
	await get_tree().process_frame
	await get_tree().process_frame


func _pantalla() -> PantallaDelCelular:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	pantalla.subir()
	return pantalla


func _barra(pantalla: PantallaDelCelular) -> Control:
	return pantalla.find_child("BarraDeEstado", true, false) as Control


func _hora(pantalla: PantallaDelCelular) -> Label:
	return pantalla.find_child("Hora", true, false) as Label


func _wifi(pantalla: PantallaDelCelular) -> TextureRect:
	return pantalla.find_child("Wifi", true, false) as TextureRect


func _sin_wifi(pantalla: PantallaDelCelular) -> TextureRect:
	return pantalla.find_child("SinWifi", true, false) as TextureRect


func _conversacion() -> Conversacion:
	var conversacion := Conversacion.new()
	conversacion.nombre = "Ana"
	conversacion.interlocutor = Conversacion.Interlocutor.JEFE
	var mensaje := Mensaje.new()
	mensaje.de_quien = conversacion.nombre
	mensaje.texto = "Un mensaje."
	conversacion.mensajes.append(mensaje)
	return conversacion


func _en_cada_vista(pantalla: PantallaDelCelular) -> Array[Callable]:
	var conversacion := _conversacion()
	var chats: Array[Conversacion] = [conversacion]
	return [
		func() -> void: pantalla.mostrar_menu(Bandeja.new(chats)),
		func() -> void: pantalla.mostrar_chat(conversacion, conversacion.mensajes, false, 1),
		func() -> void: pantalla.mostrar_chat(conversacion, conversacion.mensajes, true, 1),
	]


func test_la_barra_lleva_la_hora_y_el_wifi_a_su_derecha_en_menu_chat_y_fijo() -> void:  # AC-INV-195
	var pantalla := _pantalla()
	for mostrar: Callable in _en_cada_vista(pantalla):
		mostrar.call()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_bool(_barra(pantalla).is_visible_in_tree()).is_true()
		assert_bool(_hora(pantalla).is_visible_in_tree()).is_true()
		assert_bool(_wifi(pantalla).is_visible_in_tree()).is_true()
		assert_bool(_sin_wifi(pantalla).visible).is_false()
		var hora := _hora(pantalla).get_global_rect()
		var wifi := _wifi(pantalla).get_global_rect()
		assert_float(wifi.position.x).is_greater_equal(hora.end.x)
		assert_float(hora.position.y).is_less(_cabecera_de(pantalla).get_global_rect().position.y)


func _cabecera_de(pantalla: PantallaDelCelular) -> Control:
	return pantalla.get("_cabecera")


func test_la_hora_de_la_barra_sigue_al_tiempo_que_recibe() -> void:  # AC-INV-195, AC-SHF-120
	var pantalla := _pantalla()
	var vistas: Array[String] = []
	for restante: float in [Reglas.DURACION_DEL_TURNO, Reglas.DURACION_DEL_TURNO / 2.0, 0.0]:
		pantalla.barra_de_estado().mostrar_tiempo(restante)
		assert_str(_hora(pantalla).text).is_equal(Marcador.hora(restante))
		vistas.append(_hora(pantalla).text)
	assert_array(vistas).has_size(3)
	assert_bool(vistas[0] != vistas[1] and vistas[1] != vistas[2]).is_true()


func test_la_hora_pasa_la_medianoche_sin_saltos() -> void:  # AC-SHF-120
	var pantalla := _pantalla()
	var antes := Vector2i(Marcador.HORAS_POR_DIA - 1, Marcador.MINUTOS_POR_HORA - 1)
	var restante_antes := _restante_a(antes)
	pantalla.barra_de_estado().mostrar_tiempo(restante_antes)
	assert_str(_hora(pantalla).text).is_equal(Marcador.hora(restante_antes))
	var minuto := float(Marcador.SEGUNDOS_POR_MINUTO)
	pantalla.barra_de_estado().mostrar_tiempo(restante_antes - minuto)
	assert_str(_hora(pantalla).text).is_equal(Marcador.hora(restante_antes - minuto))
	assert_str(_hora(pantalla).text).is_not_equal(Marcador.hora(restante_antes))


## Cuánto queda del turno cuando el reloj marca esa hora, sin repetir la aritmética del marcador.
func _restante_a(hora: Vector2i) -> float:
	var horas := posmod(hora.x - Reglas.HORA_DE_APERTURA, Marcador.HORAS_POR_DIA)
	var minutos := horas * Marcador.MINUTOS_POR_HORA + hora.y
	return Reglas.DURACION_DEL_TURNO - float(minutos * Marcador.SEGUNDOS_POR_MINUTO)


func test_sin_turno_corriendo_la_barra_lee_la_hora_de_cierre() -> void:  # AC-SHF-123
	var pantalla := _pantalla()
	assert_str(_hora(pantalla).text).is_equal(Marcador.hora(0.0))
	assert_str(_hora(pantalla).text).is_not_empty()


func test_la_barra_no_recibe_clics() -> void:  # AC-INV-195
	var pantalla := _pantalla()
	for nodo: Control in [_barra(pantalla), _hora(pantalla), _wifi(pantalla), _sin_wifi(pantalla)]:
		assert_int(nodo.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

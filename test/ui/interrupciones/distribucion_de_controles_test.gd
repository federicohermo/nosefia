## Cómo se acomoda la pantalla de controles: cada pestaña entra entera sin desplazar, los renglones
## tienen la misma altura, las columnas se alinean, toda celda mide lo mismo con su glifo centrado,
## y la celda elegida se distingue de las demás.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_controles.tscn"
const CONFIGURACIONES := "res://src/ui/interrupciones/pantalla_de_configuraciones.tscn"
const PRINCIPAL := AsignacionDeControles.RANURA_PRINCIPAL
const SECUNDARIA := AsignacionDeControles.RANURA_SECUNDARIA
const EN_EL_JOYSTICK := AsignacionDeControles.RANURA_DEL_JOYSTICK
const TOLERANCIA := 1.5


func _pantalla(con_el_joystick: bool = false) -> PantallaDeControles:
	var pantalla: PantallaDeControles = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	pantalla.preparar(AsignacionDeControles.new())
	pantalla.poner_joystick_conectado(true)
	pantalla.abrir(con_el_joystick)
	await get_tree().process_frame
	await get_tree().process_frame
	return pantalla


func _mostrar(pantalla: PantallaDeControles, del_joystick: bool) -> void:
	pantalla.elegir_pestana(del_joystick)
	await get_tree().process_frame
	await get_tree().process_frame


func _desplazador(pantalla: PantallaDeControles) -> ScrollContainer:
	var filas: Control = pantalla.get("_filas")
	return filas.get_parent() as ScrollContainer


func _nombre(fila: HBoxContainer) -> String:
	return (fila.get_child(0) as Label).text


func _borde(caja: StyleBox) -> int:
	if caja is StyleBoxFlat:
		return (caja as StyleBoxFlat).get_border_width_min()
	return 0


func test_cada_pestana_entra_entera_sin_desplazar() -> void:  # AC-CFG-031
	var pantalla := await _pantalla()
	var desplazador := _desplazador(pantalla)
	var area := desplazador.get_global_rect()
	for del_joystick: bool in [false, true]:
		await _mostrar(pantalla, del_joystick)
		var barra := desplazador.get_v_scroll_bar()
		assert_bool(barra.max_value > barra.page + TOLERANCIA).is_false()
		for fila: HBoxContainer in pantalla.filas(del_joystick):
			var caja := fila.get_global_rect()
			assert_bool(caja.end.y <= area.end.y + TOLERANCIA).is_true()
			assert_bool(caja.end.x <= area.end.x + TOLERANCIA).is_true()


func test_todos_los_renglones_de_una_pestana_miden_lo_mismo() -> void:  # AC-CFG-031
	var pantalla := await _pantalla()
	for del_joystick: bool in [false, true]:
		await _mostrar(pantalla, del_joystick)
		var filas := pantalla.filas(del_joystick)
		for fila: HBoxContainer in filas:
			assert_float(fila.size.y).is_equal_approx(filas[0].size.y, TOLERANCIA)


## Lo que se ve, no la caja: la línea larga de la cabecera y del pie, el recuadro de una tecla.
func test_los_margenes_de_arriba_abajo_son_parejos_en_las_dos_pestanas() -> void:  # AC-CFG-031
	var pantalla := await _pantalla()
	var marco := pantalla.marco()
	var escala := marco.get_global_transform().get_scale().y
	var cabecera: Control = marco.get_node("Cabecera")
	var pie: Control = marco.get_node("Pie")
	var linea_de_arriba := (
		cabecera.global_position.y
		+ cabecera.size.y * escala * CabeceraConSolapa.Y_DE_LA_LINEA / CabeceraConSolapa.ALTO
		+ CabeceraConSolapa.GROSOR / 2.0 * escala
	)
	var linea_del_pie := (
		pie.global_position.y
		+ pie.size.y * escala * (1.0 - CabeceraConSolapa.Y_DE_LA_LINEA / CabeceraConSolapa.ALTO)
		- CabeceraConSolapa.GROSOR / 2.0 * escala
	)
	var pestanas: Control = (pantalla.get("_filas") as Control).get_child(0)
	for del_joystick: bool in [false, true]:
		await _mostrar(pantalla, del_joystick)
		var filas := pantalla.filas(del_joystick)
		var glifos := filas[filas.size() - 1].find_children("*", "GlifoDeEntrada", true, false)
		var ultima := glifos[0] as Control
		var tecla_abajo := (
			ultima.get_global_rect().get_center().y + ultima.get_minimum_size().y / 2.0 * escala
		)
		var margen_de_arriba := pestanas.get_global_rect().position.y - linea_de_arriba
		var margen_de_abajo := linea_del_pie - tecla_abajo
		assert_float(margen_de_arriba / escala).is_greater(0.0)
		assert_float(margen_de_abajo).is_equal_approx(margen_de_arriba, TOLERANCIA * escala)


func test_cada_pestana_alinea_a_la_izquierda_sus_glifos() -> void:  # AC-CFG-031, AC-CFG-042
	var pantalla := await _pantalla()
	for del_joystick: bool in [false, true]:
		await _mostrar(pantalla, del_joystick)
		var bordes: Array[float] = []
		for fila: HBoxContainer in pantalla.filas(del_joystick):
			bordes.append(_borde_izquierdo(fila.get_child(1)))
		for borde: float in bordes:
			assert_float(borde).is_equal_approx(bordes[0], TOLERANCIA)


func test_la_marca_fijo_entra_en_su_bloque() -> void:  # AC-CFG-035
	var pantalla := await _pantalla()
	var area := _desplazador(pantalla).get_global_rect()
	for del_joystick: bool in [false, true]:
		await _mostrar(pantalla, del_joystick)
		for fila: HBoxContainer in pantalla.filas(del_joystick):
			if not fila.has_meta(&"fijo"):
				continue
			var marca := fila.get_child(fila.get_child_count() - 1) as Label
			assert_bool(marca.get_global_rect().end.x <= area.end.x + TOLERANCIA).is_true()


## Configuraciones escribe con el tipo `TextoDelMenu` del tema: ese es el tamaño de la vara.
func _tamano_de_configuraciones() -> int:
	var configuraciones: Node = auto_free(load(CONFIGURACIONES).instantiate())
	add_child(configuraciones)
	await get_tree().process_frame
	var tamanos: Array[int] = []
	for nodo: Node in configuraciones.get_node("Fondo/Panel/Filas").find_children(
		"*", "Label", true, false
	):
		tamanos.append((nodo as Label).get_theme_font_size("font_size"))
	assert_int(tamanos.size()).is_greater(5)
	for tamano: int in tamanos:
		assert_int(tamano).is_equal(tamanos[0])
	return tamanos[0]


func test_todo_el_texto_tiene_el_tamano_de_letra_de_configuraciones() -> void:  # AC-CFG-031
	var vara := await _tamano_de_configuraciones()
	var pantalla := await _pantalla()
	pantalla.elegir(AsignacionDeControles.ADELANTE, PRINCIPAL)
	var tamanos: Array[int] = []
	for del_joystick: bool in [false, true]:
		await _mostrar(pantalla, del_joystick)
		for etiqueta: Node in pantalla.find_children("*", "Label", true, false):
			tamanos.append((etiqueta as Label).get_theme_font_size("font_size"))
		for boton: Node in pantalla.find_children("*", "Button", true, false):
			tamanos.append((boton as Button).get_theme_font_size("font_size"))
		for glifo: Node in pantalla.find_children("*", "GlifoDeEntrada", true, false):
			if not (glifo as GlifoDeEntrada).texto.is_empty():
				tamanos.append(glifo.call("_tamano_de_la_letra"))
	assert_int(tamanos.size()).is_greater(20)
	for tamano: int in tamanos:
		assert_int(tamano).is_equal(vara)


func test_el_titulo_y_su_marco_son_los_de_configuraciones() -> void:  # AC-CFG-031
	var configuraciones: Node = auto_free(load(CONFIGURACIONES).instantiate())
	add_child(configuraciones)
	var pantalla := await _pantalla()
	await get_tree().process_frame
	var de_configuraciones: Control = configuraciones.find_child("Panel", true, false)
	var de_controles := pantalla.marco()
	for nombre: String in ["Titulo", "Cabecera", "Pie", "Volver"]:
		var uno := de_configuraciones.get_node(nombre) as Control
		var otro := de_controles.get_node(nombre) as Control
		assert_vector(otro.position).is_equal(uno.position)
		assert_vector(otro.size).is_equal(uno.size)
		assert_bool(otro.has_theme_font_size_override("font_size")).is_false()


func test_cada_pestana_reparte_el_alto_y_centra_la_lista_con_las_pestanas() -> void:  # AC-CFG-031
	var pantalla := await _pantalla()
	var area := _desplazador(pantalla).get_global_rect()
	var barra := (pantalla.get("_filas") as Control).get_child(0) as Control
	var izquierda := barra.get_child(0) as Control
	var derecha := barra.get_child(barra.get_child_count() - 1) as Control
	var centro_de_las_pestanas := (
		(izquierda.get_global_rect().position.x + derecha.get_global_rect().end.x) / 2.0
	)
	for del_joystick: bool in [false, true]:
		await _mostrar(pantalla, del_joystick)
		var filas := pantalla.filas(del_joystick)
		var ultima := filas[filas.size() - 1].get_global_rect()
		assert_float(ultima.end.y).is_equal_approx(area.end.y, TOLERANCIA)
		for fila: HBoxContainer in filas:
			var caja := fila.get_global_rect()
			assert_float(caja.get_center().x).is_equal_approx(centro_de_las_pestanas, TOLERANCIA)
			assert_bool(caja.position.x >= area.position.x - TOLERANCIA).is_true()
			assert_bool(caja.end.x <= area.end.x + TOLERANCIA).is_true()


func test_las_teclas_de_renglones_vecinos_no_se_tocan() -> void:  # AC-CFG-031
	var pantalla := await _pantalla()
	var filas := pantalla.filas(false)
	var tecla := pantalla.glifo_de(AsignacionDeControles.ADELANTE, PRINCIPAL).get_minimum_size()
	var paso := filas[1].get_global_rect().position.y - filas[0].get_global_rect().position.y
	var escala := pantalla.marco().get_global_transform().get_scale().y
	assert_bool(paso / escala > tecla.y).is_true()


## Donde arranca el primer glifo que lleva ese nodo. Lo dibujado arranca ahí mismo.
func _borde_izquierdo(nodo: Node) -> float:
	var glifo := nodo.find_children("*", "GlifoDeEntrada", true, false)[0] as GlifoDeEntrada
	return glifo.get_global_rect().position.x


func _celdas(del_joystick: bool) -> Array[Array]:
	var celdas: Array[Array] = []
	if del_joystick:
		for accion: StringName in AsignacionDeControles.ACCIONES_CON_BOTON:
			celdas.append([accion, EN_EL_JOYSTICK])
		return celdas
	for accion: StringName in AsignacionDeControles.ACCIONES:
		celdas.append([accion, PRINCIPAL])
		celdas.append([accion, SECUNDARIA])
	return celdas


func test_cada_tecla_mide_su_ancho_natural_y_su_foco_la_enmarca() -> void:  # AC-CFG-036
	var pantalla := await _pantalla()
	for del_joystick: bool in [false, true]:
		await _mostrar(pantalla, del_joystick)
		for par: Array in _celdas(del_joystick):
			var celda := pantalla.boton_de(par[0], par[1])
			var glifo := pantalla.glifo_de(par[0], par[1])
			var natural := glifo.get_minimum_size()
			assert_float(glifo.marco_dibujado().size.x).is_equal_approx(natural.x, TOLERANCIA)
			assert_float(celda.size.x).is_equal_approx(natural.x, TOLERANCIA)
			assert_float(celda.get_global_rect().position.x).is_equal_approx(
				glifo.get_global_rect().position.x, TOLERANCIA
			)


func test_las_teclas_y_su_cabecera_arrancan_en_el_mismo_borde() -> void:  # AC-CFG-036
	var pantalla := await _pantalla()
	await _mostrar(pantalla, false)
	var filas := pantalla.filas(false)
	var cabecera := filas[0].get_parent().get_child(0) as HBoxContainer
	for columna: int in [1, 2]:
		var borde_de_la_cabecera := (
			(cabecera.get_child(columna) as Control).get_global_rect().position.x
		)
		for fila: HBoxContainer in filas:
			assert_float(_borde_izquierdo(fila.get_child(columna))).is_equal_approx(
				borde_de_la_cabecera, TOLERANCIA
			)


func test_una_ranura_vacia_mide_una_tecla_de_una_letra() -> void:  # AC-CFG-036
	var pantalla := await _pantalla()
	var una_letra := GlifoDeEntrada.de_una_tecla("W")
	add_child(auto_free(una_letra))
	var vacia := pantalla.glifo_de(AsignacionDeControles.EXAMINAR, SECUNDARIA)
	assert_int(vacia.forma).is_equal(GlifoDeEntrada.Forma.RANURA_LIBRE)
	assert_vector(vacia.get_minimum_size()).is_equal_approx(
		una_letra.get_minimum_size(), Vector2(TOLERANCIA, TOLERANCIA)
	)


func test_esperar_una_entrada_no_mueve_la_grilla() -> void:  # AC-CFG-036
	var pantalla := await _pantalla()
	var accion := AsignacionDeControles.EXAMINAR
	var celda := pantalla.boton_de(accion, PRINCIPAL)
	var otra := pantalla.boton_de(AsignacionDeControles.ADELANTE, SECUNDARIA)
	var antes_de_la_celda := celda.get_global_rect()
	var antes_de_la_otra := otra.get_global_rect()
	var antes_de_la_fila := pantalla.filas()[0].size
	pantalla.elegir(accion, PRINCIPAL)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_that(celda.get_global_rect()).is_equal(antes_de_la_celda)
	assert_that(otra.get_global_rect()).is_equal(antes_de_la_otra)
	assert_vector(pantalla.filas()[0].size).is_equal(antes_de_la_fila)


func test_una_ranura_vacia_mide_lo_que_una_tecla_de_una_letra() -> void:  # AC-CFG-031
	var pantalla := await _pantalla()
	var vacia := pantalla.glifo_de(AsignacionDeControles.EXAMINAR, SECUNDARIA)
	var letra := pantalla.glifo_de(AsignacionDeControles.EXAMINAR, PRINCIPAL)
	assert_vector(vacia.get_minimum_size()).is_equal(letra.get_minimum_size())


func test_la_celda_sin_foco_no_lleva_recuadro_y_la_elegida_si() -> void:  # AC-CFG-037
	var pantalla := await _pantalla()
	for accion: StringName in AsignacionDeControles.ACCIONES:
		for ranura: int in [PRINCIPAL, SECUNDARIA]:
			var celda := pantalla.boton_de(accion, ranura)
			assert_int(_borde(celda.get_theme_stylebox("normal"))).is_equal(0)
			assert_bool(_borde(celda.get_theme_stylebox("focus")) > 0).is_true()
			assert_bool(_borde(celda.get_theme_stylebox("hover")) > 0).is_true()


func test_las_flechas_se_dibujan_como_flecha_y_las_letras_no() -> void:  # AC-CFG-036
	var pantalla := await _pantalla()
	var esperadas: Dictionary[StringName, Vector2] = {
		AsignacionDeControles.ADELANTE: Vector2.UP,
		AsignacionDeControles.ATRAS: Vector2.DOWN,
		AsignacionDeControles.IZQUIERDA: Vector2.LEFT,
		AsignacionDeControles.DERECHA: Vector2.RIGHT,
	}
	for accion: StringName in esperadas:
		assert_vector(pantalla.glifo_de(accion, SECUNDARIA).flecha).is_equal(esperadas[accion])
		assert_vector(pantalla.glifo_de(accion, PRINCIPAL).flecha).is_equal(Vector2.ZERO)


func test_cada_pestana_junta_su_dibujo_con_su_texto_y_los_centra() -> void:  # AC-CFG-031
	var pantalla := await _pantalla()
	for nombre: String in ["_pestana_del_teclado", "_pestana_del_joystick"]:
		var pestana: Button = pantalla.get(nombre)
		var dibujo := pestana.find_children("*", "DibujoDeDispositivo", true, false)[0] as Control
		var texto := pestana.find_children("*", "Label", true, false)[0] as Label
		var izquierda := dibujo.get_global_rect().position.x
		var derecha := texto.get_global_rect().end.x
		var centro_del_grupo := (izquierda + derecha) / 2.0
		var centro_de_la_pestana := pestana.get_global_rect().get_center().x
		assert_float(centro_del_grupo).is_equal_approx(centro_de_la_pestana, TOLERANCIA * 4.0)
		var separacion := texto.get_global_rect().position.x - dibujo.get_global_rect().end.x
		assert_bool(separacion <= dibujo.size.x).is_true()


func test_vision_va_en_el_mismo_lugar_en_las_dos_pestanas() -> void:  # AC-CFG-031
	var pantalla := await _pantalla()
	var del_teclado: Array[String] = []
	for fila: HBoxContainer in pantalla.filas(false):
		del_teclado.append(_nombre(fila))
	var derecha := AsignacionDeControles.nombre_de_la_accion(AsignacionDeControles.DERECHA)
	assert_str(del_teclado[del_teclado.find(derecha) + 1]).is_equal(
		PantallaDeControles.TEXTO_DE_VISION
	)
	var del_joystick: Array[String] = []
	for fila: HBoxContainer in pantalla.filas(true):
		del_joystick.append(_nombre(fila))
	(
		assert_str(del_joystick[del_joystick.find(PantallaDeControles.TEXTO_DE_MOVIMIENTO) + 1])
		. is_equal(PantallaDeControles.TEXTO_DE_VISION)
	)

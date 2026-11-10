## Controles: una pestaña por dispositivo, TECLADO Y MOUSE y JOYSTICK, con la lista de acciones.
##
## En TECLADO Y MOUSE cada acción tiene una celda PRINCIPAL y otra SECUNDARIA. Se elige una celda,
## y apretar una tecla o un botón del mouse se la asigna; SUPR vacía una secundaria. En JOYSTICK
## cada acción de botón tiene la celda de su botón, que se reasigna igual. Lo que no se puede
## configurar no se muestra. Cada entrada se dibuja con su glifo.
##
## Todo el texto va en el tamaño de Configuraciones, `GlifoDeEntrada.tamano_de_la_letra()`:
## nombres, cabeceras y teclas. Todas las teclas miden lo mismo, el ancho de la más ancha, un clic
## con su nombre, y arrancan en el borde izquierdo de su columna, igual que la cabecera; el
## recuadro del foco enmarca la tecla. Los renglones van pegados a la cabecera, con el mismo paso en
## las dos pestañas, y la lista se centra en el ancho, igual que las pestañas. El alto que sobra
## queda debajo.
##
## Abajo, a la izquierda de VOLVER, sólo se ve el mensaje de lo que pasa ahora: qué entrada espera
## la celda elegida, o el aviso de una asignación que no entró.
##
## Sin un joystick conectado no se ve ningún botón de joystick: la pestaña JOYSTICK queda apagada y,
## elegida, avisa que hay que conectar uno. Conectarlo o desconectarlo con la pantalla abierta la
## actualiza.
##
## Dibuja lo que contesta `AsignacionDeControles` y avisa cada asignación que cambió algo. No
## escribe ni aplica nada: eso lo cablea quien la abre.
##
## Corre también con el árbol en pausa: se abre desde Configuraciones, que se abre desde la pausa.
## Mientras espera una entrada se come las teclas y los clics antes que nadie. Qué entrada cancela
## la espera lo contesta `AsignacionDeControles`: la de Pausa. Sin esperar, L1 y R1 cambian de
## pestaña.
class_name PantallaDeControles
extends CanvasLayer

## Una vez por asignación que cambia una ranura, con una copia: quien la recibe puede guardarla.
signal controles_cambiados(asignacion: AsignacionDeControles)
signal cerrada

const TEXTO_DEL_TITULO := "/ CONTROLES:"
const TEXTO_DE_VOLVER := "VOLVER"
const TEXTO_DE_ESPERA := "¿QUÉ TECLA?"
const TEXTO_DE_ESPERA_DEL_JOYSTICK := "¿QUÉ BOTÓN?"
const TEXTO_DEL_TECLADO := "TECLADO Y MOUSE"
const TEXTO_DEL_JOYSTICK := "JOYSTICK"
const TEXTO_DEL_JOYSTICK_CONECTADO := "● JOYSTICK CONECTADO"
const TEXTO_DE_PRINCIPAL := "PRINCIPAL"
const TEXTO_DE_SECUNDARIA := "SECUNDARIA"
const TEXTO_SIN_JOYSTICK := "CONECTÁ UN JOYSTICK PARA CONFIGURARLO"
const TEXTO_DEL_AVISO := "YA ES LA PRINCIPAL DE"
## Cuánto sobresale de la tecla el recuadro de la elegida, para no taparle el borde.
const SOBRESALE_EL_RECUADRO := 4.0
const SEPARACION_DE_LAS_COLUMNAS := 64
const ANCHO_DE_LA_PESTANA := 520.0
const ALTO_DE_LA_PESTANA := 60.0
const ALTO_DE_LA_FILA := 52.0
## Entre un renglón y el siguiente.
const SEPARACION_DE_LAS_FILAS := 11
## Entre las pestañas y la cabecera de las columnas. La tinta del texto no llena su renglón: con
## esta separación el margen se ve igual a los otros tres.
const SEPARACION_DE_LA_CABECERA := 20
## En el lienzo de 1920x1080 del marco.
const POSICION_DEL_MENSAJE := Vector2(140.0, 996.0)
const COLOR_DE_LA_CELDA_ELEGIDA := Color("d8b468")
const OPACIDAD_DEL_TEXTO_APAGADO := 0.55
const OPACIDAD_DE_LA_PESTANA_APAGADA := 0.5
const OPACIDAD_DE_LA_PESTANA_SIN_JOYSTICK := 0.3
const NOMBRES_DE_LAS_TECLAS: Dictionary = {
	KEY_ESCAPE: "ESC",
	KEY_SPACE: "ESPACIO",
	KEY_UP: "FLECHA ARRIBA",
	KEY_DOWN: "FLECHA ABAJO",
	KEY_LEFT: "FLECHA IZQUIERDA",
	KEY_RIGHT: "FLECHA DERECHA",
}

@export var _marco: Control
@export var _titulo: Label
@export var _filas: VBoxContainer
@export var _volver: Button

## En la web, Esc no se asigna a otra acción que Pausa.
var en_la_web: bool = OS.has_feature("web")

var _asignacion := AsignacionDeControles.new()
var _botones: Dictionary = {}
var _celdas: Dictionary = {}
var _glifos: Dictionary = {}
var _con_el_joystick: bool = false
var _joystick_conectado: bool = false
var _pagina_del_teclado: VBoxContainer
var _pagina_del_joystick: VBoxContainer
var _teclas_de_referencia: Array[GlifoDeEntrada] = []
var _pildoras_de_las_pestanas: Array[GlifoDeEntrada] = []
var _aviso_sin_joystick: Label
var _pestana_del_teclado: Button
var _pestana_del_joystick: Button
var _aviso_del_joystick: Label
var _mensaje: Label
var _texto_del_aviso: String = ""
var _primer_boton_del_teclado: Button
var _primer_boton_del_joystick: Button
var _esperando_accion: StringName = &""
var _esperando_ranura: int = -1
var _celda_sin_elegir := StyleBoxEmpty.new()
var _celda_elegida := StyleBoxFlat.new()


func _ready() -> void:
	visible = false
	_titulo.text = TEXTO_DEL_TITULO
	_volver.text = TEXTO_DE_VOLVER
	_volver.pressed.connect(cerrar)
	_crear_los_estilos_de_la_celda()
	_crear_las_teclas_de_referencia()
	_filas.add_theme_constant_override("separation", SEPARACION_DE_LA_CABECERA)
	_filas.add_child(_barra_de_pestanas())
	_pagina_del_teclado = _bloque_del_teclado()
	_pagina_del_joystick = _bloque_del_joystick()
	_filas.add_child(_pagina_del_teclado)
	_filas.add_child(_pagina_del_joystick)
	_filas.add_child(_aviso_sin_el_joystick())
	_crear_el_mensaje()
	poner_joystick_conectado(not Input.get_connected_joypads().is_empty())
	Input.joy_connection_changed.connect(_al_cambiar_un_joystick)
	_pintar()
	elegir_pestana(false)
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


## Cómo se lee una entrada. El nombre de una tecla lo da el motor, y sin traducir a la
## distribución del teclado: se lee el código físico como está.
static func nombre_de_la_entrada(tipo: int, codigo: int) -> String:
	if tipo == AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK:
		var del_joystick: String = AsignacionDeControles.NOMBRES_DE_LOS_BOTONES_DEL_JOYSTICK.get(
			codigo, "BOTÓN %d" % codigo
		)
		return del_joystick
	if tipo == AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE:
		var nombre: String = AsignacionDeControles.NOMBRES_DE_LOS_BOTONES.get(codigo, "")
		return nombre.to_upper()
	return String(
		NOMBRES_DE_LAS_TECLAS.get(codigo, OS.get_keycode_string(codigo as Key).to_upper())
	)


## Los valores que muestra al abrirse. Quien la abre los leyó del disco.
func preparar(asignacion: AsignacionDeControles) -> void:
	_asignacion = asignacion.copia()
	_pintar()


## Se abre en la pestaña del último dispositivo que el jugador usó, y lo decide quien la abre.
func abrir(con_el_joystick: bool = false) -> void:
	_cancelar_la_espera()
	elegir_pestana(con_el_joystick and _joystick_conectado)
	_pintar()
	visible = true
	var primero := (
		_primer_boton_del_joystick
		if con_el_joystick and _joystick_conectado
		else _primer_boton_del_teclado
	)
	primero.grab_focus(true)


func cerrar() -> void:
	if not visible:
		return
	_cancelar_la_espera()
	visible = false
	cerrada.emit()


## Atrás: cancela la espera de una entrada, y si no esperaba nada, cierra la pantalla.
func retroceder() -> void:
	if capturando():
		_cancelar_la_espera()
		_pintar()
		return
	cerrar()


func capturando() -> bool:
	return _esperando_ranura >= 0


## Pide la próxima entrada para esa ranura. Es lo que hace apretar la celda.
func elegir(accion: StringName, ranura: int) -> void:
	_esperando_accion = accion
	_esperando_ranura = ranura
	_limpiar_el_aviso()
	_pintar()


## Muestra una pestaña y esconde la otra. Sin joystick, JOYSTICK muestra su aviso y ninguna acción.
## No toca el foco: eso es de quien la cambia.
func elegir_pestana(del_joystick: bool) -> void:
	_con_el_joystick = del_joystick
	_pagina_del_teclado.visible = not del_joystick
	_pagina_del_joystick.visible = del_joystick and _joystick_conectado
	_aviso_sin_joystick.visible = del_joystick and not _joystick_conectado
	_pestana_del_teclado.set_pressed_no_signal(not del_joystick)
	_pestana_del_joystick.set_pressed_no_signal(del_joystick)
	_pestana_del_teclado.modulate.a = 1.0 if not del_joystick else OPACIDAD_DE_LA_PESTANA_APAGADA
	if not _joystick_conectado:
		_pestana_del_joystick.modulate.a = OPACIDAD_DE_LA_PESTANA_SIN_JOYSTICK
	else:
		_pestana_del_joystick.modulate.a = 1.0 if del_joystick else OPACIDAD_DE_LA_PESTANA_APAGADA
	_limpiar_el_aviso()


func pestana_del_joystick() -> bool:
	return _con_el_joystick


## Habilita o apaga la pestaña JOYSTICK y muestra u oculta L1 y R1. La pestaña elegida no cambia,
## salvo JOYSTICK cuando se va el joystick: pasa a TECLADO Y MOUSE.
func poner_joystick_conectado(conectado: bool) -> void:
	_joystick_conectado = conectado
	_aviso_del_joystick.text = TEXTO_DEL_JOYSTICK_CONECTADO if conectado else ""
	_ajustar_las_columnas(_pagina_del_joystick)
	for pildora: GlifoDeEntrada in _pildoras_de_las_pestanas:
		pildora.visible = conectado
	if _con_el_joystick and not conectado and visible:
		_cambiar_de_pestana(false)
		return
	elegir_pestana(_con_el_joystick and conectado)


func aviso_del_joystick() -> String:
	return _aviso_del_joystick.text


## El aviso de la última entrada que no se pudo asignar, o vacío.
func aviso() -> String:
	return _texto_del_aviso


## Los renglones de una pestaña, con los dos bloques juntos.
func filas(del_joystick: bool = false) -> Array[HBoxContainer]:
	var pagina := _pagina_del_joystick if del_joystick else _pagina_del_teclado
	var todas: Array[HBoxContainer] = []
	for nodo: Node in pagina.find_children("*", "HBoxContainer", true, false):
		var fila := nodo as HBoxContainer
		if fila.theme_type_variation == &"FilaDeConfiguraciones":
			todas.append(fila)
	return todas


func marco() -> Control:
	return _marco


func boton_de(accion: StringName, ranura: int) -> Button:
	return _botones[_clave(accion, ranura)]


## Lo que dice la celda de una ranura: su entrada o la espera. Vacía no dice nada.
func texto_de(accion: StringName, ranura: int) -> String:
	var glifo: GlifoDeEntrada = _glifos.get(_clave(accion, ranura))
	if glifo == null:
		return _texto_de_la_espera()
	return glifo.texto


## El glifo de la celda de una ranura, o nulo si espera una entrada.
func glifo_de(accion: StringName, ranura: int) -> GlifoDeEntrada:
	return _glifos.get(_clave(accion, ranura))


## Atiende un evento y contesta si se lo comió. Esperando una entrada, se la come toda. Sin
## esperar, se come L1 y R1, que cambian de pestaña, y SUPR sobre una celda con el foco.
func atender(evento: InputEvent) -> bool:
	if not visible or not evento.is_pressed() or evento.is_echo():
		return false
	var entrada := AjusteDePreferencias.entrada_de(evento)
	if entrada == AjusteDePreferencias.SIN_ENTRADA:
		return false
	if not capturando():
		return _atender_sin_espera(entrada)
	if _asignacion.cancela_la_espera(entrada.x, entrada.y):
		_cancelar_la_espera()
		_pintar()
		return true
	if not AsignacionDeControles.acepta(
		_esperando_accion, entrada.x, entrada.y, en_la_web, _esperando_ranura
	):
		return true
	var actual := _asignacion.entrada(_esperando_accion, _esperando_ranura)
	var estaba_vacia := Vector2i(actual["tipo"], actual["codigo"]) == AsignacionDeControles.VACIA
	var cambio := _asignacion.asignar(
		_esperando_accion,
		_esperando_ranura,
		entrada.x as AsignacionDeControles.TipoDeEntrada,
		entrada.y,
		en_la_web
	)
	_cancelar_la_espera()
	_pintar()
	if cambio:
		controles_cambiados.emit(_asignacion.copia())
	elif estaba_vacia:
		_avisar_de_quien_es(entrada)
	return true


func _input(evento: InputEvent) -> void:
	if atender(evento):
		get_viewport().set_input_as_handled()


func _atender_sin_espera(entrada: Vector2i) -> bool:
	var del_joystick := entrada.x == AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK
	if del_joystick and entrada.y == JOY_BUTTON_LEFT_SHOULDER:
		_cambiar_de_pestana(false)
		return true
	if del_joystick and entrada.y == JOY_BUTTON_RIGHT_SHOULDER:
		_cambiar_de_pestana(true)
		return true
	if entrada == Vector2i(AsignacionDeControles.TipoDeEntrada.TECLA, KEY_DELETE):
		return _vaciar_la_celda_con_el_foco()
	return false


func _cambiar_de_pestana(del_joystick: bool) -> void:
	if del_joystick == _con_el_joystick:
		return
	elegir_pestana(del_joystick)
	var primero := _primer_boton_del_joystick if del_joystick else _primer_boton_del_teclado
	primero.grab_focus(true)


func _vaciar_la_celda_con_el_foco() -> bool:
	for clave: String in _botones:
		var boton: Button = _botones[clave]
		if not boton.has_focus():
			continue
		var celda: Array = _celdas[clave]
		if _asignacion.vaciar(celda[0], celda[1]):
			_pintar()
			controles_cambiados.emit(_asignacion.copia())
		return true
	return false


## Una entrada que no entró a una secundaria vacía porque es la principal de otra acción.
func _avisar_de_quien_es(entrada: Vector2i) -> void:
	var duena := _asignacion.principal_que_ocupa(entrada)
	if duena != &"":
		_poner_el_aviso(
			"%s %s" % [TEXTO_DEL_AVISO, AsignacionDeControles.nombre_de_la_accion(duena)]
		)


func _limpiar_el_aviso() -> void:
	_poner_el_aviso("")


func _poner_el_aviso(texto: String) -> void:
	_texto_del_aviso = texto
	_mostrar_el_mensaje()


## Esperando una entrada, el mensaje dice cuál; si no, dice el aviso, o nada.
func _mostrar_el_mensaje() -> void:
	_mensaje.text = _texto_de_la_espera() if capturando() else _texto_del_aviso


func _texto_de_la_espera() -> String:
	if AsignacionDeControles.es_del_joystick(_esperando_accion, _esperando_ranura):
		return TEXTO_DE_ESPERA_DEL_JOYSTICK
	return TEXTO_DE_ESPERA


func _barra_de_pestanas() -> HBoxContainer:
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 16)
	barra.alignment = BoxContainer.ALIGNMENT_CENTER
	var izquierda := GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PILDORA, "L1")
	var derecha := GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PILDORA, "R1")
	_pildoras_de_las_pestanas = [izquierda, derecha]
	barra.add_child(izquierda)
	_pestana_del_teclado = _pestana(TEXTO_DEL_TECLADO, DibujoDeDispositivo.Dispositivo.TECLADO)
	_pestana_del_joystick = _pestana(TEXTO_DEL_JOYSTICK, DibujoDeDispositivo.Dispositivo.MANDO)
	_pestana_del_teclado.pressed.connect(elegir_pestana.bind(false))
	_pestana_del_joystick.pressed.connect(elegir_pestana.bind(true))
	barra.add_child(_pestana_del_teclado)
	barra.add_child(_pestana_del_joystick)
	barra.add_child(derecha)
	return barra


func _pestana(texto: String, dispositivo: DibujoDeDispositivo.Dispositivo) -> Button:
	var pestana := Button.new()
	pestana.theme_type_variation = &"BotonDelMenu"
	pestana.toggle_mode = true
	pestana.custom_minimum_size = Vector2(ANCHO_DE_LA_PESTANA, ALTO_DE_LA_PESTANA)
	var contenido := HBoxContainer.new()
	contenido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenido.alignment = BoxContainer.ALIGNMENT_CENTER
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_theme_constant_override("separation", 16)
	var dibujo := DibujoDeDispositivo.new()
	dibujo.dispositivo = dispositivo
	contenido.add_child(dibujo)
	var rotulo := _etiqueta(texto)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contenido.add_child(rotulo)
	pestana.add_child(contenido)
	return pestana


## En su lugar, la pestaña JOYSTICK sin joystick: sólo el aviso de conectar uno.
func _aviso_sin_el_joystick() -> Label:
	_aviso_sin_joystick = _etiqueta(TEXTO_SIN_JOYSTICK)
	_aviso_sin_joystick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_sin_joystick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aviso_sin_joystick.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aviso_sin_joystick.modulate.a = OPACIDAD_DEL_TEXTO_APAGADO
	return _aviso_sin_joystick


## La página con su cabecera en un renglón: a la izquierda lo que acompaña a los nombres y, a la
## derecha, el título de cada columna. Los renglones miden lo mismo y los separa lo mismo.
func _bloque(a_la_izquierda: Control, a_la_derecha: Array[Control] = []) -> VBoxContainer:
	var bloque := VBoxContainer.new()
	bloque.theme_type_variation = &"ColumnaDelMenu"
	bloque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bloque.add_theme_constant_override("separation", SEPARACION_DE_LAS_FILAS)
	var encabezado := HBoxContainer.new()
	encabezado.add_theme_constant_override("separation", SEPARACION_DE_LAS_COLUMNAS)
	encabezado.custom_minimum_size.y = ALTO_DE_LA_FILA
	encabezado.add_child(a_la_izquierda)
	for control: Control in a_la_derecha:
		encabezado.add_child(control)
	bloque.add_child(encabezado)
	return bloque


func _bloque_del_teclado() -> VBoxContainer:
	var bloque := _bloque(
		_etiqueta(""),
		[_titulo_de_la_columna(TEXTO_DE_PRINCIPAL), _titulo_de_la_columna(TEXTO_DE_SECUNDARIA)]
	)
	for accion: StringName in AsignacionDeControles.ACCIONES:
		var fila := _fila_con_nombre(AsignacionDeControles.nombre_de_la_accion(accion))
		fila.add_child(_celda(accion, AsignacionDeControles.RANURA_PRINCIPAL))
		fila.add_child(_celda(accion, AsignacionDeControles.RANURA_SECUNDARIA))
		if _primer_boton_del_teclado == null:
			_primer_boton_del_teclado = boton_de(accion, AsignacionDeControles.RANURA_PRINCIPAL)
		bloque.add_child(fila)
	return bloque


func _bloque_del_joystick() -> VBoxContainer:
	_aviso_del_joystick = _etiqueta("")
	_aviso_del_joystick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bloque := _bloque(_aviso_del_joystick)
	for accion: StringName in AsignacionDeControles.ACCIONES_CON_BOTON:
		var fila := _fila_con_nombre(AsignacionDeControles.nombre_de_la_accion(accion))
		fila.add_child(_celda(accion, AsignacionDeControles.RANURA_DEL_JOYSTICK))
		fila.add_child(_hueco())
		if _primer_boton_del_joystick == null:
			_primer_boton_del_joystick = boton_de(accion, AsignacionDeControles.RANURA_DEL_JOYSTICK)
		bloque.add_child(fila)
	return bloque


## Abajo, debajo de la línea del pie y a la izquierda de VOLVER: no pisa la lista.
func _crear_el_mensaje() -> void:
	_mensaje = _etiqueta("")
	_mensaje.position = POSICION_DEL_MENSAJE
	_marco.add_child(_mensaje)


func _fila_con_nombre(nombre: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.theme_type_variation = &"FilaDeConfiguraciones"
	fila.custom_minimum_size.y = ALTO_DE_LA_FILA
	fila.add_theme_constant_override("separation", SEPARACION_DE_LAS_COLUMNAS)
	var etiqueta := _etiqueta(nombre)
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(etiqueta)
	return fila


func _etiqueta(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.theme_type_variation = &"TextoDelMenu"
	return etiqueta


func _titulo_de_la_columna(texto: String) -> Label:
	var etiqueta := _etiqueta(texto)
	etiqueta.modulate.a = OPACIDAD_DEL_TEXTO_APAGADO
	return etiqueta


## Una celda es el lugar de su columna y lleva adentro el botón de su tecla, pegado al borde
## izquierdo. El botón llena la columna y muestra sólo el glifo: el recuadro aparece con el
## foco, con el mouse encima o esperando una entrada. El ancho de la columna lo pone
## `_ajustar_las_columnas`.
func _celda(accion: StringName, ranura: int) -> HBoxContainer:
	var lugar := HBoxContainer.new()
	var boton := Button.new()
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.theme_type_variation = &"BotonDelMenu"
	boton.custom_minimum_size.y = GlifoDeEntrada.ALTO
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boton.add_theme_stylebox_override("normal", _celda_sin_elegir)
	boton.add_theme_stylebox_override("disabled", _celda_sin_elegir)
	for estado: String in ["hover", "pressed", "hover_pressed", "focus"]:
		boton.add_theme_stylebox_override(estado, _celda_elegida)
	boton.pressed.connect(elegir.bind(accion, ranura))
	_botones[_clave(accion, ranura)] = boton
	_celdas[_clave(accion, ranura)] = [accion, ranura]
	lugar.add_child(boton)
	return lugar


## Los clics son las teclas más anchas: su ancho es el de todas. Se miden dentro de la pantalla, con
## su letra, y no se ven.
func _crear_las_teclas_de_referencia() -> void:
	for boton: int in [AsignacionDeControles.BOTON_IZQUIERDO, AsignacionDeControles.BOTON_DERECHO]:
		var referencia := GlifoDeEntrada.de_una_tecla(
			nombre_de_la_entrada(AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE, boton)
		)
		referencia.visible = false
		_marco.add_child(referencia)
		_teclas_de_referencia.append(referencia)


func _crear_los_estilos_de_la_celda() -> void:
	_celda_sin_elegir.set_content_margin_all(4.0)
	_celda_elegida.bg_color = Color(COLOR_DE_LA_CELDA_ELEGIDA, 0.14)
	_celda_elegida.border_color = COLOR_DE_LA_CELDA_ELEGIDA
	_celda_elegida.set_border_width_all(2)
	_celda_elegida.set_content_margin_all(4.0)
	_celda_elegida.set_expand_margin_all(SOBRESALE_EL_RECUADRO)


## Lo que ocupa el lugar de la segunda celda en un renglón que sólo tiene una.
func _hueco() -> Control:
	var hueco := Control.new()
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hueco


func _clave(accion: StringName, ranura: int) -> String:
	return "%s/%d" % [accion, ranura]


func _cancelar_la_espera() -> void:
	_esperando_accion = &""
	_esperando_ranura = -1


func _al_cambiar_un_joystick(_dispositivo: int, _conectado: bool) -> void:
	poner_joystick_conectado(not Input.get_connected_joypads().is_empty())


## Cada celda dice su entrada con su glifo, un recuadro punteado si está vacía, o el recuadro de
## elegida si espera una entrada. Lo que espera lo dice el mensaje de abajo.
func _pintar() -> void:
	for guardada: Dictionary in _asignacion.entradas():
		var accion: StringName = guardada["accion"]
		var ranura: int = guardada["ranura"]
		var clave := _clave(accion, ranura)
		var boton: Button = _botones[clave]
		var entrada := Vector2i(guardada["tipo"], guardada["codigo"])
		_quitar_el_glifo(clave, boton)
		var esperando := (
			capturando() and accion == _esperando_accion and ranura == _esperando_ranura
		)
		boton.add_theme_stylebox_override(
			"normal", _celda_elegida if esperando else _celda_sin_elegir
		)
		if esperando:
			continue
		var glifo := (
			GlifoDeEntrada.de_una_ranura_libre()
			if entrada == AsignacionDeControles.VACIA
			else GlifoDeEntrada.de_la_entrada(entrada, nombre_de_la_entrada(entrada.x, entrada.y))
		)
		glifo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		boton.add_child(glifo)
		_glifos[clave] = glifo
	_mostrar_el_mensaje()
	_ajustar_las_columnas(_pagina_del_teclado)
	_ajustar_las_columnas(_pagina_del_joystick)


## Cada columna de una pestaña mide lo mismo en todos sus renglones: la de los nombres, lo que mide
## el más largo; las de las celdas, el glifo más ancho de la pestaña o su cabecera, y en TECLADO Y
## MOUSE también un clic. Cada tecla arranca en el borde izquierdo de su columna y la llena. La
## lista queda del ancho de lo que dice. En JOYSTICK la segunda columna queda vacía.
func _ajustar_las_columnas(pagina: VBoxContainer) -> void:
	var renglones: Array[HBoxContainer] = [pagina.get_child(0) as HBoxContainer]
	for hijo: Node in pagina.get_children():
		if hijo is HBoxContainer and hijo != renglones[0]:
			renglones.append(hijo as HBoxContainer)
	var nombre := 0.0
	var columna := 0.0
	var segunda := 0.0
	for renglon: HBoxContainer in renglones:
		nombre = maxf(nombre, (renglon.get_child(0) as Control).get_minimum_size().x)
		for glifo: Node in renglon.find_children("*", "GlifoDeEntrada", true, false):
			var ancho := (glifo as GlifoDeEntrada).get_minimum_size().x
			columna = maxf(columna, ancho)
		if renglon.get_child_count() > 2:
			segunda = maxf(segunda, (renglon.get_child(2) as Control).get_minimum_size().x)
	if pagina == _pagina_del_teclado:
		for referencia: GlifoDeEntrada in _teclas_de_referencia:
			columna = maxf(columna, referencia.get_minimum_size().x)
	for titulo: int in range(1, renglones[0].get_child_count()):
		columna = maxf(columna, (renglones[0].get_child(titulo) as Control).get_minimum_size().x)
	if pagina == _pagina_del_teclado:
		segunda = columna
	for renglon: HBoxContainer in renglones:
		(renglon.get_child(0) as Control).custom_minimum_size.x = nombre
		for i: int in range(1, renglon.get_child_count()):
			(renglon.get_child(i) as Control).custom_minimum_size.x = columna if i == 1 else segunda


func _quitar_el_glifo(clave: String, boton: Button) -> void:
	var anterior: GlifoDeEntrada = _glifos.get(clave)
	if anterior == null:
		return
	boton.remove_child(anterior)
	anterior.queue_free()
	_glifos.erase(clave)


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)

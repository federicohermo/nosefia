## Controles: una pestaña por dispositivo, TECLADO Y MOUSE y JOYSTICK, y en cada una dos bloques,
## EN EL LOCAL con las acciones y EN LOS MENÚS con lo que no se cambia.
##
## En TECLADO Y MOUSE cada acción tiene una celda PRINCIPAL y otra SECUNDARIA. Se elige una celda,
## y apretar una tecla o un botón del mouse se la asigna; SUPR vacía una secundaria. En JOYSTICK
## cada acción de botón tiene la celda de su botón, que se reasigna igual. Lo demás se muestra
## con la marca FIJO y no se elige. Cada entrada se dibuja con su glifo.
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
const TEXTO_DE_ESPERA := "PRESIONÁ UNA TECLA"
const TEXTO_DE_ESPERA_DEL_JOYSTICK := "PRESIONÁ UN BOTÓN"
const TEXTO_DEL_TECLADO := "TECLADO Y MOUSE"
const TEXTO_DEL_JOYSTICK := "JOYSTICK"
const TEXTO_DEL_JOYSTICK_CONECTADO := "● JOYSTICK CONECTADO"
const TEXTO_EN_EL_LOCAL := "EN EL LOCAL"
const TEXTO_EN_LOS_MENUS := "EN LOS MENÚS"
const TEXTO_DE_PRINCIPAL := "PRINCIPAL"
const TEXTO_DE_SECUNDARIA := "SECUNDARIA"
const TEXTO_DE_LA_RANURA_VACIA := "—"
const TEXTO_FIJO := "FIJO"
const TEXTO_DEL_AVISO := "YA ES LA PRINCIPAL DE"
const TEXTO_DE_MOVIMIENTO := "MOVIMIENTO"
const TEXTO_DE_VISION := "VISIÓN"
const TEXTO_DE_NAVEGAR := "NAVEGAR"
const TEXTO_DE_ACEPTAR := "ACEPTAR"
const TEXTO_DE_CAMBIAR := "CAMBIAR"
const TEXTO_DE_BORRAR := "BORRAR"
const TEXTO_DE_LA_PESTANA := "PESTAÑA"
const TEXTO_DE_LAS_FLECHAS := "FLECHAS"
const TEXTO_DE_ENTER := "ENTER"
const TEXTO_DE_SUPR := "SUPR"
const TEXTO_DE_START := "START"
const TEXTO_DEL_MOUSE := "MOUSE"
const ANCHO_DEL_NOMBRE := 530.0
const ANCHO_DEL_NOMBRE_DE_LOS_MENUS := 140.0
const ANCHO_DE_LA_CELDA := 260.0
const ANCHO_DE_LOS_MENUS := 430.0
const ANCHO_DE_LOS_GLIFOS_DE_LOS_MENUS := 190.0
const ANCHO_DE_LA_MARCA := 64.0
const ANCHO_DE_LA_PESTANA := 420.0
const ALTO_DE_LA_PESTANA := 64.0
const ALTO_DE_LA_FILA := 44.0
const SEPARACION_DE_LAS_FILAS := 6
const LETRA_CHICA := 24
const COLOR_DE_LA_CELDA_ELEGIDA := Color("d8b468")
const OPACIDAD_DE_LA_MARCA := 0.7
const OPACIDAD_DE_LO_FIJO := 0.55
const OPACIDAD_DE_LA_PESTANA_APAGADA := 0.5
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
var _pagina_del_teclado: HBoxContainer
var _pagina_del_joystick: HBoxContainer
var _pestana_del_teclado: Button
var _pestana_del_joystick: Button
var _aviso_del_joystick: Label
var _aviso: Label
var _ayuda: HBoxContainer
var _glifos_de_la_ayuda: Array[GlifoDeEntrada] = []
var _dibujos_del_volver: HBoxContainer
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
	_filas.add_child(_barra_de_pestanas())
	_pagina_del_teclado = _pagina([_bloque_del_teclado(), _bloque_de_los_menus_del_teclado()])
	_pagina_del_joystick = _pagina([_bloque_del_joystick(), _bloque_de_los_menus_del_joystick()])
	_filas.add_child(_pagina_del_teclado)
	_filas.add_child(_pagina_del_joystick)
	_crear_el_aviso_y_la_ayuda()
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
	elegir_pestana(con_el_joystick)
	poner_joystick_conectado(not Input.get_connected_joypads().is_empty())
	_pintar()
	visible = true
	var primero := _primer_boton_del_joystick if con_el_joystick else _primer_boton_del_teclado
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


## Muestra una pestaña y esconde la otra. No toca el foco: eso es de quien la cambia.
func elegir_pestana(del_joystick: bool) -> void:
	_con_el_joystick = del_joystick
	_pagina_del_teclado.visible = not del_joystick
	_pagina_del_joystick.visible = del_joystick
	_pestana_del_teclado.set_pressed_no_signal(not del_joystick)
	_pestana_del_joystick.set_pressed_no_signal(del_joystick)
	_pestana_del_teclado.modulate.a = 1.0 if not del_joystick else OPACIDAD_DE_LA_PESTANA_APAGADA
	_pestana_del_joystick.modulate.a = 1.0 if del_joystick else OPACIDAD_DE_LA_PESTANA_APAGADA
	_limpiar_el_aviso()
	_pintar_la_ayuda()


func pestana_del_joystick() -> bool:
	return _con_el_joystick


## El aviso de la pestaña JOYSTICK se actualiza, y la pestaña elegida no cambia.
func poner_joystick_conectado(conectado: bool) -> void:
	_aviso_del_joystick.text = TEXTO_DEL_JOYSTICK_CONECTADO if conectado else ""


func aviso_del_joystick() -> String:
	return _aviso_del_joystick.text


## El aviso de la última entrada que no se pudo asignar, o vacío.
func aviso() -> String:
	return _aviso.text


## Los renglones de una pestaña, con los dos bloques juntos. Los de lo fijo llevan `fijo` como meta.
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


## Lo que dice la celda de una ranura: su entrada, la espera, o «—» si está vacía.
func texto_de(accion: StringName, ranura: int) -> String:
	var clave := _clave(accion, ranura)
	var boton: Button = _botones[clave]
	if not boton.text.is_empty():
		return boton.text
	var glifo: GlifoDeEntrada = _glifos[clave]
	return glifo.texto


## El glifo de la celda de una ranura, o nulo si está vacía o esperando.
func glifo_de(accion: StringName, ranura: int) -> GlifoDeEntrada:
	return _glifos.get(_clave(accion, ranura))


## Los glifos de la ayuda de abajo, en el orden en que se leen.
func glifos_de_la_ayuda() -> Array[GlifoDeEntrada]:
	return _glifos_de_la_ayuda


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
		_aviso.text = "%s %s" % [TEXTO_DEL_AVISO, AsignacionDeControles.nombre_de_la_accion(duena)]


func _limpiar_el_aviso() -> void:
	_aviso.text = ""


func _barra_de_pestanas() -> HBoxContainer:
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 16)
	barra.add_child(GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PILDORA, "L1"))
	_pestana_del_teclado = _pestana(TEXTO_DEL_TECLADO, DibujoDeDispositivo.Dispositivo.TECLADO)
	_pestana_del_joystick = _pestana(TEXTO_DEL_JOYSTICK, DibujoDeDispositivo.Dispositivo.MANDO)
	_pestana_del_teclado.pressed.connect(elegir_pestana.bind(false))
	_pestana_del_joystick.pressed.connect(elegir_pestana.bind(true))
	barra.add_child(_pestana_del_teclado)
	barra.add_child(_pestana_del_joystick)
	barra.add_child(GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PILDORA, "R1"))
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


func _pagina(bloques: Array[VBoxContainer]) -> HBoxContainer:
	var pagina := HBoxContainer.new()
	pagina.add_theme_constant_override("separation", 48)
	for bloque: VBoxContainer in bloques:
		pagina.add_child(bloque)
	return pagina


## El bloque con su encabezado en un renglón: el título a la izquierda y, a la derecha, lo que
## acompaña a la columna.
func _bloque(titulo: String, a_la_derecha: Array[Control] = []) -> VBoxContainer:
	var bloque := VBoxContainer.new()
	bloque.theme_type_variation = &"ColumnaDelMenu"
	bloque.add_theme_constant_override("separation", SEPARACION_DE_LAS_FILAS)
	var encabezado := HBoxContainer.new()
	encabezado.add_theme_constant_override("separation", 16)
	encabezado.custom_minimum_size.y = ALTO_DE_LA_FILA
	var rotulo := _etiqueta(titulo)
	rotulo.modulate.a = OPACIDAD_DE_LO_FIJO
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	encabezado.add_child(rotulo)
	for control: Control in a_la_derecha:
		encabezado.add_child(control)
	bloque.add_child(encabezado)
	return bloque


func _bloque_del_teclado() -> VBoxContainer:
	var bloque := _bloque(
		TEXTO_EN_EL_LOCAL,
		[_titulo_de_la_columna(TEXTO_DE_PRINCIPAL), _titulo_de_la_columna(TEXTO_DE_SECUNDARIA)]
	)
	bloque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for accion: StringName in AsignacionDeControles.ACCIONES:
		var fila := _fila_con_nombre(AsignacionDeControles.nombre_de_la_accion(accion))
		var principal := _celda(accion, AsignacionDeControles.RANURA_PRINCIPAL)
		fila.add_child(principal)
		fila.add_child(_celda(accion, AsignacionDeControles.RANURA_SECUNDARIA))
		if _primer_boton_del_teclado == null:
			_primer_boton_del_teclado = principal
		bloque.add_child(fila)
	bloque.add_child(_fila_fija(TEXTO_DE_VISION, [GlifoDeEntrada.de_un_mouse(0, TEXTO_DEL_MOUSE)]))
	return bloque


func _bloque_de_los_menus_del_teclado() -> VBoxContainer:
	var bloque := _bloque(TEXTO_EN_LOS_MENUS)
	bloque.custom_minimum_size.x = ANCHO_DE_LOS_MENUS
	bloque.add_child(
		_fila_fija(
			TEXTO_DE_NAVEGAR,
			[GlifoDeEntrada.de_una_tecla(TEXTO_DE_LAS_FLECHAS), GlifoDeEntrada.de_un_mouse()],
			true
		)
	)
	bloque.add_child(
		_fila_fija(
			TEXTO_DE_ACEPTAR,
			[
				GlifoDeEntrada.de_una_tecla(TEXTO_DE_ENTER),
				GlifoDeEntrada.de_un_mouse(AsignacionDeControles.BOTON_IZQUIERDO)
			],
			true
		)
	)
	var volver := _fila_fija(TEXTO_DE_VOLVER, [], true)
	_dibujos_del_volver = volver.get_child(1)
	bloque.add_child(volver)
	return bloque


func _bloque_del_joystick() -> VBoxContainer:
	_aviso_del_joystick = _etiqueta("")
	_aviso_del_joystick.add_theme_font_size_override("font_size", LETRA_CHICA)
	_aviso_del_joystick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bloque := _bloque(TEXTO_EN_EL_LOCAL, [_aviso_del_joystick])
	bloque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloque.add_child(
		_fila_fija(
			TEXTO_DE_MOVIMIENTO, [GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PALANCA, "L")]
		)
	)
	bloque.add_child(
		_fila_fija(TEXTO_DE_VISION, [GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PALANCA, "R")])
	)
	for accion: StringName in AsignacionDeControles.ACCIONES_CON_BOTON:
		var fila := _fila_con_nombre(AsignacionDeControles.nombre_de_la_accion(accion))
		var celda := _celda(accion, AsignacionDeControles.RANURA_DEL_JOYSTICK)
		fila.add_child(celda)
		fila.add_child(_hueco())
		if _primer_boton_del_joystick == null:
			_primer_boton_del_joystick = celda
		bloque.add_child(fila)
	bloque.add_child(
		_fila_fija(
			AsignacionDeControles.nombre_de_la_accion(AsignacionDeControles.PAUSA),
			[GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PILDORA, TEXTO_DE_START)]
		)
	)
	return bloque


func _bloque_de_los_menus_del_joystick() -> VBoxContainer:
	var bloque := _bloque(TEXTO_EN_LOS_MENUS)
	bloque.custom_minimum_size.x = ANCHO_DE_LOS_MENUS
	bloque.add_child(
		_fila_fija(
			TEXTO_DE_NAVEGAR,
			[
				GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.CRUCETA),
				GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PALANCA, "R")
			],
			true
		)
	)
	bloque.add_child(
		_fila_fija(TEXTO_DE_ACEPTAR, [GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.CRUZ)], true)
	)
	bloque.add_child(
		_fila_fija(
			TEXTO_DE_VOLVER, [GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.CIRCULO)], true
		)
	)
	return bloque


func _crear_el_aviso_y_la_ayuda() -> void:
	_aviso = _etiqueta("")
	_aviso.position = Vector2(160.0, 878.0)
	_marco.add_child(_aviso)
	_ayuda = HBoxContainer.new()
	_ayuda.add_theme_constant_override("separation", 12)
	_ayuda.position = Vector2(160.0, 928.0)
	_marco.add_child(_ayuda)


## La ayuda de abajo: con qué se cambia y con qué se vuelve, con lo que tenga asignado cada uno.
func _pintar_la_ayuda() -> void:
	for hijo: Node in _ayuda.get_children():
		_ayuda.remove_child(hijo)
		hijo.queue_free()
	_glifos_de_la_ayuda = []
	if _con_el_joystick:
		_agregar_a_la_ayuda(
			[
				GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PILDORA, "L1"),
				GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.PILDORA, "R1")
			],
			TEXTO_DE_LA_PESTANA
		)
		_agregar_a_la_ayuda(
			[GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.CRUZ)], TEXTO_DE_CAMBIAR
		)
		_agregar_a_la_ayuda(
			[GlifoDeEntrada.de_un_boton(GlifoDeEntrada.Forma.CIRCULO)], TEXTO_DE_VOLVER
		)
		return
	_agregar_a_la_ayuda([GlifoDeEntrada.de_una_tecla(TEXTO_DE_ENTER)], TEXTO_DE_CAMBIAR)
	_agregar_a_la_ayuda([GlifoDeEntrada.de_una_tecla(TEXTO_DE_SUPR)], TEXTO_DE_BORRAR)
	_agregar_a_la_ayuda([_glifo_de_pausa()], TEXTO_DE_VOLVER)


func _agregar_a_la_ayuda(glifos: Array[GlifoDeEntrada], texto: String) -> void:
	for glifo: GlifoDeEntrada in glifos:
		_ayuda.add_child(glifo)
		_glifos_de_la_ayuda.append(glifo)
	_ayuda.add_child(_etiqueta(texto))


## La entrada que tiene Pausa, como la tiene asignada ahora.
func _glifo_de_pausa() -> GlifoDeEntrada:
	var pausa := _asignacion.entrada(
		AsignacionDeControles.PAUSA, AsignacionDeControles.RANURA_PRINCIPAL
	)
	return GlifoDeEntrada.de_la_entrada(
		Vector2i(pausa["tipo"], pausa["codigo"]),
		nombre_de_la_entrada(pausa["tipo"], pausa["codigo"])
	)


## El renglón con el nombre a la izquierda y, a la derecha, lo que se muestra y no se elige.
## En el local, el glifo cae en la columna de las celdas y la marca en la de la secundaria. En los
## menús, los glifos van pegados a la marca.
func _fila_fija(
	nombre: String, glifos: Array[GlifoDeEntrada], de_los_menus: bool = false
) -> HBoxContainer:
	var fila := _fila_con_nombre(nombre, de_los_menus)
	fila.set_meta(&"fijo", true)
	var dibujos := HBoxContainer.new()
	dibujos.custom_minimum_size.x = (
		ANCHO_DE_LOS_GLIFOS_DE_LOS_MENUS if de_los_menus else ANCHO_DE_LA_CELDA
	)
	dibujos.alignment = (
		BoxContainer.ALIGNMENT_END if de_los_menus else BoxContainer.ALIGNMENT_CENTER
	)
	dibujos.add_theme_constant_override("separation", 12)
	for glifo: GlifoDeEntrada in glifos:
		dibujos.add_child(glifo)
	fila.add_child(dibujos)
	var marca := _etiqueta(TEXTO_FIJO)
	marca.add_theme_font_size_override("font_size", LETRA_CHICA)
	marca.custom_minimum_size.x = ANCHO_DE_LA_MARCA if de_los_menus else ANCHO_DE_LA_CELDA
	marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marca.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marca.modulate.a = OPACIDAD_DE_LA_MARCA
	fila.add_child(marca)
	fila.modulate.a = OPACIDAD_DE_LO_FIJO
	return fila


func _fila_con_nombre(nombre: String, de_los_menus: bool = false) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.theme_type_variation = &"FilaDeConfiguraciones"
	fila.custom_minimum_size.y = ALTO_DE_LA_FILA
	var etiqueta := _etiqueta(nombre)
	etiqueta.custom_minimum_size.x = (
		ANCHO_DEL_NOMBRE_DE_LOS_MENUS if de_los_menus else ANCHO_DEL_NOMBRE
	)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	etiqueta.custom_minimum_size.x = ANCHO_DE_LA_CELDA
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.modulate.a = OPACIDAD_DE_LO_FIJO
	return etiqueta


## Una celda muestra sólo su glifo: el recuadro aparece con el foco o con el mouse encima.
func _celda(accion: StringName, ranura: int) -> Button:
	var boton := Button.new()
	boton.theme_type_variation = &"BotonDelMenu"
	boton.custom_minimum_size = Vector2(ANCHO_DE_LA_CELDA, ALTO_DE_LA_FILA)
	boton.add_theme_font_size_override("font_size", LETRA_CHICA)
	boton.add_theme_stylebox_override("normal", _celda_sin_elegir)
	boton.add_theme_stylebox_override("disabled", _celda_sin_elegir)
	for estado: String in ["hover", "pressed", "hover_pressed", "focus"]:
		boton.add_theme_stylebox_override(estado, _celda_elegida)
	boton.pressed.connect(elegir.bind(accion, ranura))
	_botones[_clave(accion, ranura)] = boton
	_celdas[_clave(accion, ranura)] = [accion, ranura]
	return boton


func _crear_los_estilos_de_la_celda() -> void:
	_celda_sin_elegir.set_content_margin_all(4.0)
	_celda_elegida.bg_color = Color(COLOR_DE_LA_CELDA_ELEGIDA, 0.14)
	_celda_elegida.border_color = COLOR_DE_LA_CELDA_ELEGIDA
	_celda_elegida.set_border_width_all(2)
	_celda_elegida.set_content_margin_all(4.0)


## Lo que ocupa el lugar de la segunda celda en un renglón que sólo tiene una.
func _hueco() -> Control:
	var hueco := Control.new()
	hueco.custom_minimum_size.x = ANCHO_DE_LA_CELDA
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hueco


func _clave(accion: StringName, ranura: int) -> String:
	return "%s/%d" % [accion, ranura]


func _cancelar_la_espera() -> void:
	_esperando_accion = &""
	_esperando_ranura = -1


func _al_cambiar_un_joystick(_dispositivo: int, _conectado: bool) -> void:
	poner_joystick_conectado(not Input.get_connected_joypads().is_empty())


## Cada celda dice su entrada con su glifo, «—» si está vacía, o qué espera.
func _pintar() -> void:
	for guardada: Dictionary in _asignacion.entradas():
		var accion: StringName = guardada["accion"]
		var ranura: int = guardada["ranura"]
		var clave := _clave(accion, ranura)
		var boton: Button = _botones[clave]
		var entrada := Vector2i(guardada["tipo"], guardada["codigo"])
		_quitar_el_glifo(clave, boton)
		if capturando() and accion == _esperando_accion and ranura == _esperando_ranura:
			boton.text = (
				TEXTO_DE_ESPERA_DEL_JOYSTICK
				if AsignacionDeControles.es_del_joystick(accion, ranura)
				else TEXTO_DE_ESPERA
			)
		elif entrada == AsignacionDeControles.VACIA:
			boton.text = TEXTO_DE_LA_RANURA_VACIA
		else:
			boton.text = ""
			var glifo := GlifoDeEntrada.de_la_entrada(
				entrada, nombre_de_la_entrada(entrada.x, entrada.y)
			)
			glifo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			boton.add_child(glifo)
			_glifos[clave] = glifo
	_pintar_el_volver()
	_pintar_la_ayuda()


## El renglón de Volver de TECLADO Y MOUSE muestra la entrada que tenga Pausa.
func _pintar_el_volver() -> void:
	for hijo: Node in _dibujos_del_volver.get_children():
		_dibujos_del_volver.remove_child(hijo)
		hijo.queue_free()
	_dibujos_del_volver.add_child(_glifo_de_pausa())


func _quitar_el_glifo(clave: String, boton: Button) -> void:
	var anterior: GlifoDeEntrada = _glifos.get(clave)
	if anterior == null:
		return
	boton.remove_child(anterior)
	anterior.queue_free()
	_glifos.erase(clave)


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)

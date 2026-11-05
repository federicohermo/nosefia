## El dibujo conserva el scroll al ampliar: la foto se superpone al chat, no lo reconstruye.
##
## El chat entra y sale deslizándose por la derecha. La vista de destino se arma de una vez en los
## nodos reales; lo que se desliza es el chat, y lo que queda quieto debajo es la lista. Una copia
## congelada de la vista que se va ocupa el lugar que los nodos reales ya no pueden tener.
class_name PantallaDelCelular
extends CanvasLayer

signal chat_pedido(quien: Conversacion.Interlocutor)
signal volver_pedido
signal foto_pedida(indice: int)
signal tramo_pedido(identidad: String, tramo: String)
signal cierre_de_foto_pedido
## La opción que se ofrece debajo del último mensaje del chat, como la de la devolución.
signal opcion_elegida
signal celular_bajado
## Llegó a la mitad izquierda del encuadre, para la reflexión de cierre.
signal celular_desplazado
## El jugador pulsó uno de los dos botones de una queja: darle la razón o rechazarla.
signal respuesta_pedida(da_la_razon: bool)

## El jugador pulsó «Enviar» en la lista del pedido. Quien escucha lo envía, y la pantalla se
## repinta sola.
signal envio_del_pedido_pedido

enum Vista { NINGUNA, MENU, CHAT, CHAT_FIJO }

const RECORRIDO_COMPLETO := RecorridoDelCelular.DURACION
const PASO_MAXIMO := CabeceraConSolapa.PASO_MAXIMO
const TAMANO := Vector2(522.0, 928.0)
const CENTRO := Vector2(960.0, 540.0)
const CENTRO_A_LA_IZQUIERDA := Vector2(356.0, 540.0)
## Dónde queda el celular al lado del registro, en la pantalla conjunta.
const CENTRO_A_LA_DERECHA := Vector2(1624.0, 540.0)
const TEXTO_DE_DAR_LA_RAZON := "DARLE LA RAZÓN"
const TEXTO_DE_RECHAZAR := "RECHAZAR QUEJA"
## La captura de la transferencia: el tamaño del diseño y dónde va cada texto sobre la imagen.
const TAMANO_DE_LA_CAPTURA := Vector2i(736, 922)
const ZONA_DEL_IMPORTE := Rect2(0.0, 295.0, 736.0, 187.0)
const ZONA_DEL_DESTINO := Rect2(173.0, 511.0, 487.0, 113.0)
const ZONA_DEL_ORIGEN := Rect2(173.0, 742.0, 487.0, 113.0)
const TAMANO_DEL_IMPORTE := 96
const TAMANO_DE_LA_CUENTA := 36
const ALTO_DE_LA_CAPTURA_EN_EL_CHAT := 420.0
const FONDO_DE_NOTAS := Color("f0f4d1")
const TEXTO_DEL_MENU := "CHATS"
const TEXTO_DEL_RECORDATORIO := "Q"
const TINTA := Color("1a1a1a")
const PAPEL := Color("ffffff")
const BURBUJA := Color("0b343d")
const BURBUJA_RECIBIDA := Color("e0f3f4")
const BURBUJA_PROPIA := Color("f3f3ef")
const GRIS := Color("787878")
const GRIS_DE_LA_HORA := Color("7d8280")
const FONDO_DE_LA_FUNDA := Color("1a2426")
const BORDE_DE_LA_FUNDA := Color("3b4a4a")
const FONDO_DE_LA_PANTALLA := Color("c8c8c8")
const TAMANO_DEL_TEXTO := 28
const TAMANO_DE_LA_HORA := 20
const INTERLINEADO := 6
const ANCHO_MAXIMO_DEL_TEXTO := 336.0
const MASCARA_DEL_AVATAR := preload("res://assets/ui/manada/celular/avatar.tres")
const AVATAR_ENRIQUE := preload("res://assets/ui/manada/celular/enrique.png")
const AVATAR_ENRIQUE_MENU := preload("res://assets/ui/manada/celular/enrique_menu.png")
const SIMBOLOS_DE_CHAT := preload("res://assets/ui/manada/celular/simbolos_de_chat.ttf")
const RETRATO_ENRIQUE := "res://assets/ui/manada/enrique.png"
const BUSCAR := "Buscar contacto..."
const ROJO := Color("cc0d08")
const BURBUJA_CON_ERROR := Color("f7c9cc")
const TEXTO_DE_HACER_PEDIDO := "Hacer pedido"
const TEXTO_DE_ENVIAR := "Enviar"
const NARANJA_DEL_AVISO := Color("ffa024")
const DIAMETRO_DEL_AVISO := 30.0
const TAMANO_DEL_NUMERO_DEL_AVISO := 20
const FOTO := "Foto"
const MENSAJE := "Mensaje..."
const AYUDA := "ARRASTRÁ EL FONDO O USÁ LA RUEDA"
const UMBRAL_DEL_ARRASTRE := 6.0
const DIAS: Array[String] = [
	"HOY",
	"AYER",
	"HACE DOS DÍAS",
	"HACE TRES DÍAS",
	"HACE CUATRO DÍAS",
	"HACE CINCO DÍAS",
	"HACE SEIS DÍAS",
]

@export var _velo: Control
@export var _lienzo: Control
@export var _telefono: PanelContainer
@export var _titulo: Label
@export var _volver: Button
@export var _scroll: ScrollContainer
@export var _mensajes: VBoxContainer
@export var _foto_ampliada: PanelContainer
@export var _imagen: TextureRect
@export var _adjunto: RichTextLabel
@export var _recordatorio: HBoxContainer
@export var _cabecera: PanelContainer
@export var _avatar_del_chat: TextureRect
@export var _subtitulo: Label
@export var _opciones: Label
@export var _busqueda: LineEdit
@export var _pie: VBoxContainer
@export var _entrada: LineEdit
@export var _ayuda: Label
@export var _capa: Control
@export var _contenido: VBoxContainer
## El pedido de la noche: lo que el jugador marca en la lista de Hernán vive en él. Cambiarlo
## empieza de nuevo el chat.
var pedido: PedidoAlProveedor:
	set(valor):
		pedido = valor
		_chat_del_pedido = false
		_pintar_el_pedido()

var _recorrido := RecorridoDelCelular.new()
var _lateral: float = 0.0
var _destino_lateral: float = 0.0
var _ultimo: int = 0
var _ahora: Callable = Time.get_ticks_usec
var _bandeja: Bandeja
var _texto_de_la_opcion: String = ""
var _opcion: Button
var _basurero: Control
var _fuente_del_chat: FontVariation
var _jornada_de_referencia: int = 0
var _chat_de_notas: bool = false
var _historial: Array[Mensaje] = []
var _ancla: int = Celular.AL_FINAL
var _relleno: Control
var _burbujas: Array[PanelContainer] = []
var _recordatorio_pedido: bool = false
var _recordatorio_cubierto: bool = false
var _aviso: PanelContainer
var _estado_del_aviso := AvisoDeMensajesNuevos.new()
var _vibracion: Tween
var _duracion_de_la_vibracion: float = -1.0
var _base_del_recordatorio := Vector2.ZERO
var _desplazamiento_de_la_vibracion := Vector2.ZERO
var _chat_del_pedido: bool = false
var _lista_del_pedido: ListaDelPedido
var _hacer_pedido: Button
var _enviar_pedido: Button
var _barra_de_estado: BarraDeEstadoDelCelular
var _arrastrando: bool = false
var _posicion_del_arrastre: float = 0.0
var _desplazamiento_del_arrastre: float = 0.0
var _umbral_de_arrastre_superado: bool = false
var _con_velo: bool = true
var _respuestas: VBoxContainer = null
var _capturas: Dictionary[String, Texture2D] = {}
var _vista: Vista = Vista.NINGUNA
## Con la misma curva y duración que sube el celular. Su avance es cuánto del chat se ve:
## 0 es fuera del borde derecho y 1, en su lugar.
var _deslizamiento := RecorridoDelCelular.new()
var _lista_quieta: Control
var _chat_saliente: Control


func _ready() -> void:
	# El respaldo pertenece a este celular; el FontFile del tema compartido no se modifica.
	_fuente_del_chat = FontVariation.new()
	_fuente_del_chat.base_font = _adjunto.get_theme_font("normal_font")
	_fuente_del_chat.fallbacks = [SIMBOLOS_DE_CHAT]
	_volver.text = ""
	_volver.tooltip_text = "Volver al menú"
	var flecha := Line2D.new()
	flecha.name = "Flecha"
	flecha.points = PackedVector2Array([Vector2(6, -12), Vector2(-6, 0), Vector2(6, 12)])
	flecha.width = 3.0
	flecha.default_color = TINTA
	flecha.antialiased = true
	flecha.position = _volver.size / 2.0
	_volver.add_child(flecha)
	_volver.resized.connect(func() -> void: flecha.position = _volver.size / 2.0)
	_volver.pressed.connect(func() -> void: volver_pedido.emit())
	_busqueda.placeholder_text = BUSCAR
	_busqueda.text_changed.connect(_filtrar)
	_opciones.text = "..."
	_entrada.placeholder_text = MENSAJE
	_agregar_la_flecha_del_campo()
	_agregar_los_botones_del_pedido()
	_agregar_la_funda()
	_agregar_la_barra_de_estado()
	_ayuda.text = AYUDA
	_scroll.gui_input.connect(_al_tocar_el_historial)
	_scroll.get_v_scroll_bar().changed.connect(_actualizar_desplazamiento)
	_telefono.visibility_changed.connect(
		func() -> void:
			if _telefono.is_visible_in_tree():
				_enfocar_el_primero.call_deferred()
			else:
				_terminar_arrastre()
	)
	(_recordatorio.get_node("Tecla") as Label).text = TEXTO_DEL_RECORDATORIO
	_crear_el_aviso()
	_foto_ampliada.hide()
	_recordatorio.hide()
	_telefono.hide()
	_velo.hide()
	set_process(false)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _notification(que: int) -> void:
	if que == NOTIFICATION_UNPAUSED:
		_ultimo = _ahora.call()
	elif que == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_terminar_arrastre()


func _process(_delta: float) -> void:
	var ahora: int = _ahora.call()
	var segundos := clampf((ahora - _ultimo) / 1000000.0, 0.0, PASO_MAXIMO)
	_ultimo = ahora
	var llegaba := is_equal_approx(_lateral, _destino_lateral)
	var puede_correrse := _sube_antes_de_correrse()
	_recorrido.avanzar(segundos)
	_deslizamiento.avanzar(segundos)
	if puede_correrse:
		_lateral = move_toward(_lateral, _destino_lateral, segundos / RECORRIDO_COMPLETO)
	_pintar_posicion()
	_pintar_deslizamiento()
	if _desliza() and _deslizamiento.llego():
		_asentar(_hay_chat())
	if not llegaba and is_equal_approx(_lateral, 1.0):
		celular_desplazado.emit()
	if _recorrido.llego() and is_equal_approx(_lateral, _destino_lateral) and not _desliza():
		set_process(false)
		if _recorrido.destino() == 0.0:
			_lateral = 0.0
			_destino_lateral = 0.0
			_con_velo = true
			_telefono.hide()
			_velo.hide()
			celular_bajado.emit()


func subir() -> void:
	_mover_hacia(1.0)


func bajar() -> void:
	if _desliza():
		_asentar(_hay_chat())
	_mover_hacia(0.0)


func centrado() -> bool:
	return _recorrido.destino() == 1.0 and _recorrido.llego() and _destino_lateral == 0.0


## Sube el celular a la derecha, al lado del registro, sin velo que lo tape ni lo desenfoque.
func abrir_en_la_conjunta() -> void:
	_con_velo = false
	_lateral = -1.0
	_destino_lateral = -1.0
	subir()


## Lleva el teléfono, ya arriba o subiendo, hasta la mitad izquierda sin bajarlo.
func desplazar_a_la_izquierda() -> void:
	_destino_lateral = 1.0
	_ultimo = _ahora.call()
	set_process(true)


func mostrar_menu(bandeja: Bandeja) -> void:
	if _vista == Vista.CHAT and _puede_deslizar():
		_empezar_salida()
	elif _vista != Vista.MENU:
		_asentar(false)
	_vista = Vista.MENU
	_bandeja = bandeja
	_foto_ampliada.hide()
	_volver.hide()
	_titulo.text = TEXTO_DEL_MENU
	_titulo.add_theme_font_size_override("font_size", 38)
	_avatar_del_chat.hide()
	_subtitulo.hide()
	_opciones.show()
	_busqueda.show()
	_busqueda.text = ""
	_pie.hide()
	_componer(true)
	_filtrar("")
	_enfocar_el_primero.call_deferred()


## `primer_nuevo` es el lugar del mensaje con el que empieza el chat; sin él, abre en el último.
func mostrar_chat(
	conversacion: Conversacion,
	mensajes: Array[Mensaje],
	fijo: bool,
	jornada: int,
	primer_nuevo: int = Celular.AL_FINAL,
	con_respuestas: bool = false
) -> void:
	if _vista == Vista.MENU and not fijo and _puede_deslizar():
		_empezar_entrada()
	else:
		_asentar(true)
	_vista = Vista.CHAT_FIJO if fijo else Vista.CHAT
	_jornada_de_referencia = jornada
	_foto_ampliada.hide()
	_volver.visible = not fijo
	_titulo.text = conversacion.nombre.to_upper()
	_titulo.add_theme_font_size_override("font_size", 36)
	_avatar_del_chat.texture = _imagen_del_contacto(conversacion, false)
	_avatar_del_chat.show()
	_subtitulo.text = conversacion.rol
	_subtitulo.visible = not conversacion.rol.is_empty()
	_avatar_del_chat.material = null
	if _avatar_del_chat.texture == null:
		_avatar_del_chat.material = MASCARA_DEL_AVATAR
		var lisa := GradientTexture2D.new()
		var gradiente := Gradient.new()
		gradiente.colors = PackedColorArray([BURBUJA, BURBUJA])
		lisa.gradient = gradiente
		_avatar_del_chat.texture = lisa
	_opciones.hide()
	_busqueda.hide()
	_busqueda.release_focus()
	_pie.show()
	_chat_de_notas = conversacion.interlocutor == Conversacion.Interlocutor.NOTAS
	_chat_del_pedido = conversacion.ofrece_pedido and pedido != null
	_componer(false, _chat_de_notas)
	_limpiar()
	_ancla = primer_nuevo
	_historial = mensajes.duplicate()
	for indice in mensajes.size():
		var burbuja := _burbuja_de(mensajes[indice], indice)
		_burbujas.append(burbuja)
		_mensajes.add_child(burbuja)
	_ordenar_el_historial()
	_agregar_la_opcion()
	_pintar_el_pedido()
	_ofrecer_las_respuestas(con_respuestas)
	_acomodar_la_lectura.call_deferred(false)
	_enfocar_el_primero.call_deferred()


## Deja el foco en el primer control apretable del teléfono: un chat del menú, una respuesta, la
## opción o el botón de volver. Sin foco, la cruceta no tiene por dónde empezar.
func _enfocar_el_primero() -> void:
	if not _telefono.is_visible_in_tree():
		return
	if is_instance_valid(_respuestas) and FocoDeLaInterfaz.en_el_primero(_respuestas) != null:
		return
	FocoDeLaInterfaz.en_el_primero(_telefono)


## Ofrece una opción debajo del último mensaje. Sobrevive a que el chat se vuelva a dibujar.
func mostrar_opcion(texto: String) -> void:
	_texto_de_la_opcion = texto
	_agregar_la_opcion()
	if not _foto_ampliada.visible:
		_acomodar_la_lectura.call_deferred(true)


## La llegada no reconstruye el historial: conserva la foto ampliada y lo que se estaba leyendo.
func recibir(mensaje: Mensaje, indice: int, primer_nuevo: int = Celular.AL_FINAL) -> void:
	var barra := _scroll.get_v_scroll_bar()
	var al_final := _scroll.scroll_vertical >= int(barra.max_value - barra.page) - 1
	if primer_nuevo != Celular.AL_FINAL:
		_ancla = primer_nuevo
	var burbuja := _burbuja_de(mensaje, indice)
	var lugar := clampi(indice, 0, _historial.size())
	_historial.insert(lugar, mensaje)
	_burbujas.insert(lugar, burbuja)
	_mensajes.add_child(burbuja)
	_ordenar_el_historial()
	if opcion() != null:
		_mensajes.move_child(_opcion, _mensajes.get_child_count() - 1)
	_pintar_el_pedido()
	if al_final and not _foto_ampliada.visible:
		_acomodar_la_lectura.call_deferred(true)


func quitar_opcion() -> void:
	_texto_de_la_opcion = ""
	if is_instance_valid(_opcion):
		_opcion.queue_free()
	_opcion = null
	_actualizar_desplazamiento.call_deferred()


## El botón de la opción, si hay una a la vista.
func opcion() -> Button:
	return _opcion if is_instance_valid(_opcion) and not _opcion.is_queued_for_deletion() else null


func _agregar_la_opcion() -> void:
	if _texto_de_la_opcion.is_empty() or opcion() != null:
		return
	_opcion = Button.new()
	_opcion.text = _texto_de_la_opcion
	_opcion.theme_type_variation = &"BotonContinuar"
	_opcion.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_opcion.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_opcion.pressed.connect(func() -> void: opcion_elegida.emit())
	_mensajes.add_child(_opcion)
	_actualizar_desplazamiento.call_deferred()
	if not _foto_ampliada.visible:
		_opcion.grab_focus()


func ampliar(foto: Mensaje, adjunto: Mensaje) -> void:
	_imagen.texture = _textura_de(foto)
	# La primera leyenda se mide con su ancho final aun cuando el panel sigue oculto.
	# Medirla con ancho cero agrandaba el teléfono y recortaba el scroll del chat.
	var marco := _telefono.get_theme_stylebox("panel").get_minimum_size()
	var interior := _foto_ampliada.get_theme_stylebox("panel").get_minimum_size()
	_adjunto.size.x = maxf(1.0, _telefono.size.x - marco.x - interior.x)
	_adjunto.text = adjunto.texto if adjunto != null else ""
	_adjunto.visible = adjunto != null
	_foto_ampliada.show()
	_actualizar_desplazamiento()


func cerrar_foto() -> void:
	_foto_ampliada.hide()
	_actualizar_desplazamiento()


## La hora y el wifi de la barra de estado de arriba del teléfono.
func barra_de_estado() -> BarraDeEstadoDelCelular:
	return _barra_de_estado


func mostrar_recordatorio(se_ve: bool) -> void:
	_recordatorio_pedido = se_ve
	_recordatorio.visible = _recordatorio_pedido and not _recordatorio_cubierto


func cubrir_recordatorio(cubierto: bool) -> void:
	_recordatorio_cubierto = cubierto
	_recordatorio.visible = _recordatorio_pedido and not _recordatorio_cubierto


## El total de mensajes sin leer, tal como lo cuenta la bandeja. Sube: el ícono vibra.
func mostrar_no_leidos(cuantos: int) -> void:
	var vibra := _estado_del_aviso.cambiar(cuantos)
	_pintar_el_aviso()
	if vibra and _recordatorio.is_visible_in_tree():
		_vibrar()


## Mientras la persiana está baja, el total se junta y no se pinta.
func retener_los_no_leidos() -> void:
	_estado_del_aviso.retener()


func soltar_los_no_leidos() -> void:
	var vibra := _estado_del_aviso.soltar()
	_pintar_el_aviso()
	if vibra and _recordatorio.is_visible_in_tree():
		_vibrar()


func vibrando() -> bool:
	return _vibracion != null and _vibracion.is_valid()


func _pintar_la_vibracion(transcurrido: float) -> void:
	_desplazamiento_de_la_vibracion = AvisoDeMensajesNuevos.desplazamiento(
		transcurrido, _duracion_del_sonido()
	)
	_posar_el_recordatorio()


func _terminar_la_vibracion() -> void:
	if _vibracion != null:
		_vibracion.kill()
	_desplazamiento_de_la_vibracion = Vector2.ZERO
	_posar_el_recordatorio()


func _vibrar() -> void:
	var duracion := _duracion_del_sonido()
	if duracion <= 0.0:
		return
	if _vibracion != null:
		_vibracion.kill()
	_vibracion = create_tween()
	_vibracion.tween_method(_pintar_la_vibracion, 0.0, duracion, duracion)
	_vibracion.tween_callback(_terminar_la_vibracion)


func _duracion_del_sonido() -> float:
	if _duracion_de_la_vibracion < 0.0:
		_duracion_de_la_vibracion = AvisoDeMensajesNuevos.duracion_de_la_vibracion(
			TablaDeSonidos.desde_disco()
		)
	return _duracion_de_la_vibracion


func _posar_el_recordatorio() -> void:
	_recordatorio.position = (
		_base_del_recordatorio + _desplazamiento_de_la_vibracion * _recordatorio.scale
	)


func _pintar_el_aviso() -> void:
	_aviso.visible = _estado_del_aviso.se_ve()
	(_aviso.get_node("Numero") as Label).text = str(_estado_del_aviso.numero())


## El círculo cuelga del ícono y no del contenedor: un hijo de `HBoxContainer` se reacomoda.
func _crear_el_aviso() -> void:
	var icono: Control = _recordatorio.get_node("Icono")
	_aviso = PanelContainer.new()
	_aviso.name = "Aviso"
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.custom_minimum_size = Vector2(DIAMETRO_DEL_AVISO, DIAMETRO_DEL_AVISO)
	_aviso.size = _aviso.custom_minimum_size
	_aviso.position = Vector2(icono.custom_minimum_size.x, 0.0) - _aviso.size / 2.0
	_aviso.add_theme_stylebox_override(
		"panel", _estilo(NARANJA_DEL_AVISO, int(DIAMETRO_DEL_AVISO / 2.0))
	)
	var numero := _etiqueta("0", TINTA, TAMANO_DEL_NUMERO_DEL_AVISO)
	numero.name = "Numero"
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aviso.add_child(numero)
	icono.add_child(_aviso)
	_aviso.hide()


func _input(evento: InputEvent) -> void:
	if _arrastrando:
		_arrastrar(evento)
		return
	if not _telefono.visible:
		return
	var clic := evento as InputEventMouseButton
	if clic == null or not clic.pressed or clic.button_index != MOUSE_BUTTON_LEFT:
		return
	if _foto_ampliada.visible:
		get_viewport().set_input_as_handled()
		cierre_de_foto_pedido.emit()


func _al_tocar_el_historial(evento: InputEvent) -> void:
	if _empezar_arrastre(evento):
		_scroll.accept_event()


func _empezar_arrastre(evento: InputEvent) -> bool:
	var clic := evento as InputEventMouseButton
	if clic == null or not clic.pressed or clic.button_index != MOUSE_BUTTON_LEFT:
		return false
	if (
		not _telefono.is_visible_in_tree()
		or _foto_ampliada.visible
		or not _hay_historial_desplazable()
	):
		return false
	_arrastrando = true
	_umbral_de_arrastre_superado = false
	_posicion_del_arrastre = _scroll.scroll_vertical
	_desplazamiento_del_arrastre = 0.0
	_pintar_cursor(Control.CURSOR_DRAG)
	return true


func _arrastrar(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if not evento.pressed:
			if _umbral_de_arrastre_superado:
				get_viewport().set_input_as_handled()
			_terminar_arrastre()
	elif evento is InputEventMouseMotion:
		var escala := _scroll.get_global_transform_with_canvas().get_scale().y
		var desplazamiento: float = evento.relative.y / escala
		if not _umbral_de_arrastre_superado:
			_desplazamiento_del_arrastre += desplazamiento
			if absf(_desplazamiento_del_arrastre) < UMBRAL_DEL_ARRASTRE:
				return
			desplazamiento = _desplazamiento_del_arrastre
			_umbral_de_arrastre_superado = true
		var barra := _scroll.get_v_scroll_bar()
		_posicion_del_arrastre = clampf(
			_posicion_del_arrastre - desplazamiento,
			barra.min_value,
			maxf(barra.min_value, barra.max_value - barra.page)
		)
		_scroll.scroll_vertical = roundi(_posicion_del_arrastre)
		get_viewport().set_input_as_handled()


func _terminar_arrastre() -> void:
	if not _arrastrando:
		return
	_arrastrando = false
	_umbral_de_arrastre_superado = false
	_desplazamiento_del_arrastre = 0.0
	_actualizar_desplazamiento()


func _hay_historial_desplazable() -> bool:
	var barra := _scroll.get_v_scroll_bar()
	return _pie.visible and barra.max_value - barra.page > barra.min_value


func _actualizar_desplazamiento() -> void:
	var desplazable := _hay_historial_desplazable() and not _foto_ampliada.visible
	if _arrastrando and (not desplazable or not _telefono.is_visible_in_tree()):
		_terminar_arrastre()
		return
	_ayuda.modulate.a = 1.0 if desplazable else 0.0
	var forma: Control.CursorShape = (
		Control.CURSOR_POINTING_HAND if desplazable else Control.CURSOR_ARROW
	)
	if _arrastrando:
		forma = Control.CURSOR_DRAG
	_pintar_cursor(forma)


func _pintar_cursor(forma: Control.CursorShape) -> void:
	_scroll.mouse_default_cursor_shape = forma
	for hijo: Node in _mensajes.find_children("*", "Control", true, false):
		var control := hijo as Control
		if control.mouse_filter == Control.MOUSE_FILTER_PASS:
			control.mouse_default_cursor_shape = forma


func _sube_antes_de_correrse() -> bool:
	return _recorrido.destino() == 0.0 or _recorrido.llego()


func _mover_hacia(destino: float) -> void:
	_recorrido.ir_a(destino)
	_ultimo = _ahora.call()
	if destino == 1.0:
		_telefono.show()
		_velo.visible = _con_velo
	set_process(true)
	_pintar_posicion()


## Con el celular arriba y quieto, cambiar de vista se desliza. Si sube o baja, es inmediato.
func _puede_deslizar() -> bool:
	return _recorrido.destino() == 1.0 and _recorrido.llego() and _telefono.is_visible_in_tree()


func _desliza() -> bool:
	return _lista_quieta != null or _chat_saliente != null


func _hay_chat() -> bool:
	return _vista == Vista.CHAT or _vista == Vista.CHAT_FIJO


## El chat entra sobre la lista, que queda quieta debajo en una copia.
func _empezar_entrada() -> void:
	_asentar(false)
	_lista_quieta = _copiar_contenido()
	_capa.add_child(_lista_quieta)
	_capa.move_child(_lista_quieta, 0)
	_deslizamiento.ir_a(1.0)
	_comenzar_a_deslizar()


## El chat sale sobre la lista, que ya es la vista real. Parte de donde estaba el chat.
func _empezar_salida() -> void:
	_quitar_las_copias()
	_chat_saliente = _copiar_contenido()
	_contenido.offset_left = 0.0
	_contenido.offset_right = 0.0
	_capa.add_child(_chat_saliente)
	_deslizamiento.ir_a(0.0)
	_comenzar_a_deslizar()


func _comenzar_a_deslizar() -> void:
	_pintar_deslizamiento()
	_ultimo = _ahora.call()
	set_process(true)


## Termina cualquier deslizamiento en su estado final: el chat en su lugar, o la lista sola.
func _asentar(hay_chat: bool) -> void:
	_quitar_las_copias()
	_contenido.offset_left = 0.0
	_contenido.offset_right = 0.0
	_deslizamiento.ir_a(1.0 if hay_chat else 0.0)
	_deslizamiento.avanzar(RecorridoDelCelular.DURACION)


func _quitar_las_copias() -> void:
	if _lista_quieta != null:
		_lista_quieta.free()
		_lista_quieta = null
	if _chat_saliente != null:
		_chat_saliente.free()
		_chat_saliente = null


func _pintar_deslizamiento() -> void:
	if not _desliza():
		return
	var avance := clampf(_deslizamiento.posicion(), 0.0, 1.0)
	var corrimiento := (1.0 - avance) * _telefono.size.x
	var deslizante: Control = _chat_saliente if _chat_saliente != null else _contenido
	deslizante.offset_left = corrimiento
	deslizante.offset_right = corrimiento


## Una foto fija de lo que se ve ahora. No recibe clics ni foco: la vista real queda debajo.
func _copiar_contenido() -> Control:
	var copia := _contenido.duplicate(0) as Control
	copia.name = "Copia"
	copia.offset_left = 0.0
	copia.offset_right = 0.0
	copia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hijo: Node in copia.find_children("*", "Control", true, false):
		var control := hijo as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
	# El scroll no se aplica hasta que el contenedor mide; se pide para ese mismo cuadro.
	var historial := copia.find_child("Scroll", true, false) as ScrollContainer
	historial.set_deferred("scroll_vertical", _scroll.scroll_vertical)
	return copia


func _ajustar() -> void:
	var encuadre := get_viewport().get_visible_rect().size
	LienzoDeManada.ajustar(_lienzo, encuadre)
	# El recordatorio pertenece al borde de la ventana, no al lienzo centrado del teléfono.
	_recordatorio.scale = _lienzo.scale
	_base_del_recordatorio = Vector2(36.0, -130.0) * _lienzo.scale + Vector2(0, encuadre.y)
	_posar_el_recordatorio()
	_pintar_posicion()


func _pintar_posicion() -> void:
	_telefono.size = TAMANO
	var arriba := CENTRO.y - TAMANO.y / 2.0
	var centro := (
		lerpf(CENTRO.x, CENTRO_A_LA_IZQUIERDA.x, _lateral)
		if _lateral >= 0.0
		else lerpf(CENTRO.x, CENTRO_A_LA_DERECHA.x, -_lateral)
	)
	_telefono.position = Vector2(
		centro - TAMANO.x / 2.0, lerpf(1080.0, arriba, _recorrido.posicion())
	)


func _componer(menu: bool, notas: bool = false) -> void:
	_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED if menu else ScrollContainer.SCROLL_MODE_AUTO
	)
	var marco := _estilo(PAPEL if menu else FONDO_DE_LA_PANTALLA, 26, 12)
	marco.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	marco.shadow_size = 24
	marco.shadow_offset = Vector2(0.0, 12.0)
	_telefono.add_theme_stylebox_override("panel", marco)
	_cabecera.add_theme_stylebox_override(
		"panel", _estilo(FONDO_DE_NOTAS if notas else PAPEL, 16, 16)
	)
	var historial := _estilo(FONDO_DE_NOTAS if notas else PAPEL, 12, 12 if menu else 22)
	if menu:
		historial.content_margin_top = 4
		historial.content_margin_bottom = 4
	_scroll.add_theme_stylebox_override("panel", historial)
	_mensajes.add_theme_constant_override("separation", 0 if menu else 16)
	var buscar := _estilo(Color("ebebeb"), 8, 18)
	buscar.content_margin_top = 0
	buscar.content_margin_bottom = 0
	_busqueda.add_theme_stylebox_override("normal", buscar)
	_entrada.add_theme_stylebox_override("read_only", _estilo(Color("f3f3ef"), 12, 16))
	var barra := _scroll.get_v_scroll_bar()
	barra.add_theme_stylebox_override("scroll", _estilo(PAPEL, 0, 5))
	for estado: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		barra.add_theme_stylebox_override(estado, _estilo(Color("7d8280"), 9, 5))
	_actualizar_desplazamiento.call_deferred()


func _filtrar(busqueda: String) -> void:
	if _bandeja == null:
		return
	_limpiar()
	for conversacion in _bandeja.conversaciones():
		if (
			not busqueda.is_empty()
			and not conversacion.nombre.to_lower().contains(busqueda.to_lower())
		):
			continue
		var mensajes := _bandeja.mensajes_de(conversacion.interlocutor)
		var resumen := ""
		if not mensajes.is_empty():
			resumen = (
				_sin_etiquetas(mensajes[-1].texto) if not mensajes[-1].texto.is_empty() else FOTO
			)
		_mensajes.add_child(
			_boton_de(conversacion, _bandeja.no_leidos(conversacion.interlocutor), resumen)
		)
	_scroll.scroll_vertical = 0


## La vista previa es un `Label` y no interpreta BBCode: se quitan las etiquetas y queda el texto.
static func _sin_etiquetas(texto: String) -> String:
	var limpio := ""
	var resto := texto
	while true:
		var abre := resto.find("[")
		var cierra := resto.find("]", abre + 1) if abre >= 0 else -1
		if cierra < 0:
			return limpio + resto
		var nombre := resto.substr(abre + 1, cierra - abre - 1).lstrip("/")
		var es_etiqueta := not nombre.is_empty() and nombre[0].to_lower() != nombre[0].to_upper()
		limpio += resto.substr(0, abre if es_etiqueta else cierra + 1)
		resto = resto.substr(cierra + 1)
	return limpio


func _boton_de(conversacion: Conversacion, sin_leer: int, resumen: String) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(0, 132)
	boton.tooltip_text = conversacion.nombre
	boton.add_theme_stylebox_override("normal", _estilo(PAPEL, 8))
	boton.add_theme_stylebox_override("hover", _estilo(Color("ebebeb"), 8))
	boton.add_theme_stylebox_override("pressed", _estilo(Color("c8c8c8"), 8))
	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 12
	fila.offset_right = -12
	fila.add_theme_constant_override("separation", 18)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(fila)
	fila.add_child(_avatar(_imagen_del_contacto(conversacion, true)))
	var contacto := VBoxContainer.new()
	contacto.name = "Contacto"
	contacto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contacto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	contacto.add_theme_constant_override("separation", 10)
	contacto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(contacto)
	var nombre := _etiqueta(conversacion.nombre.to_upper(), TINTA, 26)
	nombre.name = "Nombre"
	contacto.add_child(nombre)
	var vista_previa := _etiqueta(resumen, GRIS, 24)
	vista_previa.name = "VistaPrevia"
	vista_previa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vista_previa.max_lines_visible = 2
	vista_previa.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	contacto.add_child(vista_previa)
	if sin_leer > 0:
		var badge := PanelContainer.new()
		badge.name = "NoLeidos"
		badge.custom_minimum_size = Vector2(36, 36)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_theme_stylebox_override("panel", _estilo(Color("093338"), 18, 4))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cuenta := _etiqueta(str(sin_leer), PAPEL, 20)
		cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(cuenta)
		fila.add_child(badge)
	var quien := conversacion.interlocutor
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.pressed.connect(func() -> void: chat_pedido.emit(quien))
	return boton


func _imagen_del_contacto(conversacion: Conversacion, menu: bool) -> Texture2D:
	# El retrato de introducción conserva su composición propia; el celular usa sus exports Figma.
	if conversacion.imagen != null and conversacion.imagen.resource_path == RETRATO_ENRIQUE:
		return AVATAR_ENRIQUE_MENU if menu else AVATAR_ENRIQUE
	return conversacion.imagen


func _avatar(imagen: Texture2D) -> PanelContainer:
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(66, 66)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_theme_stylebox_override("panel", _estilo(BURBUJA, 33))
	if imagen != null:
		var textura := TextureRect.new()
		textura.texture = imagen
		textura.material = MASCARA_DEL_AVATAR
		textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		textura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		textura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(textura)
	return avatar


func _burbuja_de(mensaje: Mensaje, indice: int) -> PanelContainer:
	var propia := _chat_de_notas or mensaje.propio
	var color := BURBUJA_PROPIA if propia else BURBUJA_RECIBIDA
	if mensaje.con_error:
		color = BURBUJA_CON_ERROR
	var panel := PanelContainer.new()
	panel.set_meta("indice_de_mensaje", indice)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END if propia else Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", _estilo(color, 16, 16))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.mouse_default_cursor_shape = _scroll.mouse_default_cursor_shape
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 8)
	contenido.mouse_filter = Control.MOUSE_FILTER_PASS
	contenido.mouse_default_cursor_shape = _scroll.mouse_default_cursor_shape
	panel.add_child(contenido)
	if mensaje.foto != null:
		var foto := TextureButton.new()
		foto.texture_normal = _textura_de(mensaje)
		foto.ignore_texture_size = true
		foto.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		foto.custom_minimum_size = Vector2(
			ANCHO_MAXIMO_DEL_TEXTO,
			ALTO_DE_LA_CAPTURA_EN_EL_CHAT if mensaje.tiene_captura() else 240
		)
		foto.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		foto.pressed.connect(
			func() -> void: foto_pedida.emit(int(panel.get_meta("indice_de_mensaje")))
		)
		contenido.add_child(foto)
	if not mensaje.texto.is_empty():
		var texto := _texto(mensaje.texto, TINTA, TAMANO_DEL_TEXTO)
		texto.add_theme_constant_override("line_separation", INTERLINEADO)
		texto.custom_minimum_size.x = _ancho_del_texto(mensaje.texto)
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not mensaje.pista_del_tramo(mensaje.tramo_de_pista).is_empty():
			texto.clear()
			var inicio := mensaje.texto.find(mensaje.texto_del_tramo)
			texto.add_text(mensaje.texto.left(inicio))
			texto.push_meta(mensaje.tramo_de_pista)
			texto.push_color(ROJO)
			texto.add_text(mensaje.texto_del_tramo)
			texto.pop()
			texto.pop()
			texto.add_text(mensaje.texto.substr(inicio + mensaje.texto_del_tramo.length()))
			texto.meta_underlined = false
			texto.mouse_filter = Control.MOUSE_FILTER_STOP
			texto.meta_clicked.connect(
				func(tramo: Variant) -> void: tramo_pedido.emit(mensaje.identidad, str(tramo))
			)
		contenido.add_child(texto)
	if mensaje.con_error:
		var aviso := _etiqueta(PedidoAlProveedor.ERROR_DE_RED, ROJO, TAMANO_DE_LA_HORA)
		aviso.name = "ErrorDeRed"
		contenido.add_child(aviso)
	if not mensaje.hora.is_empty():
		var hora := _etiqueta(mensaje.hora, GRIS_DE_LA_HORA, TAMANO_DE_LA_HORA)
		hora.name = "Hora"
		hora.size_flags_horizontal = Control.SIZE_SHRINK_END
		contenido.add_child(hora)
	return panel


## La foto que se dibuja: la de la transferencia lleva escritos el importe y la cuenta de origen.
func _textura_de(mensaje: Mensaje) -> Texture2D:
	if not mensaje.tiene_captura():
		return mensaje.foto
	var clave := mensaje.identidad + mensaje.importe_de_la_captura
	if not _capturas.has(clave):
		_capturas[clave] = _componer_la_captura(mensaje)
	return _capturas[clave]


## La imagen base y tres textos, dibujados una sola vez en un `SubViewport`.
func _componer_la_captura(mensaje: Mensaje) -> Texture2D:
	var lienzo := SubViewport.new()
	lienzo.size = TAMANO_DE_LA_CAPTURA
	lienzo.disable_3d = true
	lienzo.render_target_update_mode = SubViewport.UPDATE_ONCE
	var base := TextureRect.new()
	base.texture = mensaje.foto
	base.size = Vector2(TAMANO_DE_LA_CAPTURA)
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lienzo.add_child(base)
	var importe := _texto_de_la_captura(
		mensaje.importe_de_la_captura, ZONA_DEL_IMPORTE, TAMANO_DEL_IMPORTE
	)
	importe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lienzo.add_child(importe)
	lienzo.add_child(
		_texto_de_la_captura(
			QuejasDeLaJornada.DESTINO.replace(" ****", "\n****"),
			ZONA_DEL_DESTINO,
			TAMANO_DE_LA_CUENTA
		)
	)
	lienzo.add_child(
		_texto_de_la_captura(
			QuejasDeLaJornada.ORIGEN.replace(" ****", "\n****") + mensaje.origen_de_la_captura,
			ZONA_DEL_ORIGEN,
			TAMANO_DE_LA_CUENTA
		)
	)
	add_child(lienzo)
	return lienzo.get_texture()


func _texto_de_la_captura(texto: String, zona: Rect2, tamano: int) -> Label:
	var etiqueta := _etiqueta(texto, TINTA, tamano)
	etiqueta.position = zona.position
	etiqueta.size = zona.size
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return etiqueta


## Los dos botones de una queja sin responder toman el lugar del campo del mensaje.
func _ofrecer_las_respuestas(se_ofrecen: bool) -> void:
	if is_instance_valid(_respuestas):
		_pie.remove_child(_respuestas)
		_respuestas.queue_free()
	_respuestas = null
	_entrada.visible = not se_ofrecen
	if not se_ofrecen:
		return
	_respuestas = VBoxContainer.new()
	_respuestas.name = "Respuestas"
	_respuestas.add_theme_constant_override("separation", 10)
	_respuestas.add_child(_boton_de_respuesta(TEXTO_DE_DAR_LA_RAZON, true, BURBUJA, PAPEL))
	_respuestas.add_child(_boton_de_respuesta(TEXTO_DE_RECHAZAR, false, PAPEL, BURBUJA))
	_pie.add_child(_respuestas)
	_pie.move_child(_respuestas, 0)


func _boton_de_respuesta(texto: String, da_la_razon: bool, fondo: Color, letra: Color) -> Button:
	var boton := Button.new()
	boton.name = "DarLaRazon" if da_la_razon else "Rechazar"
	boton.text = texto
	boton.custom_minimum_size = Vector2(0, 58)
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.add_theme_font_override("font", _fuente_del_chat)
	boton.add_theme_font_size_override("font_size", 26)
	for estado: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		boton.add_theme_color_override(estado, letra)
	for estado: String in ["normal", "hover", "pressed"]:
		boton.add_theme_stylebox_override(estado, _estilo(fondo, 12, 16))
	boton.pressed.connect(func() -> void: respuesta_pedida.emit(da_la_razon))
	return boton


## El ancho que pide el texto en una línea, sin pasar del máximo: la burbuja se ajusta al texto.
func _ancho_del_texto(texto: String) -> float:
	var ancho := 0.0
	for linea: String in texto.replace("[b]", "").replace("[/b]", "").split("\n"):
		var medida := _fuente_del_chat.get_string_size(
			linea, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_DEL_TEXTO
		)
		ancho = maxf(ancho, medida.x)
	return minf(ceilf(ancho) + 2.0, ANCHO_MAXIMO_DEL_TEXTO)


func _agregar_la_flecha_del_campo() -> void:
	var flecha := _etiqueta(">", GRIS_DE_LA_HORA, 30)
	flecha.name = "Enviar"
	flecha.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	flecha.offset_left = -48.0
	flecha.offset_right = -14.0
	flecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flecha.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_entrada.add_child(flecha)


## La funda se dibuja detrás de la pantalla y sobresale de ella, así que sigue al teléfono.
func _agregar_la_funda() -> void:
	var estilo := _estilo(FONDO_DE_LA_FUNDA, 38)
	estilo.set_border_width_all(2)
	estilo.border_color = BORDE_DE_LA_FUNDA
	estilo.expand_margin_left = 24.5
	estilo.expand_margin_right = 24.5
	estilo.expand_margin_top = 24.0
	estilo.expand_margin_bottom = 24.0
	estilo.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	estilo.shadow_size = 22
	estilo.shadow_offset = Vector2(0.0, 12.0)
	var funda := Panel.new()
	funda.name = "Funda"
	funda.show_behind_parent = true
	funda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	funda.add_theme_stylebox_override("panel", estilo)
	_telefono.add_child(funda)
	_telefono.move_child(funda, 0)


## La barra de estado ocupa la fila de arriba del teléfono, sobre la cabecera.
func _agregar_la_barra_de_estado() -> void:
	_barra_de_estado = BarraDeEstadoDelCelular.new(_fuente_del_chat)
	var contenido := _cabecera.get_parent()
	contenido.add_child(_barra_de_estado)
	contenido.move_child(_barra_de_estado, 0)


func _ordenar_el_historial() -> void:
	# Reordenar sólo la composición conserva las burbujas y la foto que se esté leyendo.
	for hijo: Node in _mensajes.get_children():
		if hijo.has_meta("separador_de_jornada"):
			hijo.reparent(_basurero, false)
			hijo.queue_free()
	var posicion := 0
	var anterior := -1
	for indice: int in _historial.size():
		var mensaje := _historial[indice]
		var tanda := mensaje.tanda()
		var diferencia := _jornada_de_referencia - mensaje.jornada
		if tanda >= 0 and tanda != anterior and diferencia >= 0 and diferencia < DIAS.size():
			var rotulo := DIAS[maxi(0, _jornada_de_referencia - mensaje.dia())]
			if not mensaje.hora.is_empty():
				rotulo += "\n" + mensaje.hora
			var separador := _etiqueta(rotulo, GRIS, 24)
			separador.set_meta("separador_de_jornada", tanda)
			separador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_mensajes.add_child(separador)
			_mensajes.move_child(separador, posicion)
			posicion += 1
		var burbuja := _burbujas[indice]
		burbuja.set_meta("indice_de_mensaje", indice)
		_mensajes.move_child(burbuja, posicion)
		posicion += 1
		anterior = tanda
	_actualizar_desplazamiento.call_deferred()


## Sin primer mensaje nuevo, lleva la lista al último mensaje. Con uno, lo deja en el borde
## superior; `siguiendo` baja además lo necesario para que el último quede a la vista.
func _acomodar_la_lectura(siguiendo: bool) -> void:
	# El contenedor debe terminar de medir los mensajes antes de pedir el extremo del scroll.
	await get_tree().process_frame
	var barra := _scroll.get_v_scroll_bar()
	if _ancla < 0 or _ancla >= _burbujas.size():
		_scroll.scroll_vertical = int(barra.max_value)
		return
	var inicio := _burbujas[_ancla].position.y
	var fin := _fin_de_los_mensajes()
	var falta := barra.page - (fin - inicio) - float(_mensajes.get_theme_constant("separation"))
	_poner_el_relleno(falta if fin > barra.page else 0.0)
	await get_tree().process_frame
	var destino := maxf(inicio, fin - barra.page) if siguiendo else inicio
	_scroll.scroll_vertical = int(destino)


func _fin_de_los_mensajes() -> float:
	var fin := 0.0
	for hijo: Node in _mensajes.get_children():
		var control := hijo as Control
		if control != _relleno and control.visible:
			fin = maxf(fin, control.position.y + control.size.y)
	return fin


## Deja bajo el último mensaje el espacio que hace falta para poder subir el primer nuevo hasta el
## borde superior.
func _poner_el_relleno(alto: float) -> void:
	if _relleno == null or _relleno.get_parent() != _mensajes:
		_relleno = Control.new()
		_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mensajes.add_child(_relleno)
	_mensajes.move_child(_relleno, -1)
	_relleno.custom_minimum_size.y = maxf(alto, 0.0)
	_relleno.visible = alto > 0.0


func _limpiar() -> void:
	_terminar_arrastre()
	_ancla = Celular.AL_FINAL
	_relleno = null
	_historial.clear()
	_burbujas.clear()
	# Lo viejo espera su liberación dentro del árbol, en un nodo oculto: sacado del árbol y
	# liberado al final del cuadro, cada mensaje que llega dejaba huérfano todo el chat anterior.
	if _basurero == null:
		_basurero = Control.new()
		_basurero.visible = false
		add_child(_basurero)
	for viejo in _mensajes.get_children():
		viejo.reparent(_basurero, false)
		viejo.queue_free()


func _etiqueta(texto: String, color: Color, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.add_theme_font_override("font", _fuente_del_chat)
	etiqueta.text = texto
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _estilo(color: Color, radio: int, margen: int = 0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(radio)
	estilo.content_margin_left = margen
	estilo.content_margin_right = margen
	estilo.content_margin_top = margen
	estilo.content_margin_bottom = margen
	return estilo


func _texto(texto: String, color: Color, tamano: int) -> RichTextLabel:
	var etiqueta := RichTextLabel.new()
	etiqueta.add_theme_font_override("normal_font", _fuente_del_chat)
	etiqueta.bbcode_enabled = true
	etiqueta.fit_content = true
	etiqueta.scroll_active = false
	etiqueta.text = texto
	etiqueta.add_theme_color_override("default_color", color)
	etiqueta.add_theme_font_size_override("normal_font_size", tamano)
	etiqueta.add_theme_font_size_override("bold_font_size", tamano)
	etiqueta.add_theme_font_override("bold_font", _adjunto.get_theme_font("bold_font"))
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


## «Hacer pedido» y «Enviar» ocupan el lugar de la entrada de mensaje en el chat de Hernán.
func _agregar_los_botones_del_pedido() -> void:
	_hacer_pedido = _boton_del_pie(TEXTO_DE_HACER_PEDIDO, Color("f3f3ef"), TINTA)
	_hacer_pedido.name = "HacerPedido"
	_hacer_pedido.pressed.connect(
		func() -> void:
			pedido.abrir_lista()
			_pintar_el_pedido()
	)
	_enviar_pedido = _boton_del_pie(TEXTO_DE_ENVIAR, Color("0b343d"), PAPEL)
	_enviar_pedido.name = "EnviarPedido"
	_enviar_pedido.pressed.connect(
		func() -> void:
			envio_del_pedido_pedido.emit()
			_pintar_el_pedido()
	)
	for boton: Button in [_hacer_pedido, _enviar_pedido]:
		boton.hide()
		_pie.add_child(boton)
		_pie.move_child(boton, 0)


func _boton_del_pie(texto: String, fondo: Color, tinta: Color) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.custom_minimum_size = Vector2(0.0, 62.0)
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.add_theme_font_override("font", _fuente_del_chat)
	boton.add_theme_font_size_override("font_size", TAMANO_DEL_TEXTO)
	for color: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		boton.add_theme_color_override(color, tinta)
	boton.add_theme_color_override("font_disabled_color", GRIS)
	for estado: String in ["normal", "hover", "pressed", "focus"]:
		boton.add_theme_stylebox_override(estado, _estilo(fondo, 12, 16))
	boton.add_theme_stylebox_override("disabled", _estilo(fondo.darkened(0.15), 12, 16))
	var flecha := _etiqueta(">", tinta, 30)
	flecha.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	flecha.offset_left = -48.0
	flecha.offset_right = -14.0
	flecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flecha.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boton.add_child(flecha)
	return boton


## El chat de Hernán cambia el pie: con la lista cerrada ofrece «Hacer pedido», y con la lista
## abierta, «Enviar», que sólo se habilita con algo marcado. En los demás chats todo queda como
## estaba. La lista se arma de nuevo cada vez que se abre.
func _pintar_el_pedido() -> void:
	if _hacer_pedido == null:
		return
	var abierta := _chat_del_pedido and pedido != null and pedido.lista_abierta()
	_entrada.visible = not _chat_del_pedido
	_hacer_pedido.visible = _chat_del_pedido and not abierta
	_enviar_pedido.visible = abierta
	if abierta:
		_enviar_pedido.disabled = not pedido.puede_enviar()
		if not is_instance_valid(_lista_del_pedido) or _lista_del_pedido.get_parent() != _mensajes:
			_lista_del_pedido = ListaDelPedido.new()
			_lista_del_pedido.armar(pedido, BURBUJA_PROPIA, TINTA, _fuente_del_chat)
			_lista_del_pedido.seleccion_cambiada.connect(_pintar_el_pedido)
			_mensajes.add_child(_lista_del_pedido)
			_acomodar_la_lectura.call_deferred(true)
		else:
			_mensajes.move_child(_lista_del_pedido, _mensajes.get_child_count() - 1)
	elif is_instance_valid(_lista_del_pedido):
		_lista_del_pedido.queue_free()
		_lista_del_pedido = null

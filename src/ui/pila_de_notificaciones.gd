class_name PilaDeNotificaciones
extends CanvasLayer

const TEXTOS := {
	Notificaciones.Tipo.CLIENTE: "¡HAY UN CLIENTE!",
	Notificaciones.Tipo.LECTURA_FALLIDA: "NO SE PUDO LEER",
	Notificaciones.Tipo.CLIENTE_CANSADO: "EL CLIENTE SE CANSÓ DE ESPERAR.",
	Notificaciones.Tipo.CIERRE_PROXIMO: "QUEDA POCO TIEMPO PARA QUE\nSE TERMINE LA JORNADA.",
	Notificaciones.Tipo.PISTA: "¡NUEVA PISTA!",
	Notificaciones.Tipo.TAREAS_TERMINADAS: "YA PODÉS RETIRARTE\nPOR LA PUERTA PRINCIPAL.",
	Notificaciones.Tipo.CLIENTE_CANSADO_CON_PRODUCTOS:
	"EL CLIENTE SE CANSÓ DE ESPERAR Y DEJÓ LOS PRODUCTOS.",
}
const TITULOS := {
	Notificaciones.Tipo.CIERRE_PROXIMO: "¡HORA DE CIERRE!",
	Notificaciones.Tipo.TAREAS_TERMINADAS: "¡TAREAS COMPLETADAS!",
}
const SIMBOLO_DEL_CLIENTE := preload("res://assets/ui/manada/notificacion_cliente.svg")
const SIMBOLO_DE_LA_SALIDA := preload("res://assets/ui/manada/notificacion_salida.svg")
const SIMBOLOS := {
	Notificaciones.Tipo.CLIENTE: SIMBOLO_DEL_CLIENTE,
	Notificaciones.Tipo.LECTURA_FALLIDA: preload("res://assets/ui/manada/notificacion_lectura.svg"),
	Notificaciones.Tipo.CLIENTE_CANSADO: SIMBOLO_DE_LA_SALIDA,
	Notificaciones.Tipo.CIERRE_PROXIMO: preload("res://assets/ui/manada/notificacion_cierre.svg"),
	Notificaciones.Tipo.PISTA: preload("res://assets/ui/manada/notificacion_pista.svg"),
	Notificaciones.Tipo.TAREAS_TERMINADAS:
	preload("res://assets/ui/manada/notificacion_tareas_completadas.svg"),
	Notificaciones.Tipo.CLIENTE_CANSADO_CON_PRODUCTOS: SIMBOLO_DE_LA_SALIDA,
}
const ESCALA_DEL_CARTEL := 0.4
const PROPORCION_DEL_TITULO := 32.0 / 56.0
const DURACION_DE_ENTRADA := 0.2
const DURACION_DE_SALIDA := 0.2
const CURVA_DE_ENTRADA := 0.3
const CURVA_DE_SALIDA := 3.0
const VELOCIDAD_DE_ACOMODO := 18.0
const UMBRAL_DE_ACOMODO := 0.5


class AvisoEnPantalla:
	extends RefCounted

	var cartel: PanelContainer
	var entrada := 0.0
	var desvio_y := 0.0
	var y_en_la_pila := NAN
	var salida := 0.0
	var x_de_partida := 0.0
	var recorrido := 0.0

	func _init(nodo: PanelContainer) -> void:
		cartel = nodo


@export var _marco: Control
@export var _pila: VBoxContainer
@export var _estilo: StyleBoxFlat

var _estado := Notificaciones.new()
var _dibujadas: Array[Notificaciones.Tipo] = []
var _activos: Dictionary[Notificaciones.Tipo, AvisoEnPantalla] = {}
var _saliendo: Array[AvisoEnPantalla] = []


func _ready() -> void:
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_pila.sort_children.connect(_desplazar_carteles)
	_ajustar_al_viewport()


func _process(delta: float) -> void:
	_animar(delta)
	_estado.avanzar(delta)
	_pintar()


func avisar_llegada(comprador: Comprador) -> void:
	_estado.llego(comprador)
	_pintar()


func avisar_salida(comprador: Comprador, dejo_productos := false) -> void:
	_estado.se_fue(comprador, dejo_productos)
	_pintar()


func iniciar_conversacion(comprador: Comprador) -> void:
	_estado.atendido(comprador)
	_pintar()


func avisar_lectura_rechazada(motivo: GeneradorDeTickets.Resultado) -> void:
	_estado.lectura_rechazada(motivo)
	_pintar()


func avisar_pista() -> void:
	_estado.pista_anotada()
	_pintar()


func actualizar_salida(disponible: bool) -> void:
	_estado.actualizar_salida(disponible)
	_pintar()


func actualizar_computadora(abierta: bool) -> void:
	_estado.actualizar_computadora(abierta)
	_pintar()


func actualizar_tiempo(restante: float) -> void:
	_estado.actualizar_tiempo(restante)
	_pintar()


func vaciar() -> void:
	_estado.vaciar()
	_pintar()
	for aviso in _saliendo:
		aviso.cartel.free()
	_saliendo.clear()


func _pintar() -> void:
	var actuales := _estado.visibles()
	if actuales == _dibujadas:
		return
	for tipo: Notificaciones.Tipo in _activos.keys():
		if not actuales.has(tipo):
			_despedir(tipo)
	for indice in actuales.size():
		var tipo := actuales[indice]
		if not _activos.has(tipo):
			var aviso := AvisoEnPantalla.new(_cartel(tipo))
			if get_tree().paused:
				aviso.entrada = 1.0
			_activos[tipo] = aviso
			_pila.add_child(aviso.cartel)
		_pila.move_child(_activos[tipo].cartel, indice)
	_dibujadas = actuales


func _despedir(tipo: Notificaciones.Tipo) -> void:
	var aviso := _activos[tipo]
	_activos.erase(tipo)
	var cartel := aviso.cartel
	aviso.recorrido = _recorrido_hasta_el_borde(cartel)
	var posicion := cartel.position + _pila.position
	_pila.remove_child(cartel)
	_marco.add_child(cartel)
	cartel.position = posicion
	aviso.x_de_partida = posicion.x
	_saliendo.append(aviso)


func _animar(delta: float) -> void:
	var en_movimiento := false
	for aviso: AvisoEnPantalla in _activos.values():
		if aviso.entrada < 1.0:
			aviso.entrada = minf(aviso.entrada + delta / DURACION_DE_ENTRADA, 1.0)
			en_movimiento = true
		if aviso.desvio_y != 0.0:
			aviso.desvio_y = lerpf(aviso.desvio_y, 0.0, 1.0 - exp(-VELOCIDAD_DE_ACOMODO * delta))
			if absf(aviso.desvio_y) < UMBRAL_DE_ACOMODO:
				aviso.desvio_y = 0.0
			en_movimiento = true
	if en_movimiento:
		_pila.queue_sort()
	for aviso: AvisoEnPantalla in _saliendo.duplicate():
		aviso.salida = minf(aviso.salida + delta / DURACION_DE_SALIDA, 1.0)
		aviso.cartel.position.x = (
			aviso.x_de_partida + aviso.recorrido * ease(aviso.salida, CURVA_DE_SALIDA)
		)
		if aviso.salida >= 1.0:
			_saliendo.erase(aviso)
			aviso.cartel.free()


func _desplazar_carteles() -> void:
	for aviso: AvisoEnPantalla in _activos.values():
		var cartel := aviso.cartel
		var falta_entrar := 1.0 - ease(aviso.entrada, CURVA_DE_ENTRADA)
		cartel.position.x += _recorrido_hasta_el_borde(cartel) * falta_entrar
		if not is_nan(aviso.y_en_la_pila):
			aviso.desvio_y += aviso.y_en_la_pila - cartel.position.y
		aviso.y_en_la_pila = cartel.position.y
		cartel.position.y += aviso.desvio_y


func _recorrido_hasta_el_borde(cartel: Control) -> float:
	var borde := get_viewport().get_visible_rect().size.x
	return (borde - cartel.get_global_rect().position.x) / _marco.scale.x


func _cartel(tipo: Notificaciones.Tipo) -> PanelContainer:
	var cartel := PanelContainer.new()
	cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartel.size_flags_horizontal = Control.SIZE_SHRINK_END
	cartel.add_theme_stylebox_override("panel", _estilo)
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 22)
	cartel.add_child(fila)
	var simbolo := TextureRect.new()
	simbolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	simbolo.texture = SIMBOLOS[tipo]
	simbolo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	simbolo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	simbolo.custom_minimum_size = simbolo.texture.get_size() * ESCALA_DEL_CARTEL
	fila.add_child(simbolo)
	var texto := _etiqueta(TEXTOS[tipo])
	if TITULOS.has(tipo):
		var titulo := _etiqueta(TITULOS[tipo])
		titulo.name = &"Titulo"
		titulo.add_theme_font_size_override(
			"font_size", roundi(_marco.get_theme_default_font_size() * PROPORCION_DEL_TITULO)
		)
		var columna := VBoxContainer.new()
		columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		columna.add_theme_constant_override("separation", 0)
		columna.add_child(titulo)
		columna.add_child(texto)
		fila.add_child(columna)
	else:
		fila.add_child(texto)
	return cartel


func _etiqueta(contenido: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.text = contenido
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_color_override("font_color", Color("04060c"))
	return etiqueta


func _ajustar_al_viewport() -> void:
	var disponible := get_viewport().get_visible_rect().size
	var referencia := LienzoDeManada.TAMANO_DEL_DISENO
	var factor := minf(disponible.x / referencia.x, disponible.y / referencia.y)
	_marco.scale = Vector2.ONE * factor

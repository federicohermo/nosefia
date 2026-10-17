## El menú de inicio: dibuja las opciones que contesta el dominio y entra al almacén.
extends Control

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const PANTALLA_DE_CARGA := preload("res://src/ui/interrupciones/pantalla_de_carga.tscn")
## Por encima de todas las capas del almacén: se lo arma detrás de la pantalla de carga.
const CAPA_DE_LA_CARGA := 10
## La barra se reparte entre leer el almacén y calentar sus shaders. Lo que ya se leyó mientras
## el menú estaba abierto no ocupa barra. Calentar es lo que tarda: ~12 s de 19 en la web.
const PARTE_DE_LA_LECTURA := 0.15
const DURACION_DEL_FUNDIDO := 0.3
## En segundos: la barra termina de llenarse antes de entrar, desde donde haya quedado.
const LLENADO_FINAL := 0.35
## Un cuadro trabado no saltea el llenado: dura también al menos estos cuadros.
const CUADROS_DEL_LLENADO := 10
## En segundos: la barra llena se ve antes de pasar a la partida.
const BARRA_LLENA := 0.3
const TEMA := preload("res://assets/audio/MUS_MenuPrincipal.ogg")
## A 0 dB tapaba todo lo demás de la intro.
const VOLUMEN_DEL_TEMA_DB := -8.0

const TEXTOS: Dictionary[MenuDeInicio.Opcion, String] = {
	MenuDeInicio.Opcion.NUEVO_JUEGO: "NUEVO JUEGO",
	MenuDeInicio.Opcion.CONTINUAR: "CONTINUAR",
	MenuDeInicio.Opcion.CONFIGURACIONES: MenuDePausa.TEXTO_DE_CONFIGURACIONES,
	MenuDeInicio.Opcion.LOGROS: MenuDePausa.TEXTO_DE_LOGROS,
	MenuDeInicio.Opcion.SALIR: "SALIR",
}

## El frame de Figma pone estas dos en una fila debajo de la columna.
const EN_LA_FILA: Array[MenuDeInicio.Opcion] = [
	MenuDeInicio.Opcion.CONFIGURACIONES,
	MenuDeInicio.Opcion.SALIR,
]

@export var _opciones: VBoxContainer
@export var _pedidos: PedidosDelMenu
@export var _marco: Control
@export var _fila: HBoxContainer
@export var _configuraciones: PantallaDeConfiguraciones

var _guardado := Guardado.new()
var _ajuste: AjusteDePreferencias
var _botones: Dictionary[MenuDeInicio.Opcion, Button] = {}

var _carga: CargaEnSegundoPlano
var _pantalla: PantallaDeCarga
var _almacen: PackedScene
var _espera: EsperaDeLaCarga
var _calentamiento: CalentamientoDeShaders
var _calentamiento_en_el_menu: CalentamientoDeShaders
var _copia: Node3D
var _capas_de_la_copia: Array[CanvasLayer] = []
var _copia_leyo_un_guardado := false
var _copia_con_las_preferencias := true
var _nuevo_juego: bool = false
var _fundiendo: bool = false
var _fundido: ColorRect
var _musica: AudioStreamPlayer
var _inicio_del_fundido: int = 0
var _lectura_inicial := 0.0
var _parte_de_la_lectura := PARTE_DE_LA_LECTURA
## Lo que ya mostró la barra: el calentamiento vuelve a cero en cada pasada, y la barra no.
var _mostrado := 0.0
var _ahora: Callable = Time.get_ticks_usec


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		LienzoDeManada.ajustar(_marco, size)


## Las preferencias se aplican antes que nada: el menú no suena ni se dibuja con las de fábrica.
func _ready() -> void:
	_ajuste = AjusteDePreferencias.new()
	add_child(_ajuste)
	_configuraciones.preparar(_ajuste.cargar_y_aplicar())
	_configuraciones.preferencias_cambiadas.connect(_ajuste.previsualizar)
	_configuraciones.preferencias_confirmadas.connect(_ajuste.cambiar)
	_configuraciones.preferencias_confirmadas.connect(
		func(_nuevas: Preferencias) -> void: _copia_con_las_preferencias = false
	)
	_configuraciones.cerrada.connect(_al_cerrar_las_configuraciones)
	_sonar_el_tema()
	var menu := MenuDeInicio.new(OS.has_feature("web"), _guardado.hay_guardado())
	_pedidos.preparar(menu, _guardado)
	for opcion: MenuDeInicio.Opcion in menu.opciones():
		var boton := Button.new()
		boton.text = TEXTOS[opcion]
		boton.disabled = not menu.habilitada(opcion)
		boton.pressed.connect(_pedidos.elegir.bind(opcion))
		boton.theme_type_variation = &"BotonDelMenu"
		_botones[opcion] = boton
		if opcion in EN_LA_FILA:
			boton.custom_minimum_size.x = _opciones.size.x
			_fila.add_child(boton)
		else:
			_opciones.add_child(boton)
	_pedidos.nuevo_juego_pedido.connect(empezar_partida_nueva)
	_pedidos.continuar_pedido.connect(entrar_al_almacen)
	_pedidos.configuraciones_pedida.connect(_abrir_las_configuraciones)
	# Se crean acá y no al declararlos: una instancia que nunca entra al árbol los dejaría
	# colgados.
	_carga = CargaEnSegundoPlano.new()
	_pantalla = PANTALLA_DE_CARGA.instantiate()
	_calentamiento = CalentamientoDeShaders.new()
	var capa := CanvasLayer.new()
	capa.layer = CAPA_DE_LA_CARGA
	capa.add_child(_pantalla)
	_fundido = ColorRect.new()
	_fundido.color = Color.BLACK
	_fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_fundido)
	_fundido.hide()
	add_child(_carga)
	add_child(capa)
	add_child(_calentamiento)
	_calentamiento.avanzo.connect(_pintar_el_calentamiento.bind(_calentamiento))
	_carga.lista.connect(_al_cargar_el_almacen)
	_carga.fallo.connect(_al_fallar_la_carga)
	_carga.pedir(ESCENA_DEL_ALMACEN)
	print("[carga] menú visible")


## Una sola voz para todo el menú y la carga: abrir configuraciones o reintentar no la tocan.
## Como los bucles del local, suena como stream también en la web.
func _sonar_el_tema() -> void:
	_musica = AudioStreamPlayer.new()
	_musica.name = "Musica"
	_musica.stream = TEMA
	_musica.volume_db = VOLUMEN_DEL_TEMA_DB
	_musica.bus = EntradaSonora.BUS_DE_MUSICA
	_musica.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_musica)
	_musica.play()


func _process(delta: float) -> void:
	if _fundiendo:
		_pintar_el_fundido()
		return
	if _espera == null:
		return
	if _lectura_inicial < 1.0:
		var leido := (_carga.progreso() - _lectura_inicial) / (1.0 - _lectura_inicial)
		_pintar(_parte_de_la_lectura * clampf(leido, 0.0, 1.0))
		_pantalla.contar_lectura(_carga.progreso())
	_espera.avanzar(delta)
	if _calentamiento_en_el_menu == null and _copia != null and _sirve_la_copia():
		_pintar(_espera.avance() * (1.0 - _parte_de_la_lectura) + _parte_de_la_lectura)
	if _espera.puede_entrar() and _calentamiento_en_el_menu == null:
		_espera = null
		if _copia != null and _sirve_la_copia():
			_entrar_con_la_copia()
		else:
			_descartar_la_copia()
			_calentar_el_almacen()


## Esc la cierra sola; el foco vuelve al botón que la abrió.
func _al_cerrar_las_configuraciones() -> void:
	_marco.show()
	_botones[MenuDeInicio.Opcion.CONFIGURACIONES].grab_focus(true)


func _abrir_las_configuraciones() -> void:
	_marco.hide()
	_configuraciones.abrir()


## Nuevo juego conserva el borrado y la confirmación de PedidosDelMenu antes de llegar acá.
func empezar_partida_nueva() -> void:
	_nuevo_juego = true
	_fundiendo = true
	_inicio_del_fundido = _ahora.call()
	_fundido.modulate.a = 0.0
	_fundido.show()


## Continuar conserva la entrada directa a la jornada del archivo.
func entrar_al_almacen() -> void:
	_nuevo_juego = false
	_preparar_la_entrada()


func _pintar_el_fundido() -> void:
	var transcurrido := maxf(0.0, (_ahora.call() - _inicio_del_fundido) / 1000000.0)
	_fundido.modulate.a = minf(1.0, transcurrido / DURACION_DEL_FUNDIDO)
	if transcurrido >= DURACION_DEL_FUNDIDO:
		_fundiendo = false
		_preparar_la_entrada()
		_fundido.hide()


func _preparar_la_entrada() -> void:
	_espera = EsperaDeLaCarga.new()
	_mostrado = 0.0
	_lectura_inicial = 1.0 if _almacen != null else _carga.progreso()
	_parte_de_la_lectura = PARTE_DE_LA_LECTURA * (1.0 - _lectura_inicial)
	_pantalla.pintar(0.0)
	_pantalla.contar_lectura(1.0 if _almacen != null else _carga.progreso())
	if _almacen != null:
		_espera.terminar_carga()
	else:
		_carga.pedir(ESCENA_DEL_ALMACEN)
	_pantalla.mostrar()


## El almacén entra al árbol detenido, detrás de la pantalla de carga, y recién pasa a ser la
## escena cuando dibujó cada objeto una vez: en la web, cada shader se compila la primera vez que
## se dibuja, y cada uno frena el navegador alrededor de un segundo. Detenido, el reloj del turno
## no corre, el jugador no se mueve y no suena nada. Se lo detiene después de entrar: sólo así el
## motor pausa el sonido que ya arrancó su `_ready`.
func _calentar_el_almacen() -> void:
	set_process(false)
	var almacen := _almacen.instantiate()
	get_tree().root.add_child(almacen)
	almacen.process_mode = Node.PROCESS_MODE_DISABLED
	_calentamiento.terminado.connect(_llenar_y_entrar.bind(almacen))
	_calentamiento.calentar(almacen)


func _pintar_el_calentamiento(progreso: float, calentamiento: CalentamientoDeShaders) -> void:
	if not _pantalla.visible:
		return
	_pintar(_parte_de_la_lectura + progreso * (1.0 - _parte_de_la_lectura))
	var total := calentamiento.objetos_a_preparar()
	var faltan := calentamiento.objetos_por_preparar()
	var cola: int = calentamiento.programas_en_cola.call()
	if faltan == 0 and cola > 0:
		_pantalla.contar_compilacion(cola)
	else:
		_pantalla.contar_preparacion(total - faltan, total)


func _pintar(valor: float) -> void:
	_mostrado = maxf(_mostrado, valor)
	_pantalla.pintar(_mostrado)


func _llenar_y_entrar(almacen: Node) -> void:
	_pantalla.contar_entrada()
	var desde := _mostrado
	var inicio: int = _ahora.call()
	var cuadros := 0
	while _mostrado < 1.0:
		await get_tree().process_frame
		cuadros += 1
		var transcurrido: float = (_ahora.call() - inicio) / 1000000.0
		var avance := minf(transcurrido / LLENADO_FINAL, float(cuadros) / CUADROS_DEL_LLENADO)
		_pintar(lerpf(desde, 1.0, minf(1.0, avance)))
	await get_tree().create_timer(BARRA_LLENA).timeout
	_entrar(almacen)


func _entrar(almacen: Node) -> void:
	if _musica != null:
		_musica.stop()
		_musica.stream = null
	almacen.call("empezar_partida_nueva" if _nuevo_juego else "anunciar_la_noche")
	almacen.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().current_scene = almacen
	queue_free()
	print("[carga] almacén en pantalla")


func _al_cargar_el_almacen(escena: PackedScene) -> void:
	_almacen = escena
	if _espera != null:
		_espera.terminar_carga()
	elif OS.has_feature("web"):
		_calentar_debajo_del_menu()


func _calentar_debajo_del_menu() -> void:
	_copia = _almacen.instantiate()
	_copia_leyo_un_guardado = _guardado.hay_guardado()
	get_tree().root.add_child(_copia)
	_copia.process_mode = Node.PROCESS_MODE_DISABLED
	for capa: CanvasLayer in _copia.find_children("*", "CanvasLayer", true, false):
		if capa.visible:
			capa.visible = false
			_capas_de_la_copia.append(capa)
	_calentamiento_en_el_menu = CalentamientoDeShaders.new()
	add_child(_calentamiento_en_el_menu)
	_calentamiento_en_el_menu.avanzo.connect(
		_pintar_el_calentamiento.bind(_calentamiento_en_el_menu)
	)
	_calentamiento_en_el_menu.terminado.connect(_al_calentar_debajo_del_menu)
	_calentamiento_en_el_menu.calentar(_copia)


func _al_calentar_debajo_del_menu() -> void:
	_calentamiento_en_el_menu.queue_free()
	_calentamiento_en_el_menu = null
	_copia.visible = false
	print("[carga] almacén calentado debajo del menú")


func _sirve_la_copia() -> bool:
	return _copia_con_las_preferencias and not (_nuevo_juego and _copia_leyo_un_guardado)


func _entrar_con_la_copia() -> void:
	set_process(false)
	_copia.visible = true
	for capa: CanvasLayer in _capas_de_la_copia:
		capa.visible = true
	await get_tree().process_frame
	while _calentamiento.programas_en_cola.call() > 0:
		await get_tree().process_frame
	await get_tree().process_frame
	_llenar_y_entrar(_copia)


func _descartar_la_copia() -> void:
	if _copia != null:
		_copia.queue_free()
		_copia = null


## Una carga fallida no deja al jugador colgado en la pantalla de carga: vuelve al menú, y el
## próximo «Nuevo juego» pide el almacén otra vez.
func _al_fallar_la_carga() -> void:
	_fundiendo = false
	_nuevo_juego = false
	_fundido.hide()
	_espera = null
	_pantalla.ocultar()
	_pedidos.rearmar()

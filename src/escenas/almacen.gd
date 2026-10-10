## El cableado de la noche: le da la partida al ciclo y ata sus señales al HUD.
##
## Las decisiones pertenecen al dominio. Acá se conectan las señales y se traduce la foto física
## de cuerpos y habitaciones al estado tipado que reciben las reglas puras del cierre.
##
## **Y perdió responsabilidades en vez de ganarlas.** Antes armaba el turno y llevaba el puntaje
## del empleado adentro de la escena, o sea que los dos morían al cerrarla y la regla del
## despido no se alcanzaba jugando. Las dos cosas se fueron a `Partida`, que se ejerce sin
## levantar nada. Acá quedó lo único que necesita la escena delante: conectar y pintar.
extends Node3D

## El script del reloj de mesa se preloadea para poder tiparlo: los scripts de `escenas/` son
## cáscara y no declaran `class_name`, así que sin esto el tipo estático del `@export` sería
## `Label3D` y llamarle `declarar_jornada()` no compilaría.
const RelojDeMesaDelLocal := preload("res://src/escenas/puestos/reloj_de_mesa.gd")

## Los scripts de `escenas/` se preloadean por el mismo motivo que el del reloj de mesa:
## son cáscara y no declaran `class_name`, así que sin esto el tipo estático del `@export` sería
## el del nodo y llamarles `mostrar()` no compilaría.
const EstanteDelLocal := preload("res://src/escenas/puestos/estante.gd")
const CajaDeProductosDelDeposito := preload("res://src/escenas/objetos/caja_de_productos.gd")
const LimpiezaDelLocal := preload("res://src/escenas/puestos/limpieza_del_almacen.gd")
const AudioDelLocal := preload("res://src/escenas/puestos/audio_del_almacen.gd")
const ReposicionManual := preload("res://src/escenas/puestos/reposicion_manual.gd")
const PuertaDelLocal := preload("res://src/escenas/puestos/puerta_del_local.gd")
const PuestoDeLaCaja := preload("res://src/escenas/puestos/caja_registradora.gd")
const TachoDelLocal := preload("res://src/escenas/puestos/tacho_de_basura.gd")
const ContenedorDelLocal := preload("res://src/escenas/puestos/contenedor_de_basura.gd")
const TapaDelLocal := preload("res://src/escenas/puestos/tapa_del_contenedor.gd")
const UtilDeLimpieza := preload("res://src/escenas/objetos/util_de_limpieza.gd")
const ManijaDelBalde := preload("res://src/escenas/objetos/manija_del_balde.gd")
const HabitacionesDelAlmacen := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")
const NotasDelLocal := preload("res://src/escenas/puestos/notas_del_almacen.gd")
const PilaDelDeposito := preload("res://src/escenas/puestos/pila_del_deposito.gd")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")

## El jugador tampoco declara un `class_name` —es cáscara, como este archivo—, así que el
## `@export` de abajo no lo puede nombrar sin traerlo por `preload`.
const Jugador := preload("res://src/escenas/jugador.gd")

const ESCENA_DEL_MENU := "res://src/escenas/menu_de_inicio.tscn"

@export var _hud: Hud
@export var _reloj: RelojDelTurno
@export var _ciclo: CicloDeJornadas
@export var _pantalla: PantallaDeCierre
@export var _reloj_de_mesa: RelojDeMesaDelLocal
@export var _repositor: Repositor
@export var _estante: EstanteDelLocal
@export var _cajas_de_productos: Array[Node3D]
@export var _jugador: Jugador
@export var _atenciones: Ventanilla
@export var _computadora: ComputadoraDeEscritorio
@export var _limpiador: Limpiador
@export var _limpieza: LimpiezaDelLocal
@export var _recolector: RecolectorDeBasura
@export var _audio: AudioDelLocal
@export var _reposicion_manual: ReposicionManual
@export var _habitaciones: HabitacionesDelAlmacen

## El agarre vive adentro de `jugador.tscn`, y es la única fuente de sonidos que no cuelga de
## esta raíz. Se la nombra acá para que sus tres señales no queden sin fuente: el enlazador
## conecta lo que le pasan, no sale a recorrer el árbol.
@export var _agarre: Agarre
@export var _bolsas: Array[Node3D]

## La mopa, el balde y los tres jabones, que arrancan cada noche en el baño.
@export var _utiles_de_limpieza: Array[Node3D]
@export var _manija_del_balde: ManijaDelBalde

@export var _puertas: Array[Node3D]
@export var _contenedor: ContenedorDelLocal
@export var _tapa_del_contenedor: TapaDelLocal
@export var _caja: CajaRegistradora
@export var _puesto_de_la_caja: PuestoDeLaCaja
@export var _programa_de_tickets: ProgramaDeTickets

## Los muebles con los que el jugador choca por su contorno y no por su malla.
@export var _muebles_con_contorno: Array[PhysicsBody3D]

## La partida es de la escena y no del ciclo porque también la lee el parte: el ciclo publica lo
## que pasó, y quien quiera un número lo pide acá. Sale del guardado: sin guardado, es nueva.
var _partida := Partida.desde(Guardado.new().cargar())

## Donde el jugador arranca cada noche: el lugar del nodo `Jugador` en la escena, leído antes de
## la primera apertura. Es geometría de la escena y no un número del dominio. No es un nodo propio
## porque lo que la escena declara cuelga de la raíz; los servicios se crean en el cableado.
var _arranque: Transform3D
var _acomodador: AcomodadorDelDeposito

## Cómo se sale al menú. Es una variable y no una llamada directa porque un test no puede
## cambiar de escena: se llevaría puesto al runner.
var _ir_al_menu: Callable = volver_al_menu

@onready var _celular: CelularDelEmpleado = $Interfaz/CelularDelEmpleado
@onready var _pantalla_del_celular: PantallaDelCelular = $Interfaz/PantallaDelCelular


## Los carteles se pintan acá antes de conectar nada, y no con un `text` escrito en `hud.tscn`:
## una copia del texto en la escena duplicaría el número de obligatorias declaradas.
func _ready() -> void:
	_cablear_el_celular()
	var avisos: PilaDeNotificaciones = get_node("Interfaz/PilaDeNotificaciones")
	_atenciones.comprador_llegado.connect(avisos.avisar_llegada)
	_atenciones.comprador_vencido.connect(avisos.avisar_salida)
	_atenciones.conversacion_iniciada.connect(avisos.iniciar_conversacion)
	_caja.lectura_rechazada.connect(avisos.avisar_lectura_rechazada)
	_caja.ticket_desechado.connect(_al_desechar_un_ticket)
	_reloj.turno_cerrado.connect(avisos.vaciar.unbind(1))
	_acomodador = AcomodadorDelDeposito.new()
	_acomodador.reloj = _reloj
	add_child(_acomodador)
	_agarre.objeto_agarrado.connect(_pedir_revision_del_deposito.unbind(1))
	_agarre.objeto_soltado.connect(_pedir_revision_del_deposito.unbind(1))
	_agarre.objeto_entregado.connect(_pedir_revision_del_deposito.unbind(1))
	_jugador.examen.examen_iniciado.connect(_pedir_revision_del_deposito.unbind(1))
	_jugador.examen.examen_terminado.connect(_pedir_revision_del_deposito)
	var marco := MarcoDelObjetivo.new()
	add_child(marco)
	_jugador.objetivo_enfocado.connect(marco.enfocar)
	_jugador.objetivo_perdido.connect(marco.apagar)
	_jugador.objetivo_enfocado.connect(_hud.mostrar_foco)
	_jugador.objetivo_perdido.connect(_hud.ocultar_foco)
	for mueble in _muebles_con_contorno:
		_jugador.ignorar_el_detalle(mueble)
	# La hora se lee en el local y no en la pantalla: enterarse cuesta caminar hasta el reloj de
	# mesa, y la noche en que falla, ni caminar alcanza. La jornada se declara antes de arrancar
	# porque el ciclo abre la primera adentro de `arrancar()`.
	_reloj.tiempo_consumido.connect(_reloj_de_mesa.mostrar_tiempo)
	_ciclo.jornada_abierta.connect(_reloj_de_mesa.declarar_jornada)
	_reloj.tarea_completada.connect(_hud.mostrar_tareas)
	_reloj.tarea_descumplida.connect(_hud.mostrar_tareas)
	_atenciones.compra_realizada.connect(_computadora.revisar_registro)
	_ciclo.turno_agotado.connect(_al_agotar_el_turno)
	_ciclo.jornada_cerrada.connect(_al_cerrar_la_jornada)
	# La apertura reinicia el marcador antes de que la computadora revise la planilla nueva:
	# conservar el conteo anterior arrastraría las cumplidas de ayer. La góndola se rehace por
	# lo mismo: compartirla dejaría lo repuesto anoche y reponer se cumpliría sola desde la 2.
	# **Una sola conexión**: el 017 y el 008 llegaron por separado al mismo `jornada_abierta`, y
	# conectarlo dos veces es un error de Godot, no dos llamadas.
	_ciclo.jornada_abierta.connect(_al_abrir_la_jornada)
	# El audio se ata **por nombre de señal** y no nombrando a nadie: la lista de fuentes se le
	# pasa entera y el enlazador conecta las que existan. Una señal que todavía no está deja su
	# fila declarada sin fuente en vez de romper algo.
	(
		_audio
		. enlazar(
			[
				_reloj,
				_ciclo,
				_repositor,
				_atenciones,
				_computadora,
				_celular,
				_caja,
				_programa_de_tickets,
				_limpiador,
				_recolector,
				_agarre,
				_jugador,
				$Interfaz/PantallaDeComputadora,
				$Estructura/puerta/CuerpoDeLaHoja,
				$Estructura/puerta2/CuerpoDeLaHoja,
				$Estructura/bano_puerta_1/CuerpoDeLaHoja,
				$Estructura/bano_puerta_2/CuerpoDeLaHoja,
				$Estructura/puertaentrada/CuerpoDeLaHoja,
				$Estructura/porton/CuerpoDeLaHoja,
				$Estructura/puertajefe/CuerpoDeLaHoja,
				$Estructura/heladeranueva/puerta_heladera_0/CuerpoDeLaHoja,
				$Estructura/heladeranueva_001/puerta_heladera_1/CuerpoDeLaHoja,
				$Estructura/heladera_fuera_de_servicio/puerta_heladera_2/CuerpoDeLaHoja,
			]
		)
	)
	# Reponer, de punta a punta: el clic derecho sobre una caja apoyada entrega una unidad a la
	# mano, o le devuelve la de su producto que la mano lleva, y la zona de reposición la coloca
	# en la góndola. Quien atiende ese clic es `ReposicionManual`, que se conecta solo. La unidad
	# viaja en la mano y sigue contada en el depósito, así que el inventario recién cambia cuando
	# el estante la acepta: soltarla en el piso no repone nada, y devolverla no mueve nada.
	_recolector.agarre = _agarre
	_recolector.repositor = _repositor
	_recolector.bolsas = _bolsas
	_recolector.bolsa_sacada.connect(_al_sacar_una_bolsa)
	_jugador.uso_pedido.connect(_usar_un_tacho)
	_recolector.objeto_tirado.connect(_contenedor.recibir)
	_recolector.objeto_tirado.connect(_al_tirar_un_objeto)
	_repositor.agarre = _agarre
	_repositor.unidad_colocada.connect(_reposicion_manual.depositar)
	# El subtítulo del examen: lo que dice la caja examinada, y nada cuando termina. El texto lo
	# arma la caja en `dominio/`; lo examinado que no es una caja no dice nada, y el HUD lo pinta.
	_jugador.examen.examen_iniciado.connect(
		func(nodo: Node3D) -> void:
			_hud.mostrar_subtitulo(_reposicion_manual.texto_del_examen(nodo))
	)
	_jugador.examen.examen_terminado.connect(_hud.vaciar_subtitulo)
	for util: UtilDeLimpieza in _utiles_de_limpieza:
		util.examen = _jugador.examen
	_manija_del_balde.observador = _jugador
	# El motor no despierta lo que está sobre una caja empujada. Lo hace el puesto.
	for caja: CajaDeProductosDelDeposito in _cajas_de_productos:
		caja.empujada.connect(_reposicion_manual.despertar_lo_de_arriba)
		caja.sleeping_state_changed.connect(_pedir_revision_del_deposito)
		caja.empujada.connect(_pedir_revision_del_deposito.unbind(1))
	# «Volver al menú» de la pausa sale por el mismo camino que el de la placa.
	var pausa: ControlDePausa = get_node("Interfaz/ControlDePausa")
	_programa_de_tickets.pausa_pedida.connect(pausa.pausar)
	pausa.pausado.connect(_programa_de_tickets.cerrar_las_listas)
	pausa.volver_al_menu_pedido.connect(func() -> void: _ir_al_menu.call())
	_arranque = _jugador.global_transform
	add_child(EnlaceDeGuardado.new(_ciclo, Guardado.new()))
	_ciclo.arrancar(_partida, _reloj)
	_reposicion_manual.preparar()


## Cada noche arranca sin tareas cumplidas, cada caja del depósito llena y la góndola
## completa salvo lo que esa jornada hace faltar.
##
## El marcador lo dice la apertura y no el cierre de la anterior: entre las dos hay una placa que
## el jugador tarda lo que quiera en despachar, y el conteo de ayer no puede quedar colgado ahí.
##
## **Varios specs de la pila escribieron esta función por separado, cada uno con la parte que le
## importaba, y la unión las junta acá**: es la misma apertura y no una por tarea, y se conecta
## una sola vez —conectar `jornada_abierta` dos veces es un error de Godot—. El inventario se
## arma en este lado y no en el `Repositor` porque «con cuánta mercadería arranca una jornada»
## es una regla del juego, y `Apertura` es donde tiene test.
func _al_abrir_la_jornada(jornada: int) -> void:
	_celular.abrir_jornada(jornada)
	_pantalla_del_celular.mostrar_recordatorio(true)
	# Primero que nada, y por eso antes de `limpiar()`: lo que quedó en la mano cuelga del
	# jugador, así que devolverlo a su lugar le escribiría la posición relativa a la mano y la
	# caja terminaría flotando pegada al cuerpo toda la noche siguiente. Y antes, el examen: lo
	# examinado cuelga de la cara, y vaciar las manos lo dejaría apuntando a un nodo que ya no
	# está ahí.
	_jugador.examen.terminar()
	_agarre.vaciar_las_manos()
	_caja.arrancar(GeneradorDeTickets.para_la_jornada(jornada))
	_puesto_de_la_caja.limpiar()
	_jugador.ubicar(_arranque)
	_hud.declarar_obligatorias(Apertura.cantidad_de_obligatorias(jornada))
	(get_node("Estructura/NotasDelAlmacen") as NotasDelLocal).declarar_tareas(
		_partida.obligatorias()
	)
	# **Un solo inventario para las dos obligatorias**: reponer lo llena y la ventanilla lo
	# vacía. Construir uno por tarea daría dos stocks del mismo producto, y las dos ventanas
	# dirían números distintos sin que nada se ponga en rojo. Cuántos casilleros tiene la fila
	# de adelante de cada producto lo mide el puesto sobre el modelo; lo que falta, la jornada.
	var inventario := Apertura.inventario_de_la_jornada(jornada, _reposicion_manual.casilleros())
	_repositor.arrancar(Estante.new(inventario, Catalogo.todos()))
	_reposicion_manual.limpiar()
	_contenedor.reiniciar()
	var atender := TareaDeAtender.new(Compradores.de_la_jornada(jornada), inventario)
	_atenciones.arrancar(atender)
	_computadora.arrancar(RegistroDeVentas.new(Catalogo.todos(), atender))
	# El piso se rehace cada noche: guardar el estado entre jornadas está fuera de alcance, y una
	# sola instancia dejaría el local limpio de anoche y la obligatoria cumplida sola.
	_limpiador.arrancar(PisoDelLocal.de_la_jornada())
	_recolector.arrancar(TareaDeLaBasura.de_la_jornada(jornada))
	# La apertura restaura los cuerpos antes de pintar sólo los tachos declarados.
	for indice in _bolsas.size():
		var bolsa: ObjetoAgarrable = _bolsas[indice]
		bolsa.volver_a_su_lugar()
		bolsa.freeze = true
		for forma: CollisionShape3D in bolsa.find_children("*", "CollisionShape3D", true, false):
			forma.disabled = true
		var tacho := _tachos()[indice]
		tacho.mostrar(bolsa, _recolector.tarea().tiene_bolsa(tacho.tacho))
	var poses: Dictionary[Node3D, Transform3D] = {}
	if Apertura.cajas_apiladas(jornada):
		poses = PilaDelDeposito.poses(
			_cajas_de_productos,
			$Estructura/porton,
			$Estructura/deposito_pallet_central_izquierdo_0_1,
			$Estructura/SueloSolido/Fondo
		)
	for caja: CajaDeProductosDelDeposito in _cajas_de_productos:
		caja.declarar_origen(poses.get(caja, caja.pose_de_estanteria()))
		caja.volver_a_su_lugar()
	_pedir_revision_del_deposito()
	# Los útiles de limpieza van por lo mismo que las cajas: se trasladan, y la noche siguiente
	# arrancaría con la mopa y el balde donde los dejó la anterior. Vacío y seca los deja el piso
	# nuevo, que el limpiador recibe arriba y el puesto pinta abajo.
	for util: ObjetoAgarrable in _utiles_de_limpieza:
		util.volver_a_su_lugar()
	for puerta: PuertaDelLocal in _puertas:
		puerta.cerrar_de_golpe()
	_tapa_del_contenedor.reiniciar()
	_audio.arrancar_el_ambiente()
	_limpieza.reiniciar()
	_estante.mostrar(0)


## La jornada cerrada ya quedó anotada en la partida cuando esta señal llega: acá sólo se le
## pasan a la pantalla los números que la partida contesta.
##
## Las obligatorias salen de la partida y no de una lista propia: son **las mismas instancias**
## que el turno estuvo contando toda la noche, así que el parte lee el estado de verdad y no una
## copia que nadie completó.
func _al_cerrar_la_jornada(jornada: int, cumplidas: int) -> void:
	_celular.cerrar_jornada()
	_pantalla_del_celular.mostrar_recordatorio(false)
	_audio.callar_la_musica()
	_hud.mostrar_tareas(cumplidas)
	_pantalla.mostrar(
		ParteDeCierre.new(
			jornada,
			_partida.obligatorias(),
			_partida.apercibimientos(),
			_partida.final(),
			_partida.llamados()
		)
	)
	# Sin esto la placa es inalcanzable jugando: el jugador clava el puntero en el centro cada
	# cuadro y los botones caen más abajo, así que no se pueden clickear nunca. La suspensión
	# suelta el cursor sola, porque el modo se recalcula a partir del estado del control.
	_jugador.suspender()
	# Una conexión por placa: un segundo despacho de la misma placa no encuentra a nadie, y no
	# abre dos noches ni carga el menú dos veces.
	_pantalla.cierre_despachado.connect(_al_despachar_la_placa, CONNECT_ONE_SHOT)


## Qué hace cada opción de la placa. Cuáles se ofrecen lo decidió el parte; acá sólo se busca
## la acción de la elegida.
func _al_despachar_la_placa(opcion: ParteDeCierre.Opcion) -> void:
	var acciones: Dictionary[ParteDeCierre.Opcion, Callable] = {
		ParteDeCierre.Opcion.SEGUIR: _seguir,
		ParteDeCierre.Opcion.VOLVER_AL_MENU: _ir_al_menu,
	}
	acciones[opcion].call()


## La jornada abre detrás de la entrada; el control vuelve cuando la persiana termina de subir.
func _seguir() -> void:
	_ciclo.abrir_la_jornada()
	anunciar_la_noche()


func anunciar_la_noche() -> void:
	var persiana: PersianaDeLaNoche = get_node("Interfaz/PersianaDeLaNoche")
	_reloj.retener()
	_jugador.suspender()
	persiana.persiana_subida.connect(_al_subir_la_persiana, CONNECT_ONE_SHOT)
	persiana.anunciar(_partida.jornada())


func _al_subir_la_persiana(_jornada: int) -> void:
	_reloj.soltar()
	_jugador.reanudar()


## Deja la partida y carga el menú de inicio. No abre ninguna jornada.
func volver_al_menu() -> void:
	get_tree().change_scene_to_file(ESCENA_DEL_MENU)


func _estados_del_cierre() -> Array[ReglasDelCierre.Estado]:
	var candidatos: Array[Node3D] = []
	candidatos.append_array(_cajas_de_productos)
	candidatos.append_array(_utiles_de_limpieza)
	candidatos.append_array(_bolsas)
	candidatos.append_array(_reposicion_manual.unidades_sueltas())
	candidatos.append_array(_puesto_de_la_caja.tickets_en_el_mundo())
	var sostenido := _agarre.cuerpo_sostenido()
	if (
		sostenido != null
		and sostenido.get("datos") is UnidadDeProducto
		and not candidatos.has(sostenido)
	):
		candidatos.append(sostenido)
	var tirados := _contenedor.tirados()
	var estados: Array[ReglasDelCierre.Estado] = []
	for nodo: Node3D in candidatos:
		if not is_instance_valid(nodo) or nodo.is_queued_for_deletion() or tirados.has(nodo):
			continue
		if nodo.has_meta(&"recibido_por_comprador"):
			continue
		var clase := ReglasDelCierre.Clase.OTRO
		if nodo is CajaDeProductosDelDeposito:
			clase = ReglasDelCierre.Clase.CAJA
		elif nodo is UtilDeLimpieza:
			clase = ReglasDelCierre.Clase.UTIL_DE_LIMPIEZA
		elif nodo.get("datos") is UnidadDeProducto:
			clase = ReglasDelCierre.Clase.UNIDAD_SUELTA
		var en_mano := nodo == sostenido and not _jugador.examen.esta_examinando()
		estados.append(
			ReglasDelCierre.Estado.new(clase, _habitaciones.de(nodo.global_position), en_mano)
		)
	return estados


func _al_agotar_el_turno(_jornada: int) -> void:
	var estados := _estados_del_cierre()
	if ReglasDelCierre.hay_desorden(estados):
		_partida.anotar_llamado(Partida.Llamado.LOCAL_DESORDENADO)
	if ReglasDelCierre.hay_objetos_afuera(estados):
		_partida.anotar_llamado(Partida.Llamado.OBJETO_AFUERA)


func _al_desechar_un_ticket() -> void:
	_partida.anotar_llamado(Partida.Llamado.PAPEL_EN_EL_INODORO)


func _al_tirar_un_objeto(nodo: Node3D) -> void:
	var datos: ObjetoDelAlmacen = nodo.get("datos")
	if not ReglasDelCierre.se_tira_sin_llamado(datos):
		_partida.anotar_llamado(Partida.Llamado.OBJETO_TIRADO)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed(Celular.ACCION) and not evento.is_echo():
		get_viewport().set_input_as_handled()
		_celular.pedir_alternar(_jugador.suspendido() or _jugador.examen.esta_examinando())


func _cablear_el_celular() -> void:
	_celular.celular_abierto.connect(_al_abrir_el_celular)
	_celular.celular_cerrado.connect(_al_cerrar_el_celular)
	_celular.menu_mostrado.connect(_mostrar_el_menu_del_celular)
	_celular.chat_abierto.connect(_mostrar_el_chat_del_celular)
	_celular.foto_ampliada.connect(_pantalla_del_celular.ampliar)
	_celular.foto_cerrada.connect(_pantalla_del_celular.cerrar_foto)
	_celular.mensaje_recibido.connect(_al_recibir_en_el_celular)
	_pantalla_del_celular.chat_pedido.connect(_celular.pedir_chat)
	_pantalla_del_celular.volver_pedido.connect(_celular.pedir_volver)
	_pantalla_del_celular.foto_pedida.connect(_celular.pedir_foto)
	_pantalla_del_celular.cierre_de_foto_pedido.connect(_celular.pedir_cerrar_foto)


func _al_abrir_el_celular() -> void:
	_jugador.suspender()
	_pantalla_del_celular.subir()


func _al_cerrar_el_celular() -> void:
	_jugador.reanudar()
	_pantalla_del_celular.bajar()


func _mostrar_el_menu_del_celular() -> void:
	_pantalla_del_celular.mostrar_menu(_celular.bandeja())


func _mostrar_el_chat_del_celular(quien: Conversacion.Interlocutor) -> void:
	_pantalla_del_celular.mostrar_chat(
		_celular.bandeja().conversacion_de(quien),
		_celular.bandeja().mensajes_de(quien),
		_celular.celular().fijo()
	)


func _al_recibir_en_el_celular(quien: Conversacion.Interlocutor, _mensaje: Mensaje) -> void:
	if not _celular.celular().abierto():
		return
	if _celular.celular().pantalla() == Celular.Pantalla.MENU:
		_mostrar_el_menu_del_celular()
	elif (
		_celular.celular().pantalla() == Celular.Pantalla.CHAT
		and _celular.celular().chat() == quien
	):
		_mostrar_el_chat_del_celular(quien)


## Las señales pueden llegar antes de sincronizar los cuerpos con el espacio físico.
func _pedir_revision_del_deposito() -> void:
	_revisar_orden_del_deposito.call_deferred()


func _revisar_orden_del_deposito() -> void:
	var estados: Array[OrdenDelDeposito.Estado] = []
	var espacio := get_world_3d().direct_space_state
	var sostenido := _agarre.cuerpo_sostenido()
	for caja: CajaDeProductosDelDeposito in _cajas_de_productos:
		var estado := OrdenDelDeposito.Estado.new(caja.producto, caja == sostenido)
		if not estado.en_mano:
			var cuerpo: CollisionShape3D = caja.get_node("Cuerpo")
			var limites := cuerpo.global_transform * cuerpo.shape.get_debug_mesh().get_aabb()
			var media := limites.size.y / 2.0
			var consulta := PhysicsRayQueryParameters3D.create(
				caja.global_position, caja.global_position + Vector3.DOWN * (media + 0.02)
			)
			consulta.exclude = [caja.get_rid()]
			var golpe := espacio.intersect_ray(consulta)
			if not golpe.is_empty():
				var apoyo: Node3D = golpe.collider
				if apoyo is CajaDeProductosDelDeposito:
					estado.apoyo = OrdenDelDeposito.Apoyo.CAJA
					estado.sobre = apoyo.producto
				elif (
					str(apoyo.get_parent().name).begins_with("deposito_pallet_")
					and apoyo.get_parent().name != &"deposito_pallet_piso"
				):
					estado.apoyo = OrdenDelDeposito.Apoyo.ESTANTERIA
		estados.append(estado)
	_acomodador.revisar(estados)


func _tachos() -> Array[TachoDelLocal]:
	return [
		$Estructura/tachitobasura/StaticBody3D,
		$Estructura/tachitobasura_001/StaticBody3D,
		$Estructura/tachitobasura_002/StaticBody3D,
	]


func _usar_un_tacho(objetivo: Node3D) -> void:
	if objetivo is TachoDelLocal:
		_recolector.sacar_bolsa(objetivo.tacho)


func _al_sacar_una_bolsa(tacho: TareaDeLaBasura.Tacho) -> void:
	var bolsa := _bolsas[tacho]
	for forma: CollisionShape3D in bolsa.find_children("*", "CollisionShape3D", true, false):
		forma.disabled = false

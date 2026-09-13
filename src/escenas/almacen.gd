## El cableado de la noche: le da la partida al ciclo y ata sus señales al HUD.
##
## **No decide nada, y eso se puede verificar sin leerlo**: no tiene una sola línea que empiece
## con una condición. Cuáles son las obligatorias, cuánto dura el turno, cuántas noches dura la
## partida, cuántos apercibimientos suma cada banda y cómo se lee un tiempo son todas preguntas
## de `dominio/`, que es donde tienen test.
##
## **Y perdió responsabilidades en vez de ganarlas.** Antes armaba el turno y llevaba el puntaje
## del empleado adentro de la escena, o sea que los dos morían al cerrarla y la regla del
## despido no se alcanzaba jugando. Las dos cosas se fueron a `Partida`, que se ejerce sin
## levantar nada. Acá quedó lo único que necesita la escena delante: conectar y pintar.
extends Node3D

## El script del reloj de pared se preloadea para poder tiparlo: los scripts de `escenas/` son
## cáscara y no declaran `class_name`, así que sin esto el tipo estático del `@export` sería
## `Label3D` y llamarle `declarar_jornada()` no compilaría.
const RelojDeParedDelLocal := preload("res://src/escenas/puestos/reloj_de_pared.gd")

## Los tres scripts de `escenas/` se preloadean por el mismo motivo que el del reloj de pared:
## son cáscara y no declaran `class_name`, así que sin esto el tipo estático del `@export` sería
## el del nodo y llamarles `mostrar()` no compilaría.
const EstanteDelLocal := preload("res://src/escenas/puestos/estante.gd")
const CajaDeProductosDelDeposito := preload("res://src/escenas/objetos/caja_de_productos.gd")
const CajaDeTrasladoQueSeVe := preload("res://src/escenas/objetos/caja_de_traslado.gd")
const LimpiezaDelLocal := preload("res://src/escenas/puestos/limpieza_del_almacen.gd")
const AudioDelLocal := preload("res://src/escenas/puestos/audio_del_almacen.gd")
const ReposicionManual := preload("res://src/escenas/puestos/reposicion_manual.gd")

## El jugador tampoco declara un `class_name` —es cáscara, como este archivo—, así que el
## `@export` de abajo no lo puede nombrar sin traerlo por `preload`.
const Jugador := preload("res://src/escenas/jugador.gd")

@export var _hud: Hud
@export var _reloj: RelojDelTurno
@export var _ciclo: CicloDeJornadas
@export var _pantalla: PantallaDeCierre
@export var _reloj_de_pared: RelojDeParedDelLocal
@export var _repositor: Repositor
@export var _carga: CargaDeLaCaja
@export var _estante: EstanteDelLocal
@export var _cajas_de_productos: Array[Node3D]
@export var _caja_de_traslado: CajaDeTrasladoQueSeVe
@export var _jugador: Jugador
@export var _atenciones: Ventanilla
@export var _computadora: ComputadoraDeEscritorio
@export var _limpiador: Limpiador
@export var _limpieza: LimpiezaDelLocal
@export var _recolector: RecolectorDeBasura
@export var _audio: AudioDelLocal
@export var _reposicion_manual: ReposicionManual

## El agarre vive adentro de `jugador.tscn`, y es la única fuente de sonidos que no cuelga de
## esta raíz. Se la nombra acá para que sus tres señales no queden sin fuente: el enlazador
## conecta lo que le pasan, no sale a recorrer el árbol.
@export var _agarre: Agarre
@export var _bolsas: Array[Node3D]

## La partida es de la escena y no del ciclo porque también la mira el HUD: el ciclo publica lo
## que pasó, y quien quiera un número lo pide acá.
var _partida := Partida.nueva()


## Los carteles se pintan acá antes de conectar nada, y no con un `text` escrito en `hud.tscn`:
## una copia del texto en la escena es una copia de los números que lleva adentro —cuántas
## obligatorias hay y a cuántos apercibimientos echan—, y el de apercibimientos se quedaría en
## pantalla la jornada entera, porque hasta el cierre nadie lo vuelve a escribir.
func _ready() -> void:
	var marco := MarcoDelObjetivo.new()
	add_child(marco)
	_jugador.objetivo_enfocado.connect(marco.enfocar)
	_jugador.objetivo_perdido.connect(marco.apagar)
	_jugador.objetivo_enfocado.connect(_hud.mostrar_foco)
	_jugador.objetivo_perdido.connect(_hud.ocultar_foco)
	_hud.declarar_obligatorias(Apertura.cantidad_de_obligatorias())
	_hud.mostrar_apercibimientos(_partida.apercibimientos())
	# La hora se lee en el local y no en la pantalla: enterarse cuesta caminar hasta el reloj, y
	# desde la noche en que se rompe, ni caminar alcanza. La jornada se declara antes de arrancar
	# porque el ciclo abre la primera adentro de `arrancar()`.
	_reloj.tiempo_consumido.connect(_reloj_de_pared.mostrar_tiempo)
	_ciclo.jornada_abierta.connect(_reloj_de_pared.declarar_jornada)
	_reloj.tarea_completada.connect(_hud.mostrar_tareas)
	_ciclo.jornada_cerrada.connect(_al_cerrar_la_jornada)
	# El marcador de obligatorias no se reinicia solo: `mostrar_tareas()` se vuelve a llamar
	# recién cuando el jugador completa una, así que sin esto la noche 2 arranca mostrando las
	# que se cumplieron en la 1 hasta que se cumpla la primera de la 2. Y la góndola de cada
	# noche arranca vacía, así que el estante se rehace en la misma apertura: uno compartido
	# dejaría lo repuesto anoche puesto, y reponer se cumpliría sola a partir de la segunda.
	# **Una sola conexión**: el 017 y el 008 llegaron por separado al mismo `jornada_abierta`, y
	# conectarlo dos veces es un error de Godot, no dos llamadas.
	_ciclo.jornada_abierta.connect(_al_abrir_la_jornada)
	# La placa es quien abre la noche siguiente, y por eso el ciclo no reabre solo: entre una
	# jornada y la otra hay algo que leer.
	_pantalla.cierre_despachado.connect(_al_despachar_la_placa)
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
				_carga,
				_atenciones,
				_computadora,
				_limpiador,
				_recolector,
				_agarre,
			]
		)
	)
	# La unidad viaja en la mano; el inventario cambia cuando el estante la acepta.
	for caja: CajaDeProductosDelDeposito in _cajas_de_productos:
		caja.producto_pedido.connect(_reposicion_manual.retirar)
	_carga.producto_guardado.connect(_al_guardar_en_la_caja)
	_repositor.agarre = _agarre
	_repositor.unidad_colocada.connect(_reposicion_manual.depositar)
	_repositor.producto_colocado.connect(_al_colocar_en_el_estante)
	_ciclo.arrancar(_partida, _reloj)
	_reposicion_manual.preparar()


## Cada noche arranca con el marcador en cero, la góndola vacía y el depósito lleno.
##
## El marcador lo dice la apertura y no el cierre de la anterior: entre las dos hay una placa que
## el jugador tarda lo que quiera en despachar, y el conteo de ayer no puede quedar colgado ahí.
##
## **Varios specs de la pila escribieron esta función por separado, cada uno con la parte que le
## importaba, y la unión las junta acá**: es la misma apertura y no una por tarea, y se conecta
## una sola vez —conectar `jornada_abierta` dos veces es un error de Godot—. El inventario se
## arma en este lado y no en el `Repositor` porque «con cuánta mercadería arranca una jornada»
## es una regla del juego, y `Apertura` es donde tiene test.
func _al_abrir_la_jornada(_jornada: int) -> void:
	_hud.declarar_obligatorias(Apertura.cantidad_de_obligatorias())
	# **Un solo inventario para las dos obligatorias**: reponer lo llena y la ventanilla lo
	# vacía. Construir uno por tarea daría dos stocks del mismo producto, y las dos ventanas
	# dirían números distintos sin que nada se ponga en rojo.
	var inventario := Apertura.inventario_de_la_jornada()
	_repositor.arrancar(Estante.new(inventario, Catalogo.todos()))
	_reposicion_manual.limpiar()
	_atenciones.arrancar(TareaDeAtender.new(Compradores.de_la_jornada(), inventario))
	_computadora.arrancar(CajaRegistradora.new(inventario, CajaRegistradora.productos_del_dia()))
	# El piso se rehace cada noche: guardar el estado entre jornadas está fuera de alcance, y una
	# sola instancia dejaría el local limpio de anoche y la obligatoria cumplida sola.
	_limpiador.arrancar(PisoDelLocal.de_la_jornada())
	_recolector.arrancar(TareaDeLaBasura.de_la_jornada())
	# El dominio se resetea y los nodos no: sin esto las tres bolsas siguen adentro del `Area3D`
	# del fondo, y desde la jornada 2 la obligatoria está hecha antes de que el jugador dé un
	# paso. Van todas, siempre, sin preguntar dónde quedaron: dónde está cada una es del motor y
	# decidirlo acá sería una regla del juego escrita donde ningún gate la mira.
	for bolsa: ObjetoAgarrable in _bolsas:
		bolsa.volver_a_su_lugar()
	_audio.arrancar_el_ambiente()
	_limpieza.repintar()
	_estante.mostrar(0)


## La jornada cerrada ya quedó anotada en la partida cuando esta señal llega: acá sólo se le
## pasan a la pantalla los números que la partida contesta.
##
## Las obligatorias salen de la partida y no de una lista propia: son **las mismas instancias**
## que el turno estuvo contando toda la noche, así que el parte lee el estado de verdad y no una
## copia que nadie completó.
func _al_cerrar_la_jornada(jornada: int, cumplidas: int) -> void:
	_hud.mostrar_tareas(cumplidas)
	_hud.mostrar_apercibimientos(_partida.apercibimientos())
	_pantalla.mostrar(
		ParteDeCierre.new(jornada, _partida.obligatorias(), _partida.apercibimientos())
	)
	# Sin esto la placa es inalcanzable jugando: el jugador clava el puntero en el centro cada
	# cuadro y el botón «Seguir» cae más abajo, así que no se puede clickear nunca y la jornada 2
	# no existe en la build. La suspensión suelta el cursor sola, porque el modo se recalcula a
	# partir del estado del control.
	_jugador.suspender()


## El orden importa y por eso hay un handler en vez de conectar la señal derecho al ciclo: si el
## jugador se reanudara después de abrir la jornada, el cuadro del medio correría con el control
## todavía suspendido. Acá no se decide nada — son dos llamadas, siempre las dos.
func _al_despachar_la_placa() -> void:
	_jugador.reanudar()
	_ciclo.abrir_la_jornada()


## Lo guardado en la caja de traslado se repinta contra el contenido que contesta el dominio, y
## nunca contra una cuenta llevada acá.
func _al_guardar_en_la_caja(_producto: Producto) -> void:
	_caja_de_traslado.mostrar(_carga.caja().contenido())


## Al colocar se repintan las dos: el hueco que se llenó en el estante y el casillero que se
## vació en la caja.
func _al_colocar_en_el_estante(_producto: Producto, _completos: int) -> void:
	_caja_de_traslado.mostrar(_carga.caja().contenido())

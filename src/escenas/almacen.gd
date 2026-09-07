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

@export var _hud: Hud
@export var _reloj: RelojDelTurno
@export var _ciclo: CicloDeJornadas
@export var _pantalla: PantallaDeCierre
@export var _reloj_de_pared: RelojDeParedDelLocal
@export var _repositor: Repositor
@export var _carga: CargaDeLaCaja
@export var _estante: EstanteDelLocal
@export var _caja_de_productos: CajaDeProductosDelDeposito
@export var _caja_de_traslado: CajaDeTrasladoQueSeVe
@export var _atenciones: Ventanilla
@export var _computadora: ComputadoraDeEscritorio
@export var _limpiador: Limpiador
@export var _limpieza: LimpiezaDelLocal

## La partida es de la escena y no del ciclo porque también la mira el HUD: el ciclo publica lo
## que pasó, y quien quiera un número lo pide acá.
var _partida := Partida.nueva()


## Los carteles se pintan acá antes de conectar nada, y no con un `text` escrito en `hud.tscn`:
## una copia del texto en la escena es una copia de los números que lleva adentro —cuántas
## obligatorias hay y a cuántos apercibimientos echan—, y el de apercibimientos se quedaría en
## pantalla la jornada entera, porque hasta el cierre nadie lo vuelve a escribir.
func _ready() -> void:
	_hud.declarar_obligatorias(Apertura.cantidad_de_obligatorias())
	_hud.mostrar_apercibimientos(_partida.apercibimientos())
	# La hora se lee en el local y no en la pantalla: enterarse cuesta caminar hasta el reloj, y
	# desde la noche en que se rompe, ni caminar alcanza. La jornada se declara antes de arrancar
	# porque el ciclo abre la primera adentro de `arrancar()`.
	_reloj.tiempo_consumido.connect(_reloj_de_pared.mostrar_tiempo)
	_ciclo.jornada_abierta.connect(_reloj_de_pared.declarar_jornada)
	_reloj.tarea_completada.connect(_hud.mostrar_tareas)
	_ciclo.jornada_cerrada.connect(_al_cerrar_la_jornada)
	# La placa es quien abre la noche siguiente, y por eso el ciclo no reabre solo: entre una
	# jornada y la otra hay algo que leer. Se conecta derecho porque acá no hay nada que decidir.
	_pantalla.cierre_despachado.connect(_ciclo.abrir_la_jornada)
	# Reponer, de punta a punta: la caja del depósito despacha una unidad a la de traslado, el
	# estante la pide, y el repositor la mueve. Los dos gestos entran por el mismo clic del 006
	# y ninguno de los dos scripts de escena sabe qué pasa del otro lado.
	_caja_de_productos.producto_pedido.connect(_carga.pedir_guardar)
	_carga.producto_guardado.connect(_al_guardar_en_la_caja)
	_estante.colocacion_pedida.connect(_repositor.pedir_colocar)
	_repositor.producto_colocado.connect(_al_colocar_en_el_estante)
	# La góndola de cada noche arranca vacía, así que el estante se rehace al abrir la jornada y
	# no una sola vez acá: uno compartido dejaría lo repuesto anoche puesto, y reponer se
	# cumpliría sola a partir de la segunda.
	_ciclo.jornada_abierta.connect(_al_abrir_la_jornada)
	_ciclo.arrancar(_partida, _reloj)


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


## La noche empieza con el depósito lleno, la góndola vacía y el estante sin un hueco puesto.
##
## El inventario se arma acá y no en el `Repositor` porque «con cuánta mercadería arranca una
## jornada» es una regla del juego, y `Apertura` es donde tiene test.
func _al_abrir_la_jornada(_jornada: int) -> void:
	# **Un solo inventario para las dos obligatorias**: reponer lo llena y la ventanilla lo
	# vacía. Construir uno por tarea daría dos stocks del mismo producto, y las dos ventanas
	# dirían números distintos sin que nada se ponga en rojo.
	var inventario := Apertura.inventario_de_la_jornada()
	_repositor.arrancar(Estante.new(inventario, Catalogo.todos()))
	_atenciones.arrancar(TareaDeAtender.new(Compradores.de_la_jornada(), inventario))
	_computadora.arrancar(CajaRegistradora.new(inventario, CajaRegistradora.productos_del_dia()))
	# El piso se rehace cada noche: guardar el estado entre jornadas está fuera de alcance, y una
	# sola instancia dejaría el local limpio de anoche y la obligatoria cumplida sola.
	_limpiador.arrancar(PisoDelLocal.de_la_jornada())
	_limpieza.repintar()
	_estante.mostrar(0)


## Lo guardado en la caja de traslado se repinta contra el contenido que contesta el dominio, y
## nunca contra una cuenta llevada acá.
func _al_guardar_en_la_caja(_producto: Producto) -> void:
	_caja_de_traslado.mostrar(_carga.caja().contenido())


## Al colocar se repintan las dos: el hueco que se llenó en el estante y el casillero que se
## vació en la caja.
func _al_colocar_en_el_estante(_producto: Producto, completos: int) -> void:
	_estante.mostrar(completos)
	_caja_de_traslado.mostrar(_carga.caja().contenido())

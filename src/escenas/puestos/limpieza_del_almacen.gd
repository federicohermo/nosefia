## Las cuatro manchas del local y el gesto que las limpia. Cablea y nada más.
##
## **No decide nada sobre el juego.** Cuántas pasadas quedan, con qué se limpia y cuándo la
## obligatoria está cumplida son preguntas del dominio; qué gesto va con qué llamada es lo único
## que se decide acá.
##
## **La pasada entra por el clic derecho crudo, sin agregar una acción al `InputMap`.** El AC8 del
## spec 015 prohíbe agregar acciones, y quién consolida los tres usos del gesto —usar lo que se
## lleva, salir de la computadora, salir de la ventanilla— es el spec 034: una acción declarada
## acá sería la que hay que borrar después.
##
## **Qué mancha tiene delante lo contesta la mira del 004**, por su señal: preguntarle al árbol
## quién está más cerca sería una segunda respuesta a algo que el jugador ya decidió apuntando.
##
## Va en `puestos/` y no en `objetos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: hay uno solo y llega cableado, aunque adentro tenga cuatro manchas.
extends Node3D

## El script del jugador se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`.
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const ManchaQueSeVe := preload("res://src/escenas/objetos/mancha_en_el_piso.gd")

@export var jugador: JugadorDelLocal
@export var limpiador: Limpiador

## Lo que la mira tiene adelante, o `null`. Se guarda el nodo y no la zona porque la zona la
## contesta él, y guardarla acá sería una copia que se desincroniza al cambiar de objetivo.
var _enfocado: Node3D = null


func _ready() -> void:
	jugador.objetivo_enfocado.connect(_al_enfocar)
	jugador.objetivo_perdido.connect(_al_perder_el_objetivo)
	limpiador.pasada_dada.connect(_al_dar_una_pasada)
	# **No se repinta acá.** El `_ready()` de un hijo corre ANTES que el de la raíz, así que el
	# limpiador todavía no tiene piso y `repintar()` moriría con un `Nonexistent function … in
	# base 'Nil'` que no nombra ni a este archivo ni al orden. Quien repinta es el cableado, al
	# abrir la jornada.


## Deja las cuatro manchas como las ve el dominio. Lo llama el cableado al abrir la jornada.
func repintar() -> void:
	for mancha in manchas():
		mancha.mostrar(
			limpiador.piso().pasadas_restantes(mancha.zona_de_la_mancha()),
			ReglasDeLaLimpieza.PASADAS_POR_MANCHA
		)


## Las manchas que cuelgan de este puesto, en el orden del `.tscn`.
func manchas() -> Array[ManchaQueSeVe]:
	var encontradas: Array[ManchaQueSeVe] = []
	for hijo in get_children():
		var mancha := hijo as ManchaQueSeVe
		if mancha == null:
			continue
		encontradas.append(mancha)
	return encontradas


## El botón derecho pasa el trapeador por lo que la mira tenga delante.
##
## Es el evento crudo y no una acción del `InputMap`. Lo que se lleva en la mano se lo pregunta al
## jugador y se lo pasa al sistema: qué cuenta como trapeador lo decide el dominio.
func _unhandled_input(evento: InputEvent) -> void:
	var boton := evento as InputEventMouseButton
	if boton == null or not boton.pressed or boton.button_index != MOUSE_BUTTON_RIGHT:
		return
	var mancha := _enfocado as ManchaQueSeVe
	if mancha == null:
		return
	limpiador.pedir_pasada(mancha.zona_de_la_mancha(), jugador.id_en_la_mano())


func _al_enfocar(objetivo: Node3D, _distancia: float) -> void:
	_enfocado = objetivo


func _al_perder_el_objetivo() -> void:
	_enfocado = null


func _al_dar_una_pasada(_zona: PisoDelLocal.Zona, _restantes: int) -> void:
	repintar()

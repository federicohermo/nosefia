## El estado del control del jugador: compone la mirada, la caminata y el foco, y los suspende
## JUNTOS.
##
## Suspender es una sola llamada porque quien la hace no conoce las partes: la ventanilla —y
## también la computadora— tiene que poder decir «el jugador no controla» sin enterarse de que
## adentro hay un yaw, un vector de entrada y un rayo. Con tres interruptores sueltos, cada spec
## que suspenda al jugador tiene que acordarse de los tres, y el día que aparezca un cuarto hay
## que volver a tocarlos a todos.
class_name ControlDelJugador
extends RefCounted

var _mirada: Mirada
var _foco := Foco.new()
var _velocidad_maxima: float
var _suspendido: bool = false
var _agachado: bool = false
var _agache_apretado: bool = false
var _altura_de_la_vista: float = ReglasDelJugador.ALTURA_DE_LA_CAMARA

## Cuánto del giro falta dibujar, en radianes: `x` de yaw, `y` de pitch.
var _suavizado := SuavizadoDelGiro.new(SuavizadoDelGiro.VENTANA)


## Recibe la `Mirada` ya armada en vez de armarla: es lo que deja que un test la construya con
## una sensibilidad de números redondos sin tocar `ReglasDelJugador`.
func _init(mirada: Mirada, velocidad_maxima: float) -> void:
	_mirada = mirada
	_velocidad_maxima = velocidad_maxima


## Apaga a la vez la caminata, la mirada, el foco de la mira y el pedido de tener el cursor
## tomado. Y suelta el objetivo enfocado: así `jugador.gd` emite `objetivo_perdido` una sola vez
## y la mira deja de hablar durante toda la atención.
func suspender() -> void:
	_suspendido = true
	_foco.observar(Foco.SIN_OBJETIVO, 0.0, false)


func reanudar() -> void:
	_suspendido = false


func esta_suspendido() -> bool:
	return _suspendido


func girar(delta_del_mouse: Vector2) -> void:
	if _suspendido:
		return
	var yaw_antes := _mirada.yaw()
	var pitch_antes := _mirada.pitch()
	_mirada.girar(delta_del_mouse)
	# Se anota lo que la mirada giró y no lo que pidió el mouse: contra el tope del pitch, lo
	# pedido de más haría rebotar la cámara. Y el yaw por el camino corto, porque da la vuelta.
	_suavizado.agregar(
		Vector2(wrapf(_mirada.yaw() - yaw_antes, -PI, PI), _mirada.pitch() - pitch_antes)
	)


## El joystick derecho gira la vista en proporción a su inclinación, de `-1` a `1`: `x` a la
## derecha e `y` hacia abajo, como el delta del mouse. Se dibuja en el momento: el suavizado
## reparte los saltos del mouse, y la inclinación ya es continua.
func girar_con_el_joystick(inclinacion: Vector2, segundos: float) -> void:
	if _suspendido:
		return
	_mirada.girar_en_radianes(inclinacion * ReglasDelJugador.GIRO_DEL_JOYSTICK * segundos)


## El giro que faltaba dibujar se descarta: es de la mirada anterior.
func orientar(nuevo_yaw: float) -> void:
	_mirada.orientar(nuevo_yaw)
	_suavizado = SuavizadoDelGiro.new(SuavizadoDelGiro.VENTANA)


## Correr multiplica la velocidad de la postura: agachado o con algo pesado en la mano, por poco;
## con un bidón
## o una caja pequeña, por algo menos.
func velocidad(
	entrada: Vector2,
	corriendo: bool = false,
	en_la_mano: StringName = ObjetoDelAlmacen.SIN_ID,
	balde_con_agua: bool = false,
	caja_grande: bool = false
) -> Vector3:
	if _suspendido:
		return Vector3.ZERO
	var maxima := ReglasDelJugador.VELOCIDAD_AGACHADO if _agachado else _velocidad_maxima
	if corriendo:
		maxima *= (
			ReglasDelJugador.MULTIPLICADOR_DE_CORRER_CON_PESO
			if _agachado
			else ReglasDelJugador.multiplicador_de_correr(en_la_mano, balde_con_agua, caja_grande)
		)
	return Caminata.velocidad(entrada, _mirada.yaw(), maxima)


## La altura de la vista tras `delta` segundos. Agacharse es un interruptor: cada vez que la acción
## pasa de suelta a apretada la postura alterna, y soltarla no la cambia. Suspendido ignora la
## acción y sigue hacia la postura que había, pero igual recuerda si estaba apretada: reanudar con
## la tecla todavía abajo no alterna.
func altura_de_la_vista(apretada: bool, delta: float) -> float:
	if apretada and not _agache_apretado and not _suspendido:
		_agachado = not _agachado
	_agache_apretado = apretada
	var destino := (
		ReglasDelJugador.ALTURA_AGACHADO if _agachado else ReglasDelJugador.ALTURA_DE_LA_CAMARA
	)
	_altura_de_la_vista = TransicionDeLaVista.siguiente(_altura_de_la_vista, destino, delta)
	return _altura_de_la_vista


## Arranca una jornada parado, sin esperar a que la vista suba: la noche anterior no deja postura.
func ponerse_de_pie() -> void:
	_agachado = false
	_altura_de_la_vista = ReglasDelJugador.ALTURA_DE_LA_CAMARA


func observar(id: int, distancia: float, interactuable: bool) -> bool:
	if _suspendido:
		return false
	return _foco.observar(id, distancia, interactuable)


func yaw() -> float:
	return _mirada.yaw()


func pitch() -> float:
	return _mirada.pitch()


func avanzar_el_dibujo(delta: float) -> void:
	_suavizado.avanzar(delta)


## Hacia adónde mira la cámara que se dibuja: atrás de la mirada lo que el mouse todavía no mostró.
func yaw_dibujado() -> float:
	return wrapf(_mirada.yaw() - _suavizado.pendiente().x, -PI, PI)


func pitch_dibujado() -> float:
	return _mirada.pitch() - _suavizado.pendiente().y


func giro_atrasado() -> bool:
	return _suavizado.pendiente() != Vector2.ZERO


func objetivo() -> int:
	return _foco.objetivo()


func hay_interactuable() -> bool:
	return _foco.hay_interactuable()


## Un `bool` y no un `Input.MOUSE_MODE_*`: `dominio/` no nombra `Input`. Es la línea exacta
## donde se parte la traducción — acá se decide SI, en `src/escenas/jugador.gd` se traduce a QUÉ.
func quiere_el_cursor_tomado() -> bool:
	return not _suspendido


## El clic que llega con el cursor suelto estando el juego en marcha es el gesto que el navegador
## pide para devolverlo, y no una acción: el Esc que lo soltó no cuenta como gesto.
func clic_es_para_tomar_el_cursor(cursor_tomado: bool) -> bool:
	return quiere_el_cursor_tomado() and not cursor_tomado

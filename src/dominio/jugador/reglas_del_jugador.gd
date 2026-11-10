## Los valores fijos del controlador del jugador.
##
## Es un archivo aparte de `reglas.gd` a propósito, y no una duplicación: aquél tiene el balance
## de la tensión aritmética del turno —cuánto dura, cuánto cuesta cada tarea— y se toca
## discutiendo diseño; éstos son el tacto del controlador y se tocan probando el movimiento.
## La convención del repo pide que un valor fijo viva una sola vez en *un* archivo de
## `dominio/`, no en *el* archivo. Entre los dos no hay una sola constante repetida.
class_name ReglasDelJugador
extends RefCounted

## Metros por segundo. Un almacén se cruza caminando, no corriendo: la tensión del juego es el
## tiempo del turno, y una velocidad alta la afloja sin que nadie lo decida.
const VELOCIDAD_DE_CAMINATA := 3.5

## Radianes por píxel. La unidad no es un detalle: es lo que permite afirmar «100 píxeles son
## un radián» sin una conversión escondida en el medio.
const SENSIBILIDAD_DEL_MOUSE := 0.003

## Veces la velocidad de caminata con que se corre. Correr no se cansa ni se acaba: es una
## elección del jugador, y lo que cuesta es llevar menos cosas a la vez.
const MULTIPLICADOR_DE_CORRER := 1.4

## Lo mismo con una caja grande o el balde con agua en la mano, o agachado: acelera poco y no
## nada. Provisional hasta que el dueño lo juegue (OQ-PLY-007).
const MULTIPLICADOR_DE_CORRER_CON_PESO := 1.2

## Lo mismo con un bidón de jabón o una caja pequeña en la mano: más que con peso y menos que sin
## nada. Provisional hasta que el dueño lo juegue (OQ-PLY-007).
const MULTIPLICADOR_DE_CORRER_INTERMEDIO := 1.3

## Las cajas se llevan con las dos manos en su tamaño grande, y se llevan más livianas en el chico.
## La de reposición es la del depósito; la de fideos es una cajita.
const ID_DE_LA_CAJA_DE_REPOSICION := &"caja_de_reposicion"
const ID_DE_LA_CAJA_DE_FIDEOS := &"caja_de_fideos"

## Radianes por segundo con el joystick derecho a fondo: 180 grados. Lo decidió el dueño, y gira
## en proporción a la inclinación.
const GIRO_DEL_JOYSTICK := deg_to_rad(180.0)

## Metros, medidos desde el origen del `CharacterBody3D` que está apoyado en el piso.
const ALTURA_DE_LA_CAMARA := 1.7

## Metros, con el mismo origen. Cae dentro del hueco del segundo estante desde el piso de las
## góndolas, medido del modelo: la chapa queda a 0,79 m y la de arriba a 1,27 m. Agachado, la mira
## queda en lo que hay que alcanzar o revisar ahí.
const ALTURA_AGACHADO := 1.1

## Proporción de la velocidad de caminata con que se camina agachado. Un cuerpo agachado no
## avanza como uno erguido.
const PROPORCION_DE_VELOCIDAD_AGACHADO := 0.6

## Metros por segundo.
const VELOCIDAD_AGACHADO := VELOCIDAD_DE_CAMINATA * PROPORCION_DE_VELOCIDAD_AGACHADO

## Segundos que tarda la vista en recorrer todo el trecho entre las dos alturas, en un sentido o
## en el otro. Una duración nula es el salto de altura; una larga, un jugador que se arrastra.
const DURACION_DEL_AGACHE := 0.2

## Radianes. Los dos encierran al cero y ninguno llega a PI/2: pasarse de ahí da vuelta la
## cámara, y eso no es un límite de gusto sino de diseño.
const PITCH_MINIMO := -1.4
const PITCH_MAXIMO := 1.4

## Metros de alcance de la mira, y también hasta dónde se apoya lo que se lleva. Es proximidad: se
## mide desde los ojos sobre el piso, sin contar la altura. Lo de arriba de una estantería y lo
## tirado a los pies quedan a mano igual que lo que está enfrente. Que sea el mismo para apoyar
## es lo que deja volver a agarrar lo apoyado. Mayor que 1,2 porque se suelta lo que se lleva a
## esa distancia y afirma que se lo puede volver a mirar.
const ALCANCE_DE_LA_MIRA := 1.6
## Metros del campo que junta candidatos: a la distancia del alcance, llega del piso al techo.
const RADIO_DEL_CAMPO := 2.5
## Lo menos que cuenta el avance sobre el piso de una mirada: mirando derecho hacia abajo no
## avanza nada, y el rayo no puede ser infinito.
const AVANCE_MINIMO_DE_LA_MIRA := 0.1

## Radianes desde el centro de la vista.
const DESVIO_MAXIMO_DE_LA_MIRA := deg_to_rad(8.0)
## Los productos y sus huecos requieren apuntar cerca de su superficie.
const DESVIO_MAXIMO_DE_PRODUCTOS := deg_to_rad(3.0)
## Lo ya enfocado cuenta su desvío con este factor: se toma a 3° y se suelta a 5°. Sin esa banda,
## el foco titila en el borde de un producto.
const PERMANENCIA_DEL_FOCO := 0.6

## El contrato de «se puede interactuar con esto» ES este grupo de Godot, y vive acá por lo que
## permite: `dominio/` declara un `String` y no conoce a nadie, y un nodo de `escenas/` cumple
## el contrato agregándose al grupo en su `.tscn`, sin heredar nada. Las otras dos formas —una
## interfaz heredada y un método declarado— se descartaron midiendo: ninguna sobrevive a que el
## nodo lo declare desde la escena.
const GRUPO_INTERACTUABLE := "interactuable"

## Los nombres de las cuatro acciones del `InputMap`. Tienen que coincidir letra por letra con
## la sección `[input]` de `project.godot`, y el test de `jugador.tscn` afirma justamente eso:
## es la única forma de que ese par de `String` no se separe en silencio.
const ACCION_ADELANTE := "mover_adelante"
const ACCION_ATRAS := "mover_atras"
const ACCION_IZQUIERDA := "mover_izquierda"
const ACCION_DERECHA := "mover_derecha"

const ACCION_USAR: StringName = &"usar"

## Las cuatro direcciones del joystick derecho, que gira la vista.
const ACCION_MIRAR_IZQUIERDA: StringName = &"mirar_izquierda"
const ACCION_MIRAR_DERECHA: StringName = &"mirar_derecha"
const ACCION_MIRAR_ARRIBA: StringName = &"mirar_arriba"
const ACCION_MIRAR_ABAJO: StringName = &"mirar_abajo"

## Se mantiene apretada: soltarla levanta la vista.
const ACCION_AGACHARSE: StringName = &"agacharse"

## Se mantiene apretada: soltarla vuelve a caminar.
const ACCION_CORRER: StringName = &"correr"


## Cuánto multiplica la caminata correr con lo que se lleva en la mano, de pie.
##
## Pesa la caja de reposición grande y el balde con agua; frenan menos los bidones de jabón y las
## cajas pequeñas. El balde vacío y todo lo demás no frenan. `SIN_ID` es la mano vacía.
static func multiplicador_de_correr(
	en_la_mano: StringName, balde_con_agua: bool = false, caja_grande: bool = false
) -> float:
	if en_la_mano == ID_DE_LA_CAJA_DE_REPOSICION:
		return (
			MULTIPLICADOR_DE_CORRER_CON_PESO if caja_grande else MULTIPLICADOR_DE_CORRER_INTERMEDIO
		)
	if en_la_mano == ReglasDeLaLimpieza.ID_DEL_BALDE and balde_con_agua:
		return MULTIPLICADOR_DE_CORRER_CON_PESO
	if en_la_mano == ID_DE_LA_CAJA_DE_FIDEOS or ReglasDeLaLimpieza.JABONES.has(en_la_mano):
		return MULTIPLICADOR_DE_CORRER_INTERMEDIO
	return MULTIPLICADOR_DE_CORRER


## Lo que cuenta para el alcance: la distancia sobre el piso, sin la altura.
static func proximidad(ojo: Vector3, punto: Vector3) -> float:
	return Vector2(punto.x - ojo.x, punto.z - ojo.z).length()


## Dónde termina una mirada que sale de `ojo`: en el borde del alcance, por empinada que sea.
static func fin_de_la_mira(ojo: Vector3, direccion: Vector3) -> Vector3:
	var unitaria := direccion.normalized()
	var avance := maxf(Vector2(unitaria.x, unitaria.z).length(), AVANCE_MINIMO_DE_LA_MIRA)
	return ojo + unitaria * ALCANCE_DE_LA_MIRA / avance

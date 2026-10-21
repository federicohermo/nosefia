## La devolución de Enrique al cerrar una noche: los mensajes que manda por chat, ya elegidos, y
## qué puede elegir el jugador cuando terminan de llegar.
##
## **Los textos de la tabla viven sólo acá**, y las condiciones también: una fila elegida en la
## pantalla nacería sin test. Ningún texto muestra P, medios ni apercibimientos.
##
## P se cuenta en medios —P = 2 es cuatro medios— para no comparar decimales.
class_name DevolucionDelJefe
extends RefCounted

enum Opcion { CONTINUAR, VOLVER_AL_MENU }

## La ficha fija un segundo entre cada mensaje.
const SEGUNDOS_ENTRE_MENSAJES := 1.0

## Cuántos medios hay en un punto de la tabla.
const MEDIOS_POR_PUNTO := Reglas.MEDIOS_POR_APERCIBIMIENTO

const SALUDOS: Array[String] = ["Buen día!", "Buenas", "Hola", "Buenos días...", "Che"]

const TAREAS: Dictionary[Tarea.Tipo, Array] = {
	Tarea.Tipo.CAJA:
	[
		"Me llegó un comentario de un vecino que no fue correctamente atendido anoche.",
		"Ya es la segunda vez que escucho a un cliente quejarse de la atención nocturna del local.",
		(
			"Sigo recibiendo quejas de compradores. Eso no puede pasar. Entendés que "
			+ "la venta de productos es nuestra principal fuente de ingresos?"
		),
		"De qué me sirve tenerte de empleado si ni siquiera atendés bien a los clientes?",
	],
	Tarea.Tipo.REGISTRAR:
	[
		"El registro de la computadora no parece concordar con los ingresos de ayer.",
		"Otra vez te olvidaste de anotar los productos vendidos.",
		(
			"El registro de ventas está mal otra vez. Entendés que después tengo que "
			+ "estar haciendo cálculos revisando qué productos faltan para entender "
			+ "qué vendiste?"
		),
		(
			"No puede ser que no puedas hacer algo tan simple como anotar bien unos "
			+ "numeritos en una computadora."
		),
	],
	Tarea.Tipo.REPONER:
	[
		(
			"Faltó reponer algunas unidades en las góndolas. Como te dije, un único "
			+ "producto ausente puede hacer la diferencia."
		),
		(
			"No podés dejarle a tu compañera la tarea de completar los huecos en las "
			+ "góndolas. A veces hay que ponerse las pilas."
		),
		(
			"De nuevo quedaron algunas góndolas incompletas. Si te pido que queden "
			+ "llenas, es que queden llenas. No con algún que otro huequito. LLENAS."
		),
		(
			"Te lo puedo llegar a entender en las otras tareas, pero no es posible "
			+ "que no puedas hacer bien la reposición."
		),
	],
	Tarea.Tipo.LIMPIAR:
	[
		"Quedaron algunos rincones sucios en el local.",
		"Otra vez el local quedó sucio.",
		"No puede ser que siga quedando mugre en el local al momento de irte.",
		"De casualidad limpiás tu casa vos? Sabés cómo se usa una mopa?",
	],
}

## La Tarea 5 sale de la jornada: sólo las que declaran una particular tienen texto.
const PARTICULARES: Dictionary[int, String] = {
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA:
	(
		"Cuando te pedí que ordenaras las cajas en las estanterías del depósito, "
		+ "lo que quería decir es que pongas TODAS y cada una de las CAJAS de "
		+ "cartón con productos ARRIBA de las ESTANTERÍAS del DEPÓSITO. Ahí se "
		+ "entendió?"
	),
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1:
	"De verdad era tan difícil tirar tres bolsas de basura?",
}

## La fila de la ficha que termina la prueba: Enrique no dice nada más (BR-EMP-043).
const DESPIDO_DE_LA_PRUEBA := (
	"No, no, no. Flaco, no te puedo tomar como empleado si trabajás a medias. Un par de "
	+ "errores los puedo dejar pasar, pero si se repite todos los días...\n\nHasta acá "
	+ "llegó mi paciencia. Suerte consiguiendo otro trabajo."
)

const POETICO := (
	"Che, si usás un producto del local para la limpieza, me tenés que avisar. No podés "
	+ "hacer esas cosas sin consultarme. Espero que quede claro."
)
const POETICO_EN_EL_DESPIDO := (
	"Si usás un producto del local para la limpieza, me tenés que avisar. No podés hacer "
	+ "esas cosas sin consultarme."
)

## Los textos de los Retos; `retos()` los ordena como la ficha.
const PAPEL_1 := (
	"El baño se tapó. Por si no lo leíste, hay un cartelito muy claro "
	+ "diciendo que no se puede tirar papel en el inodoro."
)
const PAPEL_2 := (
	"Se tapó el baño de nuevo. Pensé que el cartelito y mi mensaje iban a "
	+ "ser suficientes, pero veo que te lo voy a tener que repetir. El papel "
	+ "se tira EN EL TACHO."
)
const PAPEL_MAS := "Dejá de tirar papel en el inodoro. Ya no sé cómo pedírtelo."
const PAPEL_MAS_DESPEDIDO := (
	"Una vez más tapaste el baño. Increíble. Yo que vos iría al neurólogo. O "
	+ "al gastroenterólogo, una de dos."
)
const BASURA_POR_JORNADA: Dictionary[int, String] = {
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1:
	(
		'Por si no lo sabías, la "basura" que te pedí que tiraras no incluye '
		+ "productos ni elementos del local. Estamos de acuerdo?"
	),
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2:
	(
		"Cuando te pedí que tiraras algunos productos, no me refería a objetos "
		+ "útiles y en buen estado!"
	),
}
const BASURA: Array[String] = [
	"Puede ser que hayas estado tirando cosas a la basura?",
	"El contenedor de basura es para BASURA solamente.",
	"Una vez más tuve que sacar cosas de la basura. Te parece gracioso?",
]
const AFUERA: Array[String] = [
	"Puedo saber por qué hay propiedad del local al pie de la ventana? Del lado de AFUERA?",
	(
		"Ya es la segunda vez que encuentro algo “mágicamente” depositado del "
		+ "otro lado de la ventanilla. Más te vale que no haya sido obra tuya."
	),
	(
		"En serio, si sigue apareciendo propiedad del local en la vereda, voy a "
		+ "tener que poner una reja en la ventanilla."
	),
	"BASTA DE TIRAR COSAS POR LA VENTANILLA!",
	"A esta altura del partido, ya estoy considerando tirarte a VOS por la ventanilla.",
]
const DESORDEN: Array[String] = [
	"Más allá de cumplir con los quehaceres, el orden también es importante.",
	"Dejá las cosas donde corresponde. Es una estación de servicio, no un pelotero.",
	(
		"Me parece que no está quedando claro el temita de dejar todo ordenado. "
		+ "En el corcho hay una nota que seguro te va a servir. Pegale una leída, "
		+ "dale?"
	),
	"Y si esta vez dejás ordenado? Sería mucho pedir?",
]
const DESORDEN_SIN_REMEDIO := (
	"Realmente me sorprende cómo alguien puede tener tan poca conciencia de "
	+ "lo que es el orden."
)

const CIERRE_DEL_DESPIDO := (
	"Es absurdo que tenga que estar persiguiéndote con estas cosas tan "
	+ "básicas. No puedo dejar que un desastre como vos siga perjudicando la "
	+ "reputación de mi local. Que ni se te ocurra volver a aparecer por acá, "
	+ "entendiste?"
)
## Por medios máximos, en la última: la primera fila cuyo tope alcanza a los medios gana.
const CIERRES_DE_LA_ULTIMA: Array[Array] = [
	[
		0,
		(
			"La verdad es que estoy impresionado. No hizo falta corregirte ni una "
			+ "sola cosa en las cinco noches. Un trabajo excepcional. Va a ser un "
			+ "placer tenerte trabajando acá."
		)
	],
	[
		2,
		(
			"Bueno, más allá de alguna que otra cosita que te mencioné, no tengo "
			+ "nada para corregirte. Un trabajo bien hecho. Felicitaciones, el puesto "
			+ "es tuyo."
		)
	],
	[
		4,
		(
			"Mirá, hubo un par de veces que la pifiaste, pero como soy generoso, te "
			+ "voy a dar el puesto igual. No aflojes. Desde ahora, espero que des lo "
			+ "mejor de vos."
		)
	],
	[
		6,
		(
			"Honestamente, solo puedo concluir que no sos el empleado ideal, pero "
			+ "tampoco sos un inútil. Decidí darte el puesto. No me hagas cambiar de "
			+ "opinión, ok?"
		)
	],
	[
		7,
		(
			"Me parece que quedan muchas cosas para pulir, pero ya te vas a curtir "
			+ "con el tiempo. No voy a negar que conocí peores empleados, así que te "
			+ "voy a dar una oportunidad. El puesto es tuyo, pero te voy a tener "
			+ "cortito para sacarte bien, está claro?"
		)
	],
]
## Una fila por jornada, de la primera completa a la anterior a la última.
const CIERRES_IMPECABLES: Dictionary[int, String] = {
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA:
	"Seguiste todas mis instrucciones al pie de la letra. Excelente. Seguí así.",
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1: "Nuevamente, todo en orden. Seguí así!",
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2:
	"Sin comentarios por mi parte. Dale para adelante.",
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3:
	"La jornada cerró cuadrada, como de costumbre. Excelente trabajo.",
}
const MEJORA_BAJA := "Ahora sí le vas agarrando la mano! Muy bien. Seguí así."
const MEJORA_BAJA_SOSTENIDA := "Sin nada para comentar. Adelante con eso."
const MEJORA_ALTA := "Esta vez sí cumpliste con todo. Bien. Continuá por este camino."
const MEJORA_ALTA_SOSTENIDA := "Sin comentarios."
## Por medios, con R = 0. P = 2 distingue si hubo llamados en la partida.
const ADVERTENCIAS: Dictionary[int, String] = {
	1:
	(
		"Te lo dejo pasar esta vez, pero tené en cuenta que hay ciertas normas "
		+ "básicas que tenés que cumplir además de hacer bien tus tareas."
	),
	2: "Que no se repita, ok?",
	3:
	(
		"No duermas con tus responsabilidades y prestá atención a no meter la "
		+ "pata con pavadas. Focalizate."
	),
	5:
	(
		"Puedo perdonar que te mandes alguna, pero tampoco la pavada. Estate "
		+ "atento a tus tareas y no boludees."
	),
	6: "En serio, mi paciencia tiene un límite...",
	7:
	(
		"Hay un límite en lo que te puedo dejar pasar. Un error más y te podés "
		+ "ir despidiendo de tu puesto."
	),
}
const ADVERTENCIA_SIN_LLAMADOS := (
	"Acordate de chequear que todas las tareas estén cerradas antes de irte, " + "dale?"
)
const ADVERTENCIA_CON_LLAMADOS := (
	"Acordate de hacer bien tu trabajo y respetar las normas básicas de " + "convivencia, dale?"
)

const ULTIMA_JORNADA := (
	ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
)
const MEDIOS_DEL_DESPIDO := Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO * MEDIOS_POR_PUNTO

var _mensajes: Array[String] = []
var _jornada: int = 0
var _opciones: Array[Opcion] = []


## La partida ya cerró esa noche: sus cuentas incluyen la noche, y sus obligatorias y llamados
## son los de la noche cerrada. Las jornadas de introducción cierran sin mensajes.
func _init(jornada: int, partida: Partida) -> void:
	_jornada = jornada
	_opciones.append(Opcion.VOLVER_AL_MENU if partida.terminada() else Opcion.CONTINUAR)
	# El despido de la prueba no abre la jornada siguiente: la partida sigue en la prueba.
	if partida.terminada() and partida.jornada() < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA:
		_mensajes = [DESPIDO_DE_LA_PRUEBA]
		return
	if jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA:
		return
	var sin_cumplir: Array[Tarea.Tipo] = []
	for tarea: Tarea in partida.obligatorias():
		if not tarea.completada():
			sin_cumplir.append(tarea.tipo())
	_mensajes = DevolucionDelJefe.armar(
		jornada,
		partida.medios(),
		partida.antecedentes(),
		sin_cumplir,
		partida.llamados(),
		partida.uso_de_poetico_en(jornada)
	)


func mensajes() -> Array[String]:
	return _mensajes.duplicate()


func opciones() -> Array[Opcion]:
	return _opciones.duplicate()


## Una función y no una constante: `Partida` arma la devolución, y una constante que nombra a
## `Partida` cerraría un ciclo de carga entre las dos.
static func retos() -> Array[Partida.Llamado]:
	return [
		Partida.Llamado.PAPEL_EN_EL_INODORO,
		Partida.Llamado.OBJETO_TIRADO,
		Partida.Llamado.OBJETO_AFUERA,
		Partida.Llamado.LOCAL_DESORDENADO,
	]


## Sin jornada explícita sigue siendo un texto legado: no se reconstruye su fecha.
static func mensaje(texto: String, jornada: int = 0, orden: int = 0) -> Mensaje:
	var nuevo := Mensaje.new()
	nuevo.texto = texto
	nuevo.de_quien = "Enrique Peldaño"
	nuevo.jornada = jornada
	nuevo.orden = orden
	nuevo.momento = Mensaje.Momento.CIERRE if jornada > 0 else Mensaje.Momento.SIN_FECHA
	if jornada > 0:
		nuevo.identidad = "DEVOLUCION_J%d_%d" % [jornada, orden]
	return nuevo


func mensajes_fechados() -> Array[Mensaje]:
	var fechados: Array[Mensaje] = []
	for indice: int in _mensajes.size():
		fechados.append(mensaje(_mensajes[indice], _jornada, indice))
	return fechados


## Cuántos mensajes están a la vista después de `transcurrido` segundos: el primero en cero.
static func a_la_vista(transcurrido: float, total: int) -> int:
	return mini(total, 1 + floori(maxf(0.0, transcurrido) / SEGUNDOS_ENTRE_MENSAJES))


## La tabla entera, con los hechos ya contados: la noche cerrada, los medios después de anotarla,
## las cuentas que la incluyen, lo que quedó sin cumplir y los llamados de esa noche.
static func armar(
	jornada: int,
	medios: int,
	antecedentes: Antecedentes,
	sin_cumplir: Array[Tarea.Tipo],
	llamados: Array[Partida.Llamado],
	uso_de_poetico: bool = false
) -> Array[String]:
	var mensajes: Array[String] = [_saludo(medios)]
	for tipo: Tarea.Tipo in Antecedentes.FIJAS:
		if sin_cumplir.has(tipo):
			var textos: Array = TAREAS[tipo]
			mensajes.append(textos[clampi(antecedentes.fallas(tipo), 1, textos.size()) - 1])
	if uso_de_poetico:
		mensajes.append(POETICO_EN_EL_DESPIDO if medios >= MEDIOS_DEL_DESPIDO else POETICO)
	if PARTICULARES.has(jornada) and _alguna_particular(sin_cumplir):
		mensajes.append(PARTICULARES[jornada])
	for motivo: Partida.Llamado in retos():
		if llamados.has(motivo):
			mensajes.append(_reto(motivo, antecedentes.llamados(motivo), jornada, medios))
	mensajes.append(_cierre(jornada, medios, antecedentes))
	return mensajes


@warning_ignore("integer_division")
static func _saludo(medios: int) -> String:
	return SALUDOS[mini(medios / MEDIOS_POR_PUNTO, SALUDOS.size() - 1)]


static func _alguna_particular(sin_cumplir: Array[Tarea.Tipo]) -> bool:
	for tipo: Tarea.Tipo in sin_cumplir:
		if not Antecedentes.FIJAS.has(tipo):
			return true
	return false


static func _reto(motivo: Partida.Llamado, n: int, jornada: int, medios: int) -> String:
	var despedido := medios >= MEDIOS_DEL_DESPIDO
	match motivo:
		Partida.Llamado.PAPEL_EN_EL_INODORO:
			if n <= 2:
				return PAPEL_1 if n <= 1 else PAPEL_2
			return PAPEL_MAS_DESPEDIDO if despedido else PAPEL_MAS
		Partida.Llamado.OBJETO_TIRADO:
			if BASURA_POR_JORNADA.has(jornada):
				return BASURA_POR_JORNADA[jornada]
			return BASURA[clampi(n, 1, BASURA.size()) - 1]
		Partida.Llamado.OBJETO_AFUERA:
			return AFUERA[clampi(n, 1, AFUERA.size()) - 1]
	if n <= 1:
		return DESORDEN[0]
	if n >= 5 or despedido:
		return DESORDEN_SIN_REMEDIO
	return DESORDEN[n - 1]


static func _cierre(jornada: int, medios: int, antecedentes: Antecedentes) -> String:
	if medios >= MEDIOS_DEL_DESPIDO:
		return CIERRE_DEL_DESPIDO
	if jornada == ULTIMA_JORNADA:
		for fila: Array in CIERRES_DE_LA_ULTIMA:
			if medios <= fila[0]:
				return fila[1]
	if medios == 0:
		return CIERRES_IMPECABLES[jornada]
	var noches := antecedentes.noches_sin_sumar()
	if noches >= 1:
		if medios < 2 * MEDIOS_POR_PUNTO:
			return MEJORA_BAJA if noches == 1 else MEJORA_BAJA_SOSTENIDA
		return MEJORA_ALTA if noches == 1 else MEJORA_ALTA_SOSTENIDA
	if medios == 2 * MEDIOS_POR_PUNTO:
		return (
			ADVERTENCIA_CON_LLAMADOS if antecedentes.hubo_llamados() else ADVERTENCIA_SIN_LLAMADOS
		)
	return ADVERTENCIAS[medios]

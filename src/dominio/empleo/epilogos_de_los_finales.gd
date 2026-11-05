## Las placas del epílogo de cada final narrativo (BR-SHF-070, BR-SHF-071).
##
## Cada final trae una imagen de fondo y el texto de sus placas, en el orden de la ficha. Una placa
## sin texto no se muestra: la ficha todavía no se lo cargó, y cuando lo cargue basta con
## escribirlo acá. Un final sin ninguna placa con texto no tiene epílogo. Los renglones de una
## placa se separan con un salto de línea.
class_name EpilogosDeLosFinales
extends RefCounted

const FONDO_DEL_FINAL_1: Texture2D = preload("res://assets/ui/manada/fondo_epilogo_1.png")
const FONDO_DEL_FINAL_2: Texture2D = preload("res://assets/ui/manada/fondo_epilogo_2.png")
const FONDO_DEL_FINAL_4: Texture2D = preload("res://assets/ui/manada/fondo_epilogo_4.png")
const FONDO_DEL_FINAL_5: Texture2D = preload("res://assets/ui/manada/fondo_epilogo_5.png")

const TEXTOS: Dictionary[FinalConPantalla.Cual, Array] = {
	FinalConPantalla.Cual.EMPLEADO_ESTRESADO:
	[
		(
			"Objetos que faltan, productos fuera de lugar, cortes de luz…\n"
			+ "Podría haberme obsesionado con encontrarle una explicación rebuscada a estos "
			+ "sucesos, pero opté por ignorarlos. Acá vine a TRA-BA-JAR, no a perseguirme con "
			+ "pavadas.\n"
			+ "Mis días de paranoiquear quedaron en el pasado, y estoy orgulloso de haber "
			+ "superado esa etapa de mi vida."
		),
		(
			"Por supuesto, las cosas raras siguieron pasando y yo tuve que seguir encontrando "
			+ "soluciones creativas para sortear esos problemas. ¡Y Enrique se da cuenta de lo "
			+ "mucho que me esfuerzo! Siempre aplaude mis habilidades para resolver conflictos "
			+ "sin agobiarme con cuestionamientos inútiles."
		),
		(
			"Por ejemplo, cuando conseguí arreglar los cables pelados de las heladeras sin "
			+ "desenchufarlas, para no interrumpir la cadena de frío. O cuando me quedé a "
			+ "cubrir ambos turnos el día que Yasmín se fue a visitar a su familia…"
		),
		(
			"O cuando se negó a pagarme el aguinaldo… Y el salario mínimo… Bah, tampoco le "
			+ "beneficiaba mucho tenerme en blanco, así que es lógico…"
		),
		(
			"Y cuando tuve que quedarme en cama después del pico de estrés y Enrique me lo "
			+ "descontó del sueldo… Del sueldo del mes siguiente, claro, porque todavía estaba "
			+ "en mi período de capacitación."
		),
		(
			"Pero bueno, uno tiene que hacer ojos ciegos a ciertas cosas para poder ser un "
			+ "buen empleado, ¿no?"
		),
	],
	FinalConPantalla.Cual.LOCURA_PARANOICA:
	[
		(
			"Lo intenté… traté de descubrir qué es lo que está causando estas anomalías… "
			+ "¡Pero no consigo elaborar una hipótesis clara!\n"
			+ "Objetos que faltan, productos fuera de lugar… No estoy loco… ¡Alguien está "
			+ "haciendo esto deliberadamente!"
		),
		(
			"No puedo descansar hasta entender qué es lo que está pasando… Pero necesito "
			+ "pruebas… Sino todos van a pensar que soy un obsesivo y un perseguido, como "
			+ "siempre... ¡¿Dónde están las pruebas?!"
		),
	],
	FinalConPantalla.Cual.JEFE_SABOTEADOR: ["", ""],
	FinalConPantalla.Cual.JEFE_INCOMPETENTE:
	[
		(
			"Detrás de esa puerta, pude encontrar las evidencias necesarias para apaciguar mis "
			+ "dudas.\n"
			+ "Bastó con abrir un cajón para encontrar pilas de facturas impagas, documentos "
			+ "mal clasificados, correspondencia que parecía llevar meses acumulando polvo y, "
			+ "bien al fondo, el lector de la caja medio desarmado, con una notita que decía "
			+ "“arreglar”. Vaya uno a saber cuándo iba a cumplir esa promesa."
		),
		(
			"Era obvio. La escasez de elementos de trabajo, los productos vencidos, los cortes "
			+ "de luz por falta de mantenimiento… Todo fue culpa de la incompetencia de "
			+ "Enrique.\n"
			+ "Y no cabe duda de que el desorden de los productos esa noche se debió también a "
			+ "algún error de su parte."
		),
		(
			"Yasmín siempre tuvo razón en sus advertencias sobre la inutilidad de Enrique, así "
			+ "que la llamé de inmediato para que viniera y pudiera tener la satisfacción de "
			+ "ver las pruebas con sus propios ojos. Juntos, continuamos desenterrando "
			+ "documentos, y descubrimos que la situación era mucho peor de lo que habíamos "
			+ "pensado."
		),
		(
			"Enrique venía acumulando deudas a mansalva, y algunos acreedores ya estaban "
			+ "iniciando acciones legales. La estación de servicio estaba al borde de la "
			+ "quiebra y nos íbamos a quedar sin trabajo en cualquier momento."
		),
		(
			"Para fortuna nuestra, la tía de Yasmín era la abogada del pueblo, y nos ayudó a "
			+ "elaborar un plan para salir bien parados. Parece ser que, si armábamos una "
			+ "cooperativa, podíamos “solicitar continuar con la explotación del "
			+ "establecimiento y adquirir la unidad productiva durante el proceso de "
			+ "liquidación”. O sea, en palabras sencillas, le podíamos afanar el local a "
			+ "Enrique. De forma legal, claro."
		),
		(
			"No teníamos mucha plata ni experiencia, pero contábamos con varias cosas que "
			+ "nuestro jefe pasaba por alto: conocíamos muy bien el funcionamiento de la "
			+ "estación, sabíamos tratar con la gente y, sobre todo, éramos quienes hacíamos "
			+ "todo el trabajo."
		),
		(
			"Unos meses después, la estación de servicio estaba bajo nuestro mando.\n"
			+ "Enrique se fue del pueblo y no volvimos a saber de él."
		),
	],
}

const FONDOS: Dictionary[FinalConPantalla.Cual, Texture2D] = {
	FinalConPantalla.Cual.EMPLEADO_ESTRESADO: FONDO_DEL_FINAL_1,
	FinalConPantalla.Cual.LOCURA_PARANOICA: FONDO_DEL_FINAL_2,
	FinalConPantalla.Cual.JEFE_SABOTEADOR: FONDO_DEL_FINAL_4,
	FinalConPantalla.Cual.JEFE_INCOMPETENTE: FONDO_DEL_FINAL_5,
}


## Una placa del epílogo: su fondo y su texto.
class Placa:
	extends RefCounted

	var fondo: Texture2D
	var texto: String

	func _init(fondo_de_la_placa: Texture2D, texto_de_la_placa: String) -> void:
		fondo = fondo_de_la_placa
		texto = texto_de_la_placa


## Las placas con texto del epílogo de un final, en orden. Vacía si el final no tiene epílogo: el
## despido, la partida en curso, o un final al que la ficha todavía no le escribió ninguna placa.
static func placas_de(final: FinalConPantalla.Cual) -> Array[Placa]:
	if not TEXTOS.has(final):
		return []
	return con_texto(FONDOS[final], TEXTOS[final])


## Una placa por cada texto no vacío, todas con el mismo fondo.
static func con_texto(fondo: Texture2D, textos: Array) -> Array[Placa]:
	var placas: Array[Placa] = []
	for texto: String in textos:
		if not texto.is_empty():
			placas.append(Placa.new(fondo, texto))
	return placas

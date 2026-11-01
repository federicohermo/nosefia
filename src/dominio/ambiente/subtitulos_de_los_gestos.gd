## Lo que piensa el protagonista cuando un gesto le sale mal (BR-SUB-013), y la mopa berreta la
## primera vez que se seca (BR-SUB-014). Los textos se copian de la ficha «Subtítulos».
##
## **La mopa berreta espera al examen.** Mientras se examina algo, la línea muestra el texto fijo
## de lo examinado: el aviso queda pendiente y se entrega al terminar. Recién ahí cuenta como
## mostrado, para que un cierre con el aviso pendiente no lo pierda.
class_name SubtitulosDeLosGestos
extends RefCounted

enum Id {
	NINGUNO,
	MALA_IDEA,
	CAJA_EN_EL_CONTENEDOR,
	UTIL_EN_EL_CONTENEDOR,
	POR_LA_VENTANA,
	JABON_EQUIVOCADO,
	MOPA_SIN_MOJAR,
	MOPA_YA_SECA,
	MOPA_BERRETA,
	PARED_DEL_OTRO_INODORO,
	PISO_DE_LAS_ESTANTERIAS_DEL_FONDO,
	TECHO_SOBRE_UN_CUBICULO,
	PUERTA_CON_TAREAS_PENDIENTES,
}

## No declara `class_name`: se preloadea para preguntarle qué se tira sin llamado.
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const TEXTOS: Dictionary[Id, String] = {
	Id.NINGUNO: "",
	Id.MALA_IDEA: "Me parece que eso fue una mala idea…",
	Id.CAJA_EN_EL_CONTENEDOR:
	(
		"La caja es bastante grande para el contenedor. Rebalsaría. Además, Enrique me pidió que no"
		+ " tire las cajas de productos, ni siquiera las vacías."
	),
	Id.UTIL_EN_EL_CONTENEDOR: "Me parece que no debería tirar\nlos elementos de limpieza.",
	Id.POR_LA_VENTANA: "Si Enrique se entera de que estoy tirando cosas por la ventana, me mata.",
	Id.JABON_EQUIVOCADO: "Esto no está funcionando… Creo que no estoy usando el jabón correcto.",
	Id.MOPA_SIN_MOJAR: "Necesitaría mojar la mopa en agua con jabón.",
	Id.MOPA_YA_SECA: "Ya se secó la mopa…",
	Id.MOPA_BERRETA: "Dios mío, qué mopa berreta. Se seca a los tres segundos. Literal.",
	Id.PARED_DEL_OTRO_INODORO: "Se ve que alguien no tuvo tiempo de apuntar bien…",
	Id.PISO_DE_LAS_ESTANTERIAS_DEL_FONDO: "Espero que sea vómito…",
	Id.TECHO_SOBRE_UN_CUBICULO: "¿¿Cómo llegó eso ahí??",
	Id.PUERTA_CON_TAREAS_PENDIENTES: "No debería irme. Todavía me quedan tareas por completar.",
}
const DE_LAS_MANCHAS: Dictionary[PisoDelLocal.Lugar, Id] = {
	PisoDelLocal.Lugar.PARED_DEL_OTRO_INODORO: Id.PARED_DEL_OTRO_INODORO,
	PisoDelLocal.Lugar.PISO_DE_LAS_ESTANTERIAS_DEL_FONDO: Id.PISO_DE_LAS_ESTANTERIAS_DEL_FONDO,
	PisoDelLocal.Lugar.TECHO_SOBRE_UN_CUBICULO: Id.TECHO_SOBRE_UN_CUBICULO,
}

## Cuánto se espera que lo soltado quede quieto antes de mirar si cayó afuera.
const SEGUNDOS_PARA_QUEDAR_QUIETO := 10.0

var _berreta_pendiente := false


## Lo tirado sin llamado no piensa: es lo que va al contenedor.
static func al_tirar(
	sostenido: ObjetoDelAlmacen, tiro: ReglasDeLaBasura.Tiro, levanta_una_pista: bool
) -> Id:
	match tiro:
		ReglasDeLaBasura.Tiro.TIRADO:
			var eximido := ReglasDelCierre.esta_eximido(sostenido, levanta_una_pista)
			return Id.NINGUNO if eximido else Id.MALA_IDEA
		ReglasDeLaBasura.Tiro.NO_ENTRA:
			return Id.UTIL_EN_EL_CONTENEDOR if _es_un_util(sostenido) else Id.CAJA_EN_EL_CONTENEDOR
	return Id.NINGUNO


static func _es_un_util(objeto: ObjetoDelAlmacen) -> bool:
	return (
		objeto.id == ReglasDeLaLimpieza.ID_DE_LA_MOPA
		or objeto.id == ReglasDeLaLimpieza.ID_DEL_BALDE
		or ReglasDeLaLimpieza.JABONES.has(objeto.id)
	)


static func al_quedar_afuera(objeto: ObjetoDelAlmacen) -> Id:
	if objeto == null or objeto is Ticket:
		return Id.NINGUNO
	return Id.POR_LA_VENTANA


## `se_mojo` dice si la mopa se mojó en esta jornada: seca, la queja es otra.
static func al_pasar_la_mopa(resultado: ReglasDeLaLimpieza.Resultado, se_mojo: bool) -> Id:
	match resultado:
		ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO:
			return Id.JABON_EQUIVOCADO
		ReglasDeLaLimpieza.Resultado.SIN_JABON:
			return Id.MOPA_SIN_MOJAR
		ReglasDeLaLimpieza.Resultado.MOPA_SECA:
			return Id.MOPA_YA_SECA if se_mojo else Id.MOPA_SIN_MOJAR
	return Id.NINGUNO


static func al_borrar(lugar: PisoDelLocal.Lugar) -> Id:
	return DE_LAS_MANCHAS.get(lugar, Id.NINGUNO)


## En una jornada de prueba, la entrada que no deja salir es porque queda una obligatoria. Que el
## aviso de salida espere a la computadora (BR-NTF-014) no cambia eso: se mira el cumplimiento y no
## el permiso.
static func al_usar_la_entrada(
	jornada: int,
	obligatorias: Array[Tarea],
	atender: TareaDeAtender = null,
	registro: RegistroDeVentas = null
) -> Id:
	if (
		jornada in CierreAnticipado.JORNADAS
		and not CierreAnticipado.corresponde(jornada, obligatorias, atender, registro)
	):
		return Id.PUERTA_CON_TAREAS_PENDIENTES
	return Id.NINGUNO


static func texto(id: Id) -> String:
	return TEXTOS[id]


## La identidad que hay que mostrar ya, o `NINGUNO` si no toca o si espera al examen.
func al_secarse_la_mopa(partida: Partida, examinando: bool) -> Id:
	if partida.mopa_secada() or _berreta_pendiente:
		return Id.NINGUNO
	if examinando:
		_berreta_pendiente = true
		return Id.NINGUNO
	partida.anotar_mopa_secada()
	return Id.MOPA_BERRETA


func al_terminar_el_examen(partida: Partida) -> Id:
	if not _berreta_pendiente:
		return Id.NINGUNO
	_berreta_pendiente = false
	partida.anotar_mopa_secada()
	return Id.MOPA_BERRETA


## El cierre de la jornada tira el aviso que no llegó a mostrarse: la partida sigue sin marca.
func descartar() -> void:
	_berreta_pendiente = false

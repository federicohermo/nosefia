## Lo que piensa el protagonista cuando un gesto le sale mal (BR-SUB-013), y la mopa berreta la
## primera vez que se seca (BR-SUB-014). Los textos se copian de la ficha «Subtítulos».
##
## **La mopa berreta espera al examen.** Mientras se examina algo, la línea muestra el texto fijo
## de lo examinado: el aviso queda pendiente y se entrega al terminar. Recién ahí cuenta como
## mostrado, para que un cierre con el aviso pendiente no lo pierda.
class_name SubtitulosDeLosGestos
extends RefCounted

## No declara `class_name`: se preloadea para preguntarle qué se tira sin llamado.
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const MALA_IDEA := "Me parece que eso fue una mala idea…"
const CAJA_EN_EL_CONTENEDOR := (
	"La caja es bastante grande para el contenedor. Rebalsaría. Además, Enrique me pidió que no"
	+ " tire las cajas de productos, ni siquiera las vacías."
)
const POR_LA_VENTANA := "Si Enrique se entera de que estoy tirando cosas por la ventana, me mata."
const JABON_EQUIVOCADO := "Esto no está funcionando… Creo que no estoy usando el jabón correcto."
const MOPA_SIN_MOJAR := "Necesitaría mojar la mopa en agua con jabón."
const MOPA_YA_SECA := "Ya se secó la mopa…"
const MOPA_BERRETA := "Dios mío, qué mopa berreta. Se seca a los tres segundos. Literal."
const DE_LAS_MANCHAS: Dictionary[PisoDelLocal.Lugar, String] = {
	PisoDelLocal.Lugar.PARED_DEL_OTRO_INODORO: "Se ve que alguien no tuvo tiempo de apuntar bien…",
}

## Cuánto se espera que lo soltado quede quieto antes de mirar si cayó afuera.
const SEGUNDOS_PARA_QUEDAR_QUIETO := 10.0

var _berreta_pendiente := false


## Lo tirado sin llamado —una bolsa o un ticket— no piensa: es lo que va al contenedor.
static func al_tirar(sostenido: ObjetoDelAlmacen, tiro: ReglasDeLaBasura.Tiro) -> String:
	match tiro:
		ReglasDeLaBasura.Tiro.TIRADO:
			return "" if ReglasDelCierre.se_tira_sin_llamado(sostenido) else MALA_IDEA
		ReglasDeLaBasura.Tiro.NO_ENTRA:
			return CAJA_EN_EL_CONTENEDOR
	return ""


static func al_quedar_afuera(objeto: ObjetoDelAlmacen) -> String:
	if objeto == null or objeto is Ticket:
		return ""
	return POR_LA_VENTANA


## `se_mojo` dice si la mopa se mojó en esta jornada: seca, la queja es otra.
static func al_pasar_la_mopa(resultado: ReglasDeLaLimpieza.Resultado, se_mojo: bool) -> String:
	match resultado:
		ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO, ReglasDeLaLimpieza.Resultado.SIN_JABON:
			return JABON_EQUIVOCADO
		ReglasDeLaLimpieza.Resultado.MOPA_SECA:
			return MOPA_YA_SECA if se_mojo else MOPA_SIN_MOJAR
	return ""


static func al_borrar(lugar: PisoDelLocal.Lugar) -> String:
	return DE_LAS_MANCHAS.get(lugar, "")


## El texto que hay que mostrar ya, o vacío si no toca o si queda esperando al examen.
func al_secarse_la_mopa(partida: Partida, examinando: bool) -> String:
	if partida.mopa_secada() or _berreta_pendiente:
		return ""
	if examinando:
		_berreta_pendiente = true
		return ""
	partida.anotar_mopa_secada()
	return MOPA_BERRETA


func al_terminar_el_examen(partida: Partida) -> String:
	if not _berreta_pendiente:
		return ""
	_berreta_pendiente = false
	partida.anotar_mopa_secada()
	return MOPA_BERRETA


## El cierre de la jornada tira el aviso que no llegó a mostrarse: la partida sigue sin marca.
func descartar() -> void:
	_berreta_pendiente = false

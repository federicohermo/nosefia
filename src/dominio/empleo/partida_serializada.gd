## Lo que cruza la sesión: qué campos lleva el guardado, con su tipo y su defecto.
##
## Recibe y devuelve un diccionario. El disco es de `sistemas/`.
class_name PartidaSerializada
extends RefCounted

enum Campo {
	JORNADA,
	MEDIOS,
	FALLAS,
	LLAMADOS,
	NOCHES_SIN_SUMAR,
	DEVOLUCIONES,
	MOPA_SECADA,
	EXPEDIENTE,
	NOTAS,
	CIERRE_PENDIENTE,
	ELECCIONES,
	NOCHES_DE_PRUEBA,
	APERCIBIMIENTOS_DE_LA_PRUEBA,
	ULTIMA_DE_LA_PRUEBA_COMPLETA,
	SEMILLA,
	POSES_DE_LAS_CAJAS,
}

const VERSION: int = 2
const CLAVE_DE_VERSION := "version"

## El tipo de cada campo es el de su defecto.
const DEFECTOS: Dictionary[Campo, Variant] = {
	Campo.JORNADA: ReglasDeLaPartida.PRIMERA_JORNADA,
	Campo.MEDIOS: 0,
	## Las cuentas y las devoluciones de Enrique (BR-SAV-019). Su contenido lo sanea quien lo
	## lee: acá sólo se mira que sean un diccionario, un entero y una lista.
	Campo.FALLAS: {},
	Campo.LLAMADOS: {},
	Campo.NOCHES_SIN_SUMAR: 0,
	Campo.DEVOLUCIONES: [],
	Campo.MOPA_SECADA: false,
	Campo.EXPEDIENTE: [],
	Campo.NOTAS: [],
	Campo.CIERRE_PENDIENTE: 0,
	Campo.ELECCIONES: {},
	## Por jornada cerrada, lo que anota `ResultadoDeLaNoche` (BR-EMP-041).
	Campo.NOCHES_DE_PRUEBA: {},
	Campo.APERCIBIMIENTOS_DE_LA_PRUEBA: 0,
	Campo.ULTIMA_DE_LA_PRUEBA_COMPLETA: false,
	Campo.SEMILLA: 0,
	## La pose de cada caja del depósito al cierre, por identidad de caja (BR-SAV-022). Quien lo
	## lee descarta lo que no es una caja con su pose.
	Campo.POSES_DE_LAS_CAJAS: {},
}


static func clave(campo: Campo) -> String:
	return Campo.keys()[campo].to_lower()


## Completa lo que falta y reemplaza lo mal tipado con su defecto. Siempre lleva la versión actual.
static func sanear(crudo: Dictionary) -> Dictionary:
	var saneado := {CLAVE_DE_VERSION: VERSION}
	for campo: Campo in DEFECTOS:
		var valor: Variant = crudo.get(clave(campo))
		var defecto: Variant = DEFECTOS[campo]
		var leido: Variant = valor if typeof(valor) == typeof(defecto) else defecto
		# Una copia: el defecto es una constante y quien lo recibe puede llenarlo.
		saneado[clave(campo)] = (
			leido.duplicate(true) if leido is Dictionary or leido is Array else leido
		)
	return saneado


## Un guardado sin versión, o con una versión que no es un entero, se lee como el actual.
static func legible(crudo: Dictionary) -> bool:
	var version: Variant = crudo.get(CLAVE_DE_VERSION)
	return typeof(version) != TYPE_INT or version <= VERSION

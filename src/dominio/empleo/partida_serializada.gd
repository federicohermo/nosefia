## Lo que cruza la sesión: qué campos lleva el guardado, con su tipo y su defecto.
##
## Recibe y devuelve un diccionario. El disco es de `sistemas/`.
class_name PartidaSerializada
extends RefCounted

enum Campo { JORNADA, APERCIBIMIENTOS }

const VERSION: int = 1
const CLAVE_DE_VERSION := "version"

## El tipo de cada campo es el de su defecto.
const DEFECTOS: Dictionary[Campo, Variant] = {
	Campo.JORNADA: ReglasDeLaPartida.PRIMERA_JORNADA,
	Campo.APERCIBIMIENTOS: 0,
}


static func clave(campo: Campo) -> String:
	return Campo.keys()[campo].to_lower()


## Completa lo que falta y reemplaza lo mal tipado con su defecto. Siempre lleva la versión actual.
static func sanear(crudo: Dictionary) -> Dictionary:
	var saneado := {CLAVE_DE_VERSION: VERSION}
	for campo: Campo in DEFECTOS:
		var valor: Variant = crudo.get(clave(campo))
		var defecto: Variant = DEFECTOS[campo]
		saneado[clave(campo)] = valor if typeof(valor) == typeof(defecto) else defecto
	return saneado


## Un guardado sin versión, o con una versión que no es un entero, se lee como el actual.
static func legible(crudo: Dictionary) -> bool:
	var version: Variant = crudo.get(CLAVE_DE_VERSION)
	return typeof(version) != TYPE_INT or version <= VERSION

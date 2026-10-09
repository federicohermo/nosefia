## La foto del cierre: pertenencia física y motivos, sin consultar cuerpos del motor.
extends RefCounted

enum Habitacion { LOCAL, DEPOSITO, BANO, AFUERA }
enum Clase { UNIDAD_SUELTA, CAJA, UTIL_DE_LIMPIEZA, OTRO }


class Estado:
	extends RefCounted

	var clase: Clase
	var habitacion: Habitacion
	var en_mano: bool

	func _init(tipo: Clase, lugar: Habitacion, sostenido: bool) -> void:
		clase = tipo
		habitacion = lugar
		en_mano = sostenido


static func habitacion_de(
	punto: Vector3, local: Array[AABB], deposito: Array[AABB], bano: Array[AABB]
) -> Habitacion:
	for parte: AABB in local:
		if parte.has_point(punto):
			return Habitacion.LOCAL
	for parte: AABB in deposito:
		if parte.has_point(punto):
			return Habitacion.DEPOSITO
	for parte: AABB in bano:
		if parte.has_point(punto):
			return Habitacion.BANO
	return Habitacion.AFUERA


static func hay_desorden(estados: Array[Estado]) -> bool:
	for estado: Estado in estados:
		if estado.en_mano or estado.habitacion == Habitacion.AFUERA:
			continue
		match estado.clase:
			Clase.UNIDAD_SUELTA:
				return true
			Clase.CAJA:
				if estado.habitacion != Habitacion.DEPOSITO:
					return true
			Clase.UTIL_DE_LIMPIEZA:
				if estado.habitacion != Habitacion.BANO:
					return true
	return false


static func hay_objetos_afuera(estados: Array[Estado]) -> bool:
	for estado: Estado in estados:
		if not estado.en_mano and estado.habitacion == Habitacion.AFUERA:
			return true
	return false

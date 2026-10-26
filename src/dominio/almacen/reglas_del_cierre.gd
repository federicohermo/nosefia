## La foto del cierre: pertenencia física y motivos, sin consultar cuerpos del motor.
extends RefCounted

enum Habitacion { LOCAL, DEPOSITO, BANO, AFUERA, CUARTITO }
enum Clase { UNIDAD_SUELTA, CAJA, UTIL_DE_LIMPIEZA, OTRO, BOLSA }

const CAJAS_TOLERADAS_EN_EL_LOCAL := 1


class Estado:
	extends RefCounted

	var clase: Clase
	var habitacion: Habitacion
	var en_mano: bool
	var producto: StringName
	var exento: bool

	func _init(
		tipo: Clase,
		lugar: Habitacion,
		sostenido: bool,
		identidad: StringName = ObjetoDelAlmacen.SIN_ID,
		eximido: bool = false
	) -> void:
		clase = tipo
		habitacion = lugar
		en_mano = sostenido
		producto = identidad
		exento = eximido


static func habitacion_de(
	punto: Vector3,
	local: Array[AABB],
	deposito: Array[AABB],
	bano: Array[AABB],
	cuartito: Array[AABB],
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
	for parte: AABB in cuartito:
		if parte.has_point(punto):
			return Habitacion.CUARTITO
	return Habitacion.AFUERA


static func hay_desorden(estados: Array[Estado], jornada: int) -> bool:
	var cajas_que_ocupan_la_tolerancia := 0
	for estado: Estado in estados:
		if estado.en_mano:
			if estado.clase == Clase.CAJA:
				cajas_que_ocupan_la_tolerancia += 1
			continue
		if estado.habitacion == Habitacion.AFUERA:
			continue
		match estado.clase:
			Clase.UNIDAD_SUELTA:
				if not AnomaliasDeLaJornada.sustituye_azul(estado.producto, jornada):
					return true
			Clase.CAJA:
				match estado.habitacion:
					Habitacion.LOCAL:
						cajas_que_ocupan_la_tolerancia += 1
					Habitacion.DEPOSITO:
						pass
					_:
						return true
			Clase.UTIL_DE_LIMPIEZA:
				if estado.habitacion != Habitacion.CUARTITO:
					return true
	return cajas_que_ocupan_la_tolerancia > CAJAS_TOLERADAS_EN_EL_LOCAL


static func hay_objetos_afuera(estados: Array[Estado]) -> bool:
	for estado: Estado in estados:
		if not estado.en_mano and not estado.exento and estado.habitacion == Habitacion.AFUERA:
			return true
	return false


static func hay_bolsa_afuera(estados: Array[Estado]) -> bool:
	for estado: Estado in estados:
		if (
			estado.clase == Clase.BOLSA
			and not estado.en_mano
			and estado.habitacion == Habitacion.AFUERA
		):
			return true
	return false


## La única puerta de la exención (BR-CLN-038): lo que no suma llamado afuera ni en el contenedor.
##
## `levanta_una_pista` lo dice la partida, que es quien conoce el caso: acá no se lo busca.
static func esta_eximido(objeto: ObjetoDelAlmacen, levanta_una_pista: bool) -> bool:
	if objeto == null:
		return false
	return (
		objeto is Ticket
		or objeto.vencido
		or ReglasDeLaBasura.ids_de_las_bolsas().has(objeto.id)
		or levanta_una_pista
	)

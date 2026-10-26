## La foto del cierre: pertenencia física y motivos, sin consultar cuerpos del motor.
extends RefCounted

enum Habitacion { LOCAL, DEPOSITO, BANO, AFUERA, CUARTITO }
enum Clase { UNIDAD_SUELTA, CAJA, UTIL_DE_LIMPIEZA, OTRO, BOLSA }

enum Heladera { PRIMERA, SEGUNDA, FUERA_DE_SERVICIO }

const CAJAS_TOLERADAS_EN_EL_LOCAL := 1

## La fuera de servicio no enfría nada: dejarla abierta no es un descuido.
const _FUNCIONALES: Array[Heladera] = [Heladera.PRIMERA, Heladera.SEGUNDA]


class Estado:
	extends RefCounted

	var clase: Clase
	var habitacion: Habitacion
	var en_mano: bool
	var producto: StringName

	func _init(
		tipo: Clase,
		lugar: Habitacion,
		sostenido: bool,
		identidad: StringName = ObjetoDelAlmacen.SIN_ID
	) -> void:
		clase = tipo
		habitacion = lugar
		en_mano = sostenido
		producto = identidad


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
	return not clases_de_desorden(estados, jornada).is_empty()


## Cuáles de las tres clases de desorden hubo, en el orden de la ficha: unidades sueltas, cajas y
## útiles.
static func clases_de_desorden(estados: Array[Estado], jornada: int) -> Array[Clase]:
	var hay_unidad_suelta := false
	var hay_caja_fuera_del_deposito := false
	var hay_util_fuera_del_cuartito := false
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
					hay_unidad_suelta = true
			Clase.CAJA:
				match estado.habitacion:
					Habitacion.LOCAL:
						cajas_que_ocupan_la_tolerancia += 1
					Habitacion.DEPOSITO:
						pass
					_:
						hay_caja_fuera_del_deposito = true
			Clase.UTIL_DE_LIMPIEZA:
				if estado.habitacion != Habitacion.CUARTITO:
					hay_util_fuera_del_cuartito = true
	var clases: Array[Clase] = []
	if hay_unidad_suelta:
		clases.append(Clase.UNIDAD_SUELTA)
	if hay_caja_fuera_del_deposito or cajas_que_ocupan_la_tolerancia > CAJAS_TOLERADAS_EN_EL_LOCAL:
		clases.append(Clase.CAJA)
	if hay_util_fuera_del_cuartito:
		clases.append(Clase.UTIL_DE_LIMPIEZA)
	return clases


static func hay_objetos_afuera(estados: Array[Estado]) -> bool:
	for estado: Estado in estados:
		if not estado.en_mano and estado.habitacion == Habitacion.AFUERA:
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


## Cuenta la puerta pedida abierta, aunque la hoja todavía no haya girado.
static func hay_heladera_abierta(puertas: Dictionary[Heladera, Puerta]) -> bool:
	for heladera: Heladera in _FUNCIONALES:
		if puertas.has(heladera) and puertas[heladera].abierta():
			return true
	return false


static func se_tira_sin_llamado(objeto: ObjetoDelAlmacen) -> bool:
	return (
		objeto != null and (objeto is Ticket or ReglasDeLaBasura.ids_de_las_bolsas().has(objeto.id))
	)

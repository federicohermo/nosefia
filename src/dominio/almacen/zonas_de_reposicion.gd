## Las siete zonas del piso del local donde puede faltar reponer, y qué productos cubre cada una.
##
## Una zona tiene faltante cuando algún producto que cubre tiene un casillero vacío en su fila de
## adelante. La respuesta sale del estante en el momento de preguntar: acá no se guarda ninguna
## bandera que pueda quedar desactualizada.
##
## **Cada etapa tiene su reparto.** En las jornadas de prueba el local lleva menos productos, y
## varios están en otro mueble que en el local completo, así que la tabla no se comparte.
class_name ZonasDeReposicion
extends RefCounted

const SIN_ZONA := 0
const CANTIDAD := 7

## Las líneas que separan las zonas, en metros y en el marco de la estructura del local. Salen de
## dónde están los muebles en el modelo y no de la imagen del mapa, que no está a escala.
const X_OESTE := -2.5
const X_ISLA_PRIMERA := -0.15
const X_CORTE := 1.4
const X_ISLA_SEGUNDA := 2.75
const X_ESTANTERIA := 4.5
const X_ESTE := 6.7
const Z_NORTE := -7.9
const Z_NORTE_DE_LAS_ISLAS := -3.9
const Z_SUR_DE_LAS_ISLAS := -1.0
const Z_SUR := 0.75

## `zona → Vector4(x0, z0, x1, z1)`. Cada zona incluye su borde de menor coordenada y excluye el
## de mayor, y por eso un punto sobre una línea es siempre de la misma. Una zona toca a otra sólo
## por una línea declarada una vez.
const LIMITES: Dictionary[int, Vector4] = {
	1: Vector4(X_OESTE, Z_NORTE, X_CORTE, Z_NORTE_DE_LAS_ISLAS),
	2: Vector4(X_CORTE, Z_NORTE, X_ESTANTERIA, Z_NORTE_DE_LAS_ISLAS),
	3: Vector4(X_OESTE, Z_NORTE_DE_LAS_ISLAS, X_ISLA_PRIMERA, Z_SUR_DE_LAS_ISLAS),
	4: Vector4(X_ISLA_PRIMERA, Z_NORTE_DE_LAS_ISLAS, X_ISLA_SEGUNDA, Z_SUR_DE_LAS_ISLAS),
	5: Vector4(X_ISLA_SEGUNDA, Z_NORTE_DE_LAS_ISLAS, X_ESTE, Z_SUR_DE_LAS_ISLAS),
	6: Vector4(X_OESTE, Z_SUR_DE_LAS_ISLAS, X_CORTE, Z_SUR),
	7: Vector4(X_CORTE, Z_SUR_DE_LAS_ISLAS, X_ESTE, Z_SUR),
}

## `zona → productos`, por la tanda principal de cada uno en el local de las jornadas de prueba.
const DE_PRUEBA: Dictionary[int, Array] = {
	1: [Producto.Id.PURA_COLA, Producto.Id.MAYONCHIS, Producto.Id.FERNET_GOD],
	2: [Producto.Id.ACTRONCITO, Producto.Id.DURONGA, Producto.Id.JORGILLO],
	3: [Producto.Id.ARVECOR, Producto.Id.MAROLINI],
	4:
	[
		Producto.Id.TERMINATOR,
		Producto.Id.ZUCARACHAS,
		Producto.Id.PROGRES,
		Producto.Id.DON_SATURADOS,
	],
	5: [Producto.Id.PEPITO, Producto.Id.PETISAS],
	6: [Producto.Id.MALBARDO],
	7: [Producto.Id.POETICO],
}

## Lo mismo para el local de la primera jornada completa.
const COMPLETA: Dictionary[int, Array] = {
	1:
	[
		Producto.Id.PURA_COLA,
		Producto.Id.OAAAA,
		Producto.Id.CINDOLOR,
		Producto.Id.MAYONCHIS,
		Producto.Id.TERMINATOR,
		Producto.Id.FERNET_GOD,
	],
	2:
	[
		Producto.Id.ACTRONCITO,
		Producto.Id.DUREXTRA,
		Producto.Id.POETICO,
		Producto.Id.DURONGA,
		Producto.Id.JORGILLO,
		Producto.Id.BURBALOO,
	],
	3: [Producto.Id.MAROLINI, Producto.Id.ARVECOR, Producto.Id.UAKALAS, Producto.Id.MARRANOS],
	4:
	[
		Producto.Id.ZUCARACHAS,
		Producto.Id.FROT_LUPS,
		Producto.Id.MACUMBAS,
		Producto.Id.PEPITO,
		Producto.Id.SALADICK,
		Producto.Id.PROGRES,
		Producto.Id.CHISITOS,
		Producto.Id.LAYSNNT,
	],
	5:
	[
		Producto.Id.DON_SATURADOS,
		Producto.Id.PETISAS,
		Producto.Id.OREMOS,
		Producto.Id.FEEL_RICKY_FORT,
	],
	6: [Producto.Id.MALBARDO, Producto.Id.AMARGADITO],
	7: [Producto.Id.COSA_DE_MANI, Producto.Id.FLIM_POF],
}

var _jornada: int
var _reparto: Dictionary[int, Array]


func _init(jornada: int) -> void:
	_jornada = jornada
	_reparto = (COMPLETA if jornada >= ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA else DE_PRUEBA)


## La zona de ese producto, o `SIN_ZONA` si el local de esta etapa no lo lleva.
func zona_de_producto(id: Producto.Id) -> int:
	for zona: int in _reparto:
		if _reparto[zona].has(id):
			return zona
	return SIN_ZONA


## Los productos que cubre esa zona, o ninguno si la zona no existe.
func productos_de(zona: int) -> Array[Producto.Id]:
	var ids: Array[Producto.Id] = []
	ids.assign(_reparto.get(zona, []))
	return ids


## La zona que contiene ese punto del piso, o `SIN_ZONA` si cae fuera de las siete, como el
## depósito. La altura no cuenta.
func zona_de(punto: Vector3) -> int:
	for zona: int in LIMITES:
		var limites := LIMITES[zona]
		if (
			punto.x >= limites.x
			and punto.x < limites.z
			and punto.z >= limites.y
			and punto.z < limites.w
		):
			return zona
	return SIN_ZONA


## Si algún producto de esa zona tiene un casillero vacío en este momento.
##
## Una jornada que no declara reponer no tiene zonas con faltante: las unidades que se agarran
## para vender no son trabajo pendiente.
func tiene_faltante(zona: int, estante: Estante) -> bool:
	if zona == SIN_ZONA or not Apertura.pide(_jornada, Tarea.Tipo.REPONER):
		return false
	for id in productos_de(zona):
		if not estante.casilleros_vacios(Catalogo.de(id)).is_empty():
			return true
	return false


## Si el punto cae en una zona con faltante.
func hay_faltante_en(punto: Vector3, estante: Estante) -> bool:
	return tiene_faltante(zona_de(punto), estante)

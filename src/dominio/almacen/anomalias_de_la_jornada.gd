## Las excepciones de disponibilidad y uso que declara cada jornada.
class_name AnomaliasDeLaJornada
extends RefCounted

const JORNADA_SIN_AZUL := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
const JORNADA_DE_LAS_CAJAS := (
	ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
)


static func util_disponible(identidad: StringName, jornada: int) -> bool:
	return jornada != JORNADA_SIN_AZUL or identidad != &"jabon_azul"


static func sustituye_azul(identidad: StringName, jornada: int) -> bool:
	return jornada == JORNADA_SIN_AZUL and identidad == id_de_poetico()


## Qué producto trae la caja con esa etiqueta. Fuera de la última jornada, el de su etiqueta.
static func contenido_de_la_caja(etiqueta: Producto.Id, jornada: int) -> Producto.Id:
	return contenidos_de_las_cajas(jornada).get(etiqueta, etiqueta)


## La permutación de la última jornada: cada caja trae el producto de la siguiente en el
## catálogo, y la última el de la primera. Es un dato fijo y no un sorteo, así que toda apertura
## de esa noche la repite. Vacía fuera de ella.
static func contenidos_de_las_cajas(jornada: int) -> Dictionary[Producto.Id, Producto.Id]:
	var contenidos: Dictionary[Producto.Id, Producto.Id] = {}
	if jornada != JORNADA_DE_LAS_CAJAS:
		return contenidos
	var productos := Catalogo.de_la_jornada(jornada)
	for indice in productos.size():
		contenidos[productos[indice].id] = productos[(indice + 1) % productos.size()].id
	return contenidos


static func id_de_poetico() -> StringName:
	return UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO)).id

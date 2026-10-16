## Las excepciones de disponibilidad y uso que declara cada jornada.
class_name AnomaliasDeLaJornada
extends RefCounted

const JORNADA_SIN_AZUL := 2


static func util_disponible(identidad: StringName, jornada: int) -> bool:
	return jornada != JORNADA_SIN_AZUL or identidad != &"jabon_azul"


static func sustituye_azul(identidad: StringName, jornada: int) -> bool:
	return jornada == JORNADA_SIN_AZUL and identidad == id_de_poetico()


static func id_de_poetico() -> StringName:
	return UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO)).id

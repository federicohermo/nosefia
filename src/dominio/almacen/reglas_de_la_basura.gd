## El viaje de las bolsas y el permiso de tirar lo sostenido al contenedor.
class_name ReglasDeLaBasura
extends RefCounted

enum Tiro { TIRADO, MANO_VACIA, NO_ENTRA, TAPA_NO_ABIERTA }

const BOLSAS_DE_LA_JORNADA := TareaDeLaBasura.Tacho.BANO + 1
const DISTANCIA_MINIMA_AL_CONTENEDOR := 6.0
const PREFIJO_DE_LA_BOLSA := "bolsa_de_basura_"


static func tiro(sostenido: ObjetoDelAlmacen, recibe: bool) -> Tiro:
	if sostenido == null:
		return Tiro.MANO_VACIA
	if not sostenido.entra_en_el_contenedor:
		return Tiro.NO_ENTRA
	if not recibe:
		return Tiro.TAPA_NO_ABIERTA
	return Tiro.TIRADO


static func id_de_la_bolsa(numero: int) -> StringName:
	return StringName(PREFIJO_DE_LA_BOLSA + str(numero))


static func ids_de_las_bolsas() -> Array[StringName]:
	var ids: Array[StringName] = []
	for numero in range(1, BOLSAS_DE_LA_JORNADA + 1):
		ids.append(id_de_la_bolsa(numero))
	return ids

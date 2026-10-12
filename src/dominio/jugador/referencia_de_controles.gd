class_name ReferenciaDeControles
extends RefCounted

enum Linea {
	EXAMINAR_LA_MANO,
	EXAMINAR,
	AGARRAR,
	DEJAR,
	INTERACTUAR,
	SACAR_PRODUCTO,
	METER_PRODUCTO,
}

enum Mira { NADA, LEVANTABLE, FIJO, CAJA }

enum Derecho { NINGUNO, INTERACTUAR, SACAR, METER }


static func lineas(
	_con_la_mano: bool, _mira: Mira, _derecho: Derecho, _suspendido: bool
) -> Array[Linea]:
	return []


static func texto(_linea: Linea, _control: String) -> String:
	return ""


static func accion(_linea: Linea) -> StringName:
	return &""


static func derecho_de_la_caja(_gesto: ContenidoDeLaCaja.Gesto) -> Derecho:
	return Derecho.NINGUNO


static func derecho_del_uso(_efecto: Uso.Efecto) -> Derecho:
	return Derecho.NINGUNO


static func derecho_del_lector(_sostenido: ObjetoDelAlmacen, _lector_presente: bool) -> Derecho:
	return Derecho.NINGUNO


static func derecho_del_descarte(_sostenido: ObjetoDelAlmacen, _destino: StringName) -> Derecho:
	return Derecho.NINGUNO


static func derecho_del_tacho(_con_bolsa: bool, _con_la_mano: bool) -> Derecho:
	return Derecho.NINGUNO

## El contexto declara qué gesto consume cada acción y cómo se nombra, sin predecir su resultado.
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
	ABRIR,
	CERRAR,
	MIRAR,
	HABLAR,
	ENTREGAR,
	LLENAR,
	VACIAR,
	VERTIR,
	MOJAR,
	LIMPIAR,
	INTERACTUAR_PRIMARIO,
	NINGUNA,
}
enum Mira { NADA, LEVANTABLE, FIJO, CAJA }
enum Ruta { GENERICA, PEDIR_USO, ACCIONAR, INTERACTUAR, USAR, IGNORAR }


class Contexto:
	extends RefCounted
	var primario: Linea = Linea.NINGUNA
	var secundario: Linea = Linea.NINGUNA
	var ruta_primaria: Ruta = Ruta.GENERICA
	var ruta_secundaria: Ruta = Ruta.PEDIR_USO


const FORMATO := "[%s] %s"
const TEXTOS: Dictionary[Linea, String] = {
	Linea.EXAMINAR_LA_MANO: "Examinar (mano)",
	Linea.EXAMINAR: "Examinar",
	Linea.AGARRAR: "Agarrar",
	Linea.DEJAR: "Dejar",
	Linea.INTERACTUAR: "Interactuar",
	Linea.SACAR_PRODUCTO: "Sacar producto",
	Linea.METER_PRODUCTO: "Meter producto",
	Linea.ABRIR: "Abrir",
	Linea.CERRAR: "Cerrar",
	Linea.MIRAR: "Mirar",
	Linea.HABLAR: "Hablar",
	Linea.ENTREGAR: "Entregar",
	Linea.LLENAR: "Llenar",
	Linea.VACIAR: "Vaciar",
	Linea.VERTIR: "Vertir",
	Linea.MOJAR: "Mojar",
	Linea.LIMPIAR: "Limpiar",
	Linea.INTERACTUAR_PRIMARIO: "Interactuar",
}


static func lineas(
	con_la_mano: bool, mira: Mira, contexto: Contexto, suspendido: bool
) -> Array[Linea]:
	var valen: Array[Linea] = []
	if suspendido:
		return valen
	if con_la_mano:
		valen.append(Linea.EXAMINAR_LA_MANO)
	elif mira != Mira.NADA:
		valen.append(Linea.EXAMINAR)
	if contexto.ruta_primaria == Ruta.GENERICA:
		if con_la_mano:
			valen.append(Linea.DEJAR)
		elif mira in [Mira.LEVANTABLE, Mira.CAJA]:
			valen.append(Linea.AGARRAR)
	elif contexto.primario != Linea.NINGUNA and mira != Mira.NADA:
		valen.append(contexto.primario)
	if contexto.secundario != Linea.NINGUNA and mira != Mira.NADA:
		valen.append(contexto.secundario)
	return valen


static func ruta(primario: bool, contexto: Contexto, suspendido: bool) -> Ruta:
	if suspendido:
		return Ruta.IGNORAR
	return contexto.ruta_primaria if primario else contexto.ruta_secundaria


static func texto(linea: Linea, control: String) -> String:
	return "" if control.is_empty() else FORMATO % [control, TEXTOS[linea]]


static func accion(linea: Linea) -> StringName:
	if linea in [Linea.EXAMINAR_LA_MANO, Linea.EXAMINAR]:
		return ReglasDeLosObjetos.ACCION_EXAMINAR
	if linea in [Linea.SACAR_PRODUCTO, Linea.INTERACTUAR]:
		return ReglasDelJugador.ACCION_USAR
	return ReglasDeLosObjetos.ACCION_AGARRAR


static func contexto_primario(linea: Linea, destino: Ruta = Ruta.PEDIR_USO) -> Contexto:
	var contexto := Contexto.new()
	contexto.primario = linea
	contexto.ruta_primaria = destino
	contexto.ruta_secundaria = Ruta.IGNORAR
	return contexto


static func contexto_de_la_caja(caja: ContenidoDeLaCaja, sostenido: ObjetoDelAlmacen) -> Contexto:
	var contexto := Contexto.new()
	contexto.ruta_secundaria = Ruta.IGNORAR
	if caja.uso(sostenido, true) == ContenidoDeLaCaja.Gesto.METER:
		contexto.ruta_primaria = Ruta.PEDIR_USO
		if caja.gesto_posible(sostenido, true) == ContenidoDeLaCaja.Gesto.METER:
			contexto.primario = Linea.METER_PRODUCTO
	elif caja.uso(sostenido, false) == ContenidoDeLaCaja.Gesto.SACAR:
		contexto.ruta_secundaria = Ruta.PEDIR_USO
		if caja.gesto_posible(sostenido, false) == ContenidoDeLaCaja.Gesto.SACAR:
			contexto.secundario = Linea.SACAR_PRODUCTO
	return contexto


static func contexto_del_uso(efecto: Uso.Efecto) -> Contexto:
	var verbos := {
		Uso.Efecto.LLENAR: Linea.LLENAR,
		Uso.Efecto.VACIAR: Linea.VACIAR,
		Uso.Efecto.TENIR: Linea.VERTIR,
		Uso.Efecto.MOJAR: Linea.MOJAR,
		Uso.Efecto.ENJUAGAR: Linea.MOJAR,
		Uso.Efecto.LIMPIAR: Linea.LIMPIAR,
	}
	if not verbos.has(efecto):
		return null
	return contexto_primario(verbos[efecto])


static func contexto_del_lector(sostenido: ObjetoDelAlmacen, presente: bool) -> Contexto:
	if not presente:
		var ausente := Contexto.new()
		ausente.ruta_secundaria = Ruta.IGNORAR
		return ausente
	if sostenido == null:
		return contexto_primario(Linea.NINGUNA, Ruta.IGNORAR)
	return contexto_primario(
		Linea.INTERACTUAR_PRIMARIO if sostenido is UnidadDeProducto else Linea.NINGUNA
	)


static func contexto_del_descarte(sostenido: ObjetoDelAlmacen, destino: StringName) -> Contexto:
	if Ticket.se_desecha_en(sostenido, destino):
		return contexto_primario(Linea.INTERACTUAR_PRIMARIO)
	return null


static func contexto_del_tacho(con_bolsa: bool, con_la_mano: bool) -> Contexto:
	return contexto_primario(
		Linea.INTERACTUAR_PRIMARIO if con_bolsa and not con_la_mano else Linea.NINGUNA
	)


static func contexto_de_atencion(habilitada: bool, atendido: bool, con_la_mano: bool) -> Contexto:
	if not habilitada:
		return Contexto.new()
	return contexto_primario(Linea.ENTREGAR if atendido and con_la_mano else Linea.HABLAR)


static func contexto_de_lo_fijo(abierta: bool = false, nota: bool = false) -> Contexto:
	return contexto_primario(
		Linea.MIRAR if nota else (Linea.CERRAR if abierta else Linea.ABRIR), Ruta.ACCIONAR
	)


static func contexto_del_contenedor(con_la_mano: bool) -> Contexto:
	return contexto_primario(
		Linea.INTERACTUAR_PRIMARIO if con_la_mano else Linea.NINGUNA, Ruta.INTERACTUAR
	)

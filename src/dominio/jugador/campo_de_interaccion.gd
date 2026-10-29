class_name CampoDeInteraccion
extends RefCounted


class Candidato:
	extends RefCounted

	var id: int
	var distancia: float
	var desvio: float
	var interactuable: bool
	var visible: bool
	var es_producto := false

	func _init(
		un_id: int, una_distancia: float, un_desvio: float, es_interactuable: bool, es_visible: bool
	) -> void:
		id = un_id
		distancia = una_distancia
		desvio = un_desvio
		interactuable = es_interactuable
		visible = es_visible


static func elegir(
	candidatos: Array[Candidato], excluido: int = Foco.SIN_OBJETIVO, actual: int = Foco.SIN_OBJETIVO
) -> int:
	var elegido: Candidato = null
	var desvio_elegido := INF
	for candidato in candidatos:
		if not candidato.interactuable or not candidato.visible or candidato.id == excluido:
			continue
		var alcance := (
			ReglasDelJugador.ALCANCE_DE_PRODUCTOS
			if candidato.es_producto
			else ReglasDelJugador.ALCANCE_DE_LA_MIRA
		)
		if candidato.distancia > alcance:
			continue
		var desvio_maximo := (
			ReglasDelJugador.DESVIO_MAXIMO_DE_PRODUCTOS
			if candidato.es_producto
			else ReglasDelJugador.DESVIO_MAXIMO_DE_LA_MIRA
		)
		var desvio := candidato.desvio
		if candidato.id == actual:
			desvio *= ReglasDelJugador.PERMANENCIA_DEL_FOCO
		if desvio > desvio_maximo:
			continue
		if (
			elegido == null
			or desvio < desvio_elegido
			or (desvio == desvio_elegido and candidato.distancia < elegido.distancia)
		):
			elegido = candidato
			desvio_elegido = desvio
	return Foco.SIN_OBJETIVO if elegido == null else elegido.id

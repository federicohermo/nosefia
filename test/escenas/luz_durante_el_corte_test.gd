## Durante el corte, todo lo del local se oscurece con él: toma su luz del horneado oscuro o la
## emite. Ningún objeto queda más claro que el ambiente donde está.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const Luz := preload("res://test/escenas/luz_de_cada_objeto.gd")
const Lector := preload("res://test/escenas/sondas_del_horneado.gd")
const Sondas := preload("res://addons/hornear/sondas.gd")
const HORNO_SIN_LUZ := "res://src/escenas/almacen_sin_luz.lmbake"
## La calle no es del local: el corte no la apaga.
const EXTERIOR := "Exterior"
const ESTRUCTURA := "Estructura"
## Cuánta luz de más puede tomar un objeto sobre la más alta de las sondas de adentro que lo
## rodean: la que agrega interpolar entre sondas, no la que entra de afuera.
const MARGEN := 0.02


func after_test() -> void:
	get_tree().paused = false


func test_durante_el_corte_todo_lo_del_local_toma_la_luz_del_horneado_o_la_emite() -> void:
	var local := _local_cortado()
	var sin_luz: Array[String] = []
	for fila: Dictionary in _del_local(local):
		if (
			fila.clase
			in [Luz.Clase.SIN_SOMBREADO, Luz.Clase.SIN_GI, Luz.Clase.ESTATICO_SIN_HORNEAR]
		):
			sin_luz.append("%s (%s)" % [fila.ruta, Luz.Clase.keys()[fila.clase]])
	(
		assert_array(sin_luz)
		. override_failure_message("no se oscurecen con el corte: %s" % ", ".join(sin_luz))
		. is_empty()
	)


## La luz que no está horneada sale de las sondas. Las de afuera del local no la pueden traer: ni
## el cielo de abajo del piso ni la de otro ambiente, a través de una pared.
func test_durante_el_corte_nada_toma_de_las_sondas_mas_luz_que_su_ambiente() -> void:
	var local := _local_cortado()
	var horno: LightmapGI = local.get_node("LightmapGI")
	var sondas := Lector.new(HORNO_SIN_LUZ)
	var cascara := Sondas.Cascara.new(
		local.get_node(ESTRUCTURA), horno.global_transform.affine_inverse()
	)
	var adentro: Array[int] = []
	for sonda in sondas.puntos.size():
		if cascara.encierra(sondas.puntos[sonda]):
			adentro.append(sonda)
	assert_array(adentro).is_not_empty()
	var con_sondas := 0
	var claros: Array[String] = []
	for fila: Dictionary in _del_local(local):
		if fila.clase != Luz.Clase.SONDAS:
			continue
		con_sondas += 1
		var ambiente := 0.0
		for sonda in adentro:
			if sondas.puntos[sonda].distance_to(fila.centro) <= Sondas.ALCANCE:
				ambiente = maxf(ambiente, sondas.luz_de(sonda))
		if fila.luz > ambiente + MARGEN:
			claros.append("%s (%.3f sobre %.3f)" % [fila.ruta, fila.luz, ambiente])
	assert_int(con_sondas).is_greater(0)
	(
		assert_array(claros)
		. override_failure_message("más claros que su ambiente: %s" % ", ".join(claros))
		. is_empty()
	)


func _local_cortado() -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set(
		"_partida", Partida.desde({"jornada": AnomaliasDeLaJornada.JORNADA_DEL_CORTE, "medios": 0})
	)
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	var hora := Vector2i(AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE)
	RelojDePrueba.avanzar_hasta(local.get("_reloj"), hora)
	assert_object((local.get_node("LightmapGI") as LightmapGI).light_data).is_equal(
		load(HORNO_SIN_LUZ)
	)
	return local


func _del_local(local: Node3D) -> Array[Dictionary]:
	var horno: LightmapGI = local.get_node("LightmapGI")
	var exterior := local.get_node(EXTERIOR)
	var filas: Array[Dictionary] = []
	for fila: Dictionary in Luz.clasificar(local, horno, Lector.new(HORNO_SIN_LUZ)):
		if not exterior.is_ancestor_of(fila.objeto):
			filas.append(fila)
	return filas

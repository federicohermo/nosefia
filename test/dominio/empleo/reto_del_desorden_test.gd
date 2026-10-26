## El Reto 4 nombra qué quedó desordenado: el texto de la fila por n y puntos, y después las clases.
extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const CLASE := ReglasDelCierre.Clase
const L := Partida.Llamado
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA

## Un trozo de la ficha que sólo aparece cuando esa clase se nombra.
const FRAGMENTOS: Dictionary[ReglasDelCierre.Clase, String] = {
	CLASE.UNIDAD_SUELTA: "productos tirados",
	CLASE.CAJA: "cajas",
	CLASE.UTIL_DE_LIMPIEZA: "cuartito",
}


func _antecedentes(n: int) -> Antecedentes:
	return (
		Antecedentes
		. desde(
			{
				Antecedentes.CLAVE_DE_FALLAS: {},
				Antecedentes.CLAVE_DE_LLAMADOS: {"LOCAL_DESORDENADO": n},
				Antecedentes.CLAVE_DE_NOCHES_SIN_SUMAR: 0,
			}
		)
	)


func _mensajes(n: int, medios: int, clases: Array[ReglasDelCierre.Clase]) -> Array[String]:
	var llamados: Array[L] = [L.LOCAL_DESORDENADO]
	return DevolucionDelJefe.armar(
		COMPLETA, medios, _antecedentes(n), [], llamados, false, false, clases
	)


## Las siete combinaciones, cada una con sus clases en el orden de la ficha.
func _combinaciones() -> Array[Array]:
	var todas: Array[Array] = []
	for mascara: int in range(1, 8):
		var clases: Array[ReglasDelCierre.Clase] = []
		for clase: ReglasDelCierre.Clase in FRAGMENTOS:
			if mascara & (1 << clase):
				clases.append(clase)
		todas.append(clases)
	return todas


## Cada fila de Reto 4 de la ficha: n, medios y el texto con el que empieza.
func _filas() -> Array[Array]:
	var sin_despido := DevolucionDelJefe.MEDIOS_DEL_DESPIDO - 1
	return [
		[1, sin_despido, DevolucionDelJefe.DESORDEN[0]],
		[2, sin_despido, DevolucionDelJefe.DESORDEN[1]],
		[3, sin_despido, DevolucionDelJefe.DESORDEN[2]],
		[4, sin_despido, DevolucionDelJefe.DESORDEN[3]],
		[2, DevolucionDelJefe.MEDIOS_DEL_DESPIDO, DevolucionDelJefe.DESORDEN_SIN_REMEDIO],
		[4, DevolucionDelJefe.MEDIOS_DEL_DESPIDO, DevolucionDelJefe.DESORDEN_SIN_REMEDIO],
		[5, sin_despido, DevolucionDelJefe.DESORDEN_SIN_REMEDIO],
		[8, sin_despido, DevolucionDelJefe.DESORDEN_SIN_REMEDIO],
	]


func test_cada_fila_termina_con_las_clases_de_esa_noche() -> void:  # AC-EMP-097
	for fila: Array in _filas():
		for clases: Array[ReglasDelCierre.Clase] in _combinaciones():
			var mensajes := _mensajes(fila[0], fila[1], clases)
			assert_int(mensajes.size()).is_equal(3)
			var reto := mensajes[1]
			var base: String = fila[2]
			assert_bool(reto.begins_with(base + " ")).is_true()
			var sufijo := reto.substr(base.length() + 1)
			assert_bool(sufijo.contains("+")).is_false()
			assert_bool(sufijo.ends_with(".")).is_true()
			var lugar := -1
			for clase: ReglasDelCierre.Clase in FRAGMENTOS:
				assert_bool(sufijo.contains(FRAGMENTOS[clase])).is_equal(clases.has(clase))
				if clases.has(clase):
					var donde := sufijo.find(FRAGMENTOS[clase])
					assert_int(donde).is_greater(lugar)
					lugar = donde


func test_las_siete_combinaciones_dicen_siete_cosas_distintas() -> void:  # AC-EMP-097
	var vistos := {}
	for clases: Array[ReglasDelCierre.Clase] in _combinaciones():
		vistos[_mensajes(1, 0, clases)[1]] = true
	assert_int(vistos.size()).is_equal(7)


func test_las_clases_no_cambian_n_ni_los_medios_del_legajo() -> void:  # AC-EMP-097
	var medios := 0
	var una: Array[ReglasDelCierre.Clase] = [CLASE.CAJA]
	var tres: Array[ReglasDelCierre.Clase] = [
		CLASE.UNIDAD_SUELTA, CLASE.CAJA, CLASE.UTIL_DE_LIMPIEZA
	]
	for clases: Array[ReglasDelCierre.Clase] in [una, tres]:
		var partida := Partida.desde({"jornada": COMPLETA})
		partida.abrir_la_jornada()
		for tarea: Tarea in partida.obligatorias():
			tarea.completar()
		partida.clases_de_desorden = clases
		partida.cerrar_la_jornada(partida.obligatorias().size())
		assert_int(partida.antecedentes().llamados(L.LOCAL_DESORDENADO)).is_equal(1)
		if medios == 0:
			medios = partida.medios()
		assert_int(partida.medios()).is_equal(medios)
		assert_int(partida.llamados().size()).is_equal(1)


func test_la_partida_entrega_al_reto_las_clases_que_anoto_el_cierre() -> void:  # AC-EMP-097
	var partida := Partida.desde({"jornada": COMPLETA})
	partida.abrir_la_jornada()
	var clases: Array[ReglasDelCierre.Clase] = [CLASE.UNIDAD_SUELTA, CLASE.UTIL_DE_LIMPIEZA]
	partida.clases_de_desorden = clases
	partida.cerrar_la_jornada(0)
	var retos: Array[String] = []
	for texto: String in partida.mensajes_del_jefe():
		if texto.begins_with(DevolucionDelJefe.DESORDEN[0]):
			retos.append(texto)
	assert_int(retos.size()).is_equal(1)
	assert_bool(retos[0].contains(FRAGMENTOS[CLASE.UNIDAD_SUELTA])).is_true()
	assert_bool(retos[0].contains(FRAGMENTOS[CLASE.CAJA])).is_false()
	assert_bool(retos[0].contains(FRAGMENTOS[CLASE.UTIL_DE_LIMPIEZA])).is_true()


func test_sin_clases_no_hay_llamado_y_cada_noche_trae_las_suyas() -> void:  # AC-EMP-097
	var partida := Partida.desde({"jornada": COMPLETA})
	partida.abrir_la_jornada()
	var ninguna: Array[ReglasDelCierre.Clase] = []
	partida.clases_de_desorden = ninguna
	assert_array(partida.llamados()).is_empty()
	var cajas: Array[ReglasDelCierre.Clase] = [CLASE.CAJA]
	partida.clases_de_desorden = cajas
	partida.cerrar_la_jornada(partida.obligatorias().size())
	partida.abrir_la_jornada()
	assert_array(partida.clases_de_desorden).is_empty()
	var utiles: Array[ReglasDelCierre.Clase] = [CLASE.UTIL_DE_LIMPIEZA]
	partida.clases_de_desorden = utiles
	assert_array(partida.clases_de_desorden).is_equal(utiles)

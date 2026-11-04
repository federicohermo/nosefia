extends GdUnitTestSuite

## El caso de la ficha «Caminos narrativos y finales», armado acá: las jornadas 5 a 7 todavía no
## tienen contenido en el juego.

const CAMINOS: Dictionary[String, Array] = {
	"4A": ["5A", "5B"],
	"4B": ["5C", "5D"],
	"5A": ["6A", "6B"],
	"5B": ["6C", "6D"],
	"5C": ["6E", "6F"],
	"5D": ["6G", "6H"],
	"6A": ["7A"],
	"6B": ["7B"],
	"6C": ["7C"],
	"6D": ["7D"],
	"6E": ["7E"],
	"6F": ["7F"],
	"6G": ["7G"],
	"6H": ["7H"],
}
const SORTEAN: Array[int] = [4, 5]
const CON_L: Array[int] = [5, 6]


func _pista(identidad: String) -> Pista:
	var pista := Pista.new()
	pista.identidad = identidad
	pista.jornada = identidad.left(1).to_int()
	pista.origen = StringName(identidad)
	pista.canal = Pista.Canal.CHAT
	pista.foto = GradientTexture2D.new()
	pista.texto = "Nota " + identidad
	return pista


func _hipotesis(
	identidad: String, exigencias: PackedStringArray = PackedStringArray()
) -> Hipotesis:
	var hipotesis := Hipotesis.new()
	hipotesis.identidad = identidad
	hipotesis.jornada = identidad.left(1).to_int()
	hipotesis.texto = "Texto " + identidad
	hipotesis.exigencias = exigencias
	if CAMINOS.has(identidad):
		hipotesis.camino = PackedStringArray(CAMINOS[identidad])
	return hipotesis


func _caso_de_la_ficha(con_l: bool = true) -> CasoDeInvestigacion:
	var caso := CasoDeInvestigacion.new()
	for identidad: String in ["4A", "4B"]:
		caso.pistas.append(_pista(identidad))
	for hijas: Array in CAMINOS.values():
		for identidad: String in hijas:
			caso.pistas.append(_pista(identidad))
	for jornada: int in [4, 5, 6]:
		var opciones := HipotesisDeLaJornada.new()
		opciones.jornada = jornada
		for identidad: String in CAMINOS:
			if identidad.left(1).to_int() == jornada:
				opciones.opciones.append(_hipotesis(identidad, PackedStringArray([identidad])))
		opciones.predeterminada = _hipotesis("%dP" % jornada)
		if con_l and CON_L.has(jornada):
			opciones.con_antecedentes = _hipotesis("%dL" % jornada)
		opciones.sortea_la_siguiente = SORTEAN.has(jornada)
		caso.hipotesis.append(opciones)
	return caso


## Anota cada pista del recorrido y elige la hipótesis de su misma letra.
func _por_el_camino(caso: CasoDeInvestigacion, recorrido: Array[String]) -> Expediente:
	var expediente := Expediente.new(caso)
	for identidad: String in recorrido:
		assert_int(expediente.registrar(identidad)).is_equal(Expediente.Resultado.ANOTADA)
		var jornada := caso.pista_de(identidad).jornada
		assert_int(expediente.elegir(jornada, identidad)).is_equal(Expediente.Resultado.ANOTADA)
	return expediente


func _elegir_la_predeterminada(expediente: Expediente, jornada: int) -> void:
	var opciones := expediente.hipotesis_para(jornada)
	assert_int(opciones.size()).is_equal(1)
	assert_int(expediente.elegir(jornada, opciones[0].identidad)).is_equal(
		Expediente.Resultado.ANOTADA
	)


func _azar(semilla: int) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	return azar


func _identidades(opciones: Array[Hipotesis]) -> Array[String]:
	var ids: Array[String] = []
	for opcion: Hipotesis in opciones:
		ids.append(opcion.identidad)
	return ids


func _activas(expediente: Expediente, jornada: int) -> Array:
	return Array(expediente.pistas_activas(jornada))


func test_la_hipotesis_elegida_fija_las_pistas_de_la_jornada_siguiente() -> void:  # AC-INV-074
	var caso := _caso_de_la_ficha()
	assert_int(caso.consistencia()).is_equal(CasoDeInvestigacion.Consistencia.VALIDO)
	var sin_elegir := Expediente.new(caso)
	assert_array(_activas(sin_elegir, 4)).is_equal(["4A", "4B"])
	assert_array(Array(sin_elegir.identidades())).is_empty()
	assert_array(sin_elegir.mensajes_de_notas()).is_empty()
	var recorridos: Array[Array] = [
		["4A"],
		["4B"],
		["4A", "5A"],
		["4A", "5B"],
		["4B", "5C"],
		["4B", "5D"],
		["4A", "5A", "6B"],
		["4B", "5D", "6H"],
	]
	for recorrido: Array in recorridos:
		var pasos: Array[String] = []
		pasos.assign(recorrido)
		var expediente := _por_el_camino(caso, pasos)
		var ultimo: String = pasos[-1]
		var siguiente: int = ultimo.left(1).to_int() + 1
		assert_array(_activas(expediente, siguiente)).is_equal(CAMINOS[ultimo])


func test_el_caso_de_la_partida_declara_los_caminos_de_la_cuarta_jornada() -> void:  # AC-INV-074
	var caso := CasoDeInvestigacion.de_la_partida()
	var opciones := caso.hipotesis[0].opciones
	assert_array(_identidades(opciones)).is_equal(["2A", "2B"])
	assert_array(Array(opciones[0].camino)).is_equal(CAMINOS["4A"])
	assert_array(Array(opciones[1].camino)).is_equal(CAMINOS["4B"])
	assert_array(Array(caso.hipotesis[0].predeterminada.camino)).is_empty()


func test_una_pista_fuera_del_camino_no_se_anota() -> void:  # AC-INV-075
	var caso := _caso_de_la_ficha()
	var expediente := _por_el_camino(caso, ["4A"])
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	var identidades := expediente.identidades()
	var notas := expediente.mensajes_de_notas().size()
	assert_int(expediente.registrar("5C")).is_equal(Expediente.Resultado.DESCONOCIDA)
	assert_int(expediente.registrar_por_canal(&"5C", Pista.Canal.CHAT, 5)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(Array(expediente.identidades())).is_equal(Array(identidades))
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas)
	assert_array(nuevas).is_empty()
	assert_int(expediente.registrar("5A")).is_equal(Expediente.Resultado.ANOTADA)
	assert_int(nuevas.size()).is_equal(1)


func test_sin_pistas_en_la_5_se_sortea_uno_de_los_dos_caminos_de_la_rama() -> void:  # AC-INV-076
	var caso := _caso_de_la_ficha()
	var esperados: Dictionary[String, Array] = {
		"4A": [["6A", "6B"], ["6C", "6D"]],
		"4B": [["6E", "6F"], ["6G", "6H"]],
	}
	for eleccion: String in esperados:
		var salidos: Array = []
		for semilla: int in range(1, 33):
			var expediente := _por_el_camino(caso, [eleccion])
			_elegir_la_predeterminada(expediente, 5)
			expediente.sortear_camino(6, _azar(semilla))
			var activas := _activas(expediente, 6)
			assert_bool(esperados[eleccion].has(activas)).is_true()
			if not salidos.has(activas):
				salidos.append(activas)
			var repetida := _por_el_camino(caso, [eleccion])
			_elegir_la_predeterminada(repetida, 5)
			repetida.sortear_camino(6, _azar(semilla))
			assert_array(_activas(repetida, 6)).is_equal(activas)
		assert_int(salidos.size()).is_equal(2)


func test_con_una_pista_en_la_5_no_se_sortea() -> void:  # AC-INV-076
	var caso := _caso_de_la_ficha()
	var expediente := Expediente.new(caso)
	for identidad: String in ["4A", "5B"]:
		expediente.registrar(identidad)
		expediente.elegir(caso.pista_de(identidad).jornada, identidad)
	for semilla: int in range(1, 9):
		expediente.sortear_camino(6, _azar(semilla))
	assert_dict(expediente.sorteos()).is_empty()
	assert_array(_activas(expediente, 6)).is_equal(["6C", "6D"])


func test_el_sorteo_se_hace_una_vez_y_se_guarda() -> void:  # AC-INV-077
	var caso := _caso_de_la_ficha()
	var expediente := _por_el_camino(caso, ["4A"])
	_elegir_la_predeterminada(expediente, 5)
	var notas := expediente.mensajes_de_notas().size()
	var identidades := expediente.identidades()
	expediente.sortear_camino(6, _azar(1))
	var sorteadas := _activas(expediente, 6)
	for semilla: int in range(2, 33):
		expediente.sortear_camino(6, _azar(semilla))
		assert_array(_activas(expediente, 6)).is_equal(sorteadas)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas)
	assert_array(Array(expediente.identidades())).is_equal(Array(identidades))
	assert_str(expediente.eleccion(6)).is_empty()
	var retomado := Expediente.new(caso)
	retomado.restaurar(expediente.identidades(), expediente.elecciones(), expediente.sorteos())
	assert_array(_activas(retomado, 6)).is_equal(sorteadas)
	for semilla: int in range(1, 33):
		retomado.sortear_camino(6, _azar(semilla))
		assert_array(_activas(retomado, 6)).is_equal(sorteadas)


func test_un_guardado_sin_sorteo_carga_y_uno_ajeno_se_descarta() -> void:  # AC-INV-077
	var caso := _caso_de_la_ficha()
	var base := _por_el_camino(caso, ["4A"])
	_elegir_la_predeterminada(base, 5)
	var sin_sorteo := Expediente.new(caso)
	sin_sorteo.restaurar(base.identidades(), base.elecciones())
	assert_dict(sin_sorteo.sorteos()).is_empty()
	assert_array(_activas(sin_sorteo, 6)).is_empty()
	for ajeno: Dictionary in [{6: "6A"}, {6: "inexistente"}, {6: 5}, {"6": "5A"}, {7: "5A"}]:
		var retomado := Expediente.new(caso)
		retomado.restaurar(base.identidades(), base.elecciones(), ajeno)
		assert_dict(retomado.sorteos()).is_empty()
		assert_array(_activas(retomado, 6)).is_empty()
	var valido := Expediente.new(caso)
	valido.restaurar(base.identidades(), base.elecciones(), {6: "5B"})
	assert_array(_activas(valido, 6)).is_equal(["6C", "6D"])


func test_sin_pistas_en_la_4_ni_en_la_5_no_hay_pistas_en_la_6() -> void:  # AC-INV-078
	var caso := _caso_de_la_ficha()
	var expediente := Expediente.new(caso)
	_elegir_la_predeterminada(expediente, 4)
	expediente.sortear_camino(5, _azar(1))
	var sorteo_de_la_5 := expediente.sorteos()
	assert_dict(sorteo_de_la_5).has_size(1)
	_elegir_la_predeterminada(expediente, 5)
	for semilla: int in range(1, 9):
		expediente.sortear_camino(6, _azar(semilla))
	assert_dict(expediente.sorteos()).is_equal(sorteo_de_la_5)
	assert_array(_activas(expediente, 6)).is_empty()
	assert_int(expediente.registrar("6A")).is_equal(Expediente.Resultado.DESCONOCIDA)


func test_sin_pistas_en_la_4_se_sortea_uno_de_los_dos_caminos_de_la_raiz() -> void:  # AC-INV-081
	var caso := _caso_de_la_ficha()
	var caminos: Array = [CAMINOS["4A"], CAMINOS["4B"]]
	var salidos: Array = []
	for semilla: int in range(1, 33):
		var expediente := Expediente.new(caso)
		_elegir_la_predeterminada(expediente, 4)
		assert_array(_activas(expediente, 5)).is_empty()
		expediente.sortear_camino(5, _azar(semilla))
		var activas := _activas(expediente, 5)
		assert_bool(caminos.has(activas)).is_true()
		if not salidos.has(activas):
			salidos.append(activas)
		var repetido := Expediente.new(caso)
		_elegir_la_predeterminada(repetido, 4)
		repetido.sortear_camino(5, _azar(semilla))
		assert_array(_activas(repetido, 5)).is_equal(activas)
	assert_int(salidos.size()).is_equal(2)


func test_el_sorteo_de_la_raiz_deja_anotar_su_camino_y_se_guarda() -> void:  # AC-INV-081
	var caso := _caso_de_la_ficha()
	var expediente := Expediente.new(caso)
	_elegir_la_predeterminada(expediente, 4)
	expediente.sortear_camino(5, _azar(1))
	var sorteadas := _activas(expediente, 5)
	var ajena: String = "5C" if sorteadas.has("5A") else "5A"
	assert_int(expediente.registrar(ajena)).is_equal(Expediente.Resultado.DESCONOCIDA)
	assert_int(expediente.registrar(sorteadas[0])).is_equal(Expediente.Resultado.ANOTADA)
	for semilla: int in range(2, 33):
		expediente.sortear_camino(5, _azar(semilla))
		assert_array(_activas(expediente, 5)).is_equal(sorteadas)
	var retomado := Expediente.new(caso)
	retomado.restaurar(expediente.identidades(), expediente.elecciones(), expediente.sorteos())
	assert_array(_activas(retomado, 5)).is_equal(sorteadas)


func test_con_una_pista_en_la_4_no_se_sortea_la_5() -> void:  # AC-INV-081
	var caso := _caso_de_la_ficha()
	var expediente := _por_el_camino(caso, ["4B"])
	for semilla: int in range(1, 9):
		expediente.sortear_camino(5, _azar(semilla))
	assert_dict(expediente.sorteos()).is_empty()
	assert_array(_activas(expediente, 5)).is_equal(CAMINOS["4B"])


func test_sin_pistas_en_la_6_no_hay_pistas_en_la_7() -> void:  # AC-INV-078
	var caso := _caso_de_la_ficha()
	var expediente := _por_el_camino(caso, ["4A", "5A"])
	_elegir_la_predeterminada(expediente, 6)
	for semilla: int in range(1, 9):
		expediente.sortear_camino(7, _azar(semilla))
	assert_dict(expediente.sorteos()).is_empty()
	assert_array(_activas(expediente, 7)).is_empty()
	for identidad: String in ["7A", "7B"]:
		assert_int(expediente.registrar(identidad)).is_equal(Expediente.Resultado.DESCONOCIDA)


func test_sin_pistas_la_hipotesis_es_la_p_o_la_l() -> void:  # AC-INV-079
	var caso := _caso_de_la_ficha()
	var nunca := Expediente.new(caso)
	_elegir_la_predeterminada(nunca, 4)
	assert_array(_identidades(nunca.hipotesis_para(5))).is_equal(["5P"])
	var antes := _por_el_camino(caso, ["4A"])
	assert_array(_identidades(antes.hipotesis_para(5))).is_equal(["5L"])
	antes.registrar("5B")
	assert_array(_identidades(antes.hipotesis_para(5))).is_equal(["5B"])
	var desde_la_5 := _por_el_camino(caso, ["4A", "5A"])
	assert_array(_identidades(desde_la_5.hipotesis_para(6))).is_equal(["6L"])
	assert_array(_identidades(Expediente.new(caso).hipotesis_para(4))).is_equal(["4P"])


func test_sin_l_declarada_no_se_ofrece_otra_hipotesis() -> void:  # AC-INV-079
	var caso := _caso_de_la_ficha(false)
	var antes := _por_el_camino(caso, ["4A"])
	assert_array(antes.hipotesis_para(5)).is_empty()
	var nunca := Expediente.new(caso)
	_elegir_la_predeterminada(nunca, 4)
	assert_array(_identidades(nunca.hipotesis_para(5))).is_equal(["5P"])


func test_la_cuarta_jornada_del_juego_sigue_igual() -> void:  # AC-INV-080
	var caso := CasoDeInvestigacion.de_la_partida()
	var expediente := Expediente.new(caso)
	assert_array(_activas(expediente, 4)).is_equal(["2A", "2B"])
	assert_array(_activas(expediente, 5)).is_empty()
	assert_bool(caso.hipotesis[0].sortea_la_siguiente).is_true()
	assert_int(expediente.registrar("2A")).is_equal(Expediente.Resultado.ANOTADA)
	assert_int(expediente.elegir(4, "2A")).is_equal(Expediente.Resultado.ANOTADA)
	assert_int(expediente.registrar("2B")).is_equal(Expediente.Resultado.ANOTADA)
	assert_array(_identidades(expediente.hipotesis_para(4))).is_equal(["2A", "2B"])
	assert_int(expediente.registrar_por_canal(&"2A", Pista.Canal.CHAT, 5)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)

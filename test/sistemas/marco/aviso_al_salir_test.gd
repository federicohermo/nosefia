## El aviso traduce la decisión del dominio a la página: lo pide mientras la noche corre y lo retira
## en cuanto deja de correr o el nodo sale del árbol. El navegador se reemplaza por un registro.
extends GdUnitTestSuite

var _pedidos: Array[bool] = []


func _registrar(pide: bool) -> void:
	_pedidos.append(pide)


func _aviso(reloj: RelojDelTurno) -> AvisoAlSalir:
	_pedidos.clear()
	var aviso: AvisoAlSalir = auto_free(AvisoAlSalir.new())
	aviso.vigilar(reloj, _registrar)
	return aviso


func _reloj_con_turno() -> RelojDelTurno:
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Turno.new(Ritmo.escalar(20.0), []), [])
	return reloj


func test_pide_al_correr_la_noche_y_no_antes() -> void:  # AC-SHF-143
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var aviso := _aviso(reloj)
	aviso._process(0.0)
	assert_array(_pedidos).is_empty()
	reloj.arrancar(Turno.new(Ritmo.escalar(20.0), []), [])
	aviso._process(0.0)
	aviso._process(0.0)
	assert_array(_pedidos).is_equal([true])


func test_retiene_la_confirmacion_entre_noches_y_en_el_epilogo() -> void:  # AC-SHF-144
	var reloj := _reloj_con_turno()
	var aviso := _aviso(reloj)
	aviso._process(0.0)
	reloj.retener()
	aviso._process(0.0)
	assert_array(_pedidos).is_equal([true, false])
	reloj.soltar()
	aviso._process(0.0)
	reloj.avanzar(20.0)
	aviso._process(0.0)
	assert_array(_pedidos).is_equal([true, false, true, false])


func test_al_salir_del_arbol_en_plena_noche_la_retira() -> void:  # AC-SHF-144
	var reloj := _reloj_con_turno()
	var aviso := _aviso(reloj)
	aviso._process(0.0)
	aviso._exit_tree()
	assert_array(_pedidos).is_equal([true, false])
	aviso._exit_tree()
	assert_array(_pedidos).is_equal([true, false])

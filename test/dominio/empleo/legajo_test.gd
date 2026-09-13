## La memoria entre jornadas: cuántos apercibimientos lleva acumulados y si ya lo echaron.
##
## Lo que este archivo fija no es código, son las dos lecturas ambiguas del GDD que el equipo
## cerró: las tres bandas pesan distinto sobre el despido, y una jornada completa **reinicia**
## el contador en vez de descontarle uno.
extends GdUnitTestSuite


func test_un_legajo_nuevo_no_tiene_apercibimientos_ni_despido() -> void:
	var legajo := Legajo.new()
	assert_int(legajo.apercibimientos()).is_equal(0)
	assert_bool(legajo.despedido()).is_false()


func test_una_jornada_completa_no_suma_apercibimientos() -> void:
	var legajo := Legajo.new()
	legajo.registrar(5, 5)
	assert_int(legajo.apercibimientos()).is_equal(0)


func test_el_aviso_suma_uno_y_la_banda_grave_suma_dos() -> void:
	# Es la regla entera en dos líneas: si las dos bandas pesaran igual, la de aviso y la grave
	# serían dos textos distintos con el mismo efecto.
	var legajo := Legajo.new()
	legajo.registrar(4, 5)
	assert_int(legajo.apercibimientos()).is_equal(1)
	legajo.registrar(2, 5)
	assert_int(legajo.apercibimientos()).is_equal(3)


func test_hacen_falta_cuatro_jornadas_de_aviso_para_que_lo_echen() -> void:
	# Un empleado que casi cumple no está en la misma situación que uno que no hizo nada, y ésa
	# es la diferencia que la lectura vieja —«tres días sin las cinco y afuera»— borraba.
	var legajo := Legajo.new()
	for jornada in 3:
		legajo.registrar(4, 5)
	assert_int(legajo.apercibimientos()).is_equal(3)
	assert_bool(legajo.despedido()).is_false()
	legajo.registrar(4, 5)
	assert_bool(legajo.despedido()).is_true()


func test_dos_jornadas_graves_seguidas_alcanzan_para_el_despido() -> void:
	# Es el camino más corto, y el que aprieta la tensión central: una sola noche dedicada a
	# investigar consume la mitad del margen.
	var legajo := Legajo.new()
	legajo.registrar(0, 5)
	assert_int(legajo.apercibimientos()).is_equal(2)
	assert_bool(legajo.despedido()).is_false()
	legajo.registrar(0, 5)
	assert_int(legajo.apercibimientos()).is_equal(4)
	assert_bool(legajo.despedido()).is_true()


func test_una_jornada_completa_reinicia_el_contador_en_vez_de_descontarle_uno() -> void:
	# Sin el reinicio, la cuarta jornada de esta secuencia cerraría en 6 y despediría.
	var legajo := Legajo.new()
	legajo.registrar(2, 5)
	legajo.registrar(2, 5)
	legajo.registrar(5, 5)
	assert_int(legajo.apercibimientos()).is_equal(0)
	legajo.registrar(2, 5)
	assert_int(legajo.apercibimientos()).is_equal(2)
	assert_bool(legajo.despedido()).is_false()


func test_a_la_banda_grave_le_alcanza_con_una_jornada_menos_que_a_la_de_aviso() -> void:
	# El AC que fija el cambio de diseño: tres jornadas de 4 tareas y tres de 2 tenían el mismo
	# final —despido— y ahora tienen finales opuestos.
	var casi_cumplidor := Legajo.new()
	for jornada in 3:
		casi_cumplidor.registrar(4, 5)
	assert_int(casi_cumplidor.apercibimientos()).is_equal(3)
	assert_bool(casi_cumplidor.despedido()).is_false()

	var incumplidor := Legajo.new()
	for jornada in 2:
		incumplidor.registrar(2, 5)
	assert_int(incumplidor.apercibimientos()).is_equal(4)
	assert_bool(incumplidor.despedido()).is_true()


func test_el_contador_puede_pasar_de_largo_el_umbral_sin_pisarlo() -> void:
	# El único caso del spec que no cae justo en el umbral: salta de 3 a 5. Contra un `==` en
	# lugar del `>=`, éste es el que se pone en rojo y ningún otro.
	var legajo := Legajo.new()
	legajo.registrar(4, 5)
	legajo.registrar(0, 5)
	legajo.registrar(0, 5)
	assert_int(legajo.apercibimientos()).is_equal(5)
	assert_bool(legajo.despedido()).is_true()


func test_la_jornada_completa_se_mide_contra_las_obligatorias_y_no_contra_un_cinco() -> void:
	# Con 3 obligatorias, cumplir 3 es cumplir todas. Una implementación que compare contra un
	# 5 escrito a mano cuenta esto como banda grave y suma apercibimientos.
	var cumplidor := Legajo.new()
	cumplidor.registrar(3, 3)
	assert_int(cumplidor.apercibimientos()).is_equal(0)

	var incumplidor := Legajo.new()
	incumplidor.registrar(2, 3)
	incumplidor.registrar(2, 3)
	assert_bool(incumplidor.despedido()).is_true()


func test_un_legajo_restaurado_sigue_contando_desde_donde_quedo() -> void:
	# Es la puerta por la que el 019 retoma una partida guardada. Sin ella el legajo sólo nace
	# vacío, y una historia de jornadas graves repartida entre dos sesiones no despide a nadie
	# —un bug que pasa en verde, porque todo test construye el legajo en la misma corrida en
	# que lo ejerce.
	var legajo := Legajo.con_apercibimientos(2)
	assert_int(legajo.apercibimientos()).is_equal(2)
	assert_bool(legajo.despedido()).is_false()
	legajo.registrar(0, 5)
	assert_int(legajo.apercibimientos()).is_equal(4)
	assert_bool(legajo.despedido()).is_true()


func test_restaurar_un_legajo_en_cero_es_lo_mismo_que_uno_nuevo() -> void:
	var restaurado := Legajo.con_apercibimientos(0)
	assert_int(restaurado.apercibimientos()).is_equal(Legajo.new().apercibimientos())
	assert_bool(restaurado.despedido()).is_false()

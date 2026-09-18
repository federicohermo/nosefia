## La tabla de sonidos del disco: que cargue, que cubra todos los eventos y que ninguna fila
## salga por un bus que no existe.
##
## **El caso del disco es el que más fácil miente.** Un `.tres` que falta hace abortar la función
## antes de afirmar, y gdUnit4 reporta el caso en verde: por eso acá se afirma primero que la
## tabla **no es nula**, con su mensaje propio, y recién después lo que dice adentro.
extends GdUnitTestSuite

const BUS_INVENTADO := "Efectoss"


func _tabla() -> TablaDeSonidos:
	var tabla := TablaDeSonidos.desde_disco()
	(
		assert_object(tabla)
		. override_failure_message("`%s` no carga o no es una tabla" % TablaDeSonidos.RUTA)
		. is_not_null()
	)
	return tabla


func test_la_tabla_del_disco_carga() -> void:  # 021-AC2
	assert_object(_tabla()).is_instanceof(TablaDeSonidos)


func test_la_tabla_cubre_todos_los_eventos() -> void:  # 021-AC2
	# **Un evento sin fila la pone en rojo, y el rojo dice cuál.** Sin este caso, agregar un valor
	# al `enum` dejaría un sonido que nunca se pide y nada lo diría.
	var tabla := _tabla()
	(
		assert_array(tabla.eventos_sin_fila())
		. override_failure_message(
			"la tabla no cubre los eventos %s" % str(tabla.eventos_sin_fila())
		)
		. is_empty()
	)
	assert_bool(tabla.cubre_todos()).is_true()


func test_ninguna_fila_del_disco_sale_por_un_bus_que_no_existe() -> void:  # 021-AC2
	var tabla := _tabla()
	(
		assert_array(tabla.filas_invalidas())
		. override_failure_message(
			"%d filas salen por un bus no declarado" % tabla.filas_invalidas().size()
		)
		. is_empty()
	)


func test_un_evento_sin_fila_contesta_null_en_vez_de_reventar() -> void:  # 021-AC2
	# Es la misma forma que `Catalogo.de()`: con `null` el rojo lo produce una aserción, mientras
	# que un error del motor gdUnit4 lo cuenta como *error* y deja el archivo diciendo `PASSED`.
	assert_object(TablaDeSonidos.new().de(EntradaSonora.Evento.TAREA_CUMPLIDA)).is_null()


func test_una_tabla_con_una_fila_invalida_la_nombra() -> void:  # 021-AC2
	# El caso de arriba corre sobre una tabla que ya está bien y pasaría igual si no mirara nada.
	# Éste le pasa una que sí la viola.
	var mala := EntradaSonora.new()
	mala.bus = BUS_INVENTADO
	var tabla := TablaDeSonidos.new()
	tabla.entradas = [mala] as Array[EntradaSonora]
	assert_int(tabla.filas_invalidas().size()).is_equal(1)
	assert_bool(tabla.cubre_todos()).is_false()


func test_la_ronda_reparte_por_turno_y_vuelve_al_principio() -> void:  # 021-AC2
	var ronda := RondaDeVoces.new(3)
	assert_int(ronda.siguiente()).is_equal(0)
	assert_int(ronda.siguiente()).is_equal(1)
	assert_int(ronda.siguiente()).is_equal(2)
	assert_int(ronda.siguiente()).is_equal(0)


func test_una_ronda_sin_voces_queda_vacia_y_no_falla() -> void:  # 021-AC2
	# No es un caso del juego: es el que evita que un balance mal escrito divida por cero y se
	# lleve puesta la corrida entera.
	var ronda := RondaDeVoces.new(0)
	assert_int(ronda.voces()).is_equal(0)
	assert_int(ronda.siguiente()).is_equal(-1)
	assert_int(RondaDeVoces.new(-4).voces()).is_equal(0)

## La caja de traslado: cuánto entra, qué se rechaza y por qué.
##
## **Es lo que convierte reponer en una decisión.** Sin caja, reponer es un viaje por unidad; con
## ocho casilleros el jugador elige cuánto carga, y cada viaje ahorrado es un minuto para
## investigar. Toda esa aritmética se ejerce acá sin levantar una escena.
##
## La caja **no sabe dónde está**, y por eso se mueve llena: su contenido no depende de ninguna
## ubicación. Es lo mismo que la deja aterrizar antes que el 006.
extends GdUnitTestSuite

const CAJA := "res://src/dominio/almacen/caja_de_traslado.gd"

## Lo que un archivo de `dominio/` no puede nombrar acá: la caja no tiene ubicación ni portador.
## Se buscan sobre el texto entero —código y comentarios— porque nombrarlos en un comentario ya
## es una invitación a usarlos.
const PATRONES_DE_UBICACION := ["position", "transform", "Node", "get_tree", "Manos", "Agarre"]

## Un `id` que no tiene fila en el catálogo. `Catalogo.de()` contesta `null` en vez de reventar
## —medido en headless—, y es por ahí que entra «esto no es un producto» sin que la caja tenga
## que conocer al catálogo.
const ID_QUE_NO_EXISTE := 99


func test_una_caja_nueva_esta_vacia_y_con_todos_sus_casilleros_libres() -> void:  # 033-AC1
	var caja := CajaDeTraslado.new()
	assert_int(Reglas.CASILLEROS_DE_LA_CAJA_DE_TRASLADO).is_equal(8)
	assert_int(caja.ocupados()).is_equal(0)
	assert_int(caja.libres()).is_equal(Reglas.CASILLEROS_DE_LA_CAJA_DE_TRASLADO)
	assert_bool(caja.esta_llena()).is_false()


func test_con_los_casilleros_llenos_la_caja_dice_que_esta_llena() -> void:  # 033-AC2
	var caja := _caja_llena()
	assert_bool(caja.esta_llena()).is_true()
	assert_int(caja.libres()).is_equal(0)
	assert_int(caja.ocupados()).is_equal(Reglas.CASILLEROS_DE_LA_CAJA_DE_TRASLADO)


func test_la_novena_no_entra_y_la_caja_dice_por_que() -> void:  # 033-AC3
	# El motivo importa: la escena tiene que poder decir «no entra más» y no «eso no se guarda»,
	# que son dos cosas distintas para quien está parado adelante con una lata en la mano.
	var caja := _caja_llena()
	assert_bool(caja.guardar(Catalogo.de(Producto.Id.YERBA))).is_false()
	assert_int(caja.motivo_de_rechazo()).is_equal(CajaDeTraslado.Motivo.CAJA_LLENA)
	assert_int(caja.ocupados()).is_equal(Reglas.CASILLEROS_DE_LA_CAJA_DE_TRASLADO)


func test_lo_que_no_es_un_producto_se_rechaza_en_el_dominio() -> void:  # 033-AC4
	# «Sólo entran productos» es una regla del juego, así que la decide el dominio y no la
	# escena: escrita arriba nacería sin test, y está medido que ningún gate lo diría.
	var caja := CajaDeTraslado.new()
	assert_object(Catalogo.de(ID_QUE_NO_EXISTE)).is_null()
	assert_bool(caja.guardar(Catalogo.de(ID_QUE_NO_EXISTE))).is_false()
	assert_int(caja.motivo_de_rechazo()).is_equal(CajaDeTraslado.Motivo.NO_ES_UN_PRODUCTO)
	assert_int(caja.ocupados()).is_equal(0)


func test_sacar_de_una_caja_vacia_contesta_que_no_hay_nada_en_vez_de_romperse() -> void:  # 033-AC5
	var caja := CajaDeTraslado.new()
	assert_object(caja.sacar()).is_null()
	assert_int(caja.ocupados()).is_equal(0)


func test_sacar_devuelve_lo_ultimo_que_se_guardo() -> void:  # 033-AC5
	# La caja se descarga por arriba, como una caja de verdad: lo último que entró es lo primero
	# que sale, y así el jugador no tiene que acordarse del orden en que la cargó.
	var caja := CajaDeTraslado.new()
	caja.guardar(Catalogo.de(Producto.Id.YERBA))
	var ultimo := Catalogo.de(Producto.Id.JABON)
	caja.guardar(ultimo)
	assert_object(caja.sacar()).is_same(ultimo)
	assert_int(caja.ocupados()).is_equal(1)


func test_el_contenido_que_devuelve_es_una_copia() -> void:  # 033-AC5
	# **Medido en headless**: un `Array` devuelto sin `duplicate()` es el mismo array, y un
	# `clear()` afuera vacía el original. Sin la copia, quien mira la caja la puede vaciar.
	var caja := CajaDeTraslado.new()
	caja.guardar(Catalogo.de(Producto.Id.YERBA))
	var afuera := caja.contenido()
	afuera.clear()
	assert_int(caja.ocupados()).is_equal(1)
	assert_int(caja.contenido().size()).is_equal(1)


func test_la_caja_no_sabe_donde_esta_ni_quien_la_lleva() -> void:  # 033-AC6
	# Es lo que la deja moverse llena y aterrizar antes que el 006: el contenido no depende de
	# ninguna ubicación, así que no hay nada que actualizar cuando la caja viaja.
	var texto := FileAccess.get_file_as_string(CAJA)
	assert_str(texto).is_not_empty()
	for patron: String in PATRONES_DE_UBICACION:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message("`caja_de_traslado.gd` nombra `%s`" % patron)
			. is_false()
		)


## Una caja con todos sus casilleros ocupados. Se llena por la puerta pública y no tocando el
## estado adentro: es lo que hace que el caso de la novena ejerza el camino de verdad.
func _caja_llena() -> CajaDeTraslado:
	var caja := CajaDeTraslado.new()
	for _casillero in range(Reglas.CASILLEROS_DE_LA_CAJA_DE_TRASLADO):
		caja.guardar(Catalogo.de(Producto.Id.FIDEOS))
	return caja

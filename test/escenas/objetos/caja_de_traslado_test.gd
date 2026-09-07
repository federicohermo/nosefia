## La caja que se ve: sus ocho casilleros, y que lo dibujado salga del dominio.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`:
## alcanza para leer la jerarquía y las propiedades, y hacerlo es lo que mantiene el caso
## estable cuando el 006 le cuelgue el agarre.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/objetos/caja_de_traslado.tscn"
const SCRIPT := "res://src/escenas/objetos/caja_de_traslado.gd"

## El script del nodo se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`, así que sin esto el tipo estático sería `Node3D` y llamarle
## `mostrar()` no compilaría.
const CajaQueSeVe := preload("res://src/escenas/objetos/caja_de_traslado.gd")

## Cómo se reconoce un casillero en el árbol. Se busca por prefijo y no por cantidad de hijos
## para que agregarle a la caja una tapa o una etiqueta no rompa el conteo.
const PREFIJO_DEL_CASILLERO := "Casillero"


func test_la_caja_trae_exactamente_los_casilleros_que_declara_el_balance() -> void:  # 033-AC9
	# Se cuentan contra la constante y nunca contra un `8` escrito acá: si el cupo del dominio se
	# moviera, una caja con ocho huecos dibujados dejaría al jugador mirando un casillero que
	# nunca se llena, sin un solo error.
	var caja := _caja()
	var casilleros := _casilleros_de(caja)
	(
		assert_int(casilleros.size())
		. override_failure_message(
			(
				"la caja dibuja %d casilleros y el cupo son %d"
				% [casilleros.size(), Reglas.CASILLEROS_DE_LA_CAJA_DE_TRASLADO]
			)
		)
		. is_equal(Reglas.CASILLEROS_DE_LA_CAJA_DE_TRASLADO)
	)


func test_una_caja_recien_instanciada_no_muestra_ningun_casillero_ocupado() -> void:  # 033-AC9
	# Una caja nueva está vacía y el dominio lo dice, pero los casilleros del `.tscn` nacen
	# visibles: sin declarar el estado inicial la escena carga sin un solo error y el jugador ve
	# ocho productos adentro de una caja que `CajaDeTraslado` reporta con `ocupados() == 0`.
	# Nadie la pinta al nacer —quien pinta es quien la carga—, así que lo declara la escena.
	var caja := _caja()
	(
		assert_object(caja.get("_casilleros"))
		. override_failure_message(
			"`_casilleros` llegó nulo: la caja perdió su `node_paths` o su `script`"
		)
		. is_not_null()
	)
	assert_int(_casilleros_visibles(caja)).is_equal(CajaDeTraslado.new().ocupados())


func test_el_script_de_la_caja_no_declara_nada_propio() -> void:  # 033-AC9
	# Es cáscara: sin `class_name` —nadie la nombra desde abajo— y sin una sola `const`, que es
	# por donde el cupo se copiaría. Está medido que esa copia pasa los dos gates en verde.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	assert_str(texto).not_contains("class_name")
	var declara := RegEx.create_from_string("(?m)^\\s*const\\b").search_all(texto)
	(
		assert_array(declara)
		. override_failure_message("`caja_de_traslado.gd` de `escenas/` declara una `const`")
		. is_empty()
	)


func test_los_casilleros_ocupados_son_los_que_dice_el_dominio() -> void:  # 033-AC9
	# La escena pregunta y pinta: cuántos casilleros se ven sale de `contenido()` y no de una
	# cuenta propia. Con una cuenta propia, la caja y el dominio se contradicen en silencio.
	var caja := _caja()
	var dominio := CajaDeTraslado.new()
	dominio.guardar(Catalogo.de(Producto.Id.YERBA))
	dominio.guardar(Catalogo.de(Producto.Id.ARROZ))
	caja.mostrar(dominio.contenido())
	assert_int(_casilleros_visibles(caja)).is_equal(dominio.ocupados())

	dominio.sacar()
	caja.mostrar(dominio.contenido())
	assert_int(_casilleros_visibles(caja)).is_equal(dominio.ocupados())


func _caja() -> CajaQueSeVe:
	return auto_free(load(ESCENA).instantiate())


func _casilleros_de(caja: Node) -> Array[Node3D]:
	var encontrados: Array[Node3D] = []
	for nodo in _descendientes(caja):
		if nodo.name.begins_with(PREFIJO_DEL_CASILLERO):
			encontrados.append(nodo)
	return encontrados


func _casilleros_visibles(caja: Node) -> int:
	var visibles := 0
	for casillero in _casilleros_de(caja):
		if casillero.visible:
			visibles += 1
	return visibles


static func _descendientes(nodo: Node) -> Array[Node3D]:
	var todos: Array[Node3D] = []
	for hijo: Node3D in nodo.get_children():
		todos.append(hijo)
		todos.append_array(_descendientes(hijo))
	return todos

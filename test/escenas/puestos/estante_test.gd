## El estante que se ve: sus huecos, y que lo dibujado salga del dominio.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`:
## alcanza para leer la jerarquía y las propiedades, y es lo que mantiene el caso estable cuando
## el 013 le cuelgue la venta por la ventanilla.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/almacen.tscn"
const SCRIPT := "res://src/escenas/puestos/estante.gd"

## El script del nodo se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y no
## declaran `class_name`, así que sin esto el tipo estático sería `StaticBody3D` y llamarle
## `mostrar()` no compilaría.
const EstanteQueSeVe := preload("res://src/escenas/puestos/estante.gd")


func test_el_estante_dibuja_un_hueco_por_producto_del_catalogo() -> void:  # 008-AC10
	# Se cuenta contra el catálogo y nunca contra un número escrito acá: con un producto más, un
	# estante de seis huecos dejaría al jugador mirando una góndola que nunca se llena del todo,
	# sin un solo error.
	var estante := _estante()
	var huecos := _huecos_de(estante)
	(
		assert_int(huecos.size())
		. override_failure_message(
			(
				"el estante dibuja %d huecos y el catálogo tiene %d productos"
				% [huecos.size(), Catalogo.todos().size()]
			)
		)
		. is_equal(Catalogo.todos().size())
	)


func test_los_huecos_visibles_son_los_que_dice_el_dominio() -> void:  # 008-AC10
	# La escena pregunta y pinta: cuántos huecos se ven sale de `productos_completos()` y no de
	# una cuenta propia. Con una cuenta propia, el estante y el inventario se contradicen en
	# silencio.
	var yerba := Catalogo.de(Producto.Id.YERBA)
	var inventario := Inventario.new([yerba])
	inventario.ingresar(yerba, Inventario.Ubicacion.DEPOSITO, yerba.umbral)
	var dominio := Estante.new(inventario, [yerba])
	var estante := _estante()

	estante.mostrar(dominio.productos_completos())
	assert_int(_huecos_visibles(estante)).is_equal(0)

	for _unidad in range(yerba.umbral):
		dominio.colocar(yerba)
	estante.mostrar(dominio.productos_completos())
	assert_int(_huecos_visibles(estante)).is_equal(1)


func test_el_estante_arranca_sin_un_solo_hueco_puesto() -> void:  # 008-AC10
	# La góndola de la noche arranca vacía, así que un hueco visible en el `.tscn` sería
	# mercadería que el jugador ve y el inventario no tiene.
	assert_int(_huecos_visibles(_estante())).is_equal(0)


func test_el_estante_de_la_escena_no_lleva_el_stock_adentro() -> void:  # 008-AC10
	# Está medido que una regla escrita en esta capa pasa los dos gates en verde. Por eso el
	# criterio la ata con una búsqueda sobre el archivo, que es lo único ejecutable que hay.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	for patron in ["get_child_count", "_unidades", "_stock"]:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message("`estante.gd` de `escenas/` nombra `%s`" % patron)
			. is_false()
		)


func test_el_estante_contesta_el_contrato_de_interaccion() -> void:  # 008-AC10
	# El contrato es el nombre de un método más el grupo, y no un tipo: ninguna de las capas que
	# lo necesitan puede nombrar un `class_name` de `escenas/`.
	var estante := _estante()
	assert_bool(estante.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()
	assert_bool(estante.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	# Del estante no se levanta nada: si contestara un objeto, el clic del 006 lo agarraría en
	# vez de colocar una unidad.
	assert_object(estante.call(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_null()


func _estante() -> EstanteQueSeVe:
	var almacen: Node3D = auto_free(load(ESCENA).instantiate())
	return almacen.get("_estante")


func _huecos_de(estante: Node) -> Array[Node3D]:
	var encontrados: Array[Node3D] = []
	for nodo: Node3D in estante.get("_huecos").get_children():
		encontrados.append(nodo)
	return encontrados


func _huecos_visibles(estante: Node) -> int:
	var visibles := 0
	for hueco in _huecos_de(estante):
		if hueco.visible:
			visibles += 1
	return visibles

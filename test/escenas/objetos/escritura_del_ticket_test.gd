extends GdUnitTestSuite

const PAPEL := preload("res://src/escenas/objetos/ticket.tscn")
const DISENO := preload("res://assets/ui/manada/ticket_papel.png")
const TOLERANCIA := 0.0001
## Cuánto del ancho ocupa la franja negra y dentada del borde, con aire.
const MARGEN_DEL_BORDE := 0.1
## Por debajo de esto un píxel es tinta: el papel claro y sus arrugas quedan muy por encima.
const LUMINANCIA_DE_LA_TINTA := 0.5
const PASO_DE_LA_MUESTRA := 16


func _malla_del_papel() -> MeshInstance3D:
	var papel: ObjetoAgarrable = auto_free(PAPEL.instantiate())
	var productos: Array[Producto] = [Catalogo.de(Producto.Id.MAROLINI)]
	papel.datos = Ticket.new(productos, 887, 4, "22:21")
	papel.freeze = true
	add_child(papel)
	return papel.get_node("Malla")


## La superficie cuyas caras miran hacia atrás, o -1 si el papel no tiene una aparte.
func _dorso_de(malla: MeshInstance3D) -> int:
	for superficie in malla.mesh.get_surface_count():
		var arrays := malla.mesh.surface_get_arrays(superficie)
		var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if not indices.is_empty() and normales[indices[0]].x < 0.0:
			return superficie
	return -1


func _textura_de(malla: MeshInstance3D, superficie: int) -> Texture2D:
	var material := malla.get_active_material(superficie) as StandardMaterial3D
	return material.albedo_texture if material != null else null


func test_el_dibujo_llena_la_malla_de_borde_a_borde() -> void:
	var malla := _malla_del_papel()
	var caja := malla.mesh.get_aabb()
	for superficie in malla.mesh.get_surface_count():
		var arrays := malla.mesh.surface_get_arrays(superficie)
		var posiciones: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var cuadros: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		assert_int(cuadros.size()).is_equal(posiciones.size())
		for indice in posiciones.size():
			var esperado := Vector2(
				(caja.end.z - posiciones[indice].z) / caja.size.z,
				(caja.end.y - posiciones[indice].y) / caja.size.y
			)
			assert_vector(cuadros[indice]).is_equal_approx(esperado, Vector2.ONE * TOLERANCIA)


func test_el_dorso_no_lleva_la_escritura_del_frente() -> void:
	var malla := _malla_del_papel()
	var dorso := _dorso_de(malla)
	assert_int(dorso).is_greater_equal(0)
	var del_frente: Texture2D = null
	for superficie in malla.mesh.get_surface_count():
		if superficie != dorso:
			del_frente = _textura_de(malla, superficie)
			assert_object(del_frente).is_not_same(_textura_de(malla, dorso))
	assert_object(del_frente).is_not_null()


func test_el_dorso_no_tiene_tinta_adentro_del_borde() -> void:
	var malla := _malla_del_papel()
	var dorso := _dorso_de(malla)
	assert_int(dorso).is_greater_equal(0)
	if dorso < 0:
		return
	var imagen := _textura_de(malla, dorso).get_image()
	var margen := roundi(imagen.get_width() * MARGEN_DEL_BORDE)
	var con_tinta := 0
	for y in range(margen, imagen.get_height() - margen):
		for x in range(margen, imagen.get_width() - margen):
			if imagen.get_pixel(x, y).get_luminance() <= LUMINANCIA_DE_LA_TINTA:
				con_tinta += 1
	assert_int(con_tinta).is_equal(0)


func test_el_dorso_tiene_los_mismos_dientes_que_el_frente() -> void:
	var malla := _malla_del_papel()
	var dorso := _dorso_de(malla)
	assert_int(dorso).is_greater_equal(0)
	if dorso < 0:
		return
	var imagen := _textura_de(malla, dorso).get_image()
	var diseno := DISENO.get_image()
	var comparados := 0
	for y in range(PASO_DE_LA_MUESTRA / 2, diseno.get_height(), PASO_DE_LA_MUESTRA):
		for x in range(PASO_DE_LA_MUESTRA / 2, diseno.get_width(), PASO_DE_LA_MUESTRA):
			if not _lejos_de_un_borde(diseno, x, y):
				continue
			comparados += 1
			var del_dorso := imagen.get_pixel(
				x * imagen.get_width() / diseno.get_width(),
				y * imagen.get_height() / diseno.get_height()
			)
			assert_bool(del_dorso.a >= 0.5).is_equal(diseno.get_pixel(x, y).a >= 0.5)
	assert_int(comparados).is_greater(0)


## Dos resoluciones no coinciden justo sobre el borde de un diente: ahí no se compara.
func _lejos_de_un_borde(imagen: Image, x: int, y: int) -> bool:
	var visible := imagen.get_pixel(x, y).a >= 0.5
	for desvio: Vector2i in [Vector2i(-6, 0), Vector2i(6, 0), Vector2i(0, -6), Vector2i(0, 6)]:
		var vecino := Vector2i(x, y) + desvio
		if not Rect2i(Vector2i.ZERO, imagen.get_size()).has_point(vecino):
			continue
		if (imagen.get_pixelv(vecino).a >= 0.5) != visible:
			return false
	return true

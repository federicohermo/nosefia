## La disposición de la góndola: que el recurso medido del modelo alcance para lo que el puesto
## le pide, y que cada tanda tenga la forma que el spec le exige.
##
## **No se cuentan copias ni se comparan posiciones escritas acá**: eso cambia con cada arreglo
## del artista. Se afirma lo que el puesto supone sin mirar, y que si falla rompe la noche sin un
## error que nombre al recurso, y la forma de cada tanda, que es la misma para cualquier reparto.
extends GdUnitTestSuite

const DISPOSICION := "res://src/escenas/puestos/disposicion_de_la_gondola.tres"
const GUIA := "res://src/escenas/puestos/guia_del_estante.tscn"

## Cuánto pueden diferir dos medidas del modelo que deberían ser iguales, en metros. El `.tres`
## guarda seis cifras.
const TOLERANCIA := 0.002


func test_una_fila_es_entera_de_casilleros_y_dos_conservan_la_de_atras() -> void:  # AC-STK-030
	var disposicion := DisposicionDeLaGondola.new()
	disposicion.principales = [_copia(Vector3.ZERO) + _copia(Vector3.RIGHT)]
	assert_int(disposicion.primera_reponible(Producto.Id.ACTRONCITO, 2)).is_zero()
	assert_int(disposicion.primera_reponible(Producto.Id.ACTRONCITO, 1)).is_equal(1)


func test_un_bloque_vacio_con_cupo_cero_no_indexa_antes_del_comienzo() -> void:
	var disposicion := DisposicionDeLaGondola.new()
	disposicion.principales = [PackedFloat32Array()]
	assert_int(disposicion.primera_reponible(Producto.Id.ACTRONCITO, 0)).is_zero()
	assert_vector(DisposicionDeLaGondola.frente(disposicion.principales[0], 0)).is_equal(
		Vector3.ZERO
	)


func test_un_bloque_que_no_tiene_una_o_dos_filas_nombra_el_recurso() -> void:
	var disposicion := DisposicionDeLaGondola.new()
	disposicion.resource_name = "disposicion_erronea"
	disposicion.principales = [_copia(Vector3.ZERO) + _copia(Vector3.RIGHT) + _copia(Vector3.LEFT)]
	await (
		assert_error(func() -> void: disposicion.primera_reponible(Producto.Id.ACTRONCITO, 2))
		. is_push_error(
			"DisposicionDeLaGondola disposicion_erronea: el bloque 0 tiene 3 copias para 2 casilleros"
		)
	)


func _disposicion() -> DisposicionDeLaGondola:
	return load(DISPOSICION) as DisposicionDeLaGondola


## Una copia puesta a mano: sin giro, en `origen`.
static func _copia(origen: Vector3) -> PackedFloat32Array:
	return PackedFloat32Array([1, 0, 0, origen.x, 0, 1, 0, origen.y, 0, 0, 1, origen.z])


## El puesto indexa `principales` por `Producto.Id`. Un producto sin bloque revienta al preparar.
func test_hay_un_bloque_principal_por_producto() -> void:
	assert_int(_disposicion().principales.size()).is_equal(Producto.Id.size())


## El cupo de cada producto sale de acá: un producto sin su número deja a la jornada sin saber
## cuántos casilleros tiene.
func test_cada_producto_declara_su_fila_de_adelante() -> void:
	assert_int(_disposicion().filas_de_adelante.size()).is_equal(Producto.Id.size())


## Las últimas copias de cada bloque, tantas como su fila de adelante, son los casilleros. Un
## producto sin ninguno no se repone ni falta nunca, y una fila más larga que el bloque deja la
## primera reponible en un índice negativo, con la marca en el origen del local.
func test_cada_producto_tiene_casilleros_y_entran_en_su_bloque() -> void:
	var disposicion := _disposicion()
	for producto in Catalogo.todos():
		var copias := DisposicionDeLaGondola.copias(disposicion.principales[producto.id])
		(
			assert_int(disposicion.filas_de_adelante[producto.id])
			. override_failure_message(producto.nombre)
			. is_between(1, copias)
		)


## Los faltantes caben en la fila principal medida en el recurso vigente.
func test_doscientas_semillas_entran_en_fila_y_caja() -> void:  # AC-STK-033
	var disposicion := _disposicion()
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = disposicion.filas_de_adelante[producto.id]
	for jornada in range(1, 9):
		var pedidos := Apertura.pedidos_de(Compradores.de_la_jornada(jornada))
		for semilla in 200:
			var azar := RandomNumberGenerator.new()
			azar.seed = semilla
			var faltantes := Apertura.faltantes_al_azar(pedidos, casilleros, azar)
			for id: Producto.Id in faltantes:
				assert_int(faltantes[id]).is_between(1, mini(8, casilleros[id]))


## Una fila entera de casilleros, o dos iguales con los casilleros en la de adelante: las
## reponibles son las últimas del bloque, y la fila de adelante también. Que cada lugar de esa
## fila sea un casillero lo afirma `un_lugar_por_producto_test.gd` con el local armado.
##
## **Detrás no es a la misma altura.** El estante de una cabecera está inclinado hacia el
## pasillo, y ahí la fila de atrás queda más arriba. Lo que no puede pasar es que se corra de
## costado: entonces no está detrás de su columna.
func test_la_tanda_tiene_dos_filas_y_el_cupo_entra_en_la_de_adelante() -> void:  # AC-STK-030
	var disposicion := _disposicion()
	for producto in Catalogo.todos():
		var bloque := disposicion.principales[producto.id]
		var adelante := disposicion.filas_de_adelante[producto.id]
		var nombre := producto.nombre
		var total := DisposicionDeLaGondola.copias(bloque)
		assert_int(total).override_failure_message(nombre).is_equal(
			adelante * _filas_esperadas(producto.id)
		)
		var una_fila := total == adelante
		(
			assert_int(DisposicionDeLaGondola.copias(bloque))
			. override_failure_message("%s no tiene dos filas iguales" % nombre)
			. is_in([adelante, 2 * adelante])
		)
		if una_fila:
			continue
		var frente := DisposicionDeLaGondola.frente(bloque, adelante)
		var costado := frente.cross(Vector3.UP)
		for columna: int in adelante:
			var atras := DisposicionDeLaGondola.copia(bloque, columna).origin
			var delante := DisposicionDeLaGondola.copia(bloque, adelante + columna).origin
			var paso := delante - atras
			(
				assert_float(paso.dot(frente))
				. override_failure_message(
					"%s: la columna %d no va de atrás hacia adelante" % [nombre, columna]
				)
				. is_greater(0.0)
			)
			(
				assert_float(paso.dot(costado))
				. override_failure_message(
					"%s: la columna %d no está una detrás de la otra" % [nombre, columna]
				)
				. is_equal_approx(0.0, TOLERANCIA)
			)


## Una sola tanda por producto, sobre un solo estante y sin huecos: cada fila a una misma altura
## y a una misma profundidad, las columnas a paso parejo, y la fila de atrás a la altura que da
## un estante —inclinado, a lo sumo— y no a la de otro.
func test_la_tanda_de_cada_producto_esta_junta_sobre_un_solo_estante() -> void:  # AC-STK-028
	var disposicion := _disposicion()
	for producto in Catalogo.todos():
		var bloque := disposicion.principales[producto.id]
		var adelante := disposicion.filas_de_adelante[producto.id]
		var frente := DisposicionDeLaGondola.frente(bloque, adelante)
		var costado := frente.cross(Vector3.UP)
		var total := DisposicionDeLaGondola.copias(bloque)
		var inicio_adelante := total - adelante
		var primeras: Array[Vector3] = [
			DisposicionDeLaGondola.copia(bloque, 0).origin,
			DisposicionDeLaGondola.copia(bloque, inicio_adelante).origin,
		]
		var ultima := DisposicionDeLaGondola.copia(bloque, total - 1)
		# El artista puede desplazar una columna unos milímetros: se mide el paso de la fila
		# completa para no acumular el error de su primer hueco sobre todas las demás.
		var paso := absf((ultima.origin - primeras[1]).dot(costado)) / maxi(adelante - 1, 1)
		var fondo := (primeras[1] - primeras[0]).dot(frente)
		(
			assert_float(absf(primeras[0].y - primeras[1].y))
			. override_failure_message(
				"%s: sus dos filas están en estantes distintos" % producto.nombre
			)
			. is_less_equal(fondo)
		)
		for indice: int in DisposicionDeLaGondola.copias(bloque):
			var origen := DisposicionDeLaGondola.copia(bloque, indice).origin
			var primera := primeras[0 if indice < inicio_adelante else 1]
			var mensaje := "%s: la copia %d está fuera de su tanda" % [producto.nombre, indice]
			assert_float(origen.y - primera.y).override_failure_message(mensaje).is_equal_approx(
				0.0, TOLERANCIA
			)
			(
				assert_float((origen - primera).dot(frente))
				. override_failure_message(mensaje)
				. is_equal_approx(0.0, TOLERANCIA)
			)
			(
				assert_float(absf((origen - primera).dot(costado)))
				. override_failure_message(mensaje)
				. is_equal_approx(paso * (indice % adelante), TOLERANCIA)
			)


## El frente de una tanda es de dónde se la mira: de la fila de atrás hacia la de adelante, en
## horizontal, aunque la de adelante esté más baja o corrida.
func test_el_frente_va_de_la_fila_de_atras_a_la_de_adelante() -> void:
	var bloque := PackedFloat32Array()
	for origen: Vector3 in [
		Vector3(0, 1, -0.3), Vector3(0.2, 1, -0.3), Vector3(0, 0.9, 0), Vector3(0.2, 0.9, 0)
	]:
		bloque.append_array(_copia(origen))
	assert_vector(DisposicionDeLaGondola.frente(bloque, 2)).is_equal_approx(
		Vector3.BACK, Vector3.ONE * 1e-5
	)


## Una fila conserva el frente por el orden de sus columnas; sin cupo no se inventa dirección.
func test_una_fila_tiene_frente_por_el_orden_de_sus_columnas() -> void:  # AC-STK-030
	var bloque := _copia(Vector3.ZERO) + _copia(Vector3.RIGHT)
	assert_vector(DisposicionDeLaGondola.frente(bloque, 2)).is_equal(Vector3.BACK)
	assert_vector(DisposicionDeLaGondola.frente(bloque, 0)).is_equal(Vector3.ZERO)


## El puesto toma la malla de cada guía del hijo con el mismo índice. Si las cuentas difieren,
## una guía se dibuja con la malla de otra o el puesto indexa de más.
func test_hay_una_malla_por_bloque_de_guia() -> void:
	var guia: Node = auto_free((load(GUIA) as PackedScene).instantiate())
	assert_int(guia.get_child_count()).is_equal(_disposicion().guias.size())


## Cada tanda fija dice de qué producto es y cuántas de sus últimas copias son su fila de
## adelante: son casilleros de ese producto, y el cupo los suma a los de su tanda reponible.
func test_las_fijas_conservan_filas_y_casilleros() -> void:  # AC-STK-028 AC-STK-030
	var disposicion := _disposicion()
	var guias := disposicion.guias.size()
	assert_int(disposicion.productos_de_las_guias.size()).is_equal(guias)
	assert_int(disposicion.filas_de_adelante_de_las_guias.size()).is_equal(guias)
	var esperado: Array[int] = []
	for producto in Catalogo.todos():
		esperado.append(disposicion.filas_de_adelante[producto.id])
	for indice in guias:
		var id := disposicion.productos_de_las_guias[indice]
		var adelante := disposicion.filas_de_adelante_de_las_guias[indice]
		assert_int(id).is_between(0, Producto.Id.size() - 1)
		(
			assert_int(adelante)
			. override_failure_message("la tanda fija %d tiene más fila que copias" % indice)
			. is_between(0, DisposicionDeLaGondola.copias(disposicion.guias[indice]))
		)
		var bloque := disposicion.guias[indice]
		assert_int(DisposicionDeLaGondola.copias(bloque)).is_equal(adelante * _filas_esperadas(id))
		esperado[id] += adelante
	for producto in Catalogo.todos():
		assert_int(disposicion.casilleros_de(producto.id)).is_equal(esperado[producto.id])


## La decisión conserva dos filas de Actroncito/Progres y distingue las excepciones por tanda.
static func _filas_esperadas(id: Producto.Id) -> int:
	if (
		id
		in [
			Producto.Id.COSA_DE_MANI,
			Producto.Id.FLIM_POF,
			Producto.Id.BURBALOO,
			Producto.Id.MARRANOS,
			Producto.Id.POETICO
		]
	):
		return 1
	return 2

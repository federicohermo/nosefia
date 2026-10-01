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


## Lo que una jornada hace faltar de un producto tiene que entrar en su fila: con más, la góndola
## arrancaría vacía y faltaría menos de lo que la jornada dice. Coracola tiene seis casilleros a
## propósito, para los seis que le faltan en la jornada 1.
func test_ningun_faltante_de_ninguna_jornada_pasa_de_su_fila() -> void:  # AC-STK-033
	var disposicion := _disposicion()
	for numero in ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA:
		var jornada := ReglasDeLaPartida.PRIMERA_JORNADA + numero
		var faltantes := Apertura.faltantes_de_la_jornada(jornada)
		for id: Producto.Id in faltantes:
			(
				assert_int(faltantes[id])
				. override_failure_message(
					(
						"jornada %d: faltan %d %s y su fila tiene %d casilleros"
						% [
							jornada,
							faltantes[id],
							Catalogo.de(id).nombre,
							disposicion.filas_de_adelante[id],
						]
					)
				)
				. is_less_equal(disposicion.filas_de_adelante[id])
			)


## Dos filas del mismo largo, una detrás de la otra, y los casilleros en la de adelante: las
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
		(
			assert_int(DisposicionDeLaGondola.copias(bloque))
			. override_failure_message("%s no tiene dos filas iguales" % nombre)
			. is_equal(2 * adelante)
		)
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
		var primeras: Array[Vector3] = [
			DisposicionDeLaGondola.copia(bloque, 0).origin,
			DisposicionDeLaGondola.copia(bloque, adelante).origin,
		]
		var segunda := DisposicionDeLaGondola.copia(bloque, mini(adelante + 1, 2 * adelante - 1))
		var paso := absf((segunda.origin - primeras[1]).dot(costado))
		var fondo := (primeras[1] - primeras[0]).dot(frente)
		(
			assert_float(absf(primeras[0].y - primeras[1].y))
			. override_failure_message(
				"%s: sus dos filas están en estantes distintos" % producto.nombre
			)
			. is_less(fondo)
		)
		for indice: int in DisposicionDeLaGondola.copias(bloque):
			var origen := DisposicionDeLaGondola.copia(bloque, indice).origin
			var primera := primeras[0 if indice < adelante else 1]
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


## Un bloque sin dos filas no tiene frente: se avisa, y no se inventa una dirección.
func test_un_bloque_sin_fila_de_atras_no_tiene_frente() -> void:
	var bloque := _copia(Vector3.ZERO) + _copia(Vector3.RIGHT)
	assert_vector(DisposicionDeLaGondola.frente(bloque, 2)).is_equal(Vector3.ZERO)
	assert_vector(DisposicionDeLaGondola.frente(bloque, 0)).is_equal(Vector3.ZERO)


## El puesto toma la malla de cada guía del hijo con el mismo índice. Si las cuentas difieren,
## una guía se dibuja con la malla de otra o el puesto indexa de más.
func test_hay_una_malla_por_bloque_de_guia() -> void:
	var guia: Node = auto_free((load(GUIA) as PackedScene).instantiate())
	assert_int(guia.get_child_count()).is_equal(_disposicion().guias.size())

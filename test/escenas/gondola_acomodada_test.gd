## El contorno inferior conserva el paso alrededor de los muebles actuales.
extends GdUnitTestSuite

const ESTRUCTURA := preload("res://src/escenas/puestos/estructura_del_almacen.tscn")
## AC-STK-051 exige este retiro en las caras de lado de las dos islas centrales.
const GONDOLAS := ["gondolanueva", "gondolanueva2"]
const ALTO_DEL_ZOCALO := 0.5
## Más largo que esto corre a lo largo de la cara de lado: las piezas de una cabecera son cortas.
const LARGO_DE_UN_ESTANTE := 1.0


func test_ningun_estante_inferior_sobresale_de_los_superiores() -> void:  # AC-STK-051
	var estructura: Node3D = auto_free(ESTRUCTURA.instantiate())
	for nombre: String in GONDOLAS:
		var mueble := estructura.get_node(nombre) as MeshInstance3D
		var caras := mueble.mesh.get_faces()
		var lados: Array[Vector3] = [Vector3.BACK]
		if nombre in ["gondolanueva", "gondolanueva2"]:
			lados.assign([Vector3.RIGHT, Vector3.LEFT])
		for lado in lados:
			var planas: Array[PackedVector3Array] = []
			for inicio in range(0, caras.size(), 3):
				var a := mueble.transform * caras[inicio]
				var b := mueble.transform * caras[inicio + 1]
				var c := mueble.transform * caras[inicio + 2]
				var normal := (b - a).cross(c - a).normalized()
				var altura := (a.y + b.y + c.y) / 3.0
				if absf(normal.dot(Vector3.UP)) >= 0.999 and altura >= 0.1 and altura <= 2.0:
					planas.append(PackedVector3Array([a, b, c]))
			var arriba := -INF
			for cara in planas:
				if _altura(cara) >= ALTO_DEL_ZOCALO:
					arriba = maxf(arriba, _frente(cara, lado))
			# La cara de lado es el largo que cubren sus estantes de arriba, que corren a lo largo
			# del mueble: lo que va en la cabecera, como un exhibidor, no es de esta cara.
			var largo := lado.cross(Vector3.UP)
			var desde := INF
			var hasta := -INF
			for cara in planas:
				if _altura(cara) >= ALTO_DEL_ZOCALO and _largo(cara, largo) > LARGO_DE_UN_ESTANTE:
					for punto in cara:
						desde = minf(desde, punto.dot(largo))
						hasta = maxf(hasta, punto.dot(largo))
			var abajo := -INF
			for cara in planas:
				var centro := (cara[0] + cara[1] + cara[2]).dot(largo) / 3.0
				if _altura(cara) < ALTO_DEL_ZOCALO and centro >= desde and centro <= hasta:
					abajo = maxf(abajo, _frente(cara, lado))
			(
				assert_bool(is_finite(abajo) and is_finite(arriba))
				. override_failure_message(nombre)
				. is_true()
			)
			(
				assert_float(abajo - arriba)
				. override_failure_message("%s %s" % [nombre, lado])
				. is_less_equal(0.005)
			)


static func _altura(cara: PackedVector3Array) -> float:
	return (cara[0].y + cara[1].y + cara[2].y) / 3.0


static func _frente(cara: PackedVector3Array, lado: Vector3) -> float:
	return maxf(cara[0].dot(lado), maxf(cara[1].dot(lado), cara[2].dot(lado)))


static func _largo(cara: PackedVector3Array, eje: Vector3) -> float:
	var valores: Array[float] = [cara[0].dot(eje), cara[1].dot(eje), cara[2].dot(eje)]
	return valores.max() - valores.min()

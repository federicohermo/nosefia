## El contorno inferior conserva el paso alrededor de los muebles actuales.
extends GdUnitTestSuite

const ESTRUCTURA := preload("res://src/escenas/puestos/estructura_del_almacen.tscn")
## AC-STK-051 exige este retiro en las caras de lado de las dos islas centrales.
const GONDOLAS := ["gondolanueva", "gondolanueva2"]
const ALTO_DEL_ZOCALO := 0.5


func test_ningun_estante_inferior_sobresale_de_los_superiores() -> void:  # AC-STK-051
	var estructura: Node3D = auto_free(ESTRUCTURA.instantiate())
	for nombre: String in GONDOLAS:
		var mueble := estructura.get_node(nombre) as MeshInstance3D
		var caras := mueble.mesh.get_faces()
		var lados: Array[Vector3] = [Vector3.BACK]
		if nombre in ["gondolanueva", "gondolanueva2"]:
			lados.assign([Vector3.RIGHT, Vector3.LEFT])
		for lado in lados:
			var abajo := -INF
			var arriba := -INF
			for inicio in range(0, caras.size(), 3):
				var a := mueble.transform * caras[inicio]
				var b := mueble.transform * caras[inicio + 1]
				var c := mueble.transform * caras[inicio + 2]
				var normal := (b - a).cross(c - a).normalized()
				var altura := (a.y + b.y + c.y) / 3.0
				if absf(normal.dot(Vector3.UP)) < 0.999 or altura < 0.1 or altura > 2.0:
					continue
				var frente := maxf(a.dot(lado), maxf(b.dot(lado), c.dot(lado)))
				if altura < ALTO_DEL_ZOCALO:
					abajo = maxf(abajo, frente)
				else:
					arriba = maxf(arriba, frente)
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

extends GdUnitTestSuite

const OBJETOS := preload("res://src/escenas/puestos/objetos_del_almacen.tscn")
const CAJAS := preload("res://src/escenas/puestos/cajas_del_proveedor.tscn")


## El rectángulo que un cuerpo ocupa en el piso, a partir de la forma que declara su escena.
func _huella(cuerpo: Node3D) -> Rect2:
	var forma := cuerpo.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
	var puntos: PackedVector3Array = []
	if forma.shape is BoxShape3D:
		var mitad := (forma.shape as BoxShape3D).size / 2.0
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					puntos.append(Vector3(sx, sy, sz) * mitad)
	else:
		puntos = (forma.shape as ConvexPolygonShape3D).points
	var al_mundo := cuerpo.transform * forma.transform
	var primero := al_mundo * puntos[0]
	var huella := Rect2(Vector2(primero.x, primero.z), Vector2.ZERO)
	for punto: Vector3 in puntos:
		var en_el_mundo := al_mundo * punto
		huella = huella.expand(Vector2(en_el_mundo.x, en_el_mundo.z))
	return huella


func _palanca() -> RigidBody3D:
	var objetos: Node3D = auto_free(OBJETOS.instantiate())
	return objetos.get_node("Palanca") as RigidBody3D


func _caja_de_madera() -> StaticBody3D:
	var cajas: Node3D = auto_free(CAJAS.instantiate())
	return cajas.get_node("CajaDeMadera") as StaticBody3D


func test_la_palanca_arranca_apoyada_en_el_piso_como_la_caja_de_madera() -> void:
	var palanca := _palanca()
	var alto := ((palanca.get_node("Forma") as CollisionShape3D).shape as BoxShape3D).size.y
	var base := palanca.position.y - alto / 2.0
	assert_float(base).is_equal_approx(_caja_de_madera().position.y, 0.01)


func test_la_palanca_arranca_cerca_de_la_caja_de_madera_sin_tocar_ninguna_caja() -> void:
	var palanca := _palanca()
	var cuerpo := _huella(palanca)
	var madera := _huella(_caja_de_madera())
	var cajas: Node3D = auto_free(CAJAS.instantiate())
	var carton := _huella(cajas.get_node("CajaDeCarton") as Node3D)
	assert_bool(cuerpo.intersects(madera)).is_false()
	assert_bool(cuerpo.intersects(carton)).is_false()
	var largo := maxf(cuerpo.size.x, cuerpo.size.y)
	var separacion := Vector2(
		maxf(0.0, maxf(madera.position.x - cuerpo.end.x, cuerpo.position.x - madera.end.x)),
		maxf(0.0, maxf(madera.position.y - cuerpo.end.y, cuerpo.position.y - madera.end.y))
	)
	assert_float(separacion.length()).is_less(largo)


func test_la_palanca_queda_delante_de_la_caja_de_madera_para_quien_llega_del_deposito() -> void:
	var palanca := _huella(_palanca())
	var madera := _huella(_caja_de_madera())
	assert_float(palanca.end.y).is_less(madera.position.y)

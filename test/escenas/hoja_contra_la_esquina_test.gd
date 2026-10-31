## La hoja de la puerta nunca se superpone con una caja grande, aunque ésta quede trabada contra
## una pared o una esquina: arrastrarla vale mientras haya lugar, y si no lo hay la hoja se detiene.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

const HOJA := "Estructura/puerta"

## La caja más grande del catálogo.
const PRODUCTO_DE_LA_CAJA := Producto.Id.BURBALOO

## A qué distancia de la bisagra va la caja: pegada a la bisagra, a mitad de hoja y en el extremo.
const RADIOS := [1.0, 1.2, 1.35]

## A qué ángulo de la hoja cerrada la hoja toca la caja: cerca de la bisagra, donde la hoja
## apenas empezó a abrir.
const CONTACTO := deg_to_rad(40.0)

## Cuánto gira la normal del muro respecto del sentido del arrastre: de frente, y de costado.
const INCLINACIONES := [0.0, 35.0, -35.0]

## La caja no gira con la hoja: su esquina asoma hasta la raíz de dos de su media.
const ANCHO_DE_LA_ESQUINA := 1.42

const CUADROS_MAXIMOS := 900
const CUADROS_PARA_DORMIRSE := 120
const CUADROS_QUIETA := 90
const ESPESOR_DEL_MURO := 0.2

## Cuánto deja el motor que un cuerpo vivo apoyado se hunda en lo que toca.
const PENETRACION_TOLERADA := "physics/jolt_physics_3d/simulation/penetration_slop"

## Metros. El ancho del muro.
const ANCHO_DEL_MURO := 1.2


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get_node(HOJA + "/CuerpoDeLaHoja").set("traba", 0)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	return almacen


func _cuerpo_de(hoja: Node3D) -> PhysicsBody3D:
	for hijo in hoja.get_children():
		if hijo.has_method("puerta"):
			return hijo
	return null


func _esperar(cuadros: int) -> void:
	for cuadro in cuadros:
		await get_tree().physics_frame


func _angulo_de(cuerpo: PhysicsBody3D) -> float:
	return cuerpo.call("puerta").angulo()


## Dónde está la bisagra y hacia dónde apunta la hoja cerrada, en el mundo.
func _bisagra_y_brazo(hoja: MeshInstance3D) -> Array:
	var padre: Transform3D = hoja.global_transform * hoja.transform.affine_inverse()
	var cuerpo := _cuerpo_de(hoja)
	var cerrada: Transform3D = padre * cuerpo.get("_cerrada")
	var brazo := (cerrada.basis.x * Vector3(1.0, 0.0, 1.0)).normalized()
	return [padre * cuerpo.get("_bisagra"), brazo]


func _punto_en_el_piso(
	almacen: Node3D, hoja: MeshInstance3D, angulo: float, radio: float
) -> Vector3:
	var datos := _bisagra_y_brazo(hoja)
	var punto: Vector3 = datos[0] + Basis(Vector3.UP, angulo) * datos[1] * radio
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	punto.y = suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0
	return punto


func _sentido_del_giro(hoja: MeshInstance3D, punto: Vector3) -> Vector3:
	var radio: Vector3 = punto - _bisagra_y_brazo(hoja)[0]
	radio.y = 0.0
	return Vector3.UP.cross(radio).normalized()


func _caja_en(almacen: Node3D, punto: Vector3, congelada: bool) -> RigidBody3D:
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[PRODUCTO_DE_LA_CAJA]
	caja.global_basis = Basis.IDENTITY
	caja.global_position = punto + Vector3.UP * (caja.media() + 0.01)
	caja.call("quedarse_quieta")
	if not congelada:
		caja.freeze = false
		caja.can_sleep = false
		caja.sleeping = false
	return caja


## Un muro de frente al `empuje` y, si la caja queda en el rincón, otro hacia afuera de la hoja.
func _muro(caja: RigidBody3D, normal: Vector3) -> void:
	var muro := StaticBody3D.new()
	muro.collision_layer = caja.collision_mask
	var forma := CollisionShape3D.new()
	var volumen := BoxShape3D.new()
	volumen.size = Vector3(ANCHO_DEL_MURO, 3.0, ESPESOR_DEL_MURO)
	forma.shape = volumen
	muro.add_child(forma)
	caja.get_parent().add_child(muro)
	var mitad: float = caja.call("media") * 1.42 + ESPESOR_DEL_MURO / 2.0
	muro.global_transform = Transform3D(
		Basis.looking_at(normal, Vector3.UP), caja.global_position + normal * mitad
	)


## Si el cuerpo se hunde en la hoja más de lo que el motor tolera a un cuerpo vivo que empuja.
func _adentro_de_la_hoja(cuerpo: PhysicsBody3D, hoja: PhysicsBody3D) -> bool:
	var espacio := cuerpo.get_world_3d().direct_space_state
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.margin = -(
			ReglasDeLosObjetos.ROCE + float(ProjectSettings.get_setting(PENETRACION_TOLERADA, 0.0))
		)
		for golpe in espacio.intersect_shape(consulta, 32):
			if golpe["collider"] == hoja:
				return true
	return false


## Gira la hoja hasta que llega a su tope o queda quieta contra la caja, y devuelve en qué cuadro
## se superpusieron, o -1 si nunca.
func _primer_cuadro_superpuesto(
	cuerpo: PhysicsBody3D, caja: RigidBody3D, tope: float
) -> Dictionary:
	cuerpo.call("alternar")
	var quietos := 0
	var anterior := _angulo_de(cuerpo)
	for cuadro in CUADROS_MAXIMOS:
		await get_tree().physics_frame
		if _adentro_de_la_hoja(caja, cuerpo):
			return {"cuadro": cuadro, "angulo": rad_to_deg(_angulo_de(cuerpo))}
		var angulo := _angulo_de(cuerpo)
		quietos = quietos + 1 if is_equal_approx(angulo, anterior) else 0
		anterior = angulo
		if is_equal_approx(angulo, tope) or quietos >= CUADROS_QUIETA:
			break
	return {"cuadro": -1, "angulo": rad_to_deg(_angulo_de(cuerpo))}


## Barre cada radio y cada inclinación del muro con la hoja tocando la caja a `CONTACTO`, y devuelve
## las combinaciones donde la hoja y la caja se superpusieron en algún cuadro.
func _superposiciones(abriendo: bool, congelada: bool) -> Array[String]:
	var fallas: Array[String] = []
	for radio: float in RADIOS:
		for inclinacion: float in INCLINACIONES:
			var almacen: Node3D = await _almacen()
			var hoja: MeshInstance3D = almacen.get_node(HOJA)
			var cuerpo := _cuerpo_de(hoja)
			if not abriendo:
				cuerpo.call("alternar")
				await _esperar(CUADROS_MAXIMOS / 2)
			var caja := _caja_en(almacen, Vector3.ZERO, congelada)
			# La hoja toca la caja antes de su centro, porque ésta se extiende a lo largo del arco.
			var ancho_en_el_arco := asin(caja.call("media") * ANCHO_DE_LA_ESQUINA / radio)
			var centro := CONTACTO + (ancho_en_el_arco if abriendo else -ancho_en_el_arco)
			var apoyo := _punto_en_el_piso(almacen, hoja, centro, radio)
			caja.global_position = apoyo + Vector3.UP * (float(caja.call("media")) + 0.01)
			caja.call("quedarse_quieta")
			if not congelada:
				caja.freeze = false
				caja.can_sleep = false
				caja.sleeping = false
			var empuje := (
				_sentido_del_giro(hoja, caja.global_position) * (1.0 if abriendo else -1.0)
			)
			_muro(caja, empuje.rotated(Vector3.UP, deg_to_rad(inclinacion)))
			if radio >= RADIOS[-1]:
				var afuera: Vector3 = caja.global_position - _bisagra_y_brazo(hoja)[0]
				afuera.y = 0.0
				_muro(caja, afuera.normalized())
			await get_tree().physics_frame
			var tope := Puerta.ANGULO_ABIERTA if abriendo else 0.0
			var choque := await _primer_cuadro_superpuesto(cuerpo, caja, tope)
			if choque["cuadro"] >= 0:
				fallas.append(
					(
						"radio %.2f, muro a %.0f°: superpuestas en el cuadro %d con la hoja a %.1f°"
						% [radio, inclinacion, choque["cuadro"], choque["angulo"]]
					)
				)
			almacen.queue_free()
			await get_tree().physics_frame
	return fallas


func test_la_hoja_no_se_superpone_con_una_caja_grande_al_abrir() -> void:  # AC-PLY-149
	var fallas := await _superposiciones(true, true)
	assert_array(fallas).is_empty()


func test_la_hoja_no_se_superpone_con_una_caja_grande_al_cerrar() -> void:  # AC-PLY-149
	var fallas := await _superposiciones(false, true)
	assert_array(fallas).is_empty()


func test_la_hoja_no_se_superpone_con_una_caja_grande_despierta_al_abrir() -> void:  # AC-PLY-149
	var fallas := await _superposiciones(true, false)
	assert_array(fallas).is_empty()


func test_la_hoja_no_se_superpone_con_una_caja_grande_despierta_al_cerrar() -> void:  # AC-PLY-149
	var fallas := await _superposiciones(false, false)
	assert_array(fallas).is_empty()

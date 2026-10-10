## La forma que el acomodador le da a la góndola, mirada sobre lo que queda en el repo: cómo va
## cada unidad en la rampa de una cabecera y hasta dónde llega cada cara de lado.
##
## Las dos cosas las marcó el usuario el 2026-09-29 mirando el local desde la entrada: los
## productos de las cabeceras caían hacia adelante, y los estantes achicados quedaban hundidos
## entre laterales que conservaban el ancho de antes.
extends GdUnitTestSuite

const CONTENIDO := preload("res://src/escenas/puestos/contenido_del_estante.tscn")
const GUIA := preload("res://src/escenas/puestos/guia_del_estante.tscn")
const ESTRUCTURA := preload("res://src/escenas/puestos/estructura_del_almacen.tscn")
const DISPOSICION := preload("res://src/escenas/puestos/disposicion_de_la_gondola.tres")

## Los muebles con caras de lado: las dos góndolas del medio y las dos de pared.
const GONDOLAS := ["gondolanueva", "gondolanueva2", "gondolanueva_001", "gondolanueva_002"]

## Cuánto tiene que subir la fila de atrás sobre la de adelante para que el estante sea una
## rampa, en metros: en un estante plano las dos quedan a la misma altura.
const SUBE_LA_RAMPA := 0.01

## Cuánto se echa hacia atrás, como mínimo, una unidad sobre la rampa: el seno del ángulo. El
## artista las echaba entre 9 y 15 grados, y la chapa baja 11.
const ECHADA := 0.1

## Hasta qué altura va el zócalo, en metros.
const ALTO_DEL_ZOCALO := 0.5

## Lo que puede quedar entre el frente de la fila de adelante y lo más afuera del mueble a esa
## altura, en metros: el margen detrás del labio y el portaprecio, que asoma 4,7 cm.
const HASTA_EL_LATERAL := 0.08


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


## Cada bloque de la disposición, con lo que hace falta para ubicar sus copias en el mundo: la
## vuelta del modelo que el puesto hornea en su malla, y cuántas copias forman la fila de adelante.
func _bloques() -> Array[Dictionary]:
	var contenido: Node3D = auto_free(CONTENIDO.instantiate())
	var guia: Node3D = auto_free(GUIA.instantiate())
	var bloques: Array[Dictionary] = []
	for producto in Catalogo.todos():
		var modelo := contenido.get_child(producto.id) as MeshInstance3D
		(
			bloques
			. append(
				{
					"nombre": producto.nombre,
					"bloque": DISPOSICION.principales[producto.id],
					"fila": DISPOSICION.filas_de_adelante[producto.id],
					"modelo": modelo,
				}
			)
		)
	for indice in DISPOSICION.guias.size():
		var bloque := DISPOSICION.guias[indice]
		var modelo := guia.get_child(indice) as MeshInstance3D
		var filas := 0
		for producto in Catalogo.todos():
			var principal := contenido.get_child(producto.id) as MeshInstance3D
			if principal.mesh.resource_path == modelo.mesh.resource_path:
				@warning_ignore("integer_division")
				filas = (
					DisposicionDeLaGondola.copias(DISPOSICION.principales[producto.id])
					/ DISPOSICION.filas_de_adelante[producto.id]
				)
		assert_bool(filas in [1, 2]).override_failure_message(modelo.name).is_true()
		@warning_ignore("integer_division")
		var fila := DisposicionDeLaGondola.copias(bloque) / filas
		bloques.append({"nombre": modelo.name, "bloque": bloque, "fila": fila, "modelo": modelo})
	return bloques


## Cómo queda en el mundo una copia: la vuelta de la copia sobre la del modelo, en su lugar.
static func _copia_en_el_mundo(datos: Dictionary, indice: int) -> Transform3D:
	var copia := DisposicionDeLaGondola.copia(datos.bloque, indice)
	return Transform3D(copia.basis * (datos.modelo as Node3D).basis, copia.origin)


## Cuánto sube la fila de atrás sobre la de adelante.
static func _sube_hacia_el_fondo(bloque: PackedFloat32Array, fila: int) -> float:
	var total := DisposicionDeLaGondola.copias(bloque)
	if total == fila:
		return 0.0
	var atras := 0.0
	var adelante := 0.0
	for indice in total:
		var alto := DisposicionDeLaGondola.copia(bloque, indice).origin.y
		if indice < total - fila:
			atras += alto / (total - fila)
		else:
			adelante += alto / fila
	return atras - adelante


## El eje de la unidad que más se parece a `hacia`, dado vuelta si apunta al revés.
static func _eje(giro: Basis, hacia: Vector3) -> Vector3:
	var mejor := Vector3.ZERO
	for columna in 3:
		var eje := giro[columna].normalized()
		if absf(eje.dot(hacia)) > absf(mejor.dot(hacia)):
			mejor = eje
	return mejor if mejor.dot(hacia) > 0.0 else -mejor


## En la rampa de una cabecera cada unidad va echada hacia atrás, como la ponía el artista: su
## frente mira hacia arriba y hacia el pasillo, y lo de arriba se aparta del pasillo. Apoyada de
## plano sobre la chapa, que baja hacia el pasillo, caía hacia adelante con el frente al piso.
func test_en_la_rampa_de_una_cabecera_cada_unidad_se_echa_hacia_atras() -> void:
	var en_rampa := 0
	for datos in _bloques():
		var bloque: PackedFloat32Array = datos.bloque
		var fila: int = datos.fila
		var frente := DisposicionDeLaGondola.frente(bloque, fila)
		if frente == Vector3.ZERO or _sube_hacia_el_fondo(bloque, fila) < SUBE_LA_RAMPA:
			continue
		en_rampa += 1
		for indice in DisposicionDeLaGondola.copias(bloque):
			var giro := _copia_en_el_mundo(datos, indice).basis.orthonormalized()
			var su_frente := _eje(giro, frente)
			var lo_de_arriba := _eje(giro, Vector3.UP)
			(
				assert_float(su_frente.y)
				. override_failure_message("%s: su frente no mira hacia arriba" % datos.nombre)
				. is_greater(ECHADA)
			)
			(
				assert_float(lo_de_arriba.dot(frente))
				. override_failure_message("%s: cae hacia el pasillo" % datos.nombre)
				. is_less(-ECHADA)
			)
	# Las cabeceras son rampas: sin ninguna, el test no está mirando lo que dice.
	assert_int(en_rampa).is_greater(0)


## Cada cara de lado se angosta hasta sus estantes: ninguno de arriba del zócalo queda hundido
## entre los laterales. Entre el frente de la fila de adelante de cada estante y lo más afuera del
## mueble a esa altura no queda más que el margen y el portaprecio.
func test_ningun_estante_de_arriba_queda_detras_del_lateral() -> void:
	var estructura: Node3D = auto_free(ESTRUCTURA.instantiate())
	var gondolas: Array[MeshInstance3D] = []
	var vertices: Array[PackedVector3Array] = []
	var cajas: Array[AABB] = []
	for nombre: String in GONDOLAS:
		var gondola := estructura.get_node(nombre) as MeshInstance3D
		var puntos := PackedVector3Array()
		for punto in gondola.mesh.get_faces():
			puntos.append(gondola.transform * punto)
		gondolas.append(gondola)
		vertices.append(puntos)
		cajas.append(gondola.transform * gondola.mesh.get_aabb())
	var mirados := 0
	for datos in _bloques():
		var bloque: PackedFloat32Array = datos.bloque
		var fila: int = datos.fila
		var frente := DisposicionDeLaGondola.frente(bloque, fila)
		# Las caras de lado miran al este o al oeste; las cabeceras, al norte o al sur.
		if absf(frente.x) < 0.9:
			continue
		var total := DisposicionDeLaGondola.copias(bloque)
		var malla: Mesh = (datos.modelo as MeshInstance3D).mesh
		var abajo := INF
		var adelante := -INF
		var centro := Vector3.ZERO
		for indice in range(total - fila, total):
			var caja := _copia_en_el_mundo(datos, indice) * malla.get_aabb()
			abajo = minf(abajo, caja.position.y)
			centro += caja.get_center() / fila
			for esquina in 8:
				adelante = maxf(adelante, caja.get_endpoint(esquina).dot(frente))
		if abajo < ALTO_DEL_ZOCALO:
			continue
		var de_cual := -1
		for indice in cajas.size():
			if cajas[indice].grow(0.05).has_point(centro):
				de_cual = indice
		if de_cual < 0:
			# La heladera: no se angosta.
			continue
		var lateral := -INF
		for punto in vertices[de_cual]:
			if punto.y > abajo - 0.05:
				lateral = maxf(lateral, punto.dot(frente))
		mirados += 1
		(
			assert_float(lateral - adelante)
			. override_failure_message(
				(
					"%s, en %s a %.2f m de alto: queda %.3f m detrás de lo más afuera del mueble"
					% [datos.nombre, GONDOLAS[de_cual], abajo, lateral - adelante]
				)
			)
			. is_less_equal(HASTA_EL_LATERAL)
		)
	assert_int(mirados).is_greater(0)

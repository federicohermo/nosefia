## Los dos scripts de `assets/models/` que escriben recursos commiteados a partir del modelo: la
## malla de cada producto (`extraer_mallas.gd`) y su miniatura de la planilla
## (`generar_miniaturas.gd`).
##
## Se corren a mano y no en la suite: uno reescribe `producto_*.res` y el otro necesita pantalla.
## Acá se prueba lo que deciden —el nombre de cada archivo, dónde va la cámara y cómo se endereza
## lo que está en una rampa—. Qué nodo del modelo es la unidad de cada producto lo prueba
## `modelo_exportado_test.gd`, contra la malla que el extractor dejó en el contenido.
extends GdUnitTestSuite

const ExtraerMallas := preload("res://assets/models/extraer_mallas.gd")
const GenerarMiniaturas := preload("res://assets/models/generar_miniaturas.gd")
const CONTENIDO := preload("res://src/escenas/puestos/contenido_del_estante.tscn")
const DISPOSICION := preload("res://src/escenas/puestos/disposicion_de_la_gondola.tres")

## Desde cuánta inclinación un estante es una rampa, en grados.
const RAMPA := 1.0


func test_el_nombre_de_archivo_va_en_minusculas_sin_acentos_y_con_guion_bajo() -> void:
	assert_str(ExtraerMallas.slug("Cosa de Maní")).is_equal("cosa_de_mani")
	assert_str(ExtraerMallas.slug("Feel Ricky Fort")).is_equal("feel_ricky_fort")
	assert_str(ExtraerMallas.slug("Oaaaa")).is_equal("oaaaa")


## Si el extractor escribe otro nombre que el que la escena carga, la escena queda apuntando a un
## archivo que nadie regenera, y el pipeline da verde sin haber cambiado nada del juego.
func test_la_escena_del_estante_carga_la_malla_que_escribe_el_extractor() -> void:
	var contenido: Node3D = auto_free(CONTENIDO.instantiate())
	for producto in Catalogo.todos():
		var nodo: MeshInstance3D = contenido.get_child(producto.id)
		assert_str(nodo.mesh.resource_path).override_failure_message(producto.nombre).is_equal(
			ExtraerMallas.ruta_de_la_malla(producto)
		)


## Lo mismo con la planilla: la miniatura que el generador escribe en `assets/ui/manada/`
## reemplaza a la que la planilla muestra, en vez de quedar suelta al lado.
func test_la_planilla_muestra_la_miniatura_que_escribe_el_generador() -> void:
	for producto in Catalogo.todos():
		var imagen: Texture2D = AppCaja.IMAGENES[producto.id]
		var nombre: String = GenerarMiniaturas.nombre_de_archivo(producto)
		assert_str(imagen.resource_path).override_failure_message(producto.nombre).is_equal(
			"res://assets/ui/manada".path_join(nombre)
		)


## La cara que más se ve es el frente, con un poco del costado derecho y de arriba, y la cámara
## se aleja lo justo para que el envase entero entre en la imagen.
func test_la_camara_mira_el_frente_y_ve_el_envase_entero() -> void:
	var caja := AABB(Vector3(-0.1, 0.0, -0.2), Vector3(0.2, 0.3, 0.4))
	var frentes: Array[Vector3] = [Vector3.LEFT, Vector3.BACK, Vector3(1, 0, 1).normalized()]
	for frente in frentes:
		var lugar: Vector3 = GenerarMiniaturas.lugar_de_la_camara(caja, frente)
		var desde := lugar - caja.get_center()
		var de_costado := desde.dot(Vector3.UP.cross(frente))
		assert_float(de_costado).is_greater(0.0)
		assert_float(desde.y).is_greater(0.0)
		assert_float(desde.dot(frente)).is_greater(maxf(de_costado, desde.y))
		var radio := caja.size.length() / 2.0
		var mitad_del_campo := deg_to_rad(GenerarMiniaturas.CAMPO / 2.0)
		assert_float(asin(radio / desde.length())).is_less(mitad_del_campo)


## Lo que se exhibe en una rampa sale derecho, y lo que está en un estante plano no se gira.
##
## La normal sale de las dos filas del estante y no del giro de la unidad, que depende de cómo
## está modelado cada envase: el eje que queda arriba no es el mismo en todos.
func test_la_miniatura_endereza_la_rampa_y_deja_quieto_lo_que_esta_derecho() -> void:
	var en_rampa := 0
	for producto in Catalogo.todos():
		var bloque := DISPOSICION.principales[producto.id]
		var fila := DISPOSICION.filas_de_adelante[producto.id]
		var normal: Vector3 = GenerarMiniaturas.normal_del_estante(bloque, fila)
		var derecho: Basis = GenerarMiniaturas.enderezar(normal)
		assert_float(normal.y).override_failure_message(producto.nombre).is_greater(0.0)
		(
			assert_bool((derecho * normal).is_equal_approx(Vector3.UP))
			. override_failure_message(producto.nombre)
			. is_true()
		)
		if normal.angle_to(Vector3.UP) > deg_to_rad(RAMPA):
			en_rampa += 1
		else:
			(
				assert_float(derecho.get_rotation_quaternion().get_angle())
				. override_failure_message(producto.nombre)
				. is_less(deg_to_rad(RAMPA))
			)
	# Las cabeceras son rampas: sin ninguna, este test no está mirando lo que endereza.
	assert_int(en_rampa).is_greater(0)

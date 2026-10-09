## La caja del depósito: qué producto declara, con qué cuerpo se lleva, con qué etiqueta se ve y
## qué dejó de hacer.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`.
## La excepción son los casos que miran lo que arma `_ready()`: el tamaño y la etiqueta.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/objetos/caja_de_productos.tscn"
const SCRIPT := "res://src/escenas/objetos/caja_de_productos.gd"
const CABLEADO := "res://src/escenas/almacen.gd"

## Las escenas que declaran las 31 cajas. Ninguna les pisa el material.
const ESCENAS_CON_CAJAS := [
	"res://src/escenas/puestos/objetos_del_almacen.tscn", "res://src/escenas/almacen.tscn"
]

## La escena que lista las cajas, en `_cajas_de_productos`.
const CAJAS_DEL_ALMACEN := "res://src/escenas/almacen.tscn"

## Donde el juego carga las etiquetas: `source/` no se importa, y el juego no lo ve.
const ETIQUETAS := "res://assets/boxes/"

## Donde el artista dejó las etiquetas. Lleva nombres con acento, que la copia no lleva.
const ORIGEN := "res://assets/source/textures/stockroom/DEPOSITO CAJAS TEXTURA/"

## La textura de la caja genérica «DEPÓSITO».
const GENERICA := "res://assets/models/SEPT_JUEGOS_PROTOTIPO_caja.png"

## El parámetro de importación que achica una textura: su lado más grande, en píxeles.
const LADO_TOPE := "process/size_limit"

## Una etiqueta de la góndola. Viaja en el `.glb` con el lado que el exportador le da a las de
## los productos, y ése es el lado con el que viajan las de las cajas.
const ETIQUETA_DE_LA_GONDOLA := "res://assets/models/SEPT_JUEGOS_PROTOTIPO_Actroncito completo.png"

## Los productos con etiqueta propia, con el archivo del artista del que sale cada una.
## `caja jorgillata.png` es otra textura de Jorgillo, y no va: va `CAJA JORGILLO.png`.
const ORIGEN_DE_CADA_ETIQUETA := {
	Producto.Id.ACTRONCITO: "CAJA ACTRÓNCITO.png",
	Producto.Id.AMARGADITO: "CAJA AMARGADITO.png",
	Producto.Id.BURBALOO: "CAJA BURBALOO.png",
	Producto.Id.CINDOLOR: "CAJA CINDOLOR.png",
	Producto.Id.COSA_DE_MANI: "CAJA COSA DE MANÍ.png",
	Producto.Id.DONSATURADOS: "CAJA DON SATURADOS.png",
	Producto.Id.DUREXTRA: "CAJA DUREXTRA.png",
	Producto.Id.DURONGA: "CAJA DURONGA.png",
	Producto.Id.FERNET_GOD: "CAJA FERNET-GOD.png",
	Producto.Id.FLINPUF: "CAJA FLIN POF.png",
	Producto.Id.FROTLUPS: "CAJA FROTLUPS.png",
	Producto.Id.JORGILLO: "CAJA JORGILLO.png",
	Producto.Id.LAYSNTT: "CAJA LAYSNT´T.png",
	Producto.Id.MACUMBAS: "CAJA MACUMBAS.png",
	Producto.Id.MAYONCHIS: "CAJA MAYONCHIS.png",
	Producto.Id.OAAAA: "CAJA OAAAAA.png",
	Producto.Id.PETISAS: "CAJA PETISAS.png",
	Producto.Id.TERMINATOR: "CAJA TERMINATOR.png",
	Producto.Id.ZUCARACHAS: "CAJA ZUCARACHAS.png",
}

## Los que siguen con la caja genérica: el artista no dibujó la suya.
const SIN_ETIQUETA := [
	Producto.Id.ARVEJAS,
	Producto.Id.CHISITOS,
	Producto.Id.CORACOLA,
	Producto.Id.MALBARDO,
	Producto.Id.MAROLINI,
	Producto.Id.OREMOS,
	Producto.Id.PEPITOS,
	Producto.Id.PRONGLES,
	Producto.Id.SALADIK,
	Producto.Id.UAKAS,
	Producto.Id.MARRANOS,
	Producto.Id.FEEL_RICKY_FORT,
]

## El script del nodo se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y no
## declaran `class_name`.
const CajaQueSeLleva := preload("res://src/escenas/objetos/caja_de_productos.gd")


func test_la_caja_declara_su_producto_con_un_id_del_catalogo() -> void:
	# Es un `Producto.Id` y no un `String` suelto: el conjunto es cerrado, y uno mal escrito no
	# rompe nada — el producto simplemente no llega nunca y nadie se entera.
	var caja := _caja()
	caja.producto = Producto.Id.MALBARDO
	assert_object(Catalogo.de(caja.producto)).is_not_null()
	assert_int(Catalogo.de(caja.producto).id).is_equal(Producto.Id.MALBARDO)


## El tamaño lo dice la ficha del producto, que el catálogo lleva, y no la escena: la caja chica
## de Jorgillo y la grande de Zucarachas salen de la misma escena, cambiando sólo el producto.
func test_la_caja_tiene_el_tamano_que_le_da_el_catalogo() -> void:
	var medias: Array[float] = []
	for id: Producto.Id in [Producto.Id.JORGILLO, Producto.Id.ZUCARACHAS]:
		var caja := _caja()
		caja.producto = id
		add_child(caja)
		var media: float = CajaQueSeLleva.MEDIA_CAJA[Catalogo.caja_de(id)]
		for parte: String in ["Cuerpo", "Malla"]:
			(
				assert_vector((caja.get_node(parte) as Node3D).scale)
				. override_failure_message("%s de %s" % [parte, Catalogo.de(id).nombre])
				. is_equal_approx(Vector3.ONE * media, Vector3.ONE * 1e-6)
			)
		medias.append(media)
	assert_float(medias[0]).is_less(medias[1])


func test_tocar_la_caja_la_entrega_para_levantarla() -> void:
	# Antes devolvía `null` y el clic sacaba una unidad. Ahora contesta sus propios datos, que es
	# lo que `Agarre` necesita para llevársela, y no son los de una unidad de producto: quien
	# mire lo que hay en la mano tiene que poder distinguir la caja de lo que sale de ella.
	var caja := _caja()
	var datos := caja.call(ReglasDeLosObjetos.METODO_INTERACTUAR) as ObjetoDelAlmacen
	assert_object(datos).is_not_null()
	assert_bool(datos is UnidadDeProducto).is_false()
	assert_bool(datos.es_levantable()).is_true()


func test_la_caja_contesta_el_contrato_de_interaccion() -> void:
	var caja := _caja()
	assert_bool(caja.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()
	assert_bool(caja.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()


func test_el_cuerpo_de_la_caja_se_puede_llevar() -> void:
	# Unos `datos` en `null` los rechaza `Manos` como «no es levantable»: la escena carga sin un
	# solo error y el clic no hace nada.
	#
	# **El cuerpo es rígido y arranca congelado**, y las dos mitades importan. El spec lo pedía
	# estático —«una caja se apoya, no rebota ni rueda»—, y eso sigue siendo cierto mientras
	# descansa: congelada es un cuerpo estático, y el puesto le escribe el lugar derecho. Rígido
	# es lo que la deja caer cuando le sacan lo que la sostenía, que es lo que desarma una pila.
	var caja := _caja()
	assert_object(caja).is_instanceof(RigidBody3D)
	(
		assert_bool(caja.freeze)
		. override_failure_message("la caja arranca viva: se acomoda sola antes de que la toquen")
		. is_true()
	)
	(
		assert_object(caja.datos)
		. override_failure_message("`caja_de_productos.tscn` no le asignó `datos`: no se levanta")
		. is_not_null()
	)
	assert_str(caja.datos.nombre).is_not_empty()


func test_reparentar_conserva_las_etiquetas_y_destruir_no_da_error() -> void:
	var origen: Node3D = auto_free(Node3D.new())
	var destino: Node3D = auto_free(Node3D.new())
	add_child(origen)
	add_child(destino)
	var cajas: Array[Node3D] = []
	var materiales: Array[int] = []
	var fuente: Mesh
	var material_generico: BaseMaterial3D
	var etiqueta_retenida: BaseMaterial3D
	var generica := ""
	for _indice in 2:
		# Se liberan dentro del callable: no registrarlas también en auto_free.
		var caja := load(ESCENA).instantiate() as Node3D
		var datos: Resource = caja.get("datos")
		caja.set("producto", Producto.Id.ACTRONCITO)
		origen.add_child(caja)
		cajas.append(caja)
		var malla := caja.get_node("Malla") as MeshInstance3D
		assert_object(malla.get_surface_override_material(0)).is_not_null()
		var material := _material(caja)
		etiqueta_retenida = material
		var identidad := material.get_instance_id()
		var textura := material.albedo_texture.resource_path
		assert_str(textura).is_equal(_ruta_de_la_etiqueta(Producto.Id.ACTRONCITO))
		materiales.append(identidad)
		fuente = malla.mesh
		material_generico = fuente.surface_get_material(0) as BaseMaterial3D
		generica = (fuente.surface_get_material(0) as BaseMaterial3D).albedo_texture.resource_path
		material = null
		caja.reparent(destino, true)
		assert_object(caja.get_parent()).is_same(destino)
		assert_int(_material(caja).get_instance_id()).is_equal(identidad)
		assert_str(_material(caja).albedo_texture.resource_path).is_equal(textura)
		assert_int(caja.get("producto")).is_equal(Producto.Id.ACTRONCITO)
		assert_object(caja.get("datos")).is_same(datos)
	assert_int(materiales[0]).is_not_equal(materiales[1])
	assert_object((cajas[0].get_node("Malla") as MeshInstance3D).mesh).is_same(fuente)
	var destruir := func() -> void:
		for caja in cajas:
			caja.free()
	await assert_error(destruir).is_success()
	cajas.clear()
	assert_object(fuente.surface_get_material(0)).is_same(material_generico)
	assert_str(etiqueta_retenida.albedo_texture.resource_path).is_equal(
		_ruta_de_la_etiqueta(Producto.Id.ACTRONCITO)
	)
	(
		assert_str((fuente.surface_get_material(0) as BaseMaterial3D).albedo_texture.resource_path)
		. is_equal(generica)
	)
	# La escena nunca montada tampoco debe inventar un error al liberar su malla.
	var sin_montar := load(ESCENA).instantiate() as Node3D
	await assert_error(func() -> void: sin_montar.free()).is_success()


## La señal se fue con el clic izquierdo, y mientras exista el cableado se le puede volver a
## colgar: quedarían dos rutas hacia la misma unidad y ninguna daría rojo.
func test_la_caja_ya_no_despacha_por_su_cuenta() -> void:
	# La señal se fue con el clic izquierdo, y mientras exista el cableado se le puede volver a
	# colgar: quedarían dos rutas hacia la misma unidad y ninguna daría rojo.
	for ruta: String in [SCRIPT, CABLEADO]:
		var texto := FileAccess.get_file_as_string(ruta)
		assert_str(texto).is_not_empty()
		(
			assert_str(texto)
			. override_failure_message("`%s` todavía nombra `producto_pedido`" % ruta)
			. not_contains("producto_pedido")
		)


func test_cada_caja_con_textura_muestra_la_etiqueta_de_su_producto() -> void:
	for id: Producto.Id in ORIGEN_DE_CADA_ETIQUETA:
		var caja := _caja_armada(id)
		(
			assert_str(_material(caja).albedo_texture.resource_path)
			. override_failure_message("la caja de %s no lleva su etiqueta" % _nombre(id))
			. is_equal(_ruta_de_la_etiqueta(id))
		)


func test_las_cajas_sin_textura_siguen_con_la_generica() -> void:
	for id: Producto.Id in SIN_ETIQUETA:
		var caja := _caja_armada(id)
		(
			assert_str(_material(caja).albedo_texture.resource_path)
			. override_failure_message("la caja de %s dejó la genérica" % _nombre(id))
			. is_equal(GENERICA)
		)


## Las dos listas cubren el catálogo, y ningún producto está en las dos. En el cruce del lote
## faltaba Malbardo en las dos: un producto nuevo tiene que decidir qué caja lleva.
func test_cada_producto_tiene_decidida_su_caja() -> void:
	var decididos: Array = ORIGEN_DE_CADA_ETIQUETA.keys() + SIN_ETIQUETA
	assert_int(decididos.size()).is_equal(Producto.Id.size())
	for id: Producto.Id in Producto.Id.values():
		(
			assert_int(decididos.count(id))
			. override_failure_message("%s no está una sola vez en las listas" % _nombre(id))
			. is_equal(1)
		)


## Agregar la etiqueta de un producto es una línea: la tabla del script de la caja. Treinta y
## una sobreescrituras de material en las escenas serían treinta y un lugares para olvidarse.
func test_la_etiqueta_de_cada_producto_es_una_linea_del_script() -> void:
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	for id: Producto.Id in ORIGEN_DE_CADA_ETIQUETA:
		var linea := (
			'Producto.Id.%s: preload("%s"),' % [Producto.Id.keys()[id], _ruta_de_la_etiqueta(id)]
		)
		(
			assert_int(texto.count(linea))
			. override_failure_message("el script no tiene la línea `%s`" % linea)
			. is_equal(1)
		)
	var cajas := _nombres_de_las_cajas()
	assert_int(cajas.size()).is_equal(ORIGEN_DE_CADA_ETIQUETA.size() + SIN_ETIQUETA.size())
	for ruta: String in ESCENAS_CON_CAJAS + [ESCENA]:
		var escena := FileAccess.get_file_as_string(ruta)
		assert_str(escena).is_not_empty()
		for seccion in _secciones_de_cajas(escena, ruta, cajas):
			(
				assert_str(seccion)
				. override_failure_message("`%s` le pisa el material a una caja" % ruta)
				. not_contains("material_override")
			)


## Las secciones de la escena que declaran una caja o algo adentro de una: la escena de la caja,
## entera, y en las demás los nodos con el nombre de una caja en su camino. El material de lo
## demás del almacén —el agua del balde, la punta de la mopa— no es asunto de las etiquetas.
static func _secciones_de_cajas(
	escena: String, ruta: String, cajas: Array[String]
) -> PackedStringArray:
	var secciones := ("\n" + escena).split("\n[", false)
	if ruta == ESCENA:
		return secciones
	var de_cajas := PackedStringArray()
	for seccion in secciones:
		var cabecera := seccion.get_slice("\n", 0)
		if not cabecera.begins_with("node "):
			continue
		var camino := cabecera.get_slice('parent="', 1).get_slice('"', 0).split("/")
		camino.append(cabecera.get_slice('name="', 1).get_slice('"', 0))
		for nombre in camino:
			if nombre in cajas:
				de_cajas.append(seccion)
				break
	return de_cajas


## Los nombres de las cajas, de la lista que el almacén exporta.
static func _nombres_de_las_cajas() -> Array[String]:
	var almacen := FileAccess.get_file_as_string(CAJAS_DEL_ALMACEN)
	var lista := almacen.get_slice("_cajas_de_productos = [", 1).get_slice("]", 0)
	var nombres: Array[String] = []
	for camino in RegEx.create_from_string('NodePath\\("([^"]*)"\\)').search_all(lista):
		nombres.append(camino.get_string(1).get_file())
	return nombres


## Filtra pixelado como el resto del arte: el material es el de la caja genérica con otra
## textura, y la textura se importa con los mismos parámetros que la de la genérica, comprimida
## y con mipmaps. El mismo material es también el mismo shader: en la web un shader nuevo se
## compila en la pantalla de carga.
##
## **El lado tope es el único parámetro que cambia**, y no pasa el de la genérica. Las etiquetas
## viajan a 512 como las de la góndola. Medido: a 1024 el `.pck` de la web crecía 12,7 MiB, a 512
## crece 3,2, y la caja en la mano se ve igual.
##
## Y no va como `material_override`: el calentamiento de shaders dibuja uno por cuadro, y con
## las 31 cajas pasaba de 129 cuadros a 159 sin compilar nada nuevo.
func test_la_etiqueta_filtra_pixelado_como_la_caja_generica() -> void:
	var generica := ConfigFile.new()
	assert_int(generica.load(GENERICA + ".import")).is_equal(OK)
	var gondola: Texture2D = load(ETIQUETA_DE_LA_GONDOLA)
	var lado_de_la_gondola := maxi(gondola.get_width(), gondola.get_height())
	assert_int(lado_de_la_gondola).is_less(generica.get_value("params", LADO_TOPE))
	for id: Producto.Id in ORIGEN_DE_CADA_ETIQUETA:
		var caja := _caja_armada(id)
		var material := _material(caja)
		(
			assert_object((caja.get_node("Malla") as MeshInstance3D).material_override)
			. override_failure_message("%s suma un cuadro al calentamiento" % _nombre(id))
			. is_null()
		)
		(
			assert_int(material.texture_filter)
			. override_failure_message("la etiqueta de %s no filtra pixelado" % _nombre(id))
			. is_equal(BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS)
		)
		var propio := (caja.get_node("Malla") as MeshInstance3D).mesh.surface_get_material(0)
		for propiedad: Dictionary in propio.get_property_list():
			var nombre: String = propiedad["name"]
			var uso: int = propiedad["usage"]
			var propia_de_la_copia := nombre == "albedo_texture" or nombre.begins_with("resource_")
			if uso & PROPERTY_USAGE_STORAGE == 0 or propia_de_la_copia:
				continue
			(
				assert_that(material.get(nombre))
				. override_failure_message("%s cambia `%s`" % [_nombre(id), nombre])
				. is_equal(propio.get(nombre))
			)
		var suya := ConfigFile.new()
		assert_int(suya.load(_ruta_de_la_etiqueta(id) + ".import")).is_equal(OK)
		for clave: String in generica.get_section_keys("params"):
			if clave == LADO_TOPE:
				continue
			(
				assert_that(suya.get_value("params", clave))
				. override_failure_message("%s importa `%s` distinto" % [_nombre(id), clave])
				. is_equal(generica.get_value("params", clave))
			)
		# Un lado tope en cero es sin tope: Godot importa la textura entera, de 2084 px. Y quedar
		# por debajo de la genérica no alcanza: a 1024 el `.pck` crece 12,7 MiB.
		(
			assert_int(suya.get_value("params", LADO_TOPE))
			. override_failure_message(
				"%s no viaja con el lado de las etiquetas de la góndola" % _nombre(id)
			)
			. is_equal(lado_de_la_gondola)
		)


## La copia es la textura del artista byte por byte: con otro nombre y nada más. Si el artista
## cambia la suya, esto da rojo hasta que se vuelva a copiar.
func test_cada_etiqueta_es_la_copia_de_la_textura_del_artista() -> void:
	for id: Producto.Id in ORIGEN_DE_CADA_ETIQUETA:
		var origen := FileAccess.get_file_as_bytes(ORIGEN + ORIGEN_DE_CADA_ETIQUETA[id])
		var copia := FileAccess.get_file_as_bytes(_ruta_de_la_etiqueta(id))
		assert_int(origen.size()).is_greater(0)
		(
			assert_bool(copia == origen)
			. override_failure_message("la etiqueta de %s no es su copia" % _nombre(id))
			. is_true()
		)


## `ACTRÓNCITO`, `MANÍ` y `LAYSNT´T` se escriben distinto en cada sistema de archivos: «Ó» es un
## carácter o dos, según quién lo escribió. Una ruta en ASCII resuelve igual en Windows, en la CI
## de Linux y en la web.
func test_las_etiquetas_tienen_nombres_en_ascii() -> void:
	var ascii := RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z]+)+$")
	var archivos := DirAccess.get_files_at(ETIQUETAS)
	assert_int(archivos.size()).is_greater(0)
	for archivo: String in archivos:
		(
			assert_object(ascii.search(archivo))
			. override_failure_message("`%s` no es un nombre en ASCII" % archivo)
			. is_not_null()
		)


## La caja chica y la grande son la misma malla escalada parejo. Cada cara muestra un cuadrado de
## la textura sobre un cuadrado de la caja: la etiqueta no se estira en ninguno de los dos tamaños.
func test_la_etiqueta_no_se_estira_en_la_caja_chica_ni_en_la_grande() -> void:
	var tamanos_vistos: Array[Catalogo.TamanoDeCaja] = []
	for id: Producto.Id in _una_etiqueta_de_cada_tamano():
		var caja := _caja_armada(id)
		var malla := caja.get_node("Malla") as MeshInstance3D
		var textura := _material(caja).albedo_texture
		assert_int(textura.get_width()).is_equal(textura.get_height())
		for estiramiento: float in _estiramiento_de_cada_triangulo(malla):
			(
				assert_float(estiramiento)
				. override_failure_message("la etiqueta de %s se estira" % _nombre(id))
				. is_equal_approx(1.0, 0.01)
			)
		tamanos_vistos.append(Catalogo.caja_de(id))
	assert_array(tamanos_vistos).contains_exactly_in_any_order(
		[Catalogo.TamanoDeCaja.CHICA, Catalogo.TamanoDeCaja.GRANDE]
	)


func _caja() -> CajaQueSeLleva:
	return auto_free(load(ESCENA).instantiate())


## Con `_ready()` corrido: el tamaño y la etiqueta los arma ahí.
func _caja_armada(id: Producto.Id) -> CajaQueSeLleva:
	var caja := _caja()
	caja.producto = id
	add_child(caja)
	return caja


func _material(caja: Node) -> BaseMaterial3D:
	return (caja.get_node("Malla") as MeshInstance3D).get_active_material(0) as BaseMaterial3D


func _nombre(id: Producto.Id) -> String:
	return Catalogo.de(id).nombre


## La copia lleva el nombre del `Producto.Id` en minúsculas, igual que las miniaturas de la
## computadora.
func _ruta_de_la_etiqueta(id: Producto.Id) -> String:
	return ETIQUETAS + (Producto.Id.keys()[id] as String).to_lower() + ".png"


func _una_etiqueta_de_cada_tamano() -> Array[Producto.Id]:
	var por_tamano := {}
	for id: Producto.Id in ORIGEN_DE_CADA_ETIQUETA:
		por_tamano[Catalogo.caja_de(id)] = id
	var elegidos: Array[Producto.Id] = []
	elegidos.assign(por_tamano.values())
	return elegidos


## Cuánto más mide un texel a lo ancho que a lo alto, en metros de la caja ya escalada. Uno es
## que no se estira: sale de las derivadas de la posición contra el UV de cada triángulo.
func _estiramiento_de_cada_triangulo(malla: MeshInstance3D) -> Array[float]:
	var arrays := malla.mesh.surface_get_arrays(0)
	var posiciones: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base := malla.global_transform.basis
	var estiramientos: Array[float] = []
	for t: int in range(0, indices.size(), 3):
		var i0 := indices[t]
		var lado_1 := base * (posiciones[indices[t + 1]] - posiciones[i0])
		var lado_2 := base * (posiciones[indices[t + 2]] - posiciones[i0])
		var uv_1 := uvs[indices[t + 1]] - uvs[i0]
		var uv_2 := uvs[indices[t + 2]] - uvs[i0]
		var det := uv_1.x * uv_2.y - uv_2.x * uv_1.y
		var por_u := (lado_1 * uv_2.y - lado_2 * uv_1.y) / det
		var por_v := (lado_2 * uv_1.x - lado_1 * uv_2.x) / det
		estiramientos.append(por_u.length() / por_v.length())
	return estiramientos

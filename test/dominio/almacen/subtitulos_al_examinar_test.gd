## Lo que dice cada cosa del local cuando se la examina: las tablas de la ficha, letra por letra.
extends GdUnitTestSuite

const DE_LOS_PRODUCTOS := {
	Producto.Id.ZUCARACHAS: "Una caja de cereal Zucarachas.",
	Producto.Id.FROTLUPS: "Una caja de cereal Frot Lups.",
	Producto.Id.CORACOLA: "Una lata de Pura-Cola.",
	Producto.Id.MARRANOS: "Una lata de atún Marranos.",
	Producto.Id.ARVEJAS: "Una lata de arvejas Arvecor.",
	Producto.Id.MAYONCHIS: "Un paquete de Mayonchis.",
	Producto.Id.JORGILLO: "Un alfajor Jorgillo.",
	Producto.Id.MAROLINI: "Una caja de fideos Marolini.",
	Producto.Id.UAKAS: "Una caja de fideos Uakalas.",
	Producto.Id.SALADIK: "Una caja de Saladick.",
	Producto.Id.PEPITOS: "Una caja de galletitas Pepito.",
	Producto.Id.OREMOS: "Una caja de galletitas Oremos.",
	Producto.Id.DONSATURADOS: "Un paquete de Don Saturados.",
	Producto.Id.PETISAS: "Un paquete de galletitas Petisas.",
	Producto.Id.MACUMBAS: "Un paquete de galletitas Macumbas.",
	Producto.Id.PRONGLES: "Un tubo de papitas Progres.",
	Producto.Id.LAYSNTT: "Un paquete de papitas Laysnnt.",
	Producto.Id.CHISITOS: "Un paquete de Chisitos.",
	Producto.Id.DUREXTRA: "Una caja de preservativos Durextra.",
	Producto.Id.DURONGA: "Una caja de preservativos Duronga.",
	Producto.Id.ACTRONCITO: "Una caja de medicamentos Actroncito.",
	Producto.Id.BURBALOO: "Una caja de chicles Burbaloo.",
	Producto.Id.FLINPUF: "Una caja de caramelos Flim Pof.",
	Producto.Id.MALBARDO: "Un paquete de cigarrillos Malbardo.",
	Producto.Id.AMARGADITO: "Una caja de yerba Amargadito.",
	Producto.Id.CINDOLOR: "Una caja de chocolatada Cindolor.",
	Producto.Id.COSA_DE_MANI: "Una barra de Cosa de Maní.",
	Producto.Id.FEEL_RICKY_FORT: "Una caja de barritas Feel Ricky Fort.",
	Producto.Id.FERNET_GOD: "Una botella de Fernet God.",
	Producto.Id.OAAAA: "Una caja de jugo Oaaaa.",
	Producto.Id.TERMINATOR: "Una caja de vino Terminator.",
	Producto.Id.POETICO: "Una botella de Poético.",
}

const DE_LOS_UTILES := {
	"res://src/dominio/almacen/mopa.tres": "Una mopa para limpiar las manchas del local.",
	"res://src/dominio/almacen/balde.tres": "Un balde para hacer las mezclas con los jabones.",
	"res://src/dominio/almacen/jabon_azul.tres":
	"Un bidón de jabón azul, marca “2”. Sirve para manchas de humedad.",
	"res://src/dominio/almacen/jabon_rosa.tres":
	"Un bidón de jabón rosa, marca “H”. Sirve para manchas de... para manchas marrones.",
	"res://src/dominio/almacen/jabon_amarillo.tres":
	"Un bidón de jabón amarillo, marca “O”. Sirve para manchas de polvo.",
	"res://src/dominio/almacen/bolsa_de_basura_1.tres": "Una bolsa de basura.",
	"res://src/dominio/almacen/bolsa_de_basura_2.tres": "Una bolsa de basura.",
	"res://src/dominio/almacen/bolsa_de_basura_3.tres": "Una bolsa de basura.",
}


func _de_lo_fijo() -> Dictionary:
	return {
		SubtitulosAlExaminar.INODORO:
		"Un inodoro. Enrique me pidió encarecidamente que no tire papel en él, porque se tapa.",
		SubtitulosAlExaminar.LAVATORIO: "Un lavatorio. Acá puedo cargar el balde.",
		SubtitulosAlExaminar.id_de_la_nota(NotaPegada.Id.JABONES_Y_MANCHAS):
		"Una nota explicando qué jabón usar para cada tipo de mancha.",
		SubtitulosAlExaminar.id_de_la_nota(NotaPegada.Id.INSTRUCCIONES_DE_LIMPIEZA):
		"Una nota que explica cómo usar los elementos de limpieza.",
		SubtitulosAlExaminar.id_de_la_nota(NotaPegada.Id.NO_TIRAR_PAPEL):
		"“Por favor, no tirar papel en el inodoro”",
		SubtitulosAlExaminar.id_de_la_nota(NotaPegada.Id.TAREAS_A_REALIZAR):
		"Una lista de las tareas que me dejó Enrique.",
		SubtitulosAlExaminar.id_de_la_nota(NotaPegada.Id.LOCAL_ORDENADO):
		"Una nota sobre el correcto orden del local. Enrique es medio insoportable con eso…",
		SubtitulosAlExaminar.COMPUTADORA:
		"Una computadora viejita. El único programa que tiene es el registro de productos vendidos.",
		SubtitulosAlExaminar.CAJA_REGISTRADORA:
		"La caja registradora. Acá puedo hacer los tickets para los compradores.",
		SubtitulosAlExaminar.LECTOR:
		(
			"El lector de código de barras. Si le paso un producto, lo va a anotar en el programa"
			+ " generador de tickets de la caja."
		),
		SubtitulosAlExaminar.ENTRADA_PRINCIPAL:
		"La entrada principal al local. Queda cerrada con llave durante el turno nocturno.",
		SubtitulosAlExaminar.PUERTA_DEL_JEFE:
		"Esta puerta lleva a la “oficina” de Enrique. Así le dice él. Siempre está cerrada.",
		SubtitulosAlExaminar.PORTON: "Un portón que da a la calle.",
		SubtitulosAlExaminar.CONTENEDOR: "Un contenedor de basura.",
		SubtitulosAlExaminar.id_del_tacho(TareaDeLaBasura.Tacho.LOCAL):
		"Un tacho de basura para los compradores diurnos.",
		SubtitulosAlExaminar.id_del_tacho(TareaDeLaBasura.Tacho.ESCRITORIO):
		"Un tachito de basura para nosotros, los empleados.",
		SubtitulosAlExaminar.id_del_tacho(TareaDeLaBasura.Tacho.BANO):
		"El tacho de basura del baño. Mejor ni mirar lo que tiene adentro.",
	}


func test_cada_producto_del_catalogo_dice_su_texto() -> void:  # AC-SUB-011
	assert_int(Producto.Id.size()).is_equal(DE_LOS_PRODUCTOS.size())
	for id: Producto.Id in Producto.Id.values():
		var nombre: String = Producto.Id.find_key(id)
		var texto := SubtitulosAlExaminar.de_producto(id)
		assert_str(texto).override_failure_message("%s no tiene texto" % nombre).is_not_empty()
		assert_str(texto).override_failure_message("%s dice «%s»" % [nombre, texto]).is_equal(
			DE_LOS_PRODUCTOS.get(id, "")
		)


func test_cada_unidad_dice_el_texto_de_su_producto() -> void:  # AC-SUB-011
	for producto: Producto in Catalogo.todos():
		var unidad := UnidadDeProducto.new(producto)
		assert_str(unidad.texto_al_examinar()).is_equal(DE_LOS_PRODUCTOS[producto.id])


func test_cada_util_y_cada_bolsa_dicen_su_texto() -> void:  # AC-SUB-012
	for ruta: String in DE_LOS_UTILES:
		var objeto := load(ruta) as ObjetoDelAlmacen
		assert_object(objeto).override_failure_message("%s no carga" % ruta).is_not_null()
		(
			assert_str(objeto.texto_al_examinar())
			. override_failure_message("%s dice «%s»" % [ruta, objeto.texto_al_examinar()])
			. is_equal(DE_LOS_UTILES[ruta])
		)


func test_cada_cosa_fija_dice_su_texto() -> void:  # AC-SUB-013
	var tabla := _de_lo_fijo()
	assert_int(tabla.size()).is_equal(17)
	for id: StringName in tabla:
		(
			assert_str(SubtitulosAlExaminar.de_lo_fijo(id))
			. override_failure_message("«%s» no dice su texto" % id)
			. is_equal(tabla[id])
		)


func test_lo_que_no_esta_en_la_tabla_no_dice_nada() -> void:  # AC-SUB-013
	for id: StringName in [&"", &"ventanilla", &"puerta_de_heladera", &"gondola", &"mancha"]:
		assert_str(SubtitulosAlExaminar.de_lo_fijo(id)).is_empty()


func test_el_texto_no_es_la_revelacion() -> void:  # AC-SUB-010
	var mopa := load("res://src/dominio/almacen/mopa.tres") as ObjetoDelAlmacen
	assert_bool(mopa.tiene_revelacion()).is_true()
	assert_str(mopa.texto_al_examinar()).not_contains(mopa.revelacion.texto)
	assert_str(mopa.texto_al_examinar()).is_equal("Una mopa para limpiar las manchas del local.")

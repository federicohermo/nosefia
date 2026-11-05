extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")


func _vista_previa_con(texto: String) -> Label:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	var mensaje := Mensaje.new()
	mensaje.texto = texto
	var chat := Conversacion.new()
	chat.nombre = "Contacto"
	chat.mensajes = [mensaje]
	var bandeja := Bandeja.new([chat])
	pantalla.mostrar_menu(bandeja)
	var lista: VBoxContainer = pantalla.get("_mensajes")
	return lista.get_child(0).find_child("VistaPrevia", true, false) as Label


func test_la_vista_previa_no_muestra_las_marcas_de_negrita() -> void:
	var etiqueta := _vista_previa_con("Llegó [b]la caja[/b] de hoy")
	assert_str(etiqueta.text).not_contains("[b]")
	assert_str(etiqueta.text).not_contains("[/b]")
	assert_str(etiqueta.text).contains("la caja")


func test_la_vista_previa_no_muestra_otras_marcas_de_bbcode() -> void:
	var etiqueta := _vista_previa_con("Mirá [color=#ff0000]esto[/color] y [url=x]aquello[/url]")
	assert_str(etiqueta.text).not_contains("[")
	assert_str(etiqueta.text).not_contains("]")
	assert_str(etiqueta.text).contains("esto")
	assert_str(etiqueta.text).contains("aquello")


func test_un_mensaje_solo_con_foto_muestra_el_rotulo_de_la_foto() -> void:
	var etiqueta := _vista_previa_con("")
	assert_str(etiqueta.text).is_equal(PantallaDelCelular.FOTO)

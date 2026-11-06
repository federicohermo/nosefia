extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")
const RETRATO_ENRIQUE := preload("res://assets/ui/manada/enrique.png")


func _pantalla() -> PantallaDelCelular:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	return pantalla


func _contacto(nombre: String, imagen: Texture2D) -> Conversacion:
	var contacto := Conversacion.new()
	contacto.nombre = nombre
	contacto.imagen = imagen
	return contacto


func test_el_encabezado_de_enrique_va_sin_mascara_y_el_de_otro_contacto_con_ella() -> void:
	var pantalla := _pantalla()
	var avatar: TextureRect = pantalla.get("_avatar_del_chat")
	var mensajes: Array[Mensaje] = []
	pantalla.mostrar_chat(_contacto("Otro", null), mensajes, false, 1)
	assert_object(avatar.material).is_same(PantallaDelCelular.MASCARA_DEL_AVATAR)
	pantalla.mostrar_chat(_contacto("Enrique", RETRATO_ENRIQUE), mensajes, false, 1)
	assert_object(avatar.texture).is_same(PantallaDelCelular.AVATAR_ENRIQUE)
	assert_object(avatar.material).is_null()

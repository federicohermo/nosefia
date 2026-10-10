extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/capa_de_dialogo.tscn")


func test_cada_entrada_reemplaza_la_anterior_y_cerrar_vacia_la_linea() -> void:
	var capa: CapaDeDialogo = auto_free(ESCENA.instantiate())
	add_child(capa)
	assert_bool(capa.visible).is_false()
	capa.mostrar("Primera entrada.")
	capa.mostrar("Segunda entrada.")
	var entrada: RichTextLabel = capa.get("_entrada")
	assert_str(entrada.text).is_equal("Segunda entrada.")
	assert_bool(capa.visible).is_true()
	capa.ocultar()
	assert_str(entrada.text).is_empty()
	assert_bool(capa.visible).is_false()


func test_el_locutor_cableado_muestra_entradas_y_oculta_al_final() -> void:
	var locutor: Locutor = auto_free(Locutor.new())
	var capa: CapaDeDialogo = auto_free(ESCENA.instantiate())
	capa.locutor = locutor
	add_child(capa)
	locutor.abrir(Dialogo.new(PackedStringArray(["Primera", "Segunda"])))
	var entrada: RichTextLabel = capa.get("_entrada")
	assert_str(entrada.text).is_equal("Primera")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	locutor.recibir(click)
	assert_str(entrada.text).is_equal("Segunda")
	locutor.recibir(click)
	assert_str(entrada.text).is_empty()
	assert_bool(capa.visible).is_false()

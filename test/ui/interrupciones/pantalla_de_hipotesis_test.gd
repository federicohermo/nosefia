extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_hipotesis.tscn"
const COMILLAS := "“¿Quién?” y «cuándo»"


func _reflexion(pistas: Array[String]) -> ReflexionDeCierre:
	var expediente := Expediente.new(CasoDeInvestigacion.de_la_partida())
	for pista: String in pistas:
		expediente.registrar(pista)
	var reflexion := ReflexionDeCierre.para(4, expediente)
	reflexion.empezar()
	return reflexion


func _pantalla() -> PantallaDeHipotesis:
	var pantalla: PantallaDeHipotesis = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	return pantalla


func _titulo(pantalla: PantallaDeHipotesis) -> String:
	return (pantalla.find_child("Titulo", true, false) as Label).text


func test_titulo_y_texto_se_muestran_tal_cual_vienen_en_los_datos() -> void:
	var pantalla := _pantalla()
	var reflexion := _reflexion(["2A", "2B"])
	for _opcion: int in reflexion.opciones().size():
		var opcion := reflexion.mostrada()
		pantalla.mostrar(reflexion)
		assert_str(_titulo(pantalla)).is_equal(opcion.titulo)
		assert_str(pantalla.texto()).is_equal(opcion.texto)
		reflexion.siguiente()


func test_las_comillas_del_dato_se_muestran() -> void:
	var pantalla := _pantalla()
	var reflexion := _reflexion(["2A"])
	var opcion := reflexion.mostrada()
	var titulo := opcion.titulo
	var texto := opcion.texto
	opcion.titulo = COMILLAS
	opcion.texto = COMILLAS
	pantalla.mostrar(reflexion)
	var mostrado_titulo := _titulo(pantalla)
	var mostrado_texto := pantalla.texto()
	opcion.titulo = titulo
	opcion.texto = texto
	assert_str(mostrado_titulo).is_equal(COMILLAS)
	assert_str(mostrado_texto).is_equal(COMILLAS)

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


func _fondo(control: Control) -> float:
	return control.position.y + control.size.y


func _botones(pantalla: PantallaDeHipotesis) -> Array[Control]:
	var botones: Array[Control] = []
	for nombre: String in ["Anterior", "Siguiente", "Accion"]:
		botones.append(pantalla.find_child(nombre, true, false) as Control)
	return botones


func test_el_texto_de_cada_hipotesis_del_caso_entra_en_el_marco_con_su_letra() -> void:
	var pantalla := _pantalla()
	var reflexion := _reflexion(["2A"])
	var opcion := reflexion.mostrada()
	var titulo := opcion.titulo
	var texto := opcion.texto
	var marco := pantalla.find_child("Marco", true, false) as Control
	var etiqueta := pantalla.find_child("Texto", true, false) as Label
	var pantalla_de_alto := LienzoDeManada.TAMANO_DEL_DISENO.y
	var fallas: Array[String] = []
	for opciones: HipotesisDeLaJornada in CasoDeInvestigacion.de_la_partida().hipotesis:
		var candidatas: Array[Hipotesis] = opciones.opciones.duplicate()
		for extra: Hipotesis in [opciones.predeterminada, opciones.con_antecedentes]:
			if extra != null:
				candidatas.append(extra)
		for candidata: Hipotesis in candidatas:
			opcion.titulo = candidata.titulo
			opcion.texto = candidata.texto
			pantalla.mostrar(reflexion)
			await await_idle_frame()
			if etiqueta.get_theme_font_size("font_size") != PantallaDeHipotesis.TAMANO_DEL_TEXTO:
				fallas.append("%s: la letra cambió" % candidata.identidad)
			if etiqueta.position.y + etiqueta.get_minimum_size().y > _fondo(marco):
				fallas.append("%s: el texto desborda el marco" % candidata.identidad)
			for boton: Control in _botones(pantalla):
				if boton.position.y < _fondo(marco) or _fondo(boton) > pantalla_de_alto:
					fallas.append("%s: %s fuera de lugar" % [candidata.identidad, boton.name])
	opcion.titulo = titulo
	opcion.texto = texto
	assert_array(fallas).is_empty()


func test_un_texto_largo_estira_la_tarjeta_hacia_abajo_y_uno_corto_la_deja_como_estaba() -> void:
	var pantalla := _pantalla()
	var reflexion := _reflexion(["2A"])
	var opcion := reflexion.mostrada()
	var texto := opcion.texto
	var marco := pantalla.find_child("Marco", true, false) as Control
	var titulo := pantalla.find_child("Titulo", true, false) as Control
	var etiqueta := pantalla.find_child("Texto", true, false) as Label
	opcion.texto = "Corto."
	pantalla.mostrar(reflexion)
	var arriba := marco.position.y
	var ancho := marco.size.x
	var alto_corto := marco.size.y
	var titulo_corto := titulo.position
	var letra_corta := etiqueta.get_theme_font_size("font_size")
	var distancias: Array[float] = []
	for boton: Control in _botones(pantalla):
		distancias.append(boton.position.y - _fondo(marco))
	opcion.texto = "Un renglón largo que no entra. ".repeat(40)
	pantalla.mostrar(reflexion)
	var alto_largo := marco.size.y
	var distancias_largo: Array[float] = []
	for boton: Control in _botones(pantalla):
		distancias_largo.append(boton.position.y - _fondo(marco))
	opcion.texto = "Corto."
	pantalla.mostrar(reflexion)
	opcion.texto = texto
	assert_float(alto_largo).is_greater(alto_corto)
	assert_float(marco.position.y).is_equal(arriba)
	assert_float(marco.size.x).is_equal(ancho)
	assert_vector(titulo.position).is_equal(titulo_corto)
	assert_int(etiqueta.get_theme_font_size("font_size")).is_equal(letra_corta)
	assert_array(distancias_largo).is_equal(distancias)
	assert_float(marco.size.y).is_equal(alto_corto)


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


func test_el_foco_de_la_hipotesis_queda_puesto_y_no_se_dibuja() -> void:  # AC-CFG-028
	var pantalla := _pantalla()
	pantalla.mostrar(_reflexion(["2A", "2B"]))
	var foco := pantalla.get_viewport().gui_get_focus_owner()
	assert_object(foco).is_not_null()
	assert_bool(foco != null and pantalla.is_ancestor_of(foco) and foco.has_focus()).is_true()
	assert_bool(foco != null and foco.has_focus(true)).is_false()

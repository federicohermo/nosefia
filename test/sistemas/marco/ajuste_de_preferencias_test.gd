## Aplicar las preferencias al motor: el volumen de los buses, el brillo y la letra de la interfaz.
##
## El volumen de los buses y el tema son de todo el proceso: cada caso los deja en su defecto al
## terminar, o la suite siguiente arranca con otro volumen y otra letra.
extends GdUnitTestSuite

const C := Preferencias.Campo
const TEMA := preload("res://assets/ui/manada/tema.tres")
const BUSES_DE_EFECTOS: Array[String] = [
	EntradaSonora.BUS_DE_AMBIENTE, EntradaSonora.BUS_DE_EFECTOS, EntradaSonora.BUS_DE_INTERFAZ
]

var _ajuste: AjusteDePreferencias


func before_test() -> void:
	_ajuste = auto_free(AjusteDePreferencias.new())
	add_child(_ajuste)


func after_test() -> void:
	_ajuste.aplicar(Preferencias.new())


func _con(campo: Preferencias.Campo, valor: float) -> Preferencias:
	var preferencias := Preferencias.new()
	preferencias.poner(campo, valor)
	return preferencias


func _db(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func _mudo(bus: String) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))


func _con_tema() -> Control:
	var control: Control = auto_free(Control.new())
	control.theme = TEMA
	add_child(control)
	return control


func test_en_su_defecto_los_cuatro_buses_suenan_como_hoy() -> void:  # AC-CFG-005
	_ajuste.aplicar(Preferencias.new())
	for bus: String in EntradaSonora.BUSES:
		assert_int(AudioServer.get_bus_index(bus)).is_greater_equal(0)
		assert_float(_db(bus)).is_equal_approx(0.0, 1e-4)
		assert_bool(_mudo(bus)).is_false()


func test_efectos_en_cero_calla_tres_buses_y_deja_la_musica() -> void:  # AC-CFG-005
	_ajuste.aplicar(_con(C.EFECTOS, 0.0))
	for bus: String in BUSES_DE_EFECTOS:
		assert_bool(_mudo(bus)).is_true()
	assert_bool(_mudo(EntradaSonora.BUS_DE_MUSICA)).is_false()
	assert_float(_db(EntradaSonora.BUS_DE_MUSICA)).is_equal_approx(0.0, 1e-4)


func test_musica_en_cero_calla_la_musica_y_deja_los_otros_tres() -> void:  # AC-CFG-005
	_ajuste.aplicar(_con(C.MUSICA, 0.0))
	assert_bool(_mudo(EntradaSonora.BUS_DE_MUSICA)).is_true()
	for bus: String in BUSES_DE_EFECTOS:
		assert_bool(_mudo(bus)).is_false()
		assert_float(_db(bus)).is_equal_approx(0.0, 1e-4)


func test_efectos_a_la_mitad_baja_los_tres_buses_seis_decibelios() -> void:  # AC-CFG-005
	_ajuste.aplicar(_con(C.EFECTOS, 50.0))
	for bus: String in BUSES_DE_EFECTOS:
		assert_float(_db(bus)).is_equal_approx(-6.0206, 1e-3)
	_ajuste.aplicar(_con(C.EFECTOS, 10.0))
	for bus: String in BUSES_DE_EFECTOS:
		assert_float(_db(bus)).is_equal_approx(-20.0, 1e-3)
	assert_float(_db(EntradaSonora.BUS_DE_MUSICA)).is_equal_approx(0.0, 1e-4)


func test_el_brillo_multiplica_la_interfaz_y_no_toca_lo_demas() -> void:  # AC-CFG-007
	var interfaz := _con_tema()
	interfaz.modulate.a = 0.4
	var sin_tema: Control = auto_free(Control.new())
	add_child(sin_tema)
	var del_local: Sprite3D = auto_free(Sprite3D.new())
	add_child(del_local)
	for brillo: float in [50.0, 150.0, 100.0]:
		_ajuste.aplicar(_con(C.BRILLO, brillo))
		var factor := brillo / 100.0
		assert_float(interfaz.modulate.r).is_equal_approx(factor, 1e-5)
		assert_float(interfaz.modulate.g).is_equal_approx(factor, 1e-5)
		assert_float(interfaz.modulate.b).is_equal_approx(factor, 1e-5)
		# La transparencia es de quien funde la pantalla, no del brillo.
		assert_float(interfaz.modulate.a).is_equal_approx(0.4, 1e-5)
		assert_that(sin_tema.modulate).is_equal(Color.WHITE)
		assert_that(del_local.modulate).is_equal(Color.WHITE)


func test_lo_que_aparece_despues_tambien_toma_el_brillo() -> void:  # AC-CFG-007
	_ajuste.aplicar(_con(C.BRILLO, 50.0))
	var interfaz := _con_tema()
	assert_float(interfaz.modulate.r).is_equal_approx(0.5, 1e-5)


func test_la_letra_propia_de_un_control_tambien_se_escala_sin_acumular() -> void:  # AC-CFG-008
	var raiz := _con_tema()
	var etiqueta: Label = auto_free(Label.new())
	etiqueta.add_theme_font_size_override("font_size", 44)
	raiz.add_child(etiqueta)
	for escala: float in [1.5, 0.8, 1.0]:
		_ajuste.aplicar(_con(C.TEXTOS, escala))
		assert_int(etiqueta.get_theme_font_size("font_size")).is_equal(roundi(44 * escala))


func test_el_texto_creado_despues_y_sus_cambios_toman_la_escala() -> void:  # AC-CFG-008
	var raiz := _con_tema()
	_ajuste.aplicar(_con(C.TEXTOS, 1.5))
	var etiqueta: RichTextLabel = auto_free(RichTextLabel.new())
	etiqueta.add_theme_font_size_override("normal_font_size", 26)
	etiqueta.add_theme_font_size_override("bold_font_size", 26)
	raiz.add_child(etiqueta)
	await get_tree().process_frame
	assert_int(etiqueta.get_theme_font_size("normal_font_size")).is_equal(39)
	assert_int(etiqueta.get_theme_font_size("bold_font_size")).is_equal(39)
	etiqueta.add_theme_font_size_override("normal_font_size", 30)
	await get_tree().process_frame
	assert_int(etiqueta.get_theme_font_size("normal_font_size")).is_equal(45)
	_ajuste.aplicar(_con(C.TEXTOS, 1.0))
	assert_int(etiqueta.get_theme_font_size("normal_font_size")).is_equal(30)


func test_la_escala_de_textos_multiplica_los_tamanos_de_hoy() -> void:  # AC-CFG-008
	assert_int(TEMA.get_default_font_size()).is_equal(40)
	_ajuste.aplicar(_con(C.TEXTOS, 1.5))
	assert_int(TEMA.get_default_font_size()).is_equal(60)
	_ajuste.aplicar(_con(C.TEXTOS, 0.8))
	assert_int(TEMA.get_default_font_size()).is_equal(32)
	_ajuste.aplicar(_con(C.TEXTOS, 1.0))
	assert_int(TEMA.get_default_font_size()).is_equal(40)


func test_volver_a_uno_deja_cada_tamano_como_antes_de_tocar_la_barra() -> void:  # AC-CFG-008
	var antes := {}
	for tipo: StringName in TEMA.get_font_size_type_list():
		for nombre: StringName in TEMA.get_font_size_list(tipo):
			antes["%s/%s" % [tipo, nombre]] = TEMA.get_font_size(nombre, tipo)
	assert_dict(antes).is_not_empty()
	_ajuste.aplicar(_con(C.TEXTOS, 1.5))
	assert_int(TEMA.get_font_size(&"font_size", &"Titulo")).is_equal(81)
	_ajuste.aplicar(_con(C.TEXTOS, 0.8))
	_ajuste.aplicar(_con(C.TEXTOS, 1.0))
	for clave: String in antes:
		var partes := clave.split("/")
		assert_int(TEMA.get_font_size(partes[1], partes[0])).is_equal(antes[clave])
	assert_int(TEMA.get_default_font_size()).is_equal(40)


func test_cambiar_aplica_y_escribe_en_el_momento() -> void:  # AC-CFG-012
	_ajuste.archivo.ruta = create_temp_dir("ajuste").path_join("preferencias.datos")
	assert_bool(_ajuste.cambiar(_con(C.BRILLO, 110.0))).is_true()
	assert_float(_ajuste.archivo.cargar().valor(C.BRILLO)).is_equal_approx(110.0, 1e-6)
	assert_float(_ajuste.actuales().valor(C.BRILLO)).is_equal_approx(110.0, 1e-6)


func test_al_abrir_aplica_lo_guardado() -> void:  # AC-CFG-013
	_ajuste.archivo.ruta = create_temp_dir("ajuste").path_join("preferencias.datos")
	_ajuste.archivo.escribir(_con(C.MUSICA, 0.0))
	var leidas := _ajuste.cargar_y_aplicar()
	assert_float(leidas.valor(C.MUSICA)).is_zero()
	assert_bool(_mudo(EntradaSonora.BUS_DE_MUSICA)).is_true()

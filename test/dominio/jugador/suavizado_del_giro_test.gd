## Cuánto del mouse falta dibujar: cada reporte se muestra parejo a lo largo de una ventana.
extends GdUnitTestSuite

const VENTANA := 0.02


func test_sin_mouse_no_falta_dibujar_nada() -> void:
	var suavizado := SuavizadoDelGiro.new(VENTANA)
	suavizado.avanzar(VENTANA / 2.0)
	assert_vector(suavizado.pendiente()).is_equal(Vector2.ZERO)


func test_un_reporte_recien_llegado_falta_dibujarlo_entero() -> void:
	var suavizado := SuavizadoDelGiro.new(VENTANA)
	suavizado.agregar(Vector2(10.0, -4.0))
	assert_vector(suavizado.pendiente()).is_equal(Vector2(10.0, -4.0))


func test_un_reporte_se_dibuja_parejo_a_lo_largo_de_la_ventana() -> void:
	var suavizado := SuavizadoDelGiro.new(VENTANA)
	suavizado.agregar(Vector2(10.0, -4.0))
	suavizado.avanzar(VENTANA / 4.0)
	assert_vector(suavizado.pendiente()).is_equal_approx(Vector2(7.5, -3.0), Vector2.ONE * 1e-5)


func test_pasada_la_ventana_el_reporte_ya_se_dibujo_entero() -> void:
	# Un cuadro largo no puede dibujar de más: lo que falta nunca cruza el cero.
	var suavizado := SuavizadoDelGiro.new(VENTANA)
	suavizado.agregar(Vector2(10.0, -4.0))
	suavizado.avanzar(VENTANA * 3.0)
	assert_vector(suavizado.pendiente()).is_equal(Vector2.ZERO)


func test_dos_reportes_se_reparten_cada_uno_en_su_ventana() -> void:
	var suavizado := SuavizadoDelGiro.new(VENTANA)
	suavizado.agregar(Vector2(8.0, 0.0))
	suavizado.avanzar(VENTANA / 2.0)
	suavizado.agregar(Vector2(8.0, 0.0))
	suavizado.avanzar(VENTANA / 2.0)
	assert_vector(suavizado.pendiente()).is_equal_approx(Vector2(4.0, 0.0), Vector2.ONE * 1e-5)


func test_un_mouse_de_125_hz_se_dibuja_casi_parejo_a_144_cuadros() -> void:
	# Es el caso medido: uno de cada cinco o seis cuadros llegaba sin mouse. Sin suavizar, lo
	# dibujado por cuadro iba de cero a dos veces lo normal.
	var suavizado := SuavizadoDelGiro.new(SuavizadoDelGiro.VENTANA)
	var cuadro := 1.0 / 144.0
	var reporte := 1.0 / 125.0
	var tiempo := 0.0
	var proximo := 0.0
	var dibujados: Array[float] = []
	for indice in 1000:
		var antes := suavizado.pendiente().x
		var llegado := 0.0
		while proximo <= tiempo:
			llegado += 1.0
			proximo += reporte
		suavizado.agregar(Vector2(llegado, 0.0))
		suavizado.avanzar(cuadro)
		tiempo += cuadro
		if indice > 100:
			dibujados.append(antes + llegado - suavizado.pendiente().x)
	var medio := 125.0 / 144.0
	for dibujado in dibujados:
		assert_float(dibujado / medio).is_between(0.8, 1.2)

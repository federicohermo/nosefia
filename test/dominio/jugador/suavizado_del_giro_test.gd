## Cuánto del mouse falta dibujar. Con un mouse tan rápido como la pantalla, nada. Con uno más
## lento, cada reporte se muestra parejo a lo largo de una ventana.
extends GdUnitTestSuite

const VENTANA := 0.02
const CUADRO := 1.0 / 144.0


func test_un_mouse_que_llega_en_cada_cuadro_no_se_atrasa() -> void:
	# Es la demora que se evita: un mouse de 1000 Hz no deja cuadros vacíos y no tiene nada que
	# suavizar.
	var suavizado := SuavizadoDelGiro.new(VENTANA)
	for cuadro in 300:
		suavizado.agregar(Vector2(3.0, 1.0))
		suavizado.avanzar(CUADRO)
		assert_vector(suavizado.pendiente()).is_equal(Vector2.ZERO)


func test_frenar_el_mouse_no_lo_hace_pasar_por_lento() -> void:
	# Los cuadros quietos después de soltar el mouse no son huecos: no llega ningún reporte atrás.
	var suavizado := SuavizadoDelGiro.new(VENTANA)
	for vez in 20:
		for cuadro in 10:
			suavizado.agregar(Vector2(3.0, 0.0))
			suavizado.avanzar(CUADRO)
		for cuadro in 30:
			suavizado.avanzar(CUADRO)
	suavizado.agregar(Vector2(3.0, 0.0))
	suavizado.avanzar(CUADRO)
	assert_vector(suavizado.pendiente()).is_equal(Vector2.ZERO)


func test_un_mouse_de_125_hz_se_dibuja_casi_parejo_a_144_cuadros() -> void:
	# Es el caso medido: uno de cada cinco o seis cuadros llegaba sin movimiento. Sin suavizar, lo
	# dibujado por cuadro iba de cero a dos veces lo normal.
	var suavizado := SuavizadoDelGiro.new(SuavizadoDelGiro.VENTANA)
	var dibujados := _mover_a_125_hz(suavizado, 1000)
	var medio := 125.0 / 144.0
	for dibujado in dibujados.slice(200):
		assert_float(dibujado / medio).is_between(0.8, 1.2)


func test_con_un_mouse_lento_un_reporte_se_dibuja_parejo_en_la_ventana() -> void:
	var suavizado := _lento()
	suavizado.agregar(Vector2(10.0, -4.0))
	assert_vector(suavizado.pendiente()).is_equal(Vector2(10.0, -4.0))
	suavizado.avanzar(VENTANA / 4.0)
	assert_vector(suavizado.pendiente()).is_equal_approx(Vector2(7.5, -3.0), Vector2.ONE * 1e-5)


func test_pasada_la_ventana_el_reporte_ya_se_dibujo_entero() -> void:
	# Un cuadro largo no puede dibujar de más: lo que falta nunca cruza el cero.
	var suavizado := _lento()
	suavizado.agregar(Vector2(10.0, -4.0))
	suavizado.avanzar(VENTANA * 3.0)
	assert_vector(suavizado.pendiente()).is_equal(Vector2.ZERO)


func test_dos_reportes_se_reparten_cada_uno_en_su_ventana() -> void:
	var suavizado := _lento()
	suavizado.agregar(Vector2(8.0, 0.0))
	suavizado.avanzar(VENTANA / 2.0)
	suavizado.agregar(Vector2(8.0, 0.0))
	suavizado.avanzar(VENTANA / 2.0)
	assert_vector(suavizado.pendiente()).is_equal_approx(Vector2(4.0, 0.0), Vector2.ONE * 1e-5)


## Un suavizado que ya vio un mouse de 125 Hz, sin nada pendiente.
func _lento() -> SuavizadoDelGiro:
	var suavizado := SuavizadoDelGiro.new(VENTANA)
	_mover_a_125_hz(suavizado, 300)
	for cuadro in 20:
		suavizado.avanzar(CUADRO)
	return suavizado


## Mueve el mouse parejo a 125 Hz durante `cuadros` cuadros de 144 Hz, y devuelve lo dibujado en
## cada uno.
func _mover_a_125_hz(suavizado: SuavizadoDelGiro, cuadros: int) -> Array[float]:
	var reporte := 1.0 / 125.0
	var tiempo := 0.0
	var proximo := 0.0
	var dibujados: Array[float] = []
	for indice in cuadros:
		var antes := suavizado.pendiente().x
		var llegado := 0.0
		while proximo <= tiempo:
			llegado += 1.0
			proximo += reporte
		suavizado.agregar(Vector2(llegado, 0.0))
		suavizado.avanzar(CUADRO)
		tiempo += CUADRO
		dibujados.append(antes + llegado - suavizado.pendiente().x)
	return dibujados

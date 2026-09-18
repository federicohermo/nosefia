## El cuaderno de notas: qué se anota y qué no llega a ser una nota.
extends GdUnitTestSuite


func test_una_nota_con_titulo_se_escribe_y_se_devuelve() -> void:  # 009-AC4
	var cuaderno := Cuaderno.new()
	var nota := cuaderno.escribir("Puerta del fondo", "Estaba abierta a las 3.")
	assert_object(nota).is_not_null()
	assert_int(cuaderno.cuantas()).is_equal(1)
	assert_object(cuaderno.notas()[0]).is_same(nota)


func test_una_nota_sin_titulo_devuelve_null_y_no_se_guarda() -> void:  # 009-AC4
	# Una nota sin título es un renglón que el jugador no va a poder encontrar después, y
	# guardarla igual llenaría el cuaderno de entradas que no dicen nada.
	var cuaderno := Cuaderno.new()
	assert_object(cuaderno.escribir("", "algo")).is_null()
	assert_object(cuaderno.escribir("   ", "algo")).is_null()
	assert_int(cuaderno.cuantas()).is_equal(0)


func test_una_nota_sobrevive_a_seguir_escribiendo() -> void:  # 009-AC4
	# La forma ejercible de «sobrevive a cambiar de app»: el cuaderno es una sola instancia y
	# vive en el sistema, no en la pantalla. Si lo construyera la app de notas, esconder el panel
	# al pasar a los chats tiraría todo lo anotado sin un solo error.
	var cuaderno := Cuaderno.new()
	var primera := cuaderno.escribir("Uno", "")
	cuaderno.escribir("Dos", "")
	assert_int(cuaderno.cuantas()).is_equal(2)
	assert_object(cuaderno.notas()[0]).is_same(primera)


func test_la_lista_devuelta_es_una_copia() -> void:  # 009-AC4
	# Medido en headless para los arrays de este repo: uno devuelto sin `duplicate()` es el mismo
	# array, y un `clear()` afuera vacía el original. Sin la copia, quien mire el cuaderno para
	# dibujarlo lo puede vaciar.
	var cuaderno := Cuaderno.new()
	cuaderno.escribir("Uno", "")
	var notas := cuaderno.notas()
	notas.clear()
	assert_int(cuaderno.cuantas()).is_equal(1)

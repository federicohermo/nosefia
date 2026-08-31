## Qué está mirando la mira, y —lo que importa— cuándo eso cambió.
##
## El `RayCast3D` se lee en `_physics_process`, o sea 60 veces por segundo: medido,
## `physics_ticks_per_second` vale 60 en este proyecto. Una señal por lectura son 60 emisiones
## por segundo mirando fijo una estantería, y por eso `observar()` devuelve si cambió.
extends GdUnitTestSuite

const Foco := preload("res://src/dominio/foco.gd")

## Dos identidades cualesquiera distintas de `SIN_OBJETIVO`. Son `int` porque lo que se guarda
## es el `get_instance_id()` del cuerpo con el que chocó el rayo: un `int` no conoce a nadie, y
## guardar el nodo pondría en rojo el gate de capas sin un solo `preload`.
const UN_OBJETO := 26558334344
const OTRO_OBJETO := 26558334345


func test_el_primer_objetivo_avisa_y_queda_guardado() -> void:
	var foco := Foco.new()
	assert_bool(foco.observar(UN_OBJETO, 2.0, true)).is_true()
	assert_int(foco.objetivo()).is_equal(UN_OBJETO)
	assert_float(foco.distancia()).is_equal(2.0)
	assert_bool(foco.hay_interactuable()).is_true()


func test_caminar_hacia_el_mismo_objeto_no_vuelve_a_avisar() -> void:
	# Es el caso que justifica la pieza entera: la distancia cambia todos los cuadros mientras
	# el jugador se acerca, y eso no es un cambio de objetivo.
	var foco := Foco.new()
	foco.observar(UN_OBJETO, 2.0, true)
	assert_bool(foco.observar(UN_OBJETO, 1.4, true)).is_false()
	assert_float(foco.distancia()).is_equal(1.4)


func test_mirar_otro_objeto_avisa() -> void:
	var foco := Foco.new()
	foco.observar(UN_OBJETO, 2.0, true)
	assert_bool(foco.observar(OTRO_OBJETO, 2.0, true)).is_true()
	assert_int(foco.objetivo()).is_equal(OTRO_OBJETO)


func test_que_el_mismo_objeto_deje_de_ser_interactuable_tambien_avisa() -> void:
	# La identidad y la interactuabilidad son los dos motivos de cambio, y el segundo importa
	# porque es el que decide si el HUD dice algo: el mismo nodo puede dejar de estar en el
	# grupo sin moverse de lugar.
	var foco := Foco.new()
	foco.observar(UN_OBJETO, 2.0, true)
	assert_bool(foco.observar(UN_OBJETO, 2.0, false)).is_true()
	assert_bool(foco.hay_interactuable()).is_false()


func test_dejar_de_mirar_avisa_y_limpia() -> void:
	var foco := Foco.new()
	foco.observar(UN_OBJETO, 2.0, true)
	assert_bool(foco.observar(Foco.SIN_OBJETIVO, 0.0, false)).is_true()
	assert_int(foco.objetivo()).is_equal(Foco.SIN_OBJETIVO)
	assert_bool(foco.hay_interactuable()).is_false()


func test_un_foco_recien_creado_no_mira_nada() -> void:
	# `SIN_OBJETIVO` es `0` y sirve de centinela porque el `get_instance_id()` de un `Node` real
	# nunca vale cero: medido, `26558334344`.
	var foco := Foco.new()
	assert_int(foco.objetivo()).is_equal(Foco.SIN_OBJETIVO)
	assert_bool(foco.hay_interactuable()).is_false()


func test_no_mirar_nada_dos_veces_seguidas_no_avisa_dos_veces() -> void:
	# Sin esto, mirar al vacío emitiría `objetivo_perdido` sesenta veces por segundo, que es
	# exactamente el ruido que esta pieza existe para cortar.
	var foco := Foco.new()
	assert_bool(foco.observar(Foco.SIN_OBJETIVO, 0.0, false)).is_false()

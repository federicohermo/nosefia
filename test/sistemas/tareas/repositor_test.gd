## El nodo que repone adentro del motor: reserva la unidad en la mano, se la pasa al estante y
## publica lo que el estante contestó.
##
## **Ningún caso entra un nodo al árbol y ninguno hace correr `_process`.** Se instancia con
## `auto_free(Repositor.new())` y se le llama a mano: sin `_process`, el turno no se mueve, y un
## descuento que apareciera sería un segundo cobro.
extends GdUnitTestSuite

const REPOSITOR := "res://src/sistemas/tareas/repositor.gd"

## Los archivos que este spec escribe. Ninguno puede nombrar `consumir`: el tiempo real cobra el
## camino, y cobrar además la tarea le cobraría a reponer un minuto que la investigación paga.
const ARCHIVOS_DEL_SPEC := [
	"res://src/dominio/almacen/estante.gd",
	"res://src/dominio/almacen/reglas_del_estante.gd",
	"res://src/dominio/jornada/apertura.gd",
	"res://src/sistemas/tareas/repositor.gd",
	"res://src/escenas/puestos/estante.gd",
	"res://src/escenas/objetos/caja_de_productos.gd",
]

## Lo que delataría un flag propio de la tarea adentro del nodo. El `Turno` ya sabe que la
## segunda vez no cuenta; un flag acá sería esa misma regla escrita en la capa que traduce.
const PATRONES_DE_ESTADO_PROPIO := "var\\s+_cumplida|_colocadas"

## Una fila chica para que llenar el estante sean dos colocaciones y no seis.
const CUPO_DE_PRUEBA := 2

var _colocados: int = 0
var _rechazos: int = 0
var _cumplidas_avisadas: int = 0
var _avisos_de_tarea: int = 0
var _descumplidas: int = 0

## El turno que el reloj está corriendo. Se guarda acá porque `RelojDelTurno` es su único dueño
## y no lo expone: sin esta referencia, cuánto se descontó sólo se podría leer por la señal
## `tiempo_consumido`, que sale de `_process()` — y ningún caso de esta suite lo hace correr.
var _turno: Turno = null


class UnidadFisica:
	extends RigidBody3D
	var datos: ObjetoDelAlmacen


func before_test() -> void:
	_colocados = 0
	_rechazos = 0
	_cumplidas_avisadas = 0
	_avisos_de_tarea = 0
	_descumplidas = 0
	_turno = null


func _producto(id: Producto.Id) -> Producto:
	return Producto.new(id, "de prueba", 100)


## Un repositor cableado a mano: reloj con turno arrancado, agarre y estante de un producto.
func _repositor(
	en_deposito: int = 10, restante: float = Reglas.DURACION_DEL_TURNO, en_gondola: int = 0
) -> Repositor:
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([actroncito], {Producto.Id.ACTRONCITO: CUPO_DE_PRUEBA})
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, en_deposito)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, en_gondola)

	var obligatorias := Apertura.obligatorias(1)
	_turno = Turno.new(restante, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)
	reloj.tarea_descumplida.connect(_anotar_descumplida)

	var repositor: Repositor = auto_free(Repositor.new())
	repositor.reloj = reloj
	repositor.agarre = _agarre()
	repositor.producto_colocado.connect(_anotar_colocado)
	repositor.colocacion_rechazada.connect(_anotar_rechazo)
	repositor.arrancar(Estante.new(inventario, [actroncito]))
	return repositor


func _agarre() -> Agarre:
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	return agarre


## Retira una unidad a la mano y la coloca: el único camino por el que hoy se repone.
func _reponer_una(repositor: Repositor) -> void:
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)
	repositor.pedir_colocar_de_la_mano()


func test_al_llenar_el_estante_las_tareas_cumplidas_suben_exactamente_en_uno() -> void:
	var repositor := _repositor()
	_reponer_una(repositor)
	assert_int(_avisos_de_tarea).is_equal(0)
	_reponer_una(repositor)
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)


func test_colocar_de_mas_no_vuelve_a_contar_la_tarea() -> void:
	# El estante ya está lleno, así que el intento siguiente se rechaza y `completar()` no
	# llega a llamarse de nuevo. Y si llegara, el `Turno` contestaría `false`: la regla vive
	# allá y no acá, que es lo que deja a este nodo sin estado propio.
	var repositor := _repositor()
	for _unidad in range(CUPO_DE_PRUEBA + 1):
		_reponer_una(repositor)
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)
	assert_int(_colocados).is_equal(CUPO_DE_PRUEBA)
	assert_int(_rechazos).is_equal(1)


func test_llenar_el_estante_no_mueve_el_turno() -> void:
	# `_process` no corre en ningún caso de esta suite: si alguien llamara a `consumir()`, el
	# restante ya no sería el turno entero.
	var repositor := _repositor()
	for _unidad in range(CUPO_DE_PRUEBA):
		_reponer_una(repositor)
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_float(_turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)


func test_llenar_el_estante_con_un_segundo_restante_cumple_reponer() -> void:
	# Es el caso que motivó quitar los costos: el estante lleno en el último minuto de la noche
	# no vuelve a preguntar, así que si el turno la rechaza acá, se pierde sin aviso.
	var repositor := _repositor(10, 1.0)
	for _unidad in range(CUPO_DE_PRUEBA):
		_reponer_una(repositor)
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	assert_float(_turno.tiempo_restante()).is_equal(1.0)


func test_ningun_archivo_de_este_spec_nombra_consumir() -> void:
	# Es la mitad ejecutable de la decisión del doble cobro. El nombre no se escribe ni en un
	# comentario: este caso no distingue código de prosa, y hacerlo pasar comentando distinto
	# sería trampa.
	for ruta: String in ARCHIVOS_DEL_SPEC:
		var texto := FileAccess.get_file_as_string(ruta)
		(
			assert_str(texto)
			. override_failure_message("`%s` está vacío o no existe" % ruta)
			. is_not_empty()
		)
		(
			assert_bool(texto.contains("consumir"))
			. override_failure_message("`%s` nombra `consumir`: es un segundo cobro" % ruta)
			. is_false()
		)


func test_sin_tiempo_para_reponer_la_tarea_no_se_cuenta_ni_descuenta() -> void:
	# El turno arranca cerrado, así que no cuenta nada. El estante igual se llena:
	# el estado del mundo no depende de que el jefe la cuente.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([actroncito], {Producto.Id.ACTRONCITO: CUPO_DE_PRUEBA})
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 10)
	var obligatorias := Apertura.obligatorias(1)
	_turno = Turno.new(0.0, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.reloj = reloj
	repositor.agarre = _agarre()
	repositor.arrancar(Estante.new(inventario, [actroncito]))

	for _unidad in range(CUPO_DE_PRUEBA):
		_reponer_una(repositor)
	assert_int(_avisos_de_tarea).is_equal(0)
	assert_float(_turno.tiempo_restante()).is_equal(0.0)


func test_el_repositor_no_lleva_estado_propio_de_la_tarea() -> void:
	# Está medido que un flag acá pasa los dos gates en verde: `sistemas/` puede escribir la
	# regla y nadie lo dice. Por eso el criterio la ata con una búsqueda sobre el archivo.
	var texto := FileAccess.get_file_as_string(REPOSITOR)
	assert_str(texto).is_not_empty()
	var propio := RegEx.create_from_string(PATRONES_DE_ESTADO_PROPIO).search_all(texto)
	(
		assert_array(propio)
		. override_failure_message("`repositor.gd` lleva estado propio de la tarea")
		. is_empty()
	)


func _anotar_colocado(_producto: Producto, _completos: int) -> void:
	_colocados += 1


func test_depositar_desde_la_mano_entrega_el_cuerpo_una_sola_vez() -> void:
	var repositor := _repositor()
	var agarre := repositor.agarre
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)).is_true()
	assert_object(agarre.manos().sostenido()).is_same(nodo.datos)
	assert_int(nodo.collision_layer).is_zero()
	repositor.pedir_colocar_de_la_mano()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(_colocados).is_equal(1)
	repositor.pedir_colocar_de_la_mano()
	assert_int(_colocados).is_equal(1)
	assert_int(_rechazos).is_equal(1)


func test_con_la_mano_llena_no_reserva_otra_unidad() -> void:
	var repositor := _repositor(1)
	var agarre := repositor.agarre
	var objeto := ObjetoDelAlmacen.new()
	assert_bool(agarre.manos().agarrar(objeto)).is_true()
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)).is_false()
	assert_object(agarre.manos().sostenido()).is_same(objeto)
	assert_int(repositor.estante().disponibles_para_retirar(Catalogo.todos()[0])).is_equal(1)


func _anotar_rechazo(_motivo: Estante.Rechazo) -> void:
	_rechazos += 1


func _anotar_tarea(cumplidas: int) -> void:
	_avisos_de_tarea += 1
	_cumplidas_avisadas = cumplidas


func test_devolver_saca_la_unidad_de_la_mano_y_la_mete_en_su_caja() -> void:  # AC-STK-039
	var repositor := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA)
	var agarre := repositor.agarre
	var caja := repositor.caja(Producto.Id.ACTRONCITO)
	var disponibles := repositor.estante().disponibles_para_retirar(caja.producto)
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)).is_true()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	# Devuelve el cuerpo que sacó de la mano: esconderlo es de quien lo dibuja.
	assert_object(repositor.pedir_devolver(Producto.Id.ACTRONCITO)).is_same(nodo)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_int(repositor.estante().disponibles_para_retirar(caja.producto)).is_equal(disponibles)
	assert_int(repositor.estante().unidades_en_gondola(caja.producto)).is_zero()
	assert_int(_colocados).is_zero()


func test_si_la_caja_no_la_recibe_la_unidad_sigue_en_la_mano() -> void:  # AC-STK-040
	# Nueve en el depósito: con una afuera, la caja tiene las de una caja entera y no recibe.
	var repositor := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA + 1)
	var agarre := repositor.agarre
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)).is_true()
	var unidad := agarre.manos().sostenido()
	assert_object(repositor.pedir_devolver(Producto.Id.ACTRONCITO)).is_null()
	assert_object(agarre.manos().sostenido()).is_same(unidad)
	assert_int(repositor.caja(Producto.Id.ACTRONCITO).unidades()).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)


func test_devolver_con_otra_cosa_en_la_mano_no_saca_nada() -> void:  # AC-STK-038
	var repositor := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA)
	var agarre := repositor.agarre
	assert_object(repositor.pedir_devolver(Producto.Id.ACTRONCITO)).is_null()
	var objeto := ObjetoDelAlmacen.new()
	assert_bool(agarre.manos().agarrar(objeto)).is_true()
	assert_object(repositor.pedir_devolver(Producto.Id.ACTRONCITO)).is_null()
	assert_object(agarre.manos().sostenido()).is_same(objeto)
	assert_int(repositor.caja(Producto.Id.ACTRONCITO).unidades()).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)


func test_con_la_caja_vacia_no_retira_aunque_la_gondola_tenga_lugar() -> void:  # AC-STK-016
	# Una sola unidad en el depósito, y la fila de dos casilleros vacía. La que salió queda en el
	# piso: la mano está libre y a la góndola le sobra un casillero, pero la caja no tiene más.
	var repositor := _repositor(1)
	var agarre := repositor.agarre
	var primera: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, primera)).is_true()
	assert_object(agarre.soltar(true)).is_same(primera)
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var estante := repositor.estante()
	assert_int(repositor.caja(Producto.Id.ACTRONCITO).unidades()).is_zero()
	(
		assert_int(
			(
				estante.cupo(producto)
				- estante.unidades_en_gondola(producto)
				- estante.reservadas(producto)
			)
		)
		. is_greater(0)
	)
	var segunda: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, segunda)).is_false()
	assert_object(agarre.manos().sostenido()).is_null()


func test_la_caja_es_la_del_estante_de_la_noche() -> void:  # AC-STK-037
	# Arrancar otra noche con una unidad en la mano la entrega, y la caja se cuenta sobre el
	# estante nuevo: no queda nada afuera y vuelve a estar llena.
	var repositor := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA)
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)).is_true()
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([actroncito], {Producto.Id.ACTRONCITO: CUPO_DE_PRUEBA})
	inventario.ingresar(
		actroncito, Inventario.Ubicacion.DEPOSITO, ReglasDelEstante.UNIDADES_POR_CAJA
	)
	repositor.arrancar(Estante.new(inventario, [actroncito]))
	assert_object(repositor.agarre.manos().sostenido()).is_null()
	assert_int(repositor.caja(Producto.Id.ACTRONCITO).unidades()).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)
	assert_int(repositor.estante().reservadas(actroncito)).is_zero()


func _anotar_descumplida(_cumplidas: int) -> void:
	_descumplidas += 1


func test_agarrar_de_la_gondola_pone_la_unidad_en_la_mano() -> void:  # AC-PLY-049 AC-STK-044
	var repositor := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA, Reglas.DURACION_DEL_TURNO, 2)
	var agarre := repositor.agarre
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_agarrar_de_la_gondola(Producto.Id.ACTRONCITO, 1, nodo)).is_true()
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	assert_object(unidad).is_not_null()
	assert_object(nodo.datos).is_same(unidad)
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	assert_array(repositor.estante().casilleros_vacios(actroncito)).is_equal([1])
	assert_array(repositor.estante().casilleros_ocupados(actroncito)).is_equal([0])
	# Un casillero vacío no da nada, aunque la mano esté libre.
	agarre.soltar(true)
	var otro: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_agarrar_de_la_gondola(Producto.Id.ACTRONCITO, 1, otro)).is_false()
	assert_object(agarre.manos().sostenido()).is_null()


func test_con_algo_en_la_mano_no_se_agarra_de_la_gondola() -> void:  # AC-PLY-049
	var repositor := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA, Reglas.DURACION_DEL_TURNO, 2)
	var agarre := repositor.agarre
	var objeto := ObjetoDelAlmacen.new()
	assert_bool(agarre.manos().agarrar(objeto)).is_true()
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_agarrar_de_la_gondola(Producto.Id.ACTRONCITO, 0, nodo)).is_false()
	assert_object(agarre.manos().sostenido()).is_same(objeto)
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	assert_int(repositor.estante().unidades_en_gondola(actroncito)).is_equal(2)


func test_agarrar_de_la_gondola_descumple_reponer_y_colocarla_la_cumple() -> void:  # AC-STK-048
	var repositor := _repositor()
	for _unidad in range(CUPO_DE_PRUEBA):
		_reponer_una(repositor)
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_agarrar_de_la_gondola(Producto.Id.ACTRONCITO, 0, nodo)).is_true()
	assert_int(_turno.tareas_cumplidas()).is_zero()
	assert_int(_descumplidas).is_equal(1)
	repositor.pedir_colocar_de_la_mano(_producto(Producto.Id.ACTRONCITO), 0)
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	assert_int(_avisos_de_tarea).is_equal(2)


func test_la_unidad_se_coloca_en_el_casillero_que_se_pide() -> void:  # AC-PLY-048
	var repositor := _repositor()
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)).is_true()
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	repositor.pedir_colocar_de_la_mano(actroncito, 1)
	assert_object(repositor.agarre.manos().sostenido()).is_null()
	assert_array(repositor.estante().casilleros_ocupados(actroncito)).is_equal([1])
	assert_int(_colocados).is_equal(1)
	# Otra al mismo casillero se rechaza, y sigue en la mano.
	var otra: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, otra)).is_true()
	repositor.pedir_colocar_de_la_mano(actroncito, 1)
	assert_object(repositor.agarre.manos().sostenido()).is_same(otra.datos)
	assert_int(_rechazos).is_equal(1)


func test_la_unidad_de_la_gondola_no_entra_en_la_caja_llena() -> void:  # AC-STK-047
	var repositor := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA, Reglas.DURACION_DEL_TURNO, 2)
	var agarre := repositor.agarre
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_agarrar_de_la_gondola(Producto.Id.ACTRONCITO, 1, nodo)).is_true()
	var unidad := agarre.manos().sostenido()
	assert_object(repositor.pedir_devolver(Producto.Id.ACTRONCITO)).is_null()
	assert_object(agarre.manos().sostenido()).is_same(unidad)
	assert_int(repositor.caja(Producto.Id.ACTRONCITO).unidades()).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)

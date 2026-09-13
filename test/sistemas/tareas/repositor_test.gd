## El nodo que repone adentro del motor: saca de la caja, se lo pasa al estante y publica lo que
## el estante contestó.
##
## **Ningún caso entra un nodo al árbol y ninguno hace correr `_process`.** Se instancia con
## `auto_free(Repositor.new())` y se le llama a mano, que es lo que vuelve medible el AC5: sin
## `_process`, el único descuento que puede aparecer en el turno es el de `completar()`.
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

## Un umbral chico para que llenar el estante sean dos colocaciones y no seis.
const CUPO_DE_PRUEBA := 2

var _colocados: int = 0
var _rechazos: int = 0
var _ultimo_motivo: int = Estante.Rechazo.NINGUNO
var _cumplidas_avisadas: int = 0
var _avisos_de_tarea: int = 0

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
	_ultimo_motivo = Estante.Rechazo.NINGUNO
	_cumplidas_avisadas = 0
	_avisos_de_tarea = 0
	_turno = null


func _producto(id: Producto.Id) -> Producto:
	return Producto.new(id, "de prueba", 100, CUPO_DE_PRUEBA)


## Un repositor cableado a mano: reloj con turno arrancado, caja cargada y estante de un producto.
func _repositor(unidades_en_la_caja: int, en_deposito: int = 10) -> Repositor:
	var yerba := _producto(Producto.Id.YERBA)
	var inventario := Inventario.new([yerba])
	inventario.ingresar(yerba, Inventario.Ubicacion.DEPOSITO, en_deposito)

	var obligatorias := Apertura.obligatorias()
	_turno = Apertura.turno_de_la_jornada(obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)

	var carga: CargaDeLaCaja = auto_free(CargaDeLaCaja.new())
	for _unidad in range(unidades_en_la_caja):
		carga.caja().guardar(yerba)

	var repositor: Repositor = auto_free(Repositor.new())
	repositor.reloj = reloj
	repositor.carga = carga
	repositor.producto_colocado.connect(_anotar_colocado)
	repositor.colocacion_rechazada.connect(_anotar_rechazo)
	repositor.arrancar(Estante.new(inventario, [yerba]))
	return repositor


func test_al_llenar_el_estante_las_tareas_cumplidas_suben_exactamente_en_uno() -> void:  # 008-AC4
	var repositor := _repositor(CUPO_DE_PRUEBA)
	repositor.pedir_colocar()
	assert_int(_avisos_de_tarea).is_equal(0)
	repositor.pedir_colocar()
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)


func test_colocar_de_mas_no_vuelve_a_contar_la_tarea() -> void:  # 008-AC4
	# El estante ya está lleno, así que la colocación siguiente se rechaza y `completar()` no
	# llega a llamarse de nuevo. Y si llegara, el `Turno` contestaría `false`: la regla vive
	# allá y no acá, que es lo que deja a este nodo sin estado propio.
	var repositor := _repositor(CUPO_DE_PRUEBA + 1)
	for _unidad in range(CUPO_DE_PRUEBA + 1):
		repositor.pedir_colocar()
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)
	assert_int(_rechazos).is_equal(1)
	assert_int(_ultimo_motivo).is_equal(Estante.Rechazo.ESTANTE_LLENO)


func test_llenar_el_estante_descuenta_exactamente_el_costo_de_reponer() -> void:  # 008-AC5
	# `_process` no corre en ningún caso de esta suite, así que este descuento es el único que
	# puede haber: si además alguien llamara a `consumir()`, el restante no daría este número.
	var repositor := _repositor(CUPO_DE_PRUEBA)
	for _unidad in range(CUPO_DE_PRUEBA):
		repositor.pedir_colocar()
	var esperado := Reglas.DURACION_DEL_TURNO - Reglas.COSTO_DE_REPONER
	assert_float(_turno.tiempo_restante()).is_equal(esperado)


func test_ningun_archivo_de_este_spec_nombra_consumir() -> void:  # 008-AC5
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


func test_sin_tiempo_para_reponer_la_tarea_no_se_cuenta_ni_descuenta() -> void:  # 008-AC6
	# El turno arranca vacío, así que el costo excede lo que queda. El estante igual se llena:
	# el estado del mundo no depende de que el jefe la cuente.
	var yerba := _producto(Producto.Id.YERBA)
	var inventario := Inventario.new([yerba])
	inventario.ingresar(yerba, Inventario.Ubicacion.DEPOSITO, 10)
	var obligatorias := Apertura.obligatorias()
	_turno = Turno.new(0.0, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)
	var carga: CargaDeLaCaja = auto_free(CargaDeLaCaja.new())
	for _unidad in range(CUPO_DE_PRUEBA):
		carga.caja().guardar(yerba)
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.reloj = reloj
	repositor.carga = carga
	repositor.arrancar(Estante.new(inventario, [yerba]))

	for _unidad in range(CUPO_DE_PRUEBA):
		repositor.pedir_colocar()
	assert_int(_avisos_de_tarea).is_equal(0)
	assert_float(_turno.tiempo_restante()).is_equal(0.0)


func test_la_caja_vacia_se_rechaza_como_producto_no_aceptado() -> void:  # 008-AC7
	# Sin nada que sacar, el estante recibe `null` y contesta el rechazo en vez de reventar: es
	# el mismo camino por el que llega un `id` sin fila en el catálogo.
	var repositor := _repositor(0)
	repositor.pedir_colocar()
	assert_int(_colocados).is_equal(0)
	assert_int(_rechazos).is_equal(1)
	assert_int(_ultimo_motivo).is_equal(Estante.Rechazo.PRODUCTO_NO_ACEPTADO)


func test_una_colocacion_exitosa_saca_la_unidad_de_la_caja() -> void:  # 008-AC7
	# Y sólo la exitosa: un rechazo que sacara igual dejaría al jugador con la caja vacía y el
	# estante sin llenar, sin un solo error.
	var repositor := _repositor(CUPO_DE_PRUEBA + 1)
	for _unidad in range(CUPO_DE_PRUEBA + 1):
		repositor.pedir_colocar()
	assert_int(_colocados).is_equal(CUPO_DE_PRUEBA)
	assert_int(repositor.carga.caja().ocupados()).is_equal(1)


func test_el_repositor_no_lleva_estado_propio_de_la_tarea() -> void:  # 008-AC7
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


func test_depositar_desde_la_mano_entrega_el_cuerpo_una_sola_vez() -> void:  # 008-AC2
	var repositor := _repositor(0)
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	repositor.agarre = agarre
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.YERBA, nodo)).is_true()
	assert_object(agarre.manos().sostenido()).is_same(nodo.datos)
	assert_int(nodo.collision_layer).is_zero()
	repositor.pedir_colocar_de_la_mano()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(_colocados).is_equal(1)
	repositor.pedir_colocar_de_la_mano()
	assert_int(_colocados).is_equal(1)
	assert_int(_rechazos).is_equal(1)


func test_con_la_mano_llena_no_reserva_otra_unidad() -> void:  # 006-AC2
	var repositor := _repositor(0, 1)
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	repositor.agarre = agarre
	var objeto := ObjetoDelAlmacen.new()
	assert_bool(agarre.manos().agarrar(objeto)).is_true()
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.YERBA, nodo)).is_false()
	assert_object(agarre.manos().sostenido()).is_same(objeto)
	assert_int(repositor.estante().disponibles_para_retirar(Catalogo.todos()[0])).is_equal(1)


func _anotar_rechazo(motivo: Estante.Rechazo) -> void:
	_rechazos += 1
	_ultimo_motivo = motivo


func _anotar_tarea(cumplidas: int) -> void:
	_avisos_de_tarea += 1
	_cumplidas_avisadas = cumplidas

## El nodo que atiende adentro del motor: pide el comprador siguiente, cobra y publica.
##
## **Ningún caso entra el nodo al árbol.** Se instancia con `auto_free(Ventanilla.new())` y se le
## llama a mano; el único `_process()` que corre en esta suite es el del reloj, y se lo llama
## explícitamente porque el caso del tiempo mide justamente que nadie lo haya pausado.
extends GdUnitTestSuite

## Los ocho archivos de este spec. El AC11 pide los seis de `dominio/` y `sistemas/`; los dos de
## `ui/` y `escenas/` se agregan porque son justamente los que ningún gate mira.
const ARCHIVOS_DEL_SPEC := [
	"res://src/dominio/almacen/comprador.gd",
	"res://src/dominio/almacen/compradores.gd",
	"res://src/dominio/almacen/atencion.gd",
	"res://src/dominio/almacen/tarea_de_atender.gd",
	"res://src/dominio/almacen/reglas_de_la_ventanilla.gd",
	"res://src/sistemas/tareas/ventanilla.gd",
	"res://src/ui/diegetica/panel_de_la_ventanilla.gd",
	"res://src/escenas/puestos/ventanilla.gd",
]

## Segundos **reales** de ventanilla abierta que mide el AC10, en un solo cuadro.
const SEGUNDOS_REALES_ABIERTA := 30.0

const EN_GONDOLA := 9

var _turno: Turno = null
var _llegados: int = 0
var _despachos_avisados: int = 0
var _vacia: int = 0
var _rechazos: int = 0
var _avisos_de_tarea: int = 0
var _cumplidas_avisadas: int = 0


func before_test() -> void:
	_turno = null
	_llegados = 0
	_despachos_avisados = 0
	_vacia = 0
	_rechazos = 0
	_avisos_de_tarea = 0
	_cumplidas_avisadas = 0


func _pedido() -> Venta:
	var venta := Venta.new()
	venta.agregar(Catalogo.de(Producto.Id.YERBA), 1)
	return venta


func _inventario() -> Inventario:
	var yerba := Catalogo.de(Producto.Id.YERBA)
	var inventario := Inventario.new([yerba])
	inventario.ingresar(yerba, Inventario.Ubicacion.GONDOLA, EN_GONDOLA)
	return inventario


func _compradores(cuantos: int) -> Array[Comprador]:
	var lista: Array[Comprador] = []
	for indice in range(cuantos):
		var pedido := _pedido()
		lista.append(Comprador.new("Comprador %d" % indice, pedido, pedido.total()))
	return lista


## Una ventanilla cableada a mano, con su reloj arrancado sobre un turno entero.
func _ventanilla(cuantos: int, presupuesto: float = Reglas.DURACION_DEL_TURNO) -> Ventanilla:
	var obligatorias := Apertura.obligatorias()
	_turno = Turno.new(presupuesto, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)

	var ventanilla: Ventanilla = auto_free(Ventanilla.new())
	ventanilla.reloj = reloj
	ventanilla.comprador_llegado.connect(_anotar_llegado)
	ventanilla.atencion_despachada.connect(_anotar_despacho)
	ventanilla.ventanilla_vacia.connect(_anotar_vacia)
	ventanilla.arrancar(TareaDeAtender.new(_compradores(cuantos), _inventario()))
	return ventanilla


func test_al_despachar_al_ultimo_la_obligatoria_se_cuenta_una_sola_vez() -> void:  # 013-AC9
	var ventanilla := _ventanilla(2)
	ventanilla.pedir_atender()
	ventanilla.pedir_cobrar()
	assert_int(_avisos_de_tarea).is_equal(0)
	ventanilla.pedir_atender()
	ventanilla.pedir_cobrar()
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)
	assert_int(_turno.tareas_cumplidas()).is_equal(1)


func test_despachar_al_ultimo_descuenta_el_costo_de_la_caja_y_no_lo_repite() -> void:  # 013-AC9
	# El `_process` del reloj no corre en este caso, así que este descuento es el único que
	# puede haber: si además alguien descontara por su cuenta, el restante no daría el número.
	var ventanilla := _ventanilla(1)
	ventanilla.pedir_atender()
	ventanilla.pedir_cobrar()
	var esperado := Reglas.DURACION_DEL_TURNO - Reglas.costo_de(Tarea.Tipo.CAJA)
	assert_float(_turno.tiempo_restante()).is_equal(esperado)
	# Atender de más no vuelve a cobrar: no queda nadie, y el `Turno` ya sabe que la segunda vez
	# no cuenta.
	ventanilla.pedir_atender()
	ventanilla.pedir_cobrar()
	assert_float(_turno.tiempo_restante()).is_equal(esperado)
	assert_int(_avisos_de_tarea).is_equal(1)


func test_completar_una_tarea_aparte_no_le_sube_el_contador_al_turno() -> void:  # 013-AC9
	# `RelojDelTurno.obligatoria()` es la única forma de conseguir la instancia que el turno
	# está contando: una copia devuelve `true` y deja el contador clavado en 0, sin un error.
	var obligatorias := Apertura.obligatorias()
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	assert_bool(turno.completar(Tarea.new(Tarea.Tipo.CAJA))).is_true()
	assert_int(turno.tareas_cumplidas()).is_equal(0)


func test_la_ventanilla_avisa_quien_llego_y_cuando_no_queda_nadie() -> void:  # 013-AC9
	var ventanilla := _ventanilla(1)
	ventanilla.pedir_atender()
	assert_int(_llegados).is_equal(1)
	assert_int(_vacia).is_equal(0)
	ventanilla.pedir_atender()
	assert_int(_llegados).is_equal(1)
	assert_int(_vacia).is_equal(1)


func test_despachar_sin_vender_avisa_igual_que_cobrar() -> void:  # 013-AC9
	var ventanilla := _ventanilla(1)
	ventanilla.pedir_atender()
	ventanilla.pedir_despachar_sin_vender()
	assert_int(_despachos_avisados).is_equal(1)
	assert_int(_avisos_de_tarea).is_equal(1)


func test_el_turno_sigue_corriendo_con_la_ventanilla_abierta() -> void:  # 013-AC10
	# **Es la decisión entera del spec**: atender cuesta minutos, y si el reloj se pausara la
	# ventanilla sería gratis y la tensión aritmética dejaría de apretar. Se mide contra
	# `Ritmo.escalar()` y nunca contra el número, que vive en el 007.
	var ventanilla := _ventanilla(2)
	ventanilla.pedir_atender()
	var antes := _turno.tiempo_restante()
	ventanilla.reloj._process(SEGUNDOS_REALES_ABIERTA)
	var gastado := antes - _turno.tiempo_restante()
	assert_float(gastado).is_equal(Ritmo.escalar(SEGUNDOS_REALES_ABIERTA))


func test_ningun_archivo_de_este_spec_pausa_el_juego() -> void:  # 013-AC10
	# Las dos formas de congelar el reloj desde afuera del dominio. El nombre no se escribe ni en
	# un comentario: este caso no distingue código de prosa.
	for ruta: String in ARCHIVOS_DEL_SPEC:
		var texto := FileAccess.get_file_as_string(ruta)
		(
			assert_str(texto)
			. override_failure_message("`%s` está vacío o no existe" % ruta)
			. is_not_empty()
		)
		for patron in ["get_tree().paused", "time_scale"]:
			(
				assert_bool(texto.contains(patron))
				. override_failure_message("`%s` nombra `%s`: pausa el turno" % [ruta, patron])
				. is_false()
			)


func test_ningun_archivo_de_este_spec_nombra_consumir() -> void:  # 013-AC11
	# El único que descuenta tiempo es el reloj del 007, y lo hace por cuadro. Un descuento
	# propio acá le cobraría a atender un minuto que el trayecto ya paga.
	for ruta: String in ARCHIVOS_DEL_SPEC:
		var texto := FileAccess.get_file_as_string(ruta)
		(
			assert_bool(texto.contains("consumir"))
			. override_failure_message("`%s` nombra `consumir`: es un segundo cobro" % ruta)
			. is_false()
		)


func test_ningun_archivo_de_este_spec_mueve_stock_ni_sortea() -> void:  # 013-AC11
	# Mover unidades del depósito a la góndola es del 008, y el azar no entra en ningún lado.
	for ruta: String in ARCHIVOS_DEL_SPEC:
		var texto := FileAccess.get_file_as_string(ruta)
		for patron in ["randi(", "randf(", "ingresar("]:
			(
				assert_bool(texto.contains(patron))
				. override_failure_message("`%s` nombra `%s`" % [ruta, patron])
				. is_false()
			)


func _anotar_llegado(_comprador: Comprador) -> void:
	_llegados += 1


func _anotar_despacho(_despachados: int) -> void:
	_despachos_avisados += 1


func _anotar_vacia() -> void:
	_vacia += 1


func _anotar_tarea(cumplidas: int) -> void:
	_avisos_de_tarea += 1
	_cumplidas_avisadas = cumplidas


func test_los_seis_archivos_de_dominio_y_sistemas_tienen_su_espejo() -> void:  # 013-AC13
	# Es la mitad falsable del criterio de terminado: sin los espejos el nodo `tdd` no pasa, y
	# el rojo que da nombra el archivo que falta y no el spec. Acá se lee al revés — se afirma
	# que cada archivo del spec tiene su suite— así que el rojo dice qué queda sin ejercer.
	for ruta: String in ARCHIVOS_DEL_SPEC:
		if (
			not ruta.begins_with("res://src/dominio/")
			and not ruta.begins_with("res://src/sistemas/")
		):
			continue
		var espejo := ruta.replace("res://src/", "res://test/").replace(".gd", "_test.gd")
		(
			assert_bool(FileAccess.file_exists(espejo))
			. override_failure_message("falta el espejo `%s` de `%s`" % [espejo, ruta])
			. is_true()
		)


func test_reabrir_el_panel_sigue_con_el_que_estaba_y_no_llama_al_siguiente() -> void:  # 013-AC6
	# Es la distinción entera de `pedir_abrir()`: sin ella, cerrar y volver a tocar el vidrio
	# saltea al comprador que estaba esperando —se va sin despachar— y la obligatoria queda
	# imposible de cumplir, sin un solo error.
	var ventanilla := _ventanilla(2)
	ventanilla.pedir_abrir()
	var primero := ventanilla.atencion().comprador()
	ventanilla.pedir_abrir()
	assert_object(ventanilla.atencion().comprador()).is_same(primero)
	assert_int(_llegados).is_equal(2)

	# Despachado el primero, recién ahí el vidrio llama al segundo.
	ventanilla.pedir_despachar_sin_vender()
	ventanilla.pedir_abrir()
	assert_object(ventanilla.atencion().comprador()).is_not_same(primero)
	assert_int(ventanilla.tarea().despachados()).is_equal(1)


func test_la_ventanilla_sin_cablear_no_hace_nada_y_lo_dice() -> void:  # 013-AC9
	# Un `.tscn` mal armado no es un rechazo del juego: no puede salir por las señales de
	# rechazo, o la pantalla mostraría «falta mercadería» por un `@export` en null.
	var ventanilla: Ventanilla = auto_free(Ventanilla.new())
	ventanilla.comprador_llegado.connect(_anotar_llegado)
	ventanilla.cobro_rechazado.connect(_anotar_rechazo)
	ventanilla.ventanilla_vacia.connect(_anotar_vacia)
	ventanilla.pedir_abrir()
	ventanilla.pedir_atender()
	ventanilla.pedir_cobrar()
	ventanilla.pedir_despachar_sin_vender()
	assert_int(_llegados).is_equal(0)
	assert_int(_rechazos).is_equal(0)
	assert_int(_vacia).is_equal(0)
	assert_object(ventanilla.atencion()).is_null()


func test_cobrar_sin_stock_avisa_lo_que_falta_y_no_despacha() -> void:  # 013-AC9
	# Emite **una** de las dos señales y nunca las dos: juntas dejarían a la pantalla despachando
	# al comprador y avisando que falta mercadería al mismo tiempo.
	var obligatorias := Apertura.obligatorias()
	_turno = Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	var ventanilla: Ventanilla = auto_free(Ventanilla.new())
	ventanilla.reloj = reloj
	ventanilla.cobro_rechazado.connect(_anotar_rechazo)
	ventanilla.atencion_despachada.connect(_anotar_despacho)
	# La góndola vacía es el estado de la primera noche, antes de que el 008 reponga nada.
	ventanilla.arrancar(
		TareaDeAtender.new(_compradores(1), Inventario.new([Catalogo.de(Producto.Id.YERBA)]))
	)
	ventanilla.pedir_atender()

	ventanilla.pedir_cobrar()

	assert_int(_rechazos).is_equal(1)
	assert_int(_despachos_avisados).is_equal(0)
	assert_bool(ventanilla.atencion().despachada()).is_false()
	assert_int(_turno.tareas_cumplidas()).is_equal(0)


func _anotar_rechazo(_faltantes: Array[Producto]) -> void:
	_rechazos += 1

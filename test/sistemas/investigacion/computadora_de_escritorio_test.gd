## El nodo dueño de la computadora: abre, cambia de app, registra y publica.
##
## **Es dueño de las cuatro piezas del dominio a propósito**: si las construyera la pantalla,
## esconder el panel al cambiar de app tiraría lo leído y lo anotado — sin un solo error, y con
## los seis nodos en verde.
##
## Ningún caso entra el nodo al árbol. El único `_process()` que corre es el del reloj, llamado a
## mano, y justamente porque el criterio mide que nadie lo haya pausado.
extends GdUnitTestSuite

## Los cinco archivos de `ui/` y `escenas/` de este spec, que son los que ningún gate mira, más
## los dos de abajo que tampoco pueden decidir el balance.
const ARCHIVOS_DE_LA_CASCARA := [
	"res://src/ui/diegetica/pantalla_de_computadora.gd",
	"res://src/ui/diegetica/app_caja.gd",
	"res://src/ui/diegetica/app_chats.gd",
	"res://src/ui/diegetica/app_notas.gd",
	"res://src/escenas/puestos/escritorio.gd",
	"res://src/sistemas/investigacion/computadora_de_escritorio.gd",
]

## Los ocho `.gd` de `dominio/` y `sistemas/` que este spec escribe, y que por eso llevan espejo.
const ARCHIVOS_CON_ESPEJO = [
	"res://src/dominio/investigacion/computadora.gd",
	"res://src/dominio/investigacion/mensaje.gd",
	"res://src/dominio/investigacion/conversacion.gd",
	"res://src/dominio/investigacion/bandeja.gd",
	"res://src/dominio/investigacion/nota.gd",
	"res://src/dominio/investigacion/cuaderno.gd",
	"res://src/dominio/almacen/registro_de_ventas.gd",
	"res://src/sistemas/investigacion/computadora_de_escritorio.gd",
]

## Segundos **reales** de computadora abierta que mide el caso del tiempo, en un solo cuadro.
const SEGUNDOS_REALES_ABIERTA := 30.0

var _turno: Turno = null
var _avisos_de_tarea: int = 0
var _cumplidas_avisadas: int = 0
var _descumplidas: int = 0


func before_test() -> void:
	_turno = null
	_avisos_de_tarea = 0
	_cumplidas_avisadas = 0
	_descumplidas = 0


func _reloj() -> RelojDelTurno:
	var obligatorias := Apertura.obligatorias()
	_turno = Apertura.turno_de_la_jornada(obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)
	return reloj


## Una noche con los pedidos dados, sin cobrar todavía. Cada caso cobra los que necesita.
func _atender(pedidos: Array[Venta] = []) -> TareaDeAtender:
	var inventario := Inventario.new(Catalogo.todos())
	for producto in Catalogo.todos():
		inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, producto.umbral)
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 9)
	var compradores: Array[Comprador] = []
	for pedido in pedidos:
		compradores.append(Comprador.new("Comprador", pedido, pedido.total()))
	return TareaDeAtender.new(compradores, inventario)


func _cobrar_el_siguiente(atender: TareaDeAtender) -> void:
	atender.atender()
	atender.atencion().cobrar()


func _venta(id: Producto.Id, unidades: int) -> Venta:
	var venta := Venta.new()
	venta.agregar(Catalogo.de(id), unidades)
	return venta


func _escritorio(atender: TareaDeAtender = _atender()) -> ComputadoraDeEscritorio:
	var escritorio: ComputadoraDeEscritorio = auto_free(ComputadoraDeEscritorio.new())
	escritorio.reloj = _reloj()
	escritorio.reloj.tarea_descumplida.connect(_anotar_descumplida)
	escritorio.arrancar(RegistroDeVentas.new(Catalogo.todos(), atender))
	return escritorio


func test_la_secuencia_entera_no_descuenta_un_solo_segundo() -> void:  # AC-INV-007
	# **Es la decisión entera del spec al revés**: usar la computadora no cuesta por usarla,
	# cuesta porque el reloj no se detuvo. Un descuento por acción cobraría dos veces lo mismo.
	var escritorio := _escritorio()
	var antes := _turno.tiempo_restante()
	escritorio.pedir_abrir()
	escritorio.pedir_cambiar_a(Computadora.App.CHATS)
	escritorio.pedir_marcar_leida(Conversacion.Interlocutor.JEFE)
	escritorio.pedir_cambiar_a(Computadora.App.NOTAS)
	escritorio.pedir_escribir("Puerta del fondo", "Estaba abierta.")
	escritorio.pedir_cerrar()
	assert_float(_turno.tiempo_restante()).is_equal(antes)
	assert_int(_avisos_de_tarea).is_equal(0)


# AC-INV-007
func test_treinta_segundos_con_la_computadora_abierta_cuestan_lo_mismo_que_sin_ella() -> void:
	# Se mide contra `Ritmo.escalar()` y nunca contra el número: el factor vive en el 007, y
	# escribir `30` acá lo dejaría mal por un factor de 24 el día que se rebalancee.
	var abierto := _escritorio()
	abierto.pedir_abrir()
	var turno_abierto := _turno
	var antes_abierto := turno_abierto.tiempo_restante()
	abierto.reloj._process(SEGUNDOS_REALES_ABIERTA)
	var gastado_abierto := antes_abierto - turno_abierto.tiempo_restante()

	var cerrado := _escritorio()
	var turno_cerrado := _turno
	var antes_cerrado := turno_cerrado.tiempo_restante()
	cerrado.reloj._process(SEGUNDOS_REALES_ABIERTA)
	var gastado_cerrado := antes_cerrado - turno_cerrado.tiempo_restante()

	assert_float(gastado_abierto).is_equal(Ritmo.escalar(SEGUNDOS_REALES_ABIERTA))
	assert_float(gastado_abierto).is_equal(gastado_cerrado)


func test_ningun_archivo_de_la_cascara_pausa_el_juego() -> void:
	# Las dos formas de congelar el reloj desde afuera del dominio. El nombre no se escribe ni en
	# un comentario: este caso no distingue código de prosa, y hacerlo pasar comentando distinto
	# sería trampa.
	for ruta: String in ARCHIVOS_DE_LA_CASCARA:
		var texto := FileAccess.get_file_as_string(ruta)
		(
			assert_str(texto)
			. override_failure_message("`%s` está vacío o no existe" % ruta)
			. is_not_empty()
		)
		for patron in ["paused", "time_scale"]:
			(
				assert_bool(texto.contains(patron))
				. override_failure_message("`%s` nombra `%s`: pausa el turno" % [ruta, patron])
				. is_false()
			)


func test_lo_leido_y_lo_anotado_sobreviven_a_cambiar_de_app_y_a_cerrar() -> void:  # AC-INV-012
	var escritorio := _escritorio()
	escritorio.pedir_abrir()
	escritorio.pedir_marcar_leida(Conversacion.Interlocutor.JEFE)
	escritorio.pedir_escribir("Puerta del fondo", "Estaba abierta.")
	escritorio.pedir_cambiar_a(Computadora.App.CAJA)
	escritorio.pedir_cerrar()
	escritorio.pedir_abrir()
	assert_bool(escritorio.bandeja().esta_leida(Conversacion.Interlocutor.JEFE)).is_true()
	assert_int(escritorio.cuaderno().cuantas()).is_equal(1)


func test_la_planilla_en_cero_de_una_noche_sin_ventas_no_cumple_registrar() -> void:  # AC-STK-024
	var escritorio := _escritorio()
	assert_bool(escritorio.registro().coincide()).is_true()
	assert_int(_turno.tareas_cumplidas()).is_equal(0)
	# Un «−» sobre la fila en 0 no cambia la fila, así que tampoco revisa.
	escritorio.pedir_restar(Catalogo.de(Producto.Id.ACTRONCITO))
	assert_int(_turno.tareas_cumplidas()).is_equal(0)
	assert_int(_avisos_de_tarea).is_equal(0)


func test_anotar_lo_vendido_cumple_registrar_con_el_ultimo_gesto() -> void:  # AC-STK-024
	var pedidos: Array[Venta] = [_venta(Producto.Id.ACTRONCITO, 2), _venta(Producto.Id.DUREXTRA, 1)]
	var atender := _atender(pedidos)
	_cobrar_el_siguiente(atender)
	_cobrar_el_siguiente(atender)
	var escritorio := _escritorio(atender)
	escritorio.pedir_sumar(Catalogo.de(Producto.Id.ACTRONCITO))
	escritorio.pedir_sumar(Catalogo.de(Producto.Id.ACTRONCITO))
	assert_int(_avisos_de_tarea).is_equal(0)
	escritorio.pedir_sumar(Catalogo.de(Producto.Id.DUREXTRA))
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	assert_float(_turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)


func test_una_unidad_de_mas_descumple_y_restarla_vuelve_a_cumplir() -> void:  # AC-STK-025
	var pedidos: Array[Venta] = [_venta(Producto.Id.ACTRONCITO, 1)]
	var atender := _atender(pedidos)
	_cobrar_el_siguiente(atender)
	var escritorio := _escritorio(atender)
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	escritorio.pedir_sumar(actroncito)
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	escritorio.pedir_sumar(actroncito)
	assert_int(_turno.tareas_cumplidas()).is_equal(0)
	assert_int(_descumplidas).is_equal(1)
	escritorio.pedir_restar(actroncito)
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	assert_int(_avisos_de_tarea).is_equal(2)


func test_una_venta_nueva_no_descumple_registrar() -> void:  # AC-STK-025
	var pedidos: Array[Venta] = [_venta(Producto.Id.ACTRONCITO, 1), _venta(Producto.Id.BURBALOO, 1)]
	var atender := _atender(pedidos)
	_cobrar_el_siguiente(atender)
	var escritorio := _escritorio(atender)
	escritorio.pedir_sumar(Catalogo.de(Producto.Id.ACTRONCITO))
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	_cobrar_el_siguiente(atender)
	assert_bool(escritorio.registro().coincide()).is_false()
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	assert_int(_descumplidas).is_equal(0)


func test_el_cierre_cuenta_la_planilla_de_ese_instante() -> void:
	var pedidos: Array[Venta] = [_venta(Producto.Id.ACTRONCITO, 1), _venta(Producto.Id.DUREXTRA, 2)]
	for de_mas: int in [0, 1]:
		var atender := _atender(pedidos)
		_cobrar_el_siguiente(atender)
		_cobrar_el_siguiente(atender)
		var escritorio := _escritorio(atender)
		var cierres: Array[int] = []
		escritorio.reloj.turno_cerrado.connect(
			func(cumplidas: int) -> void: cierres.append(cumplidas)
		)
		escritorio.pedir_sumar(Catalogo.de(Producto.Id.ACTRONCITO))
		escritorio.pedir_sumar(Catalogo.de(Producto.Id.DUREXTRA))
		escritorio.pedir_sumar(Catalogo.de(Producto.Id.DUREXTRA))
		for _vez in de_mas:
			escritorio.pedir_sumar(Catalogo.de(Producto.Id.FLINPUF))
		escritorio.reloj._process(Reglas.DURACION_DEL_TURNO)
		assert_array(cierres).is_equal([1 - de_mas])
		# Con el turno cerrado, un gesto ya no cumple ni descumple.
		escritorio.pedir_sumar(Catalogo.de(Producto.Id.FLINPUF))
		assert_int(_turno.tareas_cumplidas()).is_equal(1 - de_mas)


func test_cada_gesto_que_cambia_una_fila_avisa_a_la_pantalla() -> void:
	var escritorio := _escritorio()
	var avisos: Array[int] = [0]
	escritorio.registro_actualizado.connect(func() -> void: avisos[0] += 1)
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	escritorio.pedir_restar(actroncito)
	escritorio.pedir_sumar(actroncito)
	escritorio.pedir_restar(actroncito)
	assert_int(avisos[0]).is_equal(2)


func test_completar_una_tarea_aparte_no_le_sube_el_contador_al_turno() -> void:
	# Caza el bug que no da error: `RelojDelTurno.obligatoria()` es la única forma de conseguir
	# la instancia que el turno está contando, y una copia devuelve `true` sin subir el contador.
	var obligatorias := Apertura.obligatorias()
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	assert_bool(turno.completar(Tarea.new(Tarea.Tipo.REGISTRAR))).is_true()
	assert_int(turno.tareas_cumplidas()).is_equal(0)


func test_el_umbral_y_los_interlocutores_no_se_escriben_en_la_cascara() -> void:
	# Qué es un faltante lo decide el 005 y quiénes escriben lo decide el `.tres`. Copiados en la
	# pantalla, los dos pasan los dos gates en verde y se desincronizan sin que nadie avise.
	for ruta: String in ARCHIVOS_DE_LA_CASCARA:
		var texto := FileAccess.get_file_as_string(ruta)
		for patron in ["umbral", "JEFE", "PROVEEDOR", "DESCONOCIDO"]:
			(
				assert_bool(texto.contains(patron))
				. override_failure_message("`%s` nombra `%s`" % [ruta, patron])
				. is_false()
			)


func test_los_ocho_archivos_de_dominio_y_sistemas_tienen_su_espejo() -> void:
	# Es la mitad falsable del criterio de terminado: sin los espejos el nodo `tdd` no pasa. Acá
	# se lee al revés —cada archivo del spec contra su suite— así que el rojo dice qué queda sin
	# ejercer y no sólo que falta un archivo.
	assert_int(ARCHIVOS_CON_ESPEJO.size()).is_equal(8)
	for ruta: String in ARCHIVOS_CON_ESPEJO:
		var espejo := ruta.replace("res://src/", "res://test/").replace(".gd", "_test.gd")
		(
			assert_bool(FileAccess.file_exists(espejo))
			. override_failure_message("falta el espejo `%s` de `%s`" % [espejo, ruta])
			. is_true()
		)


func _anotar_tarea(cumplidas: int) -> void:
	_avisos_de_tarea += 1
	_cumplidas_avisadas = cumplidas


func _anotar_descumplida(_cumplidas: int) -> void:
	_descumplidas += 1

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
	"res://src/dominio/almacen/caja_registradora.gd",
	"res://src/sistemas/investigacion/computadora_de_escritorio.gd",
]

## Segundos **reales** de computadora abierta que mide el AC3, en un solo cuadro.
const SEGUNDOS_REALES_ABIERTA := 30.0

var _turno: Turno = null
var _avisos_de_tarea: int = 0
var _cumplidas_avisadas: int = 0


func before_test() -> void:
	_turno = null
	_avisos_de_tarea = 0
	_cumplidas_avisadas = 0


func _reloj() -> RelojDelTurno:
	var obligatorias := Apertura.obligatorias()
	_turno = Apertura.turno_de_la_jornada(obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)
	return reloj


func _escritorio() -> ComputadoraDeEscritorio:
	var escritorio: ComputadoraDeEscritorio = auto_free(ComputadoraDeEscritorio.new())
	escritorio.reloj = _reloj()
	escritorio.arrancar(
		CajaRegistradora.new(
			Apertura.inventario_de_la_jornada(), CajaRegistradora.productos_del_dia()
		)
	)
	return escritorio


func test_la_secuencia_entera_no_descuenta_un_solo_segundo() -> void:  # 009-AC2
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


func test_treinta_segundos_con_la_computadora_abierta_cuestan_lo_mismo_que_sin_ella() -> void:
	# 009-AC3
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


func test_ningun_archivo_de_la_cascara_pausa_el_juego() -> void:  # 009-AC3
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


func test_lo_leido_y_lo_anotado_sobreviven_a_cambiar_de_app_y_a_cerrar() -> void:  # 009-AC4
	var escritorio := _escritorio()
	escritorio.pedir_abrir()
	escritorio.pedir_marcar_leida(Conversacion.Interlocutor.JEFE)
	escritorio.pedir_escribir("Puerta del fondo", "Estaba abierta.")
	escritorio.pedir_cambiar_a(Computadora.App.CAJA)
	escritorio.pedir_cerrar()
	escritorio.pedir_abrir()
	assert_bool(escritorio.bandeja().esta_leida(Conversacion.Interlocutor.JEFE)).is_true()
	assert_int(escritorio.cuaderno().cuantas()).is_equal(1)


func test_registrar_el_ultimo_del_dia_cuenta_la_obligatoria_una_sola_vez() -> void:  # 009-AC7
	var escritorio := _escritorio()
	var del_dia := CajaRegistradora.productos_del_dia()
	for indice in range(del_dia.size() - 1):
		escritorio.pedir_registrar(del_dia[indice])
	assert_int(_avisos_de_tarea).is_equal(0)
	assert_int(_turno.tareas_cumplidas()).is_equal(0)

	escritorio.pedir_registrar(del_dia[-1])
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)
	assert_int(_turno.tareas_cumplidas()).is_equal(1)


func test_registrar_de_nuevo_no_descuenta_ni_emite() -> void:  # 009-AC7
	var escritorio := _escritorio()
	var del_dia := CajaRegistradora.productos_del_dia()
	for producto in del_dia:
		escritorio.pedir_registrar(producto)
	var esperado := Reglas.DURACION_DEL_TURNO - Reglas.costo_de(Tarea.Tipo.REGISTRAR)
	assert_float(_turno.tiempo_restante()).is_equal(esperado)
	for producto in del_dia:
		escritorio.pedir_registrar(producto)
	assert_float(_turno.tiempo_restante()).is_equal(esperado)
	assert_int(_avisos_de_tarea).is_equal(1)


func test_completar_una_tarea_aparte_no_le_sube_el_contador_al_turno() -> void:  # 009-AC7
	# Caza el bug que no da error: `RelojDelTurno.obligatoria()` es la única forma de conseguir
	# la instancia que el turno está contando, y una copia devuelve `true` sin subir el contador.
	var obligatorias := Apertura.obligatorias()
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	assert_bool(turno.completar(Tarea.new(Tarea.Tipo.REGISTRAR))).is_true()
	assert_int(turno.tareas_cumplidas()).is_equal(0)


func test_el_umbral_y_los_interlocutores_no_se_escriben_en_la_cascara() -> void:  # 009-AC8
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


func test_los_ocho_archivos_de_dominio_y_sistemas_tienen_su_espejo() -> void:  # 009-AC11
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

## El nodo que carga la caja: traduce el pedido y publica lo que el dominio contestó.
##
## **Ningún caso de acá entra el nodo al árbol**: se instancia con
## `auto_free(CargaDeLaCaja.new())` y se le llama a mano. Que alcance con eso es la prueba de que
## adentro no quedó ninguna regla — el cupo, qué es un producto y por qué se rechaza viven todos
## en `CajaDeTraslado`, que es donde tienen test.
extends GdUnitTestSuite

const CARGA := "res://src/sistemas/tareas/carga_de_la_caja.gd"

## Lo que el nodo no puede nombrar: el cupo escrito acá sería una copia del número que vive en
## `reglas.gd`, y una copia se desincroniza sin que ningún gate lo diga. Se busca el `8` como
## palabra entera para que un `8` adentro de otra cosa no cuente.
const PATRONES_DEL_CUPO := "\\b8\\b|cupo"

## Lo que ninguno de los tres archivos de este spec puede nombrar: la caja es dónde viaja la
## mercadería, no cuánta hay. Mover del depósito a la góndola es del 008.
const PATRONES_DEL_STOCK := ["Inventario", "ingresar", "mover"]

const ARCHIVOS_DEL_SPEC := [
	"res://src/dominio/almacen/caja_de_traslado.gd",
	"res://src/sistemas/tareas/carga_de_la_caja.gd",
	"res://src/escenas/objetos/caja_de_traslado.gd",
]

var _guardados: int = 0
var _rechazos: int = 0
var _ultimo_motivo: int = CajaDeTraslado.Motivo.NINGUNO


func before_test() -> void:
	_guardados = 0
	_rechazos = 0
	_ultimo_motivo = CajaDeTraslado.Motivo.NINGUNO


func test_pedir_guardar_un_producto_lo_guarda_y_avisa_una_sola_vez() -> void:  # 033-AC7
	var carga := _carga()
	carga.pedir_guardar(Producto.Id.YERBA)
	assert_int(_guardados).is_equal(1)
	assert_int(_rechazos).is_equal(0)
	assert_int(carga.caja().ocupados()).is_equal(1)


func test_con_la_caja_llena_avisa_el_rechazo_y_no_avisa_un_guardado() -> void:  # 033-AC7
	# Las dos mitades importan: emitir las dos señales dejaría a la escena pintando un casillero
	# nuevo y un cartel de «no entra» al mismo tiempo, sin un solo error.
	var carga := _carga()
	for _casillero in range(Reglas.CASILLEROS_DE_LA_CAJA_DE_TRASLADO):
		carga.pedir_guardar(Producto.Id.FIDEOS)
	_guardados = 0
	carga.pedir_guardar(Producto.Id.YERBA)
	assert_int(_guardados).is_equal(0)
	assert_int(_rechazos).is_equal(1)
	assert_int(_ultimo_motivo).is_equal(CajaDeTraslado.Motivo.CAJA_LLENA)


func test_el_nodo_no_lleva_el_cupo_escrito_adentro() -> void:  # 033-AC7
	# Está medido que un `const CASILLEROS := 8` copiado fuera de `reglas.gd` pasa los dos gates
	# en verde. Ésta es la puerta que ningún gate cierra, y por eso el criterio la ata acá.
	var texto := FileAccess.get_file_as_string(CARGA)
	assert_str(texto).is_not_empty()
	var copias := RegEx.create_from_string(PATRONES_DEL_CUPO).search_all(texto)
	(
		assert_array(copias)
		. override_failure_message("`carga_de_la_caja.gd` lleva el cupo escrito adentro")
		. is_empty()
	)


func test_ningun_archivo_de_este_spec_toca_el_stock() -> void:  # 033-AC8
	# La caja es el contenedor que viaja; el estante es el destino, y es del 008. Sin esta
	# frontera los dos specs terminan moviendo unidades y ninguno sabe cuál las movió.
	for ruta: String in ARCHIVOS_DEL_SPEC:
		var texto := FileAccess.get_file_as_string(ruta)
		(
			assert_str(texto)
			. override_failure_message("`%s` está vacío o no existe" % ruta)
			. is_not_empty()
		)
		for patron: String in PATRONES_DEL_STOCK:
			(
				assert_bool(texto.contains(patron))
				. override_failure_message(
					"`%s` nombra `%s`: está tocando el stock" % [ruta, patron]
				)
				. is_false()
			)


func _carga() -> CargaDeLaCaja:
	var carga: CargaDeLaCaja = auto_free(CargaDeLaCaja.new())
	carga.producto_guardado.connect(_anotar_guardado)
	carga.guardado_rechazado.connect(_anotar_rechazo)
	return carga


func _anotar_guardado(_producto: Producto) -> void:
	_guardados += 1


func _anotar_rechazo(motivo: CajaDeTraslado.Motivo) -> void:
	_rechazos += 1
	_ultimo_motivo = motivo

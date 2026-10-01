## Las filas del balde, de sus gestos y de devolver una unidad a su caja, en la tabla del disco.
##
## Va aparte de `tabla_de_sonidos_test.gd` por el tope de métodos públicos por archivo. Como allá,
## se afirma primero que la tabla no es nula: un `.tres` que no carga hace abortar el caso antes de
## afirmar, y gdUnit4 lo reporta en verde.
extends GdUnitTestSuite

## Cada gesto con el balde, con la señal que lo dispara y el audio que suena.
const GESTOS := {
	EntradaSonora.Evento.BALDE_LLENADO: [&"balde_llenado", "SFX_OBJETO_Balde_Llenar"],
	EntradaSonora.Evento.BALDE_TENIDO: [&"balde_tenido", "SFX_OBJETO_Jabon_VertirEnBalde"],
	EntradaSonora.Evento.BALDE_VACIADO: [&"balde_vaciado", "SFX_OBJETO_Balde_Vaciar"],
	EntradaSonora.Evento.MOPA_MOJADA: [&"mopa_mojada", "SFX_OBJETO_Mopa_MojarEnBalde"],
}

## La señal de un uso de la limpieza que no cambió nada.
const USO_RECHAZADO := &"uso_rechazado"


func _tabla() -> TablaDeSonidos:
	var tabla := TablaDeSonidos.desde_disco()
	(
		assert_object(tabla)
		. override_failure_message("`%s` no carga o no es una tabla" % TablaDeSonidos.RUTA)
		. is_not_null()
	)
	return tabla


## El nombre del audio de una fila, o vacío si la fila no existe o no tiene audio.
static func _audio(entrada: EntradaSonora) -> String:
	if entrada == null or not entrada.tiene_sonido():
		return ""
	return entrada.variante(0).resource_path.get_file().get_basename()


func test_el_balde_suena_su_alzar_y_en_todo_lo_demas_su_dejar() -> void:  # AC-AMB-024
	var tabla := _tabla()
	var esperado := {
		EntradaSonora.Evento.OBJETO_AGARRADO: "SFX_OBJETO_Balde_Alzar",
		EntradaSonora.Evento.OBJETO_SOLTADO: "SFX_OBJETO_Balde_Dejar",
		EntradaSonora.Evento.PRODUCTO_COLOCADO: "SFX_OBJETO_Balde_Dejar",
		EntradaSonora.Evento.UNIDAD_DEVUELTA: "SFX_OBJETO_Balde_Dejar",
	}
	# Son los eventos de objeto y no una lista aparte: uno que se sume sin fila del balde sale acá.
	assert_array(esperado.keys()).contains_exactly_in_any_order(EntradaSonora.EVENTOS_DE_OBJETO)
	for evento: EntradaSonora.Evento in esperado:
		var fila := tabla.de(evento, EntradaSonora.Sonoridad.BALDE)
		var nombre: String = EntradaSonora.Evento.find_key(evento)
		(
			assert_str(_audio(fila))
			. override_failure_message("%s del balde no suena lo suyo" % nombre)
			. is_equal(esperado[evento])
		)
		if fila != null:
			assert_bool(fila.posicional).is_true()


func test_cada_gesto_con_el_balde_suena_su_audio_plano_y_por_efectos() -> void:  # AC-AMB-025
	var tabla := _tabla()
	for evento: EntradaSonora.Evento in GESTOS:
		var fila := tabla.de(evento)
		var nombre: String = EntradaSonora.Evento.find_key(evento)
		assert_object(fila).override_failure_message("%s no tiene fila" % nombre).is_not_null()
		if fila == null:
			continue
		assert_str(fila.senal).is_equal(GESTOS[evento][0])
		assert_str(_audio(fila)).is_equal(GESTOS[evento][1])
		assert_str(fila.bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)
		# Plano: su señal no trae el balde, y una fila del espacio sin lugar se rechaza.
		assert_bool(fila.posicional or fila.en_bucle).is_false()


func test_un_uso_de_la_limpieza_que_no_cambia_nada_no_tiene_fila() -> void:  # AC-AMB-025
	# El rechazo sale por su propia señal, y ninguna fila la escucha: el gesto rechazado no suena.
	var tabla := _tabla()
	assert_int(tabla.entradas.size()).is_greater(0)
	for entrada: EntradaSonora in tabla.entradas:
		assert_str(entrada.senal).is_not_equal(USO_RECHAZADO)


func test_devolver_suena_en_cada_sonoridad_lo_mismo_que_colocar() -> void:  # AC-AMB-026
	var tabla := _tabla()
	var sonoridades := EntradaSonora.Sonoridad.values()
	sonoridades.erase(EntradaSonora.Sonoridad.NINGUNA)
	for sonoridad: EntradaSonora.Sonoridad in sonoridades:
		var nombre: String = EntradaSonora.Sonoridad.find_key(sonoridad)
		var devolver := tabla.de(EntradaSonora.Evento.UNIDAD_DEVUELTA, sonoridad)
		var colocar := tabla.de(EntradaSonora.Evento.PRODUCTO_COLOCADO, sonoridad)
		(
			assert_object(devolver)
			. override_failure_message("devolver no tiene %s" % nombre)
			. is_not_null()
		)
		(
			assert_object(colocar)
			. override_failure_message("colocar no tiene %s" % nombre)
			. is_not_null()
		)
		if devolver == null or colocar == null:
			continue
		assert_str(devolver.senal).is_equal("unidad_devuelta")
		(
			assert_object(devolver.stream)
			. override_failure_message("devolver %s no suena como colocar" % nombre)
			. is_same(colocar.stream)
		)
		assert_str(devolver.bus).is_equal(colocar.bus)
		assert_bool(devolver.posicional).is_true()

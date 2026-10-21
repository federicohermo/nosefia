extends GdUnitTestSuite

const CUPO := 2


class UnidadFisica:
	extends RigidBody3D
	var datos: ObjetoDelAlmacen


func test_la_primera_jornada_no_cuenta_reponer_al_agarrar_y_colocar() -> void:  # AC-STK-094
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := Apertura.inventario_con_faltantes({}, {actroncito.id: CUPO})
	var obligatorias := Apertura.obligatorias(1)
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(turno, obligatorias, Ritmo.de_la_jornada(1))
	var reponer := reloj.obligatoria(Tarea.Tipo.REPONER)
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.reloj = reloj
	repositor.agarre = auto_free(Agarre.new())
	repositor.agarre.punto_de_carga = auto_free(Node3D.new())
	repositor.arrancar(Estante.new(inventario, [actroncito]))
	assert_object(reponer).is_null()
	assert_int(turno.tareas_cumplidas()).is_zero()
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_agarrar_de_la_gondola(actroncito.id, 0, nodo)).is_true()
	assert_object(reloj.obligatoria(Tarea.Tipo.REPONER)).is_null()
	assert_int(turno.tareas_cumplidas()).is_zero()
	repositor.pedir_colocar_de_la_mano(actroncito, 0)
	assert_object(reloj.obligatoria(Tarea.Tipo.REPONER)).is_null()
	assert_int(turno.tareas_cumplidas()).is_zero()
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(CUPO)


func test_la_segunda_noche_exige_reponer_sus_faltantes() -> void:  # AC-STK-094, AC-STK-035
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := Apertura.inventario_con_faltantes({actroncito.id: 1}, {actroncito.id: CUPO})
	var obligatorias := Apertura.obligatorias(2)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias), obligatorias)
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.reloj = reloj
	repositor.agarre = auto_free(Agarre.new())
	repositor.agarre.punto_de_carga = auto_free(Node3D.new())
	repositor.arrancar(Estante.new(inventario, [actroncito]))
	assert_bool(reloj.obligatoria(Tarea.Tipo.REPONER).completada()).is_false()

	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(actroncito.id, nodo)).is_true()
	repositor.pedir_colocar_de_la_mano(actroncito)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REPONER).completada()).is_true()
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(CUPO)

## Reponer al abrir la noche: una góndola que abre completa arranca con la obligatoria cumplida.
extends GdUnitTestSuite

const CUPO := 2


class UnidadFisica:
	extends RigidBody3D
	var datos: ObjetoDelAlmacen


func test_la_primera_jornada_abre_con_reponer_cumplida() -> void:  # AC-STK-094
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := Apertura.inventario_con_faltantes({}, {actroncito.id: CUPO}, Catalogo.todos())
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
	assert_bool(reponer.completada()).is_true()
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_agarrar_de_la_gondola(actroncito.id, 0, nodo)).is_true()
	assert_bool(reponer.completada()).is_false()
	repositor.pedir_colocar_de_la_mano(actroncito, 0)
	assert_bool(reponer.completada()).is_true()
	assert_int(inventario.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(CUPO)


func test_una_noche_con_faltantes_no_arranca_cumplida() -> void:  # AC-STK-094
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := Apertura.inventario_con_faltantes(
		{actroncito.id: 1}, {actroncito.id: CUPO}, Catalogo.todos()
	)
	var obligatorias := Apertura.obligatorias(2)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias), obligatorias)
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.reloj = reloj
	repositor.arrancar(Estante.new(inventario, [actroncito]))
	assert_bool(reloj.obligatoria(Tarea.Tipo.REPONER).completada()).is_false()

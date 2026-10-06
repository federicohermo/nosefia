## Conecta los usos de limpiar con el limpiador, y pinta lo que el piso contesta: las manchas, el
## agua del balde y la punta de la mopa.
##
## **No decide nada.** Qué hace cada útil sobre qué, qué jabón borra cada mancha y de qué color se
## ve cada cosa lo contesta `PisoDelLocal`. Acá se traduce lo que la mira tiene adelante al `id`
## con que el dominio lo nombra, y se pinta.
extends Node3D

## Los scripts de `escenas/` se preloadean para poder tiparlos: son cáscara y no declaran
## `class_name`.
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const ManchaQueSeVe := preload("res://src/escenas/objetos/mancha_en_el_piso.gd")
const UtilDeLimpieza := preload("res://src/escenas/objetos/util_de_limpieza.gd")
const ArtefactoDelBano := preload("res://src/escenas/puestos/artefacto_del_bano.gd")
const CharcosTemporales := preload("res://src/escenas/objetos/charcos_temporales.gd")
const PisoParaAgua := preload("res://src/escenas/objetos/piso_para_agua.gd")
const SuperficieLiquida := preload("res://src/escenas/objetos/superficie_liquida.gd")

@export var jugador: JugadorDelLocal
@export var limpiador: Limpiador
@export var suelo: StaticBody3D
@export var casco_del_local: StaticBody3D

## Los dos útiles que muestran su carga. Los jabones no cambian cómo se ven.
@export var balde: UtilDeLimpieza
@export var mopa: UtilDeLimpieza

var _posicion_previa := Vector3.ZERO
var _muestreada := false
var _intervalo_visual := 0.0
var _cantidad_mostrada := -1.0
var _charcos := CharcosTemporales.new()
var _recipiente_de_la_mojada: Node3D


func _init() -> void:
	# La escena también puede descartarse antes de entrar al árbol: el dibujo ya tiene dueño.
	add_child(_charcos)


func _physics_process(delta: float) -> void:
	var posicion := jugador.global_position
	var metros := posicion.distance_to(_posicion_previa) if _muestreada else 0.0
	_posicion_previa = posicion
	_muestreada = true
	limpiador.desgastar_mopa(jugador.id_en_la_mano(), delta, metros)
	_intervalo_visual += delta
	if _intervalo_visual < 0.15 or limpiador.piso() == null:
		return
	_intervalo_visual = 0.0
	var estado := limpiador.piso().mopa()
	if estado.carga_restante() == _cantidad_mostrada:
		return
	_cantidad_mostrada = estado.carga_restante()
	mopa.mostrar_la_carga(estado.esta_mojada(), estado.color(), estado.carga_restante())
	mopa.mostrar_goteo(estado.esta_mojada(), estado.color())


func _ready() -> void:
	jugador.uso_pedido.connect(_al_pedir_uso)
	jugador.uso_sobre_superficie_pedido.connect(_al_usar_la_superficie)
	jugador.paso_dado.connect(_al_dar_un_paso)
	limpiador.balde_llenado.connect(_al_llenar_el_balde)
	limpiador.balde_tenido.connect(_al_tenir_el_balde)
	limpiador.balde_vaciado.connect(_al_vaciar_el_balde)
	limpiador.mopa_mojada.connect(_al_mojar_la_mopa.unbind(1))
	limpiador.pasada_dada.connect(_al_dar_pasada)
	# **No se repinta acá.** El `_ready()` de un hijo corre ANTES que el de la raíz, así que el
	# limpiador todavía no tiene piso y `repintar()` moriría con un `Nonexistent function … in
	# base 'Nil'` que no nombra ni a este archivo ni al orden. Quien repinta es el cableado, al
	# abrir la jornada.


func _al_mojar_la_mopa() -> void:
	# El recorrido anterior a mojarla no pertenece a la carga recién recuperada.
	_posicion_previa = jugador.global_position
	_muestreada = true
	repintar()
	var artefacto := _recipiente_de_la_mojada as ArtefactoDelBano
	if artefacto != null:
		mopa.mostrar_la_mojada(artefacto, artefacto.punto_para_la_mopa(), Basis.IDENTITY)
	else:
		mopa.mostrar_la_mojada(balde)
	jugador.preparar_el_uso_en_la_mano()


func _al_tenir_el_balde(_agua: ReglasDeLaLimpieza.Agua) -> void:
	(balde.carga as SuperficieLiquida).mezclar(limpiador.piso().balde().color())
	repintar()


func _al_llenar_el_balde() -> void:
	(balde.carga as SuperficieLiquida).llenar()
	repintar()


func _al_vaciar_el_balde() -> void:
	(balde.carga as SuperficieLiquida).vaciar()
	repintar()


func _al_usar_la_superficie(punto: Vector3, normal: Vector3, cuerpo: PhysicsBody3D) -> void:
	var sectores: Array[Node3D] = []
	sectores.assign(manchas())
	var libre := PisoParaAgua.admite(
		{"position": punto, "normal": normal, "collider": cuerpo},
		suelo,
		sectores,
		[jugador.get_rid()],
		casco_del_local
	)
	var resultado := limpiador.humedecer_piso(jugador.id_en_la_mano(), libre)
	if resultado == ReglasDeLaLimpieza.Resultado.CHARCO_DEJADO:
		_charcos.dejar_en(punto, normal)


func reiniciar() -> void:
	_charcos.limpiar()
	_muestreada = false
	_cantidad_mostrada = -1.0
	(balde.carga as SuperficieLiquida).reiniciar()
	repintar()


func _al_dar_pasada(lugar: PisoDelLocal.Lugar) -> void:
	repintar()
	if not limpiador.piso().mancha_de(lugar).esta_limpia():
		return
	for mancha: ManchaQueSeVe in manchas():
		if mancha.lugar_de_la_mancha() == lugar:
			mancha.encoger()


func _al_dar_un_paso() -> void:
	for mancha: ManchaQueSeVe in manchas():
		var distancia := mancha.global_position - jugador.global_position
		if Vector2(distancia.x, distancia.z).length() <= 0.75:
			mancha.tocar_en(jugador.global_position)


## Deja las manchas, el balde y la mopa como los ve el dominio. Lo llama el cableado al abrir la
## jornada, y cada gesto que cambia algo.
func repintar() -> void:
	var piso := limpiador.piso()
	for mancha in manchas():
		var estado := piso.mancha_de(mancha.lugar_de_la_mancha())
		mancha.mostrar(not estado.esta_limpia(), estado.color(), estado.tipo())
	balde.mostrar_la_carga(piso.balde().tiene_agua(), piso.balde().color())
	mopa.mostrar_la_carga(
		piso.mopa().esta_mojada(), piso.mopa().color(), piso.mopa().carga_restante()
	)


## Las manchas que cuelgan de este puesto, en el orden del `.tscn`.
func manchas() -> Array[ManchaQueSeVe]:
	var encontradas: Array[ManchaQueSeVe] = []
	for hijo in get_children():
		var mancha := hijo as ManchaQueSeVe
		if mancha == null:
			continue
		encontradas.append(mancha)
	return encontradas


## El clic derecho llega por `uso_pedido`, que se reparte entre los puestos: acá se descarta lo que
## no es de limpiar.
func _al_pedir_uso(objetivo: Node3D) -> void:
	var mancha := objetivo as ManchaQueSeVe
	if mancha != null:
		mancha.tocar_en(jugador.global_position)
		limpiador.pasar(jugador.id_en_la_mano(), mancha.lugar_de_la_mancha())
		return
	var destino := _destino_de(objetivo)
	if destino != &"":
		_recipiente_de_la_mojada = objetivo
		limpiador.usar(jugador.id_en_la_mano(), destino)
		_recipiente_de_la_mojada = null


## Qué es, para limpiar, lo que la mira tiene adelante: un artefacto del baño dice qué es, y un
## útil se nombra por su `id`. Lo demás no es de este puesto.
func _destino_de(objetivo: Node3D) -> StringName:
	var artefacto := objetivo as ArtefactoDelBano
	if artefacto != null:
		return artefacto.destino_del_uso()
	var util := objetivo as UtilDeLimpieza
	if util != null:
		return util.datos.id
	return &""

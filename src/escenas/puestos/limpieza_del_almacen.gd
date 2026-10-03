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

@export var jugador: JugadorDelLocal
@export var limpiador: Limpiador

## Los dos útiles que muestran su carga. Los jabones no cambian cómo se ven.
@export var balde: UtilDeLimpieza
@export var mopa: UtilDeLimpieza


func _ready() -> void:
	jugador.uso_pedido.connect(_al_pedir_uso)
	jugador.paso_dado.connect(_al_dar_un_paso)
	limpiador.balde_llenado.connect(repintar)
	limpiador.balde_tenido.connect(repintar.unbind(1))
	limpiador.balde_vaciado.connect(repintar)
	limpiador.mopa_mojada.connect(_al_mojar_la_mopa.unbind(1))
	limpiador.pasada_dada.connect(_al_dar_pasada)
	# **No se repinta acá.** El `_ready()` de un hijo corre ANTES que el de la raíz, así que el
	# limpiador todavía no tiene piso y `repintar()` moriría con un `Nonexistent function … in
	# base 'Nil'` que no nombra ni a este archivo ni al orden. Quien repinta es el cableado, al
	# abrir la jornada.


func _al_mojar_la_mopa() -> void:
	repintar()
	mopa.mostrar_la_mojada(balde)


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
	mopa.mostrar_la_carga(piso.mopa().esta_mojada(), piso.mopa().color())


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
		limpiador.usar(jugador.id_en_la_mano(), destino)


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

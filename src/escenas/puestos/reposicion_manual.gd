## Agrupa los productos colocados y conserva cuerpos independientes al soltarlos.
extends Node3D

const ZonaDeReposicion := preload("res://src/escenas/puestos/zona_de_reposicion.gd")
const GrupoDelPiso := preload("res://src/escenas/objetos/grupo_del_piso.gd")
const CajaDelDeposito := preload("res://src/escenas/objetos/caja_de_productos.gd")
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const FANTASMA := preload("res://src/escenas/puestos/fantasma_de_reposicion.gdshader")

## Hasta dónde se busca piso debajo de una caja recién soltada, en metros.
const CAIDA_MAXIMA := 3.0

## Cuántas veces se parte al medio la búsqueda del borde de un apoyo.
const PASOS_DEL_BORDE := 12

## Cuánto puede variar la altura de un apoyo y seguir siendo el mismo, en metros.
const TOLERANCIA_DEL_APOYO := 0.02

## En cuántos pasos se trae hacia el jugador lo que se soltó adentro de un mueble.
const PASOS_PARA_DESATASCAR := 12

## En cuántos anillos se busca un lugar donde la caja entre, alrededor del punto apuntado.
const PASOS_PARA_ACERCAR := 6

## Cuánto puede errarle la mira al borde de una caja y seguir apuntándole, en metros.
const HOLGURA_DE_LA_MIRA := 0.1

## Hasta cuántas cajas se sube buscando la tapa de una pila. Es un tope de cordura: el techo del
## local corta antes.
const PISOS_DE_UNA_PILA := 8

## Cuántas direcciones alrededor del jugador se prueban para dejarle la caja al lado.
const LADOS_DEL_JUGADOR := 8

## Las exhibiciones que el jugador NO repone: un `MeshInstance3D` por bloque, en el orden de
## `DisposicionDeLaGondola.guias`.
##
## **Entra instanciada adentro de este puesto y no cableada por `@export`.** Apuntada desde
## `almacen.tscn` con un `NodePath` hacia otra rama llegaba en `null` con el `node_paths` bien
## escrito, y el puesto moría en `_preparar_la_guia()` con un `Cannot call method 'get_child' on
## a null value` que no nombra ni al `@export` ni a la escena. Siendo hija no hay nada que
## resolver. Medido el 2026-09-19.
const GUIA := "Guia"

@export var repositor: Repositor
@export var jugador: JugadorDelLocal
@export var estante: Node3D
@export var contenido: Node3D

## De dónde cuelga la caja mientras se la lleva: un punto del CUERPO y no de la cámara, porque
## pegada al pitch tapa la mira. Lo mueve este puesto y no `Agarre`, que no puede nombrarla.
@export var punto_de_la_caja: Node3D
## Dónde va cada unidad de la góndola, y en qué orden.
##
## **Ningún apoyo está escrito acá.** Antes eran doce posiciones y doce direcciones a mano, una
## fila recta por producto; ahora el modelo trae tandas de varias filas de fondo y por dos caras
## del mueble, y una recta ya no las describe. Las mide el `.blend` y llegan en este recurso.
@export var disposicion: DisposicionDeLaGondola

## Cuánto gira cada modelo para mostrarle el frente a la cámara, en grados.
##
## **No se elige: se deriva.** El modelo está horneado mirando hacia donde su tanda exhibe en la
## góndola, y la mano tiene que girarlo hasta que ese frente apunte a +Z, que es de donde mira
## la cámara. Con el frente en -X el giro es 90, en +X es 270, en +Z es 0 y en -Z es 180, y no
## hay más casos porque un estante exhibe hacia una de las cuatro caras del mueble.
##
## Los doce estuvieron mal hasta el 2026-09-19 y el síntoma es mudo: el producto se agarra de
## costado o dado vuelta, y no hay error ni test que lo diga. Se mira.
@export var giros_del_frente: Array[float] = []

var _unidades: Array[Node3D] = []
var _zonas: Array[StaticBody3D] = []
var _modelos: Array[Mesh] = []
var _formas: Array[ConvexPolygonShape3D] = []
var _grupos: Array[MultiMeshInstance3D] = []
## Cuántas copias de otras exhibiciones van al principio del dibujo de cada producto.
var _guias_sumadas: Array[int] = []
var _sueltos: Array[GrupoDelPiso] = []
var _disponible: ObjetoAgarrable = null


func preparar() -> void:
	_preparar_modelos()
	_preparar_grupos()
	_preparar_la_guia()
	estante.remove_from_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	for producto in Catalogo.todos():
		var casillero := ZonaDeReposicion.new()
		casillero.name = "ZonaDe" + producto.nombre
		casillero.producto = producto.id
		casillero.collision_layer = 0
		casillero.collision_mask = 0
		casillero.add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
		add_child(casillero)
		var limites := zona(producto.id)
		casillero.global_position = limites.get_center()
		var cuerpo := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = limites.size
		cuerpo.shape = forma
		casillero.add_child(cuerpo)
		var vista := MeshInstance3D.new()
		var modelo := _modelos[producto.id]
		vista.mesh = modelo
		vista.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		vista.position = _pie_del_fantasma(modelo)
		vista.material_override = _fantasma(modelo, 0.0, 1.0)
		casillero.add_child(vista)
		casillero.mallas = [vista]
		# **El foco va de `material_overlay` y el fantasma de `material_override`**, que es lo
		# que deja los dos encendidos a la vez. Enfocado sube el piso del titileo y nada más: lo
		# que distingue el hueco señalado del hueco a secas es que no llega a apagarse.
		casillero.material_de_foco = _fantasma(modelo, 0.45, 1.0)
		casillero.colocacion_pedida.connect(pedir_colocar)
		_zonas.append(casillero)
	jugador.uso_pedido.connect(retirar_de_la_caja)
	repositor.agarre.objeto_agarrado.connect(_actualizar_zonas)
	repositor.agarre.objeto_soltado.connect(_actualizar_zonas)
	repositor.agarre.objeto_soltado.connect(_desatascar_lo_soltado)
	repositor.agarre.objeto_soltado.connect(_agrupar_suelto)
	repositor.agarre.objeto_agarrado.connect(_retirar_del_grupo)
	repositor.agarre.objeto_soltado.connect(_apoyar_la_caja)
	repositor.agarre.objeto_agarrado.connect(_colgar_la_caja)
	_actualizar_zonas()


## Saca del mueble la unidad que se soltó adentro de él.
##
## **`Agarre` suelta a 1,2 m de la cámara y no puede mirar el mundo**: eso lo contesta la escena,
## y para las cajas lo hace `_apoyar_la_caja`. Una unidad de producto no tenía quién, así que
## parado contra la góndola —el pasillo mide 1,73 m— el punto de soltado caía adentro del
## estante: el producto quedaba detrás del panel, temblando contra la malla y sin rayo que lo
## alcance. Medido el 2026-09-18 soltando desde el pasillo de enfrente: terminaba 1,35 m
## adentro del mueble, detrás del fondo, a distancia `inf` de la mira.
##
## Se lo trae hacia el jugador hasta el primer lugar libre, que es de donde vino.
func _desatascar_lo_soltado(nodo: Node3D) -> void:
	var unidad := nodo as ObjetoAgarrable
	if unidad == null or not unidad.datos is UnidadDeProducto:
		return
	var forma: CollisionShape3D = unidad.get_node("Forma")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	# **Con el contorno del mueble además de lo que el producto choca.** El hueco de un estante es
	# lugar libre, y ahí la mercadería no tiene cuerpo: el producto quedaba adentro de la góndola,
	# encimado con ella y fuera de la vista. Medido: 10 de 75 soltadas alrededor de una góndola.
	consulta.collision_mask = unidad.collision_mask | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	consulta.exclude = [unidad.get_rid(), jugador.get_rid()]
	var espacio := get_world_3d().direct_space_state
	var atras := jugador.mira().basis.z.normalized()
	var paso := ReglasDelJugador.ALCANCE_DE_LA_MIRA / PASOS_PARA_DESATASCAR
	for intento in PASOS_PARA_DESATASCAR:
		# **La consulta lleva la vuelta que el producto tiene, no una derecha.** Una unidad se
		# suelta girada —por su frente y por lo que el cuerpo giró al caer—, y una forma
		# derecha ocupa otro volumen que el real: contesta libre donde el producto igual se
		# mete en el panel, que es el caso que esta función existe para sacar.
		consulta.transform = forma.global_transform
		if espacio.intersect_shape(consulta, 1).is_empty():
			return
		unidad.global_position += atras * paso


func _agrupar_suelto(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		_sueltos[nodo.datos.producto.id].agregar(nodo)


func _retirar_del_grupo(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		_sueltos[nodo.datos.producto.id].quitar(nodo)


## Saca una unidad de la caja apuntada, y sólo con la caja apoyada.
##
## El clic derecho llega por `uso_pedido`, que se reparte entre los puestos: acá se descarta lo
## que no es una caja. Cuándo entrega lo decide `ReglasDeLosObjetos`, donde tiene test.
func retirar_de_la_caja(objetivo: Node3D) -> void:
	var caja := objetivo as CajaDelDeposito
	if caja == null:
		return
	var la_lleva := repositor.agarre.manos().sostenido() == caja.datos
	if not ReglasDeLosObjetos.se_puede_retirar(la_lleva):
		return
	retirar(caja.producto)


## Baja a la cintura la caja recién levantada y le da su volumen al cuerpo del jugador.
func _colgar_la_caja(nodo: Node3D) -> void:
	if not nodo is CajaDelDeposito:
		return
	if punto_de_la_caja == null:
		push_error("ReposicionManual sin punto de la caja cableado: revisar almacen.tscn")
		return
	repositor.agarre.mover_lo_sostenido(punto_de_la_caja)
	jugador.ocupar_el_frente(true)
	despertar_lo_de_arriba(nodo)


## Apoya la caja recién soltada donde el jugador tiene la mira, derecha y de una.
##
## Soltar la deja viva: `Agarre` le saca la `freeze` al colgarla del punto de soltado, así que
## acá se le escribe el lugar y se la vuelve a congelar con `quedarse_quieta()`. El `top_level`
## vuelve a `false` por lo mismo, que es lo que soltar deja en `true`.
##
## **Soltar suelta.** Cuando la mira no señala un lugar donde la caja entre, o el camino hasta
## ahí está cortado, la caja va al piso al lado del jugador. Antes se le volvía a la mano, y eso
## era un clic que no hacía nada y no decía por qué: parado cerca de un mueble pasaba seguido.
func _apoyar_la_caja(nodo: Node3D) -> void:
	var caja := nodo as CajaDelDeposito
	if caja == null or punto_de_la_caja == null:
		return
	jugador.ocupar_el_frente(false)
	caja.top_level = false
	caja.global_basis = Basis.IDENTITY
	var apoyo := _apoyo_apuntado(caja)
	var llego := not apoyo.is_empty() and _cerca_de(caja, apoyo["position"])
	if not llego and not _al_lado_del_jugador(caja):
		# Ni donde apunta ni al lado: el jugador está metido en un hueco del tamaño de su cuerpo.
		repositor.agarre.pedir_agarrar(caja.datos, caja)
		return
	caja.quedarse_quieta()


## Deja la caja en el lugar más cercano al punto apuntado donde entra, sobre el mismo apoyo.
##
## **El cursor no tiene que caer en el punto exacto.** Apuntando pegado a una caja vecina, a un
## parante o a la punta de una tabla, la caja no entra justo ahí y entra diez centímetros al
## costado. Antes eso la mandaba al piso al lado del jugador, y el estante tenía agujeros: zonas
## donde soltar no subía la caja sin que nada dijera por qué.
##
## Se prueba el punto y después anillos cada vez más abiertos, hasta una caja de distancia. Sólo
## cuentan los lugares que siguen teniendo el mismo apoyo debajo: correrla no es bajarla.
func _cerca_de(caja: CajaDelDeposito, punto: Vector3) -> bool:
	var paso := _media_caja(caja).x / PASOS_PARA_ACERCAR * 2.0
	for anillo in PASOS_PARA_ACERCAR + 1:
		for lado in 1 if anillo == 0 else LADOS_DEL_JUGADOR:
			var corrido := Basis(Vector3.UP, TAU * lado / LADOS_DEL_JUGADOR) * Vector3.RIGHT
			var candidato := punto + corrido * paso * anillo
			if anillo > 0 and not _hay_apoyo(caja, candidato, punto.y):
				continue
			var destino := _apartado(caja, _lugar_sobre(caja, candidato))
			caja.global_position = _llevar_hasta(caja, destino)
			if (
				caja.global_position.distance_to(destino) < TOLERANCIA_DEL_APOYO
				and _entra_entera(caja)
				and not _le_queda_encima_al_jugador(caja)
			):
				return true
	return false


## Despierta lo que una caja estaba sosteniendo, y es lo que desarma una pila: sacada la de
## abajo, las de arriba caen hasta el primer apoyo que encuentren. Vale igual para una caja
## levantada y para una empujada: en los dos casos la caja se fue.
##
## Se mira desde **el lugar que dejó** y no desde donde está: para cuando `objeto_agarrado`
## avisa, `Agarre` ya la colgó de la mano, así que su `global_position` es el puño del jugador y
## ahí arriba no hay ninguna pila.
func despertar_lo_de_arriba(nodo: Node3D) -> void:
	var caja := nodo as CajaDelDeposito
	if caja == null:
		return
	_despertar_sobre(caja, caja.apoyo_que_dejo())


## Despierta lo apoyado sobre un lugar, y sigue hacia arriba desde cada caja que despierta.
##
## **En cascada, porque una pila es una cadena.** Despertar un solo piso alcanza para dos —la de
## encima cae, y la siguiente se entera de refilón—, y a partir de la tercera no. Una caja
## congelada es estática para el motor, y un cuerpo estático que se va no despierta a nadie.
## Lo que no es una caja sólo se despierta.
##
## Despertar de más no cuesta nada, y por eso no se comprueba si lo de arriba se iba a caer: si
## tiene otro apoyo, el motor lo deja donde está y lo vuelve a dormir. La `freeze` que se mira
## es el corte de la recursión: una caja ya despierta no se vuelve a visitar.
func _despertar_sobre(caja: CajaDelDeposito, lugar: Vector3) -> void:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var media := _media_caja(caja)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = Transform3D(
		Basis.IDENTITY.scaled(forma.scale), lugar + Vector3.UP * media.y * 2.0
	)
	# **Ésta es la única consulta del archivo que NO pregunta por la máscara de la caja**, y la
	# razón es el momento: esto corre desde `objeto_agarrado`, y para entonces `Agarre` ya le
	# puso la máscara en 0 para que no choque con nada mientras la llevan. Preguntando por ella
	# no contesta nadie y la pila se queda flotando. Acá filtra el tipo: lo rígido.
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	for choque in get_world_3d().direct_space_state.intersect_shape(consulta, 8):
		var encima := choque["collider"] as RigidBody3D
		if encima == null:
			continue
		var caja_de_arriba := encima as CajaDelDeposito
		if caja_de_arriba == null:
			encima.sleeping = false
		elif caja_de_arriba.freeze:
			caja_de_arriba.soltarse()
			_despertar_sobre(caja_de_arriba, caja_de_arriba.global_position)


## Deja la caja en el piso al lado del jugador. Devuelve si encontró dónde.
##
## Se prueba alrededor y no sólo adelante: cuando la mira no encontró lugar suele ser porque hay
## un mueble enfrente, y enfrente es justo donde no hay piso libre. Se arranca por donde el
## jugador mira, así que con lugar de sobra la caja cae adelante, que es lo que espera.
##
## El radio sale del cuerpo del jugador y del de la caja, y no de un número escrito acá: más
## cerca, la caja queda adentro del jugador y lo sube arriba de ella.
func _al_lado_del_jugador(caja: CajaDelDeposito) -> bool:
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var media := _media_caja(caja)
	var radio: float = (cuerpo.shape as CapsuleShape3D).radius + media.length()
	for lado in LADOS_DEL_JUGADOR:
		var vuelta := Basis(Vector3.UP, TAU * lado / LADOS_DEL_JUGADOR)
		var costado := jugador.global_position + vuelta * (jugador.frente() * radio)
		var golpe := _rayo(
			caja, costado + Vector3.UP * media.y, costado + Vector3.DOWN * CAIDA_MAXIMA
		)
		if golpe.is_empty() or not ReglasDeLosObjetos.se_puede_apoyar_en(golpe["normal"].y):
			continue
		caja.global_position = _lugar_sobre(caja, golpe["position"])
		if _entra_entera(caja) and not _le_queda_encima_al_jugador(caja):
			return true
	return false


## Si en el lugar donde quedó la caja no hay nada más. Se encoge para preguntar, porque apoyarse
## sobre algo es tocarlo.
##
## **El barrido solo no alcanza para saberlo.** `cast_motion` contesta que el movimiento entero
## es seguro cuando la forma arranca ya tocando algo, así que el tramo que baja la caja al
## estante la deja metida entre los paneles y dice que llegó. Medido: de 256 soltadas alrededor
## de la góndola del pasillo, 20 quedaban adentro de ella, todas a la altura del estante de
## arriba.
func _entra_entera(caja: CajaDelDeposito) -> bool:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var encogida := BoxShape3D.new()
	encogida.size = (
		(forma.shape as BoxShape3D).size * forma.scale - Vector3.ONE * ReglasDeLosObjetos.ROCE
	)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = encogida
	consulta.transform = Transform3D(Basis.IDENTITY, caja.global_position)
	consulta.collision_mask = caja.collision_mask
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


## Si la caja terminó adentro del cuerpo del jugador es que ahí no hay lugar para apoyarla, y
## dejarla igual lo sube arriba de ella. Entonces no se suelta: se la vuelve a la mano.
func _le_queda_encima_al_jugador(caja: CajaDelDeposito) -> bool:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.collision_mask = caja.collision_mask
	consulta.exclude = [caja.get_rid()]
	for choque in get_world_3d().direct_space_state.intersect_shape(consulta, 8):
		if choque["collider"] == jugador:
			return true
	return false


## Sobre qué superficie quiere el jugador apoyar la caja. Vacío cuando ahí no hay ninguna.
##
## Cuatro casos, y son distintos entre sí. **Una tapa** es el lugar, derecho. **El aire** no
## señala una superficie equivocada: no señala ninguna, y entonces el lugar es el piso que haya
## debajo del cursor. **El costado de otra caja** es apilar: con una caja justo enfrente el cursor
## cae ahí y no en su tapa. **Cualquier otra cara vertical** la resuelve `_apoyo_debajo()`.
func _apoyo_apuntado(caja: CajaDelDeposito) -> Dictionary:
	var ojo := jugador.mira()
	var lejos := ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA
	var golpe := _rayo(caja, ojo.origin, lejos)
	var rozada := _caja_rozada(caja, ojo.origin, lejos, golpe)
	if rozada == null:
		rozada = _caja_sobrevolada(caja, ojo.origin, lejos, golpe)
	if rozada != null:
		golpe = _tapa_de_la_pila(caja, rozada)
	elif golpe.is_empty():
		# Media caja hacia atrás: el rayo que baja no puede arrancar adentro de lo que la caja
		# va a ocupar.
		var punto := lejos + (ojo.origin - lejos).normalized() * _media_caja(caja).length()
		golpe = _rayo(caja, punto, punto + Vector3.DOWN * CAIDA_MAXIMA)
	elif not ReglasDeLosObjetos.se_puede_apoyar_en(golpe["normal"].y):
		var enfrente := golpe["collider"] as CajaDelDeposito
		if enfrente != null:
			golpe = _tapa_de_la_pila(caja, enfrente)
		else:
			var pared := golpe
			golpe = _apoyo_debajo(caja, ojo.origin, pared["position"])
			if golpe.is_empty():
				golpe = _tapa_de_ese_canto(caja, pared)
			if golpe.is_empty():
				golpe = _apoyo_al_pie(caja, pared)
	if golpe.is_empty() or not ReglasDeLosObjetos.se_puede_apoyar_en(golpe["normal"].y):
		return {}
	return golpe


## La caja que la mira pasó rozando, cuando lo que el rayo tocó queda detrás de ella.
##
## **Errarle al borde de una caja no es apuntar detrás de ella.** El rayo fino que pasa a un
## centímetro del canto pega en el piso del otro lado, y la caja iba a parar ahí: detrás de la
## pila, fuera de la vista. Se barre una esfera chica por la misma línea, y si lo primero que
## toca es una caja que está más cerca que lo apuntado, lo apuntado es esa caja.
##
## Lo que queda **delante** de la caja no cambia: apuntar al piso al pie de una pila sigue
## dejando la caja en el piso, porque ese lugar sí se ve.
func _caja_rozada(
	caja: CajaDelDeposito, desde: Vector3, hasta: Vector3, golpe: Dictionary
) -> CajaDelDeposito:
	if golpe.get("collider") is CajaDelDeposito:
		return null
	var esfera := SphereShape3D.new()
	esfera.radius = HOLGURA_DE_LA_MIRA
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = esfera
	consulta.transform = Transform3D(Basis.IDENTITY, desde)
	consulta.motion = hasta - desde
	consulta.collision_mask = caja.collision_mask
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	var espacio := get_world_3d().direct_space_state
	var avance: float = espacio.cast_motion(consulta)[1]
	if avance >= 1.0:
		return null
	var hasta_lo_apuntado := INF if golpe.is_empty() else desde.distance_to(golpe["position"])
	if consulta.motion.length() * avance >= hasta_lo_apuntado - HOLGURA_DE_LA_MIRA:
		return null
	consulta.transform.origin = desde + consulta.motion * avance
	consulta.motion = Vector3.ZERO
	# Con margen: en el punto de contacto la esfera toca la caja, y tocar no es solaparse.
	consulta.margin = TOLERANCIA_DEL_APOYO
	for choque in espacio.intersect_shape(consulta, 4):
		if choque["collider"] is CajaDelDeposito:
			return choque["collider"]
	return null


## La caja por encima de la que pasa la mira, a menos de una caja de altura de su tapa.
##
## **El cursor está donde quedaría la caja apilada.** Parado pegado a una caja, la mira puesta en
## su borde de arriba pasa por encima de la tapa y pega en el piso de atrás: la caja iba a parar
## ahí, detrás de la otra y fuera de la vista. Medido a 70 cm de una caja: entre -10 y -43 grados
## la mandaba atrás, y recién a -46 la apilaba.
##
## Se camina el rayo a pasos cortos, y en cada uno se mira hacia abajo una caja de altura. Se
## corta en lo que el rayo tocó: lo que queda detrás de una pared no cuenta.
func _caja_sobrevolada(
	caja: CajaDelDeposito, desde: Vector3, hasta: Vector3, golpe: Dictionary
) -> CajaDelDeposito:
	if golpe.get("collider") is CajaDelDeposito:
		return null
	var fin: Vector3 = golpe.get("position", hasta)
	var largo := desde.distance_to(fin)
	var alto := _media_caja(caja).y * 2.0
	var recorrido := HOLGURA_DE_LA_MIRA
	while recorrido < largo:
		var punto := desde.lerp(fin, recorrido / largo)
		var abajo := _rayo(caja, punto, punto + Vector3.DOWN * alto)
		if (
			abajo.get("collider") is CajaDelDeposito
			and ReglasDeLosObjetos.se_puede_apoyar_en(abajo["normal"].y)
		):
			return abajo["collider"]
		recorrido += HOLGURA_DE_LA_MIRA
	return null


## La tapa de lo que se apuntó de canto: el frente de una tabla o de un mostrador.
##
## Apuntarle al canto de una tabla es apuntarle a la tabla. Se mira apenas adentro de la cara
## tocada, desde una caja más arriba: si ahí hay una tapa, es la de ese mismo mueble. Una pared
## no la tiene —sigue para arriba—, y entonces esto no contesta nada.
func _tapa_de_ese_canto(caja: CajaDelDeposito, canto: Dictionary) -> Dictionary:
	var adentro: Vector3 = -canto["normal"]
	adentro.y = 0.0
	var punto: Vector3 = canto["position"] + adentro.normalized() * HOLGURA_DE_LA_MIRA
	var alto := _media_caja(caja).y * 2.0
	return _rayo(caja, punto + Vector3.UP * alto, punto + Vector3.DOWN * TOLERANCIA_DEL_APOYO)


## El apoyo que hay al pie de una pared, debajo del punto apuntado y a cualquier altura.
##
## **La pared de atrás de un estante señala el estante.** `_apoyo_debajo()` busca hasta una caja
## de altura, y más arriba que eso la mira sobre la pared no daba nada: la caja iba al piso al
## lado del jugador, y la zona donde soltar subía la caja tenía un techo invisible. Se baja
## derecho desde media caja afuera de la pared, que es donde la caja va a quedar.
func _apoyo_al_pie(caja: CajaDelDeposito, pared: Dictionary) -> Dictionary:
	var afuera: Vector3 = pared["normal"]
	afuera.y = 0.0
	afuera = afuera.normalized()
	var media := _media_caja(caja)
	var desde: Vector3 = pared["position"] + afuera * media.length()
	# **Media caja de tolerancia a lo largo de la pared, y gana el apoyo más alto.** A diez
	# centímetros de la punta de un estante lo que hay debajo ya es el piso, y nadie que apunte
	# ahí con una caja de sesenta quiere el piso.
	var mejor := {}
	for corrido: float in [0.0, -media.x, media.x]:
		var punto := desde + afuera.cross(Vector3.UP) * corrido
		var golpe := _rayo(caja, punto, punto + Vector3.DOWN * CAIDA_MAXIMA)
		if golpe.is_empty() or not ReglasDeLosObjetos.se_puede_apoyar_en(golpe["normal"].y):
			continue
		if mejor.is_empty() or golpe["position"].y > mejor["position"].y + TOLERANCIA_DEL_APOYO:
			mejor = golpe
	return mejor


## La tapa de la caja más alta de la pila que arranca en `base`.
##
## Se sube de a una: desde el centro de cada caja, un rayo corto hacia arriba encuentra la que
## tiene apoyada encima. Un rayo desde bien arriba no sirve, porque en el depósito pegaría en el
## estante de arriba y no en la pila.
func _tapa_de_la_pila(caja: CajaDelDeposito, base: CajaDelDeposito) -> Dictionary:
	var tope := base
	for piso in PISOS_DE_UNA_PILA:
		var centro := tope.global_position
		var techo := centro + Vector3.UP * (_media_caja(tope).y + TOLERANCIA_DEL_APOYO)
		var encima := _rayo(caja, centro, techo).get("collider") as CajaDelDeposito
		if encima == null or encima == tope:
			break
		tope = encima
	var tapa := tope.global_position + Vector3.UP * _media_caja(tope).y
	return _rayo(
		caja, tapa + Vector3.UP * TOLERANCIA_DEL_APOYO, tapa + Vector3.DOWN * TOLERANCIA_DEL_APOYO
	)


## La tapa que hay debajo del punto apuntado, y sólo si la caja apoyada ahí lo taparía.
##
## **La mira no es un píxel, y el hueco de un estante es aire**: el rayo lo cruza y pega en el
## panel del fondo, así que apuntar al medio de un estante no daba el estante. Lo que el jugador
## está mirando es el hueco, y el lugar es la tapa que ese hueco tiene abajo.
##
## **El techo de la búsqueda es la caja misma, y de ahí sale la regla entera: si la caja apoyada
## ahí no llega a tapar el punto que apuntaste, no es ése el lugar.** Sin ese techo se vuelve a
## lo de antes —un rayo hasta el piso—, y entonces el frente de la madera manda la caja al suelo
## y el ángulo de la vista decide en lugar del cursor. Medido a 0,9 m del estante del depósito:
## adentro del hueco la tapa queda entre 0,12 y 0,73 m debajo de lo apuntado; desde el frente de
## la madera, a 1,6.
func _apoyo_debajo(caja: CajaDelDeposito, ojo: Vector3, punto: Vector3) -> Dictionary:
	var media := _media_caja(caja)
	var desde := punto + (ojo - punto).normalized() * media.length()
	return _rayo(caja, desde, desde + Vector3.DOWN * media.y * 2.0)


## Dónde va el centro de la caja para quedar encima del punto apoyado y adentro de su huella.
func _lugar_sobre(caja: CajaDelDeposito, punto: Vector3) -> Vector3:
	var media := _media_caja(caja)
	var huella := _huella_del_apoyo(caja, punto)
	var lugar := punto + Vector3.UP * media.y
	lugar.x = _adentro(lugar.x, huella.position.x + media.x, huella.end.x - media.x)
	lugar.z = _adentro(lugar.z, huella.position.z + media.z, huella.end.z - media.z)
	return lugar


## Corre el destino hacia afuera de lo que lo estorba, en horizontal.
##
## Apuntar al piso al pie de un mueble da un lugar donde la caja no entra: media caja queda
## adentro de la madera, y entonces el barrido que la baja se frena a mitad de camino.
func _apartado(caja: CajaDelDeposito, destino: Vector3) -> Vector3:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = Transform3D(Basis.IDENTITY.scaled(forma.scale), destino)
	consulta.collision_mask = caja.collision_mask
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	# Con margen: correrla hasta el contacto justo la deja rozando, y entonces no baja.
	consulta.margin = TOLERANCIA_DEL_APOYO
	var contactos := get_world_3d().direct_space_state.collide_shape(consulta, 1)
	if contactos.size() < 2:
		return destino
	var salida: Vector3 = contactos[0] - contactos[1]
	salida.y = 0.0
	return destino + salida


## Hasta dónde sigue habiendo superficie a la misma altura alrededor del punto apuntado.
##
## Se mide con rayos y no con el volumen del cuerpo: un mostrador es un pedazo del `.tscn` del
## edificio entero, así que su volumen abarca el local y no dice nada de dónde termina la tapa.
## Se tantea hasta una caja de distancia hacia cada lado: con eso alcanza para correrla media
## caja y que entre entera.
func _huella_del_apoyo(caja: CajaDelDeposito, punto: Vector3) -> AABB:
	var huella := AABB(punto, Vector3.ZERO)
	for direccion: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		huella = huella.expand(punto + direccion * _borde_del_apoyo(caja, punto, direccion))
	return huella


## Cuánto sigue habiendo apoyo desde el punto hacia un lado, partiendo al medio.
##
## A pasos fijos el canto de un apoyo del tamaño de la caja cae entre dos pasos, y entonces la
## huella sale más chica que la caja y la deja descentrada justo donde tenía que entrar justa.
func _borde_del_apoyo(caja: CajaDelDeposito, punto: Vector3, direccion: Vector3) -> float:
	var cerca := 0.0
	var lejos := 2.0 * _media_caja(caja).x
	if _hay_apoyo(caja, punto + direccion * lejos, punto.y):
		return lejos
	for paso in PASOS_DEL_BORDE:
		var medio := (cerca + lejos) / 2.0
		if _hay_apoyo(caja, punto + direccion * medio, punto.y):
			cerca = medio
		else:
			lejos = medio
	return cerca


## Si debajo de ese punto hay superficie a la altura dada.
func _hay_apoyo(caja: CajaDelDeposito, donde: Vector3, altura: float) -> bool:
	var golpe := _rayo(
		caja, donde + Vector3.UP * TOLERANCIA_DEL_APOYO, donde + Vector3.DOWN * TOLERANCIA_DEL_APOYO
	)
	return not golpe.is_empty() and absf(golpe["position"].y - altura) < TOLERANCIA_DEL_APOYO


## Todas las consultas de este puesto preguntan por la máscara DE LA CAJA, y no por la de todas
## las capas, que es lo que contesta un `PhysicsQueryParameters3D` recién hecho.
##
## Lo que se pregunta es dónde entra la caja, así que lo que vale es contra qué choca la caja.
## En la capa 2 están las cosas que sólo existen para la mira —la mancha del piso, el casillero
## de la góndola—, y una mancha es un cilindro de 6 cm contra una malla de 1 mm: preguntando por
## todas las capas, apoyar una caja sobre una mancha la dejaba flotando 6 cm sobre una tapa
## invisible, y el barrido la frenaba contra ella.
##
## Se lee del nodo y no de una constante porque es la pregunta honesta —contra qué choca ESTA
## caja—, igual que `jugador.gd` al medir la caída. El precio es que `Agarre` le pone la máscara
## en 0 mientras la lleva: esto corre desde `objeto_soltado`, que `soltar()` emite DESPUÉS de
## devolvérsela. Emitirlo antes dejaría todas estas consultas contestando vacío.
func _rayo(caja: CajaDelDeposito, desde: Vector3, hasta: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta, caja.collision_mask)
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(consulta)


## Hasta dónde llega la caja yendo de la mano al destino: sube, entra y baja.
##
## Derecho no alcanza: el labio de un estante queda justo a la altura a la que se la lleva, así
## que el camino recto choca contra él y la caja nunca entra. Una persona la sube y la mete. Y
## nunca por debajo de la mano: bajarla primero la hace chocar contra la tapa de un mostrador.
##
## **Se prueba desde la mano y, si se traba, desde el cuerpo.** Parado contra un estante, la mano
## queda debajo del canto de la tabla de arriba, y la subida choca con él por un par de
## centímetros: la caja no llegaba a un lugar donde entraba de sobra.
func _llevar_hasta(caja: CajaDelDeposito, destino: Vector3) -> Vector3:
	var mano := punto_de_la_caja.global_position
	var cuerpo := Vector3(jugador.global_position.x, mano.y, jugador.global_position.z)
	var llegada := mano
	for salida: Vector3 in [mano, cuerpo]:
		var alto := maxf(salida.y, destino.y + _media_caja(caja).y)
		var arriba := _barrer(caja, salida, Vector3(salida.x, alto, salida.z))
		var adentro := _barrer(caja, arriba, Vector3(destino.x, arriba.y, destino.z))
		llegada = _barrer(caja, adentro, destino)
		if llegada.distance_to(destino) < TOLERANCIA_DEL_APOYO:
			break
	return llegada


## El punto más cercano a `hasta` al que la caja llega sin meterse adentro de nada.
func _barrer(caja: CajaDelDeposito, desde: Vector3, hasta: Vector3) -> Vector3:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = Transform3D(Basis.IDENTITY.scaled(forma.scale), desde)
	consulta.motion = hasta - desde
	consulta.collision_mask = caja.collision_mask
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	var avance: float = get_world_3d().direct_space_state.cast_motion(consulta)[0]
	return desde + consulta.motion * avance


## El valor adentro del rango, o su medio cuando el rango viene dado vuelta.
static func _adentro(valor: float, desde: float, hasta: float) -> float:
	if desde > hasta:
		return (desde + hasta) / 2.0
	return clampf(valor, desde, hasta)


func _media_caja(caja: CajaDelDeposito) -> Vector3:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	return (forma.shape as BoxShape3D).size * forma.scale / 2.0


func pedir_colocar(id: Producto.Id) -> void:
	repositor.pedir_colocar_de_la_mano(Catalogo.de(id))
	_actualizar_zonas()


func _actualizar_zonas(_nodo: Node3D = null) -> void:
	var unidad := repositor.agarre.manos().sostenido() as UnidadDeProducto
	for casillero in _zonas:
		var activo: bool = unidad != null and unidad.producto.id == casillero.producto
		casillero.collision_layer = 2 if activo else 0
		casillero.visible = activo
		casillero.global_position = _apoyo(casillero.producto) + Vector3.UP * 0.15


## La tolerancia permite apuntar al entorno del producto, no a un píxel.
func zona(id: Producto.Id) -> AABB:
	var tamano := _modelos[id].get_aabb().size
	tamano.y = 0.3
	return AABB(_apoyo(id) - Vector3(tamano.x / 2, 0, tamano.z / 2), tamano).grow(0.25)


## Dónde se apoya la próxima unidad: el lugar de la primera copia que todavía no está repuesta.
##
## Es el **pie** de esa copia y no su centro: la copia trae el origen de su modelo, que según el
## producto cae en el medio o en la base, y el casillero de la góndola se dibuja desde el
## estante hacia arriba.
func _apoyo(id: Producto.Id) -> Vector3:
	var producto := Catalogo.de(id)
	var cantidad := repositor.estante().unidades_en_gondola(producto)
	# **Con el estante lleno no hay próxima, y se marca la última.** El casillero se reubica en
	# cada cambio, también cuando ya no entra nada: sin el tope, el índice se va una copia más
	# allá del bloque y el recurso contesta la identidad, que deja la marca en el origen del
	# local. Colocar de más lo rechaza `Estante`, que es donde esa regla tiene test.
	return _posicion(id, mini(cantidad, repositor.estante().cupo(producto) - 1))


func _posicion(id: Producto.Id, indice: int) -> Vector3:
	var bloque := disposicion.principales[id]
	var copia := DisposicionDeLaGondola.copia(bloque, _primera_reponible(id) + indice)
	# **El pie sale de la caja ya transformada y no de la local.** Una copia con la inclinación
	# que el estante le da ocupa otro volumen que el modelo derecho, y restarle media altura
	# local la deja 2 mm fuera de su marca: justo lo que el casillero dibuja en el piso.
	var caja := copia * _modelos[id].get_aabb()
	return caja.get_center() - Vector3.UP * caja.size.y / 2.0


## Desde qué copia arranca el tramo que el jugador repone: las de antes son la guía, y están
## siempre a la vista.
##
## **El cupo sale del dominio y no de un número de acá.** El bloque tiene lo que el artista puso
## y el cupo dice cuántas de esas quedan vacías al abrir; escribir el corte en esta capa sería el
## mismo valor en dos lugares, que es justo lo que `Estante.cupo()` existe para evitar.
func _primera_reponible(id: Producto.Id) -> int:
	var bloque := disposicion.principales[id]
	return DisposicionDeLaGondola.copias(bloque) - repositor.estante().cupo(Catalogo.de(id))


func _preparar_modelos() -> void:
	for grupo: MeshInstance3D in contenido.get_children():
		var herramienta := SurfaceTool.new()
		herramienta.append_from(grupo.mesh, 0, Transform3D(grupo.global_basis, Vector3.ZERO))
		herramienta.set_material(grupo.mesh.surface_get_material(0))
		_modelos.append(herramienta.commit())
	for modelo in _modelos:
		# **El casco sale de `create_convex_shape` y no de `get_faces()`.** Los vértices crudos
		# vienen repetidos —tres por cada esquina de una caja—, y con esa nube el solver arma un
		# manifiesto de contacto sucio: un producto de caras planas apoyado no termina de
		# asentarse y se lo ve titilar. Medido el 2026-09-18: una caja baja de 36 puntos a 8, y
		# el producto de más caras del catálogo, de 1146 a 129.
		var forma := modelo.create_convex_shape(true, false)
		var puntos := forma.points
		var centro := modelo.get_aabb().get_center()
		for indice in puntos.size():
			puntos[indice] -= centro
		forma.points = puntos
		_formas.append(forma)


func _preparar_grupos() -> void:
	for producto in Catalogo.todos():
		var malla := _modelos[producto.id]
		var grupo := _dibujar(
			"ProductosDe" + producto.nombre, malla, disposicion.principales[producto.id]
		)
		_grupos.append(grupo)
		_guias_sumadas.append(0)
		var sueltos := GrupoDelPiso.new()
		sueltos.name = "SueltosDe" + producto.nombre
		sueltos.preparar(malla, repositor.estante().cupo(producto))
		add_child(sueltos)
		_sueltos.append(sueltos)


## El fantasma que marca dónde va la próxima unidad: el envase mismo, transparente y titilando.
##
## Se arma uno por casillero y no uno compartido porque cada uno lleva **su** textura: lo que
## indica no es sólo el lugar, es qué producto va en ese lugar.
func _fantasma(modelo: Mesh, minima: float, maxima: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FANTASMA
	var base := modelo.surface_get_material(0) as BaseMaterial3D
	if base != null:
		material.set_shader_parameter("textura", base.albedo_texture)
	material.set_shader_parameter("opacidad_minima", minima)
	material.set_shader_parameter("opacidad_maxima", maxima)
	return material


## Dónde se cuelga el fantasma adentro del casillero para que su base caiga en el apoyo.
##
## El casillero está 15 cm por encima del apoyo —lo necesita para que la mira lo alcance—, así
## que el fantasma baja esos 15 cm y se corre hasta que el centro de su base quede en el origen.
func _pie_del_fantasma(modelo: Mesh) -> Vector3:
	var caja := modelo.get_aabb()
	var centro_de_la_base := Vector3(
		caja.position.x + caja.size.x / 2.0, caja.position.y, caja.position.z + caja.size.z / 2.0
	)
	return Vector3.DOWN * 0.15 - centro_de_la_base


## Las exhibiciones que no cambian. Se dibujan una vez y quedan enteras: nada las vende ni las
## repone, y por eso no se guarda el nodo.
##
## **Se juntan en la menor cantidad de dibujos posible.** Cada nodo que se dibuja le cuesta al
## motor su preparación, y en la web esa preparación es lo que más pesa del cuadro: medido el
## 2026-09-21, las guías sueltas eran el 42 % del tiempo de dibujo mirando la góndola. Una guía
## que muestra un producto del catálogo va al principio del dibujo de ese producto, donde
## `visible_instance_count` no llega a cortar. Las demás se juntan entre ellas.
##
## Van juntas si comparten malla **y material**: la misma caja lleva texturas distintas según el
## producto que muestra.
func _preparar_la_guia() -> void:
	var destino := {}
	for id in contenido.get_child_count():
		destino[_clave(contenido.get_child(id).mesh)] = id
	var sumadas: Array[PackedFloat32Array] = []
	sumadas.resize(_grupos.size())
	var sueltas := {}
	for indice in disposicion.guias.size():
		var modelo := get_node(GUIA).get_child(indice) as MeshInstance3D
		var clave := _clave(modelo.mesh)
		var bloque := disposicion.guias[indice]
		if destino.has(clave):
			var id: int = destino[clave]
			var base := (contenido.get_child(id) as Node3D).global_basis
			sumadas[id].append_array(_rebasar(bloque, modelo.global_basis, base))
		elif sueltas.has(clave):
			var primera: MeshInstance3D = sueltas[clave][0]
			sueltas[clave][1].append_array(
				_rebasar(bloque, modelo.global_basis, primera.global_basis)
			)
		else:
			sueltas[clave] = [modelo, bloque.duplicate()]
	for id in _grupos.size():
		var copias := _grupos[id].multimesh
		# Del recurso y no de `copias.buffer`: leerlo del dibujo obliga a bajarlo de la GPU.
		var bloque := sumadas[id] + disposicion.principales[id]
		copias.instance_count = DisposicionDeLaGondola.copias(bloque)
		copias.buffer = bloque
		_guias_sumadas[id] = DisposicionDeLaGondola.copias(sumadas[id])
		copias.visible_instance_count = _primera_dibujada(id)
	var numero := 0
	for clave in sueltas:
		var modelo: MeshInstance3D = sueltas[clave][0]
		var herramienta := SurfaceTool.new()
		herramienta.append_from(modelo.mesh, 0, Transform3D(modelo.global_basis, Vector3.ZERO))
		herramienta.set_material(modelo.mesh.surface_get_material(0))
		_dibujar("Guia" + str(numero), herramienta.commit(), sueltas[clave][1])
		numero += 1


## Qué tienen que compartir dos exhibiciones para dibujarse juntas: la malla y el material.
func _clave(malla: Mesh) -> int:
	var material := malla.surface_get_material(0)
	return hash(
		[
			malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
			material.resource_name if material != null else "",
		]
	)


## Las copias de un bloque horneado con `desde`, pasadas a una malla horneada con `hacia`.
##
## Cada exhibición hornea la vuelta de su modelo en la malla, y sus copias son relativas a esa
## vuelta. Para dibujarlas con la malla de otra, cada copia se queda con su lugar y cambia la
## vuelta: `copia · desde · hacia⁻¹`, que puesta sobre la otra malla da la misma unidad.
func _rebasar(bloque: PackedFloat32Array, desde: Basis, hacia: Basis) -> PackedFloat32Array:
	var cambio := desde * hacia.inverse()
	var salida := PackedFloat32Array()
	for indice in DisposicionDeLaGondola.copias(bloque):
		var copia := DisposicionDeLaGondola.copia(bloque, indice)
		var b := copia.basis * cambio
		var o := copia.origin
		salida.append_array(
			[b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z]
		)
	return salida


## Desde qué copia del dibujo arranca el tramo que el jugador repone: las guías del propio
## bloque más las de otras exhibiciones que se le sumaron adelante.
func _primera_dibujada(id: Producto.Id) -> int:
	return _guias_sumadas[id] + _primera_reponible(id)


## Un `MultiMeshInstance3D` con todas las copias de un bloque, prendidas.
##
## **El buffer se escribe tal cual viene del recurso**: cada copia ya trae su lugar y su vuelta
## medidos del modelo, y el nodo cuelga de este puesto, que está sin transformar. Convertirlas
## acá sería medirlas dos veces.
func _dibujar(nombre: String, malla: Mesh, bloque: PackedFloat32Array) -> MultiMeshInstance3D:
	var grupo := MultiMeshInstance3D.new()
	grupo.name = nombre
	grupo.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var copias := MultiMesh.new()
	copias.transform_format = MultiMesh.TRANSFORM_3D
	copias.mesh = malla
	copias.instance_count = DisposicionDeLaGondola.copias(bloque)
	copias.buffer = bloque
	copias.visible_instance_count = copias.instance_count
	grupo.multimesh = copias
	add_child(grupo)
	return grupo


func retirar(id: Producto.Id) -> void:
	var unidad := _disponible
	_disponible = null
	if unidad == null:
		unidad = OBJETO.instantiate()
		add_child(unidad)
		_unidades.append(unidad)
		unidad.add_collision_exception_with(jugador)
	# El frente de cada modelo se alinea antes de darle la inclinación de la mano.
	unidad.orientacion_en_mano = (
		Basis.from_euler(Vector3(deg_to_rad(-17), deg_to_rad(-20), 0))
		* Basis(Vector3.UP, deg_to_rad(giros_del_frente[id]))
	)
	unidad.collision_layer = 1
	# Choca también con el contorno de los muebles: caída al pie de una góndola, la unidad rodaba
	# hacia adentro del estante de abajo.
	unidad.collision_mask = 1 | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	if not repositor.pedir_retirar(id, unidad):
		_guardar_cuerpo(unidad)
		return
	unidad.show()
	var malla := _modelos[id]
	var limites := malla.get_aabb()
	var vista: MeshInstance3D = unidad.get_node("Malla")
	vista.mesh = malla
	vista.position = -limites.get_center()
	unidad.get_node("Forma").shape = _formas[id]


func depositar(unidad: Node3D, producto: Producto, unidades: int) -> void:
	_grupos[producto.id].multimesh.visible_instance_count = (
		_primera_dibujada(producto.id) + unidades
	)
	_guardar_cuerpo(unidad)


func _guardar_cuerpo(unidad: ObjetoAgarrable) -> void:
	unidad.hide()
	unidad.reparent(self)
	unidad.freeze = true
	unidad.collision_layer = 0
	unidad.collision_mask = 0
	unidad.linear_velocity = Vector3.ZERO
	unidad.angular_velocity = Vector3.ZERO
	unidad.datos = null
	if _disponible != null:
		_unidades.erase(unidad)
		unidad.queue_free()
	else:
		_disponible = unidad


func limpiar() -> void:
	for grupo in _sueltos:
		while not grupo.cuerpos.is_empty():
			grupo.quitar(grupo.cuerpos[-1])
	for unidad in _unidades:
		if is_instance_valid(unidad):
			unidad.queue_free()
	_unidades.clear()
	_disponible = null
	# **Se recorre lo que hay y no el catálogo.** La apertura de la jornada llama acá antes de
	# que el puesto se haya preparado, y entonces todavía no hay un grupo por producto: indexar
	# por `id` mata el primer cuadro con un `Out of bounds` que no nombra ni a la jornada ni a
	# este puesto.
	for id in _grupos.size():
		_grupos[id].multimesh.visible_instance_count = _primera_dibujada(id)
	_actualizar_zonas()

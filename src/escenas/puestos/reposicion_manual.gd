## Agrupa los productos colocados y conserva cuerpos independientes al soltarlos.
extends Node3D

const ZonaDeReposicion := preload("res://src/escenas/puestos/zona_de_reposicion.gd")
const GrupoDelPiso := preload("res://src/escenas/objetos/grupo_del_piso.gd")
const CajaDelDeposito := preload("res://src/escenas/objetos/caja_de_productos.gd")
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const BORDE := preload("res://src/escenas/puestos/borde_de_reposicion.gdshader")

## Hasta dónde se busca piso debajo de una caja recién soltada, en metros.
const CAIDA_MAXIMA := 3.0

## Cuántas veces se parte al medio la búsqueda del borde de un apoyo.
const PASOS_DEL_BORDE := 12

## Cuánto puede variar la altura de un apoyo y seguir siendo el mismo, en metros.
const TOLERANCIA_DEL_APOYO := 0.02

## Cuántas direcciones alrededor del jugador se prueban para dejarle la caja al lado.
const LADOS_DEL_JUGADOR := 8

@export var repositor: Repositor
@export var jugador: JugadorDelLocal
@export var estante: Node3D
@export var contenido: Node3D

## De dónde cuelga la caja mientras se la lleva: un punto del CUERPO y no de la cámara, porque
## pegada al pitch tapa la mira. Lo mueve este puesto y no `Agarre`, que no puede nombrarla.
@export var punto_de_la_caja: Node3D
## Dónde se apoya la PRIMERA unidad de cada producto, en el orden de `Producto.Id`.
@export var apoyos: Array[Vector3] = []

## Hacia dónde crece la fila de cada producto sobre el estante.
##
## **La góndola exhibe por dos caras y no por una**, y de ahí que esto sea por producto. El panel
## de fondo va de z = -3,04 a 0,60: ahí el estante tiene respaldo, mira al pasillo y la fila corre
## a lo largo, en +Z. Desde z = -4,17 hasta -3,04 no hay panel —se ve de lado a lado—, así que esa
## punta es la **cabecera**: exhibe hacia su extremo y la fila entra hacia adentro del mueble, en
## +X. Un producto del pasillo puesto en la cabecera queda parado en un marco vacío.
@export var direcciones: Array[Vector3] = []

## Cuánto gira cada modelo para mostrarle el frente a la cámara, en grados.
##
## Sale de hacia dónde está horneado el modelo, que es lo mismo que decide su cara de la góndola:
## los del pasillo miran a -X y los de la cabecera a -Z. **El estante coloca las copias sin
## rotarlas**, así que un modelo horneado hacia el lado equivocado se ve de costado y ningún
## número de acá lo arregla: se corrige la malla.
@export var giros_del_frente: Array[float] = []

var _unidades: Array[Node3D] = []
var _zonas: Array[StaticBody3D] = []
var _modelos: Array[Mesh] = []
var _formas: Array[ConvexPolygonShape3D] = []
var _grupos: Array[MultiMeshInstance3D] = []
var _sueltos: Array[GrupoDelPiso] = []
var _disponible: ObjetoAgarrable = null


func preparar() -> void:
	_preparar_modelos()
	_preparar_grupos()
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
		var malla := QuadMesh.new()
		var tamano := _modelos[producto.id].get_aabb().size
		malla.size = Vector2(tamano.x, tamano.z) + Vector2.ONE * 0.02
		vista.position.y = -0.15 + 0.005
		vista.rotation.x = -PI / 2
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0, 0, 0, 0)
		malla.material = material
		vista.mesh = malla
		casillero.add_child(vista)
		casillero.mallas = [vista]
		var borde := ShaderMaterial.new()
		borde.shader = BORDE
		borde.set_shader_parameter("color", IndicacionDelFoco.COLOR)
		borde.set_shader_parameter("tamano", malla.size)
		casillero.material_de_foco = borde
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
## alcance. Medido con el actroncito soltado desde x = 2,6: terminaba en x = 1,25, detrás del
## fondo, a distancia `inf` de la mira.
##
## Se lo trae hacia el jugador hasta el primer lugar libre, que es de donde vino.
func _desatascar_lo_soltado(nodo: Node3D) -> void:
	var unidad := nodo as ObjetoAgarrable
	if unidad == null or not unidad.datos is UnidadDeProducto:
		return
	var forma: CollisionShape3D = unidad.get_node("Forma")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.collision_mask = unidad.collision_mask
	consulta.exclude = [unidad.get_rid(), jugador.get_rid()]
	var espacio := get_world_3d().direct_space_state
	var atras := jugador.mira().basis.z.normalized()
	var paso := ReglasDelJugador.ALCANCE_DE_LA_MIRA / PASOS_DEL_BORDE
	for intento in PASOS_DEL_BORDE:
		consulta.transform = Transform3D(Basis.IDENTITY, unidad.global_position)
		if espacio.intersect_shape(consulta, 1).is_empty():
			return
		unidad.global_position += atras * paso


func _agrupar_suelto(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		_sueltos[nodo.datos.producto.id].agregar(nodo)


func _retirar_del_grupo(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		_sueltos[nodo.datos.producto.id].quitar(nodo)


## Saca una unidad de la caja apuntada, y sólo con la caja apoyada en el suelo.
##
## El clic derecho llega por `uso_pedido`, que se reparte entre los puestos: acá se descarta lo
## que no es una caja. Desde qué altura entrega lo decide `ReglasDeLosObjetos`, donde tiene test.
func retirar_de_la_caja(objetivo: Node3D) -> void:
	var caja := objetivo as CajaDelDeposito
	if caja == null or not ReglasDeLosObjetos.se_puede_retirar(caja.global_position.y):
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
	_despertar_lo_de_arriba(nodo)


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
	var llego := false
	if not apoyo.is_empty():
		var destino := _apartado(caja, _lugar_sobre(caja, apoyo["position"]))
		caja.global_position = _llevar_hasta(caja, destino)
		llego = (
			caja.global_position.distance_to(destino) < TOLERANCIA_DEL_APOYO and _entra_entera(caja)
		)
	if (not llego or _le_queda_encima_al_jugador(caja)) and not _al_lado_del_jugador(caja):
		# Ni donde apunta ni al lado: el jugador está metido en un hueco del tamaño de su cuerpo.
		repositor.agarre.pedir_agarrar(caja.datos, caja)
		return
	caja.quedarse_quieta()


## Despierta las cajas que la que se acaba de levantar estaba sosteniendo, y es lo que desarma
## una pila: sacada la de abajo, las de arriba caen hasta el primer apoyo que encuentren.
##
## Se mira desde **el lugar que dejó** y no desde donde está: para cuando `objeto_agarrado`
## avisa, `Agarre` ya la colgó de la mano, así que su `global_position` es el puño del jugador y
## ahí arriba no hay ninguna pila.
func _despertar_lo_de_arriba(nodo: Node3D) -> void:
	var caja := nodo as CajaDelDeposito
	if caja == null:
		return
	_despertar_sobre(caja, caja.apoyo_que_dejo())


## Despierta lo apoyado sobre un lugar, y sigue hacia arriba desde cada una que despierta.
##
## **En cascada, porque una pila es una cadena.** Despertar un solo piso alcanza para dos —la de
## encima cae, y la siguiente se entera de refilón porque el volumen que se consulta llega a
## rozarla—, y a partir de la tercera no. Medido con cinco pisos: sacando la base caían la
## segunda y la tercera, y la cuarta se quedaba flotando a 0,93 m de cualquier apoyo, con la
## quinta prolijamente encima. Una caja congelada no se entera de que lo que la sostenía se fue.
##
## Despertar de más no cuesta nada, y por eso no se comprueba si la de arriba se iba a caer: si
## tiene otro apoyo, el motor la deja donde está y la vuelve a dormir. La `freeze` que se mira no
## es esa pregunta, es el corte de la recursión: una ya despierta no se vuelve a visitar.
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
	# no contesta nadie y la pila se queda flotando. Acá filtra el tipo, que es más preciso que
	# una capa: lo que se despierta son cajas, no cualquier cosa que estuviera ahí arriba.
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	for choque in get_world_3d().direct_space_state.intersect_shape(consulta, 8):
		var encima := choque["collider"] as CajaDelDeposito
		if encima == null or not encima.freeze:
			continue
		encima.soltarse()
		_despertar_sobre(encima, encima.global_position)


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
		var costado := jugador.global_position + vuelta * (-jugador.global_basis.z * radio)
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
## Tres casos, y son distintos entre sí. **Una tapa** es el lugar, derecho. **El aire** no señala
## una superficie equivocada: no señala ninguna, y entonces el lugar es el piso que haya debajo
## del cursor. **Una cara vertical** es la que tiene vuelta, y la resuelve `_apoyo_debajo()`.
func _apoyo_apuntado(caja: CajaDelDeposito) -> Dictionary:
	var ojo := jugador.mira()
	var lejos := ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA
	var golpe := _rayo(caja, ojo.origin, lejos)
	if golpe.is_empty():
		# Media caja hacia atrás: el rayo que baja no puede arrancar adentro de lo que la caja
		# va a ocupar.
		var punto := lejos + (ojo.origin - lejos).normalized() * _media_caja(caja).length()
		golpe = _rayo(caja, punto, punto + Vector3.DOWN * CAIDA_MAXIMA)
	elif not ReglasDeLosObjetos.se_puede_apoyar_en(golpe["normal"].y):
		golpe = _apoyo_debajo(caja, ojo.origin, golpe["position"])
	if golpe.is_empty() or not ReglasDeLosObjetos.se_puede_apoyar_en(golpe["normal"].y):
		return {}
	return golpe


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
func _llevar_hasta(caja: CajaDelDeposito, destino: Vector3) -> Vector3:
	var mano := punto_de_la_caja.global_position
	var media := _media_caja(caja)
	var alto := maxf(mano.y, destino.y + media.y)
	var arriba := _barrer(caja, mano, Vector3(mano.x, alto, mano.z))
	var adentro := _barrer(caja, arriba, Vector3(destino.x, arriba.y, destino.z))
	return _barrer(caja, adentro, destino)


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


func _apoyo(id: Producto.Id) -> Vector3:
	var cantidad := repositor.estante().unidades_en_gondola(Catalogo.de(id))
	return _posicion(id, cantidad)


func _posicion(id: Producto.Id, indice: int) -> Vector3:
	var base := to_global(apoyos[id])
	var hacia := direcciones[id]
	var separacion := _modelos[id].get_aabb().size.dot(hacia.abs()) + 0.03
	return base + hacia * separacion * indice


func _preparar_modelos() -> void:
	for grupo: MeshInstance3D in contenido.get_children():
		var herramienta := SurfaceTool.new()
		herramienta.append_from(grupo.mesh, 0, Transform3D(grupo.global_basis, Vector3.ZERO))
		herramienta.set_material(grupo.mesh.surface_get_material(0))
		_modelos.append(herramienta.commit())
	for modelo in _modelos:
		# **El casco sale de `create_convex_shape` y no de `get_faces()`.** Los vértices crudos
		# vienen repetidos —36 para un cubo, tres por cada esquina, y 1146 para la lata de
		# arvejas—, y con esa nube el solver arma un manifiesto de contacto sucio: un producto
		# de caras planas apoyado no termina de asentarse y se lo ve titilar. Limpio, el cubo
		# son 8 puntos y la lata 129.
		var forma := modelo.create_convex_shape(true, false)
		var puntos := forma.points
		var centro := modelo.get_aabb().get_center()
		for indice in puntos.size():
			puntos[indice] -= centro
		forma.points = puntos
		_formas.append(forma)


func _preparar_grupos() -> void:
	for producto in Catalogo.todos():
		var grupo := MultiMeshInstance3D.new()
		grupo.name = "ProductosDe" + producto.nombre
		var malla := _modelos[producto.id]
		var limites := malla.get_aabb()
		var copias := MultiMesh.new()
		copias.transform_format = MultiMesh.TRANSFORM_3D
		copias.mesh = malla
		copias.instance_count = repositor.estante().cupo(producto)
		copias.visible_instance_count = 0
		var posiciones := PackedFloat32Array()
		for indice in copias.instance_count:
			var apoyo := _posicion(producto.id, indice) + Vector3.UP * limites.size.y / 2
			var posicion := to_local(apoyo) - limites.get_center()
			# MultiMesh recibe tres filas de cuatro valores por transformación.
			posiciones.append_array([1, 0, 0, posicion.x, 0, 1, 0, posicion.y, 0, 0, 1, posicion.z])
		copias.buffer = posiciones
		grupo.multimesh = copias
		add_child(grupo)
		_grupos.append(grupo)
		var sueltos := GrupoDelPiso.new()
		sueltos.name = "SueltosDe" + producto.nombre
		sueltos.preparar(malla, repositor.estante().cupo(producto))
		add_child(sueltos)
		_sueltos.append(sueltos)


func retirar(id: Producto.Id) -> void:
	var unidad := _disponible
	_disponible = null
	if unidad == null:
		unidad = OBJETO.instantiate()
		add_child(unidad)
		_unidades.append(unidad)
		unidad.add_collision_exception_with(jugador)
		# Las bolsas delgadas necesitan detectar el impacto entre pasos de física.
		unidad.continuous_cd = true
	# El frente de cada modelo se alinea antes de darle la inclinación de la mano.
	unidad.orientacion_en_mano = (
		Basis.from_euler(Vector3(deg_to_rad(-17), deg_to_rad(-20), 0))
		* Basis(Vector3.UP, deg_to_rad(giros_del_frente[id]))
	)
	unidad.collision_layer = 1
	unidad.collision_mask = 1
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
	_grupos[producto.id].multimesh.visible_instance_count = unidades
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


## Deja el dibujo de la góndola en las unidades que el inventario dice que quedan.
##
## Vender no pasa por acá: descuenta en `Inventario`, y sin este repintado la góndola seguiría
## mostrando lo que ya no está. Se redibuja el catálogo entero y no sólo lo vendido porque la
## atención despacha varios productos de una y el despachado no dice cuáles.
##
## **Baja `visible_instance_count` en vez de borrar copias**, y es lo que lo deja de acuerdo con
## `_apoyo()`: la próxima unidad se coloca en el índice que devuelve `unidades_en_gondola`, o sea
## justo la primera copia que este método acaba de ocultar. Borrar copias correría los índices y
## la unidad repuesta caería sobre una que ya se ve.
func actualizar_stock(_despachados: int) -> void:
	for producto in Catalogo.todos():
		var copias := _grupos[producto.id].multimesh
		copias.visible_instance_count = repositor.estante().unidades_en_gondola(producto)
	_actualizar_zonas()


func limpiar() -> void:
	for grupo in _sueltos:
		while not grupo.cuerpos.is_empty():
			grupo.quitar(grupo.cuerpos[-1])
	for unidad in _unidades:
		if is_instance_valid(unidad):
			unidad.queue_free()
	_unidades.clear()
	_disponible = null
	for grupo in _grupos:
		grupo.multimesh.visible_instance_count = 0
	_actualizar_zonas()

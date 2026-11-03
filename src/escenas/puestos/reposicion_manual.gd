## Agrupa los productos colocados y conserva cuerpos independientes al soltarlos.
extends Node3D

const ZonaDeReposicion := preload("res://src/escenas/puestos/zona_de_reposicion.gd")
const GrupoDelPiso := preload("res://src/escenas/objetos/grupo_del_piso.gd")
const CajaDelDeposito := preload("res://src/escenas/objetos/caja_de_productos.gd")
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const ContenedorDelLocal := preload("res://src/escenas/puestos/contenedor_de_basura.gd")
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const CONTORNO := preload("res://src/sistemas/marco/aristas_del_foco.gdshader")
const LATERALES := preload("res://src/sistemas/marco/laterales_del_foco.gdshader")
const SIN_SUPERFICIE := preload("res://src/escenas/puestos/casillero_sin_superficie.gdshader")
const PRODUCTO := preload("res://src/escenas/puestos/producto_de_la_gondola.gdshader")
const POR_COLOCAR := preload("res://src/escenas/puestos/producto_por_colocar.gdshader")
const DISPOSICION_DE_PRUEBA := preload("res://src/escenas/puestos/disposicion_de_prueba.tres")
## La variante de Cindolor con la fecha de vencimiento en rojo en el dorso.
const MODELO_DEL_VENCIDO := preload("res://assets/models/producto_cindolor_vencido.res")

## Cuántas veces se parte al medio la búsqueda del borde de un apoyo.
const PASOS_DEL_BORDE := 12

## Cuánto puede variar la altura de un apoyo y seguir siendo el mismo, en metros.
const TOLERANCIA_DEL_APOYO := 0.02
## Cuánto sobre su lugar entra la caja a un estante con la tabla de arriba justa, en metros.
const ENTRADA_A_RAS := 0.03

## En cuántos pasos se trae hacia el jugador lo que se soltó adentro de un mueble.
const PASOS_PARA_DESATASCAR := 12

## En cuántos anillos se busca un lugar donde la caja entre, alrededor del punto apuntado.
const PASOS_PARA_ACERCAR := 6

## Cuánto puede errarle la mira al borde de una caja y seguir apuntándole, en metros.
const HOLGURA_DE_LA_MIRA := 0.1

## Hasta cuántas cajas se sube buscando la tapa de una pila. Es un tope de cordura: el techo del
## local corta antes.
const PISOS_DE_UNA_PILA := 8

## Hasta qué altura sobre el piso un apoyo sigue siendo el piso, en metros: una alfombra o una
## mancha. La tapa de un pallet tirado en el piso ya es un mueble.
const A_RAS_DEL_PISO := 0.05

## Las tandas fijas —lo que se repite para completar un estante, y que el jugador NO repone—:
## un `MeshInstance3D` por bloque, en el orden de `DisposicionDeLaGondola.guias`.
##
## **Entra instanciada adentro de este puesto y no cableada por `@export`.** Apuntada desde
## `almacen.tscn` con un `NodePath` hacia otra rama llegaba en `null` con el `node_paths` bien
## escrito, y el puesto moría en `_preparar_la_guia()` con un `Cannot call method 'get_child' on
## a null value` que no nombra ni al `@export` ni a la escena. Siendo hija no hay nada que
## resolver. Medido el 2026-09-19.
const GUIA := "Guia"
## Dónde va el bidón en la mano, desde el punto donde se lleva el balde: con el mismo encuadre que
## el balde. Es 1,4 veces más grande (70 cm contra 50), así que va unas 1,3 veces más lejos sobre
## la misma línea desde el ojo: unos 18° abajo y 26° al costado, casi entero a la vista. Acompaña la
## mira como el balde, para no perderlo de vista al volcarlo.
const BIDON_A_UN_COSTADO := Vector3(0.086, -0.008, -0.18)

@export var repositor: Repositor
@export var jugador: JugadorDelLocal
@export var estante: Node3D
@export var contenido: Node3D

## De dónde cuelga la caja mientras se la lleva: un punto del CUERPO y no de la cámara, porque
## pegada al pitch tapa la mira. Lo mueve este puesto y no `Agarre`, que no puede nombrarla.
@export var punto_de_la_caja: Node3D
## El piso del local y del depósito: sobre él la caja apoyada no se endereza a ningún mueble.
@export var suelo: StaticBody3D
## Dónde va cada unidad de la góndola, y en qué orden.
##
## **Ningún apoyo está escrito acá.** Los mide el `.blend` y llegan en este recurso.
@export var disposicion: DisposicionDeLaGondola

## La raíz entrega sólo las góndolas: su hueco comercial no es soporte físico.
var muebles_con_reserva: Array[PhysicsBody3D] = []

var _unidades: Array[Node3D] = []
## Una unidad por producto, oculta y quieta. En la mano el producto es una malla suelta, y compila
## otra variante que en el lote de la góndola: el calentamiento la prepara con estas.
var _unidades_de_muestra: Array[Node3D] = []
## Los casilleros de cada producto, en el orden de `Producto.Id` y, adentro, en el de su fila.
var _casilleros: Array[Array] = []
## Lo que la mira enfoca, según el jugador. Sólo el casillero enfocado muestra la vista previa.
var _enfocado: Node3D = null
## Los casilleros con papel que la mira podría elegir ahora: los únicos que se le ofrecen.
var _cerca_de_la_mira: Dictionary[ZonaDeReposicion, bool] = {}
## El centro y el radio de la esfera que envuelve cada fila de adelante, en el orden de
## `Producto.Id`: con ellos se descarta de una vez una fila entera que la mira no alcanza.
var _centros_de_las_filas: Array[Vector3] = []
var _radios_de_las_filas: Array[float] = []
var _modelos: Array[Mesh] = []
var _formas: Array[ConvexPolygonShape3D] = []
var _grupos: Array[MultiMeshInstance3D] = []
## Un dibujo por producto para todos sus huecos, sin cuerpos ni permisos propios.
var _huecos: Array[MultiMeshInstance3D] = []
## Los casilleros que dibuja cada producto, en el orden en que los midió el modelo. El dibujo los
## reordena, y de acá sale cada vez: leerlo del dibujo obliga a bajarlo de la placa de video.
var _bloques: Array[PackedFloat32Array] = []
var _sueltos: Array[GrupoDelPiso] = []
## Los envases que hay en las góndolas, como cuerpos que sólo miran las manos y la caja: uno por
## producto, con una forma por copia de su dibujo. Aparte van las formas de los casilleros, en el
## orden de sus casilleros: son las únicas que se prenden y se apagan.
var _mercaderia: Array[CharacterBody3D] = []
var _formas_de_la_mercaderia: Array[Array] = []
## Cindolor vencido: el modelo de la mano y el piso, y los dos dibujos de la góndola y del piso.
var _modelo_vencido: Mesh
var _vencidos_puestos: MultiMeshInstance3D
var _vencidos_sueltos: GrupoDelPiso
var _disponible: ObjetoAgarrable = null
## Las aristas que dibuja el foco. Piden las mallas que arma `AristasDelProducto`.
var _aristas := ShaderMaterial.new()
var _laterales := ShaderMaterial.new()
var _disposicion_completa: DisposicionDeLaGondola
var _disposicion_preparada: DisposicionDeLaGondola
var _generados: Array[Node] = []


func unidades_sueltas() -> Array[Node3D]:
	var cuerpos: Array[Node3D] = []
	for grupo: GrupoDelPiso in _sueltos:
		cuerpos.append_array(grupo.cuerpos)
	if _vencidos_sueltos != null:
		cuerpos.append_array(_vencidos_sueltos.cuerpos)
	return cuerpos


## Cuántos casilleros tiene la fila de adelante de cada producto: su cupo, medido del modelo.
##
## Es lo que la apertura de cada jornada le pasa al inventario. **Sale de la disposición, y no
## de un número escrito acá ni del catálogo**: cuántas unidades entran de frente lo dice el
## modelo, y una tanda que el artista alarga en Blender cambia de cupo sin que nadie lo copie.
## Cada lugar de la fila de adelante es un casillero (BR-STK-025).
func casilleros() -> Dictionary[Producto.Id, int]:
	var por_producto: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		por_producto[producto.id] = disposicion.casilleros_de(producto.id)
	return por_producto


## Los casilleros de cada tanda de cada producto, la reponible primero y después cada fija, con
## la numeración de `_armar_los_bloques()`.
##
## Son los hechos del modelo. Cuáles tandas pueden abrir vacías enteras lo decide `Apertura`.
func tandas() -> Dictionary[Producto.Id, Array]:
	var por_producto: Dictionary[Producto.Id, Array] = {}
	for producto in Catalogo.todos():
		var fijas: Array = []
		var siguiente := 0
		for indice in disposicion.productos_de_las_guias.size():
			if disposicion.productos_de_las_guias[indice] == producto.id:
				var fila := disposicion.filas_de_adelante_de_las_guias[indice]
				fijas.append(PackedInt32Array(range(siguiente, siguiente + fila)))
				siguiente += fila
		var reponibles := disposicion.filas_de_adelante[producto.id]
		var reponible := PackedInt32Array(range(siguiente, siguiente + reponibles))
		por_producto[producto.id] = [reponible] + fijas
	return por_producto


## Dónde está cada casillero de cada tanda, en el mismo orden que `tandas()`.
##
## Son las posiciones del modelo. Qué estante queda contiguo y qué columnas se alinean lo decide
## `Apertura`.
func posiciones() -> Dictionary[Producto.Id, Array]:
	var por_producto: Dictionary[Producto.Id, Array] = {}
	for producto in Catalogo.todos():
		var lugares: Array = [
			_lugares_de_adelante(
				disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
			)
		]
		for indice in disposicion.productos_de_las_guias.size():
			if disposicion.productos_de_las_guias[indice] == producto.id:
				lugares.append(
					_lugares_de_adelante(
						disposicion.guias[indice],
						disposicion.filas_de_adelante_de_las_guias[indice]
					)
				)
		por_producto[producto.id] = lugares
	return por_producto


func preparar() -> void:
	if _modelos.is_empty():
		_preparar_materiales_y_modelos()
		_conectar_los_gestos()
	if _disposicion_preparada != disposicion:
		_rehacer_disposicion()
	else:
		for id in _grupos.size():
			_mostrar_lo_puesto(id)
	_actualizar_zonas()


func seleccionar_disposicion(jornada: int) -> void:
	if _disposicion_completa == null:
		_disposicion_completa = disposicion
	disposicion = (
		DISPOSICION_DE_PRUEBA
		if jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
		else _disposicion_completa
	)


## Si la jornada elegida usa el mapa de prueba.
func es_de_prueba() -> bool:
	return disposicion == DISPOSICION_DE_PRUEBA


func _preparar_materiales_y_modelos() -> void:
	_aristas.shader = CONTORNO
	_aristas.set_shader_parameter("color", IndicacionDelFoco.COLOR)
	_aristas.set_shader_parameter("grosor", IndicacionDelFoco.GROSOR_DE_PRODUCTOS)
	_laterales.shader = LATERALES
	_laterales.set_shader_parameter("color", IndicacionDelFoco.COLOR)
	_preparar_modelos()
	for producto in Catalogo.todos():
		var unidad: ObjetoAgarrable = OBJETO.instantiate()
		unidad.freeze = true
		unidad.collision_layer = 0
		unidad.collision_mask = 0
		unidad.material_de_foco = _aristas
		add_child(unidad)
		unidad.remove_from_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
		_vestir(unidad, producto.id)
		unidad.hide()
		_unidades_de_muestra.append(unidad)


func unidades_de_muestra() -> Array[Node3D]:
	return _unidades_de_muestra


func _rehacer_disposicion() -> void:
	_limpiar_unidades()
	_al_perder_el_foco()
	_cerca_de_la_mira.clear()
	if not _generados.is_empty():
		var retirados := Node3D.new()
		retirados.visible = false
		retirados.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(retirados)
		for nodo in _generados:
			nodo.reparent(retirados)
		retirados.queue_free()
	_generados.clear()
	_bloques.clear()
	_grupos.clear()
	_huecos.clear()
	_sueltos.clear()
	_mercaderia.clear()
	_formas_de_la_mercaderia.clear()
	_vencidos_puestos = null
	_vencidos_sueltos = null
	_casilleros.clear()
	_centros_de_las_filas.clear()
	_radios_de_las_filas.clear()
	_preparar_grupos()
	for id in _grupos.size():
		_mostrar_lo_puesto(id)
	_preparar_los_casilleros()
	_disposicion_preparada = disposicion


func _conectar_los_gestos() -> void:
	estante.remove_from_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	jugador.uso_pedido.connect(
		func(objetivo: Node3D) -> void: usar_la_caja(objetivo, jugador.uso_es_primario())
	)
	jugador.consultar_interaccion_con(_contexto_sobre_la_caja)
	jugador.objetivo_enfocado.connect(_al_enfocar)
	jugador.objetivo_perdido.connect(_al_perder_el_foco)
	repositor.agarre.objeto_agarrado.connect(_actualizar_zonas)
	repositor.agarre.objeto_agarrado.connect(_ampliar_producto_en_mano)
	repositor.agarre.objeto_soltado.connect(_restaurar_tamano_del_producto)
	repositor.agarre.objeto_entregado.connect(_restaurar_tamano_del_producto)
	repositor.agarre.objeto_soltado.connect(_actualizar_zonas)
	repositor.agarre.objeto_entregado.connect(_actualizar_zonas)
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
	# El contacto mide el metal. La reserva de mercadería se pregunta aparte: el hueco
	# comercial no tiene cuerpo y no puede volver a ser una plataforma invisible para cajas.
	# Antes el contorno cumplía ambas funciones; 10 de 75 soltadas entraban sin esa reserva.
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
		if espacio.intersect_shape(consulta, 1).is_empty() and not _ocupa_una_reserva(forma):
			return
		unidad.global_position += atras * paso


## Conserva orientación y escala de la unidad, sin añadir formas a la simulación.
func _ocupa_una_reserva(forma: CollisionShape3D) -> bool:
	var volumen := LimitesDeForma.de(forma.shape)
	for cuerpo: PhysicsBody3D in muebles_con_reserva:
		var malla := cuerpo.get_parent() as MeshInstance3D
		if malla == null or malla.mesh == null:
			continue
		if ReservaDeLaGondola.se_superponen(
			volumen, forma.global_transform, malla.get_aabb(), malla.global_transform
		):
			return true
	return false


func _agrupar_suelto(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		_grupo_del_piso_de(nodo.datos).agregar(nodo)


func _retirar_del_grupo(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		_grupo_del_piso_de(nodo.datos).quitar(nodo)


## El grupo que dibuja a esa unidad en el piso: la vencida tiene su propio modelo.
func _grupo_del_piso_de(unidad: UnidadDeProducto) -> GrupoDelPiso:
	if unidad.vencido and _vencidos_sueltos != null:
		return _vencidos_sueltos
	return _sueltos[unidad.producto.id]


## Traduce el gesto recibido al resultado de la caja; no deriva el botón de lo que lleva la mano.
func usar_la_caja(objetivo: Node3D, primario: bool = false) -> void:
	var caja := objetivo as CajaDelDeposito
	if caja == null:
		return
	var acciones: Dictionary[ContenidoDeLaCaja.Gesto, Callable] = {
		ContenidoDeLaCaja.Gesto.SACAR: retirar,
		ContenidoDeLaCaja.Gesto.METER: devolver,
		ContenidoDeLaCaja.Gesto.NADA: func(_id: Producto.Id) -> void: pass,
	}
	var gesto := repositor.caja(caja.producto).uso(repositor.agarre.manos().sostenido(), primario)
	acciones[gesto].call(caja.producto)


## El contenido declara ambos gestos y la capacidad sin sacar ni devolver una unidad.
func _contexto_sobre_la_caja(
	objetivo: Node3D, sostenido: ObjetoDelAlmacen
) -> ReferenciaDeControles.Contexto:
	var caja := objetivo as CajaDelDeposito
	if caja == null:
		return null
	var contenido := repositor.caja(caja.producto)
	if contenido == null:
		return null
	return ReferenciaDeControles.contexto_de_la_caja(contenido, sostenido)


## Mete en su caja la unidad de la mano y guarda su cuerpo, que deja de verse. Si la caja no la
## recibe, la unidad sigue en la mano y acá no pasa nada.
func devolver(id: Producto.Id) -> void:
	var cuerpo := repositor.pedir_devolver(id) as ObjetoAgarrable
	if cuerpo == null:
		return
	_guardar_cuerpo(cuerpo)
	_actualizar_zonas()


## Lo que dice la caja examinada, o nada si lo examinado no es una caja.
##
## El texto lo arma la caja en `dominio/`, donde tiene test, y contado sobre el estante de esta
## noche: sirve al pensamiento de la caja apoyada y al examen en la mano.
func texto_del_examen(nodo: Node3D) -> String:
	var caja := nodo as CajaDelDeposito
	if caja == null:
		return ""
	return repositor.caja(caja.producto).texto_del_examen()


## Baja a la cintura la caja recién levantada y le da su volumen al cuerpo del jugador.
func _colgar_la_caja(nodo: Node3D) -> void:
	if not _se_lleva_como_caja(nodo):
		return
	if punto_de_la_caja == null:
		push_error("ReposicionManual sin punto de la caja cableado: revisar almacen.tscn")
		return
	# El bidón tiene su propio punto: examinarlo lo devuelve a él, y no al medio de la caja.
	repositor.agarre.mover_lo_sostenido(
		punto_de_la_caja if nodo is CajaDelDeposito else _punto_del_bidon()
	)
	jugador.ocupar_el_frente(true)
	despertar_lo_de_arriba(nodo)


## Apoya la caja recién soltada donde el jugador tiene la mira, derecha y de una, y girada como
## se la llevaba: sigue hacia dónde mira el jugador. Sobre un mueble o sobre otra caja se endereza
## antes de buscar el lugar, que con otro giro ocupa otra huella.
##
## Soltar la deja viva: `Agarre` le saca la `freeze` al colgarla del punto de soltado, así que
## acá se le escribe el lugar y se la vuelve a congelar con `quedarse_quieta()`. El `top_level`
## vuelve a `false` por lo mismo, que es lo que soltar deja en `true`.
##
## **Soltar suelta.** Cuando la mira no señala un lugar donde la caja entre, o el camino hasta
## ahí está cortado, la caja va al piso al lado del jugador. Antes se le volvía a la mano, y eso
## era un clic que no hacía nada y no decía por qué: parado cerca de un mueble pasaba seguido.
func _apoyar_la_caja(nodo: Node3D) -> void:
	if not _se_lleva_como_caja(nodo) or punto_de_la_caja == null:
		return
	var caja := nodo as RigidBody3D
	jugador.ocupar_el_frente(false)
	caja.top_level = false
	caja.global_basis = _giro_de_la_mano(caja)
	var apoyo := _apoyo_apuntado(caja)
	if not apoyo.is_empty():
		var giro := _giro_sobre(caja, apoyo["collider"] as Node3D, apoyo["position"])
		if not giro.is_equal_approx(caja.global_basis):
			# Con otro giro ocupa otra huella, y la huella decide el punto apuntado.
			caja.global_basis = giro
			apoyo = _apoyo_apuntado(caja)
	var llego := not apoyo.is_empty() and _cerca_de(caja, apoyo["position"])
	if not llego:
		caja.global_basis = _giro_de_la_mano(caja)
	if not llego and not _al_lado_del_jugador(caja):
		# Ni donde apunta ni al lado: el jugador está metido en un hueco del tamaño de su cuerpo.
		repositor.agarre.pedir_agarrar(caja.get("datos"), caja)
		return
	_quedar_quieta(caja)
	# Se la ubica en vez de dejarla caer: el motor no avisa ningún choque, y el apoyo suena igual.
	caja.emit_signal(&"contacto_recibido", caja, 0.0)


## Cómo queda la caja sobre lo que la sostiene. Sobre otra caja copia su giro: girada encima de
## otra del mismo tamaño le quedan las esquinas en el aire. Sobre un mueble va al cuarto de vuelta
## más cercano al que tenía: derecha, y mirando todavía al jugador. En el piso queda como venía, y
## también sobre lo que está a ras del piso: una alfombra no es un mueble.
func _giro_sobre(caja: RigidBody3D, apoyo: Node3D, punto: Vector3) -> Basis:
	if apoyo == null or apoyo == suelo:
		return caja.global_basis
	if _a_ras_del_piso(caja, apoyo, punto):
		return caja.global_basis
	if apoyo is CajaDelDeposito:
		return apoyo.global_basis.orthonormalized()
	var del_mueble := apoyo.global_basis.orthonormalized().x
	var desde := atan2(-del_mueble.z, del_mueble.x)
	var propio := caja.global_basis.orthonormalized().x
	var desvio := angle_difference(desde, atan2(-propio.z, propio.x))
	return Basis(Vector3.UP, desde + snappedf(desvio, PI / 2.0))


## Si debajo del apoyo, a menos de `A_RAS_DEL_PISO`, está el piso. El rayo sigue de largo por lo
## que no es el piso: arranca en la cara del apoyo, y el cuerpo del edificio tiene caras a la misma
## altura que el suelo.
func _a_ras_del_piso(caja: RigidBody3D, apoyo: Node3D, punto: Vector3) -> bool:
	var consulta := PhysicsRayQueryParameters3D.create(
		punto + Vector3.UP * TOLERANCIA_DEL_APOYO,
		punto + Vector3.DOWN * A_RAS_DEL_PISO,
		caja.collision_mask
	)
	# `exclude` devuelve una copia: agregarle algo no cambia la consulta.
	var salteados: Array[RID] = [caja.get_rid(), jugador.get_rid()]
	if apoyo is CollisionObject3D:
		salteados.append((apoyo as CollisionObject3D).get_rid())
	for _intento in PISOS_DE_UNA_PILA:
		consulta.exclude = salteados
		var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
		if golpe.is_empty() or golpe["collider"] == suelo:
			return not golpe.is_empty()
		salteados.append(golpe["rid"])
	return false


## El giro horizontal que la caja tenía en la mano. La mano cuelga del giro del jugador, así que
## no se inclina con la mirada.
func _giro_de_la_mano(caja: RigidBody3D) -> Basis:
	var orientacion: Basis = caja.get("orientacion_en_mano")
	var en_la_mano := punto_de_la_caja.global_basis.orthonormalized() * orientacion
	return Basis(Vector3.UP, atan2(-en_la_mano.x.z, en_la_mano.x.x))


## Deja la caja en el lugar más cercano al punto apuntado donde entra, sobre el mismo apoyo.
##
## **El cursor no tiene que caer en el punto exacto.** Apuntando pegado a una caja vecina, a un
## parante o a la punta de una tabla, la caja no entra justo ahí y entra diez centímetros al
## costado. Antes eso la mandaba al piso al lado del jugador, y el estante tenía agujeros: zonas
## donde soltar no subía la caja sin que nada dijera por qué.
##
## Se prueba el punto y después anillos cada vez más abiertos, hasta una caja de distancia. Sólo
## cuentan los lugares que siguen teniendo el mismo apoyo debajo: correrla no es bajarla.
func _cerca_de(caja: RigidBody3D, punto: Vector3) -> bool:
	var paso := _media_caja(caja).x / PASOS_PARA_ACERCAR * 2.0
	for anillo in PASOS_PARA_ACERCAR + 1:
		for lado in 1 if anillo == 0 else ReglasDeLosObjetos.LADOS_ALREDEDOR:
			var corrido := (
				Basis(Vector3.UP, TAU * lado / ReglasDeLosObjetos.LADOS_ALREDEDOR) * Vector3.RIGHT
			)
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
	var visitadas: Dictionary[RID, bool] = {}
	_despertar_sobre(caja, caja.apoyo_que_dejo(), visitadas)


## Despierta lo apoyado sobre un lugar, y sigue hacia arriba desde cada caja que despierta.
##
## **En cascada, porque una pila es una cadena.** Despertar un solo piso alcanza para dos —la de
## encima cae, y la siguiente se entera de refilón—, y a partir de la tercera no. Una caja
## congelada es estática para el motor, y un cuerpo estático que se va no despierta a nadie.
## Lo que no es una caja se despierta y también se recorre, con el mismo criterio de visita.
##
## Despertar de más no cuesta nada, y por eso no se comprueba si lo de arriba se iba a caer: si
## tiene otro apoyo, el motor lo deja donde está y lo vuelve a dormir. Una caja despierta puede
## sostener otra ya congelada: se atraviesan ambas y los RID visitados cortan la recursión.
func _despertar_sobre(
	caja: CajaDelDeposito, lugar: Vector3, visitadas: Dictionary[RID, bool]
) -> void:
	var id := caja.get_rid()
	if visitadas.has(id):
		return
	visitadas[id] = true
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
			Agarre.despertar_lo_apoyado(encima, visitadas)
		else:
			if caja_de_arriba.freeze:
				caja_de_arriba.soltarse()
			_despertar_sobre(caja_de_arriba, caja_de_arriba.global_position, visitadas)


## Deja la caja en el piso al lado del jugador. Devuelve si encontró dónde.
##
## Se prueba alrededor y no sólo adelante: cuando la mira no encontró lugar suele ser porque hay
## un mueble enfrente, y enfrente es justo donde no hay piso libre. Se arranca por donde el
## jugador mira, así que con lugar de sobra la caja cae adelante, que es lo que espera.
##
## El radio sale del cuerpo del jugador y del de la caja, y no de un número escrito acá: más
## cerca, la caja queda adentro del jugador y lo sube arriba de ella.
func _al_lado_del_jugador(caja: RigidBody3D) -> bool:
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var media := _media_caja(caja)
	var radio: float = (cuerpo.shape as CapsuleShape3D).radius + media.length()
	var lugares := LugaresDelPiso.alrededor(
		get_world_3d().direct_space_state,
		jugador.global_position,
		jugador.frente(),
		radio,
		media.y,
		ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO,
		ReglasDeLosObjetos.LADOS_ALREDEDOR,
		caja.collision_mask,
		[caja.get_rid(), jugador.get_rid()]
	)
	for lugar in lugares:
		caja.global_position = _lugar_sobre(caja, lugar)
		if (
			_entra_entera(caja)
			and not _le_queda_encima_al_jugador(caja)
			and not _sobre_el_contenedor(caja)
		):
			return true
	return false


## Si la caja quedó parada en el contenedor. Parado junto a él, el piso de al lado del jugador
## puede ser el fondo.
func _sobre_el_contenedor(caja: RigidBody3D) -> bool:
	var centro := caja.global_position
	var debajo := _rayo(caja, centro, centro + Vector3.DOWN * _media_caja(caja).y * 2.0)
	return debajo.get("collider") is ContenedorDelLocal


## Si en el lugar donde quedó la caja no hay nada más, ni los envases de la góndola. Se encoge para
## preguntar, porque apoyarse sobre algo es tocarlo.
##
## **El barrido solo no alcanza para saberlo.** `cast_motion` contesta que el movimiento entero
## es seguro cuando la forma arranca ya tocando algo, así que el tramo que baja la caja al
## estante la deja metida entre los paneles y dice que llegó. Medido: de 256 soltadas alrededor
## de la góndola del pasillo, 20 quedaban adentro de ella, todas a la altura del estante de
## arriba.
func _entra_entera(caja: RigidBody3D) -> bool:
	var forma: CollisionShape3D = _cuerpo_de(caja)
	var encogida := BoxShape3D.new()
	# Jolt redondea las aristas con el margen, y una esquina metida unos milímetros no choca.
	encogida.margin = 0.0
	encogida.size = _tamano_encogido(forma)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = encogida
	consulta.transform = Transform3D(caja.global_basis.orthonormalized(), caja.global_position)
	consulta.collision_mask = caja.collision_mask
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
		return false
	return not _pisa_la_mercaderia(caja)


## La medida de la caja en metros, achicada porque apoyarse sobre algo es tocarlo. La escala de la
## forma lleva la medida: su caja de colisión es de 2 x 2 x 2.
func _tamano_encogido(forma: CollisionShape3D) -> Vector3:
	return LimitesDeForma.de(forma.shape).size * forma.scale - Vector3.ONE * ReglasDeLosObjetos.ROCE


## Si la caja se mete entre los envases que las góndolas tienen puestos.
##
## **Con la caja ya soltada, los envases no están en la simulación**: sólo los ven las manos
## mientras llevan algo. Se los mide a mano. Los apagados son casilleros sin producto, y ahí la
## caja puede apoyarse.
func _pisa_la_mercaderia(caja: RigidBody3D) -> bool:
	var forma: CollisionShape3D = _cuerpo_de(caja)
	var tamano := _tamano_encogido(forma)
	var volumen := AABB(-tamano / 2.0, tamano)
	var pose := Transform3D(forma.global_basis.orthonormalized(), forma.global_position)
	var del_mundo := pose * volumen
	for cuerpo in _mercaderia:
		for envase: CollisionShape3D in cuerpo.get_children():
			if envase.disabled:
				continue
			var limites := LimitesDeForma.de(envase.shape)
			if (
				(envase.global_transform * limites).intersects(del_mundo)
				and ReservaDeLaGondola.se_superponen(
					volumen, pose, limites, envase.global_transform
				)
			):
				return true
	return false


## Si la caja terminó adentro del cuerpo del jugador es que ahí no hay lugar para apoyarla, y
## dejarla igual lo sube arriba de ella.
func _le_queda_encima_al_jugador(caja: RigidBody3D) -> bool:
	var forma: CollisionShape3D = _cuerpo_de(caja)
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
## señala una superficie equivocada: no señala ninguna, y entonces el lugar es el apoyo que haya
## debajo del cursor, que resuelve `_apoyo_sobrevolado()`. **El costado de otra caja** es apilar:
## con una caja justo enfrente el cursor cae ahí y no en su tapa. **Cualquier otra cara vertical**
## la resuelve `_apoyo_debajo()`.
func _apoyo_apuntado(caja: RigidBody3D) -> Dictionary:
	var ojo := jugador.mira()
	var lejos := ReglasDelJugador.fin_de_la_mira(ojo.origin, -ojo.basis.z)
	var golpe := _rayo(caja, ojo.origin, lejos)
	var rozada := _caja_rozada(caja, ojo.origin, lejos, golpe)
	if rozada == null:
		rozada = _caja_sobrevolada(caja, ojo.origin, lejos, golpe)
	if rozada != null:
		golpe = _tapa_de_la_pila(caja, rozada)
	elif golpe.is_empty():
		golpe = _apoyo_sobrevolado(caja, ojo.origin, lejos)
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
	# El contenedor es del mundo fijo y su fondo es horizontal, pero es un vacío donde se tira: no
	# es un lugar donde dejar una caja.
	if golpe["collider"] is ContenedorDelLocal:
		return {}
	return golpe


## El apoyo más alto que la mira sobrevuela cuando termina en el aire.
##
## **Un rack sin fondo no frena la mira.** El rayo cruza el hueco y sale por atrás, y el piso
## debajo de su punta queda detrás del rack: la caja iba a parar ahí, fuera de la vista. Medido a
## 0,7 y 1,1 m del rack del medio del depósito: entre +3 y -7 grados terminaba en el piso de atrás.
##
## Se camina la mira desde la punta hacia el jugador, y en cada paso se baja derecho. Entre dos
## apoyos a la misma altura queda el más lejano: en piso abierto, el que hay debajo de la punta.
##
## **Desde la punta y hasta media caja después del ojo.** La punta es el borde del alcance: no
## frenar ahí dejaba el estante afuera a la distancia normal. Donde está parado el jugador no hay
## lugar.
func _apoyo_sobrevolado(caja: RigidBody3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	var margen := _media_caja(caja).length()
	var recorrido := desde.distance_to(hasta)
	var mejor := {}
	while recorrido > margen:
		var punto := desde.move_toward(hasta, recorrido)
		var golpe := _rayo(
			caja, punto, punto + Vector3.DOWN * ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO
		)
		if (
			not golpe.is_empty()
			and ReglasDeLosObjetos.se_puede_apoyar_en(golpe["normal"].y)
			and (
				mejor.is_empty() or golpe["position"].y > mejor["position"].y + TOLERANCIA_DEL_APOYO
			)
		):
			mejor = golpe
		recorrido -= HOLGURA_DE_LA_MIRA
	return mejor


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
	caja: RigidBody3D, desde: Vector3, hasta: Vector3, golpe: Dictionary
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
	caja: RigidBody3D, desde: Vector3, hasta: Vector3, golpe: Dictionary
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
##
## **La cara de abajo de una tabla no es un canto.** Encima de ella está esa misma tabla, que la
## mira no ve: la caja tiene que ir a la de abajo, que es la que se mira.
func _tapa_de_ese_canto(caja: RigidBody3D, canto: Dictionary) -> Dictionary:
	var adentro: Vector3 = -canto["normal"]
	adentro.y = 0.0
	if adentro.is_zero_approx():
		return {}
	var punto: Vector3 = canto["position"] + adentro.normalized() * HOLGURA_DE_LA_MIRA
	var alto := _media_caja(caja).y * 2.0
	return _rayo(caja, punto + Vector3.UP * alto, punto + Vector3.DOWN * TOLERANCIA_DEL_APOYO)


## El apoyo que hay al pie de una pared, debajo del punto apuntado y a cualquier altura.
##
## **La pared de atrás de un estante señala el estante.** `_apoyo_debajo()` busca hasta una caja
## de altura, y más arriba que eso la mira sobre la pared no daba nada: la caja iba al piso al
## lado del jugador, y la zona donde soltar subía la caja tenía un techo invisible. Se baja
## derecho desde media caja afuera de la pared, que es donde la caja va a quedar.
func _apoyo_al_pie(caja: RigidBody3D, pared: Dictionary) -> Dictionary:
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
		var golpe := _rayo(
			caja, punto, punto + Vector3.DOWN * ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO
		)
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
func _tapa_de_la_pila(caja: RigidBody3D, base: CajaDelDeposito) -> Dictionary:
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
func _apoyo_debajo(caja: RigidBody3D, ojo: Vector3, punto: Vector3) -> Dictionary:
	var media := _media_caja(caja)
	var desde := punto + (ojo - punto).normalized() * media.length()
	return _rayo(caja, desde, desde + Vector3.DOWN * media.y * 2.0)


## Dónde va el centro de la caja para quedar encima del punto apoyado y adentro de su huella.
func _lugar_sobre(caja: RigidBody3D, punto: Vector3) -> Vector3:
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
func _apartado(caja: RigidBody3D, destino: Vector3) -> Vector3:
	var forma: CollisionShape3D = _cuerpo_de(caja)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = Transform3D(forma.global_basis, destino)
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
func _huella_del_apoyo(caja: RigidBody3D, punto: Vector3) -> AABB:
	var huella := AABB(punto, Vector3.ZERO)
	for direccion: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		huella = huella.expand(punto + direccion * _borde_del_apoyo(caja, punto, direccion))
	return huella


## Cuánto sigue habiendo apoyo desde el punto hacia un lado, partiendo al medio.
##
## A pasos fijos el canto de un apoyo del tamaño de la caja cae entre dos pasos, y entonces la
## huella sale más chica que la caja y la deja descentrada justo donde tenía que entrar justa.
func _borde_del_apoyo(caja: RigidBody3D, punto: Vector3, direccion: Vector3) -> float:
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
func _hay_apoyo(caja: RigidBody3D, donde: Vector3, altura: float) -> bool:
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
func _rayo(caja: RigidBody3D, desde: Vector3, hasta: Vector3) -> Dictionary:
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
##
## **Se entra por tres alturas.** Con la tabla de arriba justa, subirla media caja la frena contra
## ella: entra a ras. Y un estante más bajo que la mano se alcanza sólo bajándola antes: a la
## altura de la mano la tabla del medio corta el paso.
func _llevar_hasta(caja: RigidBody3D, destino: Vector3) -> Vector3:
	var mano := punto_de_la_caja.global_position
	var cuerpo := Vector3(jugador.global_position.x, mano.y, jugador.global_position.z)
	var encima := destino.y + _media_caja(caja).y
	var llegada := mano
	for salida: Vector3 in [mano, cuerpo]:
		for alto: float in [maxf(salida.y, encima), encima, destino.y + ENTRADA_A_RAS]:
			var arriba := _barrer(caja, salida, Vector3(salida.x, alto, salida.z))
			var adentro := _barrer(caja, arriba, Vector3(destino.x, arriba.y, destino.z))
			llegada = _barrer(caja, adentro, destino)
			if llegada.distance_to(destino) < TOLERANCIA_DEL_APOYO:
				return llegada
	return llegada


## El punto más cercano a `hasta` al que la caja llega sin meterse adentro de nada.
func _barrer(caja: RigidBody3D, desde: Vector3, hasta: Vector3) -> Vector3:
	var forma: CollisionShape3D = _cuerpo_de(caja)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = Transform3D(forma.global_basis, desde)
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


func _punto_del_bidon() -> Node3D:
	var mano := repositor.agarre.punto_de_carga
	var punto := mano.get_node_or_null("PuntoDelBidon") as Node3D
	if punto == null:
		punto = Node3D.new()
		punto.name = "PuntoDelBidon"
		punto.position = BIDON_A_UN_COSTADO
		mano.add_child(punto)
	return punto


## Lo que se lleva al frente y se apoya como una caja: las cajas del depósito y los bidones de
## jabón.
static func _se_lleva_como_caja(nodo: Node3D) -> bool:
	if nodo is CajaDelDeposito:
		return true
	var objeto := nodo as ObjetoAgarrable
	return (
		objeto != null and objeto.datos != null and ReglasDeLaLimpieza.JABONES.has(objeto.datos.id)
	)


## El volumen de lo que se lleva como caja: la caja lo llama `Cuerpo`; un bidón, `Forma`.
static func _cuerpo_de(caja: RigidBody3D) -> CollisionShape3D:
	var cuerpo := caja.get_node_or_null("Cuerpo") as CollisionShape3D
	return cuerpo if cuerpo != null else caja.get_node("Forma") as CollisionShape3D


## La caja se congela donde quedó. Un bidón sólo se duerme: tiene que caer si le sacan lo de
## abajo, y congelado el útil vuelve al tamaño de la mano.
static func _quedar_quieta(caja: RigidBody3D) -> void:
	var del_deposito := caja as CajaDelDeposito
	if del_deposito != null:
		del_deposito.quedarse_quieta()
		return
	caja.linear_velocity = Vector3.ZERO
	caja.angular_velocity = Vector3.ZERO
	caja.sleeping = true


## La mitad de lo que ocupa en cada eje del mundo: girada, la caja ocupa más que su lado.
func _media_caja(caja: RigidBody3D) -> Vector3:
	var forma: CollisionShape3D = _cuerpo_de(caja)
	var media := LimitesDeForma.de(forma.shape).size * forma.scale / 2.0
	var giro := caja.global_basis.orthonormalized()
	return (Transform3D(giro) * AABB(-media, media * 2.0)).size / 2.0


## Coloca la unidad de la mano en ese casillero de ese producto, o en el primero vacío. Si el
## estante la rechaza, sigue en la mano.
func pedir_colocar(id: Producto.Id, indice: int = Estante.PRIMERO_VACIO) -> void:
	repositor.pedir_colocar_de_la_mano(Catalogo.de(id), indice)
	_actualizar_zonas()


## Pone en la mano la unidad de ese casillero, si la mano está libre y el casillero la tiene. Su
## copia deja de dibujarse, y las de al lado siguen donde estaban.
func agarrar_de_la_gondola(id: Producto.Id, indice: int) -> void:
	var unidad := _cuerpo_para(id)
	if not repositor.pedir_agarrar_de_la_gondola(id, indice, unidad):
		_guardar_cuerpo(unidad)
		return
	_vestir(unidad, id)
	_mostrar_lo_puesto(id)


## Lo que hace el clic sobre un casillero. **Qué gesto toca lo contesta el estante**, en
## `dominio/`, según lo que haya en la mano; acá sólo se busca la acción de ese gesto. Si el
## casillero lo recibe lo contesta después el estante también: un casillero de otro producto se
## rechaza allá, y no acá.
func _usar_el_casillero(id: Producto.Id, indice: int) -> void:
	var acciones: Dictionary[Estante.Gesto, Callable] = {
		Estante.Gesto.COLOCAR: pedir_colocar,
		Estante.Gesto.AGARRAR: agarrar_de_la_gondola,
		Estante.Gesto.NADA: func(_id: Producto.Id, _indice: int) -> void: pass,
	}
	var gesto := repositor.estante().uso(repositor.agarre.manos().sostenido())
	acciones[gesto].call(id, indice)


## Le da a cada casillero su papel con lo que hay en la mano, y lo pinta.
##
## **Qué casilleros esperan la unidad y cuáles se pueden agarrar lo dice el estante** (BR-PLY-022,
## BR-PLY-024): los vacíos de su producto con una unidad en la mano, los ocupados con la mano
## vacía, y ninguno con cualquier otra cosa. Un casillero sin papel no está para la mira: con una
## caja en la mano, un casillero enfocable se comería el clic que la suelta.
func _actualizar_zonas(_nodo: Node3D = null) -> void:
	var de_la_noche := repositor.estante()
	if de_la_noche == null:
		return
	var sostenido := repositor.agarre.manos().sostenido()
	_mostrar_la_mercaderia_a_las_manos(sostenido != null)
	for id in _casilleros.size():
		var producto := Catalogo.de(id)
		var para_colocar := de_la_noche.casilleros_para_colocar(producto, sostenido)
		var para_agarrar := de_la_noche.casilleros_para_agarrar(producto, sostenido)
		for zona: ZonaDeReposicion in _casilleros[id]:
			zona.papel = ZonaDeReposicion.Papel.NINGUNO
			if para_colocar.has(zona.casillero):
				zona.papel = ZonaDeReposicion.Papel.COLOCAR
			elif para_agarrar.has(zona.casillero):
				zona.papel = ZonaDeReposicion.Papel.AGARRAR
			_pintar(zona)


## Le ofrece a la mira sólo los casilleros con papel que podría elegir: los que caen, aunque sea
## en parte, adentro de su alcance y de su desvío (BR-PLY-004).
##
## **Es un costo medido, no una regla.** Con la mano vacía, todas las unidades puestas de la fila
## de adelante se pueden agarrar, y parado en el pasillo de las góndolas la mira tiene entre 43 y
## 54 casilleros al alcance: medirlos a todos lleva la lectura de la mira de 30 µs a 1,5 ms por
## paso de física, medido el 2026-09-30. Los que quedan afuera de este corte la mira no los
## elegiría nunca, así que ofrecerle sólo los de adentro no cambia qué enfoca.
func _physics_process(_delta: float) -> void:
	_ofrecer_a_la_mira()


func _ofrecer_a_la_mira() -> void:
	if _casilleros.is_empty():
		return
	var ojo := jugador.mira()
	var adelante := -ojo.basis.z
	var ahora: Dictionary[ZonaDeReposicion, bool] = {}
	for id in _casilleros.size():
		if not _podria_enfocar(
			ojo.origin, adelante, _centros_de_las_filas[id], _radios_de_las_filas[id]
		):
			continue
		for zona: ZonaDeReposicion in _casilleros[id]:
			if zona.papel == ZonaDeReposicion.Papel.NINGUNO:
				continue
			if _podria_enfocar(ojo.origin, adelante, zona.global_position, zona.radio):
				ahora[zona] = true
	for zona: ZonaDeReposicion in _cerca_de_la_mira:
		if not ahora.has(zona):
			zona.cerca_de_la_mira = false
			_pintar(zona)
	for zona: ZonaDeReposicion in ahora:
		if not _cerca_de_la_mira.has(zona):
			zona.cerca_de_la_mira = true
			_pintar(zona)
	_cerca_de_la_mira = ahora


## Si alguna parte de la esfera de ese centro y ese radio cae adentro del alcance y del desvío de
## la mira, mirando desde `ojo` hacia `adelante`.
static func _podria_enfocar(ojo: Vector3, adelante: Vector3, centro: Vector3, radio: float) -> bool:
	var hacia := centro - ojo
	var distancia := hacia.length()
	if ReglasDelJugador.proximidad(ojo, centro) - radio > ReglasDelJugador.ALCANCE_DE_LA_MIRA:
		return false
	if distancia <= radio:
		return true
	var margen := asin(radio / distancia)
	return adelante.angle_to(hacia) - margen <= ReglasDelJugador.DESVIO_MAXIMO_DE_LA_MIRA


## Pinta un casillero con su papel y con si la mira lo enfoca (BR-PLY-022, BR-PLY-023).
func _pintar(zona: ZonaDeReposicion) -> void:
	zona.pintar(zona == _enfocado)


func _al_enfocar(objetivo: Node3D, _distancia: float) -> void:
	var antes := _enfocado
	_enfocado = objetivo
	_repintar(antes)
	_repintar(objetivo)


func _al_perder_el_foco() -> void:
	var antes := _enfocado
	_enfocado = null
	_repintar(antes)


func _repintar(nodo: Node3D) -> void:
	if not is_instance_valid(nodo):
		return
	var zona := nodo as ZonaDeReposicion
	if zona != null:
		_pintar(zona)


## El casillero de la góndola con ese índice en la fila de ese producto. Sin índice, el primero
## vacío, o el último si la fila está llena.
func casillero(id: Producto.Id, indice: int = Estante.PRIMERO_VACIO) -> ZonaDeReposicion:
	var zonas: Array = _casilleros[id]
	if zonas.is_empty():
		return null
	if indice == Estante.PRIMERO_VACIO:
		var vacios := repositor.estante().casilleros_vacios(Catalogo.de(id))
		indice = zonas.size() - 1 if vacios.is_empty() else vacios[0]
	return zonas[indice]


## Dónde está la unidad de ese casillero, alineado a los ejes del local: donde la mira la
## encuentra. Sin índice, el del primero vacío.
func zona(id: Producto.Id, indice: int = Estante.PRIMERO_VACIO) -> AABB:
	var encontrado := casillero(id, indice)
	if encontrado == null:
		return AABB()
	var elegido := encontrado.casillero
	return global_transform * _copia_del_casillero(id, elegido) * _modelos[id].get_aabb()


## Dónde se apoya la unidad de ese casillero: el pie de su copia. Sin índice, el del primero
## vacío, o el del último si la fila está llena.
##
## Es el **pie** de esa copia y no su centro: la copia trae el origen de su modelo, que según el
## producto cae en el medio o en la base, y la unidad se para sobre el estante. Sale de la caja ya
## transformada y no de la local: una copia con la inclinación que el estante le da ocupa otro
## volumen que el modelo derecho.
func _apoyo(id: Producto.Id, indice: int = Estante.PRIMERO_VACIO) -> Vector3:
	var caja := zona(id, indice)
	return caja.get_center() - Vector3.UP * caja.size.y / 2.0


## Dónde está la copia de ese casillero en el dibujo del producto, como la midió el modelo.
func _copia_del_casillero(id: Producto.Id, indice: int) -> Transform3D:
	return DisposicionDeLaGondola.copia(_bloques[id], indice)


## Cuánto gira el modelo de un producto para mostrarle el frente a la cámara, en grados.
##
## **No se elige: se deriva de su tanda.** El modelo está horneado mirando hacia el pasillo de
## su tanda, que es el lado de la fila de adelante. Medido el 2026-09-19: cuando estaba escrito
## a mano estuvo mal en los doce productos, y el síntoma es mudo —se agarra de costado o dado
## vuelta—.
func _giro_del_frente(id: Producto.Id) -> float:
	var original := _disposicion_completa if _disposicion_completa != null else disposicion
	var frente := DisposicionDeLaGondola.frente(
		original.principales[id], original.filas_de_adelante[id]
	)
	if frente.is_zero_approx():
		var modelo := contenido.get_child(id) as Node3D
		var local: Vector3 = modelo.get_meta("frente_del_modelo")
		frente = (modelo.basis * local).normalized()
	return giro_hacia_la_camara(global_basis * frente)


## El giro que para derecho el modelo de un producto: lleva a la vertical el eje del envase que
## más se le acerca. En la rampa de una cabecera la unidad va echada hacia atrás lo que baja la
## chapa, y en la mano va derecha como las demás; en un estante plano no gira nada.
##
## Sale del modelo y no de la chapa: es el envase el que va echado, y su eje de arriba no es el
## mismo en todos.
func _derecho(id: Producto.Id) -> Basis:
	var modelo := (contenido.get_child(id) as Node3D).global_basis
	var arriba := Vector3.ZERO
	for columna in 3:
		var eje := modelo[columna].normalized()
		if absf(eje.y) > absf(arriba.y):
			arriba = eje
	return Basis(Quaternion(arriba if arriba.y > 0.0 else -arriba, Vector3.UP))


## El giro alrededor de la vertical que lleva `frente` a +Z, que es de donde mira la cámara: con
## el frente en -X es 90, en +X es 270 —o -90—, en +Z es 0 y en -Z es 180.
static func giro_hacia_la_camara(frente: Vector3) -> float:
	return rad_to_deg(atan2(-frente.x, frente.z))


func _preparar_modelos() -> void:
	for grupo: MeshInstance3D in contenido.get_children():
		_modelos.append(AristasDelProducto.preparar(_malla_en_mundo(grupo)))
	var cindolor := contenido.get_child(Producto.Id.CINDOLOR) as MeshInstance3D
	_modelo_vencido = AristasDelProducto.preparar(
		_malla_con_la_vuelta(MODELO_DEL_VENCIDO, cindolor.global_basis)
	)
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
	_armar_los_bloques()
	for producto in Catalogo.todos():
		var malla := _modelos[producto.id]
		var grupo := _dibujar(
			"ProductosDe" + producto.nombre, _malla_de_la_gondola(malla), _bloques[producto.id]
		)
		_grupos.append(grupo)
		var faltantes := _dibujar("HuecosDe" + producto.nombre, malla, _bloques[producto.id])
		faltantes.visible = false
		faltantes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_huecos.append(faltantes)
		var sueltos := GrupoDelPiso.new()
		sueltos.name = "SueltosDe" + producto.nombre
		sueltos.preparar(malla, repositor.estante().cupo(producto))
		add_child(sueltos)
		_generados.append(sueltos)
		_sueltos.append(sueltos)
	_preparar_la_mercaderia()
	_preparar_los_vencidos()


## Un cuerpo por producto con una caja por cada envase de su dibujo, para que lo que se lleva en las
## manos no se meta entre ellos.
##
## **Los envases son sólo dibujo**: un `MultiMeshInstance3D` no choca, y el contorno de la góndola
## sigue el metal. Sin cuerpo, el brazo de la mano no encontraba nada hasta el riel. Es un
## `CharacterBody3D` y no un `StaticBody3D` porque el sonido cuenta como pared a todo estático.
## Las cajas nacen apagadas: `_mostrar_lo_puesto()` prende las que el estante dice ocupadas.
func _preparar_la_mercaderia() -> void:
	for producto in Catalogo.todos():
		var cuerpo := CharacterBody3D.new()
		cuerpo.name = "MercaderiaDe" + producto.nombre
		cuerpo.collision_layer = 0
		cuerpo.collision_mask = 0
		var caja := _modelos[producto.id].get_aabb()
		var forma := BoxShape3D.new()
		forma.size = caja.size
		var bloque := _bloques[producto.id]
		var formas: Array[CollisionShape3D] = []
		for indice in DisposicionDeLaGondola.copias(bloque):
			var copia := DisposicionDeLaGondola.copia(bloque, indice)
			var envase := CollisionShape3D.new()
			envase.shape = forma
			envase.transform = Transform3D(copia.basis, copia * caja.get_center())
			envase.disabled = true
			cuerpo.add_child(envase)
			formas.append(envase)
		add_child(cuerpo)
		_generados.append(cuerpo)
		_mercaderia.append(cuerpo)
		_formas_de_la_mercaderia.append(formas)


## Prende las cajas de los casilleros que el estante tiene ocupados, y apaga el resto. Escribe sólo
## lo que cambia: cada forma que se enciende o se apaga rearma el cuerpo en el motor.
func _sincronizar_la_mercaderia(id: Producto.Id, ocupados: Array) -> void:
	if id >= _formas_de_la_mercaderia.size():
		return
	var formas := _formas_de_la_mercaderia[id]
	for casillero in formas.size():
		var envase: CollisionShape3D = formas[casillero]
		var vacio := not ocupados.has(casillero)
		if envase.disabled != vacio:
			envase.disabled = vacio


## La mercadería sólo se le muestra a las manos mientras llevan algo: con las manos vacías no
## hay qué replegar, y un cuerpo más en el espacio cuenta en cada rayo de la mira y del sonido.
func _mostrar_la_mercaderia_a_las_manos(llevando: bool) -> void:
	var capa := JugadorDelLocal.CAPA_DE_LA_MERCADERIA if llevando else 0
	for cuerpo in _mercaderia:
		if cuerpo.collision_layer != capa:
			cuerpo.collision_layer = capa


## Los dos dibujos de Cindolor vencido: el de los casilleros de la góndola, que arranca igual que
## el de las sanas, y el del piso, con lugar para todos los vencidos de la noche.
func _preparar_los_vencidos() -> void:
	var id := Producto.Id.CINDOLOR
	_vencidos_puestos = _dibujar(
		"VencidosDeCindolor", _malla_de_la_gondola(_modelo_vencido), _bloques[id]
	)
	_vencidos_puestos.visible = false
	_vencidos_sueltos = GrupoDelPiso.new()
	_vencidos_sueltos.name = "CindolorVencidoSuelto"
	_vencidos_sueltos.preparar(_modelo_vencido, ReglasDelEstante.CINDOLOR_VENCIDOS)
	add_child(_vencidos_sueltos)
	_generados.append(_vencidos_sueltos)


## El dibujo de un producto en la góndola, con el material de cada parte del modelo.
##
## Cada parte conserva su material sobre el mismo dibujo: el envase y su tapa pueden tener
## brillos distintos. El modelo original sigue disponible para la mano y los productos sueltos.
func _malla_de_la_gondola(original: Mesh) -> ArrayMesh:
	var malla := original.duplicate() as ArrayMesh
	for superficie in malla.get_surface_count():
		malla.surface_set_material(
			superficie, _material_de_la_gondola(original.surface_get_material(superficie))
		)
	return malla


func _material_de_la_gondola(original: BaseMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PRODUCTO
	material.set_shader_parameter("color", original.albedo_color)
	material.set_shader_parameter("textura", original.albedo_texture)
	material.set_shader_parameter("rugosidad", original.roughness)
	material.set_shader_parameter("metalico", original.metallic)
	material.set_shader_parameter("especular", original.metallic_specular)
	return material


## Un casillero por lugar de la fila de adelante de cada producto: el cuerpo que la mira enfoca,
## puesto donde va la unidad y con su volumen, y el envase que se dibuja ahí.
##
## **Van todos desde el principio, sin papel**: cuál espera la unidad de la mano y cuál se puede
## agarrar cambia con cada gesto, y lo decide el estante. Los dos materiales son los mismos para
## todos los casilleros: lo que cambia entre dos casilleros es la forma y el lugar.
func _preparar_los_casilleros() -> void:
	var sin_superficie := ShaderMaterial.new()
	sin_superficie.shader = SIN_SUPERFICIE
	# La superficie invisible fija la profundidad antes de dibujar las aristas.
	sin_superficie.render_priority = -1
	for producto in Catalogo.todos():
		if disposicion.casilleros_de(producto.id) == 0:
			_casilleros.append([])
			_envolver_la_fila([])
			continue
		var modelo := _modelos[producto.id]
		var fantasma := modelo.duplicate() as ArrayMesh
		for superficie in fantasma.get_surface_count():
			var material := _material_de_la_gondola(modelo.surface_get_material(superficie))
			material.shader = POR_COLOCAR
			fantasma.surface_set_material(superficie, material)
		var fila := Node3D.new()
		fila.name = "ZonaDe" + producto.nombre
		add_child(fila)
		_generados.append(fila)
		var zonas: Array[ZonaDeReposicion] = []
		for indice in disposicion.casilleros_de(producto.id):
			var zona := ZonaDeReposicion.new()
			zona.name = "Casillero%d" % indice
			zona.producto = producto.id
			zona.casillero = indice
			zona.collision_layer = 0
			zona.collision_mask = 0
			zona.add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
			fila.add_child(zona)
			var caja := modelo.get_aabb()
			var copia := global_transform * _copia_del_casillero(producto.id, indice)
			zona.global_transform = Transform3D(copia.basis, copia * caja.get_center())
			var cuerpo := CollisionShape3D.new()
			var forma := BoxShape3D.new()
			forma.size = caja.size
			cuerpo.shape = forma
			zona.add_child(cuerpo)
			var vista := MeshInstance3D.new()
			vista.mesh = modelo
			vista.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			vista.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			vista.position = -caja.get_center()
			vista.material_override = sin_superficie
			vista.material_overlay = _aristas
			vista.visible = false
			zona.add_child(vista)
			var laterales := MeshInstance3D.new()
			laterales.mesh = modelo
			laterales.material_override = _laterales
			laterales.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			vista.add_child(laterales)
			zona.vista = vista
			zona.sin_superficie = sin_superficie
			var previsualizacion := MeshInstance3D.new()
			previsualizacion.mesh = fantasma
			previsualizacion.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			previsualizacion.position = vista.position
			previsualizacion.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			previsualizacion.visible = false
			zona.add_child(previsualizacion)
			zona.previsualizacion = previsualizacion
			zona.radio = caja.size.length() / 2.0
			zona.casillero_usado.connect(_usar_el_casillero)
			zonas.append(zona)
		_casilleros.append(zonas)
		_envolver_la_fila(zonas)


## La esfera que envuelve una fila entera: su centro es el promedio de sus casilleros, y su radio
## llega hasta el borde del más lejano.
func _envolver_la_fila(zonas: Array[ZonaDeReposicion]) -> void:
	var centro := Vector3.ZERO
	for zona in zonas:
		centro += zona.global_position / zonas.size()
	var radio := 0.0
	for zona in zonas:
		radio = maxf(radio, centro.distance_to(zona.global_position) + zona.radio)
	_centros_de_las_filas.append(centro)
	_radios_de_las_filas.append(radio)


## El origen de las últimas `adelante` copias de un bloque, que son su fila de adelante.
func _lugares_de_adelante(bloque: PackedFloat32Array, adelante: int) -> PackedVector3Array:
	var lugares := PackedVector3Array()
	var total := DisposicionDeLaGondola.copias(bloque)
	for indice in range(total - adelante, total):
		lugares.append(DisposicionDeLaGondola.copia(bloque, indice).origin)
	return lugares


## El dibujo de cada producto: sus casilleros, la fila de adelante de cada tanda fija suya y al
## final la de su tanda reponible. Un estante al que la apertura no le declara vacíos vacía los
## últimos, que así quedan en la reponible, a la altura de la mano. Lo que el modelo pone detrás
## de una fila no se dibuja: cada tanda se ve en una sola fila (BR-STK-025).
##
## **Cada producto va en un solo dibujo.** Cada nodo que se dibuja le cuesta al motor su
## preparación, y en la web esa preparación es lo que más pesa del cuadro: medido el 2026-09-21,
## las guías sueltas eran el 42 % del tiempo de dibujo mirando la góndola.
func _armar_los_bloques() -> void:
	var flotantes := DisposicionDeLaGondola.FLOTANTES_POR_COPIA
	var casilleros: Array[PackedFloat32Array] = []
	for producto in Catalogo.todos():
		casilleros.append(PackedFloat32Array())
	for indice in disposicion.guias.size():
		var id := disposicion.productos_de_las_guias[indice]
		var bloque := disposicion.guias[indice]
		if disposicion.base_de_guias == DisposicionDeLaGondola.BaseDeGuias.MODELO_DE_GUIA:
			var modelo := get_node(GUIA).get_child(indice) as MeshInstance3D
			var base := (contenido.get_child(id) as Node3D).global_basis
			bloque = _rebasar(bloque, modelo.global_basis, base)
		var atras := DisposicionDeLaGondola.copias(bloque)
		atras -= disposicion.filas_de_adelante_de_las_guias[indice]
		casilleros[id].append_array(bloque.slice(atras * flotantes))
	for producto in Catalogo.todos():
		var principal := disposicion.principales[producto.id]
		var atras := DisposicionDeLaGondola.copias(principal)
		atras -= disposicion.filas_de_adelante[producto.id]
		casilleros[producto.id].append_array(principal.slice(atras * flotantes))
		_bloques.append(casilleros[producto.id])


func _malla_en_mundo(grupo: MeshInstance3D) -> ArrayMesh:
	return _malla_con_la_vuelta(grupo.mesh, grupo.global_basis)


func _malla_con_la_vuelta(malla: Mesh, vuelta: Basis) -> ArrayMesh:
	var resultado := ArrayMesh.new()
	for superficie: int in malla.get_surface_count():
		var herramienta := SurfaceTool.new()
		herramienta.append_from(malla, superficie, Transform3D(vuelta, Vector3.ZERO))
		herramienta.set_material(malla.surface_get_material(superficie))
		herramienta.commit(resultado)
	return resultado


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


## Prende de la fila de adelante las unidades que la góndola tiene puestas, y apaga el resto.
##
## **Cuáles se ven las dice el estante, y no este puesto**: un número propio acá dibujaría una
## góndola que el inventario no tiene. `visible_instance_count` corta por el final, así que el
## dibujo se reordena: primero los casilleros ocupados y después los vacíos, que quedan fuera del
## corte. Cada copia
## lleva su lugar, así que reordenarlas no mueve ninguna: la que se agarró del medio deja un hueco
## en el medio.
func _mostrar_lo_puesto(id: Producto.Id) -> void:
	if _bloques[id].is_empty():
		return
	var producto := Catalogo.de(id)
	var de_la_noche := repositor.estante()
	var ocupados := de_la_noche.casilleros_ocupados(producto)
	_sincronizar_la_mercaderia(id, ocupados)
	var vencidos := de_la_noche.vencidos.casilleros(producto)
	var sanos: Array[int] = ocupados.filter(
		func(casillero: int) -> bool: return not vencidos.has(casillero)
	)
	var afuera := de_la_noche.casilleros_vacios(producto)
	var orden := sanos + vencidos + afuera
	var bloque := _bloques[id]
	var flotantes := DisposicionDeLaGondola.FLOTANTES_POR_COPIA
	var dibujo := PackedFloat32Array()
	for puesto in orden:
		var desde := puesto * flotantes
		dibujo.append_array(bloque.slice(desde, desde + flotantes))
	var copias := _grupos[id].multimesh
	if dibujo.size() == bloque.size():
		copias.buffer = dibujo
	copias.visible_instance_count = sanos.size()
	# Los mismos casilleros, en otro lote: los vacíos primero para cortarlos sin añadir nodos
	# por envase. El estado vuelve a salir del estante en cada cambio de la góndola.
	var corte := ocupados.size() * flotantes
	var por_reponer := dibujo.slice(corte)
	por_reponer.append_array(dibujo.slice(0, corte))
	var huecos := _huecos[id].multimesh
	huecos.buffer = por_reponer
	huecos.visible_instance_count = afuera.size()
	if id == Producto.Id.CINDOLOR and _vencidos_puestos != null:
		# Los vencidos van primero en su lote, y el resto queda fuera del corte.
		var del_lote := dibujo.slice(sanos.size() * flotantes, corte)
		del_lote.append_array(dibujo.slice(0, sanos.size() * flotantes))
		del_lote.append_array(dibujo.slice(corte))
		_vencidos_puestos.multimesh.buffer = del_lote
		_vencidos_puestos.multimesh.visible_instance_count = vencidos.size()
		_vencidos_puestos.visible = not vencidos.is_empty()


## Un `MultiMeshInstance3D` con todas las copias de un bloque, prendidas.
##
## **El buffer se escribe tal cual viene del recurso**: cada copia ya trae su lugar y su vuelta
## medidos del modelo, y el nodo cuelga de este puesto, que está sin transformar. Convertirlas
## acá sería medirlas dos veces.
func _dibujar(nombre: String, malla: Mesh, bloque: PackedFloat32Array) -> MultiMeshInstance3D:
	var grupo := MultiMeshInstance3D.new()
	grupo.name = nombre
	# Los envases no se mueven: al compactar el buffer cambia el casillero de cada índice.
	# Interpolar entre esos índices hace deslizar las demás unidades al sacar o colocar una.
	grupo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	grupo.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var copias := MultiMesh.new()
	copias.transform_format = MultiMesh.TRANSFORM_3D
	copias.mesh = malla
	copias.instance_count = DisposicionDeLaGondola.copias(bloque)
	if not bloque.is_empty():
		copias.buffer = bloque
	grupo.visible = not bloque.is_empty()
	copias.visible_instance_count = copias.instance_count
	grupo.multimesh = copias
	add_child(grupo)
	_generados.append(grupo)
	return grupo


func retirar(id: Producto.Id) -> void:
	var contenido := repositor.caja(id).producto.id
	var unidad := _cuerpo_para(contenido)
	if not repositor.pedir_retirar(id, unidad):
		_guardar_cuerpo(unidad)
		return
	_vestir(unidad, contenido)


## Cómo lo inclina la mano. Lo alto va echado hacia arriba. Lo que es más hondo que alto —una
## caja exhibidora, una lata de atún— se muestra por arriba: va hacia abajo y a la izquierda, y
## de frente a la cámara se leería como una figurita plana. Sale del modelo, ya de frente y
## derecho, y no de una lista.
func _inclinacion_en_la_mano(id: Producto.Id) -> Basis:
	var de_frente := Basis(Vector3.UP, deg_to_rad(_giro_del_frente(id))) * _derecho(id)
	var caja: AABB = Transform3D(de_frente, Vector3.ZERO) * _modelos[id].get_aabb()
	if caja.size.z > caja.size.y:
		return Basis.from_euler(Vector3(deg_to_rad(8), deg_to_rad(-40), deg_to_rad(-8)))
	return Basis.from_euler(Vector3(deg_to_rad(-17), deg_to_rad(-20), 0))


## El cuerpo para una unidad de ese producto que va a la mano: el guardado, o uno nuevo.
func _cuerpo_para(id: Producto.Id) -> ObjetoAgarrable:
	var unidad := _disponible
	_disponible = null
	if unidad == null:
		unidad = OBJETO.instantiate()
		add_child(unidad)
		_unidades.append(unidad)
		unidad.add_collision_exception_with(jugador)
		unidad.material_de_foco = _aristas
	# El frente de cada modelo se alinea antes de darle la inclinación de la mano, y antes de eso
	# se endereza lo que en su estante va echado: la inclinación de la rampa es del estante.
	unidad.orientacion_en_mano = (
		_inclinacion_en_la_mano(id)
		* Basis(Vector3.UP, deg_to_rad(_giro_del_frente(id)))
		* _derecho(id)
	)
	unidad.collision_layer = 1
	# Choca también con el contorno de los muebles: caída al pie de una góndola, la unidad rodaba
	# hacia adentro del estante de abajo.
	unidad.collision_mask = ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO
	return unidad


## Le pone al cuerpo que ya está en la mano la malla y la forma de su producto.
func _vestir(unidad: ObjetoAgarrable, id: Producto.Id) -> void:
	unidad.show()
	var malla := _modelos[id]
	var datos := unidad.datos
	if datos != null and datos.vencido and id == Producto.Id.CINDOLOR:
		malla = _modelo_vencido
	var limites := malla.get_aabb()
	var vista: MeshInstance3D = unidad.get_node("Malla")
	vista.mesh = malla
	vista.scale = Vector3.ONE * 1.1
	vista.position = -limites.get_center() * 1.1
	unidad.get_node("Forma").shape = _formas[id]


func _ampliar_producto_en_mano(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		var vista: MeshInstance3D = nodo.get_node("Malla")
		vista.scale = Vector3.ONE * 1.1
		vista.position = -vista.mesh.get_aabb().get_center() * 1.1


func _restaurar_tamano_del_producto(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		var vista: MeshInstance3D = nodo.get_node("Malla")
		vista.scale = Vector3.ONE
		vista.position = -vista.mesh.get_aabb().get_center()


## La unidad que el estante aceptó deja de ser un cuerpo y pasa a ser una copia del dibujo: la de
## su casillero, que el estante ya dice ocupado.
func depositar(unidad: Node3D, producto: Producto, _unidades: int) -> void:
	_mostrar_lo_puesto(producto.id)
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


func _limpiar_unidades() -> void:
	var grupos := _sueltos.duplicate()
	if _vencidos_sueltos != null:
		grupos.append(_vencidos_sueltos)
	for grupo: GrupoDelPiso in grupos:
		while not grupo.cuerpos.is_empty():
			grupo.quitar(grupo.cuerpos[-1])
	for unidad in _unidades:
		if is_instance_valid(unidad):
			unidad.queue_free()
	_unidades.clear()
	_disponible = null


func limpiar() -> void:
	_limpiar_unidades()
	# **Se recorre lo que hay y no el catálogo.** La apertura de la jornada llama acá antes de
	# que el puesto se haya preparado, y entonces todavía no hay un grupo por producto: indexar
	# por `id` mata el primer cuadro con un `Out of bounds` que no nombra ni a la jornada ni a
	# este puesto.
	for id in _grupos.size():
		_mostrar_lo_puesto(id)
	_actualizar_zonas()


## Conserva los cuerpos de la recepción y vuelve a agrupar sólo su dibujo.
func recibir_abandonadas(cuerpos: Array[Node3D], punto: Marker3D) -> void:
	var ocupados: Array[AABB] = []
	for suelta in unidades_sueltas():
		if not is_instance_valid(suelta) or suelta.is_queued_for_deletion():
			continue
		var forma: CollisionShape3D = suelta.get_node("Forma")
		var volumen := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		ocupados.append(volumen.grow(TOLERANCIA_DEL_APOYO))
	var preparados: Array[ObjetoAgarrable] = []
	var posiciones: Array[Vector3] = []
	for nodo in cuerpos:
		var cuerpo := nodo as ObjetoAgarrable
		var lugar := _lugar_para_abandonada(cuerpo, punto, ocupados)
		if not lugar.is_finite():
			push_error("No hay piso libre para la entrega abandonada frente a la ventanilla.")
			return
		preparados.append(cuerpo)
		posiciones.append(lugar)
	for indice in preparados.size():
		var cuerpo := preparados[indice]
		cuerpo.reparent(self)
		cuerpo.top_level = false
		cuerpo.global_basis = Basis.IDENTITY
		cuerpo.global_position = posiciones[indice]
		cuerpo.reset_physics_interpolation()
		_restaurar_tamano_del_producto(cuerpo)
		cuerpo.show()
	# Las consultas anteriores ven los sólidos existentes; las huellas reservan este lote
	# antes de que el servidor sincronice los nuevos cuerpos en el próximo cuadro físico.
	for cuerpo in preparados:
		cuerpo.collision_layer = 1
		cuerpo.collision_mask = ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO
		cuerpo.linear_velocity = Vector3.ZERO
		cuerpo.angular_velocity = Vector3.ZERO
		cuerpo.freeze = false
		cuerpo.sleeping = false
		_agrupar_suelto(cuerpo)


func _lugar_para_abandonada(
	cuerpo: ObjetoAgarrable, punto: Marker3D, ocupados: Array[AABB]
) -> Vector3:
	var forma: CollisionShape3D = cuerpo.get_node("Forma")
	var limites := forma.transform * forma.shape.get_debug_mesh().get_aabb()
	var paso := maxf(limites.size.x, limites.size.z) + TOLERANCIA_DEL_APOYO * 2.0
	var espacio := get_world_3d().direct_space_state
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.collision_mask = ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO
	consulta.exclude = [cuerpo.get_rid()]
	consulta.margin = TOLERANCIA_DEL_APOYO / 4.0
	var pasos := ceili(ReglasDelJugador.ALCANCE_DE_LA_MIRA / paso)
	var candidatos: Array[Vector3] = []
	for profundidad in range(pasos + 1):
		for lateral in range(-pasos, pasos + 1):
			var desplazamiento := Vector3(lateral * paso, 0.0, -profundidad * paso)
			if desplazamiento.length() <= ReglasDelJugador.ALCANCE_DE_LA_MIRA:
				candidatos.append(desplazamiento)
	candidatos.sort_custom(
		func(a: Vector3, b: Vector3) -> bool: return a.length_squared() < b.length_squared()
	)
	for desplazamiento in candidatos:
		var lugar := punto.global_transform * desplazamiento
		var rayo := PhysicsRayQueryParameters3D.create(
			lugar + Vector3.UP, lugar + Vector3.DOWN, consulta.collision_mask
		)
		rayo.exclude = [cuerpo.get_rid()]
		var piso := espacio.intersect_ray(rayo)
		if piso.get("collider") != suelo:
			continue
		lugar.y = (
			(piso["position"] as Vector3).y - limites.position.y + TOLERANCIA_DEL_APOYO * 4.0
		)
		consulta.transform = Transform3D(Basis.IDENTITY, lugar) * forma.transform
		if not espacio.intersect_shape(consulta, 1).is_empty():
			continue
		var volumen := AABB(lugar + limites.position, limites.size).grow(TOLERANCIA_DEL_APOYO)
		var reservado := false
		for ocupado in ocupados:
			if volumen.intersects(ocupado):
				reservado = true
				break
		if reservado:
			continue
		ocupados.append(volumen)
		return lugar
	return Vector3.INF

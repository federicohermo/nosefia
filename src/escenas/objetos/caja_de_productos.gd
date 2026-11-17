## La caja del depósito: se lleva, se apoya, y declara qué producto guarda.
##
## No decide nada. Cuántas unidades tiene, qué hace el clic sobre ella y qué dice al examinarla
## lo contesta su contenido, en `dominio/`, contado sobre el depósito de la noche: por eso la caja
## no guarda ningún número. `reposicion_manual.gd` busca la acción del gesto que le contesta.
##
## **Su cuerpo es rígido pero congelado.** Apoyada se porta como algo estático —no rebota, no
## rueda, no tiembla— y el puesto le escribe el lugar derecho, que es lo que deja apoyar una caja
## entrando justa en un estante. Se descongela sólo cuando pierde lo que la sostenía, y ahí cae:
## es lo que desarma una pila cuando le sacan una de abajo. **Cuándo despertarla no se decide
## acá**, lo pide el puesto; volver a dormirse lo resuelve el motor.
extends RigidBody3D

## La caja se va a correr. Para el motor es un cuerpo estático, y lo apoyado encima no se
## entera: lo despierta el puesto.
signal empujada(caja: Node3D)

## La caja quedó apoyada. Apoyada no cae: el puesto la ubica congelada, así que el motor nunca
## avisa un choque, y el audio la escucha por acá. Misma firma que `ObjetoAgarrable`.
signal contacto_recibido(nodo: Node3D, rapidez: float)

## Media caja de cada tamaño, en metros: la escala del cubo de dos de su malla y de su cuerpo.
## Qué tamaño lleva cada producto lo dice el catálogo; cuánto mide cada tamaño es de la escena.
const MEDIA_CAJA := {Catalogo.TamanoDeCaja.CHICA: 0.2, Catalogo.TamanoDeCaja.GRANDE: 0.3037077}

## La etiqueta de cada producto, por el nombre de su PNG. Las primeras las dibujó el artista; las
## que siguen a Terminator son su misma caja con el logo del envase en tinta, porque no había
## arte. Agregar la de un producto es una línea acá y su copia en `assets/source/boxes/`, con
## el nombre en ASCII: el del artista lleva acentos, y «Ó» se escribe distinto en cada sistema
## de archivos.
##
## **Las etiquetas viajan en un atlas.** `armar_atlas.py` las junta, y `atlas_de_cajas.json`
## dice en qué rectángulo cae cada una. Sin ese reparto una caja no sabe qué dibujar.
const ETIQUETAS := {
	Producto.Id.ACTRONCITO: "actroncito",
	Producto.Id.DUREXTRA: "durextra",
	Producto.Id.BURBALOO: "burbaloo",
	Producto.Id.ZUCARACHAS: "zucarachas",
	Producto.Id.LAYSNNT: "laysntt",
	Producto.Id.JORGILLO: "jorgillo",
	Producto.Id.FROT_LUPS: "frotlups",
	Producto.Id.AMARGADITO: "amargadito",
	Producto.Id.CINDOLOR: "cindolor",
	Producto.Id.FLIM_POF: "flinpuf",
	Producto.Id.DON_SATURADOS: "donsaturados",
	Producto.Id.PETISAS: "petisas",
	Producto.Id.MACUMBAS: "macumbas",
	Producto.Id.COSA_DE_MANI: "cosa_de_mani",
	Producto.Id.DURONGA: "duronga",
	Producto.Id.FERNET_GOD: "fernet_god",
	Producto.Id.MAYONCHIS: "mayonchis",
	Producto.Id.OAAAA: "oaaaa",
	Producto.Id.TERMINATOR: "terminator",
	Producto.Id.MALBARDO: "malbardo",
	Producto.Id.PROGRES: "prongles",
	Producto.Id.ARVECOR: "arvejas",
	Producto.Id.CHISITOS: "chisitos",
	Producto.Id.OREMOS: "oremos",
	Producto.Id.PEPITO: "pepitos",
	Producto.Id.SALADICK: "saladik",
	Producto.Id.UAKALAS: "uakas",
	Producto.Id.PURA_COLA: "coracola",
	Producto.Id.MAROLINI: "marolini",
	Producto.Id.MARRANOS: "marranos",
	Producto.Id.FEEL_RICKY_FORT: "feel_ricky_fort",
	Producto.Id.POETICO: "poetico",
}

const RUTA_DEL_REPARTO := "res://assets/boxes/atlas_de_cajas.json"

@export var producto: Producto.Id = Producto.Id.ACTRONCITO
@export var datos: ObjetoDelAlmacen
@export var mallas: Array[MeshInstance3D] = []

## Cómo queda en la mano: de frente y mostrando su cara rotulada. La lee `Agarre` al colgarla.
@export var orientacion_en_mano := Basis.IDENTITY

var _lugar_de_origen: Transform3D
var _padre_de_origen: Node = null
var _origen_en_el_mundo: Transform3D
var _pose_de_estanteria: Transform3D

## Dónde se apoyó por última vez. Lo pregunta el puesto al levantarla: para cuando avisa que la
## agarró, la caja ya cuelga de la mano y el volumen que dejó libre no lo sabe nadie más.
var _apoyo_que_dejo := Vector3.ZERO


func _ready() -> void:
	collision_mask = ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO
	# Antes de anotar el lugar: el tamaño cambia dónde apoya, y el `.tscn` ya lo cuenta.
	for parte: Node3D in [get_node("Cuerpo"), get_node("Malla")]:
		parte.scale = Vector3.ONE * media()
	_ponerse_su_etiqueta()
	_lugar_de_origen = transform
	_padre_de_origen = get_parent()
	_origen_en_el_mundo = global_transform
	_pose_de_estanteria = global_transform
	_apoyo_que_dejo = global_position
	sleeping_state_changed.connect(_al_cambiar_el_reposo)


## Suelta la etiqueta al destruir la caja; reparentarla conserva el material y la textura.
func _notification(que: int) -> void:
	if que == NOTIFICATION_PREDELETE:
		var malla := get_node_or_null("Malla") as MeshInstance3D
		if malla != null:
			malla.set_surface_override_material(0, null)


## Viste la malla con la etiqueta de su producto: el material de la caja genérica, con el atlas
## como textura y el rectángulo de su producto como escala y desplazamiento de la UV. Así filtra
## pixelado igual, y en la web usa el mismo shader, que ya está compilado.
##
## Va como material de la superficie y no como `material_override`, que el calentamiento de
## shaders dibuja de a uno por cuadro. Medido: treinta cuadros más, y ningún shader nuevo.
##
## La malla es la del modelo, y lleva la etiqueta en sus caras ±X. Cuál ve el cuarto lo decide
## el giro de cada caja en `objetos_del_almacen.tscn`.
func _ponerse_su_etiqueta() -> void:
	var malla: MeshInstance3D = get_node("Malla")
	var generico := malla.mesh.surface_get_material(0) as BaseMaterial3D
	var rotulado := generico.duplicate() as BaseMaterial3D
	var reparto := _reparto()
	var etiqueta: Dictionary = reparto.get("cajas", {}).get(ETIQUETAS.get(producto, ""), {})
	if not etiqueta.is_empty():
		var atlas: String = etiqueta["atlas"]
		var tamano: Array = reparto["atlas"][atlas]
		var rect: Array = etiqueta["rect"]
		rotulado.albedo_texture = load("res://assets/boxes/" + atlas)
		rotulado.uv1_scale = Vector3(rect[2] / float(tamano[0]), rect[3] / float(tamano[1]), 1.0)
		rotulado.uv1_offset = Vector3(rect[0] / float(tamano[0]), rect[1] / float(tamano[1]), 0.0)
	malla.set_surface_override_material(0, rotulado)


## Dónde cae la etiqueta de cada caja. Sin el atlas armado no hay reparto, y la caja queda con la
## textura genérica en vez de tirar el juego: `test_atlas_al_dia.py` es quien exige el atlas.
static func _reparto() -> Dictionary:
	if not ResourceLoader.exists(RUTA_DEL_REPARTO):
		return {}
	return (load(RUTA_DEL_REPARTO) as JSON).data


func es_grande() -> bool:
	return Catalogo.caja_de(producto) == Catalogo.TamanoDeCaja.GRANDE


func media() -> float:
	return MEDIA_CAJA[Catalogo.caja_de(producto)]


func interactuar() -> ObjetoDelAlmacen:
	return datos


func lugar_de_origen() -> Transform3D:
	return _origen_en_el_mundo


## El volumen que ocupaba cuando estaba apoyada. Lo usa el puesto para saber a quién despertar.
func apoyo_que_dejo() -> Vector3:
	return _apoyo_que_dejo


## Queda quieta donde la dejaron: sin velocidad, congelada y dormida.
##
## La llama el puesto **después** de ubicarla. Soltar la deja como un cuerpo vivo —es lo que
## `Agarre` hace con todo lo que se suelta—, y un cuerpo vivo se acomoda solo: una caja que entró
## justa en un estante se saldría sola al cuadro siguiente de haberla dejado bien.
func quedarse_quieta() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	sleeping = true
	# El apoyo se anota acá y no sólo en la señal: `sleeping_state_changed` avisa los CAMBIOS, y
	# una caja que ya venía dormida —que es el caso normal, porque el puesto la ubica congelada—
	# no cambia nada. Medido: sin esta línea el apoyo se queda en el que le puso el `.tscn`.
	_apoyo_que_dejo = global_position


## La despierta, y entonces cae hasta encontrar dónde apoyarse.
##
## La llama el puesto cuando le sacan de abajo lo que la sostenía. Quedarse quieta otra vez no
## hace falta pedirlo: el motor la duerme al frenar y de ahí se agarra `_al_cambiar_el_reposo()`.
func soltarse() -> void:
	freeze = false
	sleeping = false


## Congelada mientras duerme, viva mientras no. Es lo que la deja lista para que le vuelvan a
## escribir el lugar: a un cuerpo rígido despierto no se le mueve el `transform` a mano.
##
## No decide nada, y por eso son dos asignaciones: la señal avisa los dos cambios —se durmió y se
## despertó—, y en los dos `freeze` vale lo mismo que `sleeping`. El apoyo se anota en los dos
## por el mismo motivo: al despertarse todavía está donde descansaba, y al dormirse ya está donde
## aterrizó.
func _al_cambiar_el_reposo() -> void:
	freeze = sleeping
	_apoyo_que_dejo = global_position


## El dominio se resetea y los nodos no: sin esto la jornada siguiente arranca con la caja donde
## la dejó la anterior.
##
## Vuelve también de padre, y no sólo de lugar: la noche puede terminar con la caja en la mano,
## y ahí `transform` es relativo al cuerpo del jugador. Escribirlo sin despegarla la deja
## flotando pegada a él toda la noche siguiente.
func volver_a_su_lugar() -> void:
	top_level = false
	reparent(_padre_de_origen, false)
	transform = _lugar_de_origen
	quedarse_quieta()


## Se arrastra por el piso cuando el jugador la empuja al pasar. Cuánto recibe lo dice el
## dominio; acá sólo se mueve, en horizontal y sin dar vuelta nada.
##
## Avisa **antes** de correrse: lo que hay que despertar está sobre el apoyo que todavía ocupa.
func empujar(desplazamiento: Vector3) -> void:
	var arrastre := desplazamiento * ReglasDeLosObjetos.ARRASTRE_DE_LA_CAJA
	arrastre.y = 0.0
	empujada.emit(self)
	move_and_collide(arrastre)
	_apoyo_que_dejo = global_position


func pose_de_estanteria() -> Transform3D:
	return _pose_de_estanteria


func declarar_origen(pose: Transform3D) -> void:
	_origen_en_el_mundo = pose
	_lugar_de_origen = (_padre_de_origen as Node3D).global_transform.affine_inverse() * pose

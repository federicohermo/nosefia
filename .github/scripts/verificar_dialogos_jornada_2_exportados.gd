## Correr con --main-pack desde una carpeta externa; el preset no incluye los tests.
extends SceneTree

const TEXTOS: Array[String] = [
	"Hola, ¿qué tal? Qué tarde se hizo… me alegra que todavía esté abierto el negocio.",
	(
		"Salí tardísimo del trabajo y no tuve un buen día. No vendimos suficiente. "
		+ "Por eso busco un momento de tranquilidad y placer, ¿vos entendes?"
	),
	"Quiero una botella de jabón Poético, una lata de papitas Progres y unos preservativos Duronga.",
	(
		"¡Guau, salió la colección de los productos del Chiqui Tapia! No me había dado cuenta. "
		+ "Ese señor es mi ídolo. Siempre me da los mejores tips."
	),
	"Gracias, compañero. Cuando quieras podes venir a casa y los probamos juntos.",
	"Hola… ¿me darías un vino Terminator, un Fernet God y una cajita de Actroncito?",
	"Zzzzzz.zzzzz.zzzzz",
	"Perdon, me quedé dormida... ¿En dónde estaba?",
	"Ah sí, gracias… Espero que esto me ayude a dormir mejor…"
]

var _local: Node3D
var _fallos: Array[String] = []


func _initialize() -> void:
	create_timer(90.0).timeout.connect(_vencer)
	_recorrer.call_deferred()


func _vencer() -> void:
	push_error("PAQUETE444: tiempo máximo sin terminar")
	quit(1)


func _exigir(condicion: bool, texto: String) -> bool:
	if not condicion:
		_fallos.append(texto)
		push_error("PAQUETE444: " + texto)
	return condicion


func _cuadros(cantidad: int = 3) -> void:
	for _cuadro: int in cantidad:
		await process_frame


func _pulsar() -> void:
	var puesto: Node = _local.get_node("Estructura/Ventanilla")
	if puesto.get("_abierta"):
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = true
		puesto.call("_input", clic)
	else:
		puesto.get_node("Comprador/Objetivo").call("accionar")
	await _cuadros(1)


func _pasar_entradas(atencion: RefCounted, esperadas: PackedStringArray) -> void:
	var dialogo: RefCounted = atencion.call("dialogo")
	if not _exigir(dialogo != null, "La conversación exportada no empezó"):
		return
	for texto: String in esperadas:
		_exigir(not dialogo.call("terminado"), "La conversación terminó antes de su última entrada")
		_exigir(
			dialogo.call("entrada_actual") == texto, "Una entrada exportada difiere del recurso"
		)
		await _pulsar()
	_exigir(dialogo.call("terminado"), "La conversación no terminó con su último avance")
	_exigir(
		not _local.get_node("Estructura/Ventanilla").get("_abierta"),
		"El último avance no devolvió la vista"
	)
	_exigir(
		not _local.get_node("Jugador").call("suspendido"), "El último avance no devolvió el control"
	)


func _ticket(pedido: RefCounted) -> Node3D:
	var caja: Node = _local.get("_caja")
	caja.call("pedir_borrar")
	var unidad_script: Script = load("res://src/dominio/almacen/unidad_de_producto.gd")
	for producto: RefCounted in pedido.call("productos"):
		for _unidad: int in pedido.call("unidades_de", producto):
			caja.call("pedir_anotar", unidad_script.new(producto))
	caja.call("pedir_imprimir")
	var destino: Node = _local.get("_puesto_de_la_caja").get("destino_de_los_tickets")
	var clase_ticket: Script = load("res://src/dominio/almacen/ticket.gd")
	for hijo: Node in destino.get_children():
		var datos: Variant = hijo.get("datos")
		if (
			hijo is Node3D
			and hijo.visible
			and datos is Resource
			and datos.get_script() == clase_ticket
		):
			return hijo as Node3D
	_exigir(false, "La impresora del paquete no produjo ticket")
	return null


func _probar(
	nombre: String, inicial: StringName, final: StringName, tiempo: float, esperado: Resource
) -> void:
	var clase_partida: Script = load("res://src/dominio/empleo/partida.gd")
	var partida: RefCounted = clase_partida.call("desde", {"jornada": 5})
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	if not _exigir(escena != null, "El paquete no contiene el almacén"):
		return
	_local = escena.instantiate()
	_local.set("_partida", partida)
	root.add_child(_local)
	await _cuadros(4)
	var reloj: Node = _local.get("_reloj")
	reloj.set_process(false)
	reloj.call("avanzar", tiempo)
	await _cuadros(3)
	var atenciones: Node = _local.get("_atenciones")
	var atencion: RefCounted = atenciones.call("atencion")
	if not _exigir(atencion != null, "No llegó " + nombre):
		await _limpiar()
		return
	var comprador: RefCounted = atencion.call("comprador")
	_exigir(comprador.call("nombre") == nombre, "La selección exportada usó otro comprador")
	var guion: Resource = comprador.get("dialogos")
	_exigir(guion == esperado, "La atención no usa el guion productivo de jornada 5")
	var puesto: Node = _local.get_node("Estructura/Ventanilla")
	var sprite: AnimatedSprite3D = puesto.get("comprador_visible")
	var carpeta := "fede" if nombre == "Fede" else "mia"
	_exigir(sprite.visible, "La figura está oculta con panel cerrado")
	_exigir(
		sprite.sprite_frames.resource_path == "res://assets/characters/%s/idle.tres" % carpeta,
		"La figura exportada pertenece a otro comprador"
	)
	_exigir(
		sprite.sprite_frames.get_frame_count(&"idle") == 8, "La figura perdió dibujos al exportar"
	)
	for cuadro: int in 8:
		_exigir(
			sprite.sprite_frames.get_frame_texture(&"idle", cuadro) != null,
			"Falta una textura exportada"
		)
	await _pulsar()
	_exigir(
		_local.get_node("Jugador").call("suspendido"), "El primer clic no encuadra al comprador"
	)
	await _pasar_entradas(atencion, guion.get(inicial))
	var pedido: RefCounted = comprador.call("pedido")
	var reposicion: Node = _local.get("_reposicion_manual")
	var agarre: Node = _local.get("_agarre")
	for producto: RefCounted in pedido.call("productos"):
		reposicion.call("retirar", producto.get("id"))
		_exigir(agarre.call("cuerpo_sostenido") != null, "No se extrajo la unidad del paquete")
		await _pulsar()
		_exigir(agarre.call("cuerpo_sostenido") == null, "La entrega no recibió la unidad")
	var papel := _ticket(pedido)
	if papel != null:
		_exigir(
			agarre.call("pedir_agarrar", papel.get("datos"), papel), "No se pudo agarrar el ticket"
		)
		await _pulsar()
		_exigir(atencion.call("vendida"), "El pedido completo exportado no se vendió")
		await _pasar_entradas(atencion, guion.get(final))
		_exigir(atencion.call("despachada"), "La despedida exportada no terminó el despacho")
	await _limpiar()


func _limpiar() -> void:
	if is_instance_valid(_local):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _local.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_local.queue_free()
	_local = null
	await _cuadros(4)


func _recorrer() -> void:
	var guion: Resource = load("res://assets/dialogos/compradores_jornada_2.tres")
	if _exigir(guion != null, "El paquete no contiene los diálogos de jornada 5"):
		var bloques := {&"fede": 3, &"despedida_fede": 2, &"mia": 1, &"despedida_mia": 3}
		var textos := PackedStringArray()
		for bloque: StringName in bloques:
			var entradas: PackedStringArray = guion.get(bloque)
			_exigir(entradas.size() == bloques[bloque], "Cambió la división narrativa exportada")
			for entrada: String in entradas:
				textos.append(entrada.replace("[color=#e4f850]", "").replace("[/color]", ""))
		_exigir(
			Array(textos) == TEXTOS, "Los nueve textos exportados difieren de la fuente narrativa"
		)
		var nombres := [
			["Poético", "Progres", "Duronga"], ["Terminator", "Fernet God", "Actroncito"]
		]
		for indice: int in 2:
			var entradas: PackedStringArray = guion.get(&"fede" if indice == 0 else &"mia")
			var texto := entradas[-1]
			for nombre: String in nombres[indice]:
				_exigir(
					texto.contains("[color=#e4f850]%s[/color]" % nombre),
					"Falta un destacado amarillo exportado"
				)
			_exigir(
				not texto.contains("[b]") and not texto.contains("[url"),
				"Se agregó negrita o pista al pedido"
			)
		var ritmo: Script = load("res://src/dominio/jornada/ritmo.gd")
		var factor: float = ritmo.call("de_la_jornada", 5)
		await _probar("Fede", &"fede", &"despedida_fede", 1800.0 / factor, guion)
		await _probar("Mía", &"mia", &"despedida_mia", 32400.0 / factor, guion)
	_salir.call_deferred()


func _salir() -> void:
	print("PAQUETE444_FINAL fallos=%d" % _fallos.size())
	quit(0 if _fallos.is_empty() else 1)

## Dibuja el shader de agua y manchas sobre un panel que ocupa la vista entera.
##
## No mide nada. En la web lo maneja `.github/scripts/medir_sombreado.mjs`: elige el caso con
## `window.mostrar_caso`, y toma el tiempo de GPU y la captura desde el navegador.
extends Node3D

const ASPECTO := preload("res://src/escenas/objetos/agua_y_manchas.gdshader")
const LADO_DE_LAS_ONDAS := 64
const HACIA_LA_LUZ := Vector3(-0.41, 0.88, 0.23)

## El navegador llama a esta referencia: si se suelta, el pedido no llega.
var _al_pedir_un_caso: JavaScriptObject

@onready var _camara: Camera3D = $Camara
@onready var _panel: MeshInstance3D = $Panel


func _ready() -> void:
	get_viewport().size_changed.connect(_ajustar_el_panel)
	_ajustar_el_panel()
	mostrar(casos().keys()[0])
	if OS.has_feature("web"):
		_al_pedir_un_caso = JavaScriptBridge.create_callback(_atender)
		var ventana: Variant = JavaScriptBridge.get_interface("window")
		ventana.mostrar_caso = _al_pedir_un_caso


## Los parámetros del shader de cada caso. Lo que un caso no nombra queda en su valor por defecto.
static func casos() -> Dictionary[String, Dictionary]:
	var ninguna: Color = ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.NINGUNA]
	var limpia: Color = ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.LIMPIA]
	var rosa: Color = ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.ROSA]
	# El balde trae sus normales en la malla y no asigna ninguna textura de ondas.
	var balde := {
		"normal_de_la_malla": true,
		"color_del_agua": rosa,
		"densidad_de_solucion": 1.0,
		"transparencia": 0.4,
		"hacia_la_luz": HACIA_LA_LUZ,
		"brillo": 0.65,
	}
	var mezcla := {"color_previo": limpia, "densidad_previa": 0.0, "progreso_de_mezcla": 0.5}
	var sin_color := {"color_del_agua": ninguna, "densidad_de_solucion": 0.0}
	var bano := {
		"color_del_agua": Color(0.62, 0.66, 0.64, 0.3),
		"hacia_la_luz": HACIA_LA_LUZ,
		"ondas": ImageTexture.create_from_image(ondas()),
		"texel": Vector2.ONE / LADO_DE_LAS_ONDAS,
	}
	return {
		"agua_de_malla": balde,
		"agua_en_mezcla": balde.merged(mezcla),
		"agua_sin_color": balde.merged(sin_color, true),
		"agua_del_bano": bano,
	}


## Anillos alrededor del centro, con pendiente de sobra para que la normal cambie a la vista.
static func ondas() -> Image:
	var imagen := Image.create_empty(LADO_DE_LAS_ONDAS, LADO_DE_LAS_ONDAS, false, Image.FORMAT_RF)
	var centro := Vector2.ONE * LADO_DE_LAS_ONDAS / 2.0
	for y: int in LADO_DE_LAS_ONDAS:
		for x: int in LADO_DE_LAS_ONDAS:
			var altura := 0.05 * sin(Vector2(x, y).distance_to(centro) * 0.6)
			imagen.set_pixel(x, y, Color(altura, 0.0, 0.0))
	return imagen


static func material_de(parametros: Dictionary) -> ShaderMaterial:
	var pintura := ShaderMaterial.new()
	pintura.shader = ASPECTO
	for parametro: String in parametros:
		pintura.set_shader_parameter(parametro, parametros[parametro])
	return pintura


func mostrar(nombre: String) -> void:
	_panel.material_override = material_de(casos()[nombre])


func _atender(argumentos: Array) -> void:
	var nombre := str(argumentos[0])
	if not casos().has(nombre):
		push_error("El escenario no tiene el caso «%s»." % nombre)
		return
	mostrar(nombre)
	# El runner lee esta marca antes de medir: sin ella mediría el caso anterior.
	var ventana: Variant = JavaScriptBridge.get_interface("window")
	ventana.caso_mostrado = nombre


func _ajustar_el_panel() -> void:
	var vista := get_viewport().get_visible_rect().size
	var distancia := _camara.global_position.distance_to(_panel.global_position)
	var esquina := _camara.project_position(Vector2.ZERO, distancia)
	var opuesta := _camara.project_position(vista, distancia)
	(_panel.mesh as PlaneMesh).size = Vector2(opuesta.x - esquina.x, opuesta.z - esquina.z)

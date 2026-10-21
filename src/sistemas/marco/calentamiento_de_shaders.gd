## Dibuja una vez cada objeto de una escena, con una cámara que la abarca entera, antes de que el
## jugador la vea.
##
## Compatibility no precompila shaders: cada variante se compila la primera vez que se dibuja, y
## en la web cada una frena el navegador alrededor de un segundo. Dibujarlas detrás de la pantalla
## de carga las saca del medio del juego. La cámara propia está para que entren todos los objetos,
## y con ellos todas las luces: la variante depende de las luces que tocan al objeto.
class_name CalentamientoDeShaders
extends Node

signal avanzo(progreso: float)
signal terminado

## Cuánto más arriba del techo va la cámara, para que el techo entre en el cuadro.
const ALTURA_EXTRA := 10.0
const CONTORNO := preload("res://src/sistemas/marco/contorno.gdshader")
## Cuántos materiales nuevos destapa un cuadro. Todos juntos compilaban ~125 programas en un solo
## cuadro: la web quedaba congelada 10 s y la barra no se movía. Medido el 2026-10-16. De a uno,
## sin cola, cada paso sumaba sus cuadros de asentamiento: 14 s más en Firefox, el 2026-10-19.
## Con 8 o 16 la carga no baja y aparecen variantes de luces que la partida no usa.
const MATERIALES_NUEVOS_POR_CUADRO := 4
## Cuánto tarda el navegador en enlazar un programa de la cola, hasta medirlo en la corrida. Es lo
## que tardó sin caché, en Chrome con ANGLE sobre D3D11: con caché, la cola se vacía antes.
const SEGUNDOS_POR_PROGRAMA := 0.16
const BUILD_CON_VARIANTES_UNIFICADAS := "nosefia_classdb_1_variantes"
const PASO_DEL_RECORRIDO := 1.0
const PASO_DEL_RADIO := 0.25

## Cuántos programas pidió la plantilla web y todavía no puede dibujar. Devuelve −1 si la
## plantilla no enlaza en paralelo: ahí cada programa nuevo frena el cuadro que lo pide.
var programas_en_cola: Callable = _cola_de_la_plantilla
## Si el motor que corre dibuja igual la omni y el foco sin sombra y las sondas faltantes: la
## plantilla web y el motor de escritorio de la receta de variantes los unifican. Con otro motor,
## esas luces y sondas siguen separando variantes.
var unifica_variantes: Callable = func() -> bool:
	return unifica_variantes_en(
		OS.has_feature("web"), str(Engine.get_version_info().get("build", ""))
	)
var ahora: Callable = Time.get_ticks_usec

var _pendientes: Array[GeometryInstance3D] = []
var _objetos: Array[GeometryInstance3D] = []
## Lo que estaba oculto también se dibuja, porque aparece después en medio del juego. Al terminar
## vuelve a quedar oculto.
var _ocultos: Array[GeometryInstance3D] = []
var _vistos: Dictionary = {}
var _total := 0
## Con cola, el progreso es tiempo sobre tiempo estimado: destapar y enlazar no duran lo mismo,
## y cuánto dura enlazar depende del caché del navegador.
var _con_cola := false
var _cola := 0
var _inicio := 0
var _fin_del_destape := -1
var _cola_al_destapar := 0
var _camara: Camera3D
var _anterior: Camera3D
var _contornos_listos := false
var _pases_originales: Dictionary[Material, Material] = {}
var _parametros_originales: Dictionary[ShaderMaterial, Dictionary] = {}
var _escena: Node3D
var _reflejos: Dictionary[ReflectionProbe, Vector2i] = {}
## Las que alumbran al empezar. Se toman antes de ocultar la geometría: una luz hija de una malla
## se oculta con ella.
var _luces: Array[Light3D] = []
var _muestras: Array[GeometryInstance3D] = []
var _por_muestrear: Array[GeometryInstance3D] = []
var _firmas: Dictionary[GeometryInstance3D, int] = {}
var _cuadros_de_asentamiento := 0
var _marcos: Array[MarcoDelObjetivo] = []
var _sin_copias: Array[Node3D] = []
var _unificadas := false
## En la transición entre noches, sólo se copian estos cuerpos.
var _solo_de: Array[Node3D] = []
## La cámara del jugador recorta las luces que no ve, y el motor las saca de cada objeto ese
## cuadro: la variante cambia sin que nada se mueva. Al final se mira desde adentro de cada
## sonda, hacia los cuatro lados, arriba y abajo, con todo a la vista, y a lo que queda fuera de
## las sondas sin ninguna luz en cuadro.
var _vistas: Array[Transform3D] = []
## Cada material 2D de la escena se dibuja en un píxel, debajo de la pantalla de carga. Si no,
## compilaba la primera vez que aparecía: lo oculto, como el celular o la intro, y lo que va en
## un `SubViewport`, como el agua del baño, que no se actualiza mientras la escena está detenida.
var _capa_2d: CanvasLayer


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Acá y no en `_init()`: al entrar al árbol, el motor prende el `_process` de quien lo define.
func _ready() -> void:
	set_process(false)


func calentar(escena: Node3D) -> void:
	_escena = escena
	_unificadas = unifica_variantes.call()
	# Lo que la escena declara así se dibuja en su lugar, sin copias: sus variantes las prepara
	# otra carga. El protocolo lo declara la escena, como el contorno lo declara cada objeto.
	if escena.has_method("cuerpos_sin_copias"):
		_sin_copias.assign(escena.call("cuerpos_sin_copias"))
	_inicio = ahora.call()
	_dibujar_materiales_2d(escena)
	_tomar_luces_y_sondas(escena)
	for reflejo: ReflectionProbe in _reflejos:
		reflejo.update_mode = ReflectionProbe.UPDATE_ALWAYS
	if not _reflejos.is_empty():
		# La sonda debe tener una captura válida para que el renderer active su variante.
		# Capturar antes de ocultar geometría también evita guardar un salón incompleto.
		for _cuadro: int in 4:
			await get_tree().process_frame
		for reflejo: ReflectionProbe in _reflejos:
			if is_instance_valid(reflejo):
				reflejo.update_mode = ReflectionProbe.UPDATE_ONCE
	var caja := AABB()
	for objeto: GeometryInstance3D in escena.find_children("*", "GeometryInstance3D", true, false):
		# El modelo de referencia queda en el GLB para editarlo, pero tiene un reemplazo en
		# producción. Dibujarlo acá compilaría variantes que nunca aparecen en la partida.
		if objeto.is_in_group(&"geometria_de_referencia"):
			continue
		var suya := _caja_en_mundo(objeto)
		caja = suya if _pendientes.is_empty() else caja.merge(suya)
		if not objeto.visible:
			_ocultos.append(objeto)
		objeto.visible = false
		_pendientes.append(objeto)
		_objetos.append(objeto)
	for reflejo: ReflectionProbe in _reflejos:
		for giro: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
			_vistas.append(
				Transform3D(Basis.from_euler(Vector3(0, giro, 0)), reflejo.global_position)
			)
		for inclinacion: float in [ReglasDelJugador.PITCH_MINIMO, ReglasDelJugador.PITCH_MAXIMO]:
			_vistas.append(
				Transform3D(Basis.from_euler(Vector3(inclinacion, 0, 0)), reflejo.global_position)
			)
	_anterior = get_viewport().get_camera_3d()
	_camara = Camera3D.new()
	add_child(_camara)
	_agregar_vistas_sin_luces()
	_total = _pendientes.size() + _vistas.size()
	_encuadrar(caja)
	_camara.make_current()
	# Los objetos preparan sus materiales por llamada diferida al entrar al árbol.
	# La nuestra entra después: sus contornos deben existir antes del primer dibujo.
	_preparar_contornos.call_deferred()
	set_process(true)


## Entre noches no hay carga: la escena sigue en juego detrás de la persiana. Sólo se agregan las
## copias de `cuerpos`, con su contorno de foco. Nada de la escena se oculta ni se destapa.
func calentar_copias(escena: Node3D, cuerpos: Array[Node3D]) -> void:
	_escena = escena
	_unificadas = unifica_variantes.call()
	_solo_de = cuerpos
	_inicio = ahora.call()
	_tomar_luces_y_sondas(escena)
	for objeto: GeometryInstance3D in escena.find_children("*", "GeometryInstance3D", true, false):
		if objeto.is_in_group(&"geometria_de_referencia"):
			continue
		if not objeto.visible:
			_ocultos.append(objeto)
		_objetos.append(objeto)
	_anterior = get_viewport().get_camera_3d()
	_camara = Camera3D.new()
	add_child(_camara)
	_camara.make_current()
	_preparar_contornos()
	set_process(true)


func _tomar_luces_y_sondas(escena: Node3D) -> void:
	for luz: Light3D in escena.find_children("*", "Light3D", true, false):
		if luz.is_visible_in_tree():
			_luces.append(luz)
	for reflejo: ReflectionProbe in escena.find_children("*", "ReflectionProbe", true, false):
		if reflejo.is_visible_in_tree() and reflejo.intensity > 0.0:
			_reflejos[reflejo] = Vector2i(reflejo.cull_mask, reflejo.update_mode)


func _es_pedido(nodo: Node) -> bool:
	if _solo_de.is_empty():
		return true
	for cuerpo: Node3D in _solo_de:
		if cuerpo == nodo or cuerpo.is_ancestor_of(nodo) or nodo.is_ancestor_of(cuerpo):
			return true
	return false


func _dibujar_materiales_2d(escena: Node3D) -> void:
	var vistos: Dictionary[Shader, bool] = {}
	for nodo: CanvasItem in escena.find_children("*", "CanvasItem", true, false):
		var material := nodo.material as ShaderMaterial
		if material == null or material.shader == null or vistos.has(material.shader):
			continue
		vistos[material.shader] = true
		if _capa_2d == null:
			_capa_2d = CanvasLayer.new()
			_capa_2d.layer = -1
			add_child(_capa_2d)
		var muestra := ColorRect.new()
		muestra.size = Vector2.ONE
		muestra.material = material
		_capa_2d.add_child(muestra)


func objetos_a_preparar() -> int:
	return _total


func objetos_por_preparar() -> int:
	return _pendientes.size() + _por_muestrear.size() + _vistas.size()


func progreso() -> float:
	var faltan := objetos_por_preparar()
	var destapado := 1.0 - float(faltan) / maxi(_total, 1)
	if not _con_cola or (faltan == 0 and _cola <= 0):
		return destapado
	var hechos := _total - faltan
	var transcurrido: float = (ahora.call() - _inicio) / 1000000.0
	if hechos == 0 or transcurrido <= 0.0:
		return 0.0
	var por_programa := SEGUNDOS_POR_PROGRAMA
	if _fin_del_destape >= 0 and _cola < _cola_al_destapar:
		var enlazando: float = (ahora.call() - _fin_del_destape) / 1000000.0
		por_programa = enlazando / (_cola_al_destapar - _cola)
	var resta := faltan * transcurrido / hechos + maxi(_cola, 0) * por_programa
	return transcurrido / (transcurrido + resta)


static func unifica_variantes_en(es_web: bool, build: String) -> bool:
	return es_web or build == BUILD_CON_VARIANTES_UNIFICADAS


static func _cola_de_la_plantilla() -> int:
	if not OS.has_feature("web"):
		return -1
	return int(JavaScriptBridge.eval("window.godot_programas_en_cola ?? -1"))


## Cada cuadro destapa objetos hasta juntar `MATERIALES_NUEVOS_POR_CUADRO` materiales sin dibujar:
## el costo está en el material nuevo, no en la cantidad de objetos. Termina un cuadro después del
## último, que es el cuadro en que se dibuja.
##
## Con cola, el enlace no frena el cuadro pero la compilación sí, y las pasadas no esperan a la
## cola. Entrar con la cola ocupada sí lo frena: lo que todavía compila al usarse espera detrás de
## ella. Por eso el final espera a que se vacíe.
func _process(_delta: float) -> void:
	if not _contornos_listos:
		return
	if _cuadros_de_asentamiento > 0:
		_cuadros_de_asentamiento -= 1
		return
	var cola: int = programas_en_cola.call()
	_cola = cola
	if _pendientes.is_empty():
		if _por_muestrear.is_empty():
			if not _vistas.is_empty():
				_mirar(_vistas.pop_back())
				avanzo.emit(progreso())
				return
			if _fin_del_destape < 0:
				_fin_del_destape = ahora.call()
				_cola_al_destapar = cola
			if cola > 0:
				avanzo.emit(progreso())
				return
			_terminar()
			return
		_pendientes.assign(_por_muestrear)
		_por_muestrear.clear()
		_vistos.clear()
	if cola >= 0:
		_con_cola = true
	var nuevos := 0
	while not _pendientes.is_empty() and nuevos < MATERIALES_NUEVOS_POR_CUADRO:
		var objeto: GeometryInstance3D = _pendientes.pop_back()
		objeto.visible = true
		for material: Variant in _materiales_de(objeto):
			# En una copia, la clase compila sólo el material por defecto de una superficie sin el
			# suyo. Contarla por cada combinación dejaba una sola copia por cuadro.
			if material is String and _firmas.has(objeto) and _superficies_con_material(objeto):
				continue
			# Un mismo material compila otra variante en cada combinación de luces y sondas.
			var clave: Variant = [material, _firmas[objeto]] if _firmas.has(objeto) else material
			# Sin luz no hay combinación: unificadas, sólo la clase de objeto cambia el programa.
			if _firmas.has(objeto) and _unificadas and _sin_luz(material):
				clave = [_huella(material), objeto.get_class()]
			if not _vistos.has(clave):
				nuevos += 1
			_vistos[clave] = true
	# La captura de LightmapGI se asigna después de volver visible la instancia. Pasar a las
	# muestras al cuadro siguiente dejaba sin preparar la variante con esa captura.
	if _pendientes.is_empty():
		_cuadros_de_asentamiento = 2
	avanzo.emit(progreso())


func _preparar_contornos() -> void:
	var indicacion := ShaderMaterial.new()
	indicacion.shader = CONTORNO
	indicacion.set_shader_parameter("grosor", 0.0)
	indicacion.set_shader_parameter("color", Color.WHITE)
	for objeto: GeometryInstance3D in _objetos:
		if not objeto.has_method("mostrar_contorno") or not _es_pedido(objeto):
			continue
		for material: Variant in _materiales_de(objeto):
			if material is Material:
				_guardar_pases(material as Material)
		# El protocolo lo declara el objeto; el sistema no conoce su clase ni su escena.
		objeto.call("mostrar_contorno", indicacion)
	for objetivo: Node in get_tree().get_nodes_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE):
		if objetivo is Node3D and _escena.is_ancestor_of(objetivo) and _es_pedido(objetivo):
			var marco := MarcoDelObjetivo.new()
			add_child(marco)
			marco.enfocar(objetivo as Node3D)
			_marcos.append(marco)
	_agregar_muestras()
	_contornos_listos = true


## La copia ocupa un cubo que encierra al objeto en cualquier orientación, porque en la mano gira:
## una mopa delgada cruza la costura de 3 cm entre dos sondas sólo de costado.
func _agregar_muestras() -> void:
	var fuentes: Dictionary = {}
	var radios: Dictionary[Node3D, float] = {}
	for objeto: GeometryInstance3D in _objetos:
		var cuerpo := _cuerpo_de(objeto)
		if cuerpo == null or _sin_copias.has(cuerpo) or not _es_pedido(cuerpo):
			continue
		radios[cuerpo] = maxf(radios.get(cuerpo, 0.0), _distancia_al_cuerpo(objeto, cuerpo))
		var clave: Array = [objeto.get_class(), _malla_de(objeto)]
		clave.append_array(_materiales_de(objeto).map(_huella))
		if not fuentes.has(clave):
			fuentes[clave] = objeto
	if fuentes.is_empty():
		return
	var volumen := AABB()
	var con_volumen := false
	for objeto: GeometryInstance3D in _objetos:
		if objeto.gi_mode == GeometryInstance3D.GI_MODE_STATIC:
			var suya := _caja_en_mundo(objeto)
			volumen = volumen.merge(suya) if con_volumen else suya
			con_volumen = true
	var suelo := INF
	for objeto: GeometryInstance3D in fuentes.values():
		suelo = minf(suelo, _caja_en_mundo(objeto).position.y)
	var alturas: Dictionary[GeometryInstance3D, Vector2] = {}
	var techo := suelo
	for objeto: GeometryInstance3D in fuentes.values():
		var centro := _caja_en_mundo(objeto).get_center().y
		var alcance := _alcance_de_la_mano(radios[_cuerpo_de(objeto)])
		alturas[objeto] = Vector2(suelo, maxf(centro, suelo + alcance))
		techo = maxf(techo, alturas[objeto].y)
	var puntos := _puntos_a_recorrer(
		fuentes.values(), Vector2(suelo, techo), volumen if con_volumen else AABB()
	)
	var por_radio: Dictionary[Vector3, Array] = {}
	var conocidas: Dictionary[Vector2, Dictionary] = {}
	var caja := _camara_actual()
	for objeto: GeometryInstance3D in fuentes.values():
		var radio := ceilf(_caja_en_mundo(objeto).size.length() / 2.0 / PASO_DEL_RADIO)
		radio = maxf(radio, 1.0) * PASO_DEL_RADIO
		# La capa decide qué luces y qué sondas lo alcanzan.
		var clave := Vector3(radio, objeto.layers, alturas[objeto].y)
		if not por_radio.has(clave):
			# Debajo del techo más bajo, las fuentes del mismo radio y capa comparten las firmas.
			var mismas := Vector2(radio, objeto.layers)
			if not conocidas.has(mismas):
				conocidas[mismas] = {}
			por_radio[clave] = _lugares_distintos(
				puntos,
				radio,
				objeto.layers,
				alturas[objeto],
				volumen,
				con_volumen,
				conocidas[mismas]
			)
		for lugar: Vector4 in por_radio[clave]:
			var muestra := _copiar_muestra(objeto, Vector3(lugar.x, lugar.y, lugar.z), radio)
			if muestra == null:
				break
			_firmas[muestra] = int(lugar.w)
			_por_muestrear.append(muestra)
			_total += 1
			caja = caja.merge(_caja_en_mundo(muestra))
	_encuadrar(caja)


static func _huella(material: Variant) -> Variant:
	if material is ShaderMaterial:
		return (material as ShaderMaterial).shader
	if not material is BaseMaterial3D:
		return material
	var huella: Array = [(material as Object).get_class(), (material as Material).next_pass]
	for propiedad: Dictionary in (material as Object).get_property_list():
		if not int(propiedad["usage"]) & PROPERTY_USAGE_STORAGE:
			continue
		var valor: Variant = (material as Object).get(propiedad["name"])
		if valor is bool or valor is int:
			huella.append(valor)
		elif valor is Texture or (valor == null and propiedad["type"] == TYPE_OBJECT):
			huella.append(valor != null)
	return huella


## Lo más alto que la mano lleva una parte del cuerpo, mirando hacia arriba, medido desde el
## suelo: al soltarlo o al examinarlo, lo que quede más lejos, más el radio del cuerpo, porque la
## parte no está en su origen. Un rígido no sube solo: más arriba, la copia compilaba variantes
## que la partida no dibuja.
static func _alcance_de_la_mano(radio: float) -> float:
	var mirando_arriba := (
		sin(ReglasDelJugador.PITCH_MAXIMO)
		+ ReglasDeLosObjetos.ELEVACION_DEL_EXAMEN * cos(ReglasDelJugador.PITCH_MAXIMO)
	)
	var lejos := maxf(
		ReglasDeLosObjetos.DISTANCIA_DE_SOLTADO * sin(ReglasDelJugador.PITCH_MAXIMO),
		ReglasDeLosObjetos.distancia_de_examen(radio) * mirando_arriba
	)
	return ReglasDelJugador.ALTURA_DE_LA_CAMARA + lejos + radio


## El radio del cuerpo como lo mide `Examen`, pero con las partes que esta pasada ocultó. Lo que
## cuelga con coordenadas propias, como las gotas, no cuenta.
func _distancia_al_cuerpo(parte: GeometryInstance3D, cuerpo: Node3D) -> float:
	var nodo: Node = parte
	while nodo != cuerpo:
		if (nodo as Node3D).top_level:
			return 0.0
		nodo = nodo.get_parent()
	var caja := _caja_en_mundo(parte)
	var distancia := 0.0
	for esquina: int in 8:
		distancia = maxf(distancia, caja.get_endpoint(esquina).distance_to(cuerpo.global_position))
	return distancia


func _camara_actual() -> AABB:
	var caja := AABB()
	for indice: int in _objetos.size():
		var suya := _caja_en_mundo(_objetos[indice])
		caja = suya if indice == 0 else caja.merge(suya)
	return caja


func _se_mueve(objeto: GeometryInstance3D) -> bool:
	return _cuerpo_de(objeto) != null


func _cuerpo_de(objeto: GeometryInstance3D) -> Node3D:
	var nodo := objeto.get_parent()
	while nodo != null and nodo != _escena:
		if nodo is RigidBody3D or nodo is CharacterBody3D:
			return nodo as Node3D
		nodo = nodo.get_parent()
	return null


## Con las variantes unificadas, sólo cuentan las luces con sombra y las de área, y las sondas no.
## El volumen de la GI entra igual: su borde separa variantes aunque ninguna luz llegue ahí.
func _puntos_a_recorrer(fuentes: Array, altura: Vector2, volumen: AABB) -> Array[Vector3]:
	var puntos: Array[Vector3] = []
	var sondas: Array[AABB] = []
	for reflejo: ReflectionProbe in _reflejos:
		if is_instance_valid(reflejo) and not _unificadas:
			sondas.append(_caja_de_la_sonda(reflejo))
	var luces: Array[Light3D] = _luces.filter(
		func(luz: Light3D) -> bool:
			return not _unificadas or luz.shadow_enabled or luz is AreaLight3D
	)
	for indice: int in sondas.size():
		for otra: int in range(indice + 1, sondas.size()):
			var desde := sondas[indice].position.max(sondas[otra].position)
			var hasta := sondas[indice].end.min(sondas[otra].end)
			puntos.append((desde + hasta) / 2.0)
	for indice: int in luces.size():
		var luz := luces[indice]
		puntos.append(luz.global_position)
		for otra: int in range(indice + 1, luces.size()):
			var segunda := luces[otra]
			var alcances := _alcance(luz) + _alcance(segunda)
			if alcances > 0.0:
				puntos.append(
					luz.global_position.lerp(segunda.global_position, _alcance(luz) / alcances)
				)
	var espacio := AABB()
	var con_espacio := false
	for caja: AABB in sondas:
		espacio = espacio.merge(caja) if con_espacio else caja
		con_espacio = true
	for luz: Light3D in luces:
		var alcance := Vector3.ONE * _alcance(luz)
		var suya := AABB(luz.global_position - alcance, alcance * 2.0)
		espacio = espacio.merge(suya) if con_espacio else suya
		con_espacio = true
	if _unificadas and volumen.has_volume():
		espacio = espacio.merge(volumen) if con_espacio else volumen
		con_espacio = true
	if not con_espacio:
		for objeto: GeometryInstance3D in fuentes:
			var suya := _caja_en_mundo(objeto)
			espacio = espacio.merge(suya) if con_espacio else suya
			con_espacio = true
	espacio = espacio.grow(PASO_DEL_RECORRIDO)
	espacio.position.y = altura.x
	espacio.size.y = altura.y - altura.x
	var pasos := Vector3i((espacio.size / PASO_DEL_RECORRIDO).ceil())
	for x: int in pasos.x + 1:
		for y: int in pasos.y + 1:
			for z: int in pasos.z + 1:
				puntos.append(espacio.position + Vector3(x, y, z) * PASO_DEL_RECORRIDO)
	return puntos


func _lugares_distintos(
	puntos: Array[Vector3],
	radio: float,
	capas: int,
	altura: Vector2,
	volumen: AABB,
	con_volumen: bool,
	conocidas: Dictionary
) -> Array[Vector4]:
	var candidatos: Array[Vector3] = puntos.duplicate()
	if not _unificadas:
		candidatos.append_array(_cascaron(radio))
	var lugares: Array[Vector4] = []
	var vistas: Dictionary[int, bool] = {}
	for candidato: Vector3 in candidatos:
		var punto := Vector3(candidato.x, clampf(candidato.y, altura.x, altura.y), candidato.z)
		if not conocidas.has(punto):
			var cubo := AABB(punto - Vector3.ONE * radio, Vector3.ONE * radio * 2.0)
			conocidas[punto] = _firma(cubo, capas, volumen, con_volumen)
		var firma: int = conocidas[punto]
		if not vistas.has(firma):
			vistas[firma] = true
			lugares.append(Vector4(punto.x, punto.y, punto.z, firma))
	return lugares


func _cascaron(radio: float) -> Array[Vector3]:
	var puntos: Array[Vector3] = []
	var distancia := radio + 0.01
	for reflejo: ReflectionProbe in _reflejos:
		if not is_instance_valid(reflejo):
			continue
		var caja := _caja_de_la_sonda(reflejo)
		for eje: int in 3:
			var primero := (eje + 1) % 3
			var segundo := (eje + 2) % 3
			for a: int in ceili(caja.size[primero] / PASO_DEL_RECORRIDO) + 1:
				for b: int in ceili(caja.size[segundo] / PASO_DEL_RECORRIDO) + 1:
					var punto := caja.position
					punto[primero] += minf(a * PASO_DEL_RECORRIDO, caja.size[primero])
					punto[segundo] += minf(b * PASO_DEL_RECORRIDO, caja.size[segundo])
					for cara: float in [caja.position[eje], caja.end[eje]]:
						for desvio: float in [-distancia, distancia]:
							punto[eje] = cara + desvio
							puntos.append(punto)
	return puntos


## Qué cambia la variante: si alcanza alguna luz de cada tipo sin sombra, cuántas con sombra,
## cuántas sondas, y si queda adentro del volumen de la GI. Las luces con sombra van en pasadas
## propias, y las que siguen a la primera usan otra variante: por eso cuentan hasta dos.
func _firma(cubo: AABB, capas: int, volumen: AABB, con_volumen: bool) -> int:
	var cuentas: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	for luz: Light3D in _luces:
		if not is_instance_valid(luz) or not luz.light_cull_mask & capas:
			continue
		var tipo := 0
		if luz is SpotLight3D:
			tipo = 2
		elif luz is AreaLight3D:
			tipo = 4
		elif not luz is OmniLight3D:
			continue
		if luz.shadow_enabled:
			tipo += 1
		elif _unificadas and tipo < 4:
			continue
		if not _alcanza(luz, cubo):
			continue
		cuentas[tipo] = mini(cuentas[tipo] + 1, 2 if luz.shadow_enabled else 1)
	for reflejo: ReflectionProbe in _reflejos:
		if (
			not _unificadas
			and is_instance_valid(reflejo)
			and reflejo.reflection_mask & capas
			and _caja_de_la_sonda(reflejo).intersects(cubo)
		):
			cuentas[6] = mini(cuentas[6] + 1, 2)
	cuentas[7] = int(con_volumen and volumen.has_point(cubo.get_center()))
	var firma := 0
	for cuenta: int in cuentas:
		firma = firma * 3 + cuenta
	return firma


func _alcance(luz: Light3D) -> float:
	if luz is OmniLight3D:
		return (luz as OmniLight3D).omni_range
	if luz is SpotLight3D:
		return (luz as SpotLight3D).spot_range
	if luz is AreaLight3D:
		return (luz as AreaLight3D).area_range
	return 0.0


func _alcanza(luz: Light3D, cubo: AABB) -> bool:
	var origen := luz.global_position
	if origen.clamp(cubo.position, cubo.end).distance_to(origen) >= _alcance(luz):
		return false
	if not luz is SpotLight3D:
		return true
	var hacia := cubo.get_center() - origen
	var mitad := cubo.size.length() / 2.0
	if hacia.length() <= mitad:
		return true
	var abertura := deg_to_rad((luz as SpotLight3D).spot_angle) + asin(mitad / hacia.length())
	return hacia.angle_to(-luz.global_basis.z) < abertura


func _caja_de_la_sonda(reflejo: ReflectionProbe) -> AABB:
	return reflejo.global_transform * AABB(-reflejo.size / 2.0, reflejo.size)


func _malla_de(objeto: GeometryInstance3D) -> Mesh:
	if objeto is MeshInstance3D:
		return (objeto as MeshInstance3D).mesh
	if objeto is MultiMeshInstance3D and (objeto as MultiMeshInstance3D).multimesh != null:
		return (objeto as MultiMeshInstance3D).multimesh.mesh
	return null


## Copia la geometría y los materiales activos, sin el script ni el cuerpo. Un lote sigue siendo
## un lote de una instancia: como malla suelta compila otra variante.
func _copiar_muestra(
	objeto: GeometryInstance3D, punto: Vector3, radio: float
) -> GeometryInstance3D:
	var muestra: GeometryInstance3D
	if objeto is MeshInstance3D:
		var fuente := objeto as MeshInstance3D
		if fuente.mesh == null:
			return null
		var copia := MeshInstance3D.new()
		copia.mesh = fuente.mesh
		for superficie: int in fuente.mesh.get_surface_count():
			copia.set_surface_override_material(
				superficie, fuente.get_surface_override_material(superficie)
			)
		muestra = copia
	elif objeto is MultiMeshInstance3D:
		var fuente := objeto as MultiMeshInstance3D
		if (
			fuente.multimesh == null
			or fuente.multimesh.mesh == null
			or fuente.multimesh.instance_count == 0
		):
			return null
		var copia := MultiMeshInstance3D.new()
		var lote := MultiMesh.new()
		lote.transform_format = fuente.multimesh.transform_format
		lote.use_colors = fuente.multimesh.use_colors
		lote.use_custom_data = fuente.multimesh.use_custom_data
		lote.mesh = fuente.multimesh.mesh
		lote.instance_count = 1
		lote.visible_instance_count = 1
		lote.set_instance_transform(0, Transform3D.IDENTITY)
		if lote.use_colors:
			lote.set_instance_color(0, fuente.multimesh.get_instance_color(0))
		if lote.use_custom_data:
			lote.set_instance_custom_data(0, fuente.multimesh.get_instance_custom_data(0))
		copia.multimesh = lote
		muestra = copia
	else:
		return null
	muestra.gi_mode = objeto.gi_mode
	muestra.cast_shadow = objeto.cast_shadow
	muestra.layers = objeto.layers
	muestra.material_override = objeto.material_override
	muestra.material_overlay = objeto.material_overlay
	var centro := _malla_de(objeto).get_aabb().get_center()
	muestra.custom_aabb = AABB(centro - Vector3.ONE * radio, Vector3.ONE * radio * 2.0)
	add_child(muestra)
	muestra.global_position = punto - centro
	muestra.hide()
	_muestras.append(muestra)
	return muestra


func _guardar_pases(material: Material) -> void:
	if _pases_originales.has(material):
		return
	_pases_originales[material] = material.next_pass
	var pase := material.next_pass
	while pase != null:
		var sombreado := pase as ShaderMaterial
		if sombreado != null and not _parametros_originales.has(sombreado):
			var shader := sombreado.shader
			var parametros: Dictionary = {}
			if shader != null:
				for uniforme: Dictionary in shader.get_shader_uniform_list():
					var nombre := StringName(uniforme["name"])
					parametros[nombre] = sombreado.get_shader_parameter(nombre)
			_parametros_originales[sombreado] = parametros
		pase = pase.next_pass


func _restaurar_pases() -> void:
	for material: Material in _pases_originales:
		material.next_pass = _pases_originales[material]
	for pase: ShaderMaterial in _parametros_originales:
		for nombre: StringName in _parametros_originales[pase]:
			pase.set_shader_parameter(nombre, _parametros_originales[pase][nombre])
	_pases_originales.clear()
	_parametros_originales.clear()


## La clase entra como un material más: un `Label3D` o un `Sprite3D` traen el suyo adentro.
func _materiales_de(objeto: GeometryInstance3D) -> Array:
	var materiales: Array = [objeto.get_class(), objeto.material_override, objeto.material_overlay]
	var malla: Mesh = _malla_de(objeto)
	if malla != null:
		for superficie: int in malla.get_surface_count():
			# Las fibras reemplazan el material por superficie sin cambiar la malla del modelo.
			if objeto is MeshInstance3D:
				materiales.append((objeto as MeshInstance3D).get_active_material(superficie))
			else:
				materiales.append(malla.surface_get_material(superficie))
	return materiales.filter(func(material: Variant) -> bool: return material != null)


static func _sin_luz(material: Variant) -> bool:
	if material is ShaderMaterial:
		return (material as ShaderMaterial).shader == CONTORNO
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	return false


func _superficies_con_material(objeto: GeometryInstance3D) -> bool:
	var malla := _malla_de(objeto)
	if malla == null:
		return false
	if objeto.material_override != null:
		return true
	for superficie: int in malla.get_surface_count():
		var material: Material = (
			(objeto as MeshInstance3D).get_active_material(superficie)
			if objeto is MeshInstance3D
			else malla.surface_get_material(superficie)
		)
		if material == null:
			return false
	return true


func _caja_en_mundo(objeto: GeometryInstance3D) -> AABB:
	var caja := objeto.custom_aabb
	if caja == AABB():
		caja = objeto.get_aabb()
	return objeto.global_transform * caja


func _agregar_vistas_sin_luces() -> void:
	var sondas: Array[AABB] = []
	for reflejo: ReflectionProbe in _reflejos:
		sondas.append(_caja_de_la_sonda(reflejo))
	var vistos: Dictionary = {}
	for objeto: GeometryInstance3D in _objetos:
		if objeto.gi_mode != GeometryInstance3D.GI_MODE_DYNAMIC or _se_mueve(objeto):
			continue
		var caja := _caja_en_mundo(objeto)
		if sondas.any(func(sonda: AABB) -> bool: return sonda.intersects(caja)):
			continue
		var clave: Array = [objeto.get_class(), _malla_de(objeto)]
		clave.append_array(_materiales_de(objeto).map(_huella))
		if vistos.has(clave):
			continue
		vistos[clave] = true
		_vistas.append_array(_vista_sin_luces(caja))


func _vista_sin_luces(caja: AABB) -> Array[Transform3D]:
	_en_perspectiva()
	var lugares: Array[Vector3] = [caja.get_center()]
	for esquina: int in 8:
		lugares.append(caja.get_endpoint(esquina))
	for lugar: Vector3 in lugares:
		var hacia := Vector3.FORWARD
		var cercana := INF
		for luz: Light3D in _luces:
			var distancia := lugar.distance_to(luz.global_position)
			if distancia < cercana and distancia > 0.001:
				cercana = distancia
				hacia = (lugar - luz.global_position) / distancia
		var arriba := Vector3.FORWARD if absf(hacia.y) > 0.99 else Vector3.UP
		var vista := Transform3D(Basis.looking_at(hacia, arriba), lugar)
		_camara.global_transform = vista
		var planos := _planos_de_la_camara()
		if _corta_caja(planos, caja) and not _alguna_luz_en_cuadro(planos):
			return [vista]
	return []


## `get_frustum()` usa la transformación que la cámara guarda cuando le avisan que se movió, y
## el aviso llega después: recién movida, devuelve los planos de antes.
func _planos_de_la_camara() -> Array[Plane]:
	var proyeccion := _camara.get_camera_projection()
	var planos: Array[Plane] = []
	for indice: int in 6:
		planos.append(_camara.global_transform * proyeccion.get_projection_plane(indice))
	return planos


func _alguna_luz_en_cuadro(planos: Array[Plane]) -> bool:
	for luz: Light3D in _luces:
		var adentro := true
		for plano: Plane in planos:
			if plano.distance_to(luz.global_position) >= _alcance(luz):
				adentro = false
				break
		if adentro:
			return true
	return false


static func _corta_caja(planos: Array[Plane], caja: AABB) -> bool:
	for plano: Plane in planos:
		var cercano := Vector3(
			caja.position.x if plano.normal.x > 0.0 else caja.end.x,
			caja.position.y if plano.normal.y > 0.0 else caja.end.y,
			caja.position.z if plano.normal.z > 0.0 else caja.end.z
		)
		if plano.distance_to(cercano) > 0.0:
			return false
	return true


func _en_perspectiva() -> void:
	_camara.projection = Camera3D.PROJECTION_PERSPECTIVE
	if is_instance_valid(_anterior):
		_camara.fov = _anterior.fov
		_camara.near = _anterior.near
		_camara.far = _anterior.far


func _mirar(vista: Transform3D) -> void:
	_en_perspectiva()
	_camara.global_transform = vista
	_camara.force_update_transform()
	_camara.reset_physics_interpolation()


## Desde arriba y ortogonal: así entra la escena entera, sin importar su forma.
func _encuadrar(caja: AABB) -> void:
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Sin geometría, la caja no tiene ancho; la cámara conserva un encuadre válido.
	var ancho := maxf(caja.size.x, caja.size.z)
	if ancho > 0.00001:
		_camara.size = ancho
	_camara.far = caja.size.y + 2.0 * ALTURA_EXTRA
	_camara.position = caja.get_center() + Vector3.UP * (caja.size.y / 2.0 + ALTURA_EXTRA)
	_camara.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	_camara.force_update_transform()
	_camara.reset_physics_interpolation()


func _terminar() -> void:
	set_process(false)
	_restaurar_escena()
	if _solo_de.is_empty() and not _reflejos.is_empty():
		# La primera captura ocurrió con la geometría oculta durante la carga. Se rehace
		# con el local restaurado, todavía detrás de la pantalla, sin muestras temporales.
		for reflejo: ReflectionProbe in _reflejos:
			if is_instance_valid(reflejo):
				reflejo.update_mode = ReflectionProbe.UPDATE_ALWAYS
		await get_tree().process_frame
		await get_tree().process_frame
		_restaurar_reflejos()
		while programas_en_cola.call() > 0:
			await get_tree().process_frame
	_reflejos.clear()
	terminado.emit()


func _exit_tree() -> void:
	if _camara != null or not _reflejos.is_empty():
		_restaurar_escena()


func _restaurar_escena() -> void:
	_escena = null
	_restaurar_reflejos()
	for indice: int in range(_marcos.size() - 1, -1, -1):
		if is_instance_valid(_marcos[indice]):
			_marcos[indice].apagar()
			_marcos[indice].queue_free()
	_marcos.clear()
	_vistas.clear()
	_restaurar_pases()
	for objeto: GeometryInstance3D in _objetos:
		if is_instance_valid(objeto):
			objeto.visible = not _ocultos.has(objeto)
	for muestra: GeometryInstance3D in _muestras:
		muestra.hide()
		muestra.queue_free()
	_muestras.clear()
	_por_muestrear.clear()
	_firmas.clear()
	if is_instance_valid(_capa_2d):
		_capa_2d.queue_free()
	_capa_2d = null
	if is_instance_valid(_camara):
		_camara.queue_free()
	_camara = null
	if is_instance_valid(_anterior) and _anterior.is_inside_tree():
		_anterior.make_current()


func _restaurar_reflejos() -> void:
	for reflejo: ReflectionProbe in _reflejos:
		if is_instance_valid(reflejo):
			reflejo.cull_mask = _reflejos[reflejo].x
			reflejo.update_mode = _reflejos[reflejo].y

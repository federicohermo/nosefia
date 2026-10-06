## Mide el avance del campo de ondas, sin la malla ni el balde, y deja la huella de un
## protocolo fijo. Dos revisiones conservan la simulación si informan las mismas huellas.
extends Node

const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")
const AVANCES_DEL_PROTOCOLO := 600
const DELTAS: Array[float] = [0.0, 1.0 / 144.0, 1.0 / 60.0, 1.0 / 30.0, 0.1, 0.2]
const REINICIO := 150
## Desde acá no hay impulsos ni aceleración: el campo llega solo al reposo.
const CALMA := 300
const IMPULSO_TRAS_LA_CALMA := 590
const PARTES: Array[String] = ["alturas", "velocidades", "amplitud", "muestreo"]
const PASADAS := 5
const AVANCES_POR_PASADA := 1200
const DELTA := 1.0 / 60.0
const ACELERACION := Vector2(4.0, -2.0)


func _ready() -> void:
	_ejecutar.call_deferred()


## Una grilla que pasa la pared del balde: el muestreo de los bordes entra en la huella.
static func puntos_de_muestreo() -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for fila in 9:
		for columna in 9:
			puntos.append(Vector2(columna - 4, fila - 4) * 0.3)
	return puntos


## Sale sólo del índice, sin azar: dos revisiones reciben las mismas entradas.
static func paso_del_protocolo(indice: int) -> Dictionary:
	var paso := {
		"delta": DELTAS[indice % DELTAS.size()],
		"aceleracion": Vector2.ZERO,
		"reinicio": indice == REINICIO,
	}
	if indice < CALMA and indice % 4 != 0:
		paso["aceleracion"] = Vector2(indice * 7 % 13 - 6, indice * 5 % 11 - 5) * 2.0
	if (indice < CALMA and indice % 17 == 0) or indice == IMPULSO_TRAS_LA_CALMA:
		paso["centro"] = Vector2(indice * 3 % 9 - 4, indice * 5 % 7 - 3) / Vector2(4.0, 3.0)
		# Los impulsos fuertes llevan las alturas hasta su tope.
		paso["fuerza"] = 0.07 + indice % 5 * 0.14
	return paso


static func estado_en_bytes(ondas: Ondas) -> Dictionary:
	var alturas: PackedFloat32Array = ondas.get("_alturas")
	var velocidades: PackedFloat32Array = ondas.get("_velocidades")
	return {
		"alturas": alturas.to_byte_array(),
		"velocidades": velocidades.to_byte_array(),
		"amplitud": PackedFloat64Array([ondas.amplitud()]).to_byte_array(),
		"muestreo": ondas.alturas_muestreadas().to_byte_array(),
	}


static func huella(estado: Dictionary) -> String:
	var contexto := HashingContext.new()
	contexto.start(HashingContext.HASH_SHA256)
	for parte in PARTES:
		contexto.update(estado[parte])
	return contexto.finish().hex_encode().left(16)


static func correr_protocolo() -> Dictionary:
	var ondas := Ondas.new()
	ondas.preparar_muestras(puntos_de_muestreo())
	var totales: Array[HashingContext] = []
	for parte in PARTES:
		var contexto := HashingContext.new()
		contexto.start(HashingContext.HASH_SHA256)
		totales.append(contexto)
	var estados := PackedStringArray()
	var amplitud_maxima := 0.0
	var en_reposo := 0
	for indice in AVANCES_DEL_PROTOCOLO:
		var paso := paso_del_protocolo(indice)
		if paso["reinicio"]:
			ondas.reiniciar()
		if paso.has("centro"):
			ondas.perturbar(paso["centro"], paso["fuerza"])
		ondas.avanzar(paso["delta"], paso["aceleracion"])
		var estado := estado_en_bytes(ondas)
		for parte in PARTES.size():
			totales[parte].update(estado[PARTES[parte]])
		estados.append(huella(estado))
		amplitud_maxima = maxf(amplitud_maxima, ondas.amplitud())
		en_reposo += int(not ondas.get("_activa"))
	var informe := {
		"estados": estados,
		"amplitud_maxima": amplitud_maxima,
		"estados_en_reposo": en_reposo,
	}
	for parte in PARTES.size():
		informe[PARTES[parte] + "_sha256"] = totales[parte].finish().hex_encode()
	return informe


static func mediana(valores: Array[float]) -> float:
	var ordenados := valores.duplicate()
	ordenados.sort()
	return ordenados[ordenados.size() / 2]


## La aceleración fija mantiene activo el campo: ningún avance sale por el atajo del reposo.
static func medir_pasadas(pasadas: int, avances: int) -> Dictionary:
	var ondas := Ondas.new()
	ondas.perturbar(Vector2(0.25, -0.15), 0.07)
	var tiempos: Array[float] = []
	# La primera pasada calienta y no se informa.
	for pasada in pasadas + 1:
		var inicio := Time.get_ticks_usec()
		for avance in avances:
			ondas.avanzar(DELTA, ACELERACION)
		if pasada > 0:
			tiempos.append((Time.get_ticks_usec() - inicio) / 1000.0)
	return {
		"avances_por_pasada": avances,
		"delta": DELTA,
		"aceleracion": [ACELERACION.x, ACELERACION.y],
		"pasadas_ms": tiempos,
		"mediana_ms": mediana(tiempos),
		"us_por_avance": mediana(tiempos) * 1000.0 / avances,
		"amplitud_final": ondas.amplitud(),
	}


func _ejecutar() -> void:
	# El arranque del motor todavía ocupa la CPU en los primeros cuadros.
	await get_tree().create_timer(1.0).timeout
	var informe := {
		"compilacion_debug": OS.is_debug_build(),
		"fecha_utc": Time.get_datetime_string_from_system(true),
		"godot": Engine.get_version_info().string,
		"sistema": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"tiempos": medir_pasadas(PASADAS, AVANCES_POR_PASADA),
		"protocolo": correr_protocolo(),
	}
	# En la web no hay `res://reports/` ni git: el informe sale por la consola.
	if OS.has_feature("web"):
		print("[informe] " + JSON.stringify(informe))
		return
	var revision: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], revision)
	informe["commit"] = str(revision[0]).strip_edges() if not revision.is_empty() else "desconocido"
	var ruta := "res://reports/rendimiento-ondas-del-balde.json"
	DirAccess.make_dir_recursive_absolute("res://reports")
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar " + ruta)
		get_tree().quit(1)
		return
	archivo.store_string(JSON.stringify(informe, "\t"))
	get_tree().quit()

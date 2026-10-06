## Mide el avance del campo de ondas, sin la malla ni el balde, y deja la huella de un
## protocolo fijo. Dos revisiones conservan la simulación si informan las mismas huellas.
extends Node

const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")
const AVANCES_DEL_PROTOCOLO := 600
const DELTAS: Array[float] = [0.0, 1.0 / 144.0, 1.0 / 60.0, 1.0 / 30.0, 0.1, 0.2]
const PARTES: Array[String] = ["alturas", "velocidades", "amplitud", "muestreo"]
const PASADAS := 5
const AVANCES_POR_PASADA := 1200
const DELTA := 1.0 / 60.0
const ACELERACION := Vector2(0.4, -0.2)


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
		"aceleracion": Vector2(sin(indice * 0.1), cos(indice * 0.1)) * 0.6,
	}
	if indice % 37 == 0:
		paso["centro"] = Vector2(sin(indice * 0.3), cos(indice * 0.2)) * 0.8
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
	for indice in AVANCES_DEL_PROTOCOLO:
		var paso := paso_del_protocolo(indice)
		if paso.has("centro"):
			ondas.perturbar(paso["centro"], 0.07)
		ondas.avanzar(paso["delta"], paso["aceleracion"])
		var estado := estado_en_bytes(ondas)
		for parte in PARTES.size():
			totales[parte].update(estado[PARTES[parte]])
		estados.append(huella(estado))
		amplitud_maxima = maxf(amplitud_maxima, ondas.amplitud())
	var informe := {"estados": estados, "amplitud_maxima": amplitud_maxima}
	for parte in PARTES.size():
		informe[PARTES[parte] + "_sha256"] = totales[parte].finish().hex_encode()
	ondas.reiniciar()
	informe["tras_reiniciar"] = huella(estado_en_bytes(ondas))
	return informe


static func mediana(valores: Array[float]) -> float:
	var ordenados := valores.duplicate()
	ordenados.sort()
	return ordenados[ordenados.size() / 2]


## La aceleración fija mantiene activo el campo: ningún avance sale por el atajo del reposo.
static func medir_pasadas(pasadas: int, avances: int) -> Dictionary:
	var tiempos: Array[float] = []
	var amplitud_final := 0.0
	# La primera pasada calienta y no se informa.
	for pasada in pasadas + 1:
		var ondas := Ondas.new()
		ondas.perturbar(Vector2(0.2, -0.3), 0.07)
		var inicio := Time.get_ticks_usec()
		for avance in avances:
			ondas.avanzar(DELTA, ACELERACION)
		if pasada > 0:
			tiempos.append((Time.get_ticks_usec() - inicio) / 1000.0)
		amplitud_final = ondas.amplitud()
	return {
		"avances_por_pasada": avances,
		"delta": DELTA,
		"aceleracion": [ACELERACION.x, ACELERACION.y],
		"pasadas_ms": tiempos,
		"mediana_ms": mediana(tiempos),
		"us_por_avance": mediana(tiempos) * 1000.0 / avances,
		"amplitud_final": amplitud_final,
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

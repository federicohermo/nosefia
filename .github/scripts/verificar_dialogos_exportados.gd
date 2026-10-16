## Se ejecuta desde fuera del proyecto, con --main-pack apuntando al PCK exportado.
## Leer el .tres del checkout no detecta una conversión binaria que pierde sus entradas.
extends SceneTree


func _initialize() -> void:
	var textos: Resource = load("res://assets/dialogos/compradores_jornada_1.tres")
	var bloques := {
		&"tin": ["Hola...", "me olvidé", "Es un chiste"],
		&"tia": ["Hola! Quiero una caja de cereal"],
		&"despedida_tin": ["sos lo más"],
		&"despedida_tia":
		["tenía mucha hambre", "empleado anterior", "Enrique Peldaño", "11 ****-****"],
	}
	if textos == null:
		push_error("El paquete no contiene los diálogos de la primera jornada.")
		quit(1)
		return
	for nombre: StringName in bloques:
		var entradas: PackedStringArray = textos.get(nombre)
		var esperadas: Array = bloques[nombre]
		if entradas.size() != esperadas.size():
			push_error(
				(
					"%s: se esperaban %d entradas y hay %d."
					% [nombre, esperadas.size(), entradas.size()]
				)
			)
			quit(1)
			return
		for indice: int in esperadas.size():
			if not entradas[indice].contains(esperadas[indice]):
				push_error("%s: falta el contenido de la entrada %d." % [nombre, indice])
				quit(1)
				return
	var pedidos: Array[String] = [
		"Quiero una caja de fideos Marolini, una lata de Coracola y un paquete de cigarrillos Malbardo.",
		"Quiero una caja de cereal Zucarachas y una caja de galletitas Pepito."
	]
	var nombres: Array[Array] = [["Marolini", "Coracola", "Malbardo"], ["Zucarachas", "Pepito"]]
	for indice in 2:
		var personaje: int = indice + 1
		for rechazo: bool in [false, true]:
			var dialogo: RefCounted = textos.call("recordatorio", personaje, rechazo)
			var entrada: String = dialogo.call("entrada_actual")
			var esperado := ("Yo no pedí esto. " if rechazo else "") + pedidos[indice]
			if _visible(entrada) != esperado or not _destacados(entrada, nombres[indice]):
				push_error("El recordatorio o rechazo exportado no conserva texto y destacados.")
				quit(1)
				return
	var tia: PackedStringArray = textos.get("tia")
	if (
		(
			_visible(tia[0])
			!= "Hola! Quiero una caja de cereal Zucarachas y una caja de galletitas Pepito, por favor."
		)
		or not _destacados(tia[0], nombres[1])
	):
		push_error("La entrada inicial exportada de Tia no conserva texto y destacados.")
		quit(1)
		return
	print(
		"Diálogos exportados: las nueve entradas de Tin y Tia y sus recordatorios están presentes."
	)
	quit()


func _visible(texto: String) -> String:
	var etiquetas := RegEx.new()
	etiquetas.compile("\\[[^\\]]*\\]")
	return etiquetas.sub(texto, "", true)


func _destacados(texto: String, nombres: Array) -> bool:
	for nombre: String in nombres:
		var destacado := RegEx.new()
		destacado.compile("\\[b\\]\\[color=#[a-fA-F0-9]+\\]" + nombre + "\\[/color\\]\\[/b\\]")
		if destacado.search(texto) == null:
			return false
	return true

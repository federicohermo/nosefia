## Se ejecuta desde fuera del proyecto, con --main-pack apuntando al PCK exportado.
## Leer el .tres del checkout no detecta una conversión binaria que pierde sus entradas.
extends SceneTree


func _initialize() -> void:
	var textos: Resource = load("res://assets/dialogos/compradores_jornada_1.tres")
	var bloques := {
		&"martin": ["Hola...", "me olvidé", "Es un chiste"],
		&"tiago": ["Hola! Quiero dos paquetes"],
		&"despedida_martin": ["sos lo más"],
		&"despedida_tiago":
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
	print("Diálogos exportados: las nueve entradas de Martín y Tiago están presentes.")
	quit()

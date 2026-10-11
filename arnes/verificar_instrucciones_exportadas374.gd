## Corre contra el PCK final, con --path explícito y sin leer el recurso del checkout.
extends SceneTree


func _initialize() -> void:
	var guion: Resource = load("res://src/dominio/investigacion/conversacion_con_el_jefe.tres")
	if guion == null or guion.get("nombre") != "Enrique Peldaño":
		_fallar("Falta el guion exportado de Enrique Peldaño")
		return
	var imagen: Texture2D = guion.get("imagen")
	if imagen == null or imagen.get_width() <= 0 or imagen.get_height() <= 0:
		_fallar("Falta la imagen original de Enrique")
		return
	var mensajes: Array = guion.get("mensajes")
	if mensajes.size() != 21:
		_fallar("Se esperaban21 entradas; hay%d" % mensajes.size())
		return
	var fotos := 0
	var textos := 0
	for indice: int in mensajes.size():
		var mensaje: Resource = mensajes[indice]
		var foto: Texture2D = mensaje.get("foto")
		if foto != null:
			fotos += 1
			if foto.get_width() != 960 or foto.get_height() != 540:
				_fallar("Foto exportada con dimensiones incorrectas: %s" % foto.resource_path)
				return
			if indice == mensajes.size() - 1 or mensajes[indice + 1].get("foto") != null:
				_fallar("Cada foto debe anteceder su texto adjunto")
				return
		elif not str(mensaje.get("texto")).is_empty():
			textos += 1
	if fotos != 7 or textos != 14:
		_fallar("Se esperaban7 fotos y14 textos; hay%d y%d" % [fotos, textos])
		return
	print("Instrucciones exportadas: 21 entradas, 14 textos y 7 fotos originales presentes.")
	quit()


func _fallar(motivo: String) -> void:
	push_error(motivo)
	quit(1)

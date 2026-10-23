extends "res://test/escenas/captura_de_compradores_jornada_2.gd"


class GuionDeCaptura:
	extends DialogosDeCompradores

	func inicial(personaje: int) -> Dialogo:
		if personaje == Personaje.CAMI:
			return _crear_dialogo(PackedStringArray(["Atención de prueba: Cami."]))
		return super.inicial(personaje)


func _compradores(jornada: int) -> Array[Comprador]:
	var compradores := super._compradores(jornada)
	var guion := GuionDeCaptura.new()
	guion.fede = PackedStringArray(["Atención de prueba: Fede."])
	var resultado: Array[Comprador] = []
	for comprador: Comprador in compradores:
		var cami := comprador.personaje == DialogosDeCompradores.Personaje.FEDE
		var figura := Comprador.new(
			"Cami" if cami else "Fede", comprador.pedido(), comprador.paga()
		)
		figura.horario = comprador.horario
		figura.personaje = (
			DialogosDeCompradores.Personaje.CAMI if cami else DialogosDeCompradores.Personaje.FEDE
		)
		figura.dialogos = guion
		resultado.append(figura)
	return resultado

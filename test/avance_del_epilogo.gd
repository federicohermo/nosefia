## Recorre el epílogo que el almacén puso en pantalla: lee cada placa y pulsa «SIGUIENTE» hasta que
## la pantalla se libera. El tiempo corre de a un fundido por vez.
extends RefCounted

const CUADROS_MAXIMOS := 64


## El epílogo en pantalla, o `null` si no hay ninguno.
static func de(almacen: Node) -> PantallaDeEpilogo:
	for hijo: Node in almacen.get_children():
		if hijo is PantallaDeEpilogo and not hijo.is_queued_for_deletion():
			return hijo
	return null


## Cuántos epílogos hay a la vez en el almacén.
static func cuantos(almacen: Node) -> int:
	return almacen.find_children("*", "PantallaDeEpilogo", true, false).size()


## Las placas que se vieron, en orden. Termina con la pantalla liberada.
static func recorrer(almacen: Node) -> Array[EpilogosDeLosFinales.Placa]:
	var vistas: Array[EpilogosDeLosFinales.Placa] = []
	var epilogo := de(almacen)
	var paso := RecorridoDelEpilogo.SEGUNDOS_DEL_FUNDIDO
	for _cuadro in CUADROS_MAXIMOS:
		if epilogo == null or epilogo.is_queued_for_deletion():
			return vistas
		epilogo.avanzar(paso)
		var placa := epilogo.placa_a_la_vista()
		if placa != null and epilogo.negro() == 0.0:
			vistas.append(placa)
			epilogo.boton().pressed.emit()
	return vistas

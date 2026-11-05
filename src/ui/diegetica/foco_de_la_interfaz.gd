## Deja el foco en un control de la interfaz que se abre, para que la cruceta y el joystick derecho
## tengan por dónde empezar. Sin esto, el primer gesto de un jugador con joystick no elige nada.
class_name FocoDeLaInterfaz
extends RefCounted


## El primer control habilitado de `raiz` que acepta el foco, en el orden del árbol. Si el foco ya
## está adentro de `raiz` y lo acepta lo respeta: repintar una interfaz no se lo quita al jugador.
## Un botón que se deshabilita conserva el foco del motor, y la cruceta no lo puede soltar.
## Contesta el control con el foco, o `null` si `raiz` no tiene ninguno.
static func en_el_primero(raiz: Node) -> Control:
	var actual := raiz.get_viewport().gui_get_focus_owner() if raiz.is_inside_tree() else null
	if actual != null and raiz.is_ancestor_of(actual) and _acepta_el_foco(actual):
		return actual
	for hijo: Node in raiz.find_children("*", "Control", true, false):
		var control := hijo as Control
		if _acepta_el_foco(control):
			control.grab_focus()
			return control
	return null


static func _acepta_el_foco(control: Control) -> bool:
	if control.focus_mode != Control.FOCUS_ALL or not control.is_visible_in_tree():
		return false
	# Un campo de texto no se maneja con la cruceta: el foco ahí no le sirve al joystick.
	if control is LineEdit or control is TextEdit:
		return false
	var boton := control as BaseButton
	return boton == null or not boton.disabled

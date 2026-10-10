## La imagen continúa después del despacho; no conserva atención, objetos ni ventas.
extends AnimatedSprite3D

@export var velocidad: float = 1.0

var _recorrido: float = 0.0
var _limite: float = 0.0


func preparar(limite: float) -> void:
	_limite = limite


func _process(delta: float) -> void:
	var avance := velocidad * delta
	position += basis.x * avance
	_recorrido += avance
	if _recorrido >= _limite:
		_retirar()


func _retirar() -> void:
	hide()
	stop()
	queue_free()

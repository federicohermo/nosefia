extends SceneTree

var listos: Semaphore = Semaphore.new()
var inicio: Semaphore = Semaphore.new()
var clases: Array[StringName] = []


func _initialize() -> void:
	for candidata: StringName in ClassDB.get_inheriters_from_class("Resource"):
		if not ClassDB.can_instantiate(candidata):
			clases.append(candidata)
	print("[CLASSDB-PROBE] threads=16 classes=", clases.size())
	var hilos: Array[Thread] = []
	for indice: int in 16:
		var hilo: Thread = Thread.new()
		hilos.append(hilo)
		hilo.start(_consultar.bind(indice))
	for indice: int in 16:
		listos.wait()
	for indice: int in 16:
		inicio.post()
	var consultas: int = 0
	for hilo: Thread in hilos:
		consultas += int(hilo.wait_to_finish())
	print("[CLASSDB-PROBE] complete calls=", consultas)
	quit(0)


func _consultar(desplazamiento: int) -> int:
	listos.post()
	inicio.wait()
	for indice: int in clases.size():
		var nombre: StringName = clases[(indice + desplazamiento) % clases.size()]
		ClassDB.class_get_property_default_value(nombre, "resource_name")
	return clases.size()

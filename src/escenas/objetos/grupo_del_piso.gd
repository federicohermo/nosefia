## Conserva cuerpos físicos y agrupa únicamente su dibujo.
extends MultiMeshInstance3D

var cuerpos: Array[RigidBody3D] = []
var _vistas: Array[MeshInstance3D] = []
var _matrices: Array[Transform3D] = []
var _reposos: Array[bool] = []
var _inversa := Transform3D.IDENTITY


func preparar(malla: Mesh, capacidad: int) -> void:
	# El grupo escribe en el reloj del dibujo, así que el motor no tiene que volver a interpolar.
	# Si lo hace, interpola entre dos valores ya interpolados y la copia se atrasa de nuevo.
	# Medido en el juego con la interpolación heredada: 59,92 mm en caída libre, contra 0,00 mm
	# de lo que el script escribió. La caché del script no lo ve, sólo el buffer del motor.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = malla
	multimesh.instance_count = capacidad
	multimesh.visible_instance_count = 0


func agregar(cuerpo: RigidBody3D) -> void:
	var vista: MeshInstance3D = cuerpo.get_node("Malla")
	cuerpos.append(cuerpo)
	_vistas.append(vista)
	_matrices.append(Transform3D.IDENTITY)
	_reposos.append(false)
	vista.hide()
	multimesh.visible_instance_count = cuerpos.size()
	_actualizar(cuerpos.size() - 1, true)


func quitar(cuerpo: RigidBody3D) -> void:
	var indice := cuerpos.find(cuerpo)
	if indice < 0:
		return
	_vistas[indice].show()
	var ultimo := cuerpos.size() - 1
	cuerpos[indice] = cuerpos[ultimo]
	_vistas[indice] = _vistas[ultimo]
	_matrices[indice] = _matrices[ultimo]
	_reposos[indice] = _reposos[ultimo]
	cuerpos.resize(ultimo)
	_vistas.resize(ultimo)
	_matrices.resize(ultimo)
	_reposos.resize(ultimo)
	multimesh.visible_instance_count = ultimo
	if indice < ultimo:
		_actualizar(indice, true)


## Se actualiza en el reloj del dibujo y no en el de la física. Desde `_physics_process` se leía
## el `transform` de antes de integrar el paso, así que la copia iba un paso atrás del cuerpo.
## Medido antes del cambio: 69,32 mm en el cuadro del impacto, el 43 % del alto del objeto.
func _process(_delta: float) -> void:
	var inversa := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	var movido := not inversa.is_equal_approx(_inversa)
	_inversa = inversa
	for indice in cuerpos.size():
		_actualizar(indice, movido)


func _actualizar(indice: int, forzar: bool = false) -> void:
	var cuerpo := cuerpos[indice]
	var vista := _vistas[indice]
	# El contorno existente necesita la malla individual mientras está enfocado.
	var enfocado := vista.material_overlay != null
	var dormido := cuerpo.sleeping
	if not forzar and dormido and _reposos[indice] and vista.visible == enfocado:
		return
	_reposos[indice] = dormido
	vista.visible = enfocado
	var matriz := cuerpo.transform * vista.transform
	if is_inside_tree() and cuerpo.is_inside_tree():
		if forzar:
			_inversa = global_transform.affine_inverse()
		# Dónde dibuja el motor la malla, no dónde la puso el último paso de física. Las dos
		# difieren hasta 63,65 mm en caída libre con la interpolación encendida. El motor no
		# vuelve a interpolar lo que se escribe acá: en un `MultiMesh` la interpolación es
		# opt-in y se activa con `set_buffer_interpolated()`.
		matriz = _inversa * vista.get_global_transform_interpolated()
	if enfocado:
		matriz = matriz.scaled_local(Vector3.ZERO)
	if forzar or not matriz.is_equal_approx(_matrices[indice]):
		multimesh.set_instance_transform(indice, matriz)
		_matrices[indice] = matriz

## Conserva cuerpos físicos y agrupa únicamente su dibujo.
extends MultiMeshInstance3D

var cuerpos: Array[RigidBody3D] = []
var _vistas: Array[MeshInstance3D] = []
var _matrices: Array[Transform3D] = []
var _reposos: Array[bool] = []
var _inversa := Transform3D.IDENTITY


func preparar(malla: Mesh, capacidad: int) -> void:
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


func _physics_process(_delta: float) -> void:
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
		matriz = _inversa * vista.global_transform
	if enfocado:
		matriz = matriz.scaled_local(Vector3.ZERO)
	if forzar or not matriz.is_equal_approx(_matrices[indice]):
		multimesh.set_instance_transform(indice, matriz)
		_matrices[indice] = matriz

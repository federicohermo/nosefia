## Pregunta si los triángulos de una malla tapan lo que ve una cámara.
##
## Una malla sin colisión no frena un rayo de física, así que el rayo no prueba que la vista
## esté tapada. Sus triángulos sí.
extends RefCounted


## El borde pertenece a la propia malla; se pregunta por el recorrido anterior a tocarlo.
static func tapa(camara: Camera3D, punto: Vector3, malla: MeshInstance3D) -> bool:
	var inversa := malla.global_transform.affine_inverse()
	var desde := inversa * camara.global_position
	var hasta := inversa * punto.move_toward(camara.global_position, 0.002)
	if malla.get_aabb().intersects_segment(desde, hasta) == null:
		return false
	var caras := malla.mesh.get_faces()
	for indice in range(0, caras.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				desde, hasta, caras[indice], caras[indice + 1], caras[indice + 2]
			)
			!= null
		):
			return true
	return false

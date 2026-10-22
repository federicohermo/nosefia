class_name PoseDeLaVista
extends RefCounted

## Cuánto más lejos que el justo queda la cámara, para que el marco y la calle entren.
const MARGEN_DEL_ENCUADRE := 1.15

## Dónde están los ojos y hacia dónde mira: `x` es el yaw, `y` la inclinación.
var posicion: Vector3
var orientacion: Vector2


func _init(lugar: Vector3 = Vector3.ZERO, giro: Vector2 = Vector2.ZERO) -> void:
	posicion = lugar
	orientacion = giro


## De frente al vano: sobre la perpendicular que pasa por el punto medio de las dos bisagras, del
## lado de `desde`, mirando horizontal hacia él. Los ojos conservan su altura, y la distancia es
## la menor desde la que entran el ancho y el alto del vano con ese campo de visión.
static func frontal_al_vano(
	bisagra_a: Vector3,
	bisagra_b: Vector3,
	desde: Vector3,
	alto: float,
	fov_vertical: float,
	aspecto: float
) -> PoseDeLaVista:
	var centro := (bisagra_a + bisagra_b) * 0.5
	var eje := Vector3(bisagra_b.x - bisagra_a.x, 0.0, bisagra_b.z - bisagra_a.z)
	var normal := eje.normalized().cross(Vector3.UP)
	if (desde - centro).dot(normal) < 0.0:
		normal = -normal
	var mitad_vertical := tan(fov_vertical * 0.5)
	var por_el_ancho := eje.length() * 0.5 / (mitad_vertical * aspecto)
	var piso := absf(desde.y - (centro.y - alto * 0.5))
	var techo := absf(centro.y + alto * 0.5 - desde.y)
	var por_el_alto := maxf(piso, techo) / mitad_vertical
	var distancia := maxf(por_el_ancho, por_el_alto) * MARGEN_DEL_ENCUADRE
	var lugar := Vector3(centro.x, desde.y, centro.z) + normal * distancia
	return PoseDeLaVista.new(lugar, Vector2(atan2(normal.x, normal.z), 0.0))


## El yaw toma el camino corto: de 179 a -179 grados son 2, no 358.
func mezclada_con(otra: PoseDeLaVista, proporcion: float) -> PoseDeLaVista:
	var giro := wrapf(otra.orientacion.x - orientacion.x, -PI, PI)
	return PoseDeLaVista.new(
		posicion.lerp(otra.posicion, proporcion),
		Vector2(
			orientacion.x + giro * proporcion, lerpf(orientacion.y, otra.orientacion.y, proporcion)
		)
	)

## Rellena las sondas negras de un horneado con la luz de sus vecinas.
##
## **El horneador reparte las sondas por los bordes de las mallas**, y buena parte cae adentro de
## una pared, del techo o de un mueble. Ahí no llega ningún rayo y la sonda sale negra. Un objeto
## que toma la luz de las sondas —los productos, las cajas— la interpola entre las cuatro más
## cercanas: con una o dos negras en el tétrade, el objeto se apaga aunque el estante alrededor
## esté iluminado. Medido el 2026-09-21: 392 de las 608 sondas de adentro del local eran negras.
##
## El relleno no toca la malla de tétrades ni las sondas con luz: sólo reescribe los nueve
## coeficientes de cada sonda negra con el promedio, pesado por cercanía, de las vecinas con luz.
## Una sonda negra sin ninguna vecina con luz —afuera del local— queda como está.
extends RefCounted

## Una sonda con menos luz que esto está adentro de algo: al aire libre ninguna baja de 0,06.
const NEGRA := 0.04
const VECINAS := 6
const ALCANCE := 2.5
const COEFICIENTES := 9


static func rellenar(datos: LightmapGIData) -> Dictionary:
	var sondas: Dictionary = datos.get("probe_data")
	var puntos: PackedVector3Array = sondas["points"]
	var resultado := rellenar_coeficientes(puntos, sondas["sh"])
	sondas["sh"] = resultado["sh"]
	datos.set("probe_data", sondas)
	return {"total": puntos.size(), "rellenadas": resultado["rellenadas"]}


## Se repite hasta que ninguna sonda negra tenga una vecina con luz: una rellenada en una pasada
## es vecina con luz en la siguiente. Así, aplicarlo sobre un horneado ya rellenado no cambia
## nada, y el test puede cobrarlo.
static func rellenar_coeficientes(puntos: PackedVector3Array, sh: PackedColorArray) -> Dictionary:
	var nuevo := sh.duplicate()
	var rellenadas := 0
	while true:
		var pasada := _una_pasada(puntos, nuevo)
		if pasada == 0:
			break
		rellenadas += pasada
	return {"sh": nuevo, "rellenadas": rellenadas}


static func _una_pasada(puntos: PackedVector3Array, sh: PackedColorArray) -> int:
	var con_luz: Array[int] = []
	var negras: Array[int] = []
	for i in puntos.size():
		if luz(sh, i) < NEGRA:
			negras.append(i)
		else:
			con_luz.append(i)
	var rellenadas := 0
	for i in negras:
		var vecinas := _vecinas(puntos, con_luz, puntos[i])
		if vecinas.is_empty():
			continue
		rellenadas += 1
		var peso_total := 0.0
		var suma: Array[Color] = []
		suma.resize(COEFICIENTES)
		suma.fill(Color(0, 0, 0, 0))
		for vecina in vecinas:
			var peso: float = 1.0 / maxf(vecina[0], 0.1)
			peso_total += peso
			for k in COEFICIENTES:
				suma[k] += sh[vecina[1] * COEFICIENTES + k] * peso
		for k in COEFICIENTES:
			sh[i * COEFICIENTES + k] = suma[k] / peso_total
	return rellenadas


## La luz de una sonda es el primer coeficiente: el promedio de lo que le llega de todos lados.
static func luz(sh: PackedColorArray, i: int) -> float:
	var c := sh[i * COEFICIENTES]
	return (c.r + c.g + c.b) / 3.0


static func _vecinas(puntos: PackedVector3Array, con_luz: Array[int], desde: Vector3) -> Array:
	var cerca := []
	for j in con_luz:
		var distancia := puntos[j].distance_to(desde)
		if distancia <= ALCANCE:
			cerca.append([distancia, j])
	cerca.sort()
	return cerca.slice(0, VECINAS)

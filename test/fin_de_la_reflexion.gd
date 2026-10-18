## Termina la reflexión de cierre de la partida sin la pantalla: lee cada texto y elige la primera
## hipótesis mostrada. Para los casos que pasan de una noche a la siguiente sin mirarla.
extends RefCounted


static func terminar(partida: Partida) -> void:
	var reflexion := partida.reflexion
	if reflexion == null:
		return
	reflexion.empezar()
	while reflexion.etapa() == ReflexionDeCierre.Etapa.TEXTOS:
		reflexion.continuar(reflexion.identidad_del_texto())
	if reflexion.etapa() == ReflexionDeCierre.Etapa.ELEGIR:
		reflexion.elegir(reflexion.mostrada().identidad)
	reflexion.avanzar(ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE)

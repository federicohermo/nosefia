## Una mancha que se ve en el piso: dice de qué zona es y se aclara.
##
## **No decide ni lleva contador.** Cuántas pasadas quedan lo sabe `Mancha`, y está medido que un
## contador escrito acá da cero hallazgos en los dos gates: ni el de capas ni el de tests miran
## `src/escenas/`. Acá viven la zona que declara el `.tscn` y la opacidad.
##
## Va en `objetos/` y no en `puestos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: de esto hay una por zona y se ven y desaparecen en juego.
extends StaticBody3D

## De qué zona del piso es esta mancha. Es un valor del `enum` del dominio y no un `String`: el
## conjunto es cerrado, y un nombre mal escrito no rompería nada — la mancha simplemente no se
## limpiaría nunca.
@export var zona: PisoDelLocal.Zona = PisoDelLocal.Zona.ENTRADA

@export var _mancha: MeshInstance3D


## De qué zona es. Lo pregunta el puesto de limpieza para saber qué mancha tiene delante, y es un
## método y no una lectura del campo para que el contrato sea el mismo que el de `interactuar()`.
func zona_de_la_mancha() -> PisoDelLocal.Zona:
	return zona


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`.
##
## Devuelve `null` porque una mancha no se levanta: pasarle el trapeador entra por el clic
## derecho, que es otro gesto.
func interactuar() -> ObjetoDelAlmacen:
	return null


## Se aclara según lo que falte, y desaparece al llegar a cero.
##
## Recibe los dos números en vez de ir a buscarlos: esta mancha no es dueña de ninguno, y la
## cuenta vive en `PisoDelLocal`. Es lo que la deja dibujarse sin conocer al piso.
func mostrar(restantes: int, totales: int) -> void:
	visible = restantes > 0
	_mancha.transparency = 1.0 - float(restantes) / float(maxi(totales, 1))

## Una mancha que se ve: dice en qué lugar está y se pinta del color que le toca.
##
## **No decide nada.** Qué tipo de mancha hay en su lugar, qué jabón la borra y si ya se borró lo
## sabe `PisoDelLocal`, y está medido que una regla escrita acá da cero hallazgos en los dos gates:
## ni el de capas ni el de tests miran `src/escenas/`. Acá viven el lugar que declara el `.tscn`, el
## color y si se ve.
##
## Se llama «en el piso» aunque la del depósito esté en una pared: el disco va vertical girando el
## nodo, y la escena es la misma.
##
## Va en `objetos/` y no en `puestos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: de esto hay una por lugar, y se ven y desaparecen en juego.
extends StaticBody3D

## Cuánto deja ver del piso que tiene abajo: es un charco, no una pintura.
const OPACIDAD := 0.85

## En qué lugar está esta mancha. Es un valor del `enum` del dominio y no un `String`: el conjunto
## es cerrado, y un nombre mal escrito no rompería nada — la mancha simplemente no se borraría
## nunca.
@export var lugar: PisoDelLocal.Lugar = PisoDelLocal.Lugar.ENTRADA

@export var _mancha: MeshInstance3D

## La forma con la que la mira la enfoca.
##
## Se apaga junto con la malla porque esconder un nodo **no apaga su cuerpo**: sin esto, una
## mancha ya borrada sigue frenando el rayo de la mira y se sigue enfocando, con la escena
## cargando sin un solo error.
@export var _cuerpo: CollisionShape3D


## En qué lugar está. Lo pregunta el puesto de limpieza para saber qué mancha tiene delante, y es
## un método y no una lectura del campo para que el contrato sea el mismo que el de los demás
## puestos.
func lugar_de_la_mancha() -> PisoDelLocal.Lugar:
	return lugar


## **No tiene `interactuar()`, y es a propósito.** Una mancha no se levanta: la mopa entra por el
## clic derecho, que es otro gesto. Tener el método es declarar que el clic izquierdo es propio, y
## el de `jugador.gd` se lo daba entero: llevando una caja y con la mira sobre un charco, soltar no
## hacía nada. Al grupo `interactuable` sigue perteneciendo, que es lo que la enfoca y lo que la
## deja recibir el otro botón.


## Se muestra sucia y del color que se le pasa, o desaparece entera: malla y cuerpo.
##
## Recibe los dos datos en vez de ir a buscarlos: esta mancha no es dueña de ninguno. Es lo que la
## deja dibujarse sin conocer al piso.
func mostrar(sucia: bool, color: Color) -> void:
	visible = sucia
	_cuerpo.disabled = not sucia
	var pintura := _mancha.get_surface_override_material(0) as StandardMaterial3D
	pintura.albedo_color = Color(color, OPACIDAD)


## El color con que se ve ahora. Lo leen los casos que miden la escena.
func color() -> Color:
	var pintura := _mancha.get_surface_override_material(0) as StandardMaterial3D
	return pintura.albedo_color

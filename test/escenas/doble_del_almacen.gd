## El almacén de los tests del menú: sólo lee la partida del guardado, como el de verdad.
extends Node3D

var partida := Partida.desde(Guardado.new().cargar())

---
paths:
  - "src/dominio/**/*.gd"
  - "test/dominio/**/*.gd"
---

# Capa de dominio

Las reglas del juego, sin el motor. El turno, las cinco tareas, el inventario, la ventanilla
como regla —no como pantalla—, los canales de investigación y el sistema de consecuencias.

## Puro quiere decir esto, y es literal

**Nada de acá extiende `Node`.** Se extiende `RefCounted` o `Resource`, y nada más.

Prohibido, y no como estilo sino porque rompe la propiedad que hace útil a esta capa:

| No va | Por qué |
|---|---|
| `extends Node` y cualquier descendiente | pide un árbol de escena para existir |
| `get_tree()`, `get_node()`, `$Algo` | lo mismo, por la puerta de atrás |
| `_process`, `_physics_process`, `_input` | el tiempo y la entrada los administra `sistemas/` |
| `await get_tree().create_timer(…)` | el reloj lo pasa `sistemas/`, como un parámetro |
| `preload` de cualquier otra capa | lo bloquea `gate_de_capas.py` |
| `print`, nodos de UI, `Input` | esta capa no tiene con quién hablar |

**La prueba es una sola: un test de `dominio/` tiene que poder correr sin levantar una
escena.** Si para probar algo hace falta un frame, ese algo no va acá.

## Por qué esta capa existe

Porque es la única que se puede ejercer barato, y por eso es la única donde el TDD es
posible de verdad. Las consecuencias del turno —cuántas tareas se cumplieron, cuántos
apercibimientos suma la jornada, si al jugador lo echan— son **aritmética sobre estado**, y
escribir eso adentro de un `Node` que además pinta la pantalla lo vuelve inejercitable: la
única forma de probarlo pasa a ser jugar el turno entero a mano.

De ahí que `gate_de_tests.py` exija test para todo `.gd` de acá. No es rigor por rigor: es que
en esta capa el test es barato, y donde el test es barato no hay excusa.

## El tiempo entra como parámetro

El turno tiene un tiempo limitado que se reparte entre las tareas y la investigación. Ese
tiempo **no lo lee el dominio del reloj del motor**: se lo pasan.

```gdscript
# Bien: el turno recibe cuántos segundos se consumieron y decide.
func consumir(segundos: float) -> void:

# Mal: el dominio va a buscar el tiempo, y ahora el test necesita un frame.
func consumir() -> void:
    var dt := get_process_delta_time()
```

Es lo que permite escribir el test de «tres jornadas graves seguidas y lo echan» sin jugar tres
noches.

## Conjuntos cerrados

Un conjunto cerrado —los tipos de tarea, los tres puntos de corte de las consecuencias, los
canales de investigación— va como `enum` de GDScript, que sí existe acá y sí está tipado. Lo
que **no** va es un `String` suelto: `"limpiar"` escrito en cinco archivos se desincroniza el
día que alguien escriba `"limpar"`, y el motor no dice nada.

## Los datos fijos no viven en el módulo que los usa

Un número que dos archivos necesitan igual —los segundos de un turno, cuántos compradores por
día, cuántos apercibimientos hasta el despido— va a un solo lugar de `src/dominio/` y se
importa. Dos copias de un número no son dos números: son un bug esperando a que alguien
cambie uno.

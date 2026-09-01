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

Es lo que permite escribir el test de «dos jornadas graves seguidas y lo echan» sin jugar dos
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

## Las subcarpetas: cuánto dura el efecto

La carpeta **no repite el nombre del archivo**: dice **qué se rompe si tocás lo que hay
adentro**. Una carpeta `reglas/` con los dos `reglas*.gd` sería una línea más de árbol y cero
información — es la misma regla que los comentarios de este repo, que explican el porqué y no
el qué.

Acá el alcance se mide en **cuánto dura el efecto**:

```text
src/dominio/
├── reglas.gd     ← el balance: lo citan dos de las tres, por eso no está en ninguna
├── jugador/      control_del_jugador · mirada · caminata · foco · reglas_del_jugador
├── jornada/      apertura · turno · tarea · ritmo · marcador
└── empleo/       legajo · consecuencia
```

| Si tocás… | puede cambiar |
|---|---|
| `jugador/` | cómo se siente moverse. **No puede cambiar el resultado de una noche** |
| `jornada/` | la aritmética de la tensión central: cuánto tiempo queda para investigar |
| `empleo/` | el arco entre noches —apercibimientos, despido—. Ninguna noche suelta |

`reglas_del_jugador.gd` en `jugador/` no dice «es del jugador»: dice **«estos números no pueden
desbalancear el turno»**, que es exactamente la distinción con `reglas.gd` que sin la carpeta
sólo dice el docstring.

Y `reglas.gd` se queda en la raíz porque **cruza**: lo nombran `jornada/apertura.gd`,
`jornada/tarea.gd` y `empleo/legajo.gd`, y ningún archivo de `jugador/`. La raíz de una capa es
válida a propósito, y es donde van los que no caben en una sola carpeta.

**Quién lo verifica: `gate_de_capas.py`**, con `CARPETAS_POR_CAPA` de `lib/repo.py`. Y hay que
decir hasta dónde llega, que es la mitad honesta: **valida los NOMBRES de carpeta —que exista
`jugador/` y no `movimiento/`— y NO valida que un archivo esté en la carpeta correcta.** Eso es
semántica, ninguna herramienta lo puede contestar, y lo mira la revisión. Lo que el gate cierra
es la puerta de atrás: inventar un nombre en vez de usar el criterio.

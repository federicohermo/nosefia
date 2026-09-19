---
paths:
  - "src/dominio/**/*.gd"
  - "test/dominio/**/*.gd"
---

# Capa de dominio

Las reglas del juego, sin el motor: el turno, las cinco tareas, el inventario, la ventanilla como
regla —no como pantalla—, la investigación y las consecuencias.

## Puro quiere decir esto, y es literal

**Nada de acá extiende `Node`.** Se extiende `RefCounted` o `Resource`, y nada más.

| No va | Por qué |
|---|---|
| `extends Node` y cualquier descendiente | pide un árbol de escena para existir |
| `get_tree()`, `get_node()`, `$Algo` | lo mismo, por la puerta de atrás |
| `_process`, `_physics_process`, `_input` | el tiempo y la entrada los administra `sistemas/` |
| `await get_tree().create_timer(…)` | el reloj lo pasa `sistemas/`, como un parámetro |
| `preload` de cualquier otra capa | lo bloquea el gate de capas |
| `FileAccess`, `ConfigFile`, `ResourceSaver` | el disco rompe la misma propiedad por la otra puerta |
| `print`, nodos de UI, `Input` | esta capa no tiene con quién hablar |

**La prueba es una sola: un test de `dominio/` corre sin levantar una escena.** Si para probar
algo hace falta un frame, ese algo no va acá.

**La pureza la verifica `gate_de_capas.py`**, y esa tabla es su lista. El `extends` va por **lista
blanca** —`RefCounted`, `Resource`, o un `class_name` del propio dominio—, así que
`extends CharacterBody3D` da rojo sin que nadie lo haya anotado. Una lista negra de descendientes
de `Node` nace incompleta y falla **dando verde**.

**Hasta dónde llega, que es la mitad honesta.** Mira los patrones de esa tabla y nada más, y dos
filas sólo en parte: de los callbacks busca los tres que la fila nombra, así que un `_ready` acá
pasa en verde; y los nodos de UI los caza cuando se los **extiende** o cuando son un `class_name`
de `ui/`, así que un `Label` nombrado como tipo pasa. No es un linter. Agregar el patrón siguiente
es una decisión, con el mismo criterio: ¿esto obliga a levantar una escena para probarlo?

## Por qué esta capa existe

Es la única que se puede ejercer barato, y por eso la única donde el TDD es posible de verdad.
Las consecuencias del turno son **aritmética sobre estado**; escribirlas adentro de un `Node` que
además pinta la pantalla las vuelve inejercitables. Por eso `gate_de_tests.py` exige test para
todo `.gd` de acá: donde el test es barato no hay excusa.

## El tiempo entra como parámetro

```gdscript
# Bien: el turno recibe cuántos segundos se consumieron y decide.
func consumir(segundos: float) -> void:

# Mal: el dominio va a buscar el tiempo, y ahora el test necesita un frame.
func consumir() -> void:
    var dt := get_process_delta_time()
```

Es lo que permite probar «dos jornadas graves seguidas y lo echan» sin jugar dos noches.

## Conjuntos cerrados y valores fijos

Un conjunto cerrado —los tipos de tarea, los cortes de las consecuencias, los canales— va como
`enum`. Un `String` suelto se desincroniza el día que alguien escriba `"limpar"`, y el motor no
dice nada.

Un número que dos archivos necesitan igual vive en **un solo** archivo de `src/dominio/`. Dos
copias de un número no son dos números: son un bug esperando a que alguien cambie una.

## Las subcarpetas: cuánto dura el efecto

La carpeta no repite el nombre del archivo: dice **qué se rompe si tocás lo que hay adentro**.

| Si tocás… | puede cambiar |
|---|---|
| `jugador/` | cómo se siente moverse. **No puede cambiar el resultado de una noche** |
| `jornada/` | la aritmética de la tensión central: cuánto tiempo queda para investigar |
| `empleo/` | el arco entre noches —apercibimientos, despido—. Ninguna noche suelta |
| `almacen/` | **cuánto cuesta cumplir una obligatoria**. Es el lado del turno que se paga |
| `investigacion/` | **cuánto rinde el minuto que no se paga**. Es el otro lado de la misma resta |
| `ambiente/` | cómo se siente la noche, y nada más |

`almacen/` e `investigacion/` son **las dos mitades de la tensión central**, y por eso no entran
en `jornada/`: `jornada/` es la **resta**, y estas dos son lo que cada lado de la resta compra.

- **`almacen/` y no `tareas/`**, aunque `sistemas/` sí tenga `tareas/`. Allá viven los que
  **ejecutan** una obligatoria; acá, el estado del local sobre el que operan. `inventario.gd` no
  es una tarea: es lo que la tarea de reponer consulta.
- **`ambiente/` y no `audio/`**, porque cuatro de sus cinco archivos ya dicen `sonido` o `audio`
  en su nombre. La carpeta declara el alcance y deja lugar a la luz y al clima.
- **`reglas.gd` se queda en la raíz porque cruza**: lo nombran `jornada/` y `empleo/`, y ningún
  archivo de `jugador/`. La raíz de una capa es válida, y es donde van los que no caben en una.

**Quién lo verifica: `gate_de_capas.py`**, con `CARPETAS_POR_CAPA`. Y su mitad honesta: valida los
**nombres** de carpeta y **no** que un archivo esté en la correcta. Eso es semántica, lo mira la
revisión contra el criterio de arriba, y lo que el gate cierra es la puerta de atrás — inventar
un nombre en vez de usar el criterio.

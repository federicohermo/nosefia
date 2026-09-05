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
├── reglas.gd         ← el balance: cruza todas, por eso no está en ninguna
├── jugador/          cómo se siente moverse
├── jornada/          la aritmética de la noche
├── empleo/           el arco entre noches
├── almacen/          qué hay en el local y en qué estado está
├── investigacion/    qué se sabe y qué falta saber
└── ambiente/         cómo suena y se siente la noche
```

| Si tocás… | puede cambiar |
|---|---|
| `jugador/` | cómo se siente moverse. **No puede cambiar el resultado de una noche** |
| `jornada/` | la aritmética de la tensión central: cuánto tiempo queda para investigar |
| `empleo/` | el arco entre noches —apercibimientos, despido—. Ninguna noche suelta |
| `almacen/` | **cuánto cuesta cumplir una obligatoria**: cuántos productos hay que reponer, cuántas manchas hay que limpiar. Es el lado del turno que se paga |
| `investigacion/` | **cuánto rinde el minuto que no se paga**: qué revela una pista, cuándo un caso desemboca. Es el otro lado de la misma resta |
| `ambiente/` | **cómo se siente la noche, y nada más.** Un bug acá no cambia el resultado de ninguna jornada. Es el análogo de `jugador/` un escalón más afuera |

`almacen/` e `investigacion/` son **las dos mitades de la tensión central**, y por eso merecen
nombre propio en vez de entrar en `jornada/`: `jornada/` es la **resta** —cuánto tiempo queda— y
estas dos son **lo que cada lado de la resta compra**.

**Por qué `almacen/` y no `tareas/`.** `sistemas/` ya tiene `tareas/`, y ahí el nombre es
correcto: `repositor.gd` y `limpiador.gd` son lo que **ejecuta** una obligatoria. Abajo, en el
dominio, lo que hay no son las tareas sino **el estado del local sobre el que las tareas
operan**: `inventario.gd` no es una tarea, es lo que la tarea de reponer consulta. Llamarlo
`tareas/` en las dos capas escondería justo esa diferencia — y además `tarea.gd`, el archivo que
sí modela una obligatoria, vive en `jornada/` y se queda ahí.

**Por qué `ambiente/` y no `audio/`.** Por el criterio de arriba: cuatro de los cinco archivos ya
dicen `sonido`, `sonoro` o `audio` en su nombre, así que meterlos en una carpeta `audio/` es una
línea más de árbol y cero información. `ambiente/` dice el **alcance** —cómo se siente la noche, y nada más—
y deja lugar a lo que venga de la misma clase: la luz del local, el clima.

`reglas_del_jugador.gd` en `jugador/` no dice «es del jugador»: dice **«estos números no pueden
desbalancear el turno»**, que es exactamente la distinción con `reglas.gd` que sin la carpeta
sólo dice el docstring. Y los cinco `reglas_de_*` de `almacen/` caen ahí y no en `reglas.gd`
porque fijan **cuánto cuesta una obligatoria**, que es justo lo que esa carpeta mide.

Y `reglas.gd` se queda en la raíz porque **cruza**: lo nombran `jornada/apertura.gd`,
`jornada/tarea.gd` y `empleo/legajo.gd`, y ningún archivo de `jugador/`. La raíz de una capa es
válida a propósito, y es donde van los que no caben en una sola carpeta.

**Quién lo verifica: `gate_de_capas.py`**, con `CARPETAS_POR_CAPA` de `lib/repo.py`. Y hay que
decir hasta dónde llega, que es la mitad honesta: **valida los NOMBRES de carpeta —que exista
`investigacion/` y no `pistas/`— y NO valida que un archivo esté en la carpeta correcta.** Eso es
semántica, ninguna herramienta lo puede contestar, y lo mira la revisión, contra la tabla del
`research.md` del spec 025 —que clasifica los 49 archivos que vienen uno por uno, con su columna
«por qué», y existe justamente por eso—. Lo que el gate cierra es la puerta de atrás: inventar un
nombre en vez de usar el criterio.

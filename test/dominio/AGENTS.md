# Instrucciones del directorio

Copia íntegra de `.claude/rules/dominio.md`.
Aplicar al alcance `paths` indicado, relativo a la raíz del repo.
Los enlaces relativos del texto copiado se resuelven desde el archivo original.

---
paths:
  - "src/dominio/**/*.gd"
  - "test/dominio/**/*.gd"
---

# Capa de dominio

Las reglas del juego, sin el motor: el turno, las tareas, el inventario, la ventanilla como
regla —no como pantalla—, la investigación y las consecuencias.

## Puro quiere decir esto, y es literal

**Nada de acá extiende `Node`.** Se extiende `RefCounted` o `Resource`, y nada más. Tampoco se
pide el árbol de escena, el reloj, la entrada, la pantalla ni el disco.

**La prueba es una sola: un test de `dominio/` corre sin levantar una escena.** Si para probar
algo hace falta un frame, ese algo no va acá.

**La pureza la verifica `gate_de_capas.py`.** Los usos prohibidos los declara `_USOS_DE_MOTOR`,
en `.claude/scripts/lib/capas.py`. El `extends` va por **lista blanca**: `RefCounted`,
`Resource`, o un `class_name` del propio dominio. Así, `extends CharacterBody3D` da rojo sin que
nadie lo haya anotado. Una lista negra de descendientes
de `Node` nace incompleta y falla **dando verde**.

**Hasta dónde llega, que es la mitad honesta.** Mira esos patrones y nada más. Un callback que
la lista no nombra, como `_ready`, pasa en verde. Los nodos de UI los caza cuando se los
**extiende** o cuando son un `class_name` de `ui/`: un `Label` nombrado como tipo pasa. No es
un linter. Agregar el patrón siguiente es una decisión, con el mismo criterio: ¿esto obliga a
levantar una escena para probarlo?

## Por qué esta capa existe

Es la única que se puede ejercer barato, y por eso la única donde el TDD es posible de verdad.
Las consecuencias del turno son **aritmética sobre estado**; escribirlas adentro de un `Node` que
además pinta la pantalla las vuelve inejercitables. Por eso `gate_de_tests.py` exige test para
todo `.gd` de acá: donde el test es barato no hay excusa.

## El tiempo entra como parámetro

Lo pide la [constitución](../../docs/architecture/constitution.md). Así se ve:

```gdscript
# Bien: el turno recibe cuántos segundos se consumieron y decide.
func consumir(segundos: float) -> void:

# Mal: el dominio va a buscar el tiempo, y ahora el test necesita un frame.
func consumir() -> void:
    var dt := get_process_delta_time()
```

Es lo que permite probar «dos jornadas graves seguidas y lo echan» sin jugar dos noches.

## Conjuntos cerrados y valores fijos

Un conjunto cerrado va como `enum`, y un valor fijo vive en un solo archivo de esta capa. Los dos
principios están en la [constitución](../../docs/architecture/constitution.md).

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

`almacen/` e `investigacion/` son **las dos mitades de la tensión central**. Por eso no entran
en `jornada/`: `jornada/` es la **resta**, y estas dos son lo que cada lado compra.

- **`almacen/` y no `tareas/`**, aunque `sistemas/` sí tenga `tareas/`. Allá viven los que
  **ejecutan** una obligatoria; acá, el estado del local sobre el que operan. `inventario.gd` no
  es una tarea: es lo que la tarea de reponer consulta.
- **`ambiente/` y no `audio/`**, porque sus archivos ya dicen `sonido` o `audio` en su nombre.
  La carpeta declara el alcance y deja lugar a la luz y al clima.
- **`reglas.gd` se queda en la raíz porque cruza**: lo nombran `jornada/` y `empleo/`, y ningún
  archivo de `jugador/`. La raíz de una capa es válida, y es donde van los que no caben en una.

**Quién lo verifica: `gate_de_capas.py`**, con `CARPETAS_POR_CAPA`. Y su mitad honesta: valida los
**nombres** de carpeta y **no** que un archivo esté en la correcta. Eso es semántica, y lo mira
la revisión contra el criterio de arriba. El gate cierra la puerta de atrás: inventar un nombre
en vez de usar el criterio.

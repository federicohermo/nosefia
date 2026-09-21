---
paths:
  - "**/*.gd"
---

# GDScript en este repo

Lo que vale en todo `.gd`. Lo específico de cada capa está en las otras reglas de esta carpeta.

**Casi nada de acá es una preferencia**: lo que se puede verificar lo verifica `gdlint`,
`gdformat` o un gate, y la regla dice quién. Lo que no tiene verificador se dice igual, sabiendo
que es prosa — y la prosa no frena a nadie.

## Tipado estático, siempre

```gdscript
var tareas_hechas: int = 0
func consecuencia_de(cumplidas: int, obligatorias: int) -> Consecuencias.Banda:
```

Sin tipos, el error de una firma que cambió aparece **en runtime, en la escena, a los tres
días**. Con tipos lo caza el editor al guardar. No hay gate que lo verifique: depende de la
revisión.

El `-> void` va también en las funciones que no devuelven nada. Omitirlo no es «más corto»: es no
haber decidido.

## Tabs, y el formato lo pone la herramienta

`gdformat` decide indentación, espacios y cortes de línea. **No se discute formato en una
revisión**: se corre `gdformat src test`. Lo verifica el nodo `formato`. El largo máximo de línea
es **100**, y lo verifica `gdlint`.

## Los comentarios explican el porqué, no el qué

`# suma uno a las tareas` arriba de `tareas += 1` no dice nada que el código no diga, y envejece:
el día que la línea cambie, el comentario miente. Lo que sí hay que escribir es lo que el código
**no puede** decir — una decisión, una restricción del motor, un bug evitado, un número medido.

El texto va en español, con las reglas del lenguaje en
[convenciones](../../docs/guides/conventions.md). Las excepciones son las que impone el motor:
`_ready`, `_process`, `queue_free`, los nombres de los nodos y las APIs de gdUnit4.

## Sin `print` que sobreviva al commit

`print` en producción es ruido en la consola de todos y no se puede filtrar. Para depurar
mientras se trabaja está bien; lo que no puede es quedar. Un mensaje que sí tiene que quedar va
con `push_warning` o `push_error`, que aparecen en el panel de depuración con su origen.

## Nombres

| Qué | Cómo | Quién lo verifica |
|---|---|---|
| Archivo | `snake_case.gd` | la convención de Godot, y el espejo de `test/` |
| `class_name` | `PascalCase` | `gdlint` |
| Función y variable | `snake_case` | `gdlint` |
| Constante | `MAYUSCULA_CON_GUIONES` | `gdlint` |
| Señal | `snake_case`, en pasado: `turno_cerrado` | `gdlint` |

Una señal se llama por **lo que pasó**, no por lo que hay que hacer: `tarea_completada` y no
`actualizar_hud`. Quien la emite no sabe quién la escucha, y ponerle el nombre de la reacción ata
las dos puntas justo donde la señal existía para desatarlas.

## Nada de `get_node()` con rutas largas hacia arriba

`get_node("../../Panel/Hud")` ata un script a la forma exacta del árbol, y una escena que se
reacomoda lo rompe sin que nada avise hasta que se corre. Las dos salidas: `@export var hud: Hud`
—se conecta en el editor— o una señal hacia arriba.

## La dirección de dependencia, y las dos formas de referenciar

`src/dominio` → `src/sistemas` → `src/ui` → `src/escenas`, y sólo hacia abajo. Lo verifica
`gate_de_capas.py`, y vale para las dos maneras en que un script llega a otro:

1. **Por ruta** — `preload("res://src/ui/hud.gd")`, `load(…)`, `extends "res://…"`.
2. **Por `class_name`** — un script que declara `class_name Ventanilla` queda registrado
   **globalmente**, y desde cualquier otro archivo se lo nombra sin escribir una sola ruta.

La segunda es la forma **normal** de escribir GDScript, y es la que ningún análisis de imports
encuentra. Por eso el gate construye el índice `class_name → capa` y busca esos identificadores
como palabras, sobre el código con los comentarios y los strings limpiados.
`python .claude/scripts/estructura.py` imprime ese grafo con el mismo índice.

**Lo que el gate no puede ver**, para que no se lea como cobertura total:

- **Los autoloads.** Son globales por construcción: viven en `project.godot` y cualquiera los ve,
  sin escribir una referencia.
- **Las escenas.** Un `.tscn` referencia scripts, pero el caso peligroso —una escena en
  `dominio/`— no puede existir, porque `dominio/` no tiene escenas.

## Autoloads

*(Ninguno todavía. Cuando se agregue el primero, va acá con para qué está.)*

La pregunta antes de agregar uno: ¿esto lo necesita **todo** el juego, o lo necesitan dos escenas
que podrían pasárselo? Si son dos, no es un autoload.

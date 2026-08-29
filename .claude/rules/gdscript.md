---
paths:
  - "**/*.gd"
---

# GDScript en este repo

Lo que vale en todo `.gd`, sea de la capa que sea. Lo específico de cada capa está en las
otras reglas de esta carpeta, y se carga sola al tocar sus archivos.

**Casi nada de acá es una preferencia**: lo que se puede verificar lo verifica `gdlint`,
`gdformat` o uno de los dos gates, y cuando así es, la regla dice quién la verifica. Lo que
no tiene verificador se dice igual, pero sabiendo que es prosa — y la prosa no frena a nadie.

## Tipado estático, siempre

```gdscript
var tareas_hechas: int = 0
func cerrar_turno(tareas: Array[Tarea]) -> Consecuencia:
```

GDScript tipa opcionalmente, y sin tipos el error de una firma que cambió aparece **en
runtime, en la escena, a los tres días**. Con tipos lo caza el editor al guardar. Que el
motor lo tolere no lo vuelve aceptable acá: no hay un gate que lo verifique, así que es de
las pocas reglas que dependen de que la revisión la mire.

Y el `-> void` va también en las funciones que no devuelven nada. Omitirlo no es «más corto»:
es no haber decidido.

## Tabs, y el formato lo pone la herramienta

`gdformat` decide la indentación, los espacios alrededor de los operadores y dónde corta una
línea. **No se discute formato en una revisión**: se corre `gdformat src test` y se acabó. Lo
verifica el nodo `formato` de `verificar.py`, que corre `gdformat --check`.

El largo máximo de línea es **100** y lo verifica `gdlint`.

## Español

Comentarios, nombres de funciones y variables, mensajes de commit, specs y documentación. El
equipo escribe y piensa en español, y un repo mitad y mitad obliga a traducir dos veces por
día.

Las excepciones son las que impone el motor: `_ready`, `_process`, `queue_free`, los nombres
de los nodos de Godot y las APIs de gdUnit4. Ésas se escriben como son.

## Los comentarios explican el porqué, no el qué

`# suma uno a las tareas` arriba de `tareas += 1` no dice nada que el código no diga, y
envejece: el día que la línea cambie, el comentario va a mentir. Lo que sí hay que escribir es
lo que el código **no puede** decir — una decisión, una restricción del motor, un bug evitado,
un número medido.

## Sin `print` que sobreviva al commit

`print` en producción es ruido en la consola de todos y no se puede filtrar. Para depurar
mientras se trabaja está bien; lo que no puede es quedar. Un mensaje que sí tiene que quedar
va con `push_warning` o `push_error`, que aparecen en el panel de depuración con su origen.

## Nombres

| Qué | Cómo | Quién lo verifica |
|---|---|---|
| Archivo | `snake_case.gd` | la convención de Godot, y el espejo de `test/` |
| `class_name` | `PascalCase` | `gdlint` |
| Función y variable | `snake_case` | `gdlint` |
| Constante | `MAYUSCULA_CON_GUIONES` | `gdlint` |
| Señal | `snake_case`, en pasado: `turno_cerrado` | `gdlint` |

Una señal se llama por **lo que pasó**, no por lo que hay que hacer: `tarea_completada` y no
`actualizar_hud`. Quien la emite no sabe quién la escucha, y ponerle el nombre de la reacción
ata las dos puntas justo donde la señal existía para desatarlas.

## Nada de `get_node()` con rutas largas hacia arriba

`get_node("../../Panel/Hud")` ata un script a la forma exacta del árbol de escena, y una
escena que se reacomoda —que es lo que pasa todo el tiempo mientras se diseña— lo rompe sin
que nada avise hasta que se corre. Las dos salidas son `@export var hud: Hud` —y se conecta en
el editor— o una señal hacia arriba.

## La dirección de dependencia entre capas la verifica un gate

`src/dominio` → `src/sistemas` → `src/ui` → `src/escenas`, y sólo hacia abajo. Vale tanto para
`preload("res://…")` como para nombrar un `class_name` de otra capa, que es la puerta que no
deja rastro en ningún import.

Lo verifica `python .claude/scripts/gate_de_capas.py`. El porqué de cada capa está en
[docs/architecture/overview.md](../../docs/architecture/overview.md).

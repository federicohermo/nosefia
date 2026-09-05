# Convenciones

Acá está el **porqué**. La regla en corto, y quién la verifica, está en `.claude/rules/`, que
se carga sola al tocar los archivos de cada capa.

## Qué se verifica y qué es prosa

Esta tabla es lo más útil del documento: dice de qué reglas hay que acordarse y de cuáles no.

| Regla | Quién la verifica |
|---|---|
| Formato (indentación, espacios, cortes de línea) | `gdformat --check` |
| Largo de línea (100), nombres, orden de declaraciones | `gdlint` |
| Dirección de dependencia entre capas | `gate_de_capas.py` |
| Los nombres de subcarpeta de cada capa | `gate_de_capas.py` |
| Todo script de `dominio/`/`sistemas/` con su test | `gate_de_tests.py` |
| Ningún test sin aserción, apagado o mal nombrado | `gate_de_tests.py` |
| El registro de specs contra GitHub | `tests/test_mapa.py` |
| El formato de un spec y sus cuatro techos | `tests/test_convencion_de_specs.py` |
| Cada criterio del spec de la rama, citado por un test | `tests/test_criterios_de_la_rama.py` |
| No editar `src/` sin spec | el hook de `.claude/settings.json` |
| **Tipado estático en toda firma** | **nadie: prosa** |
| **Comentarios que expliquen el porqué** | **nadie: prosa** |
| **Español** | **nadie: prosa** |
| **`print` que no sobreviva al commit** | **nadie: prosa** |

Las cuatro últimas dependen de que la revisión las mire. Que una regla se pueda verificar y no
se verifique es deuda, y va como issue.

## Tipado estático, siempre

```gdscript
var tareas_hechas: int = 0
func cerrar_turno(tareas: Array[Tarea]) -> Consecuencia:
```

GDScript tipa opcionalmente. Sin tipos, el error de una firma que cambió aparece **en runtime,
adentro de la escena, tres días después**; con tipos lo caza el editor al guardar. Un motor que
lo tolera no lo vuelve aceptable: en un juego, «aparece en runtime» quiere decir «aparece
jugando», y jugando nadie está leyendo la consola.

El `-> void` va también en las funciones que no devuelven nada: omitirlo no es más corto, es no
haber decidido.

## La dirección de dependencia

`dominio/` → `sistemas/` → `ui/` → `escenas/`, sólo hacia abajo. El porqué de cada capa está en
[la visión general](../architecture/overview.md); acá va el porqué de que sea un **gate** y no
una recomendación.

Porque en Godot la violación no deja rastro. Un script llega a otro nombrando su `class_name`,
sin escribir una sola ruta, así que no hay ningún import que revisar en el diff. La regla o se
verifica sobre el índice de clases o **no se verifica**, y una regla de arquitectura que no se
verifica dura hasta el primer apuro.

**Si el gate te frena, la salida no es una excepción.** Son dos:

- **Bajar la decisión.** Si el dominio necesita saber algo de la UI, casi siempre es que la
  regla estaba escrita al revés: la UI le pregunta al dominio, no al revés.
- **Pasar el dato por parámetro** en vez de ir a buscarlo.

## Y los nombres de subcarpeta, por el mismo motivo

El mismo gate verifica que cada `.gd` y cada `.tscn` de `src/` esté en una subcarpeta que su
capa declara, leyéndolas de `CARPETAS_POR_CAPA` en `.claude/scripts/lib/repo.py`. **El criterio
de cada capa vive en su `.claude/rules/`** —`dominio.md`, `sistemas.md`, `presentacion.md`— y es
siempre el mismo: la carpeta dice **qué se rompe si tocás lo que hay adentro**, nunca lo que el
nombre del archivo ya dice.

Es un gate y no prosa por el mismo motivo que la dirección: una convención de árbol escrita en
un documento dura hasta el primer archivo que alguien deja en la raíz apurado, y ordenar una
capa cuando ya está desordenada cuesta un spec entero de renombres.

**Lo que el gate NO contesta es si un archivo está en la carpeta *correcta*.** Eso es semántica
y ninguna herramienta lo puede decidir: lo mira la revisión. Y la raíz de una capa la admite a
propósito, que es donde viven los que cruzan dos carpetas —`reglas.gd`, `hud.gd`— o los que son
la raíz del árbol.

## Los valores fijos viven una sola vez

Los segundos de un turno, cuántos compradores por día, cuántos apercibimientos hasta el
despido: cada uno en **un** archivo de `src/dominio/`, importado por quien lo necesite.

Dos copias de un número no son dos números: son un bug esperando a que alguien cambie una. Y en
un juego que se balancea —y este se va a balancear entre entregas— ese cambio pasa todas las
semanas.

## Conjuntos cerrados con `enum`

Los tipos de tarea, los tres puntos de corte de las consecuencias, los canales de
investigación. Lo que **no** va es un `String` suelto: `"limpiar"` escrito en cinco archivos se
desincroniza el día que alguien escriba `"limpar"`, y el motor no dice absolutamente nada — el
`if` simplemente no entra nunca.

## Las señales se llaman por lo que pasó

`tarea_completada`, no `actualizar_hud`. Quien emite no sabe quién escucha, y ponerle a la señal
el nombre de la reacción ata las dos puntas justo donde la señal existía para desatarlas — y
además queda mintiendo apenas haya un segundo oyente.

## Nada de `get_node()` con rutas largas

`get_node("../../Panel/Hud")` ata un script a la forma exacta del árbol de escena. Una escena
que se reacomoda —que es lo que pasa todo el tiempo mientras se diseña— lo rompe, y no avisa
hasta que se corre esa pantalla. Las dos salidas: `@export var hud: Hud`, que se conecta en el
editor y falla al abrir la escena si falta, o una señal hacia arriba.

## Comentarios: el porqué, no el qué

`# suma uno a las tareas` arriba de `tareas += 1` no dice nada que el código no diga, y encima
envejece: el día que la línea cambie, el comentario miente. Lo que hay que escribir es lo que
el código **no puede** decir — una decisión, una restricción del motor, un bug evitado, un
número medido.

Los comentarios de `.claude/scripts/` son largos a propósito por esto mismo: casi todos guardan
el modo de falla que justifica una línea rara, y ése es el dato que no se recupera leyendo el
código.

## Español

Comentarios, nombres, commits, specs y documentación. El equipo escribe y piensa en español, y
un repo mitad y mitad obliga a traducir dos veces por día. Las excepciones son las que impone
el motor: `_ready`, `_process`, `queue_free`, las APIs de gdUnit4.

## Los borrados van en su propio commit

Para que revertirlos sea trivial. Un commit que borra un sistema y además agrega otro obliga a
elegir entre perder las dos cosas o ninguna.

## Nombres

| Qué | Cómo |
|---|---|
| Archivo | `snake_case.gd` |
| `class_name` | `PascalCase` |
| Función y variable | `snake_case` |
| Constante | `MAYUSCULA_CON_GUIONES` |
| Señal | `snake_case`, en pasado |
| Rama | `feature/<NNN>-<kebab>`, o `fix/`/`chore/` cuando no hay spec |
| Test | `test/<capa>/<nombre>_test.gd` |

Los cinco primeros los verifica `gdlint`; el de rama, el hook; el de test, `gate_de_tests.py`.

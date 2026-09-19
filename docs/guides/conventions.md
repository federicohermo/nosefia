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
| La forma de los contratos de capacidad y sus IDs | `gate_de_specs.py` |
| Cada criterio de un spec `ratified`, citado por un test | `gate_de_specs.py` |
| Que un skill traiga adentro todo lo que corre, copia por copia | `tests/test_copias_de_skills.py` |
| Que un doc diga la regla y no la lista de los skills | `tests/test_docs_no_enumeran_skills.py` |
| No editar `src/` sin issue detrás de la rama | el hook de `.claude/settings.json` |
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
capa cuando ya está desordenada cuesta un issue entero de renombres.

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

## Lenguaje

El texto sigue el modelo de **ASD-STE100**, aplicado al español. Vale para el código, los tests,
los comentarios, la documentación, `CLAUDE.md`, las reglas, los specs, los issues, los commits,
los PR y las respuestas de un agente.

1. Escribir una idea por oración.
2. Escribir instrucciones de 20 palabras o menos. Escribir descripciones de 25 palabras o menos.
3. Escribir párrafos de una idea y seis oraciones o menos.
4. Usar voz activa y tiempo presente.
5. Escribir los pasos en infinitivo: «Correr el gate», «Mover la regla al dominio».
6. Usar numeración para una secuencia y viñetas para un conjunto.
7. Poner la advertencia antes del paso al que aplica.
8. Usar un solo término por concepto. Usar el término del glosario. No usar sinónimos.
9. No usar palabras de relleno: «simplemente», «básicamente», «muy», «realmente».
10. Escribir los nombres de código, archivo y variable tal como son, entre comillas invertidas.

**Español en el contenido, inglés en los nombres de carpeta.** La única excepción es el árbol de
`src/` entero, que no es estructura sino vocabulario del GDD. Las excepciones del texto son las
que impone el motor: `_ready`, `_process`, `queue_free`, las APIs de gdUnit4.

**Un número medido se escribe con su medición**, no con un adjetivo. «Casi el triple» no es un
dato; «10 620 contra un piso de 3600» sí.

## Glosario

Un término por concepto. La columna de la derecha no es estilo: son las palabras que ya
produjeron una confusión acá.

| Término | Significado | No usar |
|---|---|---|
| **jornada** | Una noche de la partida, numerada desde 1. | día, nivel |
| **turno** | El presupuesto de tiempo de una jornada, en segundos de ficción. | ronda, tiempo |
| **obligatoria** | Una de las cinco tareas que el jefe pide esa noche. | misión, objetivo |
| **capacidad** | Una tajada de lo que el juego hace. Tiene un contrato en `specs/`. | módulo, feature |
| **contrato** | El spec de una capacidad, y la verdad a la que el código contesta. | documento, ficha |
| **criterio** | Un `AC-<COD>-###` del contrato. Lo cierra un agente. | requisito, tarea |
| **regla** | Un `BR-<COD>-###` del contrato. | norma, política |
| **issue** | El plan de una unidad de entrega, en formato task-brief. | ticket, tarea |
| **gate** | Un verificador que da rojo. Los del repo se llaman `gate_*.py`. | check, chequeo |
| **nodo de verificación** | Uno de los siete pasos de `verificar.py`. | etapa, paso |
| **`Node`** | La clase del motor. Se escribe entre comillas invertidas y en inglés. | nodo (a secas) |
| **capa** | Uno de los cuatro directorios de `src/`. | módulo, paquete |
| **salteado** | Un nodo que no pudo correr y lo declara. **No es verde.** | omitido, skipped |
| **medido** | Que se corrió algo y contestó un número. | estimado, aproximado |

Los nombres de código no cambian por el glosario: `Tarea`, `Turno`, `_process`.

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
| Rama | `feature/<issue>-<kebab>`, `bugfix/` o `hotfix/` para `src/`; `harness/`, `docs/` o `ci/` cuando no toca el producto |
| Test | `test/<capa>/<nombre>_test.gd` |

Los cinco primeros los verifica `gdlint`; el de rama, el hook; el de test, `gate_de_tests.py`.

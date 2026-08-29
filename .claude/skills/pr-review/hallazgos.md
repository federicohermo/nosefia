# El método — encontrar sin generar ruido

**Este archivo es de los dos skills de PR y vive una sola vez.** Lo lee `pr-review` en su Paso 5,
y `pr-review-batch` se lo pasa por ruta a cada uno de sus N agentes — por eso está afuera de los
dos `SKILL.md`: no le cuesta contexto al padre del batch, que no busca hallazgos, y no hay que
inlinear cien líneas en cada prompt. Si algo de acá cambia, cambia para los dos, que es
exactamente lo que se quiere.

Lo que separa un review útil de una lista de ruido está acá, no en la cantidad de hallazgos.

## Los ejes

`scripts/diff_pr.py` decide cuáles se abren, midiendo sobre el `.diff`. **Un eje que salió `no` no
se revisa** — no le busques hallazgos.

| Eje | Qué buscás en este repo |
|---|---|
| **Correctness** (siempre) | bugs alcanzables por el flujo real: el turno corriendo, la ventanilla, completar una tarea dos veces, el cierre |
| **Capas** (siempre) | **el eje que más rinde acá, y el único que ningún gate puede ver.** Ver abajo |
| **Convenciones** (siempre) | **sólo lo que las herramientas no pueden ver** — abajo está la línea, y `CLAUDE.md` ya la dibujó |
| **Prosa** (docs + comentarios) | texto que dejó de ser cierto. Ver abajo |
| **Manejo de errores** | ramas de error mudas, un `push_error` que falta, un `if` que se traga el caso |
| **Firmas y tipos** | un conjunto cerrado escrito como `String` suelto en vez de `enum`; una firma sin tipo |
| **Cobertura** | **acá no hay red**: Godot no mide cobertura. Ver abajo |
| **Escenas** | un `.tscn` en el diff. No se revisa línea por línea; ver abajo |

### Capas: el eje que ningún gate puede ver

`gate_de_capas.py` verifica la **dirección** de la dependencia, incluida la que se cruza nombrando
un `class_name`. Lo que **no** puede ver —y está escrito en `CLAUDE.md` con todas las letras— es
esto:

> Si una regla del juego termina en `ui/` o en `escenas/`, esa regla **nace sin test** y ningún
> gate lo va a decir.

`gate_de_tests.py` sólo exige espejo en `src/dominio/` y `src/sistemas/`. Una regla —cuántas
tareas cuentan, qué pasa a las tres jornadas, cuánto cuesta atender— escrita adentro de un
`_process` o de un botón pasa los seis nodos en verde y no la ejerce nadie.

**La prueba es una sola: ¿se puede ejercer sin levantar una escena?** Si sí y está arriba, es
hallazgo, y el arreglo no es testear la pantalla: es bajar la regla a `dominio/`.

Y su hermano, más chico: **un `if` sobre un `String` donde el conjunto es cerrado**. `"limpar"` no
rompe nada — el `if` simplemente no entra nunca, para siempre, en silencio.

### Convenciones: dónde está la línea

**`CLAUDE.md` ya la dibujó**, y hay que respetarla en los dos sentidos. Reportar a mano lo que
`verificar.py` ya rechaza es ruido con costo: el PR no puede haber llegado verde con eso adentro.

| Ya lo verifica una herramienta — **no lo reportes** | Nadie lo verifica — **es tuyo** |
|---|---|
| la dirección de dependencia entre capas, incluido el `class_name` | tipado estático en toda firma, `-> void` incluido |
| que todo `.gd` de `dominio/` y `sistemas/` tenga su test espejo | que el comentario explique el **porqué** y no el qué |
| el test sin aserción, apagado, o con un nombre que no corre | español en comentarios, nombres, commits y specs |
| formato, largo de línea, nombres y orden de declaraciones (`gdformat`, `gdlint`) | que un valor fijo no viva en dos lugares |
| que no se edite `src/` ni `docs/` sin un spec detrás de la rama | que no quede ningún `print` |
| | `get_node("../../…")` en vez de `@export` y señales |
| | que los borrados vayan en su propio commit |
| | que el AC del spec sea falsable y esté cubierto |

**`gdformat` decide el formato y no se discute en una revisión.** Si algo del formato te molesta,
el hallazgo es sobre la config, no sobre el PR.

### Prosa: texto que dejó de ser cierto

En el repo del que sale este harness fue el eje más productivo: **17 de 21 hallazgos de una
corrida fueron prosa que dejó de ser cierta**, no código roto. Acá todavía no hay corrida que lo
confirme — tratalo como una hipótesis con buen linaje, no como un hecho de este juego.

Dos sondas, en este orden, las dos baratas:

1. **Cruzá cada afirmación numérica contra el spec del propio PR.** `diff_pr.py` te deja la lista
   de las que el diff agrega, ya sin la numeración estructural. `specs/NNN-*/research.md` es donde
   vive la medición: si el doc dice otro número que el research, **gana el research** y el doc es
   el hallazgo.
2. **Buscá el gemelo del párrafo que el PR sí actualizó.** Un cambio acá se anuncia en varios
   registros a la vez —`CLAUDE.md`, `docs/`, `.claude/rules/`, el `README` de `specs/`— y es
   habitual que actualicen uno y se olviden del resto. Grepeá la clave del cambio: el número del
   spec, el nombre del archivo, la cifra vieja.

Un comentario o un doc que ya contradice al código de al lado es **🔴, no 🟡**: este repo trata la
prosa como parte del contrato, y `CLAUDE.md` se carga en cada sesión.

### Cobertura: acá no hay red

**Godot no mide cobertura y ninguna herramienta del ecosistema lo hace.** El harness del que sale
éste sostenía el TDD con un umbral del 100 %; acá eso no existe.

O sea que la pregunta que allá contestaba el CI, acá **la contestás vos**: `gate_de_tests.py` sabe
si el archivo de test existe, si afirma algo y si va a correr. **No sabe si ejerce una rama.** Es
un piso, no un techo, y el techo es este eje.

Concretamente: por cada rama que el diff agrega en `dominio/` o `sistemas/`, ¿hay un caso que
falla si esa rama estuviera mal? Un test que la ejecuta sin afirmar sobre su efecto es cobertura
sin verificación, y eso sí es hallazgo.

### Escenas: no se revisan línea por línea

Un `.tscn` es texto pero no es legible: los `node_paths`, los `SubResource` y los ids no dicen
nada leídos de a una línea. **No busques bugs adentro del diff de una escena.** Lo que sí es tuyo:

- **¿La escena trae lógica que debería estar en `dominio/`?** Ver el eje de capas.
- **¿Otro PR del lote toca la misma escena?** Eso no lo podés saber vos —tu rango sólo ve hacia
  abajo— pero si el padre te lo dijo en el preámbulo, **el hunk se queda quieto**: un `.tscn` no se
  mergea, y el Paso 6 va a tener que resolverlo a mano.

## Filtro de confianza

Puntuá cada hallazgo de 0 a 100 y **descartá todo lo que quede por debajo de 80**:

- **0** — falso positivo que no aguanta escrutinio liviano, o problema preexistente que el diff no
  introdujo.
- **25** — podría ser real pero no lo verificaste. Si es estilístico y no está en `CLAUDE.md` ni en
  `.claude/rules/`, no existe.
- **50** — verificado como real, pero es nitpick o pasa poco en la práctica.
- **75** — verificado, se golpea de verdad, y el enfoque actual del PR no alcanza. O está nombrado
  explícitamente en las convenciones del repo.
- **100** — confirmado con evidencia directa.

### Falsos positivos típicos — no van al reporte

- Problemas **preexistentes** en líneas que el PR no tocó.
- Cualquier cosa de la columna izquierda de la tabla de convenciones.
- **Un nodo de `verificar.py` que se salteó.** No es un hallazgo del PR: es que faltó `GODOT_BIN`,
  y el protocolo está en el skill que te invocó —Paso 6 de `pr-review`, Paso 4 del batch—. Pero
  **tampoco es verde**: no lo declares como si el PR hubiera pasado.
- Nitpicks que un senior no marcaría.
- Cambios de comportamiento que evidentemente **son la intención del PR**. Contra eso está el
  spec: si el spec lo pide, no es bug.
- Formato. Lo decide `gdformat`.

### Verificá la premisa antes de reportar

Si el hallazgo depende de una premisa sobre el entorno —una config, un flag, una versión de Godot,
un default del motor—, **comprobá la premisa**. Un grep de cinco segundos descarta la mitad de los
🔴 candidatos, y reportar uno cuesta además un fix innecesario.

**Y para buscar adentro de `specs/`, `rg --no-ignore`.** `Grep` es ripgrep y respeta el
`.gitignore`: contesta cero sin decir que no miró, que es la peor respuesta posible para verificar
una premisa.

## Política de triage — al aplicar los fixes

«Arreglá todo» es la forma más rápida de romper el PR. Pero el error que de verdad se comete es el
otro: en una corrida medida del repo de origen, **de ocho hallazgos, tres se declararon sin
aplicar y sólo uno tenía motivo**. Los otros dos fueron un bloqueo mecánico archivado como si
fuera una decisión, y una cláusula aplicada al revés. Por eso el default es **arreglar**, y no
aplicar es lo que necesita justificarse.

| Clase | Qué hacer |
|---|---|
| 🔴 Bloqueante | **se arregla siempre** |
| 🟡 con fix acotado que no toca lo que el PR garantiza | se arregla |
| 🟡 cuyo fix pelea con un AC o con el invariante del propio PR | **no se toca** — se declara y se abre como issue |
| 🟡 preexistente que el diff sólo agrava | se arregla **si el archivo ya está tocado por el PR** |
| 🟡 cuyo fix sería un cambio de diseño más grande que el PR | se declara como issue, y el cuerpo dice **qué diseño haría falta** |
| Fix que una herramienta te bloqueó | **no es un 🟡** — ver «bloqueado» abajo |

**Las tres filas de «no se toca» son la lista completa.** Si tu motivo para no aplicar un fix no
es uno de esos tres —pelea con un AC, pediría rediseñar, o lo cierra una persona—, entonces **no
hay motivo y el fix se aplica**. «Es preexistente», «es de otro spec», «no lo medí» y «lo intenté
y no pude» no están en la lista, y los cuatro aparecieron en corridas reales.

### «Bloqueado» no es «descartado»

Si una herramienta te niega el fix, **eso no es una decisión de triage**. Un 🟡 archivado y un fix
que no te dejaron aplicar se leen igual en el reporte y son cosas opuestas: del primero ya se
decidió, del segundo no decidió nadie.

1. **Reintentá por otro camino.** Y si el bloqueo vino del hook, **mirá el nombre de tu rama antes
   que nada**: `gate_de_spec.py` exige `feature/<NNN>-` con el `NNN` en `specs/mapa.json` para
   tocar `src/` o `docs/`. Es la causa número uno de un fix bloqueado acá.
2. Si sigue bloqueado, **paralo y reportalo como `BLOQUEADO: <qué> — <quién lo bloqueó>`**, con el
   fix exacto que ibas a aplicar, en una línea que se pueda copiar.
3. **Abrilo igual como issue**, diciendo que quedó bloqueado y no que se descartó.

El padre corre en el checkout principal y con otros permisos: un fix que a vos te bloquearon, él
lo aplica. Pero sólo si el reporte lo distingue.

### «Preexistente» no cubre una línea que tu diff volvió a escribir

El mismo test mecánico decide las dos caras: **si la línea aparece como `+` en tu `pr.diff`, es
tuya.** Vale para tener que arreglarlo, y en el batch vale además para atribuirlo — allá es el
reverso exacto de la cláusula 1, que usa el mismo test para mandar hacia abajo lo que no es `+`.
En un review suelto no hay «abajo», así que acá queda sólo la mitad que obliga.

Que el número lo haya vuelto falso un spec anterior no cambia nada: lo que importa es que **tu
diff lo volvió a escribir**, y una afirmación falsa re-tipeada es una afirmación que este PR
afirma. Un párrafo re-justificado cuenta como re-tipeado.

### El destino de un 🟡 que no se aplica es un issue

No el chat, y **no el spec**. Adentro de un `tasks.md` el ítem **hereda el estado de su spec**:
un spec `Implementado` puede quedar con diez casillas abiertas sin deberle nada a nadie, y así es
como la deuda se vuelve invisible. Un issue tiene estado propio y se cierra con `Closes #N`
desde un commit — y **sobrevive aunque el PR no se mergee**.

Se abre con `gh issue create --repo federicohermo/nosefia`, y lleva tres cosas:

- **Título que se entienda fuera del contexto del spec.** En la lista de issues no hay más
  contexto que el título.
- **Cuerpo con la evidencia** —`archivo:línea`, el número medido, qué hace falta para verlo—. Es
  lo único que queda cuando el diff ya no está.
- **`Detectado en #N`**, con el issue del spec del PR. **El `#N` sale de `specs/mapa.json`, no del
  `NNN`**: son dos numeraciones distintas y en este repo ya divergen — el spec 001 es el issue #3.

**El label es `bug` o `enhancement`.** No inventes uno: un label propio vuelve a partir el tracker
en dos, que es exactamente el problema que este destino cierra.

Y el precio de que el destino esté fuera del repo: **el reviewer del PR no lo ve en el diff**, así
que va sí o sí al reporte.

**Propagá cada fix a todo lo que lo describe.** Un cambio de firma toca el código **y** el
`spec.md`, cada doc que muestre el snippet viejo, y las tareas del spec que lo nombran. Un fix de
código que deja mintiendo a la doc del propio PR es medio fix.

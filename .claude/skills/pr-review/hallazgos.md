# El método — encontrar sin generar ruido

**Este archivo es de los dos skills de PR y vive una sola vez.** Lo lee `pr-review` en su Paso 5,
y `pr-review-batch` se lo pasa por ruta a cada uno de sus N agentes — por eso está afuera de los
dos `SKILL.md`: no le cuesta contexto al padre del batch, que no busca hallazgos, y no hay que
inlinear cien líneas en cada prompt. Si algo de acá cambia, cambia para los dos, que es
exactamente lo que se quiere.

Lo que separa un review útil de una lista de ruido está acá, no en la cantidad de hallazgos.

**Y ninguno de esos hallazgos sobrevive a la corrida:** las cinco descargas están en
[`../shared/sin-deuda.md`](../shared/sin-deuda.md), que es de los siete skills. Acá está sólo cómo
aterrizan sobre un diff.

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

**Lo que se acota es dónde BUSCÁS, no qué arreglás.** El alcance de la búsqueda es el diff y lo que
el diff toca — un review que sale a recorrer el repo entero no termina nunca. Pero lo que la
búsqueda encuentre se arregla, aunque sea preexistente: la tabla de arriba decide **dónde
aterriza**, no si se hace.

Puntuá cada hallazgo de 0 a 100 y **descartá todo lo que quede por debajo de 80**:

- **0** — falso positivo que no aguanta escrutinio liviano.
- **25** — podría ser real pero no lo verificaste. Si es estilístico y no está en `CLAUDE.md` ni en
  `.claude/rules/`, no existe.
- **50** — verificado como real, pero es nitpick o pasa poco en la práctica.
- **75** — verificado, se golpea de verdad, y el enfoque actual del PR no alcanza. O está nombrado
  explícitamente en las convenciones del repo.
- **100** — confirmado con evidencia directa.

### Falsos positivos típicos — no van al reporte

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

**No hay hallazgo que sobreviva a la corrida.** El método entero está en
[`../shared/sin-deuda.md`](../shared/sin-deuda.md) y no se repite acá; lo que sigue es cómo aterriza
sobre un diff.

Está medido de los dos lados. En una corrida del repo de origen, **de ocho hallazgos tres se
declararon sin aplicar y sólo uno tenía motivo**: los otros dos fueron un bloqueo mecánico
archivado como si fuera una decisión, y una cláusula aplicada al revés. Y del otro lado, la
detección de defectos de un review cae de **87 % con menos de 100 líneas a 28 % con más de 1000**
— o sea que meter todos los fixes en el PR que estás revisando **degrada la revisión que estás
haciendo**.

Las dos mediciones juntas dan una sola regla: **todo se arregla, y no todo aterriza acá.**

| Clase | Se arregla | Aterriza en |
|---|---|---|
| 🔴 Bloqueante | siempre | **este PR** |
| 🟡 acotado, del alcance del spec | sí | **este PR** |
| 🟡 en una línea que tu diff agrega o reescribe | sí | **este PR** — ver abajo |
| 🟡 preexistente, en un archivo que el PR ya toca | sí | **este PR** si el fix es acotado; si no, PR propio |
| 🟡 en un archivo que el PR no toca | sí | **su propio PR**, abierto en esta corrida |
| 🟡 cuyo fix pelea con un AC | sí, **corrigiendo el AC** | el `spec.md`, y de vuelta al issue |
| 🟡 cuyo fix sería un rediseño más grande que el PR | sí, **corrigiendo el alcance** | el `spec.md`, y de vuelta al issue |
| Decisión que es del usuario | se **pregunta ahora**, bloqueando | la respuesta, escrita |
| Fix que una herramienta te bloqueó | ver «bloqueado» | **la corrida falla** |

**«Es preexistente», «es de otro spec», «no lo medí» y «lo intenté y no pude» no son motivos** —
los cuatro aparecieron en corridas reales. Los dos primeros deciden **dónde aterriza**, nunca
**si se hace**.

Un fix que pelea con un AC no significa «no lo toco»: significa que **el AC está mal**, y
corregirlo es más barato ahora que después. Igual con el que pediría un rediseño: el que estaba
mal era el alcance del spec.

### «Bloqueado» hace fallar la corrida

Si una herramienta te niega el fix, **eso no es una decisión de triage y no es un entregable con
nota al pie**. Un 🟡 archivado y un fix que no te dejaron aplicar se leen igual en el reporte y son
opuestos: del primero ya se decidió, del segundo no decidió nadie.

1. **Reintentá por otro camino.** Y si el bloqueo vino del hook, **mirá el nombre de tu rama antes
   que nada**: `gate_de_spec.py` exige `feature/<NNN>-` con el `NNN` en `specs/mapa.json` para
   tocar `src/` o `docs/`. Es la causa número uno de un fix bloqueado acá.
2. Si sigue bloqueado, **la corrida no cierra en verde.** El reporte arranca diciéndolo, con
   `BLOQUEADO: <qué> — <quién lo bloqueó>` y el fix exacto en una línea copiable.
3. **No lo tapes con un issue.** Eso convierte un rojo en un pendiente, que es la única operación
   que esta doctrina prohíbe.

En el batch el padre corre en el checkout principal y con otros permisos: un fix que a vos te
bloquearon, él lo aplica. Pero sólo si el reporte lo distingue.

### «Preexistente» no cubre una línea que tu diff volvió a escribir

El mismo test mecánico decide las dos caras: **si la línea aparece como `+` en tu `pr.diff`, es
tuya.** Vale para tener que arreglarlo, y en el batch vale además para atribuirlo — allá es el
reverso exacto de la cláusula 1, que usa el mismo test para mandar hacia abajo lo que no es `+`.
En un review suelto no hay «abajo», así que acá queda sólo la mitad que obliga.

Que el número lo haya vuelto falso un spec anterior no cambia nada: lo que importa es que **tu
diff lo volvió a escribir**, y una afirmación falsa re-tipeada es una afirmación que este PR
afirma. Un párrafo re-justificado cuenta como re-tipeado.

### El PR propio del hallazgo fuera de alcance

Es la descarga que reemplaza al issue, y la que sostiene las dos mediciones a la vez: el trabajo
se hace **ahora**, y el changeset del PR que estás revisando **no engorda**.

```bash
git checkout -B feature/<NNN>-<kebab-del-hallazgo> origin/staging
# el fix, verificar.py en verde, commit
gh pr create --repo federicohermo/nosefia --base staging
```

Tres cosas que no son obvias:

- **Sale de `staging`, no de la rama del PR que revisás.** Si sale de ahí, arrastra los commits de
  ese PR y no se puede mergear antes que él — que es justo lo que hace falta cuando el fix es de
  otro archivo.
- **El nombre lleva un `NNN` que el mapa tenga**, o el hook te bloquea la primera edición de
  `src/`. Si el hallazgo no tiene spec propio y toca ruta protegida, **eso ya es un hallazgo sobre
  el proceso**: correspondía un spec, y la descarga es abrirlo con `spec-create`.
- **Va al reporte con su número de PR.** Quien mergea tiene que saber que hay dos.

**Y no se abre un issue «para dejarlo anotado».** Los issues de este repo son **entrada** —lo que
`deuda.py` lista y `spec-create` drena—, nunca la forma de terminar una corrida. Un hallazgo
convertido en issue es trabajo que encontraste, entendiste y decidiste no hacer.

La única excepción es la decisión del usuario ya tomada: si te dijo que algo queda para después,
**el issue lo registra esa decisión, no tu comodidad**, y el cuerpo la cita.

**Propagá cada fix a todo lo que lo describe.** Un cambio de firma toca el código **y** el
`spec.md`, cada doc que muestre el snippet viejo, y las tareas del spec que lo nombran. Un fix de
código que deja mintiendo a la doc del propio PR es medio fix.

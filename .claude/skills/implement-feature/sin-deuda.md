# La imposibilidad de la deuda

**Los siete skills que escriben traen su copia, y la de `to-spec` es la canónica.** Un skill es la
unidad que se instala: trae su implementación completa y ninguno lee este archivo por ruta.
`test_copias_de_skills.py` da rojo si una copia difiere en un byte. `shape` y `review-spec-drift`
no la traen: no escriben nada, así que no pueden dejar deuda.

## La regla

**Una corrida no termina dejando trabajo escrito para después.** Ni en un `## Seguimiento`, ni en
un criterio que ningún test nombra, ni en un issue abierto como forma de cerrar. Lo que la corrida
encuentra, la corrida lo descarga — y descargar tiene una lista cerrada de formas.

| Los skills de… | Terminan… |
|---|---|
| **review** (`pr-review`, `pr-review-batch`) | con **todo** lo que encontraron descargado, verificado, commiteado y pusheado |
| **contrato** (`to-spec`) | con el comportamiento de la capacidad entero, en criterios cerrables por un agente. Un hueco es una `OQ-<COD>-###`, nunca un valor inventado |
| **plan** (`to-issue`) | con el issue publicado, sus límites medidos contra el árbol de hoy, y el tipo y el spec que toca declarados |
| **fichas** (`features-to-issues`) | con cada ficha 🟩 traducida a su issue, o declarada fuera del lote y por qué, y la ficha apuntando a él |
| **implementación** (`implement-feature`, `implement-batch`) | con todo lo que el issue pide hecho, el PR abierto, y un test que nombra cada criterio que entrega |

**«Descargado» no es «metido en este PR».** Dónde aterriza el fix es una decisión aparte de si se
hace, y confundirlas rompe el review.

## Dónde se apoya

Una doctrina que nadie puede verificar dura lo que dura la buena voluntad. Ésta se ancla en algo
que una herramienta lee: **cada criterio de un spec `ratified` está citado como `AC-<COD>-###` por
un test**, y lo cobra `gate_de_specs.py` en el nodo `specs`.

**El ancla cambió tres veces, y siempre por el mismo motivo.** Fue una casilla del `tasks.md`
—que desapareció con él, dejando la regla sin objeto y en verde para siempre—; después los
criterios de los specs cerrados —que llegaba tarde, con el PR ya aterrizado—; después los de la
rama. **Un gate que no puede fallar no es laxo: es un gate apagado que parece encendido.**

**El ancla de hoy es más fuerte que la casilla que empezó reemplazando.** Una casilla la marca a
mano el mismo que decide si el trabajo está hecho. Un test lo tiene que escribir alguien, corre en
cada push y **se rompe solo** cuando el código deja de cumplirlo.

**La cita lleva el código de la capacidad** —`AC-EMP-004`, no `AC4`—: con la cita pelada el primer
test dejaría cubiertos a los demás para siempre.

**Su techo, dicho:** el gate verifica la **cita**, no que el test ejerza el criterio. Es un piso,
y lo que lo levanta es la disciplina de siempre: el test se escribe primero y se lo ve fallar.

## Las cinco descargas, y no hay una sexta

Todo hallazgo, toda duda y todo bloqueo sale por una de estas cinco. Si tu motivo para no aplicar
un fix no es una de ellas, **no hay motivo y el fix se aplica**.

**El destino tiene libertad cero: «después» no existe. El camino tiene libertad alta: cuál de las
cinco es tuya.**

1. **Arreglado.** Se aplicó, `verificar.py` quedó verde, está commiteado y pusheado. Es el default
   y no necesita justificarse.

   **Y aterriza donde le corresponde, que no siempre es el PR que estás revisando.** Está medido:
   la detección de defectos de un review cae de **87 % con menos de 100 líneas a 28 % con más de
   1000**. Un review que absorbe cada fix degrada su propia revisión.

   | El fix es… | Aterriza en |
   |---|---|
   | de una línea que tu diff agrega o reescribe | **este PR** |
   | del mismo archivo y del alcance del issue | **este PR** |
   | de otro archivo, o fuera del alcance | **su propio PR**, abierto en esta corrida |
   | del comportamiento y no del código | **el spec de la capacidad** — descarga 2 |

   Las dos últimas filas **no aplazan nada**: el trabajo se hace ahora, en su propio changeset.

2. **Corregido aguas arriba, ahora.** El hallazgo era del contrato. Un fix que pelea con un
   criterio significa que **el criterio está mal**, y se corrige en esta corrida, en el mismo PR.

   **Y nunca al revés: el spec no se ajusta para que coincida con el código.** Si el código no
   cumple un criterio, se corrige el código. Si el criterio ya no describe el juego, eso es una
   decisión de diseño y va por la descarga 4.

3. **Corregido el skill que lo permitió.** Ver «el lazo». Es la descarga que hace que la segunda
   corrida no repita el hallazgo de la primera.

4. **Decidido por el usuario, ahora, y bloqueando.** Para lo que es una **decisión** y no una
   verificación: un costo que corta para los dos lados, o una regla que el GDD no fija.

   **Acá vive el `won't fix`, y es legítimo**: la política de cero bugs no dice «arreglá todo»,
   dice **«arreglalo ahora o cerralo ahora»**. Cerrar con la respuesta escrita es descargar;
   dejarlo abierto «para ver» no lo es.

   La marca de que es una pregunta legítima: **ninguna medición la contesta.** Si un `rg` de cinco
   segundos la cierra, no era una pregunta, era pereza.

5. **La corrida falló.** Una herramienta negó la escritura y no hubo camino. **No es un entregable
   con una nota al pie: es un rojo.**

## El modo de falla de esta doctrina es el silencio, no la deuda

Es el precio y es real: **una corrida obligada a arreglar todo, frente a algo que no puede
arreglar, tiene presión para no encontrarlo.** «Cero hallazgos» y «cero hallazgos reportados» se
leen igual y son opuestos.

Por eso la descarga 5 es tan válida como la 1. **Una corrida que para y dice «bloqueado, acá está
el fix exacto» cumplió la doctrina.** La única que la incumple es la que reporta verde con algo
sin arreglar — y ésa incluye a la que no miró para no tener que arreglar.

Un bloqueo se descarga así:

1. **Reintentá por otro camino.** Si vino del hook, **mirá el nombre de tu rama antes que nada**:
   `gate_de_rama.py` sólo deja escribir en `src/` desde los prefijos que su mensaje nombra. Es
   la causa número uno, y el síntoma —un `Edit` denegado— se lee como un problema de
   permisos y no de nombre.
2. Si sigue bloqueado, **la corrida no cierra en verde**: el reporte arranca con
   `BLOQUEADO: <qué> — <quién>` y el fix exacto en una línea copiable.
3. **No se abre un issue para taparlo.** Eso convierte un rojo en un pendiente, que es la
   operación que esta doctrina prohíbe.

## Los issues son plan, no vertedero

Un issue es el **plan chico y descartable de un cambio puntual**, con la forma de
`.github/ISSUE_TEMPLATE/task-brief.md`. Legítimo: un pedido que llega de afuera, una
funcionalidad que se va a cambiar, un bug reportado. **No legítimo:** abrir uno como forma de terminar. Un hallazgo
convertido en issue es trabajo que la corrida encontró, entendió y decidió no hacer.

La única excepción es la descarga 4 con la respuesta ya dada: **el issue lo registra la decisión
del usuario, no la comodidad tuya**.

## El lazo: si implementar duele, el problema está aguas arriba

Las dudas se resuelven al escribir el contrato y al repartirlo. **Cuando la implementación
encuentra un problema de planteo, ese problema es del skill que lo dejó salir así.** Se corrigen
los dos en la misma corrida, y el `SKILL.md` corregido va al reporte como sección propia: es el
entregable más caro y el único que hace que el hallazgo no vuelva.

| Lo que apareció | Qué skill se corrige |
|---|---|
| un criterio que no se puede ver fallar | `to-spec` |
| una regla del juego ubicada en `ui/` o en `escenas/` | `to-spec` — el eje de capas se escribió tarde |
| un criterio que **barre un directorio y enumera excepciones** sin haber corrido el barrido | `to-spec` — de memoria sale corta y el criterio nace imposible de pasar |
| un identificador que el spec escribe en `código` y que no existe en el repo | `to-spec` — se escribió la prosa sin grepearla |
| un spec que nombra un archivo o una clase | `to-spec` — caduca con el refactor siguiente |
| un issue sin límites de archivo, o con límites que no se cruzaron contra el árbol de hoy | `to-issue` |
| dos issues que se pisan la misma escena | `to-issue` — un `.tscn` compartido se ordena, no se paraleliza |
| un issue que cambia lo que el juego hace y declara «Spec: ninguno» | `to-issue` — el tipo se decidió sin la prueba del spec |
| una ficha verde de Notion que se cayó del lote sin motivo escrito | `features-to-issues` — el reparto no se mostró entero |
| un nodo del harness en verde sin haber ejercido nada | `implement-feature` — se leyó el color del nodo y no el conteo |
| dos carriles que se pisan un archivo de scratch | `implement-batch` — el prompt no le dio un nombre propio |
| un worktree que quedó abierto y el limpiador dijo que no | `implement-batch` — salía de `git worktree list`, que no ve al que git ya soltó |
| un número que el contrato midió bien y que **envejeció** | `implement-batch` — se leyó la base que el issue declara en vez de medir hoy |
| **varios carriles pisando el mismo comando que el skill les dio escrito** | `implement-batch` — un comando se vuelve a correr antes de repartirlo, no se copia |

**Si el problema no entra en ninguna fila, agregá la fila.** Esa tabla es el registro de lo que
esta doctrina ya aprendió, y está incompleta a propósito.

## Lo que NO es deuda

- **Un `## No objetivos`.** Es una frontera, y es lo que vuelve revisable al spec. La prueba de
  que se volvió deuda: **¿algún criterio de este spec depende de eso?**
- **Una `OQ-<COD>-###`.** Es un hueco declarado, con quién lo decide. Deuda sería inventarle un
  valor por defecto.
- **Un spec `draft` con criterios sin test.** Es la cola, y el gate cuenta cuántos faltan en cada
  corrida. Deuda sería un `ratified` que miente.
- **Un issue abierto que todavía no se implementó.** Es el plan.

## Contra qué se contrastó

| Pieza | De dónde sale |
|---|---|
| el contrato dura y el código contesta a él | **spec-anchored agentic development** |
| la corrida para en vez de aplazar | **stop-the-line / andon**, del Toyota Production System |
| arreglar ahora o cerrar ahora, sin backlog | la **Zero Bug Policy** |
| gate en vez de prosa | **poka-yoke** |
| no hay «terminado con asterisco» | **Definition of Done** |
| las dudas se resuelven antes de implementar | **shift-left** |
| cada criterio se tiene que poder ver fallar | la **T de INVEST** |
| el issue declara su radio de escritura y sus comandos | el **task-brief** de ITBAF |
| el fix fuera de alcance va a su propio PR | los **datos de tamaño de PR**: 87 % → 28 % |
| la deuda deliberada la decide el usuario | el **cuadrante de Fowler** |

**Y una convención mayoritaria que este repo rechaza a propósito:** Google recomienda dejar un
`TODO` con su bug para lo que queda fuera de alcance. Acá ya se falsó con datos locales — **137
casillas «lo mira una persona» en 35 specs, 6 cerradas alguna vez**.

## Qué verifica una herramienta y qué no

| Regla | Quién |
|---|---|
| Cada criterio de un spec `ratified`, citado por un test | `gate_de_specs.py` |
| Ningún `spec.md`, `research.md`, `plan.md` ni `tasks.md` | `gate_de_specs.py` |
| Cada criterio nombra una regla que su spec declara, y ningún ID repetido | `gate_de_specs.py` |
| Que ese test **ejerza** el criterio y no sólo lo nombre | **prosa** |
| Que un `## No objetivos` no esconda un criterio propio | **prosa** — lo mira el review |
| Que el skill se haya corregido cuando el lazo lo pedía | **prosa** — lo mira el reporte |
| Que un hallazgo no se haya callado para no tener que arreglarlo | **prosa, y no hay forma de verificarlo** |

Las tres últimas son el techo que esta doctrina no alcanza, y decirlo es parte de sostenerla:
**el gate es un piso.**

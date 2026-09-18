# La imposibilidad de la deuda

**Los seis skills que escriben traen su copia, y la de `to-spec` es la canónica.** `shape` y
`review-spec-drift` no la traen: no escriben nada, así que no pueden dejar deuda. Un skill es la unidad
que se instala y se distribuye, así que trae su implementación completa: ninguno lee este archivo
por ruta. `test_copias_de_skills.py` da rojo si alguna copia difiere de la canónica en un byte,
así que editar una suelta **no se puede mergear** — se edita la de `to-spec` y se propaga.

**Cuál de las seis es la canónica es arbitrario**, y por eso está declarado en `COPIAS` y no en
el nombre de una carpeta.

## La regla

**Una corrida no termina dejando trabajo escrito para después.** Ni en un `## Seguimiento`, ni en
un criterio que ningún test nombra, ni en un issue abierto como forma de cerrar, ni en un «esto
habría que verlo». Lo que la corrida encuentra, la corrida lo descarga — y descargar tiene una
lista cerrada de formas.

| Los skills de… | Terminan… |
|---|---|
| **review** (`pr-review`, `pr-review-batch`) | con **todo** lo que encontraron descargado, verificado, commiteado y pusheado. El reporte cuenta lo hecho, no lo que queda |
| **contrato** (`to-spec`) | con el comportamiento de la capacidad entero, en reglas y criterios cerrables por un agente. Un hueco es una `OQ-<COD>-###`, nunca un valor inventado |
| **reparto** (`spec-to-tickets`) | con cada criterio del contrato asignado a un issue, o declarado fuera del lote y por qué |
| **implementación** (`implement-feature`, `implement-batch`) | con **todo** lo que el issue pide hecho, el PR abierto, y un test que nombra cada criterio que entrega |

**«Descargado» no es «metido en este PR».** Ver la descarga 1: dónde aterriza el fix es una
decisión aparte de si se hace, y confundirlas rompe el review.

## Dónde se apoya

Una doctrina que nadie puede verificar dura lo que dura la buena voluntad, así que ésta se ancla
en algo que una herramienta lee: **cada criterio de un spec `ratified` está citado como
`AC-<COD>-###` por un test**, y lo cobra `gate_de_specs.py` en el nodo `specs` de `verificar.py`.

**El ancla cambió tres veces, y siempre por el mismo motivo.**

| Cuándo | El ancla | Por qué se fue |
|---|---|---|
| mientras hubo `tasks.md` | un spec implementado no podía tener una casilla abierta | el `tasks.md` desapareció, y la regla se quedó sin objeto |
| sobre los specs cerrados | cada criterio citado como `NNN-ACn` | llegaba tarde: el PR ya había aterrizado |
| sobre la rama | los criterios del spec de la rama | el spec dejó de ser por tarea: ahora es por capacidad y dura |
| **hoy** | **cada criterio de un spec `ratified`, citado por un test** | — |

Ninguno de los cambios es cosmético. Cuando el `tasks.md` desapareció, la regla vieja siguió
escrita, no encontró ninguna casilla y salía verde para siempre: **un gate que no puede fallar no
es un gate laxo, es un gate apagado que parece encendido**.

**El ancla nueva es más fuerte que la casilla que empezó reemplazando.** Una casilla la marca a
mano el mismo que decide si el trabajo está hecho, así que verifica una afirmación contra sí
misma. Un test que nombra el criterio lo tiene que escribir alguien, corre en cada push y **se
rompe solo** cuando el código deja de cumplirlo.

**La cita lleva el código de la capacidad** —`AC-EMP-004`, no `AC4`— y eso no es formato: `AC4`
es el nombre que usaría todo spec, así que con la cita pelada el primer test dejaría cubiertos a
los demás para siempre.

**Su techo, dicho:** el gate verifica la **cita**, no que el test ejerza el criterio. Es un piso
—como todo lo que este repo verifica sin cobertura— y lo que lo levanta es la disciplina de
siempre: el test se escribe primero y se lo ve fallar.

## Las cinco descargas, y no hay una sexta

Todo hallazgo, toda duda y todo bloqueo sale por una de estas cinco. Si tu motivo para no aplicar
un fix no es una de ellas, **no hay motivo y el fix se aplica**.

**El destino tiene libertad cero: «después» no existe. El camino tiene libertad alta: cuál de las
cinco es tuya.**

1. **Arreglado.** Se aplicó, `verificar.py` quedó verde, está commiteado y pusheado. Es el
   default y no necesita justificarse.

   **Y aterriza donde le corresponde, que no siempre es el PR que estás revisando.** Está medido:
   la tasa de detección de defectos de un review cae de **87 % con menos de 100 líneas a 28 % con
   más de 1000**. Un review que absorbe cada fix engorda el PR que está revisando y degrada su
   propia revisión.

   | El fix es… | Aterriza en |
   |---|---|
   | de una línea que tu diff agrega o reescribe | **este PR** |
   | del mismo archivo y del alcance del issue | **este PR** |
   | de otro archivo, o fuera del alcance del issue | **su propio PR**, abierto en esta corrida |
   | del comportamiento y no del código | **el spec de la capacidad** — descarga 2 |

   Las dos últimas filas **no aplazan nada**: el trabajo se hace ahora, en su propio changeset.

2. **Corregido aguas arriba, ahora.** El hallazgo no era del código: era del contrato. Un fix que
   pelea con un criterio de aceptación significa que **el criterio está mal**, y se corrige en
   esta corrida, en `specs/<capability>/<capability>.md`, en el mismo PR.

   **Y nunca al revés: el spec no se ajusta para que coincida con el código.** Si el código no
   cumple un criterio, lo que se corrige es el código. Si el criterio ya no describe lo que el
   juego tiene que hacer, eso es una decisión de diseño y va por la descarga 4.

3. **Corregido el skill que lo permitió.** Ver «el lazo», abajo. Es la descarga que hace que la
   segunda corrida no repita el hallazgo de la primera.

4. **Decidido por el usuario, ahora, y bloqueando.** Para lo que es una **decisión** y no una
   verificación: un costo que corta para los dos lados, o una regla del juego que el GDD no fija.
   Se pregunta en el momento, no se archiva.

   **Acá vive el `won't fix`, y es una descarga legítima**: la política de cero bugs de la que
   sale todo esto no dice «arreglá todo», dice **«arreglalo ahora o cerralo ahora»**. Cerrar con
   la respuesta del usuario escrita es descargar; dejarlo abierto «para ver» no lo es.

   La marca de que es una pregunta legítima: **ninguna medición la contesta.** Si un `rg` de cinco
   segundos la cierra, no era una pregunta, era pereza.

5. **La corrida falló.** Una herramienta negó la escritura y no hubo camino. **No es un entregable
   con una nota al pie: es un rojo.** Ver abajo.

## El modo de falla de esta doctrina es el silencio, no la deuda

Hay que decirlo porque es el precio y es real: **una corrida obligada a arreglar todo, frente a
algo que no puede arreglar, tiene presión para no encontrarlo.** «Cero hallazgos» y «cero
hallazgos reportados» se leen igual y son opuestos.

Por eso la descarga 5 es tan válida como la 1. **Una corrida que para y dice «bloqueado, acá está
el fix exacto» cumplió la doctrina.** La única que la incumple es la que reporta verde con algo
sin arreglar — y ésa incluye a la que no miró para no tener que arreglar.

Un bloqueo se descarga así:

1. **Reintentá por otro camino.** Si el bloqueo vino del hook, **mirá el nombre de tu rama antes
   que nada**: `gate_de_rama.py` sólo deja escribir en `src/` desde `feature/<issue>-<kebab>`,
   `bugfix/` o `hotfix/`. Es la causa número uno acá, y el síntoma —un `Edit` denegado— se lee
   como un problema de permisos y no como uno de nombre.
2. Si sigue bloqueado, **la corrida no cierra en verde**. El reporte arranca diciendo que falló,
   con `BLOQUEADO: <qué> — <quién lo bloqueó>` y el fix exacto en una línea copiable.
3. **No se abre un issue para taparlo.** Un issue acá convierte un rojo en un pendiente, que es
   precisamente la operación que esta doctrina prohíbe.

## Los issues son plan, no vertedero

Este repo planifica en GitHub Issues, y un issue es el **único** plan de una unidad de trabajo:
su forma está en `specs/_template/task-brief.md`. Eso no lo convierte en un lugar donde dejar
cosas.

- **Legítimo:** un pedido que llega de afuera entra como issue; `spec-to-tickets` reparte el
  contrato de una capacidad en issues; un bug reportado es un issue.
- **No legítimo:** ningún skill abre un issue **como forma de terminar**. «Lo dejo anotado» no es
  una descarga. Un hallazgo convertido en issue es trabajo que la corrida encontró, entendió y
  decidió no hacer.

La única excepción es la descarga 4 con la respuesta ya dada: si el usuario decide que algo queda
para después, **el issue lo registra la decisión de él, no la comodidad tuya**.

## El lazo: si implementar duele, el problema está aguas arriba

**Las dudas de implementación se resuelven al escribir el contrato y al repartirlo.** Para cuando
`implement-feature` arranca, ya no debería quedar ninguna.

Entonces, **cuando la implementación encuentra un problema de planteo, ese problema no es del
issue que estás implementando: es del skill que lo dejó salir así.** La descarga tiene dos
mitades, las dos en la misma corrida: el contrato o el issue se corrigen, y **el `SKILL.md` que lo
permitió se corrige también**, con la regla que lo habría atajado. Va al reporte como sección
propia, porque es el entregable más caro de la corrida y el único que hace que el hallazgo no
vuelva.

| Lo que apareció implementando | Qué skill se corrige |
|---|---|
| un criterio que no se puede ver fallar | `to-spec` — la regla de falsabilidad no alcanzó |
| una regla del juego ubicada en `ui/` o en `escenas/` | `to-spec` — el eje de capas se escribió tarde |
| un criterio que **barre un directorio y enumera sus excepciones** sin haber corrido el barrido | `to-spec` — la lista se escribió de memoria, así que sale corta y el criterio nace imposible de pasar |
| un identificador que el spec escribe en `código` y que no existe en el repo | `to-spec` — se escribió la prosa sin grepearla contra `src/` |
| un spec que nombra un archivo o una clase | `to-spec` — eso caduca con el refactor siguiente y el contrato deja de ser el contrato |
| un issue sin límites de archivo, o con límites que no se cruzaron contra el árbol de hoy | `spec-to-tickets` — la tabla se escribió sin mirar qué toca de verdad |
| dos issues que se pisan la misma escena | `spec-to-tickets` — un `.tscn` compartido se ordena, no se paraleliza |
| una frontera que un issue le pasa a otro y que el otro **no recoge** | `spec-to-tickets` — el reparto dejó un criterio sin dueño |
| un nodo del harness en verde sin haber ejercido nada | `implement-feature` — la condición de terminado leyó el color del nodo y no el conteo de lo que corrió |
| dos carriles que se pisan un archivo de scratch | `implement-batch` — el prompt del carril no le dio un nombre propio |
| un worktree que quedó abierto y el limpiador dijo que no | `implement-batch` — el paso de limpieza salía de `git worktree list`, que no ve al que git ya soltó |
| un número que el contrato midió bien y que **envejeció** entre que se escribió y que se implementó | `implement-batch` — se leyó la base que el issue declara en vez de medir el árbol de hoy |
| **varios carriles pisando el mismo comando que el skill les dio escrito** | `implement-batch` — un comando que el preámbulo entrega no se copia de la corrida anterior: se vuelve a correr antes de repartirlo |

**Si el problema no entra en ninguna fila, agregá la fila.** Esa tabla es el registro de lo que
esta doctrina ya aprendió, y está incompleta a propósito.

## Lo que NO es deuda

La doctrina se apaga sola si empieza a comerse cosas legítimas. Estas cuatro no lo son:

- **Un `## No objetivos` en un spec.** Es una **frontera**, no una promesa: dice qué no hace esta
  capacidad, y por eso la hace revisable. La prueba de que se convirtió en deuda es una sola:
  **¿algún criterio de este spec depende de eso?** Si sí, entra al spec. Ningún gate puede decidir
  esto — lo mira el review.
- **Una `OQ-<COD>-###`.** Es un hueco declarado, con quién lo decide y qué bloquea. Deuda sería
  inventarle un valor por defecto.
- **Un spec `draft` con criterios sin test.** Es la cola de trabajo, y el gate cuenta cuántos
  faltan en cada corrida. Deuda sería un `ratified` que miente.
- **Un issue abierto que todavía no se implementó.** Es el plan.

## Contra qué se contrastó esto

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
| el fix fuera de alcance va a su propio PR | los **datos de tamaño de PR**: 87 % → 28 % de detección |
| la deuda deliberada la decide el usuario | el **cuadrante de Fowler** |

**Y una convención mayoritaria que este repo rechaza a propósito:** Google recomienda dejar un
`TODO` con su bug para lo que queda fuera de alcance. Acá eso ya se falsó con datos locales —
**137 casillas «lo mira una persona» en 35 specs, 6 cerradas alguna vez**. Evidencia propia le
gana a una convención general.

## Qué verifica una herramienta y qué no

| Regla | Quién la verifica |
|---|---|
| Cada criterio de un spec `ratified`, citado por un test | `gate_de_specs.py` |
| Ningún `spec.md`, `research.md`, `plan.md` ni `tasks.md` | `gate_de_specs.py` |
| Cada criterio nombra una regla que su spec declara | `gate_de_specs.py` |
| Un código de capacidad por capacidad, y ningún ID repetido | `gate_de_specs.py` |
| Que ese test **ejerza** el criterio y no sólo lo nombre | **prosa** — el gate verifica la cita |
| Que un `## No objetivos` no esconda un criterio propio | **prosa** — lo mira el review |
| Que el skill se haya corregido cuando el lazo lo pedía | **prosa** — lo mira el reporte |
| Que un hallazgo no se haya callado para no tener que arreglarlo | **prosa, y no hay forma de verificarlo** |

Las tres últimas filas son el techo que esta doctrina no alcanza, y decirlo es parte de
sostenerla: **el gate es un piso.**

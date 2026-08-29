# La imposibilidad de la deuda

**Ésta es la copia canónica, y los ocho skills traen la suya.** Un skill es la unidad que se
instala y se distribuye, así que trae su implementación completa: ninguno lee este archivo por
ruta. `test_copias_de_skills.py` da rojo si alguna copia difiere de ésta en un byte, así que
editarla acá y no propagar **no se puede mergear**.

**Vive en `.claude/doctrina/` y no en `.claude/skills/`** porque ahí adentro todo es un skill —un
directorio con su `SKILL.md`— y un `.md` suelto entre ellos no lo es: no aparece en la lista de
skills invocables y se lee como uno a medio hacer. Tampoco es un `CLAUDE.md`, que se cargaría al
editar esta carpeta —el meta-trabajo— y no al correr un review sobre `src/`.

## La regla

**Una corrida no termina dejando trabajo escrito para después.** Ni en un `## Seguimiento`, ni
en una casilla sin marcar, ni en un issue abierto como forma de cerrar, ni en un «esto habría
que verlo». Lo que la corrida encuentra, la corrida lo descarga — y descargar tiene una lista
cerrada de formas.

Por familia:

| Los skills de… | Terminan… |
|---|---|
| **review** (`pr-review`, `pr-review-batch`, `spec-review`, `spec-review-batch`) | con **todo** lo que encontraron descargado, verificado, commiteado y pusheado. El reporte cuenta lo hecho, no lo que queda |
| **creación** (`spec-create`, `spec-create-batch`) | con la **totalidad** de las tareas que la especificación necesita, todas cerrables por un agente. Ningún seguimiento, ningún punto a cubrir después, ninguna casilla que espere a una persona |
| **implementación** (`spec-implement`, `spec-implement-batch`) | con **todas** las tareas del spec hechas y marcadas, las marcas devueltas al issue, y el PR abierto |

**«Descargado» no es «metido en este PR».** Ver la descarga 1: dónde aterriza el fix es una
decisión aparte de si se hace, y confundirlas rompe el review. La doctrina obliga a lo primero y
no dice nada sobre lo segundo.

## Las cinco descargas, y no hay una sexta

Todo hallazgo, toda duda y todo bloqueo sale por una de estas cinco. Si tu motivo para no
aplicar un fix no es una de ellas, **no hay motivo y el fix se aplica**.

**El destino tiene libertad cero: «después» no existe. El camino tiene libertad alta: cuál de las
cinco es tuya.**

1. **Arreglado.** Se aplicó, `verificar.py` quedó verde, está commiteado y pusheado. Es el
   default y no necesita justificarse.

   **Y aterriza donde le corresponde, que no siempre es el PR que estás revisando.** Está
   medido, y en contra de la intuición: la tasa de detección de defectos de un review cae de
   **87 % con menos de 100 líneas a 28 % con más de 1000**. Un review que absorbe cada fix
   engorda el PR que está revisando y **degrada su propia revisión**; además rompe la
   atomicidad, y revertir o bisecar dejan de servir.

   | El fix es… | Aterriza en |
   |---|---|
   | de una línea que tu diff agrega o reescribe | **este PR** |
   | del mismo archivo y del alcance del spec | **este PR** |
   | de otro archivo, o fuera del alcance del spec | **su propio PR**, abierto en esta corrida |
   | del planteo y no del código | **el `spec.md`** — descarga 2 |

   Las dos últimas filas **no aplazan nada**: el trabajo se hace ahora, sólo que en su propio
   changeset.

2. **Corregido aguas arriba, ahora.** El hallazgo no era del código: era del spec. Un fix que
   pelea con un criterio de aceptación no significa «no lo toco» — significa que **el AC está
   mal** y se corrige en esta corrida, en el `spec.md`, y se devuelve al issue con
   `publicar_spec.py publicar`. Un fix que pediría un rediseño más grande que el PR significa
   que **el alcance del spec estaba mal medido**, y se corrige igual.

3. **Corregido el skill que lo permitió.** Ver «el lazo», abajo. Es la descarga que hace que la
   segunda corrida no repita el hallazgo de la primera.

4. **Decidido por el usuario, ahora, y bloqueando.** Para lo que es una **decisión** y no una
   verificación: un costo que corta para los dos lados, una regla del juego que el GDD no fija,
   o una deuda que conviene tomar a propósito. Se pregunta en el momento, no se archiva.

   **Acá vive el `won't fix`, y es una descarga legítima**: la política de cero bugs de la que
   sale todo esto no dice «arreglá todo», dice **«arreglalo ahora o cerralo ahora»**, y su
   honestidad está en el cerrar explícito. Cerrar con la respuesta del usuario escrita es
   descargar; dejarlo abierto «para ver» no lo es.

   La marca de que es una pregunta legítima: **ninguna medición la contesta.** Si un `rg` de
   cinco segundos la cierra, no era una pregunta, era pereza.

5. **La corrida falló.** Una herramienta negó la escritura y no hubo camino. **No es un
   entregable con una nota al pie: es un rojo.** Ver abajo.

## El modo de falla de esta doctrina es el silencio, no la deuda

Hay que decirlo porque es el precio y es real: **una corrida obligada a arreglar todo, frente a
algo que no puede arreglar, tiene presión para no encontrarlo.** «Cero hallazgos» y «cero
hallazgos reportados» se leen igual y son opuestos, igual que un 🟡 archivado y un fix que no te
dejaron aplicar.

Por eso la descarga 5 es tan válida como la 1. **Una corrida que para y dice «bloqueado, acá está
el fix exacto» cumplió la doctrina.** La única que la incumple es la que reporta verde con algo
sin arreglar — y ésa incluye a la que no miró para no tener que arreglar.

Un bloqueo se descarga así:

1. **Reintentá por otro camino.** Si el bloqueo vino del hook, **mirá el nombre de tu rama antes
   que nada**: `gate_de_spec.py` exige `feature/<NNN>-` con ese `NNN` en `specs/mapa.json` para
   escribir en `src/` o `docs/`. Es la causa número uno acá, y el síntoma —un `Edit` denegado— se
   lee como un problema de permisos y no como uno de nombre.
2. Si sigue bloqueado, **la corrida no cierra en verde**. El reporte arranca diciendo que falló,
   con `BLOQUEADO: <qué> — <quién lo bloqueó>` y el fix exacto en una línea copiable.
3. **No se abre un issue para taparlo.** Un issue acá convierte un rojo en un pendiente, que es
   precisamente la operación que esta doctrina prohíbe.

## Los issues son entrada, nunca salida

Este repo registra en GitHub Issues, y eso no cambia. Lo que cambia es la dirección:

- **Entrada:** un pedido que llega de afuera —del usuario, de una observación, de algo que se
  rompió— entra como issue. `python .claude/scripts/deuda.py` los lista, y `spec-create` los drena
  hacia specs. Ahí el issue es la bandeja de entrada del repo y está bien que exista.
- **Salida:** ningún skill abre un issue **como forma de terminar**. «Lo dejo anotado» no es una
  descarga. Un hallazgo que se convierte en issue es trabajo que la corrida encontró, entendió,
  y decidió no hacer.

La única excepción es la descarga 4 con la respuesta ya dada: si el usuario decide que algo queda
para después, **el issue lo registra la decisión de él, no la comodidad tuya**.

## El lazo: si implementar duele, el problema está aguas arriba

**Las dudas de implementación se resuelven entre la creación del spec y su review.** Para cuando
`spec-implement` arranca, ya no debería quedar ninguna: el spec dice qué hacer, en qué capa, con
qué AC falsable y con qué tareas.

Entonces, **cuando la implementación encuentra un problema de planteo, ese problema no es del
spec que estás implementando: es del skill que lo dejó salir así.** La descarga tiene dos mitades,
las dos en la misma corrida:

1. **El spec se corrige** para poder seguir —descarga 2—, y se devuelve al issue.
2. **El `SKILL.md` que lo permitió se corrige también**, con la regla que lo habría atajado. Va
   en el reporte como sección propia, porque es el entregable más caro de la corrida: es lo único
   que hace que el hallazgo no vuelva.

| Lo que apareció implementando | Qué skill se corrige |
|---|---|
| un AC que no se puede ver fallar | `spec-create` — la regla de falsabilidad no alcanzó |
| una tarea que no dice qué archivo toca | `spec-create` — el reparto de un lote no es revisable sin eso |
| una regla del juego ubicada en `ui/` o en `escenas/` | `spec-create` — el eje de capas se escribió tarde |
| un `[P]` que resultó falso | `spec-review` — el cruce de archivos no lo cazó |
| dos specs que se pisan la misma escena | `spec-review-batch` — la matriz no marcó el `.tscn` |
| una medición que el spec supuso en vez de correr | `spec-create` — el research salió sin número |

**Si el problema no entra en ninguna fila, agregá la fila.** Esa tabla es el registro de lo que
esta doctrina ya aprendió, y está incompleta a propósito.

## Lo que NO es deuda

La doctrina se apaga sola si empieza a comerse cosas legítimas. Estas cinco no lo son:

- **`## Fuera de alcance` en un `spec.md`.** Es una **frontera**, no una promesa: dice qué no hace
  este spec, y por eso lo hace revisable. La prueba de que se convirtió en deuda es una sola:
  **¿algún AC de este spec depende de eso?** Si sí, es deuda con sombrero y entra al spec. Si no,
  es una frontera y se queda. Ningún gate puede decidir esto — lo mira el review.
- **Un spec `Propuesto` que todavía no se implementó.** Es trabajo planificado, con estado propio
  y su issue. No es deuda: es la cola.
- **Un issue que llegó de afuera.** Es entrada. Ver arriba.
- **Una medición declarada con su número**, aunque el número sea incómodo. Deuda es la medición
  declarada como pendiente.
- **Un `## Riesgos`.** Analiza lo que podría pasar; no promete trabajo.

## Contra qué se contrastó esto

Una política que se impone sin decir contra qué se midió es exactamente lo que este repo evita en
todo lo demás. Lo que la sostiene, y lo que la limita:

| Pieza | De dónde sale |
|---|---|
| la corrida para en vez de aplazar | **stop-the-line / andon**, del Toyota Production System |
| arreglar ahora o cerrar ahora, sin backlog | la **Zero Bug Policy**, practicada y escrita |
| gate en vez de prosa | **poka-yoke** |
| no hay «terminado con asterisco» | **Definition of Done** |
| las dudas se resuelven antes de implementar | **shift-left** |
| cada AC se tiene que poder ver fallar | la **T de INVEST** |
| el fix fuera de alcance va a su propio PR | los **datos de tamaño de PR**: 87 % → 28 % de detección |
| la deuda deliberada la decide el usuario | el **cuadrante de Fowler**: deliberada y prudente es legítima |

**Y una convención mayoritaria que este repo rechaza a propósito:** Google recomienda dejar un
`TODO` con su bug para lo que queda fuera de alcance. Acá eso ya se falsó con datos locales — **137
casillas «lo mira una persona» en 35 specs, 6 cerradas alguna vez**. Evidencia propia le gana a una
convención general, y por eso el marcador no existe.

## Qué verifica una herramienta y qué no

Como en todo el repo, la mitad de esto es ejecutable y la otra mitad es prosa, y hay que saber
cuál es cuál:

| Regla | Quién la verifica |
|---|---|
| Ningún `## Seguimiento` ni sección de aplazamiento en los cuatro archivos | `test_convencion_de_specs.py` |
| Ninguna tarea que se cierre mirando, escuchando o sacando una captura | `test_convencion_de_specs.py` |
| Ninguna tarea que aplace por texto (`TODO`, `pendiente`, `más adelante`, `por ahora`) | `test_convencion_de_specs.py` |
| Ningún `research.md` con una medición declarada como no hecha | `test_convencion_de_specs.py` |
| **Un spec `Implementado` no puede tener una casilla abierta** | `test_convencion_de_specs.py` |
| Que un `## Fuera de alcance` no esconda un AC propio | **prosa** — lo mira el review |
| Que el skill se haya corregido cuando el lazo lo pedía | **prosa** — lo mira el reporte |
| Que un hallazgo no se haya callado para no tener que arreglarlo | **prosa, y no hay forma de verificarlo** |

Las tres últimas filas son el techo que esta doctrina no alcanza, y decirlo es parte de
sostenerla: **el gate es un piso.** Corre sobre los specs **hidratados**, así que sobre un árbol
sin hidratar se saltea declarándolo — y un nodo salteado no es un nodo verde.

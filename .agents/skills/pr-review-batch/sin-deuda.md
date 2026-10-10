# La imposibilidad de la deuda

**Cada skill que escribe trae su copia, y la de `to-spec` es la canónica.** Un skill es la
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
| una entrega física sin destino de productos o ticket al vencer | `to-issue` y `to-spec` — distinguir venta de vencimiento y resolver cada objeto con el usuario |
| una animación que confunde tasa del video con duración de los dibujos | `to-issue` y `to-spec` — verificar los PNG disponibles y registrar el ritmo decidido |
| un marco de Figma aparentemente vacío con texto en capas hermanas superpuestas | `to-issue` — inspeccionar la página y las coordenadas de las capas antes de declarar ausente el diseño |
| una regla del juego ubicada en `ui/` o en `escenas/` | `to-spec` — el eje de capas se escribió tarde |
| una medición corrida en el proceso equivocado | `to-spec` — lo que el motor soporta se midió en el editor y no en el juego: el editor contestó que sí y el juego que no |
| un criterio que **barre un directorio y enumera excepciones** sin haber corrido el barrido | `to-spec` — de memoria sale corta y el criterio nace imposible de pasar |
| un identificador que el spec escribe en `código` y que no existe en el repo | `to-spec` — se escribió la prosa sin grepearla |
| un spec que nombra un archivo o una clase | `to-spec` — caduca con el refactor siguiente |
| una tabla de valores que **no cierra consigo misma** —dos filas que implican duraciones distintas, o una hora de cierre que no es la apertura más la duración— | `to-spec` y `to-issue` — cada fila se recalcula desde la regla antes de escribirla, y las dos puntas se derivan, no se copian de la ficha |
| un issue sin límites de archivo, o con límites que no se cruzaron contra el árbol de hoy | `to-issue` |
| un archivo en «Sólo lectura» que **nombra por ruta** algo que el issue deja renombrar | `to-issue` — el `rg` de los límites se corre también sobre los comentarios |
| un comentario o un test fuera de «Se escribe» que **explica o arma la regla que el issue cambia** | `to-issue` — el `rg` de los límites busca la regla vieja en palabras, no sólo sus símbolos |
| dos issues que se pisan la misma escena | `to-issue` — un `.tscn` compartido se ordena, no se paraleliza |
| un criterio de bug que pide un rojo que en sus propias condiciones no aparece | `to-issue` — el síntoma se midió con el caso que el criterio excluye adentro |
| un criterio de rendimiento medido desde una vista donde **lo que el cambio agrega no se ve** | `to-issue` — el criterio no dijo desde dónde se mide, y lo que no se ve puede no costar nada |
| un issue que cambia lo que el juego hace y declara «Spec: ninguno» | `to-issue` — el tipo se decidió sin la prueba del spec |
| un issue que escribe a disco sin decir cómo lo aíslan los tests | `to-issue` — las suites que levantan la escena escriben la carpeta del usuario, y ningún gate lo ve |
| un criterio de un issue que contradice un criterio `ratified` de otra capacidad | `to-issue` — el `rg` de los límites no buscó la regla en los specs vecinos |
| varios carriles que pierden una vuelta con un comando compuesto en Bash | `implement-batch` — el preámbulo no dijo que el worktree los rechaza |
| una ficha verde de Notion que se cayó del lote sin motivo escrito | `features-to-issues` — el reparto no se mostró entero |
| un nodo del harness en verde sin haber ejercido nada | `implement-feature` — se leyó el color del nodo y no el conteo |
| dos carriles que se pisan un archivo de scratch | `implement-batch` — el prompt no le dio un nombre propio |
| un worktree que quedó abierto y el limpiador dijo que no | `implement-batch` — salía de `git worktree list`, que no ve al que git ya soltó |
| un número que el contrato midió bien y que **envejeció** | `implement-batch` — se leyó la base que el issue declara en vez de medir hoy |
| **varios carriles pisando el mismo comando que el skill les dio escrito** | `implement-batch` — un comando se vuelve a correr antes de repartirlo, no se copia |
| una lista que reparte un conjunto y **no suma el total** | `to-issue` — los grupos se cuentan contra el catálogo antes de escribirlos |
| un borde que describe un gesto que el juego no tiene, o que la regla de otra capacidad prohíbe | `to-issue` — el `rg` de los límites miró los criterios `ratified` y no los bordes ni los specs `draft` |
| un recurso generado **cuyo generador no está en el repo** | `implement-feature` — quien lo generó no commiteó la herramienta; y `to-issue`, que no la puso en «Se escribe» |
| un issue de un lote que lee un dato que ningún otro entrega, o que reescribe una regla que otro del lote acaba de escribir | `to-issue` — los borradores de «Varios de una» se cruzaron por archivo y no por lo que cada uno da por hecho |
| un issue abierto **fuera** del lote que parte de una regla que el lote cambia | `implement-batch` — el checker cruzado miró sólo adentro del lote |
| un preámbulo escrito para **la máquina de otro** | `implement-batch` — el entorno de los carriles se mide antes de repartir, no se copia del skill |
| un carril que trabaja **sobre otra base que la del issue** | `implement-batch` — el worktree arranca en `origin/main`, y la rama no salió de una base explícita |
| un objetivo numérico que **la propuesta del issue no alcanza** | `to-issue` — el número se escribió sin medir la propuesta contra el árbol |
| una referencia `#N` **que apunta a otro comportamiento** después de numerar un lote | `to-issue` — se validó la dependencia, pero no cada referencia del cuerpo publicado contra su destino |
| un conteo de obligatorias **que confunde el catálogo con lo exigido en la jornada** | `to-spec` — el ejemplo citaba todos los tipos posibles y no la declaración de la apertura |
| capturas pedidas en el PR **sin una forma que ande de subirlas** | `implement-feature` e `implement-batch` — la receta no se probó desde el worktree de un carril |
| un criterio de arte que **no entra en el modelo** | `to-issue` — el criterio se escribió sin medirlo sobre el `.blend` |
| un valor nuevo de un enum **cuyo índice vive fuera de los límites** | `to-issue` — el `rg` buscó el enum en el catálogo y no en todo lo que se indexa con él |
| un contrato que mueve un valor y **no sigue a todos sus lectores** | `to-issue` — el `rg` encontró al primer lector y el contrato se escribió sobre ése |
| un índice que contesta sobre **otro árbol** que el del carril | `implement-batch` — el preámbulo mandó a consultar el índice desde un worktree, y el servidor mira el checkout principal |
| una textura que **no se ve desde donde mira el jugador** | `to-issue` — el issue no cruzó la textura con las UV de la malla ni con la cara visible |
| una pregunta al usuario **que una medición contestaba** | `implement-batch` — el padre preguntó sin medir lo que suponía cada opción, ni cruzarla con lo que el usuario ya había decidido |
| un issue reescrito en el cruce **cuyo contrato sigue diciendo lo de antes** | `implement-batch` — se reescribió la premisa y no el contrato que salía de ella |
| un caso que **afirma el gesto viejo** y sale rojo en la corrida entera | `implement-feature` — no se buscaron los casos que ejercen el gesto redefinido antes de `verificar.py` |
| un issue que multiplica lo enfocable **sin medir la mira** | `to-issue` — el costo de `_leer_la_mira` no se midió antes de sumar cuerpos al grupo `interactuable` |
| un gesto que **deshace una obligatoria** sin que el issue diga qué pasa | `to-issue` — el cruce miró los criterios del gesto y no las tareas que su efecto toca |
| un caso de escena **verde por suerte** después de que cambió el local | la regla de tests — el caso afirmaba el resultado y no su premisa |
| un generador que **da vuelta lo que el artista hizo** | `implement-feature` — se probó el generador contra el issue y no contra el `.blend` del artista |
| un nombre que el issue borra **y que un carril en vuelo vuelve a usar** | `to-issue` — «Verificación» no llevaba el `rg` del nombre, y nadie lo corrió después del merge |
| un test que afirma sobre **una escena entera que el issue escribe**, afuera de «Se escribe» | `to-issue` — los tests de la escena no se buscaron con `tests_de` ni `quien_instancia` |
| un archivo nuevo **que el contrato implica y «Se escribe» no nombra** | `to-issue` — «Se escribe» se armó sólo con lo que ya existía |
| un conflicto entre dos carriles **que le queda a quien mergee** | `implement-batch` — las cadenas llegaban por separado a `staging`, y la resolución no vivía en ninguna rama |
| una carpeta que gdUnit4 crea **adentro del repo** con `-rd /tmp/...` | `.gitignore` e `implement-batch` — la advertencia del preámbulo no alcanzó, y el ignore la vuelve inofensiva |
| una regla que se saca y **deja caer un invariante** que otra daba por hecho | `to-issue` — el cruce sigue a los lectores de un valor que se mueve, y sacar una regla no mueve ningún valor |
| una suite que el issue manda a crecer **y ya está en el tope de `gdlint`** | `to-issue` — se contaron los `test_` y no los métodos públicos |
| una regla de tests que describe **una versión vieja de la herramienta** | la regla de tests — se escribió midiendo gdUnit4 antes de 6.2.1, y nadie la volvió a medir al actualizarlo |
| un caso que **afirma la regla que el issue invierte** sin decirla en prosa | `to-issue` — los límites salieron de un `rg`, y la inversión no se probó con un parche antes de publicar |
| un criterio con «siempre», «nunca» o «ninguno» que **pone en rojo un caso de «Sólo lectura»** | `to-issue` — el issue no invertía ninguna regla, y el criterio no se probó con su lectura literal antes de publicar |
| un criterio de medición que pide **otro protocolo que el medido**, o que cita uno que no trae escrito | `to-issue` — el prototipo alternaba en una página y el criterio pidió dos exports; los parámetros quedaron en el scratch de quien midió |
| varios issues que **dan por hecha una herramienta de medición** que ninguno entrega | `to-issue` — «Se escribe» nombró el escenario y no la copia que se exporta ni quién recoge su informe |
| un turno entre carriles que **no respeta el orden de llegada** | `implement-batch` — el turno era un cerrojo que cada carril reintentaba, y no una cola |
| una pista del padre sobre el motor **que resultó falsa** | `implement-batch` — se repartió de memoria, sin la sonda que se le exige a un comando |
| un puerto repartido **que ya escuchaba otro proceso** | `implement-batch` — se asignó sin mirar qué puertos estaban libres |
| una base integrada durante una pausa **que deja obsoleto un borrador en scratch** | `implement-batch` — al reanudar se actualizó la rama pero no se midieron otra vez los recursos, lectores y geometría |
| una copia temporal de un proyecto **dentro del checkout que contamina un gate** | `implement-batch` — las copias para exportar o medir viven fuera del checkout; `.gdignore` no limita los barridos Python |
| un issue que **recrea arte que ya existe para agregarle interacción** | `to-issue` — se buscó la funcionalidad faltante sin inspeccionar los soportes del artista ni la decisión vigente del usuario |
| un método retirado que **sigue llamado por un helper de integración** | `to-issue` — el barrido de lectores incluye `src/`, `test/`, `call()` y `Callable`, no sólo la declaración |
| un barrido que **confunde una palabra compartida con la regla retirada** | `to-issue` — se acota el patrón al enunciado retirado y se conserva el código ajeno que no cambió de contrato |
| un contrato que **exporta al editor un dato `RefCounted`** | `to-issue` — una sonda verifica el tipo exportable antes de repartir el contrato |
| una sonda de paquete **en verde con scripts que no parsearon** | `implement-batch` — cargar un recurso no basta; el paquete real se ejerce fuera de la fuente, con marcador final y sin errores del motor |
| una corrida que **leyó una versión distinta de la fuente actual** | `implement-batch` — el árbol se congela desde encolar hasta el resultado, incluida la espera y los rojos y verdes cortos |
| un comando de un issue apilado **que cobra rutas de sus ancestros** | `to-issue` — el diff se compara contra la base explícita medida, no contra `staging` |
| un hueco libre por rayos **que una malla sin collider tapa en pantalla** | `to-issue` — el encuadre cruza mallas, profundidades, proyección y capturas; los bordes físicos y los visibles se prueban aparte |
| una captura **que ya no muestra el foco y la pose preparados** | `to-issue` — el fixture comprueba foco y pose dibujada al guardar, y el padre abre el PNG; un rayo anterior no certifica el cuadro final |
| un historial de reportes **que falla sólo al superar veinte corridas** | `implement-batch` — se usa `res://reports` para que gdUnit4 globalice la ruta antes de retirarlos, sin modificar addon ni retención |
| un XML sin errores **que oculta un callback abortado o una fuga al desmontar** | `implement-feature` — se conserva la salida cruda también en verde y el fixture afirma la entrega válida y la ejecución del receptor |
| un recorrido web **que no mide los filtros del preset versionado** | `to-issue` — se cruzan filtros y dependencias importadas antes de cerrar límites; el arreglo entra en el preset publicado, no sólo en una copia de captura |
| un detector de enteros **que parte decimales en cifras de balance** | `implement-feature` — se tokeniza el literal completo y se prueba tanto la copia entera prohibida como los decimales geométricos permitidos |
| una sonda física **que elimina las colisiones al congelar la escena** | `implement-feature` — se detienen los procesos que cambian la pose y se comprueban piso y obstáculos conocidos antes de medir |
| una mira **que lee solapamientos anteriores al teletransporte** | `implement-feature` — se sincronizan las áreas con cuadros físicos y se prueban las caras visibles con la mira real |
| una base **sin stderr que impide comparar el desmontaje** | `implement-feature` — se guardan ambos canales del subproceso también en la base; `godot.log` no sustituye esa salida |
| un import frío de export **que retiene recursos de plugins del editor** | `implement-feature` — se identifican con verbose y se aísla sólo el editor en la copia externa; preset y juego permanecen idénticos, y el paquete real conserva sus chequeos estrictos |
| una lectura del navegador **que altera la activación que intenta observar** | `implement-feature` — se usa CDP con userGesture false para observar y entradas físicas para actuar; la consola se conserva desde la carga |
| un fixture **que apaga el callback que actualiza el cursor** | `implement-feature` — se mantiene activa la traducción del control y se afirma Pointer Lock al abrir, cerrar, pausar y reanudar, sin atribuirle otros errores sin prueba |
| un AC del contrato común **que queda sin dueño mientras su capacidad sigue draft** | `implement-batch` — antes de repartir se asigna cada AC nuevo a un issue y test permitido; el cierre contrasta esa lista completa, incluidos sus bordes, además de los criterios descartables de cada issue |
| una entrada nativa **que selecciona otra fila por la escala DPI** | `to-issue` — el driver declara consciencia DPI antes de consultar ventanas, cruza cliente y viewport y afirma la selección real sobre el HWND propio |
| una dependencia instalada **adentro del worktree** que tira la importación de Godot | `implement-batch` — el preámbulo no dijo que Playwright se resuelve desde el checkout principal |

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

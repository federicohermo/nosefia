---
name: spec-create
description: Abre un spec nuevo en No se fía — convierte un pedido en prosa («hay un bug», «habría que agregar», «estaría bueno que») en un spec publicado como issue de GitHub, ANTES de tocar una línea de código. Usar apenas llega el pedido, no después de investigarlo. Trae escrito qué NO necesita spec.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
---

# spec-create — del pedido al spec publicado

Cubre el tramo que va del pedido escrito en prosa al `spec.md` en disco y publicado como
issue. `spec-review` audita un spec que existe; `spec-implement` implementa uno que existe.
Acá todavía no hay ninguno.

## Antes que nada: ¿esto necesita un spec?

**La mayoría de las veces sí, y por eso esta sección va primero y es corta.** Un skill que
obliga a escribir tres archivos para arreglar una tilde se apaga entero, y un gate apagado
es peor que no tenerlo.

**No necesita spec** —seguí derecho, sin rama de feature:

| Caso | Ejemplo |
|---|---|
| Un typo o una redacción, sin cambio de comportamiento | una tilde en un comentario, un `README` mal escrito |
| Revertir el commit anterior | `git revert`, cuando lo que se revierte ya tenía su spec |
| Actualizar el addon de gdUnit4 a una versión nueva | sin cambio de API en los tests |
| Terminar lo que un spec **ya publicado** dejó abierto | cerrar su issue, marcar su avance |
| Un asset nuevo que no toca `src/` | un `.png`, un `.ogg`, una referencia |
| Lo que el usuario pida explícitamente sin spec | y entonces se dice en voz alta que se está salteando |

**Necesita spec** todo lo demás, y en particular:

- Un **bug**, aunque el arreglo sea una línea. Un bug de una línea suele destapar que faltaba
  un invariante, o que un test estaba verde sin ejercer nada — y eso no se ve mirando la línea.
- Cualquier cosa que toque `src/dominio/` o `src/sistemas/`: las reglas del juego.
- Una feature, por chica que parezca.
- Un cambio de escena que cambie **qué puede hacer** el jugador.

**En la duda, spec.** Escribirlo cuesta una hora; descubrir tres semanas después por qué se
hizo algo cuesta más.

## Paso 0 — ¿de dónde viene esto?

**¿El pedido ya es un issue?** La deuda de este repo vive en GitHub Issues, así que la
respuesta es «sí» más seguido de lo que parece:

```bash
python .claude/scripts/deuda.py   # los issues abiertos que ningún spec reclama
```

Si el pedido **es** uno de ésos, la pregunta siguiente decide el carril, y es una sola: **¿el
arreglo toca `src/` o `docs/`?** —que son las dos rutas que el hook protege.

| El arreglo… | Qué hacer | Qué cierra el issue |
|---|---|---|
| **no** las toca | rama `fix/` o `chore/` y seguí derecho: **no necesita spec** | `Closes #N` en el cuerpo del PR |
| **sí** las toca | necesita spec, y su `spec.md` lleva `**Origen:** #N` en el encabezado | un `Closes` por **cada** issue saldado |

**Esa línea no es decorativa**: `publicar_spec.py crear` la parsea y escribe `origen` en la
fila de `specs/mapa.json`, y de ahí la lee el gate que pone en rojo un spec cerrado cuyo issue
de deuda siguió abierto. Sin el dato, nada puede exigir el `Closes`.

**`origen` es lo que el spec SALDA, no lo que menciona.** Un issue citado como contexto de una
medición que el spec no arregla **no va**: con la lectura ancha el gate daría rojo sobre specs
correctos y se apagaría en una semana. Y va en el **encabezado**, antes del primer `##`: un
`#12` suelto en la prosa no cuenta.

La línea se puede agregar o corregir **después** de publicar: `crear` reconcilia el `origen` de
cada fila en cada corrida, así que volver a correrlo alcanza.

## Los cinco pasos

### 1. Medir, y recién después escribir

El `research.md` **sale de correr algo**, no de suponer.

Lo que la medición tiene que dejar por escrito:

- **Qué se rompe.** Corré `python .claude/scripts/verificar.py` con el cambio mínimo aplicado y
  contá: qué nodo se pone en rojo, cuántos tests, en qué archivos. Un número acá es lo que
  hace estimable el spec.
- **Quién cita lo que va a cambiar.** `rg` sobre `src/` y `test/`, y `rg --no-ignore` para
  `specs/` — que está en el `.gitignore`, así que `Grep` **no lo ve** y contesta cero sin decir
  que no miró.
- **Qué NO se mueve.** Es tan informativo como lo que sí: si el nodo `capas` no se mueve, el
  trabajo no cruza ninguna frontera de capa.

Para lo que no se puede medir sin escribir código, un script de un solo uso que se corre y se
borra — no se commitea.

### 2. Los tres archivos

`specs/<NNN>-<descripcion-kebab>/` con `spec.md`, `research.md` y `estrategia.md`. El formato,
las desviaciones y el corte en 030 están en [`specs/README.md`](../../../specs/README.md).

**No hay `plan.md` ni `tasks.md`**, y no es una simplificación: está medido. De las rutas de
archivo que esos dos nombraban, el **43 %** nunca se tocaba y el **39 %** de lo que el PR sí
tocaba no lo había previsto nadie, con el error escalando con el tamaño del spec. Escribir la
lista de archivos antes de abrir uno es predecir, y salía cara.

El `estrategia.md` declara lo que la predicción no puede inventar: **el orden obligado** —lo
que NO se puede paralelizar, empezando por los `.tscn`, que no se mergean—, qué **no** se
toca, y el criterio de terminado. Sin rutas predichas salvo las que el `research.md` midió.

**Y hay cuatro techos de palabras, que los verifica el gate**: 350 de prosa en el `spec.md`,
300 en el bloque `## Criterios de aceptación` **entero**, 500 en el `research.md`, 250 en el
`estrategia.md`. El segundo cae sobre el bloque y no sobre cada criterio a propósito: con un
límite por criterio, un spec cumple escribiendo veinte criterios cortos.

**El número se reserva tarde**: mirá `specs/mapa.json` recién cuando vayas a crear la carpeta.
Si hay otra sesión trabajando en paralelo, el número que elegiste al empezar ya no es el tuyo.

Cinco cosas que este repo pide y que no son obvias:

- **Cada criterio va a terminar nombrado por un test, así que numeralo `AC1`, `AC2`.** El
  gate exige que cada `ACn` de un spec `Implementado` esté citado desde `test/` o desde
  `.claude/scripts/tests/`, y nombra el que falte. Un criterio sin número no se puede citar.
- **Cada criterio de aceptación tiene que ser falsificable.** «El sistema de consecuencias
  funciona» no lo es; «con cuatro tareas cumplidas, `consecuencia()` devuelve `AVISO` y no
  `NINGUNA`» sí. Si un AC no se puede ver fallar, no verifica nada.
- **Un AC que barre un directorio y enumera excepciones: corré el barrido ANTES de escribir la
  lista.** Es la forma «`rg <patrón> <ruta>` no devuelve nada, salvo A y B». Escrita de memoria la
  lista **siempre sale corta** —los fixtures sintéticos de otros specs, los `.md` que narran el
  cambio, el archivo de demo de un hook—, y entonces el AC **nace imposible de pasar**: quien lo
  implemente va a encontrarse con un barrido que devuelve cosas que ninguna tarea suya toca, y el
  motivo va a estar en otro spec. Medido el 2026-09-01 en el lote 024/025: **cuatro de los siete
  hallazgos de implementación fueron este mismo error**, en dos specs distintos escritos por la
  misma mano — al AC17 del 024 le faltaban dos listas de excepción y seis fixtures, y al AC5 del
  025, seis fixtures más un séptimo que sólo existía del lado de `test/`. El barrido tarda cinco
  segundos y la lista sale sola.
- **Cada tarea tiene que poder cerrarla un agente.** No escribas tareas que se cierran
  mirando, escuchando o sacando una captura: en el repo del que sale este harness eran 137
  casillas marcadas así en 35 specs y sólo 6 se cerraron alguna vez — o sea que el marcador no
  decía «espera a una persona» sino «no se va a hacer, pero queda escrito». La salida es
  **volverla verificable** —un test de gdUnit4, un número medido, un valor que un gate pueda
  leer— o no anotarla. Lo verifica `test_convencion_de_specs.py`.
- **Si el spec estrena una regla, fijate de qué lado del corte cae él.** Una regla nueva casi
  siempre viene con un «desde acá en adelante», y el número de ese corte es una decisión, no un
  detalle: si el corte incluye al propio spec, la regla lo pone en rojo **el día que se publica**,
  antes de que exista su rama y sin que nadie la haya implementado. Y el síntoma en el texto es
  siempre el mismo — el `## Fuera de alcance` dice «este spec no se escribe así» y los AC dicen
  «desde este spec». **Cruzalos antes de publicar.** Medido el 2026-09-05 en el 029, que puso el
  corte en 029 con su propio research diciendo que el primero nuevo era el 030.
- **Cada tarea nombra el archivo que toca**, entre backticks. Es lo que hace revisable el
  reparto de un lote antes de lanzarlo.
- **Las tareas son la totalidad de lo que hace falta**, y ésta es la que no verifica nadie. Que
  las que escribiste sean correctas no alcanza: **recorré cada AC y preguntá qué tarea lo cumple.**
  Un AC sin tarea no rompe ningún gate, no aparece en ningún diff y **simplemente no se hace** —
  es el agujero más caro del flujo, porque el spec se implementa entero, se mergea, y el AC sigue
  sin cumplirse con todo en verde.

### Y nada se aplaza — lo verifica el gate

Un spec **no tiene dónde escribir trabajo para después**, y eso es a propósito. No hay
`## Seguimiento` ni `## Pendientes` ni `## Próximos pasos`, ninguna casilla dice `TODO` ni «por
ahora», y **ningún `research.md` declara una medición como no hecha**: o se corrió, o el spec no la
necesitaba. Las cuatro las verifica `test_convencion_de_specs.py`, sobre los specs hidratados.

**`## Fuera de alcance` sí existe y no es lo mismo.** Declara una frontera —qué NO hace este
spec— y es lo que lo vuelve revisable. La prueba de que se convirtió en deuda con sombrero es una:
**¿algún AC de este spec depende de lo excluido?** Si sí, entra al spec. Ningún gate puede
decidirlo; lo mira `spec-review`.

El porqué está en [`sin-deuda.md`](sin-deuda.md).

### 3. Publicarlo como issue

```bash
python .claude/scripts/publicar_spec.py crear     # un issue por spec, y su fila en mapa.json
python .claude/scripts/publicar_spec.py publicar  # sube spec.md al body y el resto como comentarios
```

Son dos fases porque los specs se citan entre sí, y traducir una cita a la URL de su issue
necesita que ese issue ya exista. Las dos son idempotentes: se pueden correr de nuevo.

**El veredicto sale del código de salida, nunca de un grep de la salida.** Un `| grep` que no
matchea devuelve 1 y se traga la salida entera.

### 4. Commit del mapa

```bash
git add specs/mapa.json          # lo ÚNICO del spec que se trackea
git commit && git push origin staging
```

El spec entra a `staging` y ahí termina. Un spec abandonado no se va con ninguna rama: queda
en el registro como `Descartado`, que es información.

### 5. Entregarle el control a `/spec-implement`

**La rama NO se crea acá.** Escribir un spec y decidir implementarlo son dos decisiones
distintas, y entre una y otra puede pasar cualquier cosa: que se revise y cambie, que se
descarte, que lo tome otra persona, que espere al spec del que depende. Una rama abierta en el
paso 4 es una rama que existe antes de que exista el trabajo.

La crea el implementador, y se llama `feature/<NNN>-<descripcion-kebab>` — **es de donde el
gate saca el número del spec**, así que una rama con otro nombre bloquea la primera edición de
`src/`.

## Al cerrar

No es parte de abrir un spec, pero es la otra mitad y se saltea igual de fácil:

1. **Cada criterio del spec nombrado por un test que corre.** No hay marcador para «esto queda
   pendiente», y **tampoco la salida de abrir un issue**: si aparece trabajo que el spec
   necesitaba y no tenía, eso es un defecto de este skill —el spec salió incompleto— y se
   descarga corrigiéndolo y agregando acá la regla que lo habría atajado. Ver «el lazo» en
   [`sin-deuda.md`](sin-deuda.md).

   **Lo verifica el gate:** un spec `Implementado` con un criterio que ningún test nombra —o,
   si es ≤ 029, con una casilla abierta— pone en rojo el nodo
   `harness`.
2. **Un `Closes` por cada issue saldado**, y son el del spec **más los del `origen`**. El del
   spec se cierra solo; el de deuda que lo parió no lo cierra nadie, y sin el `Closes` quedan
   dos issues por el mismo trabajo y uno abierto para siempre.
3. **No edites `specs/mapa.json` a mano en el PR.** Mientras el PR está abierto el mapa tiene
   que decir `Propuesto`, y el gate da rojo si dice otra cosa. El estado lo deriva
   `.github/workflows/mapa.yml` en el push a `staging`.
4. Lo que salió distinto de lo previsto, **como comentario en el issue**.

## Si el gate te frenó

El hook bloquea editar `src/` y `docs/` desde `main`, desde `staging`, o desde una rama que no
nombra un spec. Si saltó, no lo saltees: o estás en el caso «no necesita spec» —y entonces la
rama igual no puede ser ninguna de las dos compartidas—, o te falta el paso 3, o el spec ya
está publicado y lo que falta es **la rama**.

`.claude/` y `specs/` **no** están protegidos, a propósito: son adonde este skill te manda a
escribir primero.

# Specs

Trabajo planificado. Un spec por unidad de trabajo, en su propia carpeta numerada.

> **Cada spec ES un issue de GitHub.** `specs/[0-9]*/` está en el `.gitignore`, y lo único que
> se commitea de este directorio son tres cosas que no son specs: este `README.md`,
> [`mapa.json`](./mapa.json) —el mapa spec↔issue— y nada más. Los gates que verifican esta
> convención viven en `.claude/scripts/tests/`.

## Por qué el spec no vive en el repo

Porque un spec no es código: es un plan con fecha, que se discute, se corrige y a veces se
descarta. Un archivo en el repo no tiene estado, no tiene hilo de comentarios y no se puede
cerrar; un issue tiene las tres cosas. Y la mitad práctica: sin esto, el repo del juego se
llena de documentos de proceso que ensucian cada `grep` y cada diff.

**El directorio local es una caché, no la fuente.** Si no está, se trae:

```bash
python .claude/scripts/hidratar_specs.py           # los que están EN VUELO y falten
python .claude/scripts/hidratar_specs.py 007       # o uno solo, esté como esté
python .claude/scripts/hidratar_specs.py --todos   # todos, cerrados incluidos
```

Hace falta correrlo **en cada worktree**: `git worktree add` hace checkout de lo trackeado, y
un archivo ignorado no viaja.

> **Buscar dentro de los specs necesita `--no-ignore`.** Leerlos no: `.gitignore` es cosa de
> git y no del sistema de archivos, así que `Read`, `cat` y `head` los abren normalmente. Pero
> **ripgrep respeta el `.gitignore`**, y la herramienta `Grep` está construida sobre ripgrep —
> o sea que una búsqueda en `specs/` devuelve **cero resultados sin decir que no miró**, que es
> la peor respuesta posible.
>
> ```bash
> rg --no-ignore "lo que sea" specs/
> ```

## El mapa

[`mapa.json`](./mapa.json) es lo único trackeado, y por eso existe: **el vínculo spec↔issue no
es aritmético**. Los issues y los PR comparten contador en GitHub, así que el spec `007` no es
el issue `#7` y no hay forma de deducirlo.

```json
{ "007": { "issue": 23, "carpeta": "007-la-ventanilla-atiende-de-a-uno",
           "fecha": "2026-09-04", "estado": "Propuesto", "titulo": "Spec 007 — …" } }
```

- **`carpeta` está guardada y no se deriva del título.** El nombre de la carpeta y el título
  del issue se escriben aparte y se separan enseguida; derivar uno del otro haría que un árbol
  recién hidratado inventara carpetas que ninguna cita del repo conoce.
- **`estado` y `titulo` son copias del issue**, y las mira el gate de
  `.claude/scripts/tests/test_mapa.py`. Se copian para que las herramientas puedan contestar
  **sin red**.
- **`origen` es un sexto campo, opcional**: los issues de deuda que el spec **salda**. Ver «De
  un issue de deuda a un spec».

**El formato es una entrada por línea**, y no es estética: con un JSON indentado, agregar un
spec da un diff de siete líneas y cambiar un estado da uno que hay que leer con lupa. Así cada
cambio es exactamente la línea que cambió — que es lo que hace revisable el commit que la
Action hace sola.

## Convención de nombres

```text
specs/<NNN>-<descripcion-kebab>/
├── spec.md         ← problema, solución propuesta, criterios de aceptación y límites de alcance
├── research.md     ← estado del código relevante y archivos afectados, MEDIDO
└── estrategia.md   ← el orden obligado, qué no se toca, y el criterio de terminado
```

- `NNN` — número secuencial de tres dígitos (001, 002, …).
- **Los tres archivos son el piso.** Un spec puede agregar los que necesite —un `baseline.md`
  con la medición previa, un `reparto.md`—. El nombre va en minúsculas, dígitos y guiones:
  `publicar_spec.py` **grita** ante un nombre que no puede subir, porque un `.md` no publicado
  se pierde en la hidratación siguiente.
- **`plan.md` y `tasks.md` no**, y ésa es la única parte de la lista que es cerrada. Ver el
  corte, abajo.

Es la convención de [Spec Kit](https://github.com/github/spec-kit) con cinco desviaciones
deliberadas, anotadas abajo.

## El corte en 030, y por qué el `tasks.md` se fue

**Los specs ≤ 029 tienen cuatro archivos y los ≥ 030 tienen tres.** El corte es por número y
está escrito una sola vez, en `PRIMER_SPEC_NUEVO` de
[`test_convencion_de_specs.py`](../.claude/scripts/tests/test_convencion_de_specs.py).

Es por número y no por qué archivos hay en disco porque es lo único que no se puede evadir
escribiendo el archivo que falta. Y los viejos no se migran: son **ADR** —Desviación 2—, y
reescribirlos borraría con qué evidencia se decidió cada cosa.

**Lo que se midió, sobre los 28 specs de entonces:** de las rutas de archivo que nombran
`plan.md` y `tasks.md`, el **43 %** nunca se tocó, y el **39 %** de lo que el PR sí tocó no lo
previó nadie. El error escala con el tamaño: el spec 025 acertó el **29 %**. Y no era relleno
—sólo el **5 %** de las 837 tareas se repetía entre specs—, o sea que el problema no es que
sobre ceremonia: es que el `tasks.md` es **predicción específica y equivocada**, escrita con
autoridad de documento antes de abrir un archivo.

El `estrategia.md` declara lo que la predicción no puede inventar: **el orden obligado** —lo que
no se puede paralelizar, empezando por los `.tscn`, que no se mergean—, qué **no** se toca, y el
criterio de terminado. Sin rutas predichas salvo las que el `research.md` midió.

### Los cuatro techos de palabras

Un formato más corto que no se mide vuelve a crecer en un mes, así que el límite es ejecutable.
Sobre un spec ≥ 030, y con «palabra» = token con letra o dígito:

| Qué | Techo |
|---|---|
| la prosa del `spec.md` —todo menos el bloque de criterios— | 350 |
| el bloque `## Criterios de aceptación` **entero** | 300 |
| el `research.md` | 500 |
| el `estrategia.md` | 250 |

**El segundo cae sobre el bloque entero y no sobre cada criterio, y ahí está la decisión.** Con
un límite por criterio, un spec cumple escribiendo veinte criterios cortos — la misma enfermedad
con carpeta nueva. Sobre el bloque, el límite muerde la **cantidad**.

Los cuatro números salen de medir el `spec.md` del 029, que es el modelo del formato aunque él
mismo esté escrito en el viejo. Lo verifica un test, para que ningún techo quede calibrado
contra un documento imaginario.

## El ancla anti-deuda: de la casilla al criterio

Un spec `Implementado` con una casilla abierta era **la** contradicción que el gate perseguía. Sin
`tasks.md` esa regla se queda sin objeto: sigue escrita, no encuentra ninguna casilla, y sale
verde para siempre. Un gate que no puede fallar no es laxo — está apagado y parece encendido.

La reemplaza **AC↔test**: en un spec ≥ 030 `Implementado`, **cada `ACn` de su `spec.md` está
citado como `NNN-ACn` —`030-AC1`— por al menos un archivo bajo `test/` o
`.claude/scripts/tests/`**, y el rojo dice cuál falta. La cita lleva el número del spec porque
`AC1` es el nombre que usa **todo** spec: pelada, la primera cubriría a todas las demás para
siempre y el gate no podría volver a fallar. Es más fuerte que la que reemplaza — una casilla la marca a mano el mismo que decide si el
trabajo está hecho; un test corre en cada push y **se rompe solo**.

**Su techo, dicho:** el gate verifica la **cita**, no que el test ejerza el criterio. Es un piso,
como todo lo que este repo verifica sin cobertura.

> **Desviación 1 — la rama se crea después.** Spec Kit crea la rama primero y le da su nombre a
> la carpeta. Acá el spec entra a `staging` antes, así que un spec abandonado no se va con su
> rama: queda en el registro como `Descartado`, que es información.

> **Desviación 2 — un spec mergeado no se reescribe.** Spec Kit los trata como documentación
> viva que se regenera con el código; acá son **ADR**: registro de qué se decidió y con qué
> evidencia, con fecha. Lo que sí se mantiene al día es `docs/`, `.claude/rules/` y `CLAUDE.md`.

> **Desviación 3 — el ticket no va en el nombre de la carpeta.** La convención original usa
> `specs/<NNN>-<TICKET>-<descripcion>/`. **No es que no haya ticket**: el spec *es* un issue, y
> ése es su ticket. Lo que pasa es que su número no se conoce cuando se crea la carpeta —lo
> asigna `publicar_spec.py`— y no es derivable. Por eso existe `mapa.json`: **es el segmento de
> ticket, sacado del nombre de la carpeta**. Y por eso la rama lleva el número del spec y no el
> del issue: `feature/<NNN>-<kebab>` es de donde el hook saca de qué spec se trata.

> **Desviación 4 — el `research.md` se mide, no se supone.** Es la más importante de las cinco
> y la que más se saltea. Un `research.md` que dice «probablemente haya que tocar el HUD» no es
> research: es una intuición con formato de documento. El que sirve dice **qué corriste y qué
> contestó**.

> **Desviación 5 — no hay `plan.md` ni `tasks.md`.** Spec Kit deriva un plan del spec y una
> lista de tareas del plan. Acá el `estrategia.md` los reemplaza a los dos y declara mucho
> menos: **el orden obligado**, no el orden completo. Es la desviación con más evidencia
> local detrás, y está arriba, en «El corte en 030».

## Los cuatro estados

El campo `estado` es un conjunto cerrado, y la lista vive una sola vez: `ESTADOS` en
[`.claude/scripts/lib/specs.py`](../.claude/scripts/lib/specs.py).

| Estado | Qué dice | ¿En vuelo? | Su issue |
|---|---|---|---|
| `Propuesto` | escrito y publicado; de él todavía puede salir trabajo | **Sí** | abierto |
| `Implementado` | su PR aterrizó en `staging` | No | cerrado |
| `Descartado` | se abandonó sin implementar | No | cerrado |
| `Superado` | otro spec lo reemplazó | No | cerrado |

**«En vuelo» es la partición que importa**, y es una sola función —`en_vuelo`— porque de ella
dependen tres cosas distintas: qué trae `hidratar_specs.py` por default, si `publicar_spec.py`
cierra el issue, y qué estado del issue espera el gate. Con una copia escrita a mano en cada
uno, sacar un estado del conjunto deja a los otros mirando uno que ya no existe, **en verde**.

**No hay un estado «En curso»**, y es deliberado: ningún paso del flujo lo escribiría.
`publicar_spec.py` pone `Propuesto` al crear el issue y el merge pone `Implementado`; entre
esos dos no hay ningún momento en el que alguien vuelva al mapa a anotar que empezó. Agregarlo
sería un tercer punto de escritura manual, que es justo el mecanismo que falla. Que un spec
haya empezado se ve en que tiene rama.

## Formato de una tarea — sólo en un spec ≤ 029

Los specs del régimen viejo llevan su checklist, y el gate se la sigue verificando. En uno
≥ 030 no hay casillas: lo que un `estrategia.md` declara es el **orden**, en prosa.

```markdown
- [ ] T012 [P] Descripción, con la ruta del archivo que toca
```

| Parte | Qué dice | Obligatorio |
|---|---|---|
| `T012` | ID estable dentro del spec, para que una tarea pueda nombrar a otra | Sí |
| `[P]` | Se puede hacer en paralelo con las otras `[P]` de su bloque: no comparten archivo ni dependen entre sí | No |

Los IDs son **estables**: no se renumeran al insertar una tarea nueva, se sigue contando. Un ID
libre no molesta a nadie; uno reusado rompe la referencia que otra tarea le hacía.

**No hay marcador para «esto lo tiene que mirar una persona».** En el repo del que sale este
harness lo hubo, y se midió: de **137** casillas marcadas así en **35** specs, sólo **6** se
cerraron alguna vez. O sea que el marcador no significaba «espera a una persona» sino «no se va
a hacer, pero queda escrito», y las que seguían abiertas no eran un registro de trabajo
pendiente sino una lista de intenciones con formato de checklist.

**En su lugar hay dos salidas, y anotarlo no es ninguna**: o la verificación se vuelve
**verificable** —un test de gdUnit4, una medición, un valor que un gate pueda leer— y entonces
es una tarea normal que bloquea como cualquier otra, o **no se escribe**. Lo verifica
`test_convencion_de_specs.py`.

**Tampoco hay dónde aplazar.** Ni `## Seguimiento` ni sus alias —`## Pendientes`,
`## Próximos pasos`, `## Deuda`—, ni una casilla que diga `TODO` o «por ahora», ni un
`research.md` que declare una medición como no hecha. Adentro de un `tasks.md` el ítem **hereda el
estado de su spec**: un spec `Implementado` con diez casillas abiertas dice que ya está y sigue
debiendo, y eso es exactamente cómo la deuda se vuelve invisible.

**Las cuatro las verifica `test_convencion_de_specs.py`**, y la última incluye el caso que las
demás no cubren: **un spec ≤ 029 `Implementado` no puede tener una casilla abierta**, y uno
≥ 030 no puede tener un criterio que ningún test cite como `NNN-ACn`. Corre sobre los specs **hidratados**,
así que sobre un árbol vacío se saltea declarándolo — y un nodo salteado no es un nodo verde.

**Y la salida tampoco es abrir un issue.** Los issues de este repo son **entrada**: lo que llega de
afuera y `spec-create` drena. Si aparece trabajo que el spec necesitaba y no tenía, el defecto es
del spec —y del skill que lo dejó salir así—, y se corrigen los dos. La doctrina completa está en
[`.claude/doctrina/sin-deuda.md`](../.claude/doctrina/sin-deuda.md).

**`## Fuera de alcance` sí existe y no es lo mismo**: declara una frontera —qué NO hace este spec—
y es lo que lo vuelve revisable. Se convierte en deuda sólo si algún AC del propio spec depende de
lo excluido, y eso ningún gate lo puede ver: lo mira quien escribe el spec.

## De un issue de deuda a un spec

**Hay dos carriles y los decide una sola pregunta: ¿el arreglo toca `src/` o `docs/`?** Ésas son
las dos rutas que el hook protege.

| El arreglo… | Carril | Qué cierra el issue |
|---|---|---|
| **no** toca ruta protegida | rama `fix/` o `chore/`, sin spec | `Closes #N` en el cuerpo del PR |
| **sí** la toca | necesita spec, y el `spec.md` lleva `**Origen:** #N` | un `Closes` **por cada** issue saldado |

> **`Closes #N` en el cuerpo de un *issue* no cierra nada**: GitHub sólo autocierra desde un PR
> o un commit. Por eso el vínculo no se puede resolver escribiéndolo en el `spec.md` y nada
> más — tiene que llegar al PR.

**Y por eso existe `origen`.** La línea `**Origen:** #12` del encabezado del `spec.md` la parsea
`publicar_spec.py crear` y la escribe en la fila del mapa. De ahí la lee el gate, que pone en
rojo un spec que ya no está en vuelo y cuyo `origen` sigue abierto. **Sin ese dato nada puede
exigir el `Closes`.**

**La línea del `spec.md` es la fuente y no una copia**: `crear` reconcilia el campo en **cada**
corrida, así que agregar o corregir el `**Origen:**` de un spec ya publicado llega al mapa
igual.

**`origen` significa saldar, no citar.** Un issue mencionado como contexto de una medición que
el spec no arregla no va: con la lectura ancha el gate daría rojo sobre un spec correcto, y se
apagaría en una semana.

**Qué hay para promover lo contesta un comando:**

```bash
python .claude/scripts/deuda.py   # los issues abiertos que ningún spec reclama
```

El orden es por antigüedad y **no es una prioridad**: cuál se promueve y en qué orden es una
decisión, y una máquina que la tome inventa prioridades.

## Flujo

1. **Medir**, y recién después escribir los tres archivos.
2. **Publicarlo como issue** con `python .claude/scripts/publicar_spec.py crear` y después
   `publicar`. La primera fase le escribe su fila en `mapa.json` con estado `Propuesto`. **Esa
   fila es el mapa**, y es lo único del spec que se commitea.
3. **Crear la rama `feature/<NNN>-<descripcion-kebab>`**, y eso ya es el primer paso de
   implementar: la abre quien toma el spec, no quien lo escribió. El paso 2 termina en
   `staging`.
4. **Implementar, con el test primero**, y que cada test nombre el criterio que verifica: es
   lo que el gate lee al cerrar, y escribirlo después es escribirlo dos veces.
5. **Devolver al issue lo que se editó** con `python .claude/scripts/publicar_spec.py publicar`,
   antes de cerrar. El árbol local es caché: la próxima hidratación baja los archivos del
   issue y **se lleva puesto todo lo que no se haya subido**.
6. **Al mergear, anotar en el issue —como comentario— qué se aprendió** si el spec salió
   distinto de lo previsto. Es lo único que queda a mano.

> **El estado del mapa y el cierre del issue no son tareas.** El issue lo cierra el `Closes #N`
> del PR, y el `estado` lo deriva [`.github/workflows/mapa.yml`](../.github/workflows/mapa.yml)
> en el push a `staging`.
>
> No es disciplina floja: el gate tiene dos tests en espejo —un PR aterrizado con el mapa en
> `Propuesto` es mentira, y un `Implementado` sin PR aterrizado es la mentira al revés— y
> juntos **prohíben actualizar el mapa adentro del PR que lo justifica**. El paso sólo podría
> ocurrir en un commit posterior escrito a mano, que es el que se olvida. El estado de un spec
> no es un dato que alguien escribe: es una consecuencia de si su PR aterrizó.
>
> Se puede correr a mano —`python .claude/scripts/derivar_mapa.py`, o con `--verificar` para
> que no escriba y salga 1 si escribiría—, pero no hace falta.

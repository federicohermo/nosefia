# Specs

Trabajo planificado, un spec por unidad de trabajo. Es un *cheat sheet* como `CLAUDE.md`: lo que
no se puede averiguar mirando un archivo. **El procedimiento vive en
[`spec-create`](../.claude/skills/spec-create/SKILL.md)** y **la forma de cada archivo en
[`plantilla/`](./plantilla/)**, que es lo que se copia; acá va el porqué y quién lo cobra.

> **Cada spec ES un issue de GitHub.** `specs/[0-9]*/` está en el `.gitignore`: de este
> directorio se commitean este `README.md`, [`mapa.json`](./mapa.json) y `plantilla/`. Nada más.

## El directorio es caché, no la fuente

Un spec no es código: es un plan con fecha, que se discute, se corrige y a veces se descarta. Un
archivo del repo no tiene estado, ni hilo de comentarios, ni forma de cerrarse; un issue tiene
las tres. Y sin esto el repo del juego se llena de documentos de proceso que ensucian cada
`grep`.

```bash
python .claude/scripts/hidratar_specs.py       # los que están EN VUELO y falten
python .claude/scripts/hidratar_specs.py 007   # o uno solo, esté como esté
```

**No hay forma de traerlos todos, a propósito**: un spec cerrado es un ADR, no sale más trabajo
de él, y tenerlo en disco no habilita nada. Hace falta correrlo **en cada worktree** — `git
worktree add` no lleva lo ignorado.

> **Buscar acá adentro necesita `rg --no-ignore`** —leer no—: un `Grep` normal contesta **cero
> sin decir que no miró**. El detalle, con el `--hidden` que hace falta para `.claude/`, en
> [`.claude/rules/herramientas.md`](../.claude/rules/herramientas.md).

## El mapa

Es lo único trackeado de un spec, y existe porque **el vínculo spec↔issue no es aritmético**:
issues y PR comparten contador en GitHub, así que el spec `007` no es el issue `#7`.

```json
{ "007": { "issue": 23, "carpeta": "007-la-ventanilla-atiende-de-a-uno",
           "fecha": "2026-09-04", "estado": "Propuesto", "titulo": "Spec 007 — …" } }
```

- **`carpeta` se guarda y no se deriva del título**: se escriben aparte y se separan enseguida,
  y derivar uno del otro haría que un árbol hidratado invente carpetas que ninguna cita conoce.
- **`estado` y `titulo` son copias del issue**, para poder contestar **sin red**. Las mira
  `test_mapa.py`.
- **`origen`** es opcional: los issues de deuda que el spec **salda** — ver abajo.
- **Una entrada por línea**, para que cada cambio sea exactamente la línea que cambió. Con JSON
  indentado, el commit que la Action hace sola dejaría de ser revisable.

## Los cuatro estados

Conjunto cerrado, y la lista vive una sola vez: `ESTADOS` en
[`lib/specs.py`](../.claude/scripts/lib/specs.py).

| Estado | Qué dice | ¿En vuelo? | Su issue |
|---|---|---|---|
| `Propuesto` | escrito y publicado; todavía puede salir trabajo de él | **Sí** | abierto |
| `Implementado` | su PR aterrizó en `staging` | No | cerrado |
| `Descartado` | se abandonó sin implementar | No | cerrado |
| `Superado` | otro spec lo reemplazó | No | cerrado |

**«En vuelo» es la partición que importa**, y es una sola función porque de ella dependen tres
cosas: qué hidrata el default, si `publicar_spec.py` cierra el issue, y a quién mira el gate de
la convención. Copiada a mano en cada una, sacar un estado deja a las otras mirando uno que ya no
existe, **en verde**.

**El estado no lo escribe nadie**: lo deriva [`mapa.yml`](../.github/workflows/mapa.yml) del PR
que aterrizó, y `test_estado_del_mapa.py` da rojo si una fila que ya estaba cambia adentro de la
rama —las nuevas pasan, o abrir un spec sería imposible—. Por eso tampoco hay **«En curso»**:
ningún paso del flujo lo escribiría, y agregarlo sería un tercer punto de escritura manual, que
es justo el mecanismo que falla. Que un spec haya empezado se ve en que tiene rama.

## Los tres archivos, y los cuatro techos

`spec.md` —problema, solución y criterios—, `research.md` **medido** y `plan.md` —orden obligado,
qué no se toca, criterio de terminado—. Son el **piso**: un spec puede agregar un `baseline.md`.
Lo único cerrado es que **`tasks.md` no**.

Un formato corto que no se mide vuelve a crecer en un mes, así que el límite es ejecutable.
«Palabra» = token con letra o dígito:

| Qué | Techo |
|---|---|
| la prosa del `spec.md` —todo menos el bloque de criterios— | 350 |
| el bloque `## Criterios de aceptación` **entero** | 300 |
| el `research.md` | 500 |
| el `plan.md` | 250 |

Los números salen de medir el 029: prosa 350, criterios 228, research 444, plan 233.

- **El segundo cae sobre el bloque y no sobre cada criterio.** Con un límite por criterio, un
  spec cumple escribiendo veinte criterios cortos; sobre el bloque, muerde la **cantidad**.
- **No cuentan ni los encabezados ni los comentarios de markdown**, y los dos son medidos: con
  los encabezados el margen era cero —el 012 tenía exactamente 250—, y contando los `<!-- -->` la
  plantilla daba **386 palabras** sin una palabra propia. Un comentario es andamio, se borra, y
  no se ve en el issue renderizado. Por lo mismo **una ruta citada adentro de un comentario no
  prohíbe nada**: el párrafo que explica el `### Rutas` cita rutas para ilustrarlo, y contarlas
  dejaba a todo spec copiado prohibiendo `src/`. Que la plantilla pase sus propios gates lo cobra
  `test_convencion_de_specs.py` sobre ella misma.

## Qué del plan es ejecutable

`## Qué NO se toca` se parte en dos **por lo que se puede verificar**: las rutas de `### Rutas`
las cruza `test_rutas_del_plan.py` contra lo que la rama toca, con el PR todavía abierto; las
`### Invariantes` son prosa declarada como prosa. Sale del task-brief de ITBAF y de la Tabla I de
Koch, *Agentic Agile-V* ([arXiv 2605.20456](https://arxiv.org/abs/2605.20456)), que separa
*Constraints* de *Acceptance criteria*: este formato las colapsaba y la presión empujaba las
restricciones a los criterios.

**Las rutas son una lista negativa y cerrada**, y ahí está la diferencia con el `tasks.md`: aquél
predecía qué se **va** a tocar; una prohibición no se equivoca por omisión.

## El ancla anti-deuda

Un spec `Implementado` con una casilla abierta era **la** contradicción que el gate perseguía.
Sin `tasks.md` esa regla se queda sin objeto: sale verde para siempre, y un gate que no puede
fallar no es laxo — está apagado y parece encendido.

La reemplaza **AC↔test**: cada `ACn` citado como `NNN-ACn` desde algún archivo de `test/` o
`.claude/scripts/tests/`. Lleva el número del spec porque `AC1` es el nombre que usa **todo**
spec, y pelada la primera cubriría a las demás para siempre. Es más fuerte que la que reemplaza:
una casilla la marca el mismo que decide si el trabajo está hecho; un test **se rompe solo**.

**Y mira la RAMA, no los specs cerrados.** Sobre los `Implementado` llegaba tarde por definición
—ese estado empieza cuando el PR ya aterrizó—, así que el rojo aparecía con el trabajo en
`staging` y la única salida era abrir otra cosa: la deuda que el ancla existe para cerrar. Su
techo, dicho: verifica la **cita**, no que el test ejerza el criterio.

## Lo que no se escribe adentro de un spec

**La doctrina está en [`sin-deuda.md`](../.claude/skills/spec-create/sin-deuda.md)**, que los
ocho skills traen adentro. Acá, qué se prohíbe y por qué:

| No existe | Porque |
|---|---|
| un criterio que se cierra mirando o escuchando | de **137** casillas `[M]` en **35** specs sólo **6** se cerraron: no significaba «espera a una persona» sino «no se va a hacer, pero queda escrito» |
| `## Seguimiento` y sus alias —`## Pendientes`, `## Deuda`, `## Próximos pasos`— | un ítem adentro de un spec **hereda el estado de su spec**: uno `Implementado` con promesas aplazadas dice que ya está y sigue debiendo |
| un criterio que diga `TODO` o «por ahora» | se da por cumplido sin haber hecho nada |
| un `research.md` con una medición declarada como no hecha | el plan se apoya en un número que nadie midió, y el spec igual se publica |

Las cuatro las cobra `test_convencion_de_specs.py` sobre los specs hidratados —declarando el
salteo si no hay ninguno—, y la quinta el gate de la rama. Las salidas son dos y anotarlo no es
ninguna: o el criterio se vuelve verificable, o no se escribe.

**`## Fuera de alcance` no es lo mismo**: declara una frontera y es lo que vuelve revisable al
spec. Se hace deuda sólo si algún AC depende de lo excluido, y eso ningún gate lo ve.

## De un issue de deuda a un spec

Lo decide una pregunta: **¿el arreglo toca `src/`?** Es la ruta que el hook protege.

| El arreglo… | Carril | Qué cierra el issue |
|---|---|---|
| **no** la toca | rama `fix/` o `chore/`, sin spec | `Closes #N` en el cuerpo del PR |
| **sí** la toca | necesita spec, con `**Origen:** #N` en el `spec.md` | un `Closes` **por cada** issue saldado |

**Por eso existe `origen`.** `publicar_spec.py crear` parsea esa línea y la escribe en el mapa;
de ahí la lee el gate, que pone en rojo un spec cerrado cuyo `origen` sigue abierto. Sin ese dato
nada puede exigir el `Closes` — y un `Closes` escrito en el cuerpo de un *issue* no cierra nada,
GitHub sólo autocierra desde un PR o un commit. La línea del `spec.md` es la **fuente**: `crear`
reconcilia el campo en cada corrida. Y **significa saldar, no citar**: con la lectura ancha el
gate daría rojo sobre un spec correcto y se apagaría en una semana.

```bash
python .claude/scripts/deuda.py   # los issues abiertos que ningún spec reclama
```

El orden es por antigüedad y **no es una prioridad**: cuál se promueve es una decisión, y una
máquina que la tome inventa prioridades.

## Las cinco desviaciones de Spec Kit

Es la convención de [Spec Kit](https://github.com/github/spec-kit), con cinco cambios
deliberados:

| # | Qué cambia | Por qué |
|---|---|---|
| 1 | **la rama se crea después**, no antes | el spec entra a `staging` primero, así un spec abandonado no se va con su rama: queda como `Descartado`, que es información |
| 2 | **un spec mergeado no se reescribe** | acá son **ADR** —qué se decidió y con qué evidencia, con fecha—, no documentación viva. Lo que sí se mantiene al día es `docs/`, `.claude/rules/` y `CLAUDE.md` |
| 3 | **el ticket no va en el nombre de la carpeta** | el spec *es* un issue, pero su número lo asigna `publicar_spec.py` y no se conoce al crear la carpeta. `mapa.json` **es** ese segmento de ticket. Por eso la rama lleva el número del spec: de ahí lo saca el hook |
| 4 | **el `research.md` se mide, no se supone** | la más importante y la que más se saltea. «Probablemente haya que tocar el HUD» no es research: es una intuición con formato de documento. El que sirve dice qué corriste y qué contestó |
| 5 | **no hay `tasks.md`** | de las rutas que predecía, el **43 %** nunca se tocó y el **39 %** de lo que el PR sí tocó no lo previó nadie —28 specs, 2026-09-05; el 025 acertó el **29 %**—. No sobraba ceremonia: era **predicción específica y equivocada** con autoridad de documento. El `plan.md` declara el **orden obligado**, no el orden completo |

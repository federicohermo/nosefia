---
name: spec-create-batch
description: "Convierte N pedidos en prosa —o N issues de deuda— en N specs publicados como issues, en paralelo: un agente escritor por spec, los números repartidos de una vez por el padre, y una sola corrida de crear/publicar/commit al cerrar. Usar al abrir dos o más specs de una. Para uno solo, spec-create."
argument-hint: "<los pedidos, o --deuda [N] > [--dry]"
# Sin `allowed-tools`, igual que el resto de los skills de spec de este repo. Éste abanica N
# agentes, corre el harness en Python y habla con GitHub por `gh`: declarar una lista parcial
# le sacaría todo lo que no estuviera en ella y lo rompería en silencio a mitad de corrida.
---

# spec-create-batch — No se fía

## Censo de números

<!-- Inyección dinámica: corre ANTES de que el modelo procese este archivo, así que el censo
     llega con el skill ya cargado en vez de costar un turno de tool. Sin argumentos a
     propósito: cuántos specs tiene el lote se sabe recién en el Paso 3, y ahí se lo vuelve a
     llamar con el número. La ruta sale de `${CLAUDE_SKILL_DIR}` para que el skill se pueda
     mover sin editar su propio contenido, y con `python` adelante porque en Windows un `.py`
     no es ejecutable por sí solo. -->

!`python "${CLAUDE_SKILL_DIR}/scripts/numeros.py"`

---

`spec-create` convierte **un** pedido en prosa en **un** spec publicado. Este convierte N, y su
entregable propio son las tres cosas que ningún `spec-create` suelto puede hacer:

1. **Repartir los números.** Escribir un spec suelto dice *reservá el número tarde*. En un lote
   esa regla se da vuelta, y el Paso 3 explica por qué.
2. **Cruzar los pedidos antes de escribirlos.** Dos pedidos que eran un solo spec cuestan cinco
   minutos ahora y dos carpetas, dos issues y dos ramas después.
3. **Publicar una sola vez.** `publicar_spec.py` no es una operación por spec: recorre el árbol
   entero y escribe `specs/mapa.json`. N agentes corriéndolo a la vez es una carrera con el
   registro adentro.

## Por qué no hay worktrees, y por qué no hay ramas

`spec-create` **no crea rama**: escribir un spec y decidir implementarlo son dos decisiones
distintas, y una rama entre las dos queda colgada. Eso vale igual acá, multiplicado por N.

Y no hacen falta worktrees: cada agente escribe adentro de `specs/<NNN>-*/`, que es disjunta por
construcción una vez que los números están repartidos. **Esa disyunción es lo único que hace
segura la concurrencia** — no hay merge que arregle un choque acá, porque `specs/[0-9]*/` está en
el `.gitignore` y la última escritura gana en silencio, sin aparecer en ningún `git status`.

**El hook tampoco frena nada de esto**: `specs/` y `.claude/` no están entre las rutas protegidas,
a propósito — son adonde este skill manda a escribir primero. Lo que el hook sí va a frenar es la
**medición** del Paso 4 si toca `src/`, y eso está resuelto ahí.

---

## Paso 0 — De dónde sale el lote

`$ARGUMENTS`: los pedidos en prosa, o `--deuda [N]` = los N issues abiertos más viejos que ningún
spec reclama. **Sin argumentos, preguntá**: no asumas.

```bash
python .claude/scripts/deuda.py     # los issues abiertos que ningún spec reclama
```

El orden que imprime es por antigüedad y **no es una prioridad**. Cuál se promueve y en qué orden
es una decisión: si el usuario pidió `--deuda 4`, los cuatro primeros son una **propuesta** que va
en el reporte del Paso 6, no un hecho.

### Antes de repartir nada: cuáles de estos pedidos NO necesitan spec

Va primero y es corto, porque la presión del batch es hacia escribir de más: ya están los N
agentes, ya hay formato, sale casi gratis por unidad. Y un skill que obliga a cuatro archivos para
arreglar una tilde se apaga entero.

**La pregunta que decide el carril es una sola: ¿el arreglo toca `src/` o `docs/`?** Son las dos
rutas que el hook protege. Si no las toca —un typo, un revert, un asset, una casilla de un spec ya
publicado, el addon de gdUnit4— va por rama `fix/` o `chore/` con su `Closes #N` y **sale del
lote**. La tabla entera está en [`spec-create`](../spec-create/SKILL.md).

**Un pedido que sale del lote se reporta igual.** Si no, quien lo pidió cree que se perdió.

Con `--dry` se corre hasta el reporte y ahí termina: no se escriben carpetas, no se crean issues,
no se commitea.

## Paso 1 — El preámbulo, destilado una vez

Es el ahorro propio del batch: sin esto, N agentes lo re-derivan N veces desde frío. Cinco
insumos, y los cinco van **destilados**, no como rutas a leer:

- **Qué es el juego y dónde está la tensión.** Un `spec.md` que agrega contenido sin apretar la
  aritmética —cada minuto investigando es un minuto que no va a las tareas— está bien escrito y
  mal pensado, y eso no lo caza ningún gate. El GDD vive en Notion y **manda**.
- **Las cuatro capas, su dirección, y qué gate verifica cada cosa.** Es el insumo que decide
  dónde el spec ubica cada regla, que es la decisión más cara que toma un spec en este repo.
- **Las convenciones verificables, ≤40 líneas**, con **quién verifica cada una**: `CLAUDE.md` más
  los `.claude/rules/` de las capas que el lote toca.
- **El mapa síntoma → deuda** (`deuda.py`), aunque el lote no salga de ahí: es lo que deja que un
  spec declare bien su `**Origen:**` en vez de reabrir algo que ya tiene issue.
- **Cómo se busca acá**: `Grep` es ripgrep y respeta el `.gitignore`, así que **no ve `specs/`** y
  contesta cero sin decir que no miró. Para buscar entre specs, `rg --no-ignore … specs/`. Va
  literal en el prompt de cada agente: es la trampa que más barato se pisa y más caro se paga,
  porque el resultado falso se parece a un resultado.

## Paso 2 — El checker cruzado, antes de escribir una línea

Las siete clases de [`choques.md`](./choques.md), recorridas **todas**, sobre los **pedidos** —que
todavía no son specs—. Las que dan que no también se escriben.

Lo que salga es **una decisión de diseño**: se toma, se escribe, y **va en el prompt del agente
como parte de su encargo, con su porqué y con el AC que la verifica** — no como nota al pie: el
agente la va a leer sin este contexto. La recomendación se toma, no se ofrece. Lo único que frena
con `AskUserQuestion` es lo que decide el GDD (clase 4 de `choques.md`), porque eso no es una
ambigüedad técnica: es una decisión que pertenece a otro documento.

**Terminado cuando** las siete tienen respuesta escrita, el lote quedó con su cuenta final de
specs, y cada dependencia entre ellos tiene escrito **el archivo o el número que la justifica**.

## Paso 3 — Repartir los números, y esto sí es del padre

```bash
python .claude/skills/spec-create-batch/scripts/numeros.py <cuantos>
```

**Acá el skill invierte una regla de `spec-create`, y hay que decirlo en voz alta.** Escribir un
spec suelto dice: *el número se reserva tarde, mirá `mapa.json` recién cuando vayas a crear la
carpeta, porque si hay otra sesión en paralelo el número que elegiste al empezar ya no es tuyo.*

En un lote esa regla **no se puede cumplir**: los N agentes escriben a la vez, así que si cada uno
mira el mapa cuando le toca, los N ven el mismo último número y eligen el mismo siguiente. La
colisión no da error —son carpetas distintas hasta que alguien las compara— y aparece recién en
`publicar_spec.py crear`, con la mitad del lote escrita.

La regla de allá y ésta protegen lo mismo —que dos cosas no se lleven el número— contra
concurrencias distintas: allá la de otra sesión, acá la de los N agentes propios. **Reservar
temprano y desde un solo lugar es lo que hace que el lote entero sea una sola sesión** frente al
mapa.

Dos cosas que el censo puede decir y hay que mirar:

- **Carpetas en disco sin fila en el mapa** — un spec escrito y sin publicar. Su número está
  tomado igual, y `publicar_spec.py crear` le va a abrir issue **a ella también** cuando el Paso 5
  corra, porque esa fase recorre el disco y no el lote. O se publica a propósito, o se saca de
  `specs/` antes de empezar. Lo que no se puede es ignorarla.
- **Filas sin carpeta** son sólo specs sin hidratar. Normal, y el censo no las lista.

**El número no se reusa aunque su spec esté `Descartado`.** Aparece en ramas, commits, comentarios
y citas de otros specs: reusarlo vuelve ambiguas todas esas referencias sin romper nada, que es la
clase de daño que no se descubre.

## Paso 4 — N agentes escritores

Lanzá los N en **un solo mensaje**, un `Agent` por spec. Más de ~6 conviene en tandas: el cuello
no es el reloj, es que el padre tiene que sostener los reportes para el Paso 5.

Cada uno recibe el preámbulo del Paso 1, **su número**, su pedido, las decisiones del Paso 2 que
le tocan, y el orden del lote. Y este contrato:

1. **Medir, y recién después escribir.** El `research.md` sale de correr algo: qué corriste y qué
   contestó. `python .claude/scripts/verificar.py` con el cambio mínimo aplicado, y contar qué
   nodo se pone en rojo y en cuántos archivos — **un número acá es lo que hace estimable el
   spec**. Más `rg` sobre `src/` y `test/`, y `rg --no-ignore` para `specs/`. Y **qué NO se
   mueve**, que es tan informativo como lo que sí: si `capas` no se mueve, el trabajo no cruza
   ninguna frontera.

   **Dos avisos sobre medir adentro de un lote**, y los dos son propios de esto:
   - **El hook te va a frenar el cambio mínimo, y la salida no es aplazar la medición.** Editar
     `src/` desde `staging` está bloqueado, y acá **no hay rama de feature todavía ni la va a
     haber**. Un `research.md` que dice «queda por medir» pone en rojo el nodo `harness` —lo
     verifica `test_convencion_de_specs.py`— y con razón: el plan entero se apoyaría en un número
     que nadie midió, y el spec **igual se publica**.

     **Los gates de este repo son puros, así que se los ejerce con entrada sintética en vez de
     mutando `src/`.** Es lo que ya hizo el research del 002: `gate_de_capas.py` y
     `gate_de_tests.py` reciben rutas y contenido, no un árbol de trabajo, así que la pregunta
     «¿qué se pone en rojo con este cambio?» se contesta contra un archivo del scratchpad. Lo
     mismo el resto: correr los nodos, leer, `rg`, un script de un solo uso que se corre y se
     borra.

     Y si de verdad **ninguna de esas vías alcanza**, eso no se anota: **se pregunta ahora**
     (descarga 4 de [`../shared/sin-deuda.md`](../shared/sin-deuda.md)) o el spec se escribe sin
     necesitar ese número. Un AC que depende de una medición imposible es un AC mal planteado.
   - **Declará contra qué base medís.** `staging`, o `staging` más los specs del lote que te
     preceden. Una medición sin base declarada es infalsificable en cuanto el lote se reordena —
     y el lote se reordena siempre.
2. **Los cuatro archivos** en `specs/<NNN>-<descripcion-kebab>/`: `spec.md`, `research.md`,
   `plan.md`, `tasks.md`. El formato y las cuatro desviaciones están en
   [`specs/README.md`](../../../specs/README.md).
3. **`**Origen:** #N` en el encabezado del `spec.md`** si el spec salda issues de deuda — antes
   del primer `##`, porque un `#12` suelto en la prosa no cuenta. La parsea `crear` y de ahí sale
   el campo del mapa que le deja al gate exigir el `Closes`. **Origen es lo que el spec SALDA, no
   lo que menciona**, y el Paso 2 ya decidió de quién es cada issue: no lo vuelvas a decidir.
4. **Cada criterio de aceptación tiene que ser falsable.** «El sistema de consecuencias funciona»
   no lo es; «con cuatro tareas cumplidas, `consecuencia()` devuelve `AVISO` y no `NINGUNA`» sí.
   Si un AC no se puede ver fallar, no verifica nada.
5. **Cada tarea tiene que poder cerrarla un agente**, y **cada tarea nombra el archivo que toca**,
   entre backticks. Lo primero lo verifica `test_convencion_de_specs.py`; lo segundo es lo que
   hace revisable el reparto del lote antes de lanzarlo, y sin eso el Paso 5 no puede cruzar nada.
   Nada de *a ojo*, *de oído*, *captura* ni *mirar la pantalla*: se vuelve verificable —un test de
   gdUnit4, un número medido, un valor que un gate lea— o no se anota.
6. **Las tareas son la totalidad.** Recorré cada AC y preguntá qué tarea lo cumple: un AC sin
   tarea no rompe ningún gate, no sale en ningún diff, y **no se hace nunca** — el spec se
   implementa entero, se mergea, y el AC sigue sin cumplirse con los seis nodos en verde.
7. **Nada se aplaza.** Ninguna sección que aplace —`## Seguimiento` y sus alias `## Pendientes`,
   `## Próximos pasos`, `## Deuda`—, ninguna casilla con `TODO` o «por ahora», ningún marcador
   para «esto lo mira una persona». Las verifica `test_convencion_de_specs.py`. **`## Fuera de
   alcance` sí va**: es una frontera, no una promesa — salvo que un AC tuyo dependa de lo
   excluido, y entonces entra al spec.
8. **Español**, y las reglas de capa puestas: una regla del juego va en `dominio/`, que es puro.
   Si el spec la ubica en `sistemas/`, en `ui/` o en una escena, **nace sin test** y ningún gate
   lo va a decir.

Y las cuatro cosas que **no** hace:

> **No corrés `publicar_spec.py`, ni `crear` ni `publicar`.** Las dos recorren el árbol entero,
> así que un agente que las corra publica también los specs que los otros están escribiendo a
> medias — y `crear` además escribe `specs/mapa.json`, que es un leer-modificar-escribir sobre un
> archivo compartido: N a la vez es una carrera con el registro adentro. Las corre el padre, una
> vez, en el Paso 5.
>
> **No tocás `specs/mapa.json`, no abrís rama, y no escribís fuera de tu carpeta** — ni `docs/`,
> ni `CLAUDE.md`, ni el spec del vecino. Lo que haga falta afuera vuelve como **edición
> propuesta**, con `path:línea` y el texto exacto.

Cada uno devuelve un reporte de **20–30 líneas**: qué mide su `research.md` y contra qué base, en
qué capa cae cada regla, cuántos AC y cuántas tareas, su `origen` si tiene, **la lista de archivos
de `src/` y de escenas que sus tareas nombran** —es con lo que el padre cruza en el Paso 5— y
**qué AC cubre cada tarea**, que es como el padre verifica que el `tasks.md` esté completo sin
releer los cuatro archivos.

## Paso 5 — Cruzar lo escrito, y publicar una sola vez

El padre no re-audita: cruza, y después publica. En este orden, y el orden importa.

1. **Cruzá lo escrito contra lo decidido en el Paso 2**, con la matriz del skill hermano — que ya
   sabe leer un `tasks.md` y no hay por qué duplicarlo:

   ```bash
   python .claude/skills/spec-review-batch/scripts/lote.py <NNN NNN ...>
   ```

   Tres cosas se miran acá y ninguna necesita leer los specs enteros: que ninguna
   **`<- ESCENA COMPARTIDA`** haya quedado sin orden declarado, que los archivos de `dominio/`
   compartidos sean los que el Paso 2 asignó a un dueño, y que ningún par de specs mueva el mismo
   número sin citarse. Descontá `verificar.py` y `specs/mapa.json`: los cita el ritual de cierre
   de todo `tasks.md` de este repo, así que salen compartidos en **todos** los lotes y no son
   aristas.

   Lo que aparezca acá se corrige **ahora**, en el `tasks.md` del spec que corresponda. Todavía es
   texto.
2. **Crear los issues, los N de una:**

   ```bash
   python .claude/scripts/publicar_spec.py crear
   ```

   **Los N antes de publicar ninguno, y no es una optimización.** Un spec del lote que cita a otro
   —lo normal, si el Paso 2 encontró una cadena— se publica traduciendo esa cita a la URL de su
   issue, y lo que no está en el mapa **se deja como estaba**: una ruta relativa a un directorio
   que está en el `.gitignore`, o sea un enlace muerto en el issue. Sin error y sin aviso. Por eso
   las dos fases existen, y por eso en un lote correr `crear` para todos antes de `publicar` para
   uno es la condición.
3. **Publicar los cuerpos:**

   ```bash
   python .claude/scripts/publicar_spec.py publicar
   ```

   Es idempotente —se puede volver a correr— y **el veredicto sale del código de salida, nunca de
   un grep de la salida**: un `| grep` que no matchea devuelve 1 y se traga la salida entera. Con
   `--dry` imprime qué issue tocaría sin tocarlo, y con un lote grande vale la pena mirarlo antes.
4. **Commitear el mapa, y sólo el mapa:**

   ```bash
   git add specs/mapa.json
   git commit && git push origin staging
   ```

   Es lo **único** del spec que se trackea. Las carpetas están en el `.gitignore` a propósito: el
   registro es el issue.

## Paso 6 — Reporte, y entregar el control

En este orden y en ~35 líneas más la tabla:

1. **Una tabla, una fila por spec:** `NNN`, título, issue, `origen`, cuántos AC y cuántas tareas,
   y contra qué base midió su `research.md`.
2. **Qué encontró el Paso 2 y qué se decidió** — el entregable propio de este skill. Incluidas las
   clases que dieron que no.
3. **Los pedidos que salieron del lote** y por qué: cuáles no necesitaban spec y por qué carril
   van, y cuáles se fundieron con otro.
4. **El orden del lote**, y **qué pares no se pueden paralelizar por escena compartida**. Eso es
   lo que va a leer quien lo implemente.
5. **La cobertura de los AC**: por spec, que cada criterio tenga una tarea que lo cumpla. Es la
   única regla de completitud que ningún gate verifica — un AC sin tarea no rompe nada y no se
   hace nunca.
6. **Si esta corrida corrigió un `SKILL.md`**, cuál y qué regla se le agregó.

**Lo que el reporte no puede tener es una lista de mediciones pendientes.** Si el hook frenó una
medición, la salida era entrada sintética contra los gates —que son puros— o replantear el AC que
la necesitaba; ver el Paso 4. Un `research.md` que declara una medición como no hecha pone en rojo
el nodo `harness`, así que **corré `python .claude/scripts/verificar.py --solo harness` antes de
publicar**: es mucho más barato que descubrirlo cuando el lote ya son N issues.

Y lo que queda para después, que **no es de este skill**:

- **Auditarlos**: `/spec-review-batch <los NNN>`. Este skill cruza lo grueso antes de escribir;
  ése cruza lo fino sobre lo escrito —un AC que otro spec del lote vuelve infalsificable— y los
  dos pases hacen falta. Corre barato: los specs todavía son texto.
- **Implementarlos**: `/spec-implement-batch`, que abre las ramas. **La rama la abre el
  implementador**, y por eso este skill termina en `staging`.

---

## Lo que no hace

- **No implementa, no abre ramas y no toca `src/`.**
- **No audita los specs que escribió.** Eso es `spec-review-batch`, y corre después.
- **No mueve estados en `specs/mapa.json`.** `crear` los pone en `Propuesto`; de ahí en adelante
  el estado lo deriva la Action en el push a `staging`, y el gate da rojo si alguien lo escribe a
  mano.
- **No decide qué deuda se promueve.** Lista, propone, y lo dice: cuál se promueve y en qué orden
  es una decisión, y una máquina que la tome inventa prioridades.

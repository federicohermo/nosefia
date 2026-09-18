# CLAUDE.md

Guía para Claude Code acá. Es un *cheat sheet*: lo que no se puede averiguar mirando un
archivo. El detalle vive en `docs/`, las reglas por capa en `.claude/rules/` —se cargan solas al
tocar sus archivos—, **el contrato de cada capacidad en `specs/`**, y **el trabajo planificado en
GitHub Issues**, que son el único plan.

## Qué es

**No se fía** — un juego de turno nocturno en un almacén. El empleado nuevo reparte un tiempo
limitado entre **cinco tareas obligatorias** del jefe —caja, reponer, registrar, limpiar y sacar
la basura— y **averiguar qué está pasando**. Atiende por una **ventanilla**, no más de dos
compradores por día. Al cierre se cuentan las tareas cumplidas y las consecuencias caen en tres
bandas: las 5 no pasa nada, 3 o 4 es un aviso, menos de 3 es grave. **Las tres pesan distinto
sobre el despido** —grave suma dos apercibimientos, aviso suma uno, una jornada completa los
reinicia a cero, y a los cuatro lo echan—, así que dos jornadas graves seguidas despiden y una
completa borra la deuda entera. **El número exacto sale del dominio y nunca de acá**, y no de un
solo archivo: los apercibimientos están en `src/dominio/reglas.gd`, el corte entre aviso y grave
en `src/dominio/empleo/consecuencia.gd`, y las cinco no están escritas en ninguna parte — salen de
recorrer `Tarea.Tipo`. **Un spec que discrepe con esos archivos es un hallazgo**, y quién está mal
lo decide el GDD: si el spec dice lo que el GDD pide, el que está mal es el código.

**La tensión central es aritmética: cada minuto investigando es un minuto que no se dedica a
las tareas.** Al evaluar una feature, la pregunta es si aprieta esa tensión — no si agrega
contenido.

El diseño vive en el **GDD de Notion**, documento vivo que manda sobre lo que este archivo
diga del juego. Acá está lo técnico.

**Stack:** Godot 4.7.2 · GDScript · gdUnit4 **6.2.1** · gdtoolkit 4.x · Python 3.11+ para el harness

## Comandos

```bash
python .claude/scripts/verificar.py             # EL comando: los siete nodos, en paralelo
python .claude/scripts/verificar.py --solo tdd  # uno solo
gdformat src test                               # arregla el formato, no sólo lo señala
```

Lo que hay que saber antes de abrir
[docs/guides/verificacion.md](./docs/guides/verificacion.md):

- **`verificar.py` es el nodo de convergencia**, y es lo que se corre antes de un PR:
  `lint ‖ formato ‖ capas ‖ tdd ‖ specs ‖ harness ‖ tests`. **La CI corre este script**, no la lista de
  nodos: enumerarlos allá sería un segundo lugar donde vive la lista.
- **Un nodo `salteado` NO es un nodo verde.** Cada salteo dice qué no miró, y vence: `tests` se
  saltea mientras no haya un solo `*_test.gd`, y con el primero **la falta de `GODOT_BIN` pasa a
  ser un rojo, no un salteo** —en Windows, el `_console.exe` y **fuera de OneDrive**—.
- **`gdformat` decide el formato.** No se discute en una revisión.
- **El veredicto sale del código de salida, nunca de un grep de la salida.** Un `| grep` que no
  matchea devuelve 1 y se traga la salida entera.

## Arquitectura

`src/` son cuatro capas, con **una sola dirección de dependencia**:

```text
dominio/  ←  sistemas/  ←  ui/  ←  escenas/
```

**`dominio/`** es puro —`RefCounted`/`Resource`, sin `Node`, sin `get_tree()`, sin
`_process`—: el turno, las tareas, el inventario, las consecuencias. **`sistemas/`** son los
`Node` y autoloads que lo hacen correr adentro del motor: traducen, **no deciden**. **`ui/`** es
el HUD, la computadora y la ventanilla. **`escenas/`** son los scripts pegados a un `.tscn`,
cáscara.

**La prueba de que algo va en `dominio/` es una sola: se puede ejercer sin levantar una
escena.** De ahí sale el resto del diseño — es lo que hace testeable a un juego de Godot, donde
el patrón por defecto (un `Node` gordo con la lógica en `_process`) sólo se puede probar jugando.

**La consecuencia, presente al escribir cualquier cosa: si una regla del juego termina en `ui/`
o en `escenas/`, nace sin test y ningún gate lo va a decir.** El arreglo no es testear la
pantalla: es bajar la regla al dominio.

Detalle en [docs/architecture/overview.md](./docs/architecture/overview.md).

## Reglas que valen en todo el repo

Las de cada capa se cargan solas (`.claude/rules/`), y el porqué de todas está en
[docs/guides/conventions.md](./docs/guides/conventions.md). Acá va la regla y **quién la verifica**.

Verificadas por una herramienta:

- **La dirección de dependencia entre capas** (`gate_de_capas.py`), y cuenta también **nombrar un
  `class_name` de otra capa** — la forma normal de escribir Godot, y no deja rastro en ningún
  import: por eso el gate indexa las clases en vez de mirar los `preload`.
- **Los nombres de subcarpeta de cada capa**, que son un conjunto cerrado (`gate_de_capas.py`,
  con `CARPETAS_POR_CAPA` de `lib/repo.py`). La mitad honesta es qué **no** verifica: **si un
  archivo está en la carpeta correcta, no lo puede decir** — eso es semántica y lo mira la
  revisión. El criterio de cada capa, en su `.claude/rules/`.
- **Todo `.gd` de `dominio/` y `sistemas/` tiene su test espejo** en `test/<capa>/<nombre>_test.gd`
  (`gate_de_tests.py`).
- **La forma de los contratos de capacidad, y el ancla AC↔test** (`gate_de_specs.py`, nodo
  `specs`): un código de tres letras por capacidad, ningún ID repetido, cada criterio nombrando
  una regla que existe, y **cada criterio de un spec `ratified` citado por un test** como
  `AC-<COD>-###`. Verifica la cita, no que el test ejerza el criterio. Sobre un `draft` cuenta
  cuántos faltan y lo dice.
- **Ningún test sin aserción, apagado (`skip(true)`, `assert_not_yet_implemented`) o con un
  nombre que hace que no corra.** Las cuatro reglas cierran la misma cosa: verde sin ejercer
  nada.
- **Formato, largo de línea (100), nombres y orden de declaraciones** (`gdformat`, `gdlint`).
- **A `src/` lo tocan tres prefijos de rama, más `staging`** —`feature/<issue>-<kebab>`,
  `bugfix/` y `hotfix/`—, y a `feature/` el hook le exige el número de su issue
  (`.claude/settings.json`, `gate_de_rama.py`). `main` es la única bloqueada. Lo que no toca
  `src/` se nombra por lo que toca: `harness/`, `docs/`, `ci/` —
  [ramas](./docs/infra/ramas.md).
- **Un skill es autocontenido: trae adentro todo lo que corre** (`test_copias_de_skills.py`).
  Ninguno alcanza `../otro-skill/`: uno que sale a buscar el archivo al de al lado deja de
  funcionar apenas viaja solo. El precio es la duplicación, y el gate la cobra: **una copia que
  difiere de su canónico en un byte es rojo**, y los canónicos se declaran en ese archivo.
- **Un doc dice la regla, no la lista** (`test_docs_no_enumeran_skills.py`), y el umbral es
  **tres nombres de skill en una misma línea**: una entrada del árbol que enumera su contenido
  caduca sola —ésa caducó cuatro veces—, mientras que la prosa que manda al lector a un skill
  por su nombre, o que contrasta uno con su variante en lote, es correcta y pasa.

Prosa — dependen de que la revisión las mire, y que no tengan verificador es deuda:

- **Tipado estático en toda firma**, `-> void` incluido.
- **Textos breves, claros y en español controlado**: frases cortas, una idea por frase y un
  término por concepto. Aplica a documentación, comentarios, specs y respuestas. Evitar
  repeticiones y abstracciones que el cambio no necesita.
- **Español en el contenido, inglés en los nombres de carpeta**, con una sola excepción
  deliberada: **el árbol de `src/` entero**, que no es estructura sino vocabulario del GDD. Las
  carpetas de `specs/` eran la segunda y dejaron de serlo: una capacidad se nombra en inglés,
  como cualquier otra carpeta, y su contenido va en español.
- **Los comentarios explican el porqué**, no el qué.
- **Un valor fijo vive una sola vez**, en un archivo de `src/dominio/`.
- **Un conjunto cerrado es un `enum`**, nunca un `String` suelto: `"limpar"` no rompe nada, el
  `if` simplemente no entra nunca.
- **Los borrados van en su propio commit**, para que revertirlos sea trivial.
- Las de GDScript —cero `print`, nada de `get_node("../../…")`— se cargan solas al tocar un
  `.gd`: `.claude/rules/`.

## TDD sin cobertura

Godot **no mide cobertura** y ninguna herramienta del ecosistema lo hace: lo reemplazan las
cuatro reglas del gate de tests. **Qué se pierde: el gate no sabe si un test ejerce una rama.**
Sabe si el archivo existe, si afirma algo y si va a correr. Es un piso, no un techo.

El ciclo: **el test primero**, contra la firma que todavía no existe, y se lo ve **fallar por
lo que se espera** —un `nonexistent function` no verifica nada, verifica que el archivo no
existe—; después lo mínimo para que pase; después limpiar, con el test de testigo.

Lo que hace testeable a un juego, y es la parte que no es sobre herramientas: **el tiempo y el
azar entran como parámetro.** Un dominio que lee el reloj del motor o sortea adentro no se puede
probar. [docs/guides/tdd.md](./docs/guides/tdd.md).

## Documentación

| Sección | Archivo | Cuándo consultarlo |
|---|---|---|
| Visión general | [docs/architecture/overview.md](./docs/architecture/overview.md) | Las cuatro capas, su dirección y qué el gate no puede ver |
| Estructura de directorios | [docs/architecture/directory-structure.md](./docs/architecture/directory-structure.md) | Dónde crear cada cosa |
| Inicio rápido | [docs/guides/quickstart.md](./docs/guides/quickstart.md) | Qué instalar, `GODOT_BIN`, qué correr |
| Verificación | [docs/guides/verificacion.md](./docs/guides/verificacion.md) | Los siete nodos, qué se saltea y hasta cuándo |
| TDD sin cobertura | [docs/guides/tdd.md](./docs/guides/tdd.md) | Qué reemplaza al umbral y qué se pierde |
| Convenciones | [docs/guides/conventions.md](./docs/guides/conventions.md) | El porqué de cada regla, y cuáles son prosa |
| Troubleshooting | [docs/guides/troubleshooting.md](./docs/guides/troubleshooting.md) | Errores reales ya pisados acá |
| Ramas | [docs/infra/ramas.md](./docs/infra/ramas.md) | `staging` integra, `main` entrega, y la carrera entre sus workflows |
| Despliegue | [docs/infra/despliegue.md](./docs/infra/despliegue.md) | Cada push a `main` deja una web jugable: los secretos, el par preset↔headers y por qué el `$?` del export no decide |
| Contratos de capacidad | [specs/README.md](./specs/README.md) | Las nueve capacidades, los tres estados y el ancla AC↔test. La forma, en `specs/_template/` |

**Trabajo planificado:** el contrato de cada capacidad vive en
`specs/<capability>/<capability>.md`, **trackeado y durable**, y **el plan es el issue**. El spec
dice qué tiene que ser cierto; el issue dice qué se toca esta vez, con qué límites de archivo y
con qué comandos se cierra. No hay `spec.md`, `research.md`, `plan.md` ni `tasks.md`, y no hay
mapa: el número de la rama es el del issue y lo asigna GitHub.

**El código contesta al spec, y nunca al revés.** Si el código no cumple un criterio, se corrige
el código. Si el criterio ya no describe lo que el juego tiene que hacer, eso es una decisión de
diseño y la toma una persona. **Nunca se ajusta el spec para que coincida con el código**: si
difieren, eso es el hallazgo.

**Y un issue no es un vertedero.** Un pedido de afuera entra como
[issue](https://github.com/federicohermo/nosefia/issues), y un contrato se reparte en issues. Lo
que **no** existe es abrir uno para **terminar** una corrida. La doctrina entera, que los seis
skills que escriben traen adentro: [sin-deuda.md](./.claude/skills/to-spec/sin-deuda.md) es la
copia canónica.

## Antes de un cambio grande

**Primero el contrato, después el issue, después el código**, y son tres decisiones distintas:

1. **Entrevistar** hasta que no quede nada supuesto en silencio — el skill `shape`. No escribe
   nada.
2. **Escribir el contrato** de la capacidad, con sus reglas `BR-<COD>-###` y sus criterios
   `AC-<COD>-###` — el skill `to-spec`. Entra por su propio PR, y **el merge es la aprobación**.
3. **Repartirlo en issues** con formato task-brief — el skill `spec-to-tickets`. El issue declara
   qué criterios entrega, qué archivos puede escribir, qué no se toca y qué comandos tienen que
   dar cero.

**Ahí termina planificar: la rama la abre el implementador**, y **lo bloquea un hook**, no la
buena voluntad. Un spec **no nombra archivos, clases ni escenas**: eso caduca con el refactor
siguiente, y entonces el contrato deja de ser el contrato.

**Qué NO necesita tocar un spec:** un refactor, un bug de motor o de configuración que no cambia
ninguna regla del juego, el arte, el audio, y todo lo que no toca `src/`.

## Las trampas de este repo

Las que ya costaron tiempo acá:

- **La salida en Windows sale en cp1252** en una tubería, y **cualquier acento tira el script
  abajo** — incluido el mensaje de bloqueo del hook. Por eso todo script de `.claude/scripts/`
  llama a `configurar()` de `lib/consola.py` antes de imprimir nada.
- **`Grep` no ve `.claude/`.** Es ripgrep: saltea los ocultos aunque se le apague el
  `.gitignore`, y contesta cero **sin decir que no miró**. Ahí va `rg --no-ignore --hidden`,
  **uno por línea y separados por `;`** — con `&&` corta en el primero sin match, también sin
  decirlo. `specs/` sí se ve: dejó de ser caché el día que el contrato pasó a ser durable.
- **`GODOT_BIN` declarada no es `GODOT_BIN` visible.** En Windows un proceso hereda el entorno de
  su padre y no lo relee del registro: una terminal abierta antes de declararla no la ve nunca —y
  abrir una pestaña del mismo host tampoco—, así que se cierra el host de la terminal o la
  sesión. El registro contesta la ruta correcta mientras el script dice que no la encuentra, que
  es lo que vuelve caro el diagnóstico.
- **Godot adentro de OneDrive no se puede ejecutar** si el archivo no está descargado: Windows
  contesta «el proveedor de archivos de nube no se está ejecutando», que no nombra ni a Godot ni
  a los tests.
- **Un `.tscn` no se mergea.** Un merge de tres vías sobre una escena no da un conflicto: da una
  escena corrupta. Dos specs que tocan la misma escena se ordenan, no se paralelizan.
- **El `.glb` se exporta apagando POR NOMBRE los modificadores `Array`**: son Geometry Nodes
  llamados así, no modificadores de tipo `ARRAY`, y apagar por tipo no apaga ninguno. Si
  quedan, los productos salen multiplicados, y el juego necesita una unidad porque
  `reposicion_manual.gd` apila `cupo()` copias. El síntoma es el 042-AC2 en rojo —dos productos
  vecinos se pisan—, que no nombra ni a Blender ni al modificador. El procedimiento y las
  medidas, en [test_modelo_actualizado.py](./.claude/scripts/tests/test_modelo_actualizado.py).
- **La caché de `.godot/imported/` declara verde un modelo que ya cambió.** Un `.glb` reexportado
  no se reimporta solo en una corrida headless, así que los tests comparan contra la malla
  anterior y pasan. Costó dos diagnósticos equivocados el 2026-09-15. Antes de creerle a un verde
  que dependa del modelo: borrar `.godot/imported/SEPT_JUEGOS_PROTOTIPO.glb-*` y correr
  `--import`.
- **Un verde de gdUnit4 puede ser una suite que no corrió.** Tiene tres escalones y los tres
  salen `ok`: una suite que no parsea se descarta en silencio, un `class_name` nuevo no existe
  hasta el `--import` siguiente, y un caso cuyo recurso falta sale `PASSED` por abortar antes de
  afirmar. El número que vale es el `Executed test suites: (N/N)` de la salida cruda. Los tres,
  con su medición, en [.claude/rules/tests.md](./.claude/rules/tests.md), que se carga sola al
  tocar un test.

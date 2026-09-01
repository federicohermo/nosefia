# CLAUDE.md

Guía para Claude Code en este repositorio. Es un *cheat sheet*: lo que no se puede averiguar
mirando un archivo. El detalle vive en `docs/`, las reglas por capa en `.claude/rules/` —se
cargan solas al tocar sus archivos—, y **el trabajo planificado y la deuda en GitHub Issues**:
`specs/mapa.json` es el mapa spec↔issue, y el porqué de cada decisión, un comentario en su
issue.

## Qué es

**No se fía** — un juego de turno nocturno en un almacén. El empleado nuevo reparte un tiempo
limitado entre **cinco tareas obligatorias** del jefe —caja, reponer, registrar, limpiar y sacar
la basura— y **averiguar qué está pasando**. Atiende por una **ventanilla**, no más de dos
compradores por día. Al cierre se cuentan las tareas cumplidas y las consecuencias caen en tres
bandas: las 5 no pasa nada, 3 o 4 es un aviso, menos de 3 es grave. **Las tres bandas pesan
distinto sobre el despido**: una jornada grave suma dos apercibimientos, una de aviso suma uno,
una jornada completa los reinicia a cero, y a los cuatro lo echan. O sea que **dos jornadas graves
seguidas despiden, una grave más dos avisos también, y cuatro de cuatro tareas también** — pero
tres de cuatro tareas no, y una jornada completa borra la deuda entera.

**La tensión central es aritmética: cada minuto investigando es un minuto que no se dedica a
las tareas.** Al evaluar una feature, la pregunta es si aprieta esa tensión — no si agrega
contenido.

El diseño vive en el **GDD de Notion**, que es documento vivo y manda sobre cualquier cosa que
diga este archivo sobre el juego. Acá está lo técnico.

**Stack:** Godot 4.4.1 · GDScript · gdUnit4 **5.1.1** · gdtoolkit 4.x · Python 3.11+ para el harness

---

## Comandos

```bash
python .claude/scripts/verificar.py             # EL comando: los seis nodos, en paralelo
python .claude/scripts/verificar.py --solo tdd  # uno solo
gdformat src test                               # arregla el formato, no sólo lo señala
```

Lo que hay que saber antes de abrir
[docs/guides/verificacion.md](./docs/guides/verificacion.md):

- **`verificar.py` es el nodo de convergencia**, y es lo que se corre antes de un PR:
  `lint ‖ formato ‖ capas ‖ tdd ‖ harness ‖ tests`. La CI corre **este script** y no la lista de
  nodos: enumerarlos allá sería un segundo lugar donde vive la lista.
- **Un nodo `salteado` NO es un nodo verde.** El reporte los distingue y cada salteo dice qué no
  miró. Si `tests` se saltea por falta de `GODOT_BIN`, la suite no corrió.
- **Hace falta `GODOT_BIN`**: en Windows el `_console.exe`, y **fuera de OneDrive**.
- **`gdformat` decide el formato.** No se discute en una revisión.
- **El veredicto sale del código de salida, nunca de un grep de la salida.** Un `| grep` que no
  matchea devuelve 1 y se traga la salida entera.

---

## Arquitectura

`src/` son cuatro capas, con **una sola dirección de dependencia**:

```text
dominio/  ←  sistemas/  ←  ui/  ←  escenas/
```

1. **`dominio/`** — puro: `RefCounted`/`Resource`, sin `Node`, sin `get_tree()`, sin `_process`.
   El turno, las tareas, el inventario, las consecuencias.
2. **`sistemas/`** — los `Node` y autoloads que hacen correr el dominio adentro del motor.
   Traducen; **no deciden**.
3. **`ui/`** — HUD, la computadora, la ventanilla.
4. **`escenas/`** — los scripts pegados a un `.tscn`. Cáscara.

**La prueba de que algo va en `dominio/` es una sola: se puede ejercer sin levantar una
escena.** De ahí sale todo el resto del diseño — es lo que hace testeable a un juego de Godot,
donde el patrón por defecto (un `Node` gordo con la lógica en `_process`) produce código que
sólo se puede probar jugando.

**La consecuencia, y es la que hay que tener presente al escribir cualquier cosa: si una regla
del juego termina en `ui/` o en `escenas/`, esa regla nace sin test y ningún gate lo va a
decir.** El arreglo no es testear la pantalla: es bajar la regla al dominio.

Detalle en [docs/architecture/overview.md](./docs/architecture/overview.md).

---

## Reglas que valen en todo el repo

Las de cada capa se cargan solas (`.claude/rules/`), y el porqué de todas está en
[docs/guides/conventions.md](./docs/guides/conventions.md). Acá va la regla y **quién la verifica**.

Verificadas por una herramienta:

- **La dirección de dependencia entre capas** (`gate_de_capas.py`), y cuenta también **nombrar un
  `class_name` de otra capa** — la forma normal de escribir Godot, y no deja rastro en ningún
  import: por eso el gate indexa las clases en vez de mirar los `preload`.
- **Todo `.gd` de `dominio/` y `sistemas/` tiene su test espejo** en `test/<capa>/<nombre>_test.gd`
  (`gate_de_tests.py`).
- **Ningún test sin aserción, apagado (`skip(true)`, `assert_not_yet_implemented`) o con un
  nombre que hace que no corra.** Las cuatro reglas cierran la misma cosa: verde sin ejercer
  nada.
- **Formato, largo de línea (100), nombres y orden de declaraciones** (`gdformat`, `gdlint`).
- **No se edita `src/` ni `docs/` sin un spec detrás de la rama** (el hook de
  `.claude/settings.json`).
- **Un skill es autocontenido: trae adentro todo lo que corre** (`test_copias_de_skills.py`).
  Ningún `SKILL.md` alcanza `../otro-skill/`, porque un skill es la unidad que se instala y uno
  que sale a buscar el archivo al de al lado deja de funcionar apenas viaja solo. El precio es la
  duplicación, y el gate la cobra: **una copia que difiere de su canónico en un byte es rojo**, y
  los canónicos están declarados en ese archivo.

Prosa — dependen de que la revisión las mire, y que no tengan verificador es deuda:

- **Tipado estático en toda firma**, `-> void` incluido.
- **Español en el contenido, inglés en los nombres de carpeta.** Comentarios, identificadores,
  commits, specs y docs en español —las excepciones son las del motor: `_ready`, `_process`—;
  las carpetas, en inglés. **Dos excepciones deliberadas:** las cuatro capas, que no son
  estructura sino vocabulario del juego, y las carpetas de spec, cuyo nombre **es** su título.
  `reportes/` es la única mal puesta, y arreglarla pide un spec: renombrarla toca `docs/`.
- **Los comentarios explican el porqué**, no el qué.
- **Un valor fijo vive una sola vez**, en un archivo de `src/dominio/`.
- **Un conjunto cerrado es un `enum`**, nunca un `String` suelto: `"limpar"` no rompe nada, el
  `if` simplemente no entra nunca.
- **Los borrados van en su propio commit**, para que revertirlos sea trivial.
- Las de GDScript —cero `print`, nada de `get_node("../../…")`— se cargan solas al tocar un
  `.gd`: `.claude/rules/`.

---

## TDD sin cobertura

Godot **no mide cobertura** y ninguna herramienta del ecosistema lo hace. El harness del que
sale éste sostenía el TDD con un umbral del 100 %; acá eso no existe, así que lo reemplazan las
cuatro reglas del gate de tests.

**Hay que decir qué se pierde: el gate no sabe si un test ejerce una rama.** Sabe si el archivo
existe, si el test afirma algo y si va a correr. Es un piso, no un techo.

El ciclo, y el orden importa:

1. **El test primero**, contra la firma que todavía no existe. Se corre y **falla** — y falla
   por lo que se espera: un `nonexistent function` no verifica nada, verifica que el archivo no
   existe.
2. Lo mínimo para que pase.
3. Limpiar, con el test en verde de testigo.

Lo que hace testeable a un juego, y es la parte que no es sobre herramientas: **el tiempo y el
azar entran como parámetro.** Un dominio que lee el reloj del motor o sortea adentro no se puede
probar. [docs/guides/tdd.md](./docs/guides/tdd.md).

---

## Documentación

| Sección | Archivo | Cuándo consultarlo |
|---|---|---|
| Visión general | [docs/architecture/overview.md](./docs/architecture/overview.md) | Las cuatro capas, su dirección y qué el gate no puede ver |
| Estructura de directorios | [docs/architecture/directory-structure.md](./docs/architecture/directory-structure.md) | Dónde crear cada cosa |
| Inicio rápido | [docs/guides/quickstart.md](./docs/guides/quickstart.md) | Qué instalar, `GODOT_BIN`, qué correr |
| Verificación | [docs/guides/verificacion.md](./docs/guides/verificacion.md) | Los seis nodos, qué se saltea y hasta cuándo |
| TDD sin cobertura | [docs/guides/tdd.md](./docs/guides/tdd.md) | Qué reemplaza al umbral y qué se pierde |
| Convenciones | [docs/guides/conventions.md](./docs/guides/conventions.md) | El porqué de cada regla, y cuáles son prosa |
| Troubleshooting | [docs/guides/troubleshooting.md](./docs/guides/troubleshooting.md) | Errores reales ya pisados acá |
| Ramas | [docs/infra/ramas.md](./docs/infra/ramas.md) | `staging` integra, `main` entrega, y la carrera entre sus workflows |
| Convención de specs | [specs/README.md](./specs/README.md) | El formato, los cuatro estados y el flujo |

**Trabajo planificado:** cada spec **es un issue**, y [specs/mapa.json](./specs/mapa.json) los
mapea. **Su `estado` lo deriva `mapa.yml`** en el push a `staging`: el gate prohíbe tocarlo dentro
del PR que lo justifica.

**Los issues son la ENTRADA del repo, nunca la salida.** Un pedido de afuera entra como
[issue](https://github.com/federicohermo/nosefia/issues) y `spec-create` lo drena hacia specs
(`deuda.py` lista qué hay). Lo que **no** existe es abrir uno para **terminar** una corrida:
ningún skill deja trabajo escrito para después, y un `tasks.md` tampoco puede registrarlo —el ítem
hereda el estado de su spec—. **Eso ahora es un rojo**: `test_convencion_de_specs.py` verifica la
casilla abierta en un spec `Implementado`, las secciones y tareas que aplazan, y las mediciones
declaradas como no hechas. La doctrina y su evidencia, que los ocho skills traen adentro:
[.claude/doctrina/sin-deuda.md](./.claude/doctrina/sin-deuda.md) es la copia canónica.

---

## Antes de un cambio grande

Los cuatro archivos (`spec` · `research` · `plan` · `tasks`), publicados como issue con
`publicar_spec.py crear` y `publicar`, y **sólo** `specs/mapa.json` commiteado a `staging`. **Ahí
termina abrir un spec: la rama la abre el implementador**, porque escribirlo y decidir
implementarlo son dos decisiones distintas y una rama entre las dos queda colgada. **Y lo bloquea
un hook**, no la buena voluntad. El flujo entero y **qué NO necesita spec**, en el skill
[spec-create](./.claude/skills/spec-create/SKILL.md).

`specs/[0-9]*/` está en el `.gitignore`: es una **caché** que se trae con
`hidratar_specs.py <NNN>`, y hace falta **en cada worktree**.

El `research.md` se escribe **midiendo, no suponiendo**: qué corriste y qué contestó. Uno que dice
«probablemente haya que tocar el HUD» es una intuición con formato de documento.

---

## Las trampas de este repo

Las cinco que ya costaron tiempo acá:

- **La salida en Windows sale en cp1252** cuando va a una tubería, y **cualquier acento tira el
  script abajo** — incluido el mensaje de bloqueo del hook. Por eso todo script de
  `.claude/scripts/` llama a `configurar()` de `lib/consola.py` antes de imprimir nada.
- **`Grep` no ve `specs/`.** Es ripgrep y respeta el `.gitignore`: contesta cero **sin decir
  que no miró**. Ahí va `rg --no-ignore`.
- **Y encadenar `rg` con `&&` se traga los que siguen.** Un `rg A && rg B && rg C` corta en el
  primero sin match —que devuelve 1— y **los otros dos no corren, sin decirlo**: la salida vacía
  se lee como «ninguno matcheó» cuando en realidad sólo se preguntó por el primero. Es la misma
  falla que el `| grep`, en la otra dirección. **Un `rg` por línea, separados por `;`, nunca por
  `&&`.** Medido el 2026-09-01 verificando los AC del 023 sobre tres specs de una.
- **Godot adentro de OneDrive no se puede ejecutar** si el archivo no está descargado: Windows
  contesta «el proveedor de archivos de nube no se está ejecutando», que no nombra ni a Godot ni
  a los tests.
- **Un `.tscn` no se mergea.** Un merge de tres vías sobre una escena no da un conflicto: da una
  escena corrupta. Dos specs que tocan la misma escena se ordenan, no se paralelizan.
- **Una suite de gdUnit4 que no parsea se descarta en silencio y `tests` sale VERDE.** Medido
  tres veces en el lote 001/002/004/007: una suite que hace `preload` de un archivo que todavía
  no existe —o sea, el estado normal del paso 1 del TDD— no corre, y gdUnit4 igual devuelve 0.
  `verificar.py` hace lo correcto, porque el veredicto es el código de salida, y aun así declara
  `ok`. **Un error de parseo en `dominio/` puede dejar el dominio entero sin correr con la CI en
  verde**, y las cuatro reglas del gate de tests no lo ven: el espejo existe, afirma y no está
  apagado. Mientras se hace TDD, el número que hay que mirar es el `Executed test suites: (N/N)`
  de la salida cruda contra la cantidad de `*_test.gd`, no el color del nodo.

  **Y tiene un segundo escalón, medido el 2026-09-01 implementando el 011:** crear el `.gd`
  no alcanza. Un `class_name` recién escrito **no existe para gdUnit4 hasta que se vuelve a
  correr `--import`**, porque no está en `global_script_class_cache.cfg`. El síntoma es
  **idéntico** al del archivo ausente —`Parse Error: Identifier "X" not declared`,
  `No test cases found`, `Exit code: 0`—, así que se lee como «todavía no lo escribí» cuando
  en realidad ya está en disco. Hay que re-importar **después de crear cada archivo con
  `class_name` nuevo**, no sólo una vez al abrir el worktree. Lo pisaron los dos carriles
  del lote 005/011/022/023 que crearon clases, cada uno perdiendo una vuelta.

  **Y el paso 1 del TDD miente todavía de una tercera forma, que es la peor: sale `PASSED`.**
  Cuando el recurso que el caso carga no existe, el error de script **aborta la función** y
  gdUnit4 no cuenta ninguna aserción fallida: el caso se reporta en verde por no haber llegado
  a afirmar nada. Medido el 2026-09-01 en el 023: con la escena todavía sin escribir, **4 de 5
  casos dieron `PASSED`** y sólo dio rojo el que afirmaba el tipo. O sea que el «falla por lo
  que se espera» del paso 1 **no se lee en el conteo de fallos**: se lee en el
  `ERROR: Failed loading resource` de la salida cruda.

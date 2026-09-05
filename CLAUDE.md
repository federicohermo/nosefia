# CLAUDE.md

Guía para Claude Code acá. Es un *cheat sheet*: lo que no se puede averiguar mirando un
archivo. El detalle vive en `docs/`, las reglas por capa en `.claude/rules/` —se cargan solas al
tocar sus archivos—, y **el trabajo planificado en GitHub Issues**, mapeados por
`specs/mapa.json`.

## Qué es

**No se fía** — un juego de turno nocturno en un almacén. El empleado nuevo reparte un tiempo
limitado entre **cinco tareas obligatorias** del jefe —caja, reponer, registrar, limpiar y sacar
la basura— y **averiguar qué está pasando**. Atiende por una **ventanilla**, no más de dos
compradores por día. Al cierre se cuentan las tareas cumplidas y las consecuencias caen en tres
bandas: las 5 no pasa nada, 3 o 4 es un aviso, menos de 3 es grave. **Las tres pesan distinto
sobre el despido** —grave suma dos apercibimientos, aviso suma uno, una jornada completa los
reinicia a cero, y a los cuatro lo echan—, así que dos jornadas graves seguidas despiden y una
completa borra la deuda entera. **El número exacto sale de `src/dominio/reglas.gd`, nunca de
acá**: un spec que discrepe con ese archivo está mal.

**La tensión central es aritmética: cada minuto investigando es un minuto que no se dedica a
las tareas.** Al evaluar una feature, la pregunta es si aprieta esa tensión — no si agrega
contenido.

El diseño vive en el **GDD de Notion**, documento vivo que manda sobre lo que este archivo
diga del juego. Acá está lo técnico.

**Stack:** Godot 4.7.2 · GDScript · gdUnit4 **6.2.1** · gdtoolkit 4.x · Python 3.11+ para el harness

## Comandos

```bash
python .claude/scripts/verificar.py             # EL comando: los seis nodos, en paralelo
python .claude/scripts/verificar.py --solo tdd  # uno solo
gdformat src test                               # arregla el formato, no sólo lo señala
```

Lo que hay que saber antes de abrir
[docs/guides/verificacion.md](./docs/guides/verificacion.md):

- **`verificar.py` es el nodo de convergencia**, y es lo que se corre antes de un PR:
  `lint ‖ formato ‖ capas ‖ tdd ‖ harness ‖ tests`. **La CI corre este script**, no la lista de
  nodos: enumerarlos allá sería un segundo lugar donde vive la lista.
- **Un nodo `salteado` NO es un nodo verde.** Cada salteo dice qué no miró. Si `tests` se
  saltea por falta de `GODOT_BIN` —en Windows el `_console.exe`, y **fuera de OneDrive**—, la
  suite no corrió.
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
- **Ningún test sin aserción, apagado (`skip(true)`, `assert_not_yet_implemented`) o con un
  nombre que hace que no corra.** Las cuatro reglas cierran la misma cosa: verde sin ejercer
  nada.
- **Formato, largo de línea (100), nombres y orden de declaraciones** (`gdformat`, `gdlint`).
- **No se edita `src/` ni `docs/` sin un spec detrás de la rama** (el hook de
  `.claude/settings.json`).
- **Un skill es autocontenido: trae adentro todo lo que corre** (`test_copias_de_skills.py`).
  Ninguno alcanza `../otro-skill/`: uno que sale a buscar el archivo al de al lado deja de
  funcionar apenas viaja solo. El precio es la duplicación, y el gate la cobra: **una copia que
  difiere de su canónico en un byte es rojo**, y los canónicos se declaran en ese archivo.

Prosa — dependen de que la revisión las mire, y que no tengan verificador es deuda:

- **Tipado estático en toda firma**, `-> void` incluido.
- **Español en el contenido, inglés en los nombres de carpeta**, con dos excepciones
  deliberadas: **el árbol de `src/` entero**, que no es estructura sino vocabulario del GDD, y
  las carpetas de spec, cuyo nombre **es** su título. `reportes/` es la única mal puesta, y
  arreglarla pide un spec: renombrarla toca `docs/`.
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
(`deuda.py` lista qué hay). Lo que **no** existe es abrir uno para **terminar** una corrida.
**Eso es un rojo**, y lo cobra `test_convencion_de_specs.py`: en un spec `Implementado`, **cada
criterio nombrado por un test** si es ≥ 030, y ninguna casilla abierta si es ≤ 029. La doctrina
entera, que los ocho skills traen adentro:
[sin-deuda.md](./.claude/skills/spec-create/sin-deuda.md) es la copia canónica.

## Antes de un cambio grande

Tres archivos (`spec` · `research` · `estrategia`) publicados como issue con
`publicar_spec.py crear` y `publicar`, y **sólo** `specs/mapa.json` commiteado a `staging`. **El
spec es un prompt, no un documento**, y el techo es ejecutable: 350 palabras de prosa, 300 en el
bloque de criterios, 500 en el research, 250 en la estrategia. Del **030** en adelante; los
≤ 029 son ADR en el formato viejo y no se reescriben.

**Ahí termina abrir un spec: la rama la abre el implementador**, porque escribirlo y decidir
implementarlo son dos decisiones distintas. **Y lo bloquea un hook**, no la buena voluntad. El
flujo entero y **qué NO necesita spec**, en [spec-create](./.claude/skills/spec-create/SKILL.md).

`specs/[0-9]*/` está en el `.gitignore`: es **caché**, se trae con `hidratar_specs.py <NNN>`, y
hace falta **en cada worktree**. Y el `research.md` se escribe **midiendo, no suponiendo**: qué
corriste y qué contestó.

## Las trampas de este repo

Las que ya costaron tiempo acá:

- **La salida en Windows sale en cp1252** en una tubería, y **cualquier acento tira el script
  abajo** — incluido el mensaje de bloqueo del hook. Por eso todo script de `.claude/scripts/`
  llama a `configurar()` de `lib/consola.py` antes de imprimir nada.
- **`Grep` no ve `specs/`.** Es ripgrep y respeta el `.gitignore`: contesta cero **sin decir que
  no miró**. Ahí va `rg --no-ignore`, **uno por línea y separados por `;`** — encadenarlos con
  `&&` corta en el primero sin match y los siguientes no corren, también sin decirlo.
- **Godot adentro de OneDrive no se puede ejecutar** si el archivo no está descargado: Windows
  contesta «el proveedor de archivos de nube no se está ejecutando», que no nombra ni a Godot ni
  a los tests.
- **Un `.tscn` no se mergea.** Un merge de tres vías sobre una escena no da un conflicto: da una
  escena corrupta. Dos specs que tocan la misma escena se ordenan, no se paralelizan.
- **Un verde de gdUnit4 puede ser una suite que no corrió.** Tiene tres escalones y los tres
  salen `ok`: una suite que no parsea se descarta en silencio, un `class_name` nuevo no existe
  hasta el `--import` siguiente, y un caso cuyo recurso falta sale `PASSED` por abortar antes de
  afirmar. El número que vale es el `Executed test suites: (N/N)` de la salida cruda. Los tres,
  con su medición, en [.claude/rules/tests.md](./.claude/rules/tests.md), que se carga sola al
  tocar un test.

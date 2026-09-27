# CLAUDE.md

Lo que no se puede averiguar mirando un archivo. El detalle vive en `docs/`, las reglas por capa
en `.claude/rules/` —se cargan solas al tocar sus archivos—, el contrato de cada capacidad en
`specs/`, y el plan de cada cambio en GitHub Issues.

## Qué es

**No se fía** es un juego de turno nocturno en un almacén. El empleado reparte un tiempo limitado
entre las tareas obligatorias y averiguar qué está pasando. **La tensión central es aritmética:
cada minuto investigando es un minuto que no va a las tareas.** Una feature se evalúa por si
aprieta esa tensión. Los números de la partida los declara `src/dominio/`, y no se citan acá. El
diseño vive en Notion: el **GDD** tiene la visión y el alcance, y la base «Features y sistemas»
el detalle de cada feature. El GDD manda sobre este archivo. Si un spec discrepa del código, lo
decide el GDD: si el spec dice lo que el GDD pide, el que está mal es el código.

**Stack:** Godot · GDScript · gdUnit4 · gdtoolkit · Python para el harness. Las versiones las
declaran `project.godot`, `addons/gdUnit4/plugin.cfg` y `.github/workflows/verify.yml`.

## Comandos

```bash
python .claude/scripts/verificar.py             # EL comando: todos los nodos, en paralelo
python .claude/scripts/verificar.py --solo tdd  # uno solo
python .claude/scripts/estructura.py            # el mapa del sistema, derivado del código
gdformat src test                               # arregla el formato, no sólo lo señala
```

- **`verificar.py` es el nodo de convergencia**, y se corre antes de cada PR. Sus nodos los
  declara `NODOS`, adentro del script. **La CI llama al script**, no a la lista.
- **Un nodo `salteado` NO es un nodo verde.** Cada salteo dice qué no miró y hasta cuándo vale.
  Sin `GODOT_BIN`, el nodo `tests` sale **rojo**. En Windows va el `_console.exe`, y **fuera de
  OneDrive**.
- **El veredicto sale del código de salida, nunca de un grep.** Un `| grep` sin match devuelve 1
  y se traga la salida entera.

Detalle: [verificación](./docs/guides/verificacion.md).

## El índice del código

**`nosefia-index`, registrado en `.mcp.json`.** Consultarlo **antes** de un `Grep` o un `Read`
para ubicar un símbolo, ver quién lo usa, saber qué se mueve si lo tocás o qué declara una
escena. `mapa_del_sistema` es la primera consulta de cualquier tarea. Un hook lo recuerda.

No hay nada que instalar ni que regenerar: no tiene dependencias y lee el árbol en cada
respuesta. Las herramientas y lo que **no** cubren, en [docs/guides/mcp.md](./docs/guides/mcp.md).

## Arquitectura

```text
dominio/  ←  sistemas/  ←  ui/  ←  escenas/
```

`dominio/` es puro: `RefCounted` y `Resource`, sin `Node`, sin `get_tree()`, sin `_process`.
`sistemas/` son los `Node` que lo hacen correr adentro del motor: traducen, no deciden. `ui/` es
la presentación. `escenas/` son los scripts pegados a un `.tscn`: cáscara.

**La prueba de que algo va en `dominio/` es una sola: se puede ejercer sin levantar una escena.**
Es lo que hace testeable a un juego de Godot, donde el patrón por defecto —un `Node` gordo con la
lógica en `_process`— sólo se prueba jugando.

**Una regla del juego que termina en `ui/` o en `escenas/` nace sin test, y ningún gate lo
dice.** El arreglo no es testear la pantalla: es bajar la regla al dominio.

**El árbol no se documenta: se deriva.** `estructura.py` imprime las capas, sus carpetas, el
grafo de referencias y el estado de cada capacidad. El criterio de cada carpeta vive en la regla
de su capa.

## Reglas que hay que saber antes de escribir

Cada una nombra quién la verifica. El porqué está en la
[constitución](./docs/architecture/constitution.md) y en las
[directrices](./docs/guides/conventions.md).

- **Una capa no nombra un `class_name` de una capa posterior.** No deja rastro en ningún import,
  y por eso `gate_de_capas.py` indexa las clases.
- **Una subcarpeta de capa sale de `CARPETAS_POR_CAPA`**, en `lib/repo.py`. Lo verifica
  `gate_de_capas.py`.
- **Todo `.gd` de `dominio/` y `sistemas/` tiene su test espejo en `test/<capa>/`.** Lo verifica
  `gate_de_tests.py`, que también frena un test sin aserción o apagado.
- **Cada criterio de un spec `ratified` lo cita un test como `AC-<COD>-###`.** Lo verifica
  `gate_de_specs.py`.
- **Toda declaración lleva tipo.** Lo verifica el motor: `project.godot` hace error del tipo
  faltante.
- **`gdformat` decide el formato**, y un hook lo corre después de editar un `.gd`. Nombres y
  largo de línea los verifica `gdlint`.
- **El prefijo de la rama decide si se puede tocar `src/`.** Lo verifica el hook
  `gate_de_rama.py`, y los prefijos viven ahí.
- **Un worktree se abre sólo en `.claude/worktrees/` del checkout principal.** Lo verifica el
  hook `gate_de_worktrees.py`.
- **Un `.tscn` no se mergea.** `.gitattributes` hace que el merge dé conflicto. Dos issues que
  tocan la misma escena se ordenan, no se paralelizan.

El gate de capas valida el **nombre** de la carpeta, no que el archivo esté en la correcta. El de
specs verifica la **cita**, no que el test ejerza el criterio. Lo que falta lo mira la revisión,
igual que las directrices sin verificador.

## TDD sin cobertura

Godot **no mide cobertura**. La reemplaza el gate de tests, que sabe si el archivo existe, si
afirma algo y si va a correr. **Lo que se pierde: el gate no sabe si un test ejerce una rama.**

El ciclo: **el test primero**, contra la firma que todavía no existe. Se lo ve **fallar por lo
que se espera**: un `nonexistent function` verifica que el archivo no existe, no el criterio.
Después, lo mínimo para que pase. Después, limpiar con el test de testigo.
[TDD sin cobertura](./docs/guides/tdd.md).

## Antes de un cambio

**Un issue no es un spec.** El issue es un plan chico y descartable: resuelve un problema
puntual, con límites y criterios propios, y se cierra con su PR. El spec es el contrato durable
de una funcionalidad. Un issue toca un spec sólo si cambia lo que el juego tiene que hacer.

0. **Traer el pedido de Notion**, si sale de ahí: las fichas con el diseño cerrado de «Features
   y sistemas» las trae el skill `features-to-issues`, que las deja apuntando a su issue.
1. **Entrevistar** si algo queda supuesto — el skill `shape`, que no escribe nada.
2. **Escribir el issue** con formato task-brief — el skill `to-issue`. Declara el tipo, si toca
   un spec, sus criterios, qué puede escribir, qué no se toca y qué comandos dan cero.
3. **Escribir el spec** sólo si el cambio crea, modifica o borra una funcionalidad — el skill
   `to-spec`, desde el issue o directo. Es el primer commit de la rama.

**Ahí termina planificar.** La rama la abre quien escribe su primer commit: `to-spec` si hay
spec, el implementador si no.

- **El código contesta al spec, nunca al revés.** Si el código no cumple un criterio, se corrige
  el código. Si el criterio ya no describe el juego, eso es una decisión de diseño y la toma una
  persona.
- **Un spec no nombra archivos, clases ni escenas.** Eso caduca con el refactor siguiente.
- **Un issue no es un vertedero.** Se abre para planificar un cambio, nunca para terminar una
  corrida. La doctrina: [sin-deuda.md](./.claude/skills/to-spec/sin-deuda.md).
- **Qué NO necesita spec:** un refactor, un bug que no cambia ninguna regla, una mejora de UI,
  arte, audio o rendimiento, y todo lo que no toca `src/`.

## Documentación

| Sección | Cuándo consultarlo |
|---|---|
| [Constitución](./docs/architecture/constitution.md) | Los principios no negociables. Cambiar uno pide un ADR |
| [Capacidades](./docs/architecture/capacidades.md) | Qué decide cada una y qué pasa entre ellas |
| [Decisiones](./docs/architecture/decisions/) | Qué se decidió, cuándo y por qué |
| [Inicio rápido](./docs/guides/quickstart.md) | Qué instalar, `GODOT_BIN`, qué correr |
| [Verificación](./docs/guides/verificacion.md) | Los nodos, qué se saltea y hasta cuándo |
| [TDD sin cobertura](./docs/guides/tdd.md) | Qué reemplaza al umbral y qué se pierde |
| [Directrices](./docs/guides/conventions.md) | Cómo se escribe el código y los docs, el lenguaje y el glosario |
| [Rendimiento](./docs/guides/rendimiento.md) | Cómo se mide y dónde queda el resultado |
| [Iluminación](./docs/guides/iluminacion.md) | Toda la luz está horneada: por qué, cómo se hornea y qué se commitea |
| [El índice MCP](./docs/guides/mcp.md) | Las herramientas de `nosefia-index`, y qué no cubren |
| [Ramas](./docs/infra/ramas.md) | `staging` integra, `main` entrega, y qué exige el hook |
| [Despliegue](./docs/infra/despliegue.md) | Cada push a `main` deja una web jugable |

## Las trampas de este repo

Las que no tienen gate, porque no se pueden verificar desde acá. Cada una nombra dónde vive
su arreglo.

- **`GODOT_BIN` declarada no es `GODOT_BIN` visible.** Una terminal abierta antes de declararla
  no la ve nunca. Se cierra el host de la terminal.
- **Godot adentro de OneDrive no se puede ejecutar** si el archivo no está descargado.
- **Un verde de gdUnit4 puede ser una suite que no corrió.** El número que vale es el
  `Executed test suites: (N/N)` de la salida cruda. Cómo leerlo, en
  [.claude/rules/tests.md](./.claude/rules/tests.md).

Y las del modelo, que no tienen síntoma legible:

- **El `.glb` tiene que traer UNA unidad de cada producto, y por dos caminos distintos.** Los
  modificadores `Array` se apagan **por nombre** —son Geometry Nodes llamados así, y apagar por
  tipo no apaga ninguno—, y la colección **`guia`**, donde viven las copias linkeadas, se
  excluye del view layer. Si cualquiera de las dos viaja, cada producto se dibuja dos veces: una
  horneada y otra por su `MultiMesh`. Las dos las hace `exportar_modelo.py`, y la colección
  queda visible en Blender.
- **Mover o renombrar arte rompe los enlaces del `.blend`, y ningún nodo lo ve.** Sus rutas son
  relativas al archivo, y el `.glb` lleva las texturas embebidas. El juego sigue idéntico, los
  nodos siguen verdes, y la escena se abre en magenta.
- **La caché de `.godot/imported/` declara verde un modelo que ya cambió.** Antes de creerle a un
  verde que dependa del modelo: borrar la caché del `.glb` y correr `--import`.

# CLAUDE.md

Lo que no se puede averiguar mirando un archivo. El detalle vive en `docs/`, las reglas por capa
en `.claude/rules/` —se cargan solas al tocar sus archivos—, el contrato de cada capacidad en
`specs/`, y el plan de cada entrega en GitHub Issues.

## Qué es

**No se fía** — un juego de turno nocturno en un almacén. El empleado reparte un tiempo limitado
entre **cinco tareas obligatorias** —caja, reponer, registrar, limpiar, sacar la basura— y
averiguar qué está pasando. Atiende por una ventanilla, hasta **dos compradores por noche**.

Al cierre, las tareas cumplidas caen en tres bandas: las 5 no pasa nada, 3 o 4 es aviso, menos de
3 es grave. **Las tres pesan distinto sobre el despido**: grave suma dos apercibimientos, aviso
suma uno, una jornada completa los reinicia, y a los cuatro lo echan. Dos noches graves seguidas
despiden; una noche impecable borra la deuda entera.

**La tensión central es aritmética: cada minuto investigando es un minuto que no se dedica a las
tareas.** Al evaluar una feature, la pregunta es si aprieta esa tensión.

**Ningún número de arriba se cita desde acá.** Salen del dominio: los apercibimientos de
`src/dominio/reglas.gd`, el corte de las bandas de `src/dominio/empleo/consecuencia.gd`, y las
cinco tareas de recorrer `Tarea.Tipo`.

El diseño vive en el **GDD de Notion**, que manda sobre lo que este archivo diga del juego. Si un
spec discrepa del código, eso es un hallazgo, y lo decide el GDD: si el spec dice lo que el GDD
pide, el que está mal es el código.

**Stack:** Godot 4.7.2 · GDScript · gdUnit4 **6.2.1** · gdtoolkit 4.x · Python 3.11+ para el harness

## Comandos

```bash
python .claude/scripts/verificar.py             # EL comando: los siete nodos, en paralelo
python .claude/scripts/verificar.py --solo tdd  # uno solo
python .claude/scripts/estructura.py            # el mapa del sistema, derivado del código
gdformat src test                               # arregla el formato, no sólo lo señala
```

- **`verificar.py` es el nodo de convergencia**, y se corre antes de cada PR:
  `lint ‖ formato ‖ capas ‖ tdd ‖ specs ‖ harness ‖ tests`. **La CI llama al script**, no a la
  lista: enumerarla allá sería un segundo lugar donde vive.
- **Un nodo `salteado` NO es un nodo verde.** Cada salteo dice qué no miró y hasta cuándo vale.
  `tests` se saltea mientras no haya un `*_test.gd`; desde el primero, la falta de `GODOT_BIN` es
  **rojo**. En Windows va el `_console.exe`, y **fuera de OneDrive**.
- **El veredicto sale del código de salida, nunca de un grep.** Un `| grep` sin match devuelve 1
  y se traga la salida entera.
- **`gdformat` decide el formato.** No se discute en una revisión.

Detalle: [verificación](./docs/guides/verificacion.md).

## El índice del código

**`nosefia-index`, registrado en `.mcp.json`.** Consultarlo **antes** de un `Grep` o un `Read`
para ubicar un símbolo, ver quién lo usa, saber qué se mueve si lo tocás o qué declara una
escena. `mapa_del_sistema` es la primera consulta de cualquier tarea.

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
De ahí sale el resto del diseño. Es lo que hace testeable a un juego de Godot, donde el patrón
por defecto —un `Node` gordo con la lógica en `_process`— sólo se prueba jugando.

**La consecuencia, presente al escribir cualquier cosa: una regla del juego que termina en `ui/`
o en `escenas/` nace sin test, y ningún gate lo dice.** El arreglo no es testear la pantalla: es
bajar la regla al dominio.

**El árbol no se documenta: se deriva.** `estructura.py` imprime las capas, sus carpetas, el
grafo de referencias y el estado de cada capacidad. El criterio de cada carpeta vive en la regla
de su capa.

## Reglas que valen en todo el repo

El porqué de cada una está en [convenciones](./docs/guides/conventions.md). Acá va la regla y
quién la verifica.

**Verificadas por una herramienta:**

| Regla | Quién |
|---|---|
| La dirección de dependencia entre capas, contando **nombrar un `class_name` de otra capa** — que no deja rastro en ningún import, y por eso el gate indexa las clases | `gate_de_capas.py` |
| Los nombres de subcarpeta de cada capa, que son un conjunto cerrado | `gate_de_capas.py`, con `CARPETAS_POR_CAPA` |
| Todo `.gd` de `dominio/` y `sistemas/` con su test espejo en `test/<capa>/<nombre>_test.gd` | `gate_de_tests.py` |
| Ningún test sin aserción, apagado, o con un nombre que hace que no corra | `gate_de_tests.py` |
| La forma de los contratos, y **cada criterio de un spec `ratified` citado por un test** como `AC-<COD>-###` | `gate_de_specs.py` |
| Formato, largo de línea (100), nombres y orden de declaraciones | `gdformat`, `gdlint` |
| Que a `src/` sólo lo toquen `feature/<issue>-<kebab>`, `bugfix/` y `hotfix/`, más `staging` | el hook, `gate_de_rama.py` |
| Que un skill traiga adentro todo lo que corre, copia por copia | `test_copias_de_skills.py` |
| Que un doc diga la regla y no la lista de los skills | `test_docs_no_enumeran_skills.py` |

**La mitad honesta de dos de ellas:** el gate de capas valida el **nombre** de la carpeta y no
que el archivo esté en la correcta; el de specs verifica la **cita** y no que el test ejerza el
criterio. Las dos son un piso, y lo que falta lo mira la revisión.

**Prosa — las mira la revisión, y que no tengan verificador es deuda:**

- **Tipado estático en toda firma**, `-> void` incluido.
- **Español controlado**, con las diez reglas y el glosario en
  [convenciones](./docs/guides/conventions.md). Aplica a docs, comentarios, specs y respuestas.
- **Español en el contenido, inglés en los nombres de carpeta.** La única excepción es el árbol
  de `src/`, que no es estructura sino vocabulario del GDD.
- **Los comentarios explican el porqué**, no el qué.
- **Un valor fijo vive una sola vez**, en un archivo de `src/dominio/`.
- **Un conjunto cerrado es un `enum`.** Un `String` suelto no rompe nada: el `if` no entra nunca.
- **Los borrados van en su propio commit**, para que revertirlos sea trivial.

## TDD sin cobertura

Godot **no mide cobertura**, y ninguna herramienta del ecosistema lo hace. La reemplazan las
cuatro reglas del gate de tests, que saben si el archivo existe, si afirma algo y si va a correr.
**Lo que se pierde: el gate no sabe si un test ejerce una rama.**

El ciclo: **el test primero**, contra la firma que todavía no existe, y se lo ve **fallar por lo
que se espera** —un `nonexistent function` verifica que el archivo no existe, no el criterio—;
después lo mínimo para que pase; después limpiar, con el test de testigo.

**El tiempo y el azar entran por parámetro.** Un dominio que lee el reloj del motor o sortea
adentro no se puede probar. [TDD sin cobertura](./docs/guides/tdd.md).

## Antes de un cambio grande

Primero el contrato, después el issue, después el código. Son tres decisiones distintas:

1. **Entrevistar** hasta que no quede nada supuesto en silencio — el skill `shape`, que no
   escribe nada.
2. **Escribir el contrato** de la capacidad, con sus reglas `BR-<COD>-###` y sus criterios
   `AC-<COD>-###` — el skill `to-spec`. Entra por su PR, y el merge es la aprobación.
3. **Repartirlo en issues** con formato task-brief — el skill `spec-to-tickets`. Cada issue
   declara qué criterios entrega, qué puede escribir, qué no se toca y qué comandos dan cero.

**Ahí termina planificar: la rama la abre el implementador**, y lo bloquea un hook.

- **El código contesta al spec, nunca al revés.** Si el código no cumple un criterio, se corrige
  el código. Si el criterio ya no describe el juego, eso es una decisión de diseño y la toma una
  persona.
- **Un spec no nombra archivos, clases ni escenas.** Eso caduca con el refactor siguiente, y ahí
  el contrato deja de ser el contrato.
- **Un issue no es un vertedero.** Se abre para planificar una entrega, nunca para terminar una
  corrida. La doctrina, que los seis skills que escriben traen adentro:
  [sin-deuda.md](./.claude/skills/to-spec/sin-deuda.md).
- **Qué NO necesita spec:** un refactor, un bug de motor o de configuración que no cambia ninguna
  regla, el arte, el audio, y todo lo que no toca `src/`.

## Documentación

| Sección | Cuándo consultarlo |
|---|---|
| [Constitución](./docs/architecture/constitution.md) | Los principios no negociables. Cambiar uno pide un ADR |
| [Capacidades](./docs/architecture/capacidades.md) | Qué decide cada una y qué pasa entre ellas |
| [Decisiones](./docs/architecture/decisions/) | Qué se decidió, cuándo y por qué |
| [Inicio rápido](./docs/guides/quickstart.md) | Qué instalar, `GODOT_BIN`, qué correr |
| [Verificación](./docs/guides/verificacion.md) | Los siete nodos, qué se saltea y hasta cuándo |
| [TDD sin cobertura](./docs/guides/tdd.md) | Qué reemplaza al umbral y qué se pierde |
| [Convenciones](./docs/guides/conventions.md) | El porqué de cada regla, el lenguaje y el glosario |
| [Rendimiento](./docs/guides/rendimiento.md) | Cómo se mide, y contra qué números |
| [El índice MCP](./docs/guides/mcp.md) | Las herramientas de `nosefia-index`, y qué no cubren |
| [Troubleshooting](./docs/guides/troubleshooting.md) | Errores reales ya pisados acá |
| [Ramas](./docs/infra/ramas.md) | `staging` integra, `main` entrega, y qué exige el hook |
| [Despliegue](./docs/infra/despliegue.md) | Cada push a `main` deja una web jugable |

## Las trampas de este repo

El síntoma literal y el arreglo están en [troubleshooting](./docs/guides/troubleshooting.md).
Esto es la lista para reconocerlas.

- **La salida en Windows sale en cp1252** en una tubería, y cualquier acento tira el script
  abajo. Por eso todo script llama a `configurar()` antes de imprimir.
- **`Grep` no ve `.claude/`**: ripgrep saltea los ocultos aunque se le apague el `.gitignore`. Va
  `rg --no-ignore --hidden`, **un patrón por línea y separados por `;`**. Con `&&` corta en el
  primero sin match, sin decirlo.
- **`GODOT_BIN` declarada no es `GODOT_BIN` visible.** Una terminal abierta antes de declararla
  no la ve nunca. Se cierra el host de la terminal.
- **Godot adentro de OneDrive no se puede ejecutar** si el archivo no está descargado.
- **Un `.tscn` no se mergea.** Un merge de tres vías sobre una escena da una escena corrupta, no
  un conflicto. Dos issues que tocan la misma escena se ordenan, no se paralelizan.
- **Un verde de gdUnit4 puede ser una suite que no corrió**, por tres caminos que salen `ok`. El
  número que vale es el `Executed test suites: (N/N)` de la salida cruda —
  [.claude/rules/tests.md](./.claude/rules/tests.md).

Y dos del modelo, que no tienen síntoma legible:

- **El `.glb` se exporta apagando POR NOMBRE los modificadores `Array`**: son Geometry Nodes
  llamados así, y apagar por tipo no apaga ninguno. Si quedan, los productos salen multiplicados.
- **La caché de `.godot/imported/` declara verde un modelo que ya cambió.** Costó dos
  diagnósticos equivocados el 2026-09-15. Antes de creerle a un verde que dependa del modelo:
  borrar la caché del `.glb` y correr `--import`.

Las dos, con su procedimiento y sus medidas, en
[test_modelo_actualizado.py](./.claude/scripts/tests/test_modelo_actualizado.py).

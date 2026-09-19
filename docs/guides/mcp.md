# El índice estructural: `nosefia-index`

Un servidor MCP local, registrado en `.mcp.json`. Expone el repo —código, escenas, tests y
assets— como herramientas. Existe para gastar menos consultas explorando: **una pregunta en
vez de cinco `Grep` y tres `Read`**.

Está adaptado del `inventario-index` de los repos de referencia, con lo que aplica a un juego de
Godot y no a un monorepo de funciones.

## No hay nada que instalar ni que regenerar

```bash
python mcp-server/servidor.py    # lo levanta Claude Code, no se corre a mano
```

Sin `install`, sin `build` y **sin un índice en disco**. Las dos decisiones tienen el mismo
motivo, y las dos se apartan de la referencia:

- **Sin dependencias.** El servidor de la referencia es TypeScript con el SDK oficial y su propio
  `package.json`. Acá la regla del harness es que `python archivo.py` alcance en un clone recién
  hecho, y MCP sobre stdio es JSON-RPC con un objeto por línea: son ochenta líneas de biblioteca
  estándar. A cambio no hay un `install` que correr por worktree ni un `dist/` que se pueda
  separar de su fuente.
- **Sin índice.** La referencia compila a `.index/` y cada respuesta declara con qué commit se
  generó, porque un índice envejece: un archivo nuevo es invisible y un símbolo renombrado
  conserva el nombre viejo. Acá `src/` son 96 `.gd` y 18 `.tscn`, así que leer el árbol cuesta
  milisegundos y **cada respuesta mira el disco de ahora**. Se pierde el paso que hay que
  acordarse de correr, y con él el modo de falla entero.

## Las herramientas

**`mapa_del_sistema` es la primera consulta de cualquier tarea.** Las otras contestan una
pregunta puntual.

| Herramienta | Contesta |
|---|---|
| `mapa_del_sistema` | las capas, qué puede referenciar cada una, y las capacidades con su estado |
| `buscar_simbolo` | un `class_name`, función o constante por parte de su nombre |
| `quien_usa` | quién nombra un símbolo, con archivo y línea |
| `contexto_de_archivo` | qué declara un `.gd`, a quién nombra, quién lo nombra, su test espejo |
| `impacto_de_tocar` | qué se mueve si lo tocás, incluidas las escenas que lo cuelgan |
| `contexto_de_escena` | los nodos de un `.tscn`, sus scripts, sus instancias y su `node_paths` |
| `quien_instancia` | qué escenas instancian a una escena |
| `criterio` | un `AC-<COD>-###`: su texto, su regla, y qué test lo cita |
| `donde_vive_el_numero` | dónde está declarada una constante de balance y quién la lee |
| `sin_test` | qué script no tiene espejo y qué criterio no tiene cita |
| `contexto_de_test` | qué prueba una suite: sus casos, qué criterios cita, qué clases ejerce |
| `tests_de` | qué suites prueban un `.gd`, y si le falta el espejo |
| `contexto_de_asset` | quién referencia un asset, por las cuatro formas que existen acá |
| `assets_sin_referencia` | qué asset no alcanza ninguna de las cuatro |

## Lo que la descripción de cada una no dice

- **`quien_usa` distingue tres respuestas**: tiene consumidores, existe sin ninguno, o no existe.
  La del medio puede ser código muerto — o algo que sólo se usa desde un `.tscn` por `@export`,
  y eso lo contesta `contexto_de_escena`.
- **Las cuatro que miran símbolos ignoran los comentarios.** Un `class_name` nombrado en prosa no
  es un uso. La excepción es `criterio`: la cita de un AC **vive en un comentario**, así que ésa
  busca sobre el texto crudo.
- **`contexto_de_escena` marca los `@export` de tipo `Node` que no están en el `node_paths`.** Es
  el modo de falla que carga la escena sin un solo error y mata el juego en el primer cuadro. No
  todos son un bug: uno que se asigna por código no va en la lista.
- **`quien_instancia` es la consulta de paralelizar.** Un `.tscn` no se mergea, así que dos
  issues que tocan la misma escena se ordenan.
- **`sin_test` lista, no juzga.** El veredicto lo dan `gate_de_tests.py` y `gate_de_specs.py`.
- **Las dos de assets miran cuatro formas de referencia, y la cuarta es la que importa.** Un
  `.glb` lleva sus texturas **embebidas**: el nombre vive en su chunk JSON y Godot las
  extrae a `<stem>_<name>`, con el índice de la imagen pegado atrás cuando dos comparten
  nombre. No hay `res://`, no hay `uid://`, y el nombre del archivo tampoco está como cadena
  adentro del binario. Medirlo con las otras tres da treinta huérfanas que no lo son —eso ya
  se borró una vez, y la reimportación cayó con `Failed loading resource`.
- **`assets_sin_referencia` sigue siendo una sospecha.** Cubre lo que este repo usa hoy; la
  quinta forma que aparezca no está. El que decide es el rojo de una corrida de `--import`.

## Qué no cubre

- **Texto que no es un símbolo**: un mensaje que ve el jugador, una ruta, un `uid://`. Va `rg`.
- **Lo que un método hace por dentro.** Dice dónde está y quién lo nombra.
- **Los autoloads**, que son globales por construcción y no dejan referencia.
- **Las llamadas en ejecución.** Sin consumidores no hay prueba de código muerto: hay una
  sospecha.

## Que no contradiga al gate

El índice de `class_name` sale de `lib/capas.py`, **el mismo que usa `gate_de_capas.py`**. No hay
un segundo indexador, y eso no es economía: una herramienta que contesta distinto que el gate se
deja de mirar el mismo día. Ya pasó con `estructura.py`, que en su primera versión dibujaba tres
flechas que el gate pone en rojo.

Sus tests corren en el nodo `harness` de `verificar.py`.

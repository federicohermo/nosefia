# Documentación técnica — No se fía

Juego de turno nocturno en un almacén: el empleado nuevo reparte un tiempo limitado entre las
tareas que le dejó el jefe y averiguar qué está pasando. Godot 4.7, GDScript, equipo Manada.

El diseño —pitch, pilares, core loop, sistemas, alcance por entrega— vive en el **Game Design
Document de Notion**, que es documento vivo. Acá está lo **técnico**: cómo está armado el
repo, cómo se verifica y cómo se trabaja.

## Índice

### Arquitectura
- [Visión general](./architecture/overview.md) — Las cuatro capas, su dirección de dependencia y por qué
- [Estructura de directorios](./architecture/directory-structure.md) — Dónde va cada cosa

### Guías
- [Inicio rápido](./guides/quickstart.md) — Qué instalar, qué declarar y qué correr
- [Verificación](./guides/verificacion.md) — `verificar.py` entero: los seis nodos y por qué cada uno tiene la forma que tiene
- [TDD sin cobertura](./guides/tdd.md) — Cómo se sostiene la disciplina de tests en un motor que no mide cobertura
- [Convenciones](./guides/conventions.md) — GDScript, capas, nombres, comentarios
- [Troubleshooting](./guides/troubleshooting.md) — Errores reales ya pisados en este repo

### Infraestructura
- [Ramas](./infra/ramas.md) — `staging` integra, `main` es lo que se entrega, y el gate que lo sostiene

### Trabajo planificado
- [specs/README.md](../specs/README.md) — La convención y el flujo
- [specs/mapa.json](../specs/mapa.json) — El mapa spec↔issue y el estado de cada uno
- [GitHub Issues](https://github.com/federicohermo/nosefia/issues) — Cada spec **es** un issue; y lo registrado que todavía no tiene spec, también

## El stack

| Qué | Versión | Para qué |
|---|---|---|
| Godot | 4.7.2 | El motor. Renderer **Forward Plus** |
| GDScript | — | Todo el juego. Sin C#, sin GDExtension |
| gdUnit4 | **6.2.1** | Tests, vendorizado en `addons/gdUnit4/`. Se mueve junto con Godot — ver abajo |
| gdtoolkit | 4.x | `gdlint` y `gdformat`. Se instala con pip |
| Python | 3.11+ | Las herramientas del harness, **sin dependencias** |

### Los dos números se mueven juntos, y no se pueden mover de a uno

**El motor y el addon de tests son un solo pin.** gdUnit4 declara una versión mínima de Godot y
Godot rompe la sintaxis vieja del addon, así que cada serie del addon vive dentro de una ventana
de versiones del motor y afuera **no compila**. La combinación vigente es **Godot 4.7.2 con
gdUnit4 6.2.1**, y moverla es un cambio para **todo el equipo** y para la CI a la vez, así que
va con su spec.

Las dos direcciones del desajuste están medidas, y **las dos salen con código 0**, que es lo que
las hace difíciles de ver. Los síntomas literales de cada una están en
[troubleshooting](./guides/troubleshooting.md):

- **addon 5.x bajo motor 4.7** — la 5.x llama a `FileAccess.get_as_text(true)`, que en 4.7 no
  acepta argumentos, y declara un `func call(arg0=null, …)` cuya firma 4.7 valida contra
  `Object.call`. El plugin del editor no carga.
- **addon 6.x bajo motor 4.4** — la 6.x pide **Godot 4.5 o más** y usa `...varargs`, que 4.4 ni
  siquiera parsea. Es el que ve quien hace `pull` y sigue en 4.4.x.

Y hay un dato que le va a hacer falta al próximo que mire: **la 6.2.1 declara compatibilidad
hasta 4.7.1 y no nombra a 4.7.2.** Se eligió 4.7.2 igual, y la evidencia de que la combinación
funciona en *este* proyecto es una medición y no la tabla: 23/23 suites y 171/171 casos en
verde, sin tocar un test. El plan B, si algo aparece, es bajar a **4.7.1** —que sí está en la
matriz— sin tocar el addon.

La versión que baja la CI vive en el `env: GODOT_VERSION` de `.github/workflows/verify.yml`, y
la de cada máquina en `GODOT_BIN`. La tabla «GdUnit4 Version / Godot minimal required» del
README de gdUnit4 es la fuente — **no** los badges de «Supported Godot Versions», que listan las
versiones que el proyecto soporta *en alguna* de sus series y hacen creer que la última sirve
para todas.

## Los comandos

```bash
python .claude/scripts/verificar.py             # el nodo de convergencia: correlo antes de un PR
python .claude/scripts/verificar.py --solo tests  # sólo la suite de gdUnit4
gdformat src test                               # arregla el formato en vez de sólo señalarlo

python .claude/scripts/publicar_spec.py crear   # publica los specs nuevos como issues
python .claude/scripts/hidratar_specs.py <NNN>  # trae un spec desde su issue
python .claude/scripts/deuda.py                 # qué issues no reclama ningún spec
python .claude/scripts/derivar_mapa.py          # el estado del mapa, derivado de los PR
```

## Variables de entorno

**Una sola**: `GODOT_BIN`, con la ruta al ejecutable de Godot. Sin ella el nodo `tests` no
puede correr — y lo dice, con la instrucción para declararla. Cómo, en el
[inicio rápido](./guides/quickstart.md).

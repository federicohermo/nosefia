# Documentación técnica — No se fía

Juego de turno nocturno en un almacén: el empleado nuevo reparte un tiempo limitado entre las
tareas que le dejó el jefe y averiguar qué está pasando. Godot 4.4, GDScript, equipo Manada.

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
| Godot | 4.4.1 | El motor. Renderer **Forward Plus** |
| GDScript | — | Todo el juego. Sin C#, sin GDExtension |
| gdUnit4 | **5.1.1** | Tests, vendorizado en `addons/gdUnit4/`. La serie 5.x es la de Godot 4.4 — ver abajo |
| gdtoolkit | 4.x | `gdlint` y `gdformat`. Se instala con pip |
| Python | 3.11+ | Las herramientas del harness, **sin dependencias** |

### gdUnit4 va en la serie 5.x, y no es «una versión atrás»

**gdUnit4 6.x pide Godot 4.5 o más.** La serie para Godot 4.3, 4.4 y 4.4.1 es la **5.x**, y eso
está en la tabla «GdUnit4 Version / Godot minimal required» del README del proyecto — **no** en
los badges de «Supported Godot Versions» de más arriba, que listan las versiones que el proyecto
soporta *en alguna* de sus series y hacen creer que la última sirve para todas.

Instalar la 6.2.1 sobre Godot 4.4.1 **no falla al instalar**: falla al correr, con un
`Could not resolve class "GdUnitCSIMessageWriter"` y el proceso colgado hasta el timeout.

Las dos formas de salir de esto el día que haga falta:

- Quedarse en Godot 4.4.x → gdUnit4 **5.x**. Es lo que hay hoy.
- Subir Godot a 4.5+ → gdUnit4 6.x. Es un cambio para **todo el equipo** y para la CI a la vez
  (`GODOT_VERSION` en `verify.yml`), así que va con su spec.

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

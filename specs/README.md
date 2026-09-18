# Specs

**Un contrato durable por capacidad**, y el código contesta a él. `specs/<capability>/<capability>.md`
es la fuente de verdad del comportamiento; el código que se desvía es el hallazgo, no el spec.

Formato de referencia: *spec-anchored agentic development*. La forma la fija
[`_template/capability-spec.md`](./_template/capability-spec.md), y las reglas de edición,
[`.claude/rules/specs.md`](../.claude/rules/specs.md), que se carga sola al tocar este árbol.

## Una capacidad no es una capa

Una capacidad es una tajada de lo que el juego **hace**: atender la ventanilla, reponer la
góndola, arrastrar el legajo entre noches. No es `dominio/`, no es una clase y no es una
pantalla. El nombre de la carpeta va en inglés; el contenido, en español, incluidas las palabras
EARS y DADO/CUANDO/ENTONCES.

| Capacidad | Qué decide |
|---|---|
| [`shift-cycle`](./shift-cycle/shift-cycle.md) | cuánto dura la noche y en qué se gasta |
| [`employment-record`](./employment-record/employment-record.md) | apercibimientos, despido y los cinco días |
| [`counter-service`](./counter-service/counter-service.md) | la ventanilla: quién viene, qué paga |
| [`store-stock`](./store-stock/store-stock.md) | depósito, góndola y los productos del día |
| [`store-cleanup`](./store-cleanup/store-cleanup.md) | manchas y bolsas: el local en orden |
| [`investigation`](./investigation/investigation.md) | qué compra el minuto que no se paga |
| [`player-actions`](./player-actions/player-actions.md) | moverse, mirar, agarrar, examinar |
| [`save-and-resume`](./save-and-resume/save-and-resume.md) | qué cruza el cierre del juego |
| [`ambience`](./ambience/ambience.md) | qué suena y por qué canal |

## El issue es el único plan

**Un spec no se implementa: se implementa un issue.** El spec dice qué tiene que ser cierto; el
issue dice qué se toca esta vez, con qué límites y con qué comandos se cierra. Su forma es
[`_template/task-brief.md`](./_template/task-brief.md) y no se commitea: vive en
[GitHub](https://github.com/federicohermo/nosefia/issues).

No existen `spec.md`, `research.md`, `plan.md` ni `tasks.md`. El issue **no inventa criterios**:
los toma del spec de su capacidad, y si el comportamiento todavía no está escrito, lo primero
que se edita es el spec.

## Los tres estados

`status` en el frontmatter, y lo mira `gate_de_specs.py`.

| Estado | Qué dice |
|---|---|
| `draft` | escrito, todavía no ratificado: hay criterios que ningún test nombra |
| `ratified` | **todos** sus criterios están nombrados por un test. El merge del PR lo ratifica |
| `superseded` | otro spec lo reemplazó |

## Cada criterio nombra su test

El test cita el ID en un comentario de su línea, que es la forma que este repo ya usaba:

```gdscript
func test_dos_jornadas_graves_seguidas_despiden() -> void:  # AC-EMP-004
```

`rg "AC-EMP-004"` encuentra el vínculo. **Un criterio que ningún test nombra no está aceptado**,
y sobre un spec `ratified` eso es rojo. Verifica la **cita**, no que el test ejerza el criterio:
es un piso, y el techo no lo ve ninguna herramienta.

## Cambios

- Un cambio de comportamiento actualiza el spec y los tests **en el mismo PR**. Un refactor no
  toca el spec.
- Nunca se ajusta el spec para que coincida con el código. Si difieren, eso es el hallazgo.
- Un ID no se renumera ni se reutiliza: se retira. Uno nuevo sigue la numeración.
- Un hueco va a `OQ-<COD>-###`. No se inventa un valor por defecto.

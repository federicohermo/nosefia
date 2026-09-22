---
name: spec-to-tickets
description: Reparte el contrato de una capacidad de No se fía en issues de GitHub con formato task-brief — el único plan de este repo. Usar cuando un spec ya escrito tiene criterios que ningún test nombra. No escribe código ni abre ramas.
---

# spec-to-tickets — del contrato al plan

Adaptado del skill homónimo de *spec-anchored agentic development*. **El issue es el único plan.**
El spec dice qué tiene que ser cierto; el issue dice qué se toca esta vez, con qué límites y con
qué comandos se cierra. No hay `spec.md`, `research.md`, `plan.md` ni `tasks.md`.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md).

## La ley

Un issue es **una unidad de entrega**:

> la unidad coherente más chica que produce **un** resultado demostrable por sí solo y justifica
> un dueño, una rama, un PR y un ciclo completo de implementación y review.

Y estas cuatro cosas **no son lo mismo**:

| | |
|---|---|
| `AC-<COD>-###` | verdad durable del contrato |
| issue | un resultado de entrega coherente |
| paso de implementación | trabajo adentro del issue |
| caso de verificación | la evidencia que cierra el issue |

**Un issue puede entregar varios criterios, cruzar las cuatro capas y llevar varios tipos de
test.** Se optimiza por cohesión y por costo de coordinación, no por el cambio más chico que se
puede separar técnicamente.

Completá esta oración por cada issue candidato: **«después de este issue, el juego puede
<un comportamiento observable>»**. Si no se puede completar, el corte está mal.

## Paso 0 — Qué falta de esa capacidad

```bash
python .claude/scripts/gate_de_specs.py
```

Imprime, por cada spec `draft`, cuántos criterios ya tienen test. **Los que faltan son el trabajo
que hay para repartir.** Cruzalo contra lo que ya está en vuelo:

```bash
gh issue list --state open --limit 50
```

Un criterio que ya tiene issue abierto no se reparte dos veces.

## Paso 1 — Cortar donde hay un borde independiente

**Un issue entrega comportamiento de punta a punta, aunque sea flaco.** Nunca se corta por capa
—«primero el dominio, después el sistema, después la escena»—: eso deja dos issues que no se
pueden ver funcionar y un tercero que carga con todo el riesgo. Tampoco por criterio, ni por tipo
de test.

**Se parte sólo cuando existe un borde de verdad**, y el issue declara cuál:

- cada parte es útil y aceptable por separado;
- las dos partes tienen dueños o autoridades de aprobación distintas;
- **son operativamente disjuntas y seguras de correr en paralelo** — el caso normal acá;
- una parte es un habilitador que varias otras necesitan, y tiene verificación propia.

Y dos que en este repo obligan a **serializar**, no a partir:

- **Una escena compartida.** Dos issues que editan el mismo `.tscn` van en serie: un merge de tres
  vías sobre una escena no da un conflicto, da una escena corrupta.
- **Una dependencia declarada.** Si un issue necesita una firma que otro estrena, lo dice:
  `Depende de #N`.

**No se parte** porque el issue «se ve grande», porque toca varias carpetas, ni porque entrega
más de un criterio.

**Ningún issue inventa criterios.** Si al repartir aparece comportamiento que el contrato no
tiene, lo primero que se edita es el contrato — con `to-spec`, en esta misma corrida.

## Paso 2 — Escribir cada issue

La forma la fija el [task-brief](../../../.github/ISSUE_TEMPLATE/task-brief.md), que GitHub
ofrece al abrir el issue. Las seis secciones van todas. Lo que más se rompe:

- **«Criterios que entrega» son IDs del spec**, y son los que después se citan en los tests. Si
  un issue no entrega ningún criterio, o no es trabajo de producto —y entonces va por
  `harness/`, `docs/` o `ci/`— o le falta el contrato.
- **Los límites de archivo se miden, no se suponen.** Antes de escribir la tabla:

  ```bash
  rg -n "<lo que el issue va a tocar>" src/ test/
  ```

  La fila **«No se toca»** es una lista negativa y cerrada: no predice qué se va a tocar,
  prohíbe. Ahí van siempre los `.tscn` que otro issue en vuelo edita.
- **Los comandos de verificación devuelven código de salida 0**, y el primero es siempre
  `python .claude/scripts/verificar.py`. El veredicto sale del código de salida, nunca de un grep
  de la salida: un `| grep` que no matchea devuelve 1 y se traga la salida entera.
- **Los bordes van escritos.** El caso feliz lo cubre cualquier implementación.

## Paso 3 — Publicar

```bash
gh issue create --title "<qué cambia>" --body-file <archivo> --label spec
```

El cuerpo se escribe en un archivo temporal del scratchpad y **no se commitea**: el issue es la
fuente, el repo no guarda una copia que se separe.

Después de crear, anotá el número: la rama que lo implemente se va a llamar
`feature/<issue>-<kebab>`, y el hook la exige así.

## Paso 4 — Preguntar antes de cerrar

**Antes de publicar el lote, mostrá el reparto y esperá.** Tres cosas que sólo el usuario decide:

1. **Qué entra en esta tanda y qué no.** Repartir todos los criterios de una vez es un backlog, no
   un plan.
2. **El orden.** Cuál bloquea a cuál, cuando la dependencia no es evidente del contrato.
3. **Una `OQ-<COD>-###` que bloquea un criterio.** Si el criterio depende de una pregunta abierta,
   el issue no se publica: se contesta la pregunta primero.

## Al cerrar

- Cada criterio repartido tiene issue, **o está declarado fuera del lote con su motivo**. Un
  criterio que se cae del reparto en silencio es la deuda que este paso existe para no crear.
- Ningún issue quedó sin límites de archivo ni sin comandos.
- El reporte dice: qué issues se abrieron, con qué criterios cada uno, y qué quedó afuera.

---
paths:
  - "specs/**"
---

# Specs

`specs/<capability>/<capability>.md` es el contrato durable de una capacidad, y el código
contesta a él. Nombre de carpeta en inglés, texto en español, incluidas las palabras EARS y
DADO/CUANDO/ENTONCES. Plantilla:
[capability-spec.md](../../specs/_template/capability-spec.md). Formato de referencia:
spec-anchored agentic development.

**El spec no se implementa: se implementa un issue.** Su forma es
[task-brief.md](../../specs/_template/task-brief.md) y no se commitea. No se crean `spec.md`,
`research.md`, `plan.md` ni `tasks.md`.

## Qué declara un spec

- Comportamiento observable y verdad del juego. **Sin rutas de archivo, sin nombres de clase y
  sin nombres de escena**: eso vive en el issue y en `docs/`. Un spec que nombra un archivo
  caduca con el refactor siguiente, y entonces el contrato deja de ser el contrato.
- Reglas `BR-<COD>-###` y criterios `AC-<COD>-###`. El código de tres letras es único en el
  repo. Un ID no se renumera y no se reutiliza: se retira. Uno nuevo sigue la numeración.
- Cada AC es DADO/CUANDO/ENTONCES **con los valores que deciden**, y nombra las reglas que
  verifica. Lo cierra un agente, no una persona mirando o escuchando.
- Un valor de balance se cita, nunca se copia: el número exacto sale del dominio.
- Un hueco va a `OQ-<COD>-###`. No se inventa un valor por defecto.
- `status: draft` mientras algún criterio no tenga test. El PR que lo pasa a `ratified` es la
  aprobación. Un spec reemplazado pasa a `superseded`.

## Cada AC nombra su test

El test cita el ID en un comentario de su línea:

```gdscript
func test_dos_jornadas_graves_seguidas_despiden() -> void:  # AC-EMP-004
```

`rg "AC-EMP-004"` encuentra el vínculo. Un AC que ningún test nombra **no está aceptado**, y
sobre un spec `ratified` eso es rojo: lo cobra `gate_de_specs.py`, en el nodo `specs` de
`verificar.py`. Sobre un `draft` el gate cuenta cuántos faltan y lo dice.

Verifica la **cita**, no que el test ejerza el criterio. Es el mismo piso que todo lo que este
repo verifica sin cobertura.

## Cambios

- Un cambio de comportamiento actualiza el spec y los tests en el mismo PR. Un refactor no lo
  cambia.
- Si el código no cumple un AC, se corrige el código y su test, no el spec. **Nunca se ajusta el
  spec para que coincida con el código**: si difieren, eso es el hallazgo.
- El PR declara, por cada AC tocado, `AC-<COD>-### → test → resultado`.

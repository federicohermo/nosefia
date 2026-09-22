---
name: review-spec-drift
description: Audita la deriva entre el contrato de una capacidad de No se fía y el código que lo implementa. Sólo reporta: no arregla nada y no toca el spec. Usar cada tanto, y siempre antes de ratificar una capacidad.
argument-hint: "[capability | vacío = todas]"
---

# review-spec-drift — qué se separó del contrato

Adaptado del skill homónimo de *spec-anchored agentic development*. **El spec es la verdad y el
código contesta a él**, así que la deriva es un bug del código — salvo que el contrato haya
envejecido, y eso lo decide una persona.

**No arregla nada.** Reporta.

## Procedimiento

1. Leé el contrato: `specs/<capability>/<capability>.md`, entero, reglas y criterios.
2. Leé el código que lo implementa. El contrato no nombra archivos a propósito, así que el mapeo
   se hace por vocabulario: los términos del glosario son los nombres del árbol de `src/`.
3. Corré el gate, que ya contesta una parte:

   ```bash
   python .claude/scripts/gate_de_specs.py
   ```

   Dice cuántos criterios de esa capacidad no tiene test que los cite. **Un criterio sin test es
   una sospecha de deriva, no una deriva**: puede estar implementado y sin citar.

4. Buscá las cuatro formas, en este orden:

   | Forma | Cómo se ve |
   |---|---|
   | **comportamiento del spec que el código no tiene** | la regla existe, no hay código ni test |
   | **comportamiento del código que el spec no anticipa** | hay una rama, un `enum` o un rechazo que ninguna regla nombra |
   | **un valor que no coincide** | el spec dice 3600 y la constante dice otra cosa |
   | **un criterio citado por un test que no lo ejerce** | el comentario `# AC-XXX-###` está y la función no afirma nada sobre eso |

   La última es la que ningún gate puede ver, y es la razón por la que este skill existe: el gate
   verifica la cita, no el ejercicio.

## El reporte

Tres bandas, y cada hallazgo dice qué regla o qué criterio toca:

- **Deriva crítica** — el juego hace algo que el contrato prohíbe, o no hace algo que el contrato
  exige y que otro sistema da por hecho.
- **Deriva relevante** — falta comportamiento declarado, sin que nada se rompa hoy.
- **Deriva cosmética** — el contrato quedó viejo: un término, un número que ya se rebalanceó con
  decisión tomada.

Y al final, una línea: **si la capacidad es ratificable**, o sea si todos sus criterios están
citados y ninguna deriva crítica quedó abierta.

## Lo que este skill no decide

**Cuál de los dos está mal.** Un valor que no coincide puede ser un bug del código o un contrato
que envejeció, y la diferencia es una decisión de diseño. El reporte la nombra y la deja abierta:
la contesta el usuario, y después el trabajo sale por `spec-to-tickets` o por `to-spec`.

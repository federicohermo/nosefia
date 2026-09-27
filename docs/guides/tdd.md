# TDD sin cobertura

## El problema

**En GDScript no hay número de cobertura.** Godot no instrumenta scripts, y ninguna herramienta
de test del ecosistema mide cobertura de ramas. Este repo busca las señales que sí se miden, y
dice **qué se pierde**: los gates no saben si un test ejerce una rama. **Es un piso, no un
techo.**

## Las reglas del gate de tests

Las verifica `gate_de_tests.py`, en el nodo `tdd` de `verificar.py`. Cada regla, con el modo de
falla que cierra, está en el encabezado de `.claude/scripts/lib/tdd.py`. Cómo se ve cada una en
una suite, en [la regla de tests](../../.claude/rules/tests.md).

`ui/` y `escenas/` no tienen test obligatorio. Por qué, y qué obliga eso, en
[la regla de presentación](../../.claude/rules/presentacion.md).

## El ciclo, y por qué el orden importa

1. **El test primero**, contra la firma que todavía no existe. Se corre y **falla**.
2. Lo mínimo para que pase.
3. Limpiar, con el test en verde de testigo.

**Un test escrito después del código se escribe mirando el código.** Prueba lo que el código
hace, no lo que tenía que hacer.

**El rojo del paso 1 tiene que ser el rojo que se espera.** Un
`nonexistent function 'consecuencia'` no verifica el criterio: verifica que el archivo no
existe. Si el test falla por eso, escribir la firma vacía y volver a correr. El rojo útil dice
«esperaba AVISO, recibí NINGUNA».

## Qué hace testeable a un juego

El tiempo y el azar entran por parámetro: lo pide la
[constitución](../architecture/constitution.md), y el ejemplo está en
[la regla de dominio](../../.claude/rules/dominio.md).

**El estado se pregunta, no se mira.** Si para saber si el turno terminó hay que leer una
etiqueta del HUD, la regla está en el HUD. El dominio tiene que poder contestarlo.

Las tres son la misma idea: **lo que el dominio necesita del mundo, se lo dan.** Así, «dos
jornadas graves seguidas y lo echan» es un test de tres líneas.

## Lo que igual hay que probar a mano

Los gates no cubren si el juego se siente bien, si una tarea del turno es tediosa o si la
paranoia funciona. Eso es playtesting y no tiene gate, a propósito.

**No escribirlo como criterio de aceptación.** Uno que se cierra mirando no lo cierra nadie. Si
hay que playtestear algo, va al Backlog de Notion, que es donde el equipo mira lo que no es
código.

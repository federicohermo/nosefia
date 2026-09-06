# Plan — Spec NNN

<!-- Techo: 250 palabras. Los encabezados NO cuentan, así que rotular no cuesta.
     Los tres `##` de abajo los exige `test_convencion_de_specs.py`; podés agregar otros. -->

## Orden obligado

Qué **no** se puede paralelizar, y por qué. En prosa, no como lista de tareas: la lista de lo
que sí se puede hacer junto exige conocer los archivos antes de abrirlos, y está medido que esa
predicción falla —43 % de rutas nunca tocadas, 39 % de imprevistos—.

Empezá por los `.tscn`: un merge de tres vías sobre una escena da una escena corrupta, no un
conflicto.

## Qué NO se toca

<!-- Las dos mitades se separan por lo que se puede verificar y lo que no. Es la sección 4
     (blast radius) y la 3 (invariantes) del task-brief, y la fila "Constraints" de la Tabla I
     de Agentic Agile-V, que las pone aparte de los criterios de aceptación. -->

### Rutas

Los archivos y directorios que este spec **no escribe**, uno por viñeta y entre backticks. Es
una lista **negativa y cerrada**: no predice qué vas a tocar, prohíbe lo que no. Por eso no
hereda la medición que mató al `tasks.md`.

- `src/dominio/reglas.gd` — es del spec NNN.
- `src/escenas/almacen.tscn` — un `.tscn` no se mergea.

Si el spec no restringe ningún archivo, escribí `Ninguna.` — 11 de los 24 specs abiertos están
en ese caso, y omitir el rubro se lee igual que olvidarlo.

**Sólo lo que de verdad es intocable.** Un archivo citado como *fuente* de algo no va acá: el
plan del 012 nombra `.claude/rules/dominio.md` como la lista de la que salen sus patrones, y
declararlo prohibido daría rojo sobre un PR correcto.

### Invariantes

Lo que sigue siendo cierto después del cambio, y que ningún gate puede decidir: «ningún
autoload», «ninguna regla del juego en `escenas/`», «ninguna unidad de stock se mueve fuera de
`Estante.colocar()`». Es prosa a propósito — la mira la revisión, y está declarado como prosa
igual que el resto de las reglas no verificables del repo.

## Criterio de terminado

`verificar.py` en verde sin nodos salteados, y qué más. Si hay algo que sólo se ve corriendo el
juego, decilo acá: no es un criterio de aceptación, porque un criterio lo tiene que poder cerrar
un agente.

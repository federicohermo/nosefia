# Research — Spec NNN

<!-- Techo: 500 palabras. Sale de CORRER algo, no de suponer. Un `research.md` que dice
     «probablemente haya que tocar el HUD» no es research: es una intuición con formato de
     documento. El que sirve dice qué corriste y qué contestó. -->

Medido el AAAA-MM-DD sobre `<rama>`.

## Qué se rompe hoy

Corré `python .claude/scripts/verificar.py` con el cambio mínimo aplicado y contá: qué nodo se
pone en rojo, cuántos tests, en qué archivos. El número es lo que hace estimable al spec.

## Quién cita lo que va a cambiar

`rg` sobre `src/` y `test/`. Para `specs/`, **`rg --no-ignore`**: están en el `.gitignore`, así
que una búsqueda normal contesta cero **sin decir que no miró**.

Pegá el comando y su salida, no el resumen.

## Qué NO se mueve

Tan informativo como lo que sí. Si el nodo `capas` no se mueve, el trabajo no cruza ninguna
frontera de capa — y eso es lo que después justifica el `### Rutas` del plan.

## Lo que se midió y sorprendió

Los números que contradicen lo que se suponía. Si un doc del repo dice otro número que esto,
**gana esto** y el doc es un hallazgo.

<!-- No existe «medición pendiente»: `test_convencion_de_specs.py` da rojo sobre «queda por
     medir», «sin medir», «habría que medirlo». O se corrió, o el spec no la necesitaba. -->

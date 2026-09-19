# El contrato por capacidad reemplaza los tres archivos por spec

**2026-09-18**

Hasta hoy una unidad de trabajo era un spec de tres archivos —`spec.md`, `research.md`,
`plan.md`— publicado como issue, con `specs/mapa.json` de registro y `specs/` ignorado por git.
El spec era un plan con fecha: se cerraba con su PR y no se volvía a leer.

**Decisión: el repo pasa a spec-anchored.** `specs/<capability>/<capability>.md` es un contrato
durable por capacidad, trackeado, y el código contesta a él. El plan es el issue de GitHub, en
formato task-brief. No hay `spec.md`, `research.md`, `plan.md`, `tasks.md` ni mapa.

Por qué: un spec por tarea no podía ser la verdad de nada. Al cerrarse quedaba como historia, así
que la única fuente del comportamiento volvía a ser el código — y ahí el GDD y el juego podían
separarse sin que nada lo dijera. Con un contrato por capacidad, esa diferencia es un hallazgo
verificable: el nodo `specs` de `verificar.py` exige que cada criterio de un spec `ratified` esté
citado por un test.

El costo, dicho: nueve contratos que hay que mantener al día, y un régimen de IDs tipados
—`BR-<COD>-###`, `AC-<COD>-###`— que no se renumeran nunca.

Formato de referencia: *spec-anchored agentic development*, y el task-brief de ITBAF.

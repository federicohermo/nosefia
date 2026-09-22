---
name: Task brief
about: El plan de un cambio puntual. Se cierra con su PR y se descarta.
title: ""
labels: ""
---

<!-- Un issue es un plan chico y descartable: resuelve un problema puntual, con límites y
     criterios propios. Un spec es otra cosa: el contrato durable de una funcionalidad.
     Un issue cambia un spec sólo si cambia lo que el juego tiene que hacer. -->

# <Qué cambia, no qué área toca>

## Contexto

- **Objetivo:** una oración. Qué problema resuelve.
- **Tipo:** `feature` | `bugfix` | `hotfix` | `refactor` | `improvement`
- **Spec:** ninguno | crea | modifica | borra — `specs/<capability>/<capability>.md`
- **Rama:** `<tipo>/<issue>-<kebab>`

<!-- `feature` es el único tipo que siempre toca un spec. Un `bugfix` toca uno sólo si el bug
     era una regla que nadie había escrito. -->

## Criterios de aceptación

<!-- Los de este issue: binarios y con los valores que deciden. Mueren con el issue.
     Si el issue toca un spec, acá van también los `AC-<COD>-###` que agrega o cambia: ésos
     sí duran, y un test los cita. -->

- [ ] <...>

## Contrato

<!-- Sólo si aparecen firmas, señales o datos nuevos. Cada uno con su capa y su tipo de
     retorno. El caso de falla va junto al de éxito. -->

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | <...> |
| **Sólo lectura** | <...> |
| **No se toca** | <...> |

<!-- La tercera fila es una lista negativa y cerrada. Un `.tscn` que otro issue en vuelo edita
     va siempre acá: un merge de tres vías sobre una escena da una escena corrupta. -->

## Verificación

<!-- Comandos que devuelven código de salida 0. El veredicto sale del código de salida,
     nunca de un grep de la salida. -->

1. `python .claude/scripts/verificar.py`
2. <...>

## Bordes

<!-- El caso feliz lo cubre cualquier implementación. Acá van los límites: cero, uno, el
     máximo, el valor justo antes del corte, el que llega dos veces. -->

- <...>

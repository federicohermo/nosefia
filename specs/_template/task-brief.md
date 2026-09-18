# <Qué cambia, no qué área toca>

<!-- Este archivo es la forma del ISSUE, y el issue es el único plan. No se commitea: se pega
     en el cuerpo del issue de GitHub. No hay `spec.md`, `research.md`, `plan.md` ni `tasks.md`.
     Sale del task-brief de ITBAF, recortado a lo que este repo puede verificar. -->

## Contexto

- **Objetivo:** una oración. Qué tiene que poder hacer el juego cuando esto esté.
- **Capacidad:** `specs/<capability>/<capability>.md`
- **Criterios que entrega:** `AC-<COD>-001`, `AC-<COD>-002`
- **Rama:** `feature/<issue>-<kebab>`

<!-- Los criterios ya existen en el spec de la capacidad: el issue NO los inventa. Si el
     comportamiento todavía no está escrito, primero se edita el spec. -->

## Contrato

<!-- Qué firmas, señales o datos nuevos aparecen, y en qué capa cae cada uno. Las firmas van
     con su tipo de retorno. El caso de falla va junto al de éxito. -->

- **Dominio:** <...>
- **Sistemas:** <...>
- **Escena o UI:** <...>

## Invariantes

<!-- Lo que sigue siendo cierto después del cambio y ningún gate puede decidir: «ningún
     autoload nuevo», «ninguna regla del juego en `escenas/`», «el dominio no toca disco». -->

- <...>

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | <...> |
| **Sólo lectura** | <...> |
| **No se toca** | <...> |

<!-- La tercera fila es una lista negativa y cerrada. Un `.tscn` que otro issue en vuelo edita
     va siempre acá: un merge de tres vías sobre una escena da una escena corrupta. -->

## Verificación

<!-- Comandos que tienen que devolver código de salida 0. El veredicto sale del código de
     salida, nunca de un grep de la salida. -->

1. `python .claude/scripts/verificar.py`
2. <...>

## Bordes que los tests cubren

<!-- El caso feliz lo cubre cualquier implementación. Acá van los límites: cero, uno, el
     máximo, el valor justo antes del corte, el que llega dos veces. -->

- <...>

---
schema_version: 1
capability_id: CAP-ANO
status: ratified
owner: game design
provenance: ficha «11. Anomalías», «9. Tarea Limpieza», fichas Poético y bidón azul; decisiones de #432, 15 de octubre de 2026; ocho jornadas de #526
---

# Capacidad: las anomalías de la jornada

## Propósito

Alterar las condiciones de una tarea rutinaria según la jornada. La quinta noche exige buscar
un sustituto vendible del jabón que falta, conservando las reglas de preparación y limpieza.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Anomalía** | condición excepcional de una jornada que cambia disponibilidad o permisos de una tarea | avería aleatoria |
| **Ausente** | objeto que no está disponible en ningún lugar del mundo ni participa de su cierre físico | escondido, tirado |
| **Sustituto** | producto que recibe un permiso excepcional de uso durante esa jornada | bidón nuevo |
| **Poético** | producto vendible de limpieza, distinto del bidón azul marca «2» | jabón azul |

## Comportamiento normativo

### BR-ANO-001 — Falta el azul sólo durante la quinta noche

CUANDO se abre jornada 5, el sistema DEBE dejar disponibles sólo los bidones rosa y amarillo.
El azul DEBE quedar oculto, sin colisión, foco, agarre ni examen y excluido de la evaluación
física del cierre. En las demás jornadas los tres bidones DEBEN estar disponibles normalmente.
La ausencia de la jornada 5 NO DEBE producir por sí misma desorden ni objeto afuera.

### BR-ANO-002 — La disponibilidad se aplica sobre cualquier apertura

CUANDO se abre jornada 5 directamente o tras jornada 4, el sistema DEBE terminar examen y vaciar
mano antes de aplicar la ausencia, cualquiera fuera el destino previo del azul. Repetir esa
apertura NO DEBE volver a habilitarlo. CUANDO abre jornada 6, el sistema DEBE restaurar el mismo
bidón a padre, pose, visibilidad y colisiones originales, incluso si había sido tirado.

### BR-ANO-003 — El permiso del sustituto pertenece a una sola jornada

MIENTRAS la jornada es 5, el sistema DEBE habilitar exclusivamente una unidad real de Poético
como sustituto del azul al preparar agua del balde. En las demás jornadas NO DEBE habilitarlo.
El permiso DEBE recibirse por jornada e identidad y NO DEBE convertir al producto en un bidón
permanente ni cambiar el inventario. La preparación, sus rechazos y sus efectos DEBEN seguir
BR-CLN-033 y BR-CLN-034 de [`store-cleanup`](../store-cleanup/store-cleanup.md).

## Criterios de aceptación

### AC-ANO-001 — Matriz de disponibilidad *(verifica BR-ANO-001)*

DADO aperturas de jornadas 1 a 8 CUANDO se consultan los bidones presentes ENTONCES la 5 tiene
rosa/amarillo y cada una de las otras siete, azul/rosa/amarillo. En la 3 están los tres aunque
pida limpiar. En la 5 ningún recorrido de mira, agarre o examen alcanza el azul ni su cuerpo obstruye el paso.
Con los demás cuerpos ordenados, la ausencia no produce motivos de desorden ni afuera al cerrar.

### AC-ANO-002 — Apertura directa y transición equivalen *(verifica BR-ANO-002, BR-ANO-001)*

DADO el azul antes, por turno, en mano, examen, piso y contenedor CUANDO se abre jornada 5
ENTONCES mano y examen quedan vacíos, el azul queda ausente y no participa de la foto física
del cierre. Abrir directamente desde checkpoint en 5 produce la misma disponibilidad. Repetir
la apertura conserva la ausencia, sin emitir un descarte de objeto importante.

### AC-ANO-003 — El sexto día recupera el objeto original *(verifica BR-ANO-002)*

DADO el azul tirado en jornada 4 y ausente durante la 5 CUANDO se abre la 6 ENTONCES el mismo
bidón vuelve a su padre y pose originales, visible, físico, enfocable, levantable y examinable;
no queda una segunda copia ni una marca de tirado heredada.

### AC-ANO-004 — Matriz de sustitución *(verifica BR-ANO-003)*

DADO el producto Poético real CUANDO se consulta su permiso de teñir agua limpia del balde en
jornadas 1 a 8 ENTONCES contesta sí sólo en la 5 y no en las otras siete. Otro producto
renombrado Poético contesta no en las ocho. Consultar no tiñe ni cambia mano o mercadería; ejecutar el permiso
válido usa el recorrido de limpieza sin consumo adicional.

## No objetivos

- Esta capacidad NO decide mezclas, carga de la mopa, manchas, ventas ni consecuencias laborales.
- Esta capacidad NO define las anomalías de las jornadas 6 a 8. Sus contenidos pertenecen a
  sus contratos respectivos; aquí sólo se fija la vigencia de la excepción del jabón azul.

## Contratos

- **Entrada:** jornada que abre, identidad del útil o producto y estado físico previo.
- **Salida:** útiles disponibles y permiso de sustituir azul con Poético durante esa jornada.
- **Falla:** una identidad distinta de Poético no recibe permiso; una apertura repetida
  conserva la disponibilidad y no duplica cuerpos ni descartes.

## Señales

- La disponibilidad preparada al abrir la jornada. Consultar permisos no publica uso ni hallazgo.

## Dependencias

- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): jornada que abre.
- [`store-cleanup`](../store-cleanup/store-cleanup.md) (alimenta): útiles disponibles y permiso
  de sustitución; limpieza resuelve y publica el teñido aceptado con identidad.
- [`store-stock`](../store-stock/store-stock.md) (consume): identidad de la unidad vendible,
  que conserva su propiedad y sus recorridos normales.

## Preguntas abiertas

Ninguna para la anomalía de jornada 5.

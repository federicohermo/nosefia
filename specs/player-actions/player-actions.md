---
schema_version: 1
capability_id: CAP-PLY
status: draft
owner: por definir
provenance: GDD «Controles»; migración de los specs 003, 004, 006, 014, 034, 043
---

# Capacidad: lo que el empleado puede hacer

## Propósito

Moverse por el local, enfocar lo que está a mano, levantar una cosa por vez y abrir las puertas.
Lo único que tiene que hacer bien es **costar recorrido sin pelear con el jugador**: el precio de
una tarea son los metros, no la torpeza del control.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Mira** | lo que la vista enfoca, dentro de su alcance y su desvío | cursor, puntero |
| **Foco** | qué objeto está enfocado ahora, y si cambió | selección, target |
| **Manos** | qué se lleva encima. Es una sola | inventario, mochila |
| **Suspender** | apagar juntos la caminata, la mirada y el foco | pausar, bloquear |
| **Interactuable** | lo que contesta cuando se lo usa | clickeable, activable |

## Comportamiento normativo

### BR-PLY-001 — La diagonal no camina más rápido

CUANDO se camina en diagonal, el sistema DEBE normalizar la dirección. Es el bug clásico del
controlador de primera persona: no se nota jugando hasta que alguien lo aprovecha.

### BR-PLY-002 — El adelante gira con la mirada

El sistema DEBE rotar la dirección de la caminata con el giro horizontal de la vista. La
velocidad de caminata es de **3,5 metros por segundo**: un almacén se cruza caminando, no
corriendo.

### BR-PLY-003 — La vista no se da vuelta

El sistema DEBE dar la vuelta completa en horizontal y DEBE limitar el vertical a **±1,4
radianes**. Pasarse de ahí da vuelta la cámara, y eso no es un límite de gusto.

### BR-PLY-004 — Se enfoca lo que está a mano

El sistema DEBE enfocar lo que está a **2,5 metros o menos** y a **15 grados o menos** del centro
de la vista. Entre varios candidatos gana el de menor desvío, y con el mismo desvío el más
cercano.

### BR-PLY-005 — El foco avisa sólo cuando cambió

El sistema DEBE avisar del foco **sólo cuando cambia el objeto enfocado o si es interactuable**.
Que cambie la distancia mientras el jugador camina hacia lo mismo NO es un cambio: el rayo se lee
sesenta veces por segundo.

### BR-PLY-006 — Suspender es una sola llamada

CUANDO otra cosa toma el control —la ventanilla, la computadora, el cierre—, el sistema DEBE
apagar **juntos** la caminata, la mirada y el foco, y DEBE soltar lo enfocado. Con interruptores
sueltos, cada pantalla tiene que acordarse de todos.

### BR-PLY-007 — Una cosa por vez

El sistema DEBE permitir llevar **1 objeto**. Es la mitad del precio de sacar la basura: tres
bolsas y una mano son tres viajes.

### BR-PLY-008 — Los dos rechazos de agarrar, en orden

CUANDO se intenta agarrar, el sistema DEBE rechazar por **no es levantable** primero y por
**manos llenas** después. Al revés, apuntarle a una puerta con algo en la mano contestaría el
motivo que el jugador puede resolver, y al vaciar las manos la puerta seguiría sin levantarse.

### BR-PLY-009 — Soltar con las manos vacías no anuncia nada

SI no se lleva nada, ENTONCES soltar NO DEBE avisar que se soltó algo. Sin eso, cada clic al aire
anuncia un objeto.

### BR-PLY-010 — Lo que se suelta se puede volver a agarrar

El sistema DEBE soltar los objetos **dentro del alcance de la mira**. Las tres distancias de
examinar, llevar y soltar van de la más cerca a la más lejos, y ninguna llega al alcance.

### BR-PLY-011 — La puerta es una intención y una hoja

CUANDO se interactúa con una puerta, el sistema DEBE alternar entre abierta y cerrada de
inmediato, y DEBE mover la hoja hacia su tope sin pasarse y sin saltar en un cuadro. Abierta, la
hoja queda a **un cuarto de vuelta** y deja pasar.

### BR-PLY-012 — Una herramienta sirve para algo o para nada

CUANDO se usa lo que se lleva sobre algo, el sistema DEBE contestar el efecto declarado para ese
par, y **ningún efecto** para cualquier otro par o con las manos vacías.

## Criterios de aceptación

### AC-PLY-001 — La diagonal no corre *(verifica BR-PLY-001)*

DADO una entrada de adelante y derecha a la vez CUANDO se calcula la velocidad ENTONCES su módulo
es la velocidad de caminata y no su raíz de dos.

### AC-PLY-002 — El adelante sigue a la vista *(verifica BR-PLY-002)*

DADO un giro de un cuarto de vuelta CUANDO se camina hacia adelante ENTONCES la dirección es la
que mira la vista, y la entrada nula da el vector cero.

### AC-PLY-003 — El vertical se clava *(verifica BR-PLY-003)*

DADO un giro hacia abajo enorme ENTONCES el ángulo vertical queda en `-1.4`; hacia arriba, en
`1.4`; y el horizontal da la vuelta sin crecer sin límite.

### AC-PLY-004 — Los dos bordes de la mira *(verifica BR-PLY-004)*

DADO un candidato a 2,5 metros ENTONCES se enfoca; a 2,6, no. DADO uno a 15 grados de desvío
ENTONCES se enfoca; a 16, no.

### AC-PLY-005 — Gana el menor desvío *(verifica BR-PLY-004)*

DADO dos candidatos válidos, uno más cerca y otro con menos desvío ENTONCES se enfoca el de menos
desvío; con el mismo desvío, el más cercano.

### AC-PLY-006 — El foco no habla de más *(verifica BR-PLY-005)*

DADO el mismo objeto enfocado CUANDO se lo observa dos veces a distinta distancia ENTONCES la
segunda no avisa cambio; si cambia si es interactuable, sí avisa.

### AC-PLY-007 — Suspender apaga las tres cosas *(verifica BR-PLY-006)*

DADO el control suspendido CUANDO se gira, se camina y se observa ENTONCES la vista no se mueve,
la velocidad es cero, no hay objetivo enfocado y no se pide el cursor tomado.

### AC-PLY-008 — Una sola mano *(verifica BR-PLY-007)*

DADO un objeto en la mano CUANDO se intenta agarrar otro levantable ENTONCES se rechaza por manos
llenas y se sigue llevando el primero.

### AC-PLY-009 — El orden de los rechazos *(verifica BR-PLY-008)*

DADO las manos llenas CUANDO se intenta agarrar algo no levantable ENTONCES el motivo es «no es
levantable» y no «manos llenas».

### AC-PLY-010 — Soltar al aire no anuncia *(verifica BR-PLY-009)*

DADO las manos vacías CUANDO se suelta ENTONCES no se devuelve ningún objeto.

### AC-PLY-011 — Las tres distancias están ordenadas *(verifica BR-PLY-010)*

DADO las distancias de examinar, llevar y soltar ENTONCES crecen en ese orden y todas son
menores al alcance de la mira.

### AC-PLY-012 — La hoja llega al tope y no se pasa *(verifica BR-PLY-011)*

DADO una puerta recién abierta CUANDO se la hace avanzar muchos segundos ENTONCES el ángulo es
exactamente un cuarto de vuelta; y apenas alternada, ya está abierta con el ángulo en cero.

### AC-PLY-013 — La puerta cierra hasta cero *(verifica BR-PLY-011)*

DADO una puerta abierta del todo CUANDO se la cierra y avanza ENTONCES el ángulo llega a `0.0` y
no baja.

### AC-PLY-014 — El uso declarado y los demás *(verifica BR-PLY-012)*

DADO el trapeador sobre una mancha ENTONCES el efecto es limpiar; con cualquier otro par, o con
las manos vacías, no hay efecto.

## No objetivos

- Esta capacidad NO decide qué esconde un objeto: eso es de
  [`investigation`](../investigation/investigation.md).
- Esta capacidad NO cuenta unidades ni repone: eso es de
  [`store-stock`](../store-stock/store-stock.md).
- Esta capacidad NO lee el teclado ni el mouse. Recibe la entrada ya traducida a números.

## Contratos

- **Entrada:** el vector de movimiento, el delta del mouse, los candidatos que el rayo encontró,
  el objeto que se quiere agarrar y los segundos del cuadro.
- **Salida:** la velocidad, los dos ángulos de la vista, qué está enfocado y si cambió, qué se
  lleva en la mano, el motivo de cada rechazo, el ángulo de la hoja y el efecto de un uso.
- **Falla:** los dos rechazos de agarrar; soltar con las manos vacías no devuelve nada; un uso no
  declarado no tiene efecto.

## Señales

- El objetivo enfocado y perdido, el objeto agarrado y soltado, y el agarre rechazado.

## Dependencias

- [`store-cleanup`](../store-cleanup/store-cleanup.md) (alimenta): qué se lleva en la mano
  decide si se puede limpiar.
- [`investigation`](../investigation/investigation.md) (alimenta): qué objeto se examina.

## Preguntas abiertas

- **OQ-PLY-001 — ¿La segunda mano entra alguna vez?**
  - Por qué sigue abierta: subir las manos a 2 le afloja el costo a sacar la basura sin tocar
    ningún costo de tarea, y eso es una decisión de balance que nadie tomó.
  - Decide: el dueño del repo, jugando.
  - Bloquea: nada. Movería `BR-PLY-007` y el tercer criterio de
    [`store-cleanup`](../store-cleanup/store-cleanup.md).

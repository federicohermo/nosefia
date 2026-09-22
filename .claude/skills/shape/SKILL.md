---
name: shape
description: La entrevista que le da forma al trabajo de No se fía — interroga una idea, un pedido, código sin spec o un spec ya escrito hasta que no quede nada supuesto en silencio. Sólo la entrevista: el issue lo escribe to-issue y el spec to-spec. Usar apenas llega un pedido, antes de escribir el issue o el contrato.
argument-hint: "[idea | pedido | capacidad | área de código]"
---

# shape — la entrevista

Adaptado del skill `shape` de *spec-anchored agentic development*. Lo propio de acá es contra qué
se contrasta: el GDD, las cuatro capas y la tensión aritmética del juego.

**Esto NO escribe el issue ni el spec.** Los escriben `to-issue` y `to-spec`, y la separación es
deliberada: entrevistar y editar el archivo a la vez obliga al usuario a revisar un documento que
se mueve mientras todavía está contestando.

## Los cuatro modos

- **Una idea o un pedido en prosa** → entrevistar hacia el contrato de una capacidad.
- **Código sin spec** → arqueología: leer el código, establecer qué **hace**, interrogar qué
  **debería** hacer.
- **Un spec ya escrito** → interrogarlo buscando ambigüedad y agujeros.
- **Un issue o un pedido puntual** → afilarlo hasta que un agente lo pueda implementar sin
  adivinar, y decidir si cambia lo que el juego tiene que hacer. El pedido puede ser una ficha
  de «Features y sistemas» en Notion, una optimización, un cambio del harness o un bug: la
  entrevista es la misma.

Los cuatro son la misma máquina: **se entrevista hasta que la frontera queda vacía**, no hasta
llenar una lista. Nunca se escribe código de producción y nunca se edita el spec.

## La mecánica

- **La entrevista es un árbol, y se recorre en rondas.** La **frontera** son todas las preguntas
  cuyos prerrequisitos ya están resueltos. Se preguntan **todas juntas, numeradas**, y se espera.
  Una pregunta que depende de otra todavía abierta va a la ronda siguiente.
- **Cada pregunta lleva tu respuesta recomendada.** El usuario confirma o corrige; componer desde
  cero es fricción. La recomendación es una propuesta, la respuesta es la verdad.
- **Si una pregunta se contesta mirando el código, mirá el código en vez de preguntar.** Pero el
  código resuelve **hechos**, no **intención**: un comportamiento encontrado en el código entra
  como **pregunta**, nunca como regla, hasta que el usuario lo confirma. El código puede tener
  bugs que se volvieron estructura.
- **Los números van antes que la prosa.** Para cualquier regla con un cálculo o un umbral: primero
  los pares entrada → salida esperada con el usuario, después la regla EARS como generalización de
  esos ejemplos. Al revés, los ejemplos se inventan para que encajen con tu redacción.
- **Una capacidad por sesión.** Si el trabajo cruza capacidades, pará y decilo: eso es
  arquitectura, no una entrevista de spec.

## Lo propio de este juego

- **El GDD manda sobre el código y sobre lo que diga cualquier archivo del repo.** Vive en Notion.
  Si el código contradice al GDD, lo que se escribe es la regla del GDD, y la diferencia es el
  hallazgo.
- **La pregunta que hay que hacer siempre: ¿esto aprieta la tensión central?** Cada minuto
  investigando es un minuto que no se dedica a las tareas. Una feature que agrega contenido sin
  tocar esa resta es contenido, no diseño.
- **¿De qué lado de la resta cae?** Lo que cuesta tiempo del turno y cumple una obligatoria, lo
  que cuesta tiempo y no cumple nada, o lo que no cuesta nada. Las tres son capacidades distintas.
- **¿Se puede ejercer sin levantar una escena?** Si la respuesta es no, la regla va a nacer en
  `ui/` o en `escenas/`, que son las dos capas sin test obligatorio: ahí nace sin test y ningún
  gate lo dice. La salida es bajarla al dominio, y eso se decide acá, no implementando.
- **Un valor de balance no se inventa en la entrevista.** O sale del GDD, o sale de medir, o es
  una `OQ-<COD>-###` con quién la decide.

## Qué recorren las preguntas

- **Propósito y lenguaje de la capacidad** — qué hace para el juego; los términos con significado
  propio adentro.
- **Reglas en EARS**, de a una.
- **Criterios de aceptación** concretos, en DADO/CUANDO/ENTONCES, con los valores que deciden.
  Cada criterio afirma **el estado final observable, nunca el evento intermedio**: «se emite la
  señal» no es un criterio; «el legajo quedó en 2» sí.
- **Bordes** — cero, uno, el máximo, el valor justo antes del corte, el que llega dos veces, el
  que llega en otro orden. No preguntes lo obvio: preguntá qué puede salir mal.
- **No objetivos con dientes** — cada uno tiene que ser algo que un agente construiría igual si
  nadie se lo prohíbe.
- **Contratos y dependencias** — qué consume y qué produce, de qué capacidad y hacia cuál.

## Dónde aterriza lo que se resolvió

**Depende de qué es la respuesta, no de dónde vino el pedido.**

| Lo que se resolvió | Aterriza en |
|---|---|
| diseño del juego, y el pedido salió de una ficha de Notion | **un comentario en la ficha**, con el arroba a Cami y Tiago, que lo resuelven. El texto de la ficha no se toca |
| una regla durable del juego | el contrato de la capacidad, con `to-spec` |
| qué se toca esta vez, con qué límites | el issue, con `to-issue` |
| algo que no toca el juego —el harness, una optimización, un bug— | el issue, y nada más |

**La entrevista no escribe ninguno de los cuatro.**

## El estado corre en la conversación, no en un archivo

- **Términos → un glosario con opinión**: el término canónico, qué **es** en una o dos oraciones,
  y los sinónimos prohibidos.
- **Reglas → en EARS**, a medida que se acuerdan.
- **Valores → con su número**, a medida que se recogen.
- **Decisiones → un ADR en `docs/architecture/decisions/`**, y sólo cuando las tres son ciertas:
  difícil de revertir, sorprendente sin contexto, y resultado de un intercambio real. Si falta
  una, no hay ADR. El formato es mínimo: un título y una a tres oraciones.

## El interrogatorio final

Antes de pasarle el material a `to-spec`:

- **Divergencia:** ¿dos implementaciones con **comportamiento distinto** podrían defenderse con
  este texto? Donde sí, el spec es ambiguo ahí. Que dos implementaciones difieran por dentro sin
  cambiar el comportamiento es libertad, no ambigüedad.
- **Bordes:** cero, negativo, enorme, duplicado, fuera de orden — ¿hay una regla que conteste cada
  uno, o está declarado fuera de alcance?
- **Verificabilidad:** cada regla tiene un criterio que un agente puede cerrar, o está declarada
  como territorio de juicio humano.
- **Aritmética:** si este cambio mueve un costo o el turno, ¿el margen sigue por encima del
  mínimo? Ese número sale del dominio.

## Salida

- **Modos de spec:** el resumen corrido, organizado por sección de la plantilla, más las preguntas
  que siguen abiertas. Después, invocar `to-spec`. **La ambigüedad que
  quedó va a las preguntas abiertas, nunca rellenada con un valor por defecto.**
- **Modo issue:** el material del issue —tipo, si toca un spec, criterios, bordes, fuera de
  alcance—. Después, invocar `to-issue`. Si toca un spec, después de `to-issue` va `to-spec`.

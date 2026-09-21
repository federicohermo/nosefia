---
schema_version: 1
capability_id: CAP-<COD>
status: draft        # draft → ratified → superseded. El merge del PR del spec lo ratifica.
owner: <dueño de la capacidad>
provenance: <de dónde sale el contenido>
---

# Capacidad: <nombre>

<!-- Un contrato durable por capacidad. Las secciones van de lo estable a lo volátil.
     Sólo lo que no se infiere del código. Sin rutas de archivo, sin nombres de clase y sin
     nombres de escena: eso vive en el issue que implementa y en `docs/`. -->

## Propósito

<!-- Una o dos oraciones: qué hace para el juego y lo único que tiene que hacer bien. -->

## Lenguaje de la capacidad

<!-- Glosario con opinión. El término canónico, qué ES acá, y los sinónimos prohibidos. -->

| Término | Significado acá | Evitar |
|---|---|---|
| | | |

## Comportamiento normativo

<!-- Un encabezado por regla con ID tipado estable. No se renumera ni se reutiliza: se retira.
     EARS: "El sistema DEBE", "CUANDO <disparador>, el sistema DEBE",
     "SI <condición>, ENTONCES el sistema DEBE", "MIENTRAS <estado>, el sistema DEBE".
     Un cálculo va con su fórmula y sus valores de referencia. -->

### BR-<COD>-001 — <nombre>

CUANDO <disparador>, el sistema DEBE <comportamiento observable>.

## Criterios de aceptación

<!-- Un encabezado por criterio con ID tipado estable. Binario, con los valores que deciden, y
     lo cierra un agente. Cada uno nombra las reglas que verifica. -->

### AC-<COD>-001 — <nombre> *(verifica BR-<COD>-001)*

DADO <estado> CUANDO <acción> ENTONCES <resultado observable con valores>.

## No objetivos

- Esta capacidad NO <...>.

## Contratos

<!-- Qué recibe y qué contesta, y qué pasa en el borde. El caso de falla va junto al de éxito. -->

- **Entrada:** <...>
- **Salida:** <...>
- **Falla:** <...>

## Señales

- <lo que emite al cumplirse y al rechazar>.

## Dependencias

- <capacidad> (<consume | alimenta>): <qué usa>.

## Preguntas abiertas

<!-- Huecos sin resolver, nunca valores inventados. -->

- **OQ-<COD>-001 — <pregunta>**
  - Por qué sigue abierta: <...>
  - Decide: <...>
  - Bloquea: <...>

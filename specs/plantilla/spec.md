# Spec NNN — Un título que dice qué cambia, no qué área toca

<!-- De esta primera línea sale el título del issue, tal cual.
     Techos: 350 palabras de prosa, y 300 el bloque `## Criterios de aceptación` ENTERO.
     El segundo cae sobre el bloque y no sobre cada criterio a propósito: con un límite por
     criterio, un spec cumple escribiendo veinte criterios cortos. -->

<!-- **Origen:** #12  ← sólo si el spec SALDA issues de deuda. Va antes del primer `##`, porque
     un `#12` suelto en la prosa no lo parsea nadie. Es lo que salda, no lo que menciona. -->

## Problema

Qué está mal hoy, con evidencia. No «sería bueno que»: qué se rompe, qué cuesta, qué no se ve.
Si hay un número, va acá y sale del `research.md`.

## Solución propuesta

Qué se hace, en qué capa, y por qué esa y no otra. La prueba de que algo va en `dominio/` es una
sola: se puede ejercer sin levantar una escena.

## Criterios de aceptación

<!-- Cada uno termina citado por un test como `NNN-ACn`, y lo cobra
     `test_criterios_de_la_rama.py` mientras el PR todavía está abierto. Numerálos. -->

- **AC1** — **Falsable**: tiene que poder verse fallar. «El HUD muestra el tiempo» no lo es;
  «con 3 minutos restantes, `tiempo_restante()` devuelve 180.0» sí.
- **AC2** — **Nombra el borde, no el caso feliz.** El caso feliz lo cubre cualquier
  implementación; lo que decide si el código está bien es el límite: cero, uno, el máximo, el
  valor justo antes del corte, el que llega dos veces. En este juego la aritmética de las
  consecuencias vive ahí — 5 tareas, 3 o 4, menos de 3, el cuarto apercibimiento.
- **AC3** — **Lo cierra un agente**, no una persona mirando o escuchando. Si no se puede
  verificar con un test, una medición o un valor que un gate lea, el que está mal escrito es el
  criterio.
- **AC4** — Si barre un directorio y enumera excepciones, **corré el barrido antes de escribir
  la lista**: de memoria sale corta y el AC nace imposible de pasar.

## Fuera de alcance

Qué **no** hace este spec. Es una frontera y es lo que lo vuelve revisable — no es deuda, salvo
que algún AC de acá dependa de lo excluido, y eso lo mira la revisión.

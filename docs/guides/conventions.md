# Directrices

Un gate, un hook o un test nuevo nombra el fallo que evita.

Acá van las directrices que ninguna herramienta verifica. Las que sí tienen verificador las nombra
`CLAUDE.md`, cada una con el suyo. Los principios están en la
[constitución](../architecture/constitution.md), y lo propio de cada capa en `.claude/rules/`.

## Código

- **Ante el rojo de un gate, mover la decisión, no pedir una excepción.** Bajarla a la capa que
  corresponde, o pasar el dato por parámetro en vez de ir a buscarlo.
- **Escribir en un comentario lo que el código no puede decir:** una decisión, una restricción
  del motor, un bug evitado.
- **Revisar si un archivo está en la carpeta correcta.** El gate de capas valida sólo el nombre
  de la carpeta.

## Documentación

- **Guardar en un doc sólo lo que ninguna fuente dice.** El porqué de una decisión, una trampa,
  el camino entre dos herramientas.
- **Nombrar la fuente en vez de copiarla.** Un número, una lista o una versión se citan por el
  archivo o el símbolo que los declara.
- **No escribir mediciones en un doc.** Un doc dice cómo se mide y dónde queda el resultado. La
  medición va al PR o al archivo que escribe el script.
- **Decir cada regla en un solo doc.** El otro enlaza.
- **No escribir referencias que caducan:** números de línea, conteos de archivos, fechas de una
  corrida.
- **Dejar un porqué sólo si registra un hecho de este repo, en una frase.**
- **No reescribir un ADR.** Es registro histórico, aunque nombre algo que ya cambió.

## Lenguaje

El texto sigue el modelo de **ASD-STE100**, aplicado al español. Vale para el código, los tests,
los comentarios, la documentación, `CLAUDE.md`, las reglas, los specs, los issues, los commits,
los PR y las respuestas de un agente.

1. Escribir una idea por oración.
2. Escribir instrucciones de 20 palabras o menos. Escribir descripciones de 25 palabras o menos.
3. Escribir párrafos de una idea y seis oraciones o menos.
4. Usar voz activa y tiempo presente.
5. Escribir los pasos en infinitivo: «Correr el gate», «Mover la regla al dominio».
6. Usar numeración para una secuencia y viñetas para un conjunto.
7. Poner la advertencia antes del paso al que aplica.
8. Usar un solo término por concepto. Usar el término del glosario. No usar sinónimos.
9. No usar palabras de relleno: «simplemente», «básicamente», «muy», «realmente».
10. Escribir los nombres de código, archivo y variable tal como son, entre comillas invertidas.

- **Escribir en español el contenido y en inglés los nombres de carpeta.** La excepción es el
  árbol de `src/`, que es vocabulario del GDD. En el texto, las excepciones las impone el motor:
  `_ready`, `_process`, `queue_free`, las APIs de gdUnit4.
- **Escribir un número medido con su medición, no con un adjetivo.** «Casi el triple» no es un
  dato.

## Glosario

Un término por concepto. La columna de la derecha no es estilo: son las palabras que ya
produjeron una confusión acá.

| Término | Significado | No usar |
|---|---|---|
| **jornada** | Una noche de la partida, numerada desde 1. | día, nivel |
| **turno** | El presupuesto de tiempo de una jornada, en segundos de ficción. | ronda, tiempo |
| **obligatoria** | Una de las tareas que el jefe pide esa noche. | misión, objetivo |
| **capacidad** | Una tajada de lo que el juego hace. Tiene un contrato en `specs/`. | módulo, feature |
| **contrato** | El spec de una capacidad, y la verdad a la que el código contesta. | documento, ficha |
| **criterio** | Un `AC-<COD>-###` del contrato. Lo cierra un agente. | requisito, tarea |
| **regla** | Un `BR-<COD>-###` del contrato. | norma, política |
| **issue** | El plan de una unidad de entrega, en formato task-brief. | ticket, tarea |
| **gate** | Un verificador que da rojo. Los del repo se llaman `gate_*.py`. | check, chequeo |
| **nodo de verificación** | Uno de los pasos que declara `NODOS` en `verificar.py`. | etapa, paso |
| **`Node`** | La clase del motor. Se escribe entre comillas invertidas y en inglés. | nodo (a secas) |
| **capa** | Uno de los directorios de primer nivel de `src/`. | módulo, paquete |
| **salteado** | Un nodo que no pudo correr y lo declara. **No es verde.** | omitido, skipped |
| **medido** | Que se corrió algo y contestó un número. | estimado, aproximado |

Los nombres de código no cambian por el glosario: `Tarea`, `Turno`, `_process`.

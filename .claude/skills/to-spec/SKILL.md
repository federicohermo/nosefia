---
name: to-spec
description: "Escribe o actualiza el contrato durable de una capacidad de No se fía — `specs/<capability>/<capability>.md`, con sus reglas BR y sus criterios AC. Usar cuando cambia lo que el juego tiene que hacer —una funcionalidad nueva, cambiada o que se quita—, antes de tocar una línea de código. Parte de un issue de tipo feature, de varios de una, o directo de un pedido. Para escribir el issue, to-issue."
argument-hint: "[NN del issue | capability | pedido en prosa]"
---

# to-spec — el contrato de una capacidad

Adaptado del skill `to-spec` de *spec-anchored agentic development*. **Un contrato durable por
capacidad, y el código contesta a él.** El spec no es andamio: se queda, y la diferencia entre lo
que dice y lo que el código hace es un hallazgo, nunca una excusa para reescribir el spec.

**Este skill no entrevista: las preguntas ya pasaron.** Convierte en archivo el material que hay: un issue
de tipo `feature`, una sesión de `shape`, notas o un pedido en prosa. Si falta material para una sección, **va a preguntas abiertas: no se pregunta acá, no se
inventa y no se rellena con un valor por defecto en silencio**.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md).

**Un spec no es un issue.** El issue es el plan descartable de un cambio; el spec es el
contrato que queda. Un issue puede traer los criterios que el spec necesita, pero acá se
reescriben como reglas y criterios de la capacidad, sin nada propio de esa entrega.

## Los tres modos

- **Crear** (la capacidad no tiene spec): se llenan todas las secciones de la plantilla con el
  material resuelto.
- **Actualizar** (ya existe): se produce el **delta**. Las reglas y los criterios nuevos llevan
  **IDs emitidos en continuación**, y **los existentes no se renumeran ni se reescriben** salvo
  que la entrevista haya resuelto explícitamente cambiarlos. El ID es la dirección: los issues y
  los tests apuntan ahí.
- **Borrar** (la funcionalidad se quita del juego): el spec se borra **en su propio commit**, y
  en la misma rama se borran el código y los tests que lo citaban. La historia queda en git.
  Si otra capacidad dependía de ésta, su spec se actualiza en la misma corrida.

## Varios de una

Con varios issues de una, agrupalos por el spec que tocan antes de escribir.

**Dos issues que emiten IDs nuevos en el mismo spec chocan.** Cada rama emite los IDs en
continuación del último que ve, y las dos emiten el mismo. El gate de specs ve el ID repetido
recién después del merge, y no ve qué test quedó citando un criterio ajeno. Hay dos salidas:

- **Repartí los IDs nuevos entre los dos antes de abrir las ramas.**
- **Escribilos en orden:** el segundo, desde `staging` con la rama del primero ya mergeada.

Si uno de los dos no emite IDs nuevos, como el que sólo borra, no hace falta repartir. Si no
comparten ningún spec, escribilos uno detrás del otro.

## Qué NO necesita tocar un spec

No todo cambio cambia el contrato. Estos no:

- **Un refactor.** Mismo comportamiento, otra forma. Va por `refactor/`.
- **Un bug** que no cambia ninguna regla del juego. Va por `bugfix/`.
- **Una mejora que no cambia ninguna regla**: UI, arte, audio, rendimiento. Va por
  `improvement/`.
- **El harness y los docs.** Rama `harness/` o `docs/`.

Sí lo tocan: una regla nueva, un valor de balance que cambia, un comportamiento que el GDD fija y
el juego no cumple, y un borde que nadie había escrito.

## Paso 1 — De qué capacidad es

`docs/architecture/capacidades.md` tiene las nueve, con qué decide cada una y qué pasa entre ellas. **Una capacidad es una tajada de lo
que el juego hace**, no una capa ni una clase.

Si no entra en ninguna, puede ser una capacidad nueva: se abre con su código de tres letras libre
—`gate_de_specs.py` da rojo si se repite— y su carpeta en inglés. **Antes de abrirla, probá que
no sea una regla de una de las nueve.** Una capacidad de un solo criterio casi siempre es una
regla de otra.

## Paso 2 — Medir, no suponer

**El contrato se escribe contra el código y contra el GDD, no contra la memoria.** Lo que hay que
tener a la vista antes de escribir una regla:

```bash
rg -n "class_name" src/dominio/ | head -40      # qué existe hoy
rg --no-ignore -n "AC-XXX" specs/ test/         # si ese ID ya se usó
```

- **Un valor de balance se cita, no se copia.** El número exacto sale del dominio: los
  apercibimientos de `src/dominio/reglas.gd`, el corte de las bandas de
  `src/dominio/empleo/consecuencia.gd`, y las cinco tareas de recorrer `Tarea.Tipo`.
- **El GDD manda sobre el código.** Si el GDD y el código difieren en un valor, la regla dice
  lo que dice el GDD y el código está en falta. Eso es el hallazgo.
- **Un hueco es una `OQ-<COD>-###`**, con por qué sigue abierta, quién la decide y qué bloquea.
  Nunca un valor inventado.
- **Lo que el motor soporta se mide en el juego, no en el editor.** Son dos procesos de Godot y
  pueden contestar distinto. Una medición en el editor no dice qué hace el juego.

## Paso 3 — Escribir las reglas y los criterios

La forma la fija [`specs/_template/capability-spec.md`](../../../specs/_template/capability-spec.md).
Lo que más se rompe:

- **Sin rutas de archivo, sin nombres de clase y sin nombres de escena.** Un spec que los nombra
  caduca con el refactor siguiente. Eso vive en el issue y en `docs/`.
- **Las reglas van en EARS** —«el sistema DEBE», «CUANDO …, el sistema DEBE», «SI …, ENTONCES el
  sistema DEBE», «MIENTRAS …, el sistema DEBE»— y cada una lleva su ID.
- **Cada criterio es DADO/CUANDO/ENTONCES con los valores que deciden**, nombra las reglas que
  verifica, y **lo cierra un agente**. «El HUD muestra el tiempo» no es un criterio; «con 3
  minutos restantes contesta 180.0» sí.
- **El criterio nombra el borde, no el caso feliz.** Cero, uno, el máximo, el valor justo antes
  del corte, el que llega dos veces. En este juego la aritmética vive ahí: las 5 tareas, 3 o 4,
  menos de 3, el cuarto apercibimiento.
- **Si un criterio barre un directorio y enumera excepciones, corré el barrido antes de escribir
  la lista.** De memoria sale corta y el criterio nace imposible de pasar.
- **Una tabla de valores se recalcula fila por fila desde la regla, y las puntas se derivan.** Una
  hora de cierre se calcula como apertura más duración, nunca se copia de la ficha: «doce horas,
  de las 20:00 a las 06:00» pasó por el spec y el issue con la suma sin hacer, y el primer test
  lo encontró.
- **Retirar es borrar.** Una regla o un criterio que sale del juego se borra entero: el
  encabezado, el texto, la pregunta abierta que lo cerró y el test que sólo lo citaba. No queda
  un «*Retirada*», ni una nota, ni un test que afirme que no está. El número queda como hueco:
  no se renumera y no se reutiliza. El gate de specs rechaza un encabezado «Retirada».

## Paso 4 — El pase de completitud

Antes de decir que está, las cuatro que el escritor tiene que poder afirmar:

- Cada sección de la plantilla está llena **o representada en preguntas abiertas**.
- **Cada regla tiene un criterio que la verifica**, o está declarada como territorio de juicio
  humano. Una regla sin criterio es una promesa.
- Cada valor de balance está citado y no copiado.
- El spec quedó **agnóstico de capa**: ni rutas, ni nombres de clase, ni nombres de escena. Sólo
  comportamiento y verdad del juego.

## Paso 5 — Verificar la forma

```bash
python .claude/scripts/gate_de_specs.py
```

Verifica el frontmatter, que el código de tres letras sea único, que ningún ID esté dos veces y
que cada criterio nombre una regla que el spec declara. Y cuenta, por cada `draft`, cuántos
criterios ya tienen test.

**El estado arranca en `draft`.** Pasa a `ratified` sólo cuando **todos** sus criterios están
nombrados por un test, y ahí el gate empieza a cobrarlo: un `ratified` con un criterio sin test es
rojo.

## Paso 6 — La rama y el PR

**El spec es el primer commit de la rama `feature/`**, y viaja en el mismo PR que el código que
lo cumple. Si sale de un issue, la rama es `feature/<N>-<kebab>`; si no, `feature/<kebab>`.

**El merge es la aprobación.** No hay un campo que alguien marque.

## Cuando el contrato y el código no coinciden

Es el caso que este método existe para hacer visible, y tiene una sola salida:

| Qué pasa | Qué se hace |
|---|---|
| el código no cumple un criterio | se corrige **el código**, con su test. Nunca el criterio |
| el criterio ya no describe lo que el juego tiene que hacer | es una decisión de diseño: se pregunta al usuario y se edita el spec |
| el comportamiento existe y no está escrito | se escribe la regla, y el criterio cita el test que ya lo prueba |

**Nunca se ajusta el spec para que coincida con el código.** Si difieren, eso es el hallazgo.

## Al cerrar

- `gate_de_specs.py` en verde, y `python .claude/scripts/verificar.py` si el PR toca código.
- Cada criterio nuevo que ya tenga test, **citado** en ese test: `# AC-EMP-004` al final de la
  línea de la función.
- El paso siguiente es `implement-feature`, en la misma rama.
- Si el spec falsificó algo que la documentación afirma en presente, actualizá `docs/`,
  `.claude/rules/` y `CLAUDE.md`.

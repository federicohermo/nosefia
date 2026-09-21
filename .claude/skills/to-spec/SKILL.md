---
name: to-spec
description: Escribe o actualiza el contrato durable de una capacidad de No se fía — `specs/<capability>/<capability>.md`, con sus reglas BR y sus criterios AC. Usar cuando cambia lo que el juego tiene que hacer, antes de tocar una línea de código. Para repartir un contrato ya escrito en issues, spec-to-tickets.
---

# to-spec — el contrato de una capacidad

Adaptado del skill `to-spec` de *spec-anchored agentic development*. **Un contrato durable por
capacidad, y el código contesta a él.** El spec no es andamio: se queda, y la diferencia entre lo
que dice y lo que el código hace es un hallazgo, nunca una excusa para reescribir el spec.

**Este skill no entrevista: las preguntas ya pasaron.** Convierte en archivo el material que hay
—lo normal es una sesión de `shape`, pero pueden ser notas o un pedido en
prosa—. Si falta material para una sección, **va a preguntas abiertas: no se pregunta acá, no se
inventa y no se rellena con un valor por defecto en silencio**.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md).

## Los dos modos

- **Crear** (la capacidad no tiene spec): se llenan todas las secciones de la plantilla con el
  material resuelto.
- **Actualizar** (ya existe): se produce el **delta**. Las reglas y los criterios nuevos llevan
  **IDs emitidos en continuación**, y **los existentes no se renumeran ni se reescriben** salvo
  que la entrevista haya resuelto explícitamente cambiarlos. El ID es la dirección: los issues y
  los tests apuntan ahí.

## Qué NO necesita tocar un spec

No todo cambio cambia el contrato. Estos no:

- **Un refactor.** Mismo comportamiento, otra forma. El spec no se entera.
- **Un bug de motor o de configuración** —una física mal seteada, un `.tscn` mal cableado— que no
  cambia ninguna regla del juego. Va por un issue de `bugfix/` y nada más.
- **Arte, audio, texto de contenido.** Entra como dato.
- **El harness, los docs y la CI.** Rama `harness/`, `docs/` o `ci/`, sin issue de capacidad.

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
- **El GDD manda sobre el código.** Si el GDD dice diez minutos y el código da veinte, la regla
  dice diez y el código está en falta. Eso es el hallazgo, y sale en un issue.
- **Un hueco es una `OQ-<COD>-###`**, con por qué sigue abierta, quién la decide y qué bloquea.
  Nunca un valor inventado.

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
- **Un ID no se renumera y no se reutiliza: se retira.** Uno nuevo sigue la numeración, aunque
  queden huecos.

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

## Paso 6 — El PR

**El spec es el primer commit, solo**, antes de que ningún issue lo referencie: entra por su
propia rama —`docs/<capability>`— y su propio PR. La excepción es el spec que se edita
implementando, que viaja en el PR del issue.

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
- Los criterios que todavía no tienen test se reparten con `spec-to-tickets`, en esta corrida. Un
  contrato escrito y no repartido es un plan que nadie va a ejecutar.
- Si el spec falsificó algo que la documentación afirma en presente, actualizá `docs/`,
  `.claude/rules/` y `CLAUDE.md`.

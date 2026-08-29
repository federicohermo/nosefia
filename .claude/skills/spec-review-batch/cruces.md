# Cruces — las contradicciones que sólo se ven con los N specs adelante

**Este archivo es el brief del carril de coherencia** del Paso 3. Ocho clases, cada una con cómo
se detecta y qué se edita. Son clases, no respuestas: el lote que tengas enfrente se deriva
igual, y **las ocho se recorren aunque siete den que no** — un cruce ausente es información, uno
no mirado no.

Todas se pagan tarde y caro. Cuando se descubren, dos ramas del lote ya están escritas y el
arreglo es un rebase. Acá el spec todavía es **texto**: el hallazgo se corrige en el spec que
corresponda y listo.

**Vos no escribís ninguno de esos arreglos.** El contrato del Paso 3 vale entero: devolvés la
edición propuesta con `path:línea` y el texto exacto, y **no abrís ni cerrás issues ni corrés
`publicar_spec.py`**.

**Ningún cruce queda anotado para después** —ver [`../sin-deuda.md`](../sin-deuda.md)—, así que el
que **excede al lote** no sale como issue: sale como **un spec más**, y lo escribe el padre en el
Paso 5. Lo que tenés que devolver listo para copiar es lo que ese spec necesita y vos sos el único
que lo tiene a la vista:

- **Un título que se entienda fuera del contexto de los dos specs.** Un cruce abarca dos, así que
  no hay uno solo que le sirva de contexto: es justo donde un título que arranque con «el problema
  del 002» no le dice nada a nadie dentro de seis meses.
- **La evidencia**: los dos `path:línea`, el número medido, y **qué AC queda infalsificable** si
  nadie lo toca. Es el `research.md` del spec nuevo, ya medido.
- **Qué specs quedan involucrados**, para que el `**Origen:**` y las citas cruzadas salgan bien.
  El `#N` de cada uno sale de `specs/mapa.json` y **no del `NNN`**: son dos numeraciones distintas
  y en este repo ya divergen —el spec 001 es el issue #3—.

**Y si el cruce se pudo colar porque una regla del método no lo atajaba, decilo.** Eso corrige el
`SKILL.md`, no el spec, y es lo único que impide que el mismo cruce vuelva en el lote siguiente.

> **Sobre los precedentes que se citan abajo.** Los que dicen *medido acá* se corrieron en este
> repo y se puede volver a correrlos. Los que dicen *medido en el repo de origen* vienen del
> harness del que sale éste: valen como clase, no como hecho de este juego. La distinción
> importa — un skill que presenta lo importado como propio le enseña a quien lo lea a no
> confiar en ninguna de las dos.

---

## 1 · Una medición vence cuando otro spec mueve lo medido

La firma de este skill, y la que ningún review suelto puede tener: un `research.md` mide contra
el repo de un día, y **el lote cambia ese repo antes de que el spec se implemente**.

Es la clase más probable acá porque la Desviación 4 de `specs/README.md` obliga a medir: cuantos
más números tenga un `research.md`, más superficie tiene para vencer. La medición no está mal
—estaba bien el día que se hizo—; lo que falta es **contra qué base vale**.

- **Se detecta** cruzando cada número del `research.md` contra los archivos que los specs
  anteriores del lote reescriben. Si el archivo medido está en la matriz de otro spec, la
  medición tiene orden.
- **Se edita** el enunciado de la medición para que declare su base. Una medición sin base
  declarada es infalsificable en cuanto el lote se reordena — y el lote se reordena siempre, en
  el Paso 2.

## 2 · Dos specs tocan la misma escena, y no es un conflicto: es corrupción

**La única clase de esta lista donde compartir el archivo ya es la conclusión.** Un `.tscn` no se
mergea: un merge de tres vías sobre una escena no da un conflicto que alguien resuelve, da una
escena rota que Godot abre a medias. Está en las trampas de `CLAUDE.md`.

Por eso `lote.py` la marca aparte —`<- ESCENA COMPARTIDA`— en vez de dejarla en el montón de
«compartido»: para todo lo demás compartir un archivo dice *dónde mirar*, y acá dice *qué hacer*.

- **Se detecta** en la matriz del Paso 2, sin leer nada más.
- **No se edita: se ordena.** Los dos specs se declaran en cadena —cuál va primero y por qué— y
  el orden va al reporte, que es lo que lee quien reparta el lote. Un `[P]` entre dos tareas que
  tocan la misma escena es un hallazgo bloqueante en los dos specs.

## 3 · Un número del balance que dos specs mueven

La arista más fácil de perder: no hay `preload` ni `class_name` que la delate, los dos specs
escriben el mismo archivo de `src/dominio/` y parecen un conflicto de merge cualquiera.

Y en **este** juego pesa más que en cualquier otro repo, porque la tensión central es
aritmética: cada minuto investigando es un minuto que no va a las tareas. Un spec que mueve la
duración del turno y otro que mueve el costo de una tarea **no chocan en ningún archivo** y sin
embargo cambian los dos el mismo presupuesto — que es lo que cada AC del otro está midiendo.

Su hermana barata, que se detecta igual: **el mismo valor fijo declarado en dos archivos
distintos**. La convención del repo es que un valor fijo vive una sola vez, en `src/dominio/`;
dos specs que lo necesitan y no se pusieron de acuerdo lo declaran cada uno en el suyo, y ningún
gate lo ve porque los dos archivos son válidos por separado.

- **Se detecta** con el tercer bloque de `lote.py` —los pares `X -> Y` de cada línea de tarea—
  cruzando los `Y` de un spec contra los `X` del resto, más los archivos de `src/dominio/`
  compartidos en la matriz. **Medido acá el 2026-08-28** sobre el lote 001 002 003:
  `src/dominio/reglas.gd` lo escriben el 001 (T002, la duración del turno y el costo de cada
  tipo) y el 002 (T003, `JORNADAS_HASTA_EL_DESPIDO`), y el `tasks.md` del 002 **lo declara** —
  «que es donde el spec 001 declaró que viven los números de balance». Ése es el caso sano: la
  arista existe y está escrita.
- **Se edita** la tarea de abajo para que cite el valor que deja la de arriba, y el AC para que
  diga contra qué valor se mide. Si el margen es de una unidad, decirlo no es opcional.

## 4 · Un spec produce el dato que otro apaga

Los dos specs son correctos por separado y **el lote entero puesto deja un AC infalsificable**.
Ésa es la consecuencia visible y es el mejor detector que hay: si un AC del lote no se puede
firmar con los N specs aplicados, hay un cruce de esta clase atrás.

Medido en el repo de origen, y es el caso testigo: un spec hace que la pieza muteada emita el
evento sin nota, y otro pone en `false` la bandera que habilita esa rama. Con los dos puestos el
resultado es silencio total, y un AC del segundo pide verificar lo contrario.

La forma que toma acá: un spec agrega un estado nuevo al turno o a una tarea, y otro agrega la
guarda que lo hace inalcanzable. En `dominio/` es puro, así que se puede seguir leyendo — no
hace falta levantar nada.

- **Se detecta** leyendo, para cada rama o estado que un spec agrega, quién la condiciona en los
  demás. `rg` sobre `src/` alcanza; para `specs/`, **`rg --no-ignore`**.
- **Se edita** el AC del spec de abajo, o su default. Nunca los dos: elegir cuál cede es la
  decisión, y va escrita con su porqué.

## 5 · Dos specs reclaman el mismo issue en su `origen`

Propia de este repo, y silenciosa de la peor manera: **`origen` significa saldar, no citar**, y
dos specs que ponen `**Origen:** #12` prometen los dos cerrar el mismo issue. Lo que pasa
después es que el primer PR que aterriza lo cierra con su `Closes #12`, y el segundo llega con un
`Closes` a un issue ya cerrado — o, peor, sin `Closes`, y el gate que pone en rojo un spec
cerrado cuyo `origen` sigue abierto **no dice nada**, porque el issue ya lo cerró otro.

El resultado es que el trabajo del segundo spec queda sin nada que lo reclame, que es
exactamente lo que `origen` existe para impedir.

- **Se detecta** cruzando el campo `origen` de las filas de `specs/mapa.json` del lote, más las
  líneas `**Origen:**` de cada `spec.md` —que son la fuente; el mapa es la copia—.
- **Se edita** dejando el `origen` en **uno** solo: el spec que efectivamente salda el issue. El
  otro lo cita en su prosa si le sirve de contexto, sin la línea del encabezado. Y si los dos lo
  saldan a medias, el hallazgo es que **falta partir el issue de entrada en dos**, y ahí sí se
  abre uno: no es registrar deuda propia, es arreglar la bandeja de entrada para que cada mitad
  tenga su `origen`. **Se parte ahora** — partirlo después es partir también los dos `Closes` que
  ya salieron.

## 6 · Una regla que cae de dos lados de la frontera de capas

Un spec ubica una regla del juego en `dominio/` y otro la asume en `sistemas/` o la escribe en la
pantalla. Por separado ninguno está mal escrito. Juntos, **la regla nace sin test**:
`gate_de_tests.py` no mira `ui/` ni `escenas/`, así que la mitad que quedó arriba no la verifica
nadie, y `gate_de_capas.py` recién grita al implementar — cuando ya hay dos ramas.

Su variante más cara es la que ni siquiera parte una regla: **dos specs deciden lo mismo dos
veces**. El caso que este juego tiene servido es la quinta tarea obligatoria, que el GDD deja sin
definir: dos specs del mismo lote pueden definirla distinto sin nombrarse nunca.

- **Se detecta** listando, por spec, qué decide y en qué capa lo pone; y cruzando las decisiones,
  no los archivos. Dos specs que deciden lo mismo **no comparten ningún archivo**, así que la
  matriz del Paso 2 no los ve: esta clase se caza leyendo, y es de las que justifican que el
  carril de coherencia tenga los N specs enteros adelante.
- **Se edita** bajando la regla entera a `dominio/`, en un solo spec, y dejando en el otro la
  cita. Si la decisión pertenece al GDD, el hallazgo es que **el spec está decidiendo algo que no
  le toca**, y eso frena con una pregunta al usuario.

## 7 · Lo que un spec declara es intención, no grafo

«Depende del 001» lo escribe quien planificó el lote, y planifica en fila porque así lo pensó.

Medido en el repo de origen: un lote declarado textualmente como *«una cadena»* de cinco
eslabones dio **tres carriles** al derivar el grafo de archivos. El error va en los dos sentidos
—dependencias que no existen y dependencias que no se declararon— y el segundo es el caro.

- **Se detecta** contrastando la matriz del Paso 2 contra lo que los specs declaran.
- **Se corrige donde se declaró** —el `tasks.md` o el `spec.md`, que todavía son texto— y el
  orden corregido es lo que va al reporte: es el insumo de `spec-implement-batch`, que reparte el
  lote en carriles a partir de exactamente esto.

## 8 · Dos specs declaran la misma tarea de documentación

Barato pero contagioso: los dos agregan la misma fila a `docs/architecture/directory-structure.md`
o reescriben el mismo párrafo de `CLAUDE.md`, y el segundo llega a un archivo que ya no dice lo
que su tarea supone.

- **Se detecta** en la matriz, filtrando por el verbo de la tarea: una mención adentro de una
  tarea de documentación no es una escritura de código, pero **sí** es una escritura de ese doc.
  `lote.py` no lo filtra a propósito —el verbo no se adivina— así que este filtro es tuyo.
- **Se edita** dejándola en uno solo, con la razón anotada. Si las dos tienen que quedar, la de
  abajo declara que la de arriba ya tocó el archivo.

---

**Y un caso que no es cruce sino permiso:** un spec puede declarar que tolera llegar antes que
aquel del que depende — *«sólo con el 001 mergeado; si éste llega antes, la tarea se deja abierta
y la cierra el 001»*. Eso no se corrige: se verifica que esté escrito, y **saca al spec de la
cadena**. Un permiso escrito no es un olvido, y tratarlo como olvido serializa el lote de gratis.

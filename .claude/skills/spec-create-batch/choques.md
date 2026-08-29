# Choques — lo que hay que decidir ANTES de escribir el lote

**Este archivo es el brief del Paso 2**, y lo recorre el padre, no un agente. Siete clases. Se
recorren **todas**, y las que dan que no también se escriben: un choque ausente es información, y
uno no mirado no.

La diferencia con [`cruces.md`](../spec-review-batch/cruces.md) es cuándo se paga:

| | acá | en `spec-review-batch` |
|---|---|---|
| Sobre qué | **los pedidos**, que todavía no son specs | los specs ya escritos |
| Qué se ve | lo grueso: el mismo trabajo dos veces, el mismo issue, la misma escena | lo fino: un AC que el otro spec vuelve infalsificable |
| Cuánto cuesta arreglarlo | **nada**: todavía no hay nada escrito | un párrafo |
| Quién lo mira | el padre, antes de lanzar | un carril propio, después |

Los dos pases hacen falta y ninguno reemplaza al otro. Éste existe porque **un agente que ya
escribió cuatro archivos no los tira**: si dos pedidos eran el mismo spec, para cuando alguien lo
note hay dos carpetas, dos issues y dos ramas. Cinco minutos acá.

**Lo que salga de acá es una decisión, no una pregunta.** Se decide, se escribe, y **va en el
prompt del agente que escribe ese spec, como parte de su encargo y con su porqué** — no como nota
al pie: el agente lo va a leer sin este contexto. Va también al reporte del Paso 6, que es donde
el usuario la ve: si quiere darla vuelta, revierte un párrafo, que sale más barato que el turno de
ida y vuelta que la habría evitado. Lo único que sigue frenando con `AskUserQuestion` es lo que
decide el GDD (clase 4).

---

## 1 · Dos pedidos son un solo spec

El más común y el más barato. Llegan como frases distintas —«el turno no avisa cuánto queda» y
«no se entiende cuándo se te acaba el tiempo»— y son un spec.

- **Se detecta** preguntando por el **cambio**, no por el síntoma: si los dos pedidos se
  satisfacen tocando los mismos archivos de `dominio/`, es uno.
- **Se decide** fundirlos, y el pedido que se cayó **se nombra en el `spec.md`** del que quedó.
  Sin esa línea, quien pidió lo segundo no tiene forma de saber que su pedido está adentro, y lo
  vuelve a pedir.

## 2 · Un pedido no necesita spec, y el lote lo va a escribir igual

La presión del batch es hacia escribir de más: ya están los N agentes lanzados, ya hay un
formato, sale casi gratis por unidad. Y un skill que obliga a cuatro archivos para arreglar una
tilde **se apaga entero**.

- **Se detecta** con la tabla de `spec-create` —«¿esto necesita un spec?»—, aplicada **una vez
  por pedido y antes de repartir números**. La pregunta que decide el carril es una sola: ¿el
  arreglo toca `src/` o `docs/`?
- **Se decide** sacándolo del lote y diciéndolo: va por rama `fix/` o `chore/` con su `Closes #N`,
  o directo si no tiene issue. **Un pedido sacado del lote se reporta igual** — si no, el usuario
  cree que su pedido se perdió.

## 3 · Dos specs reclaman el mismo issue en su `origen`

**`origen` significa saldar, no citar**, y dos specs que ponen `**Origen:** #12` prometen los dos
cerrar el mismo issue. El primer PR que aterriza lo cierra con su `Closes #12`; el segundo llega
con un `Closes` a un issue ya cerrado, y el gate que pone en rojo un spec cerrado cuyo `origen`
sigue abierto **no dice nada**, porque el issue ya lo cerró otro. El trabajo del segundo spec
queda sin nada que lo reclame — que es exactamente lo que `origen` existe para impedir.

En un lote esto es **probable, no excepcional**: si el lote sale de `deuda.py`, los N pedidos
vienen de la misma lista de issues.

- **Se detecta** cruzando los `#N` de `deuda.py` que cada pedido reclama, antes de escribir nada.
- **Se decide** dejando el `origen` en **uno**: el spec que efectivamente lo salda. El otro lo
  cita en su prosa, sin la línea del encabezado. Y si los dos lo saldan a medias, la decisión es
  que **falta partir el issue en dos**, y eso se hace ahora — partirlo después es partir también
  los dos `Closes`.

## 4 · Dos specs deciden lo mismo, y la decisión no es de ellos

La que este juego tiene servida: el GDD deja **una de las cinco tareas obligatorias sin definir**.
Dos specs del mismo lote pueden definirla distinto sin nombrarse nunca y sin compartir un solo
archivo — así que ninguna matriz los ve.

La familia es más ancha que ese caso: cualquier decisión de diseño que dos pedidos necesiten y el
GDD no haya tomado. Y el GDD **manda sobre cualquier cosa que diga el repo**, así que un spec que
la toma por su cuenta no está resolviendo una ambigüedad: está decidiendo en el documento
equivocado.

- **Se detecta** listando, por pedido, **qué decide** —no qué archivo toca—, y cruzando las
  listas.
- **Se decide con `AskUserQuestion`.** Es la única clase de este archivo que frena: el resto son
  decisiones técnicas que el padre toma y escribe, ésta pertenece al GDD y a quien lo escribe.

## 5 · Dos specs necesitan el mismo valor fijo

La convención es que un valor fijo vive **una sola vez**, en `src/dominio/`. Dos specs que lo
necesitan y no se pusieron de acuerdo lo declaran cada uno en su archivo, y **ningún gate lo ve**:
los dos son válidos por separado.

Y en este juego el valor fijo casi siempre es de balance —la duración del turno, el costo de una
tarea, cuántas jornadas hasta el despido—, o sea que las dos copias no divergen en un refactor:
divergen la primera vez que alguien ajusta la dificultad tocando una sola.

- **Se detecta** listando los números que cada pedido necesita fijar.
- **Se decide** nombrando **el archivo y el spec dueños**, y el otro spec cita. Eso va escrito en
  los dos `tasks.md`: el dueño lo crea, el otro declara de dónde lo saca. Es exactamente la forma
  que ya tiene el 002 respecto del 001 en este repo.

## 6 · Dos specs tocan la misma escena

**Un `.tscn` no se mergea**: un merge de tres vías sobre una escena no da un conflicto que alguien
resuelve, da una escena rota. Está en las trampas de `CLAUDE.md`, y es la única clase donde
compartir el archivo ya es la conclusión.

- **Se detecta** preguntando por escena, no por archivo: qué pantalla toca cada pedido.
- **Se decide ordenando, no editando.** Los dos specs se declaran en cadena —cuál va primero y
  por qué— y el segundo lo escribe en su `tasks.md`. Ningún `[P]` entre tareas que tocan la misma
  escena, ni adentro de un spec ni entre dos.

## 7 · El lote mide contra un repo que el lote va a cambiar

La Desviación 4 obliga a que el `research.md` **se mida**: qué corriste y qué contestó. Si tres
specs del lote van a aterrizar, la medición del segundo vale contra un repo que el primero ya
cambió.

No se arregla midiendo distinto —la medición está bien el día que se hace—. Se arregla
**declarando la base**.

- **Se detecta** derivando el orden probable del lote antes de escribir, con las clases 5 y 6
  puestas.
- **Se decide** que cada `research.md` diga contra qué base midió: `staging`, o `staging` más los
  specs que lo preceden. Una medición sin base declarada es infalsificable en cuanto el lote se
  reordena — y el lote se reordena siempre.

---

**Y una que no es choque sino permiso:** un spec puede declarar que **tolera** llegar antes que
aquel del que depende —«si éste llega primero, la tarea se deja abierta y la cierra el 001»—. Eso
no hay que corregirlo: hay que verificar que esté **escrito**, y saca al spec de la cadena. Un
permiso escrito tratado como olvido serializa el lote de gratis.

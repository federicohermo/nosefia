---
name: features-to-issues
description: "Trae de Notion las fichas de «Features y sistemas» con el diseño cerrado —las 🟩— y las convierte en issues de GitHub, o actualiza los issues que ya tienen. Usar con «pasá las features a issues», «qué fichas verdes no tienen issue», «actualizá los issues de Notion», o al arrancar una entrega y querer saber qué hay para construir. Deja cada ficha apuntando a su issue vigente."
argument-hint: "[nombre de una ficha | vacío = todas las 🟩]"
---

# features-to-issues — de la ficha al plan

**El issue sale de la ficha, no del GDD.** En Notion son dos cosas distintas:

- **«Features y sistemas»** es la base de fichas. Cada ficha tiene el diseño de una feature o un
  sistema, con el detalle suficiente para construirlo. **De acá sale el issue.**
- El **Game Design Document** es una página aparte: la visión, el core loop y el alcance. No
  tiene el detalle de ninguna feature, y tiene secciones sin llenar.

**El GDD manda sobre la ficha, y la ficha manda sobre el código.** Si una ficha contradice al
GDD, eso es un hallazgo y lo decide una persona. Si el GDD no dice nada del tema, la ficha
alcanza.

**Este skill nunca edita el diseño**, ni en la ficha ni en el GDD.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md).

## La señal es el cuadrado verde

**Una ficha 🟩 tiene el diseño cerrado y se puede construir.** 🟨 y 🟥 no: siguen en
discusión, y una ficha sin ícono todavía no se miró.

**La propiedad `Estado` no decide nada acá.** Está casi sin mantener —fichas ya implementadas
siguen en `Sin empezar`— y contradice al ícono.

## Paso 1 — Leer la base

```
notion-query-data-sources   # SQL sobre collection://602bf1c1-6da7-4f9a-aa16-ef1d35bd6372
notion-fetch                # una por ficha: el ícono está en `icon`, no en las propiedades
```

Si ese identificador ya no resuelve, la base se encuentra buscando «Features y sistemas» en
Notion, y el `fetch` de la base imprime la URL de su data source.

El SQL da las filas y sus URLs, pero **no da el ícono**: eso sale de `notion-fetch` por ficha.
Con muchas fichas, repartilas entre agentes y pediles sólo el ícono, el cuerpo y la línea del
issue. Traer las páginas enteras al contexto es el gasto más caro de este skill.

De cada ficha 🟩 salen cuatro cosas: el título, el `Resumen`, el cuerpo —que es el diseño— y la
**línea del issue**, que es el primer párrafo del cuerpo.

**Una ficha 🟩 puede estar incompleta igual.** Si el cuerpo no alcanza para escribir criterios
—no dice qué pasa en el borde, o el número que decide no está—, el issue no se inventa: el
problema se plantea en un comentario de la ficha, como dice el paso 6.

## Paso 2 — Cruzar con GitHub

```bash
gh issue list --state all --limit 100 --json number,title,state,body,labels
```

La línea de la ficha dice `issue #N`, con el número enlazado al repo. Por cada ficha 🟩:

| Lo que hay | Qué corresponde |
|---|---|
| sin línea, o «Sin spec todavía» | **issue nuevo** |
| `issue #N` abierto, y la ficha no cambió desde que se escribió | **nada** |
| `issue #N` abierto, y la ficha pide algo que el issue no dice | **editar ese issue** |
| `issue #N` cerrado, y la ficha pide algo más | **issue nuevo**, y la línea pasa a nombrarlo |
| `Spec NNN — issue #N` | la parte `Spec NNN` es del régimen viejo y **se borra**: hoy los specs son por capacidad y no se numeran |

**Un issue cerrado no se reabre.** El trabajo que ya entró está entregado; lo que falta es otro
cambio y va en otro issue.

**Una ficha puede necesitar más de un issue.** El corte lo decide `to-issue`, no el tamaño de la
ficha. Cuando son varios, la línea los nombra a todos.

## Paso 3 — Mostrar el reparto y esperar

Antes de escribir nada, mostrá una tabla: ficha, qué corresponde, y por qué. **Esperá.** Publicar
un lote entero de issues sin que nadie lo mire es un backlog, no un plan.

Dos cosas que decide el usuario: **qué fichas entran en esta tanda**, y el orden cuando una
depende de otra.

## Paso 4 — Escribir

**Cada issue lo escribe `to-issue`**, con el cuerpo de la ficha como pedido. Ahí se decide el
tipo, si toca un spec y cuáles son los límites de archivo. No lo repitas acá.

Para un issue que ya existe y quedó corto, `gh issue edit <N>`. **Se agrega lo que la ficha pide
y no está**; lo que ya dice el issue no se reescribe, porque puede haber PRs que lo citan.

## Paso 5 — Dejar la ficha apuntando a su issue

En Notion, `notion-update-page` con `content_updates`, sobre el primer párrafo del cuerpo:

```
issue #N
```

`issue #N` va como enlace a `https://github.com/federicohermo/nosefia/issues/N`. Con varios
issues, se separan con comas. **Eso es todo lo que este skill escribe en Notion.** El diseño de
la ficha, su `Estado`, su ícono y sus propiedades no se tocan.

## Paso 6 — Los problemas del diseño van a los comentarios

**El texto de una ficha no se reescribe nunca.** Lo que le falta, lo que se contradice y lo que
quedó viejo se plantea como **pregunta en un comentario de esa ficha**, con el arroba a quienes
deciden el diseño.

```
notion-create-comment       # page_id de la ficha, y el arroba de cada uno
notion-get-comments         # leer el comentario recién escrito, para ver cómo quedó
```

El arroba va como `mention` de usuario, con el **ID de usuario**:

| Quién decide el diseño | ID |
|---|---|
| Cami | `5004fd3f-7661-4ee0-bb8c-b9b1c2d77117` |
| Tiago | `b76e5dab-dfcb-45e5-8543-bc7e80dc9518` |

**Si hace falta buscar un usuario, es `notion-search` con `query_type: "user"`.** Devuelve nombre,
mail e ID. `notion-get-users` no sirve en este espacio: contesta sólo con su dueño y el bot del
MCP, y buscar por mail ahí devuelve vacío.

**Y el ID de usuario no es el de su página de People.** `notion-fetch` sobre una página de People
contesta 403, y ese ID en un arroba hace fallar el comentario entero con
`Could not find user with ID`. Medido el 2026-09-22.

**Comprobá el primer comentario leyéndolo de vuelta**, con `notion-get-comments`. Si el arroba
quedó como `<mention-user url="user://…"/>`, notificó; si quedó como texto, no notificó a nadie y
**el reporte lo dice**.

Un comentario, un problema. Cada uno dice qué dice la ficha, contra qué choca —otra ficha, un
spec, el código— y qué hay que decidir. No propone la respuesta como si estuviera decidida.

## Al cerrar

El reporte dice, por ficha: qué issue quedó, si es nuevo o editado, y qué fichas 🟩 quedaron sin
issue con su motivo.

Y lista los comentarios que dejaste, con su ficha y si el arroba notificó.

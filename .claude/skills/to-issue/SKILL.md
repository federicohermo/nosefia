---
name: to-issue
description: "Escribe y publica un issue de No se fía, o varios de una, con formato task-brief — el plan chico y descartable de un cambio puntual — y decide si cada cambio toca un spec. Usar apenas llega un pedido, un bug o una idea que se va a hacer, antes de abrir la rama; también con «abrí un issue», «armá el ticket» o la salida de shape en modo issue. Si el issue cambia lo que el juego tiene que hacer, después va to-spec. No escribe código ni specs."
argument-hint: "[pedido | bug | idea]"
---

# to-issue — el plan de un cambio

**Un issue y un spec son cosas distintas.** El issue es un plan chico: resuelve un problema
puntual, tiene límites y criterios propios, y se descarta al cerrar su PR. El spec es el contrato
durable de una funcionalidad. Un issue toca un spec sólo cuando cambia lo que el juego tiene que
hacer. Muchos issues no tocan ninguno.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md).

## Cuándo vale un issue

Casi siempre, y nunca a la fuerza. Un issue deja escrito qué se hace y cómo se sabe que está.
Si el usuario pide un arreglo para ahora y no quiere issue, se hace sin issue: un `bugfix/` o un
`improvement/` no lo exigen. Ofrecelo una vez y seguí.

## Paso 1 — Qué clase de cambio es

| Tipo | Qué es | Etiqueta | ¿Toca un spec? |
|---|---|---|---|
| `feature` | una funcionalidad nueva, cambiada o que se quita | `enhancement` | **siempre**: crea, modifica o borra |
| `bugfix` | el juego no hace lo que ya tiene que hacer | `bug` | casi nunca |
| `refactor` | el mismo comportamiento con otra forma | `refactor` | nunca |
| `improvement` | todo lo demás que no cambia ninguna regla: UI, arte, sonido, rendimiento, documentación, accesibilidad | `improvement`, más `documentation` o `accessibility` cuando aplica | nunca |

La etiqueta la pone `gh issue create --label`. Las de gestión —`duplicate`, `invalid`,
`wontfix`, `question`, `good first issue`, `help wanted`— no dicen de qué tipo es el cambio:
dicen en qué estado está el issue, y van sobre cualquier tipo.

**La prueba para el spec es una sola: ¿cambia lo que el juego tiene que hacer?** Una regla
nueva, un valor de balance, un comportamiento que el GDD fija, una funcionalidad que se quita.
Si la respuesta es sí, el tipo es `feature`.

**Un hotfix no es un tipo de issue.** Es un commit directo sobre `staging`, con el mensaje
empezando por `hotfix:`. No lleva issue, rama ni PR.

Un `bugfix` toca un spec en un solo caso: el bug era una regla que nadie había escrito. Ahí la
regla se escribe con el arreglo.

Si el tipo no está claro, preguntá. Es la decisión que define la rama y el resto del flujo.

## Paso 2 — Medir antes de escribir

**Los límites de archivo y los criterios salen del árbol de hoy, no de la memoria.**

```bash
rg -n "<lo que el issue va a tocar>" src/ test/ docs/   # una guía también describe la regla
gh issue list --state open --limit 50      # si ya hay uno igual, no se abre otro
```

Consultá `nosefia-index` para saber quién usa lo que vas a tocar. Lo que aparece ahí entra en
«Sólo lectura» o en «No se toca».

## Paso 3 — Escribir el issue

**El borrador sale del template, nunca de memoria.** Arrancalo con el script y llená el archivo
que deja:

```bash
python .claude/skills/to-issue/scripts/borrador.py nuevo <archivo del scratchpad>
```

Copia el [task-brief](../../../.github/ISSUE_TEMPLATE/task-brief.md) sin su encabezado. Se llenan
los huecos y no se agregan ni se sacan secciones. Los comentarios quedan: GitHub no los muestra.
Lo que más se rompe:

- **Un issue, un problema.** Completá esta frase: «después de este issue, <algo observable>». Si
  no se completa, el corte está mal. Si se completa con dos cosas sin relación, son dos issues.
- **Los criterios son del issue**, binarios y con los valores que deciden. Si el issue toca un
  spec, los `AC-<COD>-###` nuevos o cambiados van también acá, y **los escribe `to-spec`**, no
  este skill. Acá se nombran por lo que tienen que decir.
- **La fila «No se toca» es una lista cerrada que prohíbe.** Ahí van los `.tscn` que otro issue
  en vuelo edita: una escena no se mergea. Si dos issues tocan la misma escena, el segundo dice
  `Depende de #N`.
- **El primer comando de verificación es siempre `python .claude/scripts/verificar.py`.** El
  veredicto sale del código de salida, nunca de un grep.
- **Un comando que prueba una ausencia se corre hoy, y devuelve todo lo que el criterio saca.**
  Si deja casos afuera, se amplía. Si no se puede, el criterio nombra el test que los cubre. En
  el #140, el `rg` de la verificación no veía los productos de la raíz del modelo.
- **Un valor de balance no se inventa.** Un costo, un tiempo o un umbral sale del GDD o del
  dominio. Si ninguno lo fija, el criterio lo nombra como pregunta abierta y `to-spec` lo
  registra. Un número propuesto por el agente se lee como decidido.
- **Un síntoma medido se reproduce en las condiciones del criterio antes de pedir su rojo.** Si
  el criterio excluye un caso —un obstáculo, un cuadro de transición—, la medición también lo
  excluye. En el #187, los saltos de lo que se lleva se midieron en el local, y eran del brazo
  rozando un mueble: en un piso libre no había rojo que pedir.
- **Los bordes van escritos.** El caso feliz lo cubre cualquier implementación.
- **Un criterio de rendimiento dice desde dónde se mide, y desde ahí se ve lo que el cambio
  agrega.** Lo que no está en pantalla puede no costar nada. En el #181, el p95 se medía desde
  donde arranca el jugador, el agua del baño no se veía desde ahí, y su simulación estaba en
  pausa: el criterio salía verde sin medir el agua.
- **Una tabla de ejemplos cierra consigo misma.** Cada fila se recalcula desde la regla antes de
  escribirla, y una hora de cierre es apertura más duración, no un número copiado de la ficha.
- **Si el issue deja renombrar algo, el `rg` de los límites se corre también sobre los
  comentarios.** Un archivo en «Sólo lectura» que nombra por ruta lo que se renombra queda
  mintiendo, y el implementador no lo puede tocar.
- **Si el issue cambia una regla, el `rg` de los límites busca también la regla vieja en
  palabras.** Un símbolo no encuentra el comentario que explica la regla con otras palabras, ni
  el test que arma el estado que la regla lee. En el #166 quedaron fuera de «Se escribe» cinco
  archivos con comentarios y un test.

## Paso 4 — Mostrar y publicar

Primero, el script revisa el borrador contra el template:

```bash
python .claude/skills/to-issue/scripts/borrador.py revisar <archivo del scratchpad>
```

Si sale con 1, nombra lo que falta: una sección que no está o sobra, un hueco sin llenar, un
campo copiado tal cual. Se arregla y se vuelve a correr. **Con un 1 no se muestra ni se publica.**
El único hueco que deja pasar es `<issue>` en la rama: el número no existe hasta publicar.

Mostrá el issue **entero, como va a quedar publicado**, y no un resumen. Esperá la
confirmación. Después:

```bash
gh issue create --title "<qué cambia>" --label <etiqueta> --body-file <archivo del scratchpad>
python .claude/skills/to-issue/scripts/borrador.py numerar <archivo del scratchpad> <N>
gh issue edit <N> --body-file <archivo del scratchpad>
```

`numerar` escribe el número en la rama y revisa sin dejar pasar nada. El cuerpo no se commitea:
el issue es la fuente.

## Varios de una

Con varios issues de una, antes de mostrar nada:

1. **Cruzá las filas «Se escribe» de todos los borradores.** Si dos comparten un archivo,
   elegí cuál va primero y publicalo primero. El otro dice `Depende de #N`, con el número ya
   publicado. Hasta entonces nombra al primero por su título: `<issue>` no sirve, porque
   `numerar` lo reemplaza por el número propio. Sin un archivo en común, el orden da igual.
2. **Dos issues que se bloquean entre sí son un solo cambio mal cortado.** Cortalo de nuevo antes
   de publicar.
3. **Mostrá todos los borradores enteros, cada uno con `revisar` en 0, y esperá un solo sí
   sobre el lote.** Si el usuario aprueba una parte, publicá sólo esa parte. Los demás
   borradores quedan en el scratchpad.

## Al cerrar

Reportá el número del issue, el tipo, y el paso siguiente:

- **Spec: crea, modifica o borra** → `to-spec`, con el issue como entrada, en la rama
  `feature/<N>-<kebab>`.
- **Spec: ninguno** → `implement-feature`, en la rama `<tipo>/<N>-<kebab>`. Un issue que no toca
  `src/` se nombra por lo que toca: `harness/<N>-<kebab>` o `docs/<N>-<kebab>`.

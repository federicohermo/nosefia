---
name: spec-implement-batch
description: Implementa N specs de specs/ en paralelo —un carril por cadena de dependencias, cada uno en su worktree— delegando cada spec a spec-implement, y cierra con un PR por spec, verificar.py en verde y ninguna tarea sin marcar. Usar al implementar dos o más specs de una. Para uno solo, spec-implement.
argument-hint: "<NNN NNN ...> | <NNN-MMM> | --propuestos [--dry] [--max N]"
# Sin `allowed-tools`, igual que el resto de los skills de este repo: éste abanica agentes,
# abre worktrees, corre el harness en Python y habla con GitHub por `gh`. Declarar una lista
# parcial le sacaría todo lo que no estuviera en ella y lo rompería en silencio a mitad de
# corrida.
---

# spec-implement-batch — No se fía

## Matriz del lote

<!-- Inyección dinámica: corre ANTES de que el modelo procese este archivo, así que la matriz
     llega con el skill ya cargado en vez de costar un turno de tool. Es el MISMO script que usa
     `spec-review-batch`, alcanzado por ruta de hermano: la pregunta «qué archivo tocan dos
     specs del lote» es idéntica en los dos, y duplicar el parser del `tasks.md` es la clase de
     deuda que se descubre cuando uno cambia y el otro no. -->

!`python "${CLAUDE_SKILL_DIR}/../spec-review-batch/scripts/lote.py" $ARGUMENTS`

---

`spec-implement` abanica los **pasos** de un spec. Este reparte **specs** en carriles.

Esa diferencia manda todo lo demás. Adentro de un spec, el padre escribe los archivos compartidos
al converger. **Entre carriles ese padre no existe**: cada carril tiene su árbol de trabajo y
converge recién en el merge, que resuelve texto y no semántica.

**El skill global es el piso; este archivo manda.** Y no deja deuda: las cinco descargas están en
[`../sin-deuda.md`](../sin-deuda.md), con una vuelta propia — ver «el lazo», al final.

## Lo que este repo cambia respecto del batch genérico

| El batch genérico | Acá |
|---|---|
| `node scripts/matriz.mjs` sobre los `tasks.md` | **`lote.py` de `spec-review-batch`**, inyectado arriba: misma matriz, y además marca la **escena compartida** |
| Instalar dependencias en cada worktree (`node_modules`) | **No hay install**: `addons/gdUnit4` está vendorizado. Lo que sí falta es `specs/` — ver Paso 3 |
| El PR nombra una actividad de Jira, y hay un script de claves | **No hay Jira.** El PR lleva `Closes #N` por cada issue saldado: el del spec **más los de su `origen`** |
| La rama se llama como convenga | **`feature/<NNN>-<kebab>` o el hook bloquea `src/`.** Es la falla número uno acá |
| Cierra con `pnpm verify` | **`verificar.py`**, y un nodo **salteado no es un nodo verde** |
| Un conflicto se resuelve leyendo | **un `.tscn` no se mergea**: dos specs sobre la misma escena **no van en carriles distintos** |
| Deja al usuario mover el estado del registro | **Nadie toca `specs/mapa.json` en un PR**: lo deriva la Action en el push a `staging`, y el gate da rojo si el mapa se adelanta |

## Arista, conflicto, o escena — la decisión que define el lote

Es la que se equivoca hacia el lado conservador: si tratás **cada archivo compartido como arista**,
el lote colapsa a una cadena de ancho 1 y el batch deja de comprar nada.

| Entre A y B | Es | Cuesta |
|---|---|---|
| B usa el `class_name` que A crea | **arista** | serie |
| B parte de un valor de `dominio/` que A mueve | **arista** | serie |
| Escriben la misma función del mismo `.gd` | **arista** | serie |
| Escriben regiones distintas del mismo `.gd` | **conflicto** | una resolución de merge |
| **Tocan el mismo `.tscn`** | **arista, siempre** | serie — y no se negocia |

**La última fila es de este repo y no admite el juicio de las otras.** Un merge de tres vías sobre
una escena no da un conflicto que alguien arregla: da una escena rota. `lote.py` la marca sola
(`<- ESCENA COMPARTIDA`), y esa marca **ya es la conclusión**: esos dos specs van en el mismo
carril, en orden.

Y **`.gitattributes` no te cubre**: marca `binary` los `.png` y los `.ogg` con el argumento escrito
de que un merge de tres vías los corrompe, y **no marca los `.tscn`**. O sea que git los va a
mergear alegremente.

---

## Paso 0 — Leer la matriz, y sacar los que no van

`$ARGUMENTS`: números sueltos (`007 008 009`), un rango (`007-009`), o `--propuestos`. **Sin
argumentos, preguntá.**

1. **Sacá los terminales.** `Descartado` y `Superado` no se implementan. Decí cuáles sacaste.
2. **Sacá los que ya tienen rama.** `git ls-remote --heads origin 'feature/*'`: puede haberla
   abierto otra sesión, y ahí lo que corresponde no es un carril nuevo.
3. **Mirá si el lote pasó por `spec-review-batch`.** Si sí, el Paso 2 es **verificación** y no
   derivación: los cruces ya están decididos y escritos en los specs. Si no, decilo — vas a estar
   derivando en el momento más caro del flujo, con los worktrees a punto de abrirse.

Con `--dry` se corre hasta el reporte del Paso 1 y ahí termina: no se abre ningún worktree.

## Paso 1 — Repartir en carriles

1. **Aplicá la tabla de arriba** a cada archivo compartido que la matriz lista.
2. **La arista real de Godot se cruza nombrando un `class_name`**, y no deja rastro en ningún
   `preload`. Buscá por identificador, no por import — es la misma razón por la que
   `gate_de_capas.py` indexa las clases en vez de mirar los `preload`.
3. **Contrastá contra las dependencias que los specs declaran.** Eso dice qué quiso el autor; el
   grafo dice qué va a pasar. **Si difieren, ése es el hallazgo** y va al reporte.
4. **Cada cadena de aristas es un carril.** Los specs sin aristas entre sí van en carriles
   distintos.

**Terminado cuando** cada spec está en exactamente un carril y **cada arista tiene escrito el
archivo o el `class_name` que la justifica**. Un carril sin esa justificación es una cadena
adivinada.

Si sale **un solo carril**, decilo y **arrancá igual en serie, sin preguntar**: el batch sigue
comprando el preámbulo y el Paso 2, pero no compra reloj. Que no compre reloj es un dato del
reporte, no una decisión que necesite al usuario.

## Paso 2 — El checker cruzado, antes de escribir una línea

Cuatro preguntas que ningún `spec-implement` suelto puede contestar, porque mira un spec:

1. **Un valor de `dominio/` que dos specs mueven.** Es el caso propio de este juego: los valores
   fijos viven en un solo archivo por convención, así que **el lote entero converge ahí**.
   Confirmá que el segundo parte del valor que deja el primero y no del de la base.
2. **Un spec produce el dato que otro apaga.** Con los dos puestos el resultado no es ninguno de
   los dos, y un AC del segundo pide verificar lo contrario.
3. **Un spec baja al dominio una regla que otro escribió arriba.** El segundo pasa los seis nodos
   en verde con la regla duplicada, una en `dominio/` y otra en un `_process`.
4. **Un spec que cierra una tarea de otro.** Es la única escritura que sale de su propio spec:
   anotala para que dos carriles no la pisen.

Lo que salga es **una decisión de diseño que le falta al spec**. Decidila, escribila en el
`spec.md`, y **devolvela al issue con `publicar_spec.py publicar`** antes de abrir los worktrees —
`specs/` es caché, y el worktree va a hidratar **desde el issue**, así que una corrección que sólo
esté en tu disco no llega a ningún carril.

No se frena con `AskUserQuestion` salvo que la decisión sea del GDD. Arreglar un spec cuesta un
párrafo; arreglar dos carriles cuesta un rebase.

**Terminado cuando** las cuatro tienen respuesta escrita, **incluidas las que dieron que no**.

## Paso 3 — Un worktree por carril

**Por carril, no por spec.** La cadena de un carril se apila adentro de su propio worktree y no
necesita gimnasia de ramas; lo que se aísla es el carril, que es lo que corre concurrente.

Lanzá los carriles en **un solo mensaje**, un `Agent` por carril con `isolation: "worktree"`.

Cada agente recibe, literal:

- **El preámbulo destilado una vez para todo el lote**: las cuatro capas y su dirección, las
  convenciones verificables con **quién verifica cada una**, y las trampas de este repo. Es el
  ahorro propio del batch — sin esto, N carriles lo re-derivan N veces desde frío.
- **La rama se llama `feature/<NNN>-<kebab>` y eso no es decorativo.** `gate_de_spec.py` corre como
  hook y **bloquea toda escritura a `src/` y `docs/` desde una rama que no matchee
  `^feature/(\d{3})-` con ese `NNN` en `specs/mapa.json`**. El síntoma es un `Edit` denegado, que
  se lee como un problema de permisos y no como uno de nombre. **Es la falla número uno de un
  carril**, y aparece recién en la primera edición, con el worktree ya abierto.
- **Hidratar antes de leer nada**: `python .claude/scripts/hidratar_specs.py <NNN>`, por cada spec
  del carril. `specs/[0-9]*/` está en el `.gitignore`, así que **`git worktree add` sólo trae lo
  trackeado** y al worktree llegan `mapa.json` y `README.md` y ningún spec. Sin esto el carril
  implementa sin spec — que es la versión cara de fallar en verde, porque igual termina y reporta.
- **`Grep` no ve `specs/`.** Es ripgrep y respeta el `.gitignore`: contesta cero sin decir que no
  miró. Para buscar ahí, `rg --no-ignore … specs/`.
- **No hay install que correr**, pero **`GODOT_BIN` tiene que estar en el entorno del carril**: sin
  ella `verificar.py` **saltea** el nodo `tests` y lo declara, y un carril que lee «6/6» sin mirar
  los salteados da por corrida una suite que no corrió.
- **Que delegue cada spec a `spec-implement`**, que deriva el grafo interno y abanica lo que
  corresponda, **y que cierre cada uno antes de arrancar el siguiente**.
- **La base del primer spec del carril es `staging`**; los que siguen, la rama del spec anterior
  **del mismo carril** — PRs apilados, porque cada uno necesita la historia del anterior.
- **El PR lleva un `Closes` por cada issue saldado**: el del spec **más los de su `origen`**. **El
  `#N` sale de `specs/mapa.json` y no del `NNN`** —el spec 001 es el issue #3—: un `#N` equivocado
  cierra el issue que no es, y nada en ningún diff lo delata.
- **Que no toque nada compartido entre carriles**: ni `CLAUDE.md`, ni `docs/`, ni `.claude/`, ni
  `specs/mapa.json`. Vuelve como **edición propuesta** con `ruta:línea` y el texto exacto, y lo
  aplica el padre en serie.
- **El mensaje de commit se escribe con `Write` a un archivo y se pasa con `-F`, nunca con
  heredoc.** Los backticks y los `$` del contenido lo rompen con un `unexpected EOF` que cuesta más
  diagnosticar que reescribirlo — está medido en esta máquina.

### La condición de terminado del carril — no se negocia

> **Un carril termina con el PR abierto y sin una sola casilla sin marcar. No antes.**
>
> Por cada spec suyo: `verificar.py` en verde **sin nodos salteados**, todas las tareas del
> `tasks.md` hechas y marcadas, **las marcas devueltas al issue** con
> `python .claude/scripts/publicar_spec.py publicar`, rama pusheada y PR abierto contra la base
> que le toca.
>
> **No existe volver con «quedó listo para commitear», «falta abrir el PR» ni «lo dejo en el
> working tree».** Y no existe volver con una casilla abierta: si el `tasks.md` tenía trabajo que
> no se hizo, el carril no terminó — ver el lazo, abajo.
>
> Si algo bloquea de verdad, el carril **igual vuelve con lo que sí cerró**, y el bloqueo escrito
> con su evidencia y el comando exacto. Lo que no vuelve nunca es un carril entero sin entregar
> nada.

**El padre lo verifica, no lo cree.** Cuando vuelva un carril, chequeá con `gh pr list --head
<rama>` que cada spec suyo tenga PR, y con `hidratar_specs.py` que el `tasks.md` del **issue** no
tenga casillas abiertas. Un reporte que dice «listo» sin PR es un carril incompleto: terminalo vos
o relanzalo con lo que le faltó.

Esperá a que vuelvan todos antes del reporte.

## Paso 4 — Lo que sólo el padre puede cerrar

- **Las ediciones fuera de carril**, en serie, para que el diff se lea.
- **El lazo, y es del padre por construcción**: si dos carriles corrigen el mismo `SKILL.md` a la
  vez, se pisan sin conflicto visible. Ver abajo.
- **Los `Closes` que el lote mueve.** Si dos specs del lote declaran el mismo `origen`, el primer
  PR que aterriza cierra el issue y el segundo llega con un `Closes` a un issue ya cerrado — y el
  gate que pone en rojo un spec cerrado cuyo `origen` sigue abierto **no dice nada**, porque lo
  cerró otro. Se arregla dejando el `origen` en uno solo.
- **`python .claude/scripts/verificar.py`** en el checkout principal, con todo mergeado hacia
  arriba. Los seis nodos verdes por carril no implican los seis verdes juntos.

## Paso 5 — Destruir los worktrees

```bash
python .claude/scripts/limpiar_worktrees.py --todos
```

**Va antes del reporte, no después, y no se hace a mano.** `git worktree remove` falla con
`Directory not empty` en **todo worktree que haya corrido `verificar.py`**, o sea en todos: el nodo
`tests` levanta Godot headless y Godot escribe su caché en `.godot/`, que está en el `.gitignore`.
`--force` no ayuda — no es un problema de cambios sin commitear.

Y mata **por ruta del worktree, nunca por nombre de proceso**: un filtro por `godot.exe` se
llevaría puesto el editor que el usuario tiene abierto con el checkout principal.

Si imprime `SIGUE AHI`, el handle es de afuera. **Lo cierra el usuario, no vos**: decilo.

## Paso 6 — El reporte

1. **Si algo quedó bloqueado, la primera línea dice que la corrida falló.** No «se cerró casi
   todo».
2. **Una tabla, una fila por spec:** `NNN`, carril, PR, `Closes` que lleva, y **si `verificar.py`
   pasó a la primera, a la segunda, o con algún nodo salteado**. La tercera opción no se omite.
3. **Los carriles, su ancho, y cuántas de las aristas declaradas resultaron falsas.**
4. **Qué encontró el Paso 2 y qué se decidió** — el entregable propio de este skill.
5. **Qué obligó a corregir un `spec.md`**, y que se devolvió al issue.
6. **Qué `SKILL.md` se corrigió y con qué regla.** Es el lazo, y es lo único que impide que el
   mismo problema vuelva en el lote siguiente.
7. **El orden de merge, de abajo hacia arriba**, y que un squash obliga a rebasear el carril de
   arriba.
8. **Las escenas que el lote tocó**, y si alguna hay que rehacer a mano en el editor.

**El reporte no puede decir «queda pendiente».** Si aparece esa frase, algo no se descargó.

## El lazo — si implementar duele, el problema está aguas arriba

**Para cuando este skill corre, las dudas de planteo deberían estar resueltas**: las cierran
`spec-create` y `spec-review`, donde cuestan un párrafo. Entonces **una duda que aparece acá es
evidencia de que uno de esos dos tiene un agujero**, y en un lote la evidencia es más fuerte que en
un spec suelto: si tres carriles tropiezan con lo mismo, no fue mala suerte.

Las dos mitades, las dos en esta corrida:

1. **El carril corrige su spec** para poder seguir, y lo devuelve al issue.
2. **El padre corrige el `SKILL.md`** que lo permitió, con la regla que lo habría atajado. La tabla
   de qué skill corregir está en [`../sin-deuda.md`](../sin-deuda.md), y **está incompleta a
   propósito**: si tu caso no entra, agregá la fila.

**Es del padre y no del carril**, y no es una preferencia: `.claude/` es el único árbol que los N
carriles comparten, y dos worktrees editando el mismo `SKILL.md` se pisan en silencio — el segundo
`git add` gana y nadie ve un conflicto.

## Lo que no hace

- **No escribe specs ni los audita.** Eso es `spec-create-batch` y `spec-review-batch`, y los dos
  corren antes y salen mucho más baratos: un cruce detectado como texto cuesta un párrafo.
- **No mergea a `staging`, y no mueve `specs/mapa.json`.** El estado lo deriva la Action en el push
  a `staging`, y el gate da rojo si el mapa se adelanta al PR.
- **No revisa los PR que abre.** Eso es `pr-review-batch`, y corre después.
- **No abanica los pasos de un spec** — eso es `spec-implement`, adentro de cada carril.
- **No abre el juego.** Corre la suite en headless. Si un spec toca algo que se ve, la verificación
  en pantalla queda **declarada en el reporte** con qué habría que medir.

---
name: spec-review
description: Especialización de /spec-review para No se fía (Godot). Dónde vive el registro en este repo, el contrato de tasks.md, y las convenciones que un spec suele violar por escrito. Se lee junto con el skill global.
---

# spec-review — No se fía

Este archivo **no reemplaza** al skill global: aporta lo que en este repo es distinto. Los
ejes, los gates y el formato del reporte salen de allá.

**Y acá el review corrige, no señala.** Todo lo que encuentra sale por una de las cinco descargas
de [`sin-deuda.md`](sin-deuda.md), y ninguna es «lo dejo anotado». Es el momento
más barato del flujo para hacerlo: **mientras el spec es texto, un hallazgo cuesta un párrafo**; el
mismo hallazgo detectado implementando cuesta un rebase, y detectado en el PR cuesta además el
review del PR.

## Antes de leer un spec: traerlo

`specs/[0-9]*/` está en el `.gitignore`. Un review sobre un directorio vacío **no falla**:
audita un spec que no leyó, y reporta igual. Antes de nada:

```bash
python .claude/scripts/hidratar_specs.py <NNN>
```

Y para buscar adentro de los specs, `rg --no-ignore`: `Grep` es ripgrep y respeta el
`.gitignore`, o sea que contesta cero sin decir que no miró.

## Dónde está cada cosa acá

El registro está partido en cuatro, y buscar la deuda en `specs/README.md` la deja fuera del
review entero:

| Dónde | Qué tiene |
|---|---|
| `specs/mapa.json` | El mapa spec↔issue y el estado de cada uno |
| **GitHub Issues** | La deuda registrada **sin** spec — es el mapa síntoma → deuda |
| Los comentarios del issue de cada spec | Qué se aprendió escribiéndolo o revisándolo. Acá está el «esto ya se probó y no funcionó» |
| `specs/README.md` | Sólo la convención de formato y el flujo |

**`Descartado` y `Superado` son terminales.** Un spec en uno de esos dos no se revisa ni se
corrige: es historia.

**Que el spec bajo review contradiga a uno anterior no es un hallazgo.** Los specs son planes
con fecha, no documentación de lo que el código hace hoy: dar vuelta una decisión vieja es
para lo que existe un spec nuevo.

## El contrato de `tasks.md`

```markdown
- [ ] T012 [P] Descripción, con la ruta del archivo que toca
```

Al revisar, verificá:

- **Cada tarea lleva su `T0NN`**, sin duplicados, y **los IDs no se renumeraron** respecto de
  la versión anterior. Renumerar rompe toda referencia que otra tarea le hiciera.
  **Una tarea nueva va con el número libre siguiente y se escribe donde corre**, porque el ID
  no es el orden. El sufijo de letra —`T001a`— **es rojo**: el gate exige tres dígitos exactos
  (`TAREA = ^- \[[ x]\] (T\d{3})( \[P\])? \S`). Medido en el lote 001–002 el 2026-08-30, donde
  los dos agentes lo pisaron el mismo día.
- **Ninguna tarea se cierra mirando o escuchando.** Una tarea que dice *a ojo*, *de oído*,
  *captura* o *mirar la pantalla* es un hallazgo, y el arreglo es volverla verificable —un test
  de gdUnit4, un número medido, un valor que un gate lea— o sacarla. Marcarla no es una salida.
  Lo verifica `test_convencion_de_specs.py`, pero sólo sobre los specs hidratados: si el review
  corre sobre un árbol vacío, el gate se saltea **declarándolo** y el que mira sos vos.
- **`[P]` no miente.** Dos tareas `[P]` del mismo bloque no pueden tocar el mismo archivo. Es
  el hallazgo más caro de los tres, porque `spec-implement` las abanica en paralelo y el
  conflicto aparece recién al escribir.
- **Ninguna sección que aplace y ninguna tarea que aplace.** Ni `## Seguimiento` ni sus alias
  —`## Pendientes`, `## Próximos pasos`, `## Deuda`—, ni una casilla que diga `TODO`, «por ahora»
  o «más adelante». Adentro del spec el ítem **hereda el estado de su spec**, y un spec
  `Implementado` con diez casillas abiertas no le debe nada a nadie: así se vuelve invisible.
  Lo verifica `test_convencion_de_specs.py` sobre los specs **hidratados**.
- **`## Fuera de alcance` sí se queda, y es lo único de esta lista que tenés que juzgar vos.**
  Declarar una frontera hace revisable al spec; el gate no puede distinguirla de una deuda con
  sombrero. La prueba es una: **¿algún AC de este spec depende de lo excluido?** Si sí, entra al
  spec ahora.
- **Las tareas están completas.** Que las que hay sean correctas no alcanza: si el spec necesita
  algo que ninguna tarea cubre, **el hallazgo es la tarea que falta** y se escribe acá. Es el eje
  que más rinde en este paso, porque una tarea faltante no rompe ningún gate — simplemente nunca
  se hace.

## Lo que hay que mirar en un spec de este juego

Ocho preguntas que en un repo de Godot deciden si el spec es implementable:

1. **¿En qué capa cae cada cosa?** Si el spec propone una regla —cuántas tareas, qué pasa a los
   dos días, qué cuenta como cumplir— y la ubica en un `Node` de `sistemas/` o en una escena,
   esa regla **nace sin test**: `gate_de_tests.py` no mira `ui/` ni `escenas/`, y en
   `sistemas/` sólo se puede probar lo que no necesita frames. La corrección es bajarla a
   `dominio/`, y el spec tiene que decirlo.
2. **¿Cruza alguna frontera de capa?** Un spec que necesita que el dominio sepa algo de la
   pantalla está mal planteado, y lo va a frenar `gate_de_capas.py` recién al implementar.
3. **¿Los criterios de aceptación se pueden ver fallar?** «El HUD muestra el tiempo» no; «con
   3 minutos restantes, `tiempo_restante()` devuelve 180.0» sí.
4. **¿Toca escenas que otro spec del lote también toca?** Un `.tscn` no se mergea: un merge de
   tres vías sobre una escena produce una escena rota, no un conflicto. Dos specs sobre la
   misma escena se ordenan, no se paralelizan.
5. **¿El alcance entra en lo que el GDD llama una entrega?** El GDD vive en Notion y define
   qué significa «terminado» para el núcleo de jugabilidad y para la demo. Un spec que se sale
   de eso no está mal — pero tiene que decir que se sale.
6. **¿Cada identificador que el spec escribe en `código` existe de verdad?** Un `class_name`,
   una constante o un método citado de otro spec y nunca grepeado contra el repo. La revisión
   lo cierra con un comando, no leyendo: `rg -n "NOMBRE" src/` — y si no devuelve nada, el spec
   nombra algo que no está. **En Godot este error no se cobra caro al implementar sino después:**
   un identificador inexistente en un `*_test.gd` hace que la suite **no parsee**, gdUnit4 la
   **descarta en silencio**, y el nodo `tests` sale **verde** sin haberla corrido. O sea que el
   spec induce un fallo que ningún nodo del harness nombra. Medido el 2026-09-01 en el spec 011,
   que decía `Ritmo.FACTOR` cuando la constante es `Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL`.
7. **¿Los cuatro archivos dicen el mismo número?** El `spec.md`, el `research.md`, el `plan.md`
   y el `tasks.md` se escriben en momentos distintos, y **el que se implementa es el `tasks.md`**:
   una contradicción entre ellos no la caza ningún gate y la gana la tarea. Es peor cuando el
   número **es lo que el spec existe para corregir**, porque entonces el spec escribe el mismo
   error que vino a cerrar, con la autoridad de venir a cerrarlo. Medido el 2026-09-01 en el
   spec 022 —«los docs dicen la regla del despido vigente»—: su `spec.md` decía «dos jornadas
   graves», su `plan.md` y su T001 decían «tres», y el valor real sale de
   `src/dominio/reglas.gd`. **Se cierra contra la fuente de verdad, no por mayoría entre los
   cuatro archivos.**
8. **Si el spec propone un gate, ¿camina el tipo de archivo de lo que dice verificar?** Un gate
   que declara cubrir las cuatro capas y sólo lee `.gd` deja `escenas/` sin verificar, porque
   esa capa es casi toda `.tscn` — y el spec **no miente**: el gate corre, sale verde y nadie
   ve el hueco. La revisión lo cierra con dos comandos, no leyendo: qué extensiones tiene la
   capa (`find src/<capa> -type f | sed 's/.*\.//' | sort -u`) contra qué extensiones camina el
   helper que el spec nombra. Y el AC de la sonda tiene que traer **una sonda por extensión**:
   con una sola, el hueco pasa en verde. Medido el 2026-09-01 revisando el PR del spec 024, que
   estrenaba `src/escenas/puestos/` con un `.tscn` que su propio gate no podía ver.

## Las convenciones que un spec suele violar por escrito

Están en `CLAUDE.md`, en `docs/guides/conventions.md` y en `.claude/rules/`, y casi todas las
verifica una herramienta:

- **`dominio/` es puro**: nada de `Node`, `get_tree()`, `_process` ni `await` de un timer. Un
  spec que propone un `Node` en `dominio/` propone algo que el gate va a frenar.
- **Tipado estático** en toda firma, `-> void` incluido.
- **La dirección de dependencia entre capas**, incluida la que se cruza nombrando un
  `class_name`.
- **Español** en comentarios, commits y specs.
- **Un valor fijo que dos archivos necesitan igual va a un solo lugar**, y el spec tiene que
  decir a cuál.
- **`print` no sobrevive al commit.**

## Al cerrar — las ediciones se devuelven al issue

```bash
python .claude/scripts/publicar_spec.py publicar
```

**No es opcional y no lo hace nadie más.** El árbol de `specs/` es **caché**: un review que editó
el `spec.md` en disco y no publicó dejó el trabajo en un archivo que git ignora, y la próxima
hidratación **lo sobreescribe sin avisar**. No falla, no aparece en ningún `git status`, y el spec
vuelve a decir lo que decía. Es la forma más cara de perder una corrida entera.

**El `estado` del mapa no se toca acá** —lo deriva la Action en el push a `staging`—, y
`test_convencion_de_specs.py` corre sobre lo hidratado, así que verificá con
`python .claude/scripts/verificar.py --solo harness` antes de publicar.

**Y si el hallazgo era de planteo, corregí también el skill que lo dejó pasar.** Un AC
infalsificable o una tarea sin archivo que llegaron hasta el review son una regla que
`spec-create` no atajó: agregala allá y decilo en el reporte. Ver «el lazo» en
[`sin-deuda.md`](sin-deuda.md).

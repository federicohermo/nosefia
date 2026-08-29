---
name: spec-review
description: Especialización de /spec-review para No se fía (Godot). Dónde vive el registro en este repo, el contrato de tasks.md, y las convenciones que un spec suele violar por escrito. Se lee junto con el skill global.
---

# spec-review — No se fía

Este archivo **no reemplaza** al skill global: aporta lo que en este repo es distinto. Los
ejes, los gates y el formato del reporte salen de allá.

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
- **Ninguna tarea se cierra mirando o escuchando.** Una tarea que dice *a ojo*, *de oído*,
  *captura* o *mirar la pantalla* es un hallazgo, y el arreglo es volverla verificable —un test
  de gdUnit4, un número medido, un valor que un gate lea— o sacarla. Marcarla no es una salida.
  Lo verifica `test_convencion_de_specs.py`, pero sólo sobre los specs hidratados: si el review
  corre sobre un árbol vacío, el gate se saltea **declarándolo** y el que mira sos vos.
- **`[P]` no miente.** Dos tareas `[P]` del mismo bloque no pueden tocar el mismo archivo. Es
  el hallazgo más caro de los tres, porque `spec-implement` las abanica en paralelo y el
  conflicto aparece recién al escribir.
- **Ningún `## Seguimiento`.** La deuda que aparece implementando se abre como issue: adentro
  del spec hereda su estado, y un spec `Implementado` con diez casillas abiertas no le debe
  nada a nadie.

## Lo que hay que mirar en un spec de este juego

Cinco preguntas que en un repo de Godot deciden si el spec es implementable:

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

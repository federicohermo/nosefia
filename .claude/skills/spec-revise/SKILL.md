---
name: spec-revise
description: Contrasta un requisito NUEVO —venga de donde venga— contra los specs vivos de este repo y deja los specs al día, moviendo a Superado los que el requisito reemplaza. Usar cuando una definición del juego cambió y hay specs escritos que la daban por otra cosa. Para dos o más specs de una, spec-revise-batch.
---

# spec-revise — No se fía

**La entrada no es un spec: es un requisito nuevo.** Este skill no audita un texto para ver si
está bien escrito — contrasta lo que el juego pide **hoy** contra lo que los specs vivos dicen
que iban a hacer, y deja los specs diciendo lo de hoy.

Es lo que reemplaza a `spec-review`, y el motivo es medido: un review que audita un spec sin un
requisito nuevo adelante no puede saber qué mitad del texto va a envejecer. Lo que sí envejece
está declarado — **3 de 28 specs existían sólo para propagar a los docs una definición ya
decidida en otro lado**, o sea el 11 % del corpus gastado en llevar noticias. Este skill es esa
propagación, sin el spec de por medio.

## La fuente del requisito es indistinta

**Esto es lo único que no se puede leer mal.** El disparador es que **un requisito cambió**, y de
dónde viene no cambia nada de lo que hay que hacer:

| De dónde llega | Ejemplo | ¿Cambia el método? |
|---|---|---|
| una página de Notion | el GDD, que es documento vivo y manda | **no** |
| un documento de Drive | una tabla de balance, una minuta | **no** |
| el usuario, en el momento | «los apercibimientos ahora se reinician a los tres días» | **no** |
| un issue, un mensaje, una charla | lo que sea | **no** |

Este skill **no está atado a ninguna herramienta**. Si el requisito llegó como texto en la
conversación, ése es el insumo y alcanza; no hay que ir a buscarlo a ningún lado ni pedir un
enlace para empezar. **Lo único que hace falta es poder escribirlo en una línea**: qué pide ahora,
y qué pedía antes.

Si eso no se puede escribir, todavía no hay un requisito — hay una idea, y este skill no es el
lugar. Preguntá cuál de las dos es, que es una pregunta que ninguna medición contesta y por eso es
legítima (descarga 4 de [`sin-deuda.md`](sin-deuda.md)).

## Los cuatro pasos

### 1. Escribir el requisito en una línea, con su antes y su después

Antes de abrir un solo spec. El formato es una tabla de dos columnas y no un párrafo, porque el
paso 2 se hace **grepeando el después contra el antes**, y un párrafo no se grepea.

Si el requisito toca un valor —un número de tareas, una banda de consecuencia, un tiempo—,
**el «antes» sale del código y no de la memoria**: `rg -n "<lo que sea>" src/dominio/`. La fuente
de verdad de una regla del juego es `src/dominio/`, y un spec que diga otra cosa es justamente el
hallazgo que este skill viene a buscar.

### 2. Traer los specs vivos y buscar quién habla del tema

```bash
python .claude/scripts/hidratar_specs.py            # los que están EN VUELO
rg --no-ignore -n "<el término>" specs/
```

**`Grep` no ve `specs/`**: es ripgrep y respeta el `.gitignore`, así que contesta cero sin decir
que no miró. Y **un `rg` por línea, separados por `;`** — encadenarlos con `&&` corta en el
primero sin match y los demás no corren, también sin decirlo.

**Sólo los que están en vuelo.** `Implementado`, `Descartado` y `Superado` son terminales: son
historia, y la Desviación 2 de [`specs/README.md`](../../../specs/README.md) dice que un spec
mergeado no se reescribe. Que un spec viejo contradiga al requisito de hoy **no es un hallazgo**
— es lo que se espera de un plan con fecha.

Lo que sí hay que mirar afuera de `specs/`: si el requisito falsifica algo que la documentación
afirma **en presente**, eso se corrige — `docs/`, `.claude/rules/` y `CLAUDE.md`.

### 3. Decidir, spec por spec, cuál de las tres

Cada spec vivo que habla del tema cae en una y sólo una:

| El requisito nuevo… | Qué se hace | Quién lo cierra |
|---|---|---|
| **ajusta** lo que el spec dice | se edita el spec y se publica | queda `Propuesto` |
| **reemplaza** al spec entero | se escribe el spec que lo sustituye y el viejo pasa a `Superado` | una decisión, escrita |
| **no lo toca** | nada, y se dice que se miró | — |

**La tercera fila es un entregable, no un descarte.** Un spec revisado y sin cambios se lee igual
que uno no revisado, y ésa es la diferencia entre «no hay contradicciones» y «no busqué».

**`Superado` no lo deriva ninguna Action.** `estado` lo escribe
[`.github/workflows/mapa.yml`](../../../.github/workflows/mapa.yml) a partir de si el PR
aterrizó, y un spec al que otro reemplaza **no tiene PR**: nadie lo va a mover solo. Es una
decisión humana sobre el destino del spec, y por eso se escribe a mano en `specs/mapa.json`,
en su propio commit a `staging`, con el spec que lo supera nombrado en el comentario del issue.

### 4. Devolver todo al issue

```bash
python .claude/scripts/publicar_spec.py publicar
```

**No es opcional y no lo hace nadie más.** El árbol de `specs/` es **caché**: una revisión que
editó el `spec.md` en disco y no publicó dejó el trabajo en un archivo que git ignora, y la
próxima hidratación **lo sobreescribe sin avisar**. No falla, no aparece en ningún `git status`,
y el spec vuelve a decir lo que decía.

Y verificá antes de publicar, que el gate corre sobre lo hidratado:

```bash
python .claude/scripts/verificar.py --solo harness
```

## Qué mirar en el spec que estás editando

El requisito nuevo entra a un spec que ya existe, así que hay que dejarlo bien, no sólo
actualizado. Lo que en un repo de Godot decide si el spec es implementable:

1. **¿En qué capa cae la regla que el requisito cambió?** Si es una regla del juego —cuántas
   tareas, qué pasa a los dos días, qué cuenta como cumplir— y el spec la ubica en un `Node` de
   `sistemas/` o en una escena, **nace sin test**: `gate_de_tests.py` no mira `ui/` ni `escenas/`.
   La corrección es bajarla a `dominio/`, y el spec tiene que decirlo.
2. **¿El criterio se puede ver fallar?** «El HUD muestra el tiempo» no; «con 3 minutos restantes,
   `tiempo_restante()` devuelve 180.0» sí. Un criterio que no se puede ver fallar no verifica
   nada, y del 030 en adelante encima **tiene que estar nombrado por un test**: uno infalsificable
   deja al gate exigiendo un test que no puede existir.
3. **¿Cada identificador que el spec escribe en `código` existe?** `rg -n "NOMBRE" src/`, no
   leyendo. **En Godot este error no se cobra al implementar sino después:** un identificador
   inexistente en un `*_test.gd` hace que la suite **no parsee**, gdUnit4 la descarta **en
   silencio**, y el nodo `tests` sale **verde** sin haberla corrido. Medido el 2026-09-01 en el
   spec 011, que decía `Ritmo.FACTOR` cuando la constante es
   `Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL`.
4. **¿Los archivos del spec dicen el mismo número?** El `spec.md`, el `research.md` y el
   `estrategia.md` se escriben en momentos distintos, y una contradicción entre ellos no la caza
   ningún gate. **Se cierra contra la fuente de verdad —`src/dominio/`—, no por mayoría entre los
   archivos.** Medido el 2026-09-01 en el spec 022: su `spec.md` decía «dos jornadas graves», su
   `plan.md` y su T001 decían «tres».
5. **¿El spec toca una escena que otro spec vivo también toca?** Un `.tscn` no se mergea: un merge
   de tres vías sobre una escena produce una escena rota, no un conflicto. Dos specs sobre la
   misma escena se ordenan en el `estrategia.md`, no se paralelizan.
6. **¿El spec sigue entrando en los techos?** Un spec ≥ 030 tiene cuatro: 350 palabras de prosa en
   el `spec.md`, 300 en el bloque de criterios entero, 500 en el `research.md`, 250 en el
   `estrategia.md`. Agregar sin sacar es la forma en que el formato viejo vuelve, y acá el gate lo
   cobra.

## Las convenciones que un spec viola por escrito

Están en `CLAUDE.md`, en `docs/guides/conventions.md` y en `.claude/rules/`:

- **`dominio/` es puro**: nada de `Node`, `get_tree()`, `_process` ni `await` de un timer.
- **Tipado estático** en toda firma, `-> void` incluido.
- **La dirección de dependencia entre capas**, incluida la que se cruza nombrando un `class_name`.
- **Español** en comentarios, commits y specs.
- **Un valor fijo que dos archivos necesitan igual va a un solo lugar**, y el spec dice a cuál.

## Y acá se corrige, no se señala

Todo lo que este skill encuentra sale por una de las cinco descargas de
[`sin-deuda.md`](sin-deuda.md), y ninguna es «lo dejo anotado». Es el momento más barato del
flujo: **mientras el spec es texto, un hallazgo cuesta un párrafo**; el mismo hallazgo detectado
implementando cuesta un rebase.

**Y si el hallazgo era de planteo, corregí también el skill que lo dejó pasar.** Un criterio
infalsificable que llegó hasta acá es una regla que `spec-create` no atajó: agregala allá y decilo
en el reporte. Ver «el lazo» en [`sin-deuda.md`](sin-deuda.md).

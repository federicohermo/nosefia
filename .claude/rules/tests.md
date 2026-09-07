---
paths:
  - "test/**/*.gd"
---

# Tests con gdUnit4

`test/` es el **espejo** de `src/`: `src/dominio/jornada/turno.gd` se prueba en
`test/dominio/jornada/turno_test.gd`. El espejo no es orden: es lo que permite que un gate
conteste «esto no tiene test» sin que nadie mantenga una lista.

**El espejo conserva la subcarpeta**, y eso hay que decirlo porque es lo que duplica el trabajo
de mover un archivo: `ruta_de_test()` replica el anidamiento entero, así que mover un `.gd` sin
su test pone `gate_de_tests.py` en rojo. Los dos se mueven en el mismo commit — un rojo esperado
a mitad de camino no se distingue de uno real.

## La forma de una suite

```gdscript
extends GdUnitTestSuite

const Tarea := preload("res://src/dominio/jornada/tarea.gd")
const Turno := preload("res://src/dominio/jornada/turno.gd")


func test_completar_la_unica_obligatoria_la_cuenta_como_cumplida() -> void:
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	var turno := Turno.new(3600.0, [limpiar])
	turno.completar(limpiar)
	assert_int(turno.tareas_cumplidas()).is_equal(1)
```

- **`extends GdUnitTestSuite`** — es lo que hace que el archivo se descubra como suite.
- **El archivo termina en `_test.gd`** — lo verifica `gate_de_tests.py`, porque un test con el
  nombre equivocado **no corre y no se queja**: la suite pasa, el archivo está a la vista, y da
  la impresión contraria.
- **Cada `func test_…` afirma algo.** También lo verifica el gate: un test sin aserción cuesta
  lo mismo que uno de verdad y no puede fallar nunca.

## Las cuatro cosas que el gate rechaza

Están en `.claude/scripts/lib/tdd.py`, con el modo de falla que cierra cada una. En corto: sin
test espejo, sin aserción, apagado (`skip(true)`, `assert_not_yet_implemented`), o con un
nombre que hace que no corra. **Las cuatro son la misma cosa: verde sin ejercer nada.**

## El test se escribe primero, y en rojo

No es ceremonia: un test escrito después del código se escribe **mirando el código**, y
entonces prueba lo que el código hace en vez de lo que tenía que hacer. La secuencia es:

1. El test, contra la firma que todavía no existe. Se corre y **falla** — y falla por lo que
   se espera, no por un `nonexistent function`, que es un rojo que no verifica nada.
2. Lo mínimo para que pase.
3. Limpiar, con el test en verde de testigo.

## Nombres que dicen qué se rompe

`test_cerrar_con_menos_de_tres_tareas_avisa_al_jefe`, no `test_consecuencias_2`. El nombre del
test es lo único que se lee cuando la CI está en rojo: si no dice qué se rompió, hay que abrir
el archivo para saber si importa.

## Nada de nodos colgados

Lo que se instancia se libera. gdUnit4 lo reporta como *orphan nodes* y ensucia las corridas
siguientes:

```gdscript
var reloj := auto_free(Reloj.new())   # se libera al terminar el test
```

## Las tres formas en que un verde de gdUnit4 miente

Es lo más caro de este repo y no lo ve ningún gate: **el nodo `tests` sale `ok` sin haber
corrido lo que creías.** `verificar.py` hace lo correcto —el veredicto es el código de salida—
y aun así declara verde, porque gdUnit4 devuelve 0.

**El número que vale es el `Executed test suites: (N/N)` de la salida cruda**, contra la
cantidad de `*_test.gd`. No el color del nodo.

```bash
"$GODOT_BIN" --path . --headless -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --continue --ignoreHeadlessMode \
  -rd reportes 2>&1 | grep "Executed test suites"
```

**1 — La suite que no parsea se descarta en silencio.** Una que hace `preload` de un archivo que
todavía no existe —el estado normal del paso 1 del TDD— no corre, y el exit code es 0 igual. Un
error de parseo en `dominio/` puede dejar el dominio entero sin correr **con la CI en verde**, y
las cuatro reglas de arriba no lo ven: el espejo existe, afirma y no está apagado. Medido tres
veces en el lote 001/002/004/007.

**2 — Un `class_name` recién escrito no existe hasta el `--import` siguiente.** No está en
`global_script_class_cache.cfg`, y el síntoma es **idéntico** al del archivo ausente:
`Parse Error: Identifier "X" not declared`, `No test cases found`, `Exit code: 0`. Se lee como
«todavía no lo escribí» cuando ya está en disco. Re-importá **después de crear cada archivo con
`class_name` nuevo**, no una sola vez al abrir el worktree:

```bash
"$GODOT_BIN" --headless --path . --import --quit
```

Lo pisaron los dos carriles del lote 005/011/022/023 que crearon clases, cada uno perdiendo una
vuelta. Medido el 2026-09-01 implementando el 011.

**3 — Y la peor: el paso 1 sale `PASSED`.** Cuando el recurso que el caso carga no existe, el
error de script **aborta la función** y gdUnit4 no cuenta ninguna aserción fallida: el caso se
reporta en verde por no haber llegado a afirmar nada. Medido el 2026-09-01 en el 023, con la
escena sin escribir: **4 de 5 casos dieron `PASSED`**, y sólo dio rojo el que afirmaba el tipo.

O sea que el «falla por lo que se espera» del paso 1 **no se lee en el conteo de fallos**: se lee
en el `ERROR: Failed loading resource` de la salida cruda.

## Correrlos

```bash
python .claude/scripts/verificar.py --solo tests   # la suite entera, headless
python .claude/scripts/verificar.py                # y todo lo demás
```

Hace falta `GODOT_BIN` apuntando al ejecutable de Godot. Mientras no exista un solo
`*_test.gd`, el nodo se saltea **diciéndolo**; en cuanto exista el primero, Godot pasa a ser
obligatorio y su falta es un rojo.

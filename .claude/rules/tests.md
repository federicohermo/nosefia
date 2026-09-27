---
paths:
  - "test/**/*.gd"
---

# Tests con gdUnit4

`test/` es el **espejo** de `src/`: `src/dominio/jornada/turno.gd` se prueba en
`test/dominio/jornada/turno_test.gd`. El espejo es lo que permite que un gate conteste «esto no
tiene test» sin que nadie mantenga una lista.

**El espejo conserva la subcarpeta**, y eso duplica el trabajo de mover un archivo: mover un
`.gd` sin su test pone `gate_de_tests.py` en rojo. Los dos se mueven en el mismo commit — un rojo
esperado a mitad de camino no se distingue de uno real.

## La forma de una suite

```gdscript
extends GdUnitTestSuite

const Tarea := preload("res://src/dominio/jornada/tarea.gd")
const Turno := preload("res://src/dominio/jornada/turno.gd")


func test_con_un_segundo_restante_la_obligatoria_cuenta() -> void:  # AC-SHF-007
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	var turno := Turno.new(1.0, [limpiar])
	turno.completar(limpiar)
	assert_int(turno.tareas_cumplidas()).is_equal(1)
```

- **`extends GdUnitTestSuite`** hace que el archivo se descubra como suite.
- **El archivo termina en `_test.gd`**, y **cada `func test_…` afirma algo.**
- **El criterio que verifica va citado al final de la línea**, como `AC-<COD>-###`. Lo cobra
  `gate_de_specs.py` sobre los specs `ratified`.

## Lo que el gate rechaza

Sin test espejo, sin aserción, apagado, o con un nombre que hace que no corra. **Es la misma
cosa: verde sin ejercer nada.** Cada regla, con su modo de falla, está en
`.claude/scripts/lib/tdd.py`.

En gdUnit4 un test se apaga con el parámetro `do_skip` de la función de test. Saltear un test se
decide borrándolo o arreglándolo.

## El test se escribe primero, y en rojo

Un test escrito después se escribe **mirando el código**, y entonces prueba lo que el código
hace en vez de lo que tenía que hacer. El ciclo y lo que reemplaza a la cobertura, en
[TDD sin cobertura](../../docs/guides/tdd.md).

## Nombres que dicen qué se rompe

`test_cerrar_con_menos_de_tres_tareas_avisa_al_jefe`, no `test_consecuencias_2`. El nombre es lo
único que se lee cuando la CI está en rojo.

## Nada de nodos colgados

Lo que se instancia se libera. gdUnit4 lo reporta como *orphan nodes* y ensucia las corridas
siguientes:

```gdscript
var reloj := auto_free(Reloj.new())   # se libera al terminar el test
```

## Las tres formas en que un verde de gdUnit4 miente

Es lo más caro de este repo y no lo ve ningún gate: **el nodo `tests` sale `ok` sin haber corrido
lo que creías.** `verificar.py` hace lo correcto —el veredicto es el código de salida— y aun así
declara verde, porque gdUnit4 devuelve 0.

**El número que vale es el `Executed test suites: (N/N)` de la salida cruda**, contra la cantidad
de `*_test.gd`. No el color del nodo.

```bash
"$GODOT_BIN" --path . --headless -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --continue --ignoreHeadlessMode \
  -rd reports 2>&1 | grep "Executed test suites"
```

**1 — La suite que no parsea se descarta en silencio.** Una que hace `preload` de un archivo que
todavía no existe —el estado normal del paso 1 del TDD— no corre, y el exit code es 0 igual. Un
error de parseo puede dejar el dominio entero sin correr **con la CI en verde**, y el gate de
tests no lo ve: el espejo existe, afirma y no está apagado.

**2 — Un `class_name` recién escrito no existe hasta el `--import` siguiente.** El síntoma es
**idéntico** al del archivo ausente: `Parse Error: Identifier "X" not declared`,
`No test cases found`, `Exit code: 0`. Se lee como «todavía no lo escribí» cuando ya está en
disco. Re-importá **después de crear cada archivo con `class_name` nuevo**, no una vez por
worktree:

```bash
"$GODOT_BIN" --headless --path . --import --quit
```

**3 — Y la peor: el paso 1 sale `PASSED`.** Cuando el recurso que el caso carga no existe, el
error de script **aborta la función** y gdUnit4 no cuenta ninguna aserción fallida. El caso sale
`PASSED` por no haber llegado a afirmar nada.

O sea que el «falla por lo que se espera» del paso 1 **no se lee en el conteo de fallos**: se lee
en el `ERROR: Failed loading resource` de la salida cruda.

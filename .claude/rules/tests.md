---
paths:
  - "test/**/*.gd"
---

# Tests con gdUnit4

`test/` es el **espejo** de `src/`: `src/dominio/turno.gd` se prueba en
`test/dominio/turno_test.gd`. El espejo no es orden: es lo que permite que un gate conteste
«esto no tiene test» sin que nadie mantenga una lista.

## La forma de una suite

```gdscript
extends GdUnitTestSuite

const Tarea := preload("res://src/dominio/tarea.gd")
const Turno := preload("res://src/dominio/turno.gd")


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

## Correrlos

```bash
python .claude/scripts/verificar.py --solo tests   # la suite entera, headless
python .claude/scripts/verificar.py                # y todo lo demás
```

Hace falta `GODOT_BIN` apuntando al ejecutable de Godot. Mientras no exista un solo
`*_test.gd`, el nodo se saltea **diciéndolo**; en cuanto exista el primero, Godot pasa a ser
obligatorio y su falta es un rojo.

# Instrucciones del directorio

Copia íntegra de `.claude/rules/tests.md`.
Aplicar al alcance `paths` indicado, relativo a la raíz del repo.
Los enlaces relativos del texto copiado se resuelven desde el archivo original.

---
paths:
  - "test/**/*.gd"
---

# Tests con gdUnit4

## Qué merece una prueba

Probar funcionalidades, flujos completos y rendimiento medible. Una prueba debe detectar una
falla que afecte al jugador o al funcionamiento del proyecto. Las decisiones visuales se revisan
jugando: no fijar coordenadas de manchas, distancias decorativas, tamaños de alfombras ni valores
de materiales. Reubicar un elemento por diseño no debe obligar a cambiar una prueba.

Comprobar colisiones o alcance cuando afectan una función. Por ejemplo: limpiar una mancha,
abrir una puerta o recoger un producto sin atravesar sólidos. Derivar sus
puntos de prueba de la escena cuando sea posible; no convertir su ubicación actual en contrato.
No ajustar reglas de jugabilidad para satisfacer una aproximación geométrica de un test.

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
- **Una suite tiene hasta 20 métodos públicos**, y `.gdlintrc` pone `max-public-methods: 20`.
  Cuentan sus `test_`, y también `before`, `after`, `before_test`, `after_test` y cualquier
  función que no empiece con `_`. La que se pasa sale roja en el nodo `lint`, no en `tests`, y se
  parte por lo que prueba. Se cuenta con `rg -c '^func [a-z]'`, no con los `test_`. Le costó una
  vuelta al carril de #262, y en el #277 `repositor_test.gd` tenía 19 casos y 20 métodos.

- **Un caso de escena afirma su premisa, además de su resultado**: dónde pegó el rayo que lo
  ubica, hacia qué mira. Cuando el local cambia, la premisa sale roja en vez de pasar por suerte.
  En el #262, `producto_soltado_test.gd` soltaba desde la tapa de una góndola del depósito. Y
  los casos de `contorno_de_los_muebles_test.gd` caían al pasillo al angostarse la góndola. Los
  dos seguían verdes sin probar nada.

## Lo que el gate rechaza

Sin test espejo, sin aserción, apagado, o con un nombre que hace que no corra. **Es la misma
cosa: verde sin ejercer nada.** Cada regla, con su modo de falla, está en
`.claude/scripts/lib/tdd.py`.

En gdUnit4, el parámetro `do_skip` apaga un test en su función, y la suite entera en `before`.
Saltear un test se decide borrándolo o arreglándolo.

## El test se escribe primero, y en rojo

Un test escrito después se escribe **mirando el código**, y entonces prueba lo que el código
hace en vez de lo que tenía que hacer. El ciclo y lo que reemplaza a la cobertura, en
[TDD sin cobertura](../../docs/guides/tdd.md).

**gdUnit4 no corre un caso solo desde la línea de comandos.** `-a` toma una suite o una
carpeta, y la forma `suite:caso` la entiende sólo `-i`, que saltea. Para ver fallar un caso se
corre su suite entera. Le costó una vuelta al carril de #266.

## Nombres que dicen qué se rompe

`test_cerrar_con_menos_de_tres_tareas_avisa_al_jefe`, no `test_consecuencias_2`. El nombre es lo
único que se lee cuando la CI está en rojo.

## Nada de nodos colgados

Lo que se instancia se libera. gdUnit4 lo reporta como *orphan nodes* y ensucia las corridas
siguientes:

```gdscript
var reloj := auto_free(Reloj.new())   # se libera al terminar el test
```

## Cómo sale rojo gdUnit4, y qué se lee en la salida cruda

**Desde gdUnit4 6.2.1, lo que no llega a afirmar sale rojo.** Medido el 2026-09-30, con una suite
de sonda por caso:

| Qué pasa | Qué hace el runner |
|---|---|
| una suite hace `preload` de un archivo que no existe | corta la corrida entera antes de correr nada, y sale con 105 |
| un `class_name` recién escrito, sin el `--import` siguiente | lo mismo: `Identifier "X" not declared`, y 105 |
| un caso aborta por un error de script antes de afirmar | el caso sale `FAILED` con el error contado, y el runner sale con 100 |

El corte de los dos primeros lo anuncia «Script errors were detected during test discovery!».
`verificar.py` toma el veredicto del código de salida, así que el nodo `tests` sale rojo en los
tres. Con la versión de antes, medida el 2026-09-01, salían con 0. Un error de parseo dejaba el
dominio entero sin correr con la CI en verde.

**El conteo crudo sigue siendo el control, y no cuesta nada**: el `Executed test suites: (N/N)`
de la salida cruda, contra la cantidad de `*_test.gd`. `verificar.py` no lo imprime.

**También se lee la salida cruda cuando el XML da cero errores.** Un callback de señal o el
desmontaje puede fallar fuera del contador del caso. El fixture usa el tipo de la señal y afirma
que su receptor se ejecutó. La ausencia de una reacción no prueba nada si la entrega abortó.
Los errores nuevos y las fugas se corrigen; se distinguen los diagnósticos esperados de
`assert_error` y del debugger remoto deliberadamente inaccesible.

```bash
"$GODOT_BIN" --path . --headless -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --continue --ignoreHeadlessMode \
  -rd res://reports 2>&1 | grep "Executed test suites"
```

**Re-importá después de crear cada archivo con `class_name` nuevo**, no una vez por worktree. Sin
eso la corrida entera sale con 105 aunque el archivo ya esté en disco, y se lee como «todavía no
lo escribí»:

```bash
"$GODOT_BIN" --headless --path . --import --quit
```

**El rojo del paso 1 se lee en la salida cruda.** Un 105 por el `preload` de lo que todavía no
existe prueba que el archivo falta, no el criterio. El criterio lo prueba el caso `FAILED` por su
aserción, o por el `ERROR: Failed loading resource` del recurso que carga.

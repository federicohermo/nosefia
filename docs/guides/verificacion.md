# Verificación

```bash
python .claude/scripts/verificar.py
```

Es **el nodo de convergencia**: lo único que hay que correr antes de un PR, y lo mismo que
corre la CI sobre cada PR y cada push a `staging` y `main`.

## Los seis nodos

| Nodo | Qué corre | Qué caza |
|---|---|---|
| `lint` | `gdlint src test` | nombres, orden de declaraciones dentro de una clase, líneas de más de 100 |
| `formato` | `gdformat --check src test` | todo lo que sea formato. Se arregla con `gdformat src test` |
| `capas` | `gate_de_capas.py` | una referencia que va en contra de la dirección de dependencia |
| `tdd` | `gate_de_tests.py` | un script sin test, un test sin aserción, uno apagado, o uno con un nombre que hace que no corra |
| `harness` | `unittest` sobre `.claude/scripts/tests/` | las herramientas del proceso, y el registro de specs contra GitHub |
| `tests` | gdUnit4 en Godot headless | el juego |

Corren **en paralelo**: son procesos independientes y ninguno depende de la salida de otro.

## Por qué la CI llama al script y no enumera los nodos

Porque enumerarlos en el workflow crearía un **segundo lugar** donde vive la lista, y el día
que alguien agregue un nodo acá, la CI seguiría corriendo la lista vieja — en verde. Es la
misma familia de bug que todo lo demás de este harness persigue: pasar sin haber mirado.

El workflow corre una línea: `python .claude/scripts/verificar.py`.

## Un nodo salteado no es un nodo verde

El reporte los distingue, y cada salteo dice **qué no miró y cómo hacer que mire**:

```
  salteado  tests       0.0s

── tests: salteado ──
no hay un solo `*_test.gd` todavía. En cuanto exista el primero, este nodo pasa a
necesitar Godot y deja de saltearse.
```

Es la regla más importante de todo el harness. Un gate que no puede correr y no lo dice se ve
**exactamente igual** que uno que pasó, y en esa diferencia se esconde el peor bug posible: el
que hace que todo esté verde mientras nada se verifica.

Hoy se saltean tres cosas, y cada una tiene su condición de vencimiento:

| Se saltea | Mientras | Vence cuando |
|---|---|---|
| `lint` y `formato` | no haya un solo `.gd` propio | se escriba el primero |
| `tests` | no haya un solo `*_test.gd` | se escriba el primero — y ahí `GODOT_BIN` pasa a ser obligatorio |
| El gate del mapa contra GitHub | no haya `gh` con sesión, o el mapa esté vacío | se publique el primer spec |
| El gate de convención de specs | no haya specs hidratados en disco | `hidratar_specs.py --todos` |

## El veredicto sale del código de salida

Nunca de un grep de la salida. Un `| grep` que no matchea devuelve 1 y se traga la salida
entera: es la forma más corta conocida de declarar verde una corrida rota.

Vale también para gdUnit4: el nodo `tests` mira el exit code del proceso de Godot, no el texto
del reporte.

## Sobre el nodo `tests`

Corre así, y cada flag está por algo:

```text
$GODOT_BIN --path <repo> --headless -s -d
    --remote-debug tcp://127.0.0.1:0
    res://addons/gdUnit4/bin/GdUnitCmdTool.gd
    -a test --continue --ignoreHeadlessMode -rd reportes
```

- **`--remote-debug tcp://127.0.0.1:0`** — sin esto, un error de parseo en cualquier `.gd` abre
  el depurador interactivo de Godot y el proceso **queda colgado para siempre** en un prompt
  `debug>` que nadie va a contestar. El puerto 0 no se liga nunca, así que la conexión siempre
  se rechaza, que es justo lo que se quiere.
- **`--continue`** — por defecto gdUnit4 corta en el primer fallo. Acá se corre todo: saber que
  fallan siete cosas y cuáles vale más que saber cuál fue la primera.
- **`--ignoreHeadlessMode`** — gdUnit4 se niega a correr headless salvo que se lo declare, y
  correr headless es todo el punto: es lo que hace que la CI y tu máquina hagan lo mismo.
- **`-rd reportes`** — los reportes van a un directorio ignorado por git.

## Lo que esta verificación NO cubre

Dicho para que no se lea como cobertura total:

- **No hay cobertura de código.** Godot no instrumenta GDScript. Qué la reemplaza y qué se
  pierde con el cambio está en [TDD sin cobertura](./tdd.md).
- **No verifica escenas.** Un `.tscn` con un nodo mal conectado pasa los seis nodos. Eso se ve
  abriendo el juego.
- **No verifica que el juego sea divertido**, ni que una tarea del turno se sienta bien. Eso es
  playtesting, y es de las pocas cosas de este repo que no tiene ningún gate — a propósito.

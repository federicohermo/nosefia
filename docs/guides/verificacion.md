# Verificación

```bash
python .claude/scripts/verificar.py
```

Es **el nodo de convergencia**: lo único que hay que correr antes de un PR, y lo mismo que
corre la CI.

## Los nodos

Los declara `NODOS`, en `verificar.py`. Cada `nodo_*` de ese archivo dice qué corre, y cada gate
dice en su encabezado qué caza. Corren **en paralelo**: son procesos independientes y ninguno
depende de la salida de otro.

La CI llama al script y no enumera los nodos. Una segunda lista en el workflow seguiría
corriendo la vieja el día que se agregue un nodo, y en verde.

En GitHub Actions, las suites de Godot se reparten entre cuatro runners independientes:

```bash
python .claude/scripts/verificar.py --particion-tests 0/4
```

El índice empieza en cero. La última partición corre también los demás nodos; las otras sólo
corren sus suites. En el reparto actual es más liviana y deja CPU libre en la partición más larga.
La asignación prioriza las suites más lentas y las agrega al runner con menor carga estimada.
Usa las duraciones medidas de veinte suites y reserva margen para los demás nodos en la última partición.
Las suites nuevas reciben un costo estimado por defecto. Los tiempos orientan el reparto;
el inventario sigue saliendo de todos los archivos `_test.gd` actuales.
El orden es determinista y conserva la selección en Windows y Linux.
Cada runner importa sus recursos y tiene sus propios datos de usuario y reportes. El check
obligatorio `verify` sólo pasa cuando pasan las cuatro particiones.

Sin `--particion-tests`, el comando conserva la ejecución completa en un solo checkout.

## Un nodo salteado no es un nodo verde

El principio está en la [constitución](../architecture/constitution.md). El reporte distingue
`salteado` de `ok`, y cada salteo dice **qué no miró y cómo hacer que mire**. Las condiciones
de cada salteo son las llamadas a `_saltear` de `verificar.py`.

**El ancla AC↔test no se saltea: cambia de fuerza con el estado del spec.** Sobre un `ratified`,
un criterio sin test es rojo. Sobre un `draft`, el gate cuenta cuántos faltan y lo imprime.
Cobrarle a todo spec escrito haría que nadie escriba el contrato de una capacidad nueva.

## Sobre el nodo `tests`

El veredicto es el código de salida del proceso de Godot, no el texto del reporte. Cada flag de
la invocación lleva su porqué en un comentario de `nodo_tests`. Los reportes van a `reports/`,
que está en `.gitignore`.

Desde gdUnit4 6.2.1, una suite que no parsea corta la corrida con 105 y el nodo sale rojo. El
conteo crudo sigue siendo el control de que corrió todo. Cómo leerlo, en
[la regla de tests](../../.claude/rules/tests.md).

Cada partición coteja sus suites con el XML JUnit recién generado.
El nodo falla si falta una suite, se repite, sobra alguna o no tiene casos,
aunque Godot termine con cero.
Los artefactos `reports-gdunit4-<índice>` incluyen la selección esperada, el resultado del cotejo,
la salida de gdUnit4 y sus reportes. No se aceptan XML de una ejecución anterior.

## Lo que esta verificación NO cubre

- **No hay cobertura de código.** Godot no instrumenta GDScript. Qué la reemplaza y qué se
  pierde, en [TDD sin cobertura](./tdd.md).
- **No verifica que un test ejerza el criterio que cita.** El nodo `specs` verifica la **cita**.
  Un `# AC-EMP-004` en un test que no afirma nada pasa igual.
- **Verifica poco de las escenas.** De un `.tscn` mira lo que cobran `lib/escenas.py` y los
  tests de `test/escenas/`. El resto se ve abriendo el juego.
- **No verifica que el juego sea divertido**, ni que una tarea del turno se sienta bien. Eso es
  playtesting, y no tiene gate a propósito.

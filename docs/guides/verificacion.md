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

Un verde de gdUnit4 puede ser una suite que no corrió. Cómo leer el conteo crudo, en
[la regla de tests](../../.claude/rules/tests.md).

## Lo que esta verificación NO cubre

- **No hay cobertura de código.** Godot no instrumenta GDScript. Qué la reemplaza y qué se
  pierde, en [TDD sin cobertura](./tdd.md).
- **No verifica que un test ejerza el criterio que cita.** El nodo `specs` verifica la **cita**.
  Un `# AC-EMP-004` en un test que no afirma nada pasa igual.
- **Verifica poco de las escenas.** De un `.tscn` mira lo que cobran `lib/escenas.py` y los
  tests de `test/escenas/`. El resto se ve abriendo el juego.
- **No verifica que el juego sea divertido**, ni que una tarea del turno se sienta bien. Eso es
  playtesting, y no tiene gate a propósito.

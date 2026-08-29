# Visión general

`src/` son cuatro capas en carpetas, con **una sola dirección de dependencia**:

```text
dominio/  ←  sistemas/  ←  ui/  ←  escenas/
   ▲            ▲          ▲
   │            │          └── ui/ conoce dominio/ y sistemas/
   │            └── sistemas/ conoce dominio/
   └── dominio/ no conoce a nadie
```

Lo verifica `python .claude/scripts/gate_de_capas.py`, y corre dentro de `verificar.py`.

## Las cuatro capas

### `src/dominio/` — las reglas, sin el motor

GDScript puro: `RefCounted` y `Resource`, nada que extienda `Node`. El turno, las cinco tareas
diarias, el inventario, la ventanilla **como regla** —cuántos compradores entran, qué pasa si
no se los atiende—, los canales de investigación y el sistema de consecuencias con sus tres
puntos de corte.

**La prueba de que algo pertenece acá es una sola: se puede ejercer sin levantar una escena.**

### `src/sistemas/` — el motor hablando con el dominio

Los `Node` y autoloads que hacen correr al dominio: el reloj del turno, el guardado, el bus de
señales, la carga de escenas. **Traducen, no deciden.** Toman lo que el motor da —un `delta`,
un evento de entrada, un archivo— y lo convierten en una llamada al dominio; y publican como
señal lo que el dominio contesta.

### `src/ui/` — lo que se ve

HUD, la computadora con sus chats, inventarios y cámaras, la ventanilla. Presentación.

### `src/escenas/` — los scripts pegados a un `.tscn`

La cáscara. Cablean nodos y conectan señales; no deciden nada.

## Por qué esta separación y no otra

**Porque es la única que hace testeable a un juego de Godot.** El patrón por defecto del motor
—un `Node` por cosa, con la lógica adentro de `_process`— produce código que sólo se puede
ejercer jugando: para saber si «a los dos días seguidos sin cumplir lo echan», hay que jugar
dos días.

Con las reglas en `dominio/`, ese mismo hecho es tres líneas de test que corren en
milisegundos y sin abrir una ventana. De ahí sale todo lo demás: por eso
`gate_de_tests.py` exige test para `dominio/` y `sistemas/` y no para las otras dos, y por eso
`gate_de_capas.py` existe.

**La consecuencia práctica, y es la que hay que tener presente al escribir un spec: si una
regla del juego termina adentro de una escena o de un `Node` gordo, esa regla nace sin test y
nada lo va a decir.**

## Las dos formas de referenciar, y por qué el gate mira las dos

En Godot un script llega a otro de dos maneras:

1. **Por ruta** — `preload("res://src/ui/hud.gd")`, `load(…)`, `extends "res://…"`.
2. **Por `class_name`** — un script que declara `class_name Ventanilla` queda registrado
   **globalmente**, y desde cualquier otro archivo se lo nombra sin escribir una sola ruta.

La segunda es la forma **normal** de escribir GDScript, y es la que ningún análisis de imports
encuentra. Por eso el gate construye el índice `class_name → capa` y después busca esos
identificadores como palabras, sobre el código con los comentarios y los strings limpiados.

## Lo que el gate no puede ver

Se dice acá para que no se lea como cobertura total:

- **Los autoloads.** Son globales por construcción: viven en `project.godot` y cualquiera los
  ve, sin escribir una referencia. Es una decisión de arquitectura que se toma al agregarlos,
  y por eso cada uno se anota abajo.
- **Las escenas (`.tscn`).** Una escena referencia scripts, pero el caso peligroso —una escena
  en `dominio/`— no puede existir, porque `dominio/` no tiene escenas.

### Autoloads declarados

*(Ninguno todavía. Cuando se agregue el primero, va acá con para qué está.)*

La pregunta antes de agregar uno: ¿esto lo necesita **todo** el juego, o lo necesitan dos
escenas que podrían pasárselo? Si son dos, no es un autoload.

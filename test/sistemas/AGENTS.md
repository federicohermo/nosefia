# Instrucciones del directorio

Copia íntegra de `.claude/rules/sistemas.md`.
Aplicar al alcance `paths` indicado, relativo a la raíz del repo.
Los enlaces relativos del texto copiado se resuelven desde el archivo original.

---
paths:
  - "src/sistemas/**/*.gd"
  - "test/sistemas/**/*.gd"
---

# Capa de sistemas

Los `Node` que hacen correr al dominio adentro del motor: el reloj del turno, el guardado, el
agarre, el audio. Conocen `dominio/`; **no conocen la pantalla**.

## Qué es un sistema y qué no

Un sistema **traduce entre el motor y el dominio**. Toma lo que el motor le da —un `delta`, un
evento ya interpretado, un archivo—, lo convierte en una llamada al dominio, y publica como señal
lo que el dominio contesta.

Lo que **no** hace es decidir. Un `if` sobre las reglas del juego acá significa que la regla está
en el lugar equivocado.

```gdscript
# Bien: el sistema aporta el tiempo y publica el resultado; la regla la tiene el turno.
func _process(delta: float) -> void:
    _turno.consumir(delta)
    if _turno.cerrado():
        turno_cerrado.emit(_turno.tareas_cumplidas())

# Mal: la regla de las cinco tareas vive en un Node y ya no se puede probar sin la escena.
func _process(delta: float) -> void:
    if _tareas_hechas >= 5 and _minutos <= 0:
        ...
```

## También tiene test obligatorio

`gate_de_tests.py` los pide igual que en `dominio/`, y es una decisión: un sistema **fino** se
prueba sin escena, con `auto_free(Sistema.new())` y llamándole los métodos. Si uno no se puede
probar así, tiene adentro una regla o un pedazo de presentación — y el arreglo es sacarlos, no
eximirlo del test.

## Las subcarpetas: si consume tiempo del turno, y para qué

| Carpeta | Qué hace con el tiempo |
|---|---|
| `marco/` | **no lo consume**: hace correr el juego. Un bug acá no cambia el balance, lo detiene |
| `tareas/` | lo consume **y cumple una obligatoria** |
| `investigacion/` | lo consume **y no cumple nada**. Es el otro lado de la tensión central |

Es la distinción menos deducible de las cuatro capas: `limpiador.gd` y `examen.gd` son dos `Node`
que se parecen en todo salvo en lo único que importa —uno paga el minuto y el otro no—, y el
nombre del archivo no lo dice.

**`agarre.gd` va en `marco/` y no en `tareas/`, y el motivo vale como ejemplo:** agarrar es el
mecanismo, no la tarea. Quien paga el minuto es el `repositor` o el `recolector_de_basura` que lo
usa. Lo mismo el audio.

**Quién lo verifica: `gate_de_capas.py`**, con `CARPETAS_POR_CAPA`. Valida los **nombres** y no
que un archivo esté en la carpeta correcta: eso es semántica y lo mira la revisión. La raíz de la
capa se admite, para lo que cruza. El árbol lo imprime
`python .claude/scripts/estructura.py`.

## Autoloads: pocos, y declarados

Un autoload es una variable global con otro nombre: lo ve todo el proyecto, nadie declara que lo
usa, y `gate_de_capas.py` **no puede verlo**. Cada uno se decide al agregarlo y se anota en la
[regla de GDScript](./gdscript.md), con para qué está.

## Las señales van hacia arriba, las llamadas hacia abajo

Un sistema **llama** al dominio y **emite** hacia la UI. Nunca al revés: si un sistema necesita
preguntarle algo a la pantalla, la pantalla se lo tenía que haber pasado.

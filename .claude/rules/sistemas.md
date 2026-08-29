---
paths:
  - "src/sistemas/**/*.gd"
  - "test/sistemas/**/*.gd"
---

# Capa de sistemas

Los `Node` y autoloads que hacen correr al dominio adentro del motor: el reloj del turno, el
guardado, el bus de señales, la carga de escenas. Conocen `dominio/`; **no conocen la
pantalla**.

## Qué es un sistema y qué no

Un sistema **traduce entre el motor y el dominio**. Toma lo que el motor le da —un `delta`, un
evento de entrada ya interpretado, un archivo— y lo convierte en una llamada al dominio; y
toma lo que el dominio contesta y lo publica como señal.

Lo que **no** hace es decidir. Si un archivo de acá tiene un `if` sobre las reglas del juego,
esa regla está en el lugar equivocado: va a `dominio/`, donde se puede probar sin escena.

```gdscript
# Bien: el sistema aporta el tiempo y publica el resultado; la regla la tiene el turno.
func _process(delta: float) -> void:
    if _turno.consumir(delta):
        turno_cerrado.emit(_turno.consecuencia())

# Mal: la regla de las cinco tareas vive en un Node y ya no se puede probar sin la escena.
func _process(delta: float) -> void:
    if _tareas_hechas >= 5 and _minutos <= 0:
        ...
```

## También tiene test obligatorio

`gate_de_tests.py` los pide igual que en `dominio/`, y eso es una decisión: un sistema **fino**
se puede probar sin escena, instanciando el `Node` con `auto_free(Sistema.new())` y llamándole
los métodos. Si un sistema no se puede probar así, es porque tiene adentro una regla o un
pedazo de presentación — y el arreglo es sacarlos, no eximirlo del test.

## Autoloads: pocos, y declarados

Un autoload es una variable global con otro nombre: lo ve todo el proyecto y nadie declara que
lo usa, así que `gate_de_capas.py` **no puede verlo**. Por eso cada uno se decide al agregarlo
y no cuando hace falta rápido, y se anota en
[docs/architecture/overview.md](../../docs/architecture/overview.md) con para qué está.

La pregunta antes de agregar uno: ¿esto lo necesita **todo** el juego, o lo necesitan dos
escenas que podrían pasárselo? Si son dos, no es un autoload.

## Las señales van hacia arriba, las llamadas hacia abajo

Un sistema **llama** al dominio y **emite** hacia la UI. Nunca al revés: si un sistema
necesita preguntarle algo a la pantalla, la pantalla se lo tenía que haber pasado.

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
    _turno.consumir(delta)
    if _turno.cerrado():
        turno_cerrado.emit(_turno.tareas_cumplidas())

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

## Las subcarpetas: si consume tiempo del turno, y para qué

La carpeta **no repite el nombre del archivo**: dice **qué se rompe si tocás lo que hay
adentro**. Acá ese alcance se mide en **si consume tiempo del turno, y para qué**.

Esta capa tiene **un** archivo hoy y por eso parece no necesitar orden. Los specs propuestos le
traen **trece más**: es la que más se multiplica de las cuatro. Ordenarla cuando ya esté
desordenada cuesta un spec entero de renombres.

```text
src/sistemas/
├── marco/          reloj_del_turno · ciclo_de_jornadas · guardado · arranque_del_juego
│                   · agarre · enlace_de_audio · reproductor_de_sonidos
├── tareas/         repositor · limpiador · recolector_de_basura · ventanilla
└── investigacion/  computadora_de_escritorio · registro_de_investigacion · examen
```

| Carpeta | Qué hace con el tiempo |
|---|---|
| `marco/` | **no lo consume**: hace correr el juego. Un bug acá no cambia el balance, lo detiene |
| `tareas/` | lo consume **y cumple una obligatoria** |
| `investigacion/` | lo consume **y no cumple nada**. Es el otro lado de la tensión central |

Es la distinción menos deducible de las cuatro capas: `limpiador.gd` y `examen.gd` son dos
`Node` que se parecen en todo salvo en lo único que importa —uno paga el minuto y el otro no—,
y el nombre del archivo no lo dice.

**`agarre.gd` va en `marco/` y no en `tareas/`, y el motivo vale como ejemplo del criterio:**
agarrar es el mecanismo, no la tarea. Quien paga el minuto es el `repositor` o el
`recolector_de_basura` que lo usa. Lo mismo el audio: un bug ahí detiene el juego sin cambiar
el balance.

**Quién lo verifica: `gate_de_capas.py`**, con `CARPETAS_POR_CAPA` de `lib/repo.py`. Valida los
**nombres** de carpeta —que exista `marco/` y no `nucleo/`— y **no** valida que un archivo esté
en la carpeta correcta: eso es semántica, ninguna herramienta lo puede contestar, y lo mira la
revisión. La raíz de la capa la admite a propósito, para lo que cruza.

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

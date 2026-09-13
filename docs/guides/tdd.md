# TDD sin cobertura

## El problema, dicho de frente

El harness del que sale éste sostiene el TDD con un **gate de cobertura al 100 %** en las
cuatro métricas, sin una sola excepción: una función sin test no se mergea porque el número
baja y la CI se pone roja. Es un mecanismo que no depende de la buena voluntad de nadie.

**En GDScript ese número no existe.** Godot no instrumenta scripts, y ninguna de las dos
herramientas de test del ecosistema mide cobertura de ramas.

Así que hay dos salidas honestas: pedir TDD por escrito y confiar, o buscar las señales que sí
son medibles. Este repo toma la segunda, y hay que decir con todas las letras **qué se
pierde**: los gates de acá no saben si un test ejerce una rama. Saben si el archivo existe, si
el test afirma algo y si va a correr. **Es un piso, no el techo que da un 100 %.**

## Las cuatro reglas, y el modo de falla que cierra cada una

Las verifica `python .claude/scripts/gate_de_tests.py`, dentro de `verificar.py`.

### 1. Todo script de `dominio/` y `sistemas/` tiene su test espejo

`src/dominio/jornada/turno.gd` → `test/dominio/jornada/turno_test.gd`.

Es la que reemplaza al umbral. Sin ella, el código nuevo entra sin nada que lo ejerza y nadie
se entera hasta que rompe. Y el espejo es lo que permite contestarlo **sin que nadie mantenga
una lista**: la pregunta «¿esto tiene test?» se responde con una ruta.

**`ui/` y `escenas/` quedan afuera, y eso no es una amnistía.** Ahí el test necesita el
`scene_runner` y frames de verdad; exigirlo por gate empujaría a escribir tests de humo que
pasan sin ejercer nada — peor que no tenerlos, porque además mienten. La consecuencia es la
regla que sí importa: **si una regla del juego termina en esas dos capas, nace sin test.** El
arreglo no es testear la pantalla: es bajar la regla al dominio.

### 2. Ningún test sin una sola aserción

Un test que corre y no afirma nada es **verde permanente**: cuesta lo mismo que uno de verdad,
ocupa el mismo lugar en la suite, y no puede fallar nunca.

### 3. Ningún test apagado

`skip(true)` y `assert_not_yet_implemented()` son la misma familia: verde sin ejercer. Saltear
un test es una decisión que se toma **borrándolo o arreglándolo**, no dejándolo apagado adentro
del archivo, donde se lee como cobertura.

### 4. Ningún `func test_…` en un archivo que no sea `*_test.gd`

Un test con el nombre equivocado **no corre y no se queja**. La suite pasa, el archivo con los
tests está ahí a la vista, y da la impresión contraria.

## El ciclo, y por qué el orden importa

1. **El test primero**, contra la firma que todavía no existe. Se corre y **falla**.
2. Lo mínimo para que pase.
3. Limpiar, con el test en verde de testigo.

**Un test escrito después del código se escribe mirando el código**, y entonces prueba lo que
el código hace en vez de lo que tenía que hacer. Es la diferencia entre un test que caza un bug
y uno que lo documenta.

Y el paso 1 tiene una trampa: **el rojo tiene que ser el rojo que se espera**. Un
`nonexistent function 'consecuencia'` no verifica nada — verifica que el archivo no existe.
Si el test falla por eso, escribí la firma vacía primero y volvé a correr: el rojo útil es el
que dice «esperaba AVISO, recibí NINGUNA».

## Qué hace testeable a un juego

Es la parte que no es sobre herramientas.

**El tiempo entra como parámetro.** El dominio no lee el reloj del motor: se lo pasan.

```gdscript
# Bien: el test le pasa 400 segundos y ve qué decide.
func consumir(segundos: float) -> void:

# Mal: ahora el test necesita un frame, y esperar.
func consumir() -> void:
    var dt := get_process_delta_time()
```

**El azar entra como parámetro.** Lo mismo con `randi()`: un dominio que sortea adentro no se
puede probar, porque cada corrida da otra cosa. La semilla o el resultado del sorteo se
reciben.

**El estado se pregunta, no se mira.** Si para saber si el turno terminó hay que leer una
etiqueta del HUD, la regla está en el HUD. El dominio tiene que poder contestarlo.

Las tres son la misma idea: **lo que el dominio necesita del mundo, se lo dan**. Es lo que
convierte «jugar dos jornadas graves seguidas para ver si lo echan» en tres líneas que
corren en milisegundos.

## Lo que igual hay que probar a mano

Los gates no cubren si el juego se siente bien, si una tarea del turno es tediosa o si la
paranoia funciona. Eso es playtesting y no tiene gate, a propósito.

Lo que **no** vale es anotar eso como trabajo del spec: una tarea que se cierra mirando no la
cierra nadie —está medido: 137 casillas así en 35 specs, 6 cerradas alguna vez— y termina
siendo una lista de intenciones con formato de checklist. Si hay que playtestear
algo, va al Backlog de Notion, que es donde el equipo mira lo que no es código.

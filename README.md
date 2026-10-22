# Salida voluntaria del PR 601

Las tres grabaciones salen del juego nativo Godot 4.7.2 del proyecto, con el código de producción de `1987dd76`. Los commits posteriores sólo preparan el suavizado del mouse y corrigen la espera de una señal en los tests.

Cada toma usa el foco real de la entrada y envía al viewport una pulsación primaria con coordenadas en el centro de la ventana y su liberación. El registrador no llama a los métodos de salida ni adelanta la cámara o la puerta. Captura cuadros del viewport y el audio del bus Master. Los MP4 conservan los intervalos observados entre capturas. El GIF no lleva audio.

La preparación crea una partida de la jornada indicada, sin compradores, completa sus obligatorias y deja el reloj detenido antes de hacer clic. Es un atajo para llegar al estado habilitado. El recorrido real de ventas y registro lo conserva la suite de cierre anticipado. El guardado de estas tomas usa un archivo separado de la partida del jugador.

El registrador pausa el árbol durante el giro y durante la apertura. Las pruebas de integración ejercen además el control de pausa del juego. Las capturas ralentizan el dibujo, por lo que sus tiempos sirven para identificar los cuadros y no para evaluar rendimiento.

| Archivo | Qué muestra |
|---|---|
| jornada-1.mp4, jornada-2.mp4, jornada-3.mp4 | Secuencia real con audio y dos pausas |
| jornada-1.json, jornada-2.json, jornada-3.json | Eventos y poses por captura |
| 01-antes.png | Entrada enfocada y referencia Interactuar antes del clic |
| 02-giro.png | Cámara girando con la puerta cerrada y la persiana arriba |
| 03-abriendo.png | Hoja a medio abrir y persiana arriba |
| 04-abierta.png | Apertura completa antes de comenzar la bajada |
| 05-persiana.png | Bajada y devolución habitual |
| registrar_salida.gd | Registrador usado en las tres tomas |

En cada registro hay una apertura y un cierre de jornada. El ángulo de la puerta al cerrar vale PI/2. Durante cada pausa se conservan los ángulos de cámara y puerta. La posición del jugador permanece fija desde el clic.

## Decisiones y verificación

Model the Domain llevó el orden a una etapa enumerada. Sequence Work into Verifiable Units separó el contrato, la regresión roja y la implementación. Test Behavior, Not Implementation mantuvo las aserciones sobre puerta, persiana, control, devolución y guardado. Prove It Works exigió estas capturas del juego y el fallo real de CI antes de implementar.

Se comparó una máquina de estados con una operación asíncrona sobre el ciclo existente. Se eligió la primera para descartar confirmaciones fuera de orden y pedidos repetidos sin dejar esperas suspendidas entre jornadas. La escena sólo conecta los actores. No se modificó ningún `.tscn`.

La regresión previa falló en el run `39713457599`, partición 2, con seis aserciones de persiana y devolución prematuras. La primera implementación pasó las otras aserciones pero falló al suponer que una sola entrada del mouse activaba el suavizado adaptativo. El test ahora prepara la cadencia de mouse lento que ya usan las pruebas de control y conserva la aserción de giro pendiente.

Las cuatro pruebas de animación pasaron en el run `39715438595`. Esa corrida detectó además que el helper anterior esperaba `hoja_quieta()` sin argumentos. La señal entrega el cuerpo de la puerta. La corrección conserva la espera del hito real y añade su argumento, sin modificar el producto ni aumentar el timeout.

Se descartó la primera toma porque el clic sintético no tenía coordenadas válidas. Una segunda toma confirmó la secuencia. Se repitió con reloj monotónico para sincronizar los cuadros y el audio de los MP4 publicados.

La revisión estática no encontró problemas ni comentarios agregados prescindibles. Los agentes usaron el modelo heredado porque no había configuración local de modelos. La revisión no aporta diversidad de modelos. La CI final y su enlace quedan en el PR.

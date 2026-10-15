# Evidencia de #435

Revisi?n de c?digo: 6fbfe2af. Godot 4.7.2, Windows, Compatibility/OpenGL3 sobre NVIDIA RTX 4050.

La verificaci?n completa pas? 7/7 a la primera: 265/265 suites, 2044/2044 casos, sin nodos salteados. Los focales ejecutaron 3/3 suites y 37/37 casos. El rojo previo del dominio tiene fallos de aserci?n esperados, sin errores de ejecuci?n. La revisi?n del motor completo contrasta los 67 diagn?sticos deliberados con la base; s?lo normaliza IDs temporales y coordenadas de rescate a mil?metros, conservando su funci?n y archivo causantes.

Las 14 capturas son automatizadas, de dos instancias limpias de la escena real en jornada 2. El reloj del turno avanza hasta la ?ltima hora y emite el evento real. Se detienen ?nicamente los procesos del reloj y de la pila para observar el mismo instante; no se apaga la ra?z ni sus cuerpos. La computadora usa su entrada p?blica de presentaci?n; celular, ventanilla y pausa usan sus puertos reales. La pila consume un segundo antes de pausar y dos despu?s de reanudar. El clic real a trav?s del aviso, la pausa del procesamiento y el reinicio de las cinco jornadas se ejercen adem?s en las suites.

El aviso usa layer 5 y pausa layer 6. `nativo/medidas.json` conserva textos, rect?ngulos, cursor y pausa por captura. Los scripts y stdout/stderr se incluyen para reproducir el protocolo. No se presenta este fixture como un recorrido manual del juego.

`huellas.json` registra los bytes locales de todos los otros archivos; la auditor?a posterior los contrasta con los blobs publicados.

# Evidencia de #435

Revisión de código: 6fbfe2af. Godot 4.7.2, Windows, Compatibility/OpenGL3 sobre NVIDIA RTX 4050.

La verificación completa pasó 7/7 a la primera: 265/265 suites, 2044/2044 casos, sin nodos salteados. Los focales ejecutaron 3/3 suites y 37/37 casos. El rojo previo del dominio tiene fallos de aserción esperados, sin errores de ejecución. La revisión del motor completo contrasta los 67 diagnósticos deliberados con la base; sólo normaliza IDs temporales y coordenadas de rescate a milímetros, conservando su función y archivo causantes.

Las 14 capturas son automatizadas, de dos instancias limpias de la escena real en jornada 2. El reloj del turno avanza hasta la última hora y emite el evento real. Se detienen únicamente los procesos del reloj y de la pila para observar el mismo instante; no se apaga la raíz ni sus cuerpos. La computadora usa su entrada pública de presentación; celular, ventanilla y pausa usan sus puertos reales. La pila consume un segundo antes de pausar y dos después de reanudar. El clic real a través del aviso, la pausa del procesamiento y el reinicio de las cinco jornadas se ejercen además en las suites.

El aviso usa layer 5 y pausa layer 6. `nativo/medidas.json` conserva textos, rectángulos, cursor y pausa por captura. Los scripts y stdout/stderr se incluyen para reproducir el protocolo. No se presenta este fixture como un recorrido manual del juego.

`huellas.json` registra los bytes publicados de todos los otros archivos. La primera publicación normalizó finales de línea; se conserva su commit y sus hashes locales de procedencia. La segunda publicación corrige el manifiesto y se contrasta archivo por archivo con los blobs remotos.

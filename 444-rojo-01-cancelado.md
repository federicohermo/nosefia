El turno root-444-rojo-01 se canceló mientras esperaba detrás de la completa #433.
Se contrastó el PID 54652 y su CommandLine antes de terminar exclusivamente ese proceso.
Nunca adquirió el motor: no existe salida de Godot ni se acredita como testigo rojo.

La revisión previa detectó entradas[-1] sobre el Resource vacío del stub, que habría
producido un error de script. Se conservó la suite original afuera como
444-rojo-01-suite-retirada-sin-ejecucion.gd. Se agregó una aserción de contenido no vacío
antes de indexar y se reencoló root-444-rojo-02 con cuatro casos. No se cambió producción
ni se interrumpió otro turno. La raíz volvió a quedar congelada desde ese enqueue.

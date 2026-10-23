Forma de datos. Cada PantallaDeCarga tiene una ProgressBar, cuyo value ya es el progreso visible. No hace falta otro acumulador.

Ground. El calentamiento emite estimaciones v?lidas que pueden bajar al crecer el trabajo o recalcular la cola. El men? conserva otro m?ximo y usa ese valor para el llenado final. La transici?n conecta directamente la se?al a pintar. Una pantalla se reutiliza en el men? despu?s de una carga fallida, mientras entre noches se instancia una nueva.

Sketch A. Conservar el m?ximo en cada emisor obligar?a a duplicar el contrato y no proteger?a otros consumidores.
Sketch B. Conservar el m?ximo en pintar, reiniciar en mostrar y exponer progreso() para el llenado final del men?. El value existente es la ?nica fuente de estado.

Decisi?n. B. Misma firma de pintar. Un getter permite quitar el acumulador y el wrapper del men?. Sin cambios a la estimaci?n ni a escenas. La comparaci?n usa el valor visible, que ProgressBar ya limita a su rango.

Revisi?n sin subagentes, por pedido del usuario. Principios aplicados: Model the Domain, Fix Root Causes, Test Behavior Not Implementation, Laziness Protocol y Prove It Works.

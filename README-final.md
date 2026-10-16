# Apoyos reales de cajas — #428

El borde gris del baño sostiene ambos tamaños. En la cabecera de góndola, el gesto acomoda
la caja sobre metal visible, como eligió el usuario. El frontal conserva el encuadre anterior;
el contacto oculto tras Saladik se muestra en las vistas lateral y alta del commit inmutable
f1ef7fbb6e6c1fc4e82be1d606cb0b0deeab5e45. La decisión y sus once blobs permanecen intactos.

La reserva lógica de mercancía queda separada del soporte físico. Los tres muebles rechazan
unidades dentro del hueco comercial sin convertirse en plataformas para cajas. Se preservan
la esquina exterior oblicua, el interior de heladera, inventario, tareas y recogida.
El mismo predicado rechaza también el candidato interior de una bolsa desde el jugador,
conservando el guard heredado AC-PLY-035 y su caída sin mira.

Fuente actual: 3e381d1be90e30589e9c7b38905199a576c43201. Antes: d9bfd082 para control de caída y bc26e684 para el control anterior.
Convergencia definitiva: tercera completa, 7/7 nodos, 269/269 suites y 2075/2075 casos,
sin errores, fallos, skips ni huérfanos. XML y conteo inmediato se conservan juntos. El crudo
no contiene Script Error, Parse Error ni fugas. Sus 73 diagnósticos frente a 67 del control
incluyen rescates y cambios de pose/clase: las diferencias se preservan completas y no se
presentan como identidad literal ni se atribuye fase por concatenar stdout y stderr.
Las doce fotos nuevas son cuatro gestos reales baño/góndola × chica/grande, a 1280×720 con
OpenGL3/RTX4050. No hay liberación manual de física ni pose V5 en el protocolo final.
Las fotos de recogida muestran el apoyo vacío; la identidad en mano se prueba en el crudo.

La cascada reveló 14,488 mm de penetración heredada en el piso, idéntica antes y después del
compuesto. Se corrigió la revisión del reposo: espera el estado final de congelación y cancela
si el cuerpo se destruyó o despertó. Los guards estrictos de base y volumen se mantienen.
El empate de ROCE usa igualdad numérica estándar: el exceso de 67 nm era redondeo float32,
no una holgura de juego. El resultado y los incidentes anteriores se conservan.
La primera completa detectó dos regresiones: bolsa colocada dentro de la reserva comercial
y apoyo anotado anterior después de rescatar una caja. Se conserva íntegra esa completa roja.
El test causal de apoyo anotado falló por el dato antiguo y pasó tras actualizarlo únicamente
después de rescatar un cuerpo que ya estaba congelado y dormido. La señal previa conserva
el origen necesario para despertar la pila; no se cambia CajaDeProductos ni el acomodo manual.
Las cinco focales de caja, bolsa, red, integración y matriz pasaron. El helper de recogida
de la reserva falló porque un rayo al pivote podía encontrar antes la mancha del piso.
Se conservan sus descartes: el helper final consulta centro convexo y caras visibles desde
los mismos veinticuatro pies candidatos, y sigue exigiendo impacto, foco real y gesto.
La suite final de reserva pasó sus tres casos sin errores ni retenciones al cerrar.
La segunda completa todavía detectó flotación en la pila heredada, sin errores ni fugas.
Dos tests causales nuevos prueban que una caja intermedia despierta cortaba la visita de
otra superior congelada, en ambos tamaños. El recorrido ahora usa RID visitados locales
y atraviesa las dos condiciones. La traza válida del runner anterior pasó sus veinte casos;
se conserva separada de las completas fallidas y no demuestra una causa única del fallo.
Se conservan también los dos observadores inválidos como incidentes propios del diagnóstico.
La traza externa conjunta terminó su diagnóstico pero retuvo recursos al cerrar la bolsa;
se conserva como incidente y no como evidencia verde ni fuga atribuida al producto.
Las focales de la cabeza final ejecutaron 66 casos: matriz y puentes 18, cajas heredadas 20,
red 18, reserva 3 e integración 7. Los 20 casos previos de reposición se distinguen como
fuente 3d1b7cb7; no se suman como 86 casos de la cabeza final. Las dos suites aisladas de
cajas e integración retuvieron cien recursos al cerrar, registrados en sus crudos; la
completa definitiva se audita aparte y exige ausencia de fugas, sin usar esa observación
aislada como una exención.

Geometría: 65 convexos en cada góndola central A/B y 16 prismas de riel. La cobertura completa de las caras
metálicas y los 43.860 rayos de grilla se documentan aparte. El máximo de relleno observado
fue 3 mm: no es una cota continua de Hausdorff. Las 48 etiquetas planas sin volumen se excluyen.
El generador real de Blender ejecutó dos pasadas y conservó cuatro salidas byteidénticas y
el SHA del arte. No se modificaron assets ni otros bloques de la estructura.

Rendimiento: 300 muestras por cada uno de tres recorridos y variante. Las consultas p95
pasaron de 56/57/52 µs a 122/132/79 µs. Física p95: 3,484/2,362/3,074 ms frente a
2,504/2,314/2,024 ms. Intervalo p95 de cuadros alrededor de 16,7 ms en ambas variantes.
Se conserva un máximo aislado de 82,726 ms en la candidata, sin atribuir causa.

El control verbose de volumen y contorno conserva exactamente los mismos cien recursos
de addons, sin nuevos ni ausentes. Esto no sustituye la auditoría de la suite completa.
Los manifiestos distinguen bytes locales de los blobs publicados cuando Git normaliza texto.
Este README-final describe la entrega actual. README.md y decision/ conservan la muestra
histórica anterior a la decisión, byteidéntica al commit inmutable citado.

- [Convergencia definitiva y XML](convergencia/)
- [Primera completa fallida](incidentes/full01/) y [segunda completa fallida](incidentes/full02/)
- [Cuatro gestos finales y crudo nativo](despues-final/)
- [Focales y retenciones aisladas explícitas](focales-final-auditadas.json)
- [Hashes de todos los archivos](huellas-final.json) y [fuentes de cada medición](procedencia/fuentes-final.json)

El delta generado conserva una línea vacía al final de estructura_del_almacen.tscn que
git diff --check advierte; no se afirma un delta totalmente limpio de avisos de formato.

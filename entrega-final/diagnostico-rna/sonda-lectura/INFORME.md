# Realimentación de escala: sonda de lectura

Fuente de código c780de3e0290826236dbd7a55bb9f66659db4645. Una ejecución Blender
por FIFO, 35 segundos, sin guardar. Los 35 inputs conservaron sus SHA exactos.
`sourcepins.json` identifica los tres modelos copiados y el código. La primera
fuente generada es un **backup candidato**, no los textos originales perdidos.

## Resultado y causa medida

`_puntos` y `matriz_de` leen `matrix_world.to_scale()`. `poner` asigna una matriz
global, que Blender descompone en las propiedades locales del objeto. Volver a
leer la norma de esa matriz reconstruida incorpora error de punto flotante a la
escala que se usa para la siguiente colocación y regeneración.

Los tres modelos contienen 32 unidades fuente. Los cinco marcos heredados
`parent.matrix_world @ matrix_parent_inverse` son rígidos; su escala calculada
es exactamente (1, 1, 1) en Blender. Por eso, en estas fuentes la escala local
conservada expresa también la escala del envase en el mundo, sin depender de la
rotación anterior. No se presume válido para futuros padres con escala o shear.

En los tres modelos, el camino actual cambia los textos de matrices a seis
decimales de Arvejas y Coracola entre ciclos. Amargadito también cambia su matriz
RNA en original/primera, aunque no cruza un decimal escrito en este ensayo.
Ambas alternativas ensayadas conservan exactamente la escala local y tienen
matrices RNA idénticas entre ciclos para los 31 productos exhibidos:

- Leer escala local y, tras asignar `matrix_world`, restaurar `object.scale`.
- Leer escala local y asignar location/rotation/scale por componentes locales.

La primera alternativa requiere menos cambios y evita cambiar el cálculo de
orientación existente. La segunda es también estable, pero modifica más código.
No se modifica `_numero`, `punto_en_godot`, el exportador ni los compuestos de #428.

El ensayo mueve reiteradamente un clon por los lugares de su principal; amplifica
la realimentación para distinguir causas. Registra también filas y matrices del
padre de copias de cada tanda. **No equivale a tres regeneraciones completas**:
no guarda/reabre candidatos, no prueba todos los clones tras cambiarles el padre
ni prueba los cuatro textos finales. El desvío máximo objetivo/RNA de ambos
candidatos fue 0,000000476837 m; es una observación, no una tolerancia nueva para
aceptar idempotencia. El gate de textos sigue exigiendo bytes idénticos.

## Hunk mínimo propuesto, todavía no aplicado

En `_puntos` y `matriz_de`, sustituir cada lectura de
`unidad.matrix_world.to_scale()` por `unidad.scale.copy()` con documentación de
los padres rígidos medidos. En `poner`, capturar esa escala antes de cambiar
padre/matriz y restaurarla en el objeto colocado después de `matrix_world`.
Conservar todos los padres, ángulos y las escalas originales del artista.

La siguiente generación debe arrancar desde la copia original 0c23, porque el
modelo ya generado contiene la escala degradada que este cambio no puede adivinar
ni recuperar. El generador reconstruye su guía y sus metadatos visibles; no hace
falta introducir metadatos de escala ocultos.

Antes de otra ejecución: conservar por separado TODOS los outputs de primera y
segunda pasada (blend, GLB, huella, caché unwrap, cuatro textos y 32 RES), con SHA.
Después comparar estrictamente textos/RES y analizar por separado el GLB.

## Cruce con las exportaciones ya conservadas

El análisis puro `../deltas-glb.json` observó los mismos 255 nodos y 222 mallas,
índices/posiciones/normales exactos y 97 imágenes/materiales exactos. Cambiaron
cuatro transformaciones: Amargadito, Marolini, Arvejas y Coracola, hasta
0,000000238419 m en traslación. También cambiaron UV exportadas de muebles y
vanitory hasta 0,000000238419, sin cambios de geometría ni materiales. Esto último
se clasifica aparte: no se atribuye a los UV del arte fuente ni autoriza redondear.

El primer `producto_coracola.res` no se copió: sólo existe su SHA. No se atribuye
su diferencia binaria todavía. Los tres primeros textos tampoco están preservados
como originales. Cualquier reconstrucción futura desde backup llevará esa etiqueta
y sólo un HASHMATCH contra el manifiesto primero probará equivalencia de bytes.

Crudos: `blender.log`, `turno.log`; detalle: `medicion.json`, `resumen.json`,
`limites-candidato.json`. No se ejecutaron más motores después de esta sonda.

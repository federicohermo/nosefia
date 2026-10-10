# Evidencia de #369

Cabeza de producto probada: a59b80ad906c04e669a83c7649db0f23242c95dc.
Base integrada: eb8ac2b2a5fca71166a7ea4330667e43fd863fd2.
Primera publicación de las dos capturas: ef818405c4879ec1dfbe972aeb98e56e6b766483, conservada como ancestro.

## Rojos y focos

- `369-rojo-dominio-2.log`: 28 casos, 25 aserciones fallidas, cero errores de carga.
- `369-rojo-escena-3.log`: 11 casos, 76 aserciones fallidas, cero errores de carga.
- `369-rojo-tokenizacion.log` y su crudo Godot: testigo decimal, 6 casos y 3 aserciones fallidas antes de corregir el token completo.
- `369-verde-geometria.log` y su crudo: 2 suites/9 casos verdes, pila y recorrido de bolsas.
- `369-regresion-focal.log` y su crudo: 127 suites/1130 casos, 7 aserciones por premisas heredadas; se preserva el rojo.
- `369-captura-validada.log` y `369-captura-validacion-godot.log`: 6 suites/44 casos verdes en el contador; el crudo mostró un callback duplicado de persiana en el fixture. Se corrigió terminando la entrada antes de avanzar la noche.
- `369-verde-fixtures-final.log` y su crudo: 4 suites/35 casos, cero errores, fallos, salteos y huérfanos; sin callback duplicado.

## Intentos e incidentes conservados

`369-rojo-dominio.log` conserva un primer import abortado (3221225477).
`369-rojo-escena.log` y `369-rojo-escena-2.log` conservan los intentos invalidados por constante no declarada y quoting de la sonda. No se presentan como TDD de aserciones.
`369-sonda-geometria.log` es una sonda de geometría con avisos de recursos al salir; no se presenta como verde.
`369-verde-inicial.log` conserva 31 aserciones fallidas por premisas iniciales de fixture y sincronización de áreas; su nombre de archivo no implica un resultado verde.

## Convergencia

La base original pasó 7/7, 225 suites/1740 casos en 761,1 s; `base.log` y `base-motor.log` conservan resultado y crudo.
La base integrada #301 también se conserva en `301-final-tests.log` y `301-motor.log` para comparar diagnósticos heredados.

Full1 (`369-final*`): 6/7 nodos, 231/231 suites, 1764 casos y 25 aserciones fallidas, 741,2 s. Las premisas corregidas se limitaron a fixtures autorizados: apoyos directos en jornada 2, pallet desde pose inicial y enlaces serializados antes de `_ready`. No se cambiaron tolerancias ni balance. El crudo registró 142 ObjectDB/100 recursos al salir.

Full2 (`369-final-2*`): 7/7 nodos, 231/231 suites y 1764/1764 casos, 739,9 s. Cero errores, fallos, flaky, skipped y orphans de Godot. Es una verificación formal repetida. Cada nodo, importación, XML y `godot.log` se conserva incluso en verde. El conteo se ejecutó inmediatamente en ambos intentos, sin otra suite, y confirma 231 archivos/231 suites. Los dos archivos `conteo-full*-inmediato.txt` son extractos identificados; la fuente es el stdout original.

No se omitió ningún nodo. Harness conserva el caso condicionado de la base (no hay `.res` comprimidos). El comando oficial produce los diagnósticos deliberados de puerto 0. Full2 vuelve a los 141 ObjectDB/100 recursos y PagedAllocator de la base, aislados por el padre al orden de carga de dos suites de gdUnit4. Los avisos de rescate adicionales corresponden a los escenarios ejercidos.

## Capturas y hashes

Las dos PNG reales fueron abiertas y aprobadas por el padre. Desde la puerta, los racks ocultan parte de la pila; la vista interior complementaria muestra las columnas delante del portón y los estantes vacíos. No se movieron cajas ni se ocultó geometría para capturar.

`manifiesto.json` contiene SHA256, bytes y OID de cada blob publicado, incluidas ambas PNG. Se calcula sobre `git cat-file blob` después de publicar los contenidos y se verifica de nuevo contra la cabeza final y cada URL cruda por commit. Los hashes locales se identifican sólo como procedencia. El manifiesto se excluye de su propio hash para evitar una referencia circular.

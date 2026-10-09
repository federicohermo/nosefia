# Evidencia #327 y del ajuste previo de export

Base: `444d05db`, geometría `f17948fe`. Candidato: `c8990685`.
Los dos exports reales usan el mismo preset, idéntico al changeset previo.
Las fixtures UI sólo cambian main_scene y usuario aislado, sin autoloads;
presentan las escenas originales y cargan explícitamente 356 recursos.
El recorrido y el inventario entran al almacén real con contextos nuevos.

`resumen.json` reúne hashes conservados, inventario y comparaciones de capturas.
La GPU es RTX 4050/ANGLE Direct3D11, Godot 4.7.2 Compatibility/S3TC, Chrome 154.
Son bytes lógicos de texturas: excluyen renderbuffers, copias CPU y driver.
No representan VRAM física ni una mejora de FPS.

La compresión ahorra 7.257.600 bytes lógicos (87,5 %) en ventanilla.
El PCK aumenta 214.484 bytes respecto a su base: se informa como disco.
El changeset anterior ahorra 5.761.024 bytes de PCK retirando sólo 14 entradas
correspondientes a siete archivos sin referencias. Los originales siguen intactos.
Los tres cambios de metadata se decodifican en los JSON de registros:
106 clases idénticas salvo orden, siete UID retirados y el ID generado de un único
nodo del panel del addon MCP. No se modifica arte ni recursos de juego.

`c-exclusion-comparaciones.log` contiene exports y recorridos exitosos, y termina 1
en una comparación binaria inicialmente demasiado estricta de esas tres metadatas.
La comparación posterior decodifica/verifica cada campo y sale 0; sus resultados están
en `c-exclusion-validacion.json`. No se oculta la primera corrida.
Los exports all_resources originales de 93,8/94,0 MiB excedían el techo de 90 MiB;
esa regresión de base se conserva en sus logs diagnósticos, separados del fix.

Ventanilla base/propuesta reproduce exactamente los píxeles de las capturas históricas
aceptadas. Diferencia entre variantes: MAE 0,392269483/255, p99=2, máximo 6.
Computadora e inicio son idénticos entre variantes. Se comprueban ambas UI en 1920×1080
y 1280×720, con apertura/cierre, audio, tres conversaciones y cero errores.

Las dos full propias pasaron 7/7, sin salteos, con 190 suites/1494 casos cada una.
Cada una fue seguida inmediatamente por conteo: 190 suites / 190 archivos.
La primera corrida duró 729,3 s; la segunda usa la base final del ajuste de export.
Los registros completos conservan los resultados y tiempos exactos.
También se publica la primera full 7/7 del ajuste independiente de export:
731,4 s, 190 suites/1494 casos y conteo inmediato de 190 suites / 190 archivos.

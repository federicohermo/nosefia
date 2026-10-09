# Evidencia #327 y del ajuste previo de export

Base: `444d05db`, geometría `f17948fe`. Candidato: `c8990685`.
Los dos exports reales usan el mismo preset, idéntico al changeset previo.
Las fixtures UI sólo cambian main_scene y usuario aislado, sin autoloads;
presentan las escenas originales y cargan explícitamente 356 recursos.
El recorrido y el inventario entran al almacén real con contextos nuevos.

`resumen.json` reúne hashes conservados, inventario y comparaciones de capturas.
La GPU es RTX4050/ANGLE Direct3D11, Godot4.7.2 Compatibility/S3TC, Chrome154.
Son bytes lógicos de texturas: excluyen renderbuffers, copias CPU y driver.
No representan VRAM física ni una mejora de FPS.

La compresión ahorra7.257.600 bytes lógicos (87,5%) en ventanilla.
El PCK aumenta214.484 bytes respecto a su base: se informa como disco.
El changeset anterior ahorra5.761.024 bytes de PCK retirando sólo14 entradas
correspondientes a siete archivos sin referencias. Los originales siguen intactos.
Los tres cambios de metadata se decodifican en los JSON de registros:
106 clases idénticas salvo orden, siete UID retirados y el ID generado de un único
nodo del panel del addon MCP. No se modifica arte ni recursos de juego.

`c-exclusion-comparaciones.log` contiene exports y recorridos exitosos, y termina1
en una comparación binaria inicialmente demasiado estricta de esas tres metadatas.
La comparación posterior decodifica/verifica cada campo y sale0; sus resultados están
en `c-exclusion-validacion.json`. No se oculta la primera corrida.
Los exports all_resources originales93,8/94,0MiB excedían el techo90MiB;
esa regresión de base se conserva en sus logs diagnósticos, separados del fix.

Ventanilla base/propuesta reproduce exactamente los píxeles de las capturas históricas
aceptadas. Diferencia entre variantes: MAE0,392269483/255, p99=2, máximo6.
Computadora e inicio son idénticos entre variantes. Se comprueban ambas UI en1920×1080
y1280×720, con apertura/cierre, audio, tres conversaciones y cero errores.

La primera full propia pasó7/7 con190 suites/1494 casos. La segunda full tras
rebase al ajuste de export se informa en el PR cuando termina, seguida por conteo.

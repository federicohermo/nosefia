# Evidencia de #430

Código `ff5d8d960fb9d8e4f1a68d1db60e469613bd4c25`, rama
`feature/430-chats-apertura-jornada-2`, sobre contratos `dc83c877`.

## TDD

| Fase válida | Suites/casos | Casos rojos | Aserciones fallidas | Errores / huérfanos |
|---|---|---|---|---|
| Guion | 1/3 | 3 | 3 | 0/0 |
| Contenido y metadatos | 2/8 | 7 | 7 | 0/0 |
| Interacción | 3/19 | 4 | 12 | 0/0 |
| Glifos portables | 1/11 | 1 | 3 | 0/0 |
| Focal final | 16/129 | 0 | 0 | 0/0 |

Crudos/XML en `tdd/` y `focal/`. El focal definitivo es `focal-glifos-verde.log` y
`focal-glifos-verde.xml`: 528 líneas revisadas, sólo dos errores deliberados del debugger
en puerto 0 presentes también en la base, sin retención.

## Recorridos reales

`nativo/`: catorce PNG, dos crudos estrictos, fixtures y JSON. Ambas resoluciones
1920×1080/1280×720 terminaron con FINAL0, sin errores/advertencias/fugas: dos pedidos 2A
por resolución, prefijo sin pedido, expediente intacto, cursor visible al abrir/capturado
al cerrar y scroll 6302 conservado al ampliar/cerrar la foto. Diez imágenes únicas abiertas;
cuatro son byteidénticas (`yasmin-tramo` a `yasmin-inicio`, `foto-cerrada` a `enrique`).
El padre aceptó los diez únicos y el fondo también visible en el primero:
`nativo/root-inspeccion.json`.

`web/`: diecinueve PNG del main original, acciones reales, consola desde carga y estados CDP
sin activación artificial. Continue carga un checkpoint de Partida real en J2; badges 23/15
antes de leer. A 1280 se conserva la misma partida ya leída. Las capturas comprobaron
visibilidad/aislamiento y 80–146 RAF en un segundo; Q cerrando recuperó Pointer Lock en ambas.
El historial visible antes/después de ampliar tiene cero diferencias de píxeles en ambas.
El padre aceptó diez estados principales: `web/root-inspeccion.json`.

Preview 💪 y burbujas ✨/💪 se ven como contornos reconocibles, sin hexadecimales. Roles, círculo
liso, frase lila, contenedor y adjunto se inspeccionaron a ambas resoluciones. Consola final:
cero errores/pageerrors y 36 avisos Chromium `GL_INVALID_OPERATION: glBlitFramebuffer` durante
warmup, todos antes de `[carga] almacén en pantalla`. La misma familia/cuenta se observó en
el export anterior b764 y el control #427; comparación observacional, sin atribución causal.

## Paquete, fuente y foto

`paquete/huellas.json` fija HEAD, proyecto, preset, plantilla y cuatro artefactos.
PCK 96.453.952 bytes, SHA256
`ac8e8446e3417827165e75ea5f5c12b272468c9b336f226776e48fe2ad2b79b8`.
Proyecto y preset permanecen byteidénticos. Primer export: 111 recursos/162 ObjectDB retenidos
al salir. Control en MISMA copia/plugins ON/verbose: cero errores/advertencias/retención,
cuatro artefactos byteidénticos. Se conservan ambos crudos sin atribuir causa ni cambiar opciones.
La sonda fuera de fuente terminó `PAQUETE430_FINAL fallos=0` sin diagnósticos/retención:
ambos chats, orden, foto/adjunto, 2A, cuatro caminos de glifos y SHA exacto de FontFile.data,
incluida la OFL completa embebida.

`fuente/procedencia.json`: tres regeneraciones idénticas, familia renombrada
`No se fia Chat Symbols`, exactamente U+2728/U+1F4AA. Noto Emoji original GoogleFonts revisión
`8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5`; hashes fijados en el generador versionado.
Dependencia del generador del asset: `fonttools==4.60.0`.

```text
python -m pip install fonttools==4.60.0
python assets/ui/manada/celular/generar_simbolos_de_chat.py
```

TTF 11.184 bytes SHA256 `af469b9aea3c3e278a8def15a63d87f67264254b7c77823b871c5ba74b6fc4ed`.
OFL completa en archivo y dentro del TTF. FontVariation local conserva primaria como base;
el test comprueba que Theme/fallbacks/caracteres compartidos permanecen intactos.
`foto/` contiene PNG real y medición del rayo/encuadre; el generador valida las ocho esquinas
de cada malla del soporte antes de guardar.

## Incidentes

`incidentes/` conserva invocaciones/fixtures inválidos, focal parcial y recorte transitorio
de scroll corregido mediante ancho final del primer adjunto. `paquete-sin-glifos` y
`web-sin-glifos` son el export b764 que reveló hexadecimales, no el de aceptación.
`nativo-coordenadas`: fixture abortado, sólo su ventana identificada por PID se cerró para
recoger crudo. `nativo-control-02`: warp_mouse no resolvía clics posteriores a rueda. La única
diferencia del control final es también enviar rueda liberada; resolvió 2A/regreso/foto ambas
resoluciones sin cambiar producción. Fixtures/crudos permiten comparar el protocolo.

## Convergencia

Primera completa propia: **7/7 nodos verdes, sin nodos salteados, 912,1 segundos**.
Conteo inmediato: **268 suites corridas / 268 archivos**. XML: **2048/2048 casos**, cero
fallos, errores, flaky, skipped y huérfanos. `completa/` conserva los siete crudos, import,
XML, conteo inmediato y la salida con los marcadores finales.

Se leyeron íntegros los 1.160.340 bytes del crudo del juego y se compararon con la base:
mismos 25 errores deliberados y 42 avisos Rescate, con sus causas/contextos de tests;
cero diagnósticos nuevos/ausentes, nuevas familias de rescate, retención o abortos.
`auditoria-crudo.json` y `diagnosticos-completos.json` conservan la comparación y los
contextos completos. La rama de código coincide con el SHA remoto citado arriba y está limpia.
El unittest Python del harness registra 606 pruebas y un skipped, igual que la base;
ningún nodo se salteó ni ningún caso gdUnit4 se omitió.

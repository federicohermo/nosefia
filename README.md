# Evidencia de #431

Fuente inmutable: `6d60f82c16bbbc1f7182e656ebead8df8bf5ad87`, sobre `e6cc0ac4bff25335c0b6a605d85b70cb9014cab0`.
La completa y los nativos midieron esa fuente limpia, congelada desde encolado hasta resultado.
El export final archiva exactamente esa cabeza en una copia externa, independiente del árbol donde ya se desarrolla #22.

`manifiesto.json` calcula tamaños, SHA256 y OID leyendo los blobs Git publicados.
`manifiesto-local.json` conserva por separado las huellas de los archivos locales, incluidos sus saltos de línea.
`full-01/pins.json` documenta el alcance real del registro anterior y posterior.

## Verificación

- Rojo funcional: siete casos, diez aserciones fallidas por rótulos ausentes, sin errores de script.
- Verde focal: cinco suites, 45 casos, exit 0.
- Primera y única completa: 7/7 nodos, 279/279 suites, 2147 casos, exit 0 y conteo inmediato.
- XML sin fallos, errores, skips o flaky; completa sin Script/Parse, ObjectDB, recursos retenidos ni Pages.
- CI del PR467 sobre la misma cabeza confirmó 7/7 y los mismos 279/2147.
- `full-01/revision-root-independiente.json` conserva la auditoría independiente de raíz.
- Cuatro avisos de Balde cambian pose, cuerpo o alternativa de rescate respecto de la base; ambos lados permanecen literales.

No se atribuye una causa a esos cuatro avisos.
Los errores deliberados del debugger remoto y fixtures se conservan; el registro completo contiene esos ERROR esperados.

## Criterios propios

| Criterio | Pruebas principales |
|---|---|
| Cinco rótulos por bloque conocido | `test_cada_bloque_conocido_separa_los_cinco_dias` |
| Historial J1/J2, reapertura y consulta pura | `test_reabrir_historial_real_de_jornada_2_conserva_lecturas_y_guion` |
| Contexto cerrado explícito | `test_el_contexto_fijo_cerrado_recalcula_solo_al_abrir_otra_jornada` y cierre real |
| Vacío, huecos, repetidos y legado | `test_vacio_huecos_repetidos_y_legacy_no_inventan_bloques` |
| Índices, metadata, foto e intercalación | `test_foto_y_tramo_despues_del_separador_conservan_indices_y_metadata`, `test_intercalar_actualiza_fotos_sin_reconstruir_la_ampliada` |
| Encabezado, opción y foto en ambas resoluciones | `test_recibir_en_un_bloque_no_duplica_y_conserva_la_opcion_al_final`, `test_cabecera_opcion_y_foto_caben_en_ambos_encuadres` |

Los ocho casos están en `test/ui/diegetica/separadores_del_celular_test.gd` y pasaron.
Los fixtures heredados conservan las aserciones de entrada, lectura, metadata, adjunto y scroll de #430.
Este issue no añade AC de spec; sus citas heredadas siguen comprobando su comportamiento correspondiente.
La composición genérica prepara notas futuras; NOTAS y la selección de hipótesis pertenecen a sus issues.

## Capturas nativas

`nativo/` contiene 22 PNG, recorridos JSON y logs completos, a 1920×1080 y 1280×720.
`nativo-*-enrique-ayer.png` muestra AYER al comienzo de J1.
`nativo-*-cierre-jornada-2-rotulo-hoy.png` muestra HOY durante el cierre J2, con Partida ya en 3.
`nativo-*-cierre-jornada-2-hoy.png` conserva CONTINUAR y los mensajes finales; su nombre no acredita un rótulo visible.
`nativo-*-foto-intercalada.png` conserva la misma ampliación al insertar un mensaje anterior.
El fixture comprueba identidad del nodo, índice actualizado, adjunto y scroll, y dos pedidos 2A desde el tramo lila.

## Paquete y Chrome definitivos

`paquete-03/` contiene el export definitivo, sus guardias, huellas, manifiesto de plantilla y sondas completas.
`paquete/` y `incidentes/paquete-plantilla-anterior/` conservan mediciones históricas con otra plantilla.
La receta actual tiene identidad `d8b6ba2bc89cd8c041831c20bbe3739f3364529431b390698cccfece327a2b56` y origen COMPILADO.
La pareja ZIP/manifiesto se copió íntegra, sin importarla ni modificar sus metadatos.
ZIP: `56ef44d05a4715ed4b86ea612a1c983173e36ee2e032d7037f67a7055e0c35f7`.
WASM: `47b267630a0bbfcd0c8a1276a7b8f83adf24c2f1425ee2b83396331aa6e82c61`.
JS: `1fa2dfa3e6371b3ceeaa6eb37d6806a961358b0e1fb297f23f3f0beda961884b`.
`--comprobar` pasó antes de importar/exportar y `--verificar-export` pasó después.
Proyecto, preset y los cuatro artefactos permanecieron idénticos durante las sondas finales.

La primera sonda del paquete03 acabó con 24 ObjectDB y cuatro recursos de audio retenidos.
El control verbose identifica Neon, Tema1, sus OggPacketSequence y los playbacks; conserva cada ruta y clase.
La variante del runner difiere únicamente la salida hasta después del retorno de su método.
Ese control y la sonda de diálogos terminaron sin errores, avisos ni retenciones, sobre exactamente el mismo PCK.
Se conservan ambos resultados; no se atribuye la retención a scripts, escenas ni addons.

`web/` corresponde a Chrome05 sobre ese paquete: exit 0, consola sin errores y PNG finales revisados a ambas resoluciones.
`web-1920-chats-validado.png` acredita CHATS real antes de enviar las acciones restantes.
El primer PNG llamado `web-1920-chats.png` muestra el mundo y se rechazó; no se infiere una causa desde esa imagen.
Se conservó, se esperó y se pulsó nuevamente; una espera fija o RAF nunca sustituyeron la inspección del menú real.
Los PNG Yasmín inicio, Enrique AYER/HOY, contenedor y foto cerrada acreditan texto, rótulos, glifos, adjunto y regreso.
El recorrido registra viewport efectivo, RAF, visibilidad y Pointer Lock; el cursor queda libre en el celular y capturado al volver.
El checkpoint J2 proviene de Partida real y su SHA256 aparece en el recorrido.
Chrome usó perfil efímero y datos aislados, sin tocar el guardado real.
`web/auditoria.json` conserva los avisos literales y el contraste con Web04, sin inferir equivalencia por cantidad.

## Intentos conservados

- Export inicial agotó C:; el proyecto parcial se trasladó íntegro a D: y su traceback se conserva.
- Export02 con plantilla anterior informó retenciones; su control posterior conserva artefactos idénticos y 39 Orphan StringName.
- Chrome01 rechazó su comprobación de dibujo; el runner antiguo no persistió la medición fallida.
- Chrome02 produjo imágenes del mundo y se rechazó; Chrome03 agotó inactividad antes del primer comando.
- Web04 funcionó visualmente con una plantilla anterior y permanece bajo `incidentes/web-plantilla-anterior/`.
- Una auditoría parcial agotó espacio y su JSON fue sobrescrito antes de recibir la instrucción de conservarlo.
- `full-01/incidente-errno28-auditoria.json` declara esa pérdida, separada de la auditoría definitiva.
- La publicación fedd normalizó CRLF a LF mientras el manifiesto describía bytes locales; se conserva el diagnóstico independiente.
- El commit correctivo c2e9 conserva fedd como padre y fue auditado: 235/235 blobs coinciden.
- La primera revisión raíz de c2e9 tuvo un falso positivo de esquema al aparecer el campo adicional OID; se conserva y se distingue.

Los incidentes de herramientas no requirieron cambiar el juego ni repetir la completa de #431.
`reproduccion/` conserva fuentes, runners y procedencia; adaptar sus rutas externas antes de reutilizarlos.

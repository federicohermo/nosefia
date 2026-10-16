# Evidencia de #431

Fuente: `6d60f82c16bbbc1f7182e656ebead8df8bf5ad87`, sobre `e6cc0ac4bff25335c0b6a605d85b70cb9014cab0`.
El worktree permaneció limpio y congelado desde cada encolado hasta su resultado.
`manifiesto.json` identifica archivos y SHA256; `full-01/pins.json` explica el alcance del registro previo y posterior.

## Verificación

- Rojo funcional: siete casos, diez aserciones fallidas por los rótulos ausentes; ningún error de script.
- Verde focal: cinco suites, 45 casos, exit 0.
- Primera y única completa: siete nodos verdes, 279/279 suites, 2147 casos, exit 0; conteo inmediato.
- XML sin failures, errors, skipped ni flaky. Ningún Script/Parse Error, ObjectDB, recurso retenido o Pages en la completa.
- Se conservan todos los diagnósticos literales y su comparación con la base integrada.
- Cuatro avisos de Balde cambian pose, cuerpo o alternativa de rescate. No se atribuye una causa.
- La revisión independiente del padre está en `full-01/revision-root-independiente.json`.

Los dos errores del puerto remoto 0 son deliberados y ya estaban en la base.
Otros errores deliberados de fixtures también se conservan; no se afirma que el log esté vacío de ERROR.

## Criterios del issue

| Criterio propio | Prueba principal | Resultado |
|---|---|---|
| Cinco rótulos, por bloque conocido | `test_cada_bloque_conocido_separa_los_cinco_dias` | Verde |
| Historial real J1/J2, reapertura y consulta pura | `test_reabrir_historial_real_de_jornada_2_conserva_lecturas_y_guion` | Verde |
| Día cerrado explícito, sin tomar la siguiente jornada | `test_el_contexto_fijo_cerrado_recalcula_solo_al_abrir_otra_jornada` y fixture de devolución real | Verde |
| Vacío, huecos, repetidos y legacy | `test_vacio_huecos_repetidos_y_legacy_no_inventan_bloques` | Verde |
| Índices, metadata, foto, adjunto e intercalación | `test_foto_y_tramo_despues_del_separador_conservan_indices_y_metadata`, `test_intercalar_actualiza_fotos_sin_reconstruir_la_ampliada` | Verde |
| Encabezado, opción y foto en ambos tamaños | `test_recibir_en_un_bloque_no_duplica_y_conserva_la_opcion_al_final`, `test_cabecera_opcion_y_foto_caben_en_ambos_encuadres` | Verde |

Todos esos casos están en `test/ui/diegetica/separadores_del_celular_test.gd`.
Los fixtures heredados mantienen las aserciones de entrada, lectura, metadata, adjunto y scroll de #430.
No hay AC de spec nuevos; las citas heredadas siguen ligadas a su conducta correspondiente.
La conversación genérica prueba la composición para notas futuras; NOTAS y la hipótesis pertenecen a otros issues.

## Capturas nativas válidas y medición Web pendiente

`nativo/` contiene las dos resoluciones, sus recorridos JSON y logs completos.
`nativo-*-enrique-ayer.png` muestra AYER al inicio del historial J1.
`nativo-*-cierre-jornada-2-rotulo-hoy.png` muestra HOY durante el cierre real J2, cuando Partida ya indica 3.
`nativo-*-cierre-jornada-2-hoy.png` conserva la vista final con CONTINUAR; su nombre no acredita que el rótulo esté dentro del scroll.
`nativo-*-foto-intercalada.png` conserva la ampliación al insertar otro mensaje antes de la foto.
El fixture comprueba el nuevo índice, el mismo nodo, el adjunto y el scroll conservados.
El recorrido pulsó sólo el tramo lila dos veces y produjo exactamente dos pedidos 2A.

`web/` corresponde al intento 04, exit 0, ejecutado sobre el PCK exportado de esta cabeza con una plantilla anterior.
Su imagen funciona, pero no acredita la receta vigente. La revisión independiente detectó la diferencia antes de abrir el PR.
La plantilla usada tiene ZIP `257ba2b...`; el preparador de esta cabeza exige `012d4d...` y consulta de recorte `isEnabled`.
La validación estática de `_cache` rechaza su identidad. Falta reexportar y recorrer con la pareja correcta.
Se comprobó visualmente el menú CHATS real antes de continuar; ni una espera fija ni RAF acreditaron por sí solos la entrada.
`recorrido.json` registra viewport efectivo, visibilidad, RAF y Pointer Lock en cada captura.
El cursor está liberado dentro del teléfono y capturado al volver al mundo, en ambos tamaños.
El checkpoint J2 es de una Partida real y su SHA256 está en el recorrido.
Se inyectó en el almacenamiento de un perfil efímero de Chrome; no se tocó el guardado del usuario.
El paquete, shell y preset originales permanecieron sin cambios; esto no sustituye la validación de la receta del motor.
`web/auditoria.json` coteja los 36 avisos glBlitFramebuffer con la evidencia publicada de #430.
Sólo cambia el handle hexadecimal; ambos textos literales y cantidades se conservan. No hubo errores de consola ni página.

## Paquete anterior y procedencia conservada

`paquete/huellas.json` registra fuente, preset, proyecto, plantilla y los cuatro artefactos exportados.
La fuente se archivó en una copia externa sobre D:, fuera de todos los worktrees.
La sonda main-pack carga el PCK, comprueba glifos, chats, rótulos, foto y metadata: `PAQUETE431_FINAL fallos=0`.
Esta sonda corresponde al paquete anterior y no cierra la comprobación pendiente de plantilla vigente.
`dialogos-paquete.log` conserva también la sonda de diálogos exportados de cierre próximo.
`reproduccion/` incluye fixtures y runners adaptados, con hashes de los originales de #430.
Sus rutas de scratch son propias de esta máquina: adaptar destino y puerto antes de reutilizarlos.

El primer export en D: informó 162 ObjectDB, 111 recursos y dos Pages al salir, con exit 0.
Se conservó el crudo y se repitió sólo exportación, con verbose y exactamente el mismo proyecto, preset y plugins.
El control no repitió esos diagnósticos; sus cuatro artefactos resultaron idénticos en SHA256.
El control sí informa 39 Orphan StringName; se conserva literalmente, sin presentarlo como un log vacío.
No se atribuye la retención inicial a addons por su cantidad.

## Intentos e incidentes

- El primer montaje de exportación agotó C:. Su traceback se conserva en `incidentes/exportar-sin-espacio.log`.
- Su archivo y proyecto parciales se trasladaron íntegros a `D:/nosefia-carril-C-429-444/431-export-incompleto-01`.
- Chrome 01 rechazó la comprobación de dibujo tras entrar. La medición que falló no quedó persistida en ese runner antiguo.
- Chrome 02 terminó con 0, pero sus capturas eran del mundo porque se pulsó Q durante la entrada. Se rechazó como evidencia.
- Chrome 03 agotó el límite de inactividad antes de recibir su primer comando. No prueba un fallo del juego.
- Los tres intentos anteriores, sus imágenes, consola y recorridos se conservan bajo `incidentes/`.
- Chrome 04 comprobó CHATS real y produjo las capturas válidas de `web/`.
- Una escritura inicial de auditoría agotó espacio. El JSON parcial fue sobrescrito antes de recibir la instrucción de conservarlo.
- `full-01/incidente-errno28-auditoria.json` declara esa pérdida; la auditoría definitiva se identifica por separado.

No se repitió la suite completa: los incidentes posteriores pertenecen al montaje de capturas y exportación.

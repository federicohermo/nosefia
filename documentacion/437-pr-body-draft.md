Conecta las identidades Fede/Mía de #433 a sus recursos propios en la ventanilla. Incorpora dieciséis PNG byteidénticos a los blobs de `62390898635a04fbb1b6a29558355a5e1984684f`, dos recursos idle y su procedencia, sin cambiar pose, geometría, pedidos o selección productiva.

Closes #437

Base explícita: #433 `d8c0d8cb5a6e3d968d9cd8fd04f4a12c17829875`, que incorpora #429. El cambio productivo de GDScript son únicamente las dos entradas FEDE/MIA de `ANIMACIONES`; no agrega AC ni modifica specs.

| Criterio propio | Evidencia |
|---|---|
| 16 originales binarios, resolución y alfa | `test_los_dieciseis_png_conservan_los_blobs_y_rgba_originales`; procedencia y SHA256 en `assets/characters/jornada_2_origen.md`. |
| Dos idle con ocho cuadros, orden y ritmo | `test_los_recursos_conservan_orden_duracion_y_ritmo_idle`. |
| Tabla FEDE/MIA y conservación Tin/Tia | `test_la_tabla_resuelve_cuatro_identidades_con_recursos_propios`. |
| Presencia, orientación y oclusión | `test_cada_figura_permanece_visible_al_hablar_y_volver_al_mundo` y `test_el_antepecho_ocluye_el_corte_desde_frente_lados_y_encuadre`; la premisa se prueba con piso/cápsula y triángulos reales. |
| Alfa, contorno, frame y cambio de comprador | `test_el_foco_y_contorno_usan_alfa_y_frame_actual_de_ambos` y `test_cambiar_comprador_cambia_recurso_y_reinicia_sin_contorno_anterior`. |
| Entrada, pausa, retirada y reinicio | `test_pausar_entrada_y_retirada_y_reiniciar_no_duplica_imagenes`. |
| Import frío, paquete y capturas | CI propia con checkout/import fríos Linux y suite completa verde. Export final conjunto `4fa20754` con ambas sondas externas verdes; los dieciséis `.ctex` nuevos estaban ausentes antes del import Windows inicial, y su continuidad binaria se comprobó en el export final. Capturas reales pendientes. El intento previo de clon totalmente frío Windows terminó nativamente con código 3221226356 y se conserva como intento incompleto, sin causa atribuida. |
| Sin activar agenda ni publicar guiones sustitutos | `test_el_fixture_no_modifica_las_selecciones_productivas` y diff de producción limitado a dos rutas; los textos de una entrada viven sólo en el fixture de tests excluido del preset. |

TDD: el primer intento conservado falló por un helper de aserción inexistente y no se cuenta como rojo funcional. El segundo ejecutó los nueve casos: catorce aserciones por las claves FEDE/MIA ausentes, cero errores XML; los casos de PNG y recursos ya pasaban. Después se agregaron las dos entradas de presentación.

Validación y entrega siguen en curso. El cierre requiere focal verde, CI de esta cabeza y lectura de crudos/XML de la completa local conjunta #437+#444. La exportación/capturas de esa integración se atribuirán a su cabeza explícita, con comparación de los dieciséis PNG, dos idle y tabla de este PR; no se presentan como una corrida exclusiva de #437. No se ha marcado aceptado por esos pasos todavía.

Cabeza de este PR: `838e0baae3ed7f61f6f3190a00058a5d6c10b503`. Verde focal: nueve casos propios ejecutados; crudos y XML conservados en 437-verde-02. La completa heredada se verifica junto a #444 sobre la integración final.

CI propia [38957377068](https://github.com/federicohermo/nosefia/actions/runs/38957377068): siete nodos en verde, 286 suites y 2181 casos, cero fallos, errores, saltos o flaky; los nueve casos propios están presentes en el XML. Se descargaron y auditaron workflow completo y XML. Los cuarenta archivos fijados para el focal coinciden con los blobs de esta cabeza y los pines antes/después son idénticos.

Export conjunto real: `4fa20754cd58c7f4a62699183a4a625df3e0d90a`, con preset y proyecto versionados intactos. Las sondas fuera de fuente terminaron con `SPRITES437_PCK_OK` y `PAQUETE444_FINAL fallos=0`, exit 0 y crudos sin errores de script/parseo ni retenciones. PCK SHA256 `9a974e7cdc6ffebe3017b2aafc7b91ec5843dc55c17728d087585deda93a5fc5` (109308012 bytes). Los cuarenta blobs de #437 son iguales entre esta cabeza y la integración; dieciséis PNG, dos idle y tabla siguen byteidénticos después del export. Los cuatro artefactos Web y los dieciséis `.ctex` coinciden entre los dos exports; el segundo usa caché y no se cuenta como frío.

El primer probe de diálogos se conserva fallido: tomaba el primer Node3D de la estructura como ticket. Se corrigió el selector de la sonda versionada y se reexportó la nueva cabeza; no cambió producto ni PCK. La completa local conjunta de raíz y las capturas reales posteriores al dibujo siguen pendientes. Este PR permanece borrador hasta esos resultados.

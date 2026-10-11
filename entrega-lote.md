# Entrega del lote 364, 369, 373, 374, 301 y 370

| Issue | Carril | PR | Criterios | Verificación completa |
|---|---|---|---|---|
| #364 | 364→373→374 | [#389](https://github.com/federicohermo/nosefia/pull/389) | 8/8 | Primera, 7/7; 228 suites / 1750 casos |
| #369 | 369→370 | [#391](https://github.com/federicohermo/nosefia/pull/391) | 18/18 | Segunda, 7/7; 231 suites / 1764 casos |
| #373 | 364→373→374 | [#394](https://github.com/federicohermo/nosefia/pull/394) | 33/33 | Segunda, 7/7; 236 suites / 1808 casos |
| #374 | 364→373→374 | [#395](https://github.com/federicohermo/nosefia/pull/395) | 11/11 | Tercera, 7/7; 239 suites / 1823 casos |
| #301 | 301→370 | [#390](https://github.com/federicohermo/nosefia/pull/390) | 8/8 | Primera, 7/7; 228 suites / 1750 casos |
| #370 | 369→370 y 301→370 | [#392](https://github.com/federicohermo/nosefia/pull/392) | 10/10 | Primera, 7/7; 232 suites / 1774 casos |

Ninguna entrega salteó nodos. Se conservan los intentos anteriores: #369 adaptó fixtures autorizados de la jornada y almacenamiento, #373 corrigió sólo orden de declaración y largo de un nombre para lint, y #374 adaptó el reloj del helper heredado de carga al fundido de 0,3 s. Su segunda completa dio 7/7 pero retuvo 23 scripts adicionales; controles equivalentes aislaron una precarga del fixture nuevo de dominio. Cargar el guion dentro del caso restableció la firma heredada sin cambiar aserciones ni producto. Un caso heredado de unittest del harness se saltea por ausencia de un recurso RSCC; no equivale a un nodo salteado ni a un test gdUnit omitido.

Tres carriles: 364→373→374, 369→370 y 301→370; ancho 3 y cero dependencias declaradas falsas. Las escenas compartidas se editaron en serie. La pila final incorpora 301 y 369 antes de 370, y 370 antes de 373.

Se cruzaron entrada, retención del reloj, particular declarada, guardado e investigación. Los contratos preceden al producto (PR #387); el usuario resolvió los ocho tiempos. La placa permanece quieta 1 s y se funde 0,5 s; después la persiana sube durante 1 s. El celular sube y baja en 0,25 s, el menú funde a negro en 0,3 s, la persiana baja aparece en 0,3 s y las instrucciones suben en 0,3 s. Las jornadas 3–5 conservan cuatro obligatorias y la particular reservada. Las bolsas de J2 usan la representación genérica ya decidida. #301 se midió sobre el modelo actual; #370 heredó su posición final. El issue externo #379 se corrigió para referenciar celular #373 y examen #376.

Los límites se corrigieron completos antes de modificar lectores: fixtures de J2, preset versionado, README y generador de fotos. Se conservaron las aserciones útiles. La revisión cruzada detectó una cita de retomar sin reconstrucción real; el test ahora destruye y reconstruye el almacén desde Guardado. Se corrigió también un fixture que conservaba el estado del menú anterior al borrar el archivo.

La auditoría encontró también AC-EMP-050 sin cita ni los bordes 3/2 de jornada 3. Se amplió el issue #374 entero para extender sólo el caso heredado de Partida, conservando el caso original de cuatro cumplidas y sin cambiar el dominio.

PR #388 recoge doce lecciones en implement-batch, implement-feature, to-issue, to-spec y sin-deuda, con espejos .agents: referencias numéricas, tareas declaradas, colisiones, sincronización física, ambos canales de salida, literales numéricos completos, dependencias del preset, aislamiento medido de plugins sólo en la copia externa, observación pasiva del navegador, callbacks del cursor activos durante la medición, asignación explícita de cada AC del contrato común e identificación de retenciones por fase con controles equivalentes y revisión del crudo antes de integrar.

Orden de merge: #387→#389→#390→#391→#392→#394→[#395](https://github.com/federicohermo/nosefia/pull/395). #388 es independiente. Antes de borrar cada base, repuntar el siguiente PR a staging. No se mergeó ningún PR remoto.

No hay escenas que rehacer manualmente. Se modificaron `src/escenas/puestos/estructura_del_almacen.tscn`, `interfaz_del_almacen.tscn` y `objetos_del_almacen.tscn`, y `src/ui/diegetica/pantalla_de_computadora.tscn`; se retiró `src/ui/diegetica/app_chats.tscn`; se añadieron `src/ui/diegetica/pantalla_del_celular.tscn`, `src/ui/interrupciones/persiana_de_la_noche.tscn` y `pantalla_de_instrucciones.tscn`. Ninguna escena se resolvió mediante merge de tres vías.

Las siete capacidades afectadas quedan ratificadas: employment-record (28), investigation (31), player-actions (80), save-and-resume (23), shift-cycle (23), store-cleanup (49) y store-stock (54): 288 criterios citados. El repositorio completo conserva diez capacidades ratificadas y 372 criterios citados.

La convergencia integrada final pasó 7/7 nodos en 772,7 s sobre bf8cf0bfe703e606d949ca0bf6199ccdf9b899b5; tests 765,0 s. El conteo inmediato de reports/report_3 confirma 239/239 suites y 1823 casos, cero errores, fallos, flaky, skipped y huérfanos de gdUnit. La importación quedó sin ERROR/WARNING. El crudo del motor conserva exactamente los 60 diagnósticos de la tercera completa de #374, normalizando sólo sufijos numéricos de nodos y sin redondear coordenadas: ningún SCRIPT ERROR ni retención adicional; firma heredada 141 ObjectDB/100 recursos y PagedAllocator. El harness pasó 577 pruebas en 108,5 s con su único skip interno heredado.

Se publican separados los dos intentos integrados interrumpidos, sus logs parciales y sus incidentes. El primero se canceló al descubrir el fixture de carga incompatible con el fundido; el segundo, al identificar la nueva retención del fixture. Ninguno se cuenta como convergencia. La tercera completa de #374 y la integrada final se ejecutaron sobre sus cabezas congeladas, con todos los cambios finales y dentro de la cola compartida.

Los ocho PR propios están abiertos, listos para revisión y con CI verde: seis de implementación, contratos #387 y harness #388. La auditoría final exige 88/88 criterios de los seis issues, un PR por issue con Closes, cabezas locales/remotas/GitHub idénticas, bases apiladas correctas y ningún draft. Los once archivos canónicos de skills coinciden byte a byte con sus espejos .agents. La base remota staging conserva f695e897745490e8e8c15c33769c903cede89d70.

Limpieza final terminada con el script oficial y las cuatro rutas explícitas, sin --todos. Se retiraron batch-20261010-301, batch-20261010-364, batch-20261010-369 y batch-20261010-370. El wrapper comprobó que cada ruta pertenecía al repositorio principal, estaba limpia y registrada, y que el inventario posterior era exactamente el anterior menos esas cuatro rutas. Conservó el checkout principal, comber y lc, todos los otros worktrees registrados en ese momento. Cardinalfish ya no figuraba en el inventario inmediatamente anterior a la limpieza. Los agentes habían terminado y sus servidores propios estaban cerrados. No se tocaron servidores 8072/8073 ni procesos ajenos. El árbol de integración quedó limpio y pusheado.

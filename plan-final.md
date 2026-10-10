# El tacho grande del local queda al lado de la puerta de entrada

## Contexto

- **Objetivo:** colocar el tacho grande dentro del local, junto a la entrada, con sus centros AABB mundiales a 2 m o menos, preservando los demás muebles y el arte vigente.
- **Tipo:** `improvement`.
- **Spec:** ninguno; no cambia una regla ni se incorpora interacción.
- **Rama:** `improvement/301-tacho-junto-a-la-entrada`.
- **Diseño:** ficha [Mapa del local](https://app.notion.com/p/3e586efecd9d80ffa836de777f4884e5).
- **Depende de #305:** aterrizado en la base de implementación; la bolsa sólo cuenta por clic izquierdo sobre el contenedor del depósito completamente abierto.
- **Base explícita real del PR:** `cd5f93c38dfc140398759c52431bcece29985fd9`, cabeza validada de `feature/364-placa-noche-y-persiana` incorporada antes de la convergencia completa. Incluye los contratos resueltos del lote, #340, #305 y la entrada de #364. El diff propio y los comandos protegidos comparan contra esa cabeza, nunca contra staging móvil ni contra 48a5fa9.

La ficha distingue el tacho grande del local, los dos chicos y el contenedor del depósito. Se mueve la pieza vigente, sin añadir otra ni restaurar arte anterior. La medición del árbol de implementación confirma el rojo: centros a **2,604476 m**, aunque los orígenes estén a menos de 2 m.

La primera sonda leyó la cabeza 20ac5e21e2d52c5ac47b1b258c56a04448d7df9e; el diff 20ac5e21..e6a10983 en assets/ y src/ es vacío y el carril limpio avanzó con ff-only. Las sondas definitivas de base/candidato se midieron en 20ac: su aplicación a e6 se apoya en esa identidad comprobada de recursos. Las sondas finales se ejecutan sobre el arte aplicado en e6.

La fuente y las capturas se produjeron sobre e6. Después se incorporó #364, sin cambios en modelos, almacén geométrico, muebles ni horneado: el diff e6..cd5 de esas rutas es vacío. El cambio de #364 agrega la interfaz de entrada y su código; son herencia de la base, no cambios de este issue. La cabeza de convergencia es `eb8ac2b2a5fca71166a7ea4330667e43fd863fd2`.

### Mediciones sobre la base vigente y destino externo

Se conserva como procedencia histórica el rojo de `48a5fa9f7217997ebd215fce52943d4ec15443eb`: 2,604476 m entre centros. Esa cabeza ya no es la base de este PR. Se volvió a medir el GLB y la escena real de `e6a109833690c064c228cd04d9bc2d8c2ecf92c6`.

| Dato Godot XYZ | Base real | Destino medido antes de escribir fuente |
|---|---|---|
| Origen tacho grande | (7,272359; 0,503739; 5,249999) | (6,612360; 0,503739; 5,699999) |
| Centro AABB tacho | (7,279999; 0,503838; 5,249999) | (6,619999; 0,503838; 5,699999) |
| Bounds mínimos tacho | (6,910436; 0,102237; 4,876636) | (6,250436; 0,102237; 5,326635) |
| Bounds máximos tacho | (7,649563; 0,905439; 5,623363) | (6,989563; 0,905439; 6,073363) |
| Centro AABB entrada | (4,910000; 1,494000; 6,330000) | Igual |
| Distancia horizontal entre centros | **2,604476 m: ROJO** | **1,822360 m: VERDE** |
| Spawn del jugador | (5,710000; 0,112000; 5,300000) | Igual |
| Tacho chico 1, origen | (0,704194; 0,401514; 4,297547) | Igual |
| Tacho chico 2, origen | (9,144305; 0,401514; 5,456000) | Igual |

Se mueve el objeto Blender `tachitobasura-col` por **(-0,66; -0,45; 0) m** en Blender, equivalente a **(-0,66; 0; +0,45) m** en Godot. La propuesta se mide primero en `301-modelo-externo.blend` fuera de todo checkout/worktree. Su límite junto a fachada es Z=6,073363 frente al comienzo de la entrada Z=6,24; conserva el apoyo Y=0,102237. La comprobación física incluye los cuerpos importados y los overrides/ancestros de la escena real: no se infiere una cápsula libre sólo de esos bounds.

La sonda física aislada completó sus aserciones: cápsula inicial sin intersecciones; 3.696 celdas alcanzables con la cápsula real y cast_motion de 0,20 m, conservando los seis accesos de la base (puertas interiores/cabinas, ventanilla y mostrador). Cinco rayos bajo el tacho confirman apoyo en SueloSolido con separación de 0,000000209 m. La salida headless mostró además una firma de desmontaje de 24 ObjectDB/4 recursos, que se conserva y se identifica por separado antes de certificar la evidencia final; no se confunde ese diagnóstico con una aserción física fallida.

El rojo histórico no se usa para restaurar nada. Se retiraron las coordenadas del modelo viejo del 3 de octubre. El cambio conserva altura, giro, escala, malla, materiales y colisiones locales; sólo cambia XZ mundial del tacho grande.

## Criterios de aceptación

- [x] El tacho grande queda dentro del local, junto a la entrada: centros AABB mundiales `tachitobasura`/`puertaentrada` a ≤2,0 m. El destino externo medido se publica en este plan antes de escribir la fuente.
- [x] La cápsula real arranca libre y se conserva acceso a puertas interiores, ventanilla y mostrador. Se deriva la geometría de la escena final y se adjunta una captura desde el arranque.
- [x] Frente a la base explícita, se conserva el conjunto de nodos/mallas/materiales, altura, giro y escala. Sólo cambia la posición del tacho grande; los dos chicos y el contenedor del depósito, con su tapa y colisiones, quedan iguales.
- [x] El BLEND vigente se guarda en su lugar; `exportar_modelo.py` produce el GLB y su huella SHA-256. El acomodador conserva la nueva posición, probado únicamente en una copia externa.
- [x] `hornear.py` produce EXR/LMBake vigentes: no persiste la sombra anterior y el tacho nuevo recibe luz. Se adjuntan capturas comparables de ambas cabezas.
- [x] El diff contiene únicamente las salidas autorizadas de modelo y horneado. No cambian escenas, imágenes, mallas de productos, reglas, tests ni interacciones.
- [x] Una bolsa soltada sobre el tacho, cerca del contenedor o por su boca sigue recogible y sin contar; sólo el clic izquierdo con tapa completamente abierta la cuenta. Abrir con derecho no la deposita.
- [x] Se publica evidencia del rojo de base (histórico y remedido actual), del verde final y la procedencia de cada dato. `verificar.py` pasa siete nodos sin salteos, con conteo inmediato completo.

## Contrato

No hay firmas, señales ni datos nuevos. El tacho sigue siendo un mueble físico sin interacción. El mecanismo de contar bolsas pertenece al contenedor del depósito y a #305.

Los bounds estáticos salen de accessors POSITION y TRS jerárquico del GLB; la sonda de escena valida ancestros/overrides, cápsula, apoyo y circulación usando los cuerpos reales. Se comparan semánticamente mallas, materiales e imágenes; diferencias de serialización del exportador no se confunden con cambios artísticos. Se conservan origen y centro como medidas distintas.

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | `assets/models/SEPT_JUEGOS_PROTOTIPO.blend` sólo posición del tacho; `.glb` y `.glb.fuente` generados por `exportar_modelo.py`; `.glb.unwrap_cache` si la importación lo reescribe; `src/escenas/almacen.lmbake`, `src/escenas/almacen.exr` generados por `hornear.py`; `src/escenas/almacen.exr.import` sólo si cambian capas del atlas. Medidas, protocolo, logs y capturas fuera de fuente, publicados en la rama huérfana `capturas/301` con `capturas_a_rama.py`. |
| **Sólo lectura** | Pipeline `exportar_modelo.py`, `blender/exportar.py`, `blender/acomodar.py`, `hornear.py`; `almacen.tscn`, estructura/limpieza del almacén; suites existentes de apoyos, modelo integrado/exportado, objetos soltados, red de seguridad, alcance, iluminación, exterior, arranque y #305; `test_modelo_actualizado.py`; `docs/guides/iluminacion.md`. |
| **No se toca** | `src/` fuera de las salidas de horneado; `test/`, `specs/`, `project.godot`, `export_presets.cfg`; `.claude/`, `.agents/`, AGENTS, reglas y skills; `assets/` fuera de las salidas de modelo enumeradas. Todas las escenas, cajas, contenedor, productos e imágenes quedan intactos. |

## Verificación

1. Antes de aplicar, medir una copia externa del BLEND con Blender 5.2.1 y la propuesta con los cuerpos de la escena base. Publicar el destino en este issue.
2. Aplicar sólo el desplazamiento. Correr el acomodador sobre la copia externa y exigir posición preservada. Ejecutar los pipelines originales de exportación y horneado.
3. Comparar el diff propio de la cabeza final contra `cd5f93c38dfc140398759c52431bcece29985fd9` y los inventarios de arte contra `e6a109833690c064c228cd04d9bc2d8c2ecf92c6`: nodos/transformadas, mallas, materiales, imágenes, colisiones locales y huella del BLEND. Recalcular bounds y centros en GLB y escena final.
4. Comprobar cápsula sin intersecciones al arrancar y trayectos hasta las puertas interiores, ventanilla y mostrador con consultas/cast_motion de la cápsula real. Confirmar apoyo del tacho sobre piso del local. Capturar arranque, tacho/entrada y posición anterior/nueva con luz real.
5. Ejercer las suites existentes enumeradas y el protocolo de bolsa soltada/recogida/clic abierto de #305, sin redefinir su gesto ni sumar interacción al tacho.
6. Commit y push; ejecutar `python .claude/scripts/verificar.py` dentro de la cola compartida, con GODOT_BIN del registro de usuario. Inmediatamente `python .claude/skills/implement-batch/scripts/conteo.py`; siete nodos verdes sin salteos y todas las suites ejecutadas. Conservar la salida cruda del motor aunque esté verde.
7. `git diff --name-only cd5f93c38dfc140398759c52431bcece29985fd9` debe ser subconjunto de «Se escribe». `git diff --exit-code cd5f93c38dfc140398759c52431bcece29985fd9 -- test specs src/escenas/almacen.tscn src/escenas/puestos/estructura_del_almacen.tscn src/escenas/puestos/objetos_del_almacen.tscn src/ui project.godot export_presets.cfg` devuelve 0.

## Bordes

- Se conserva el tacho dentro del local y apoyado sobre el piso.
- Un origen a menos de 2 m no reemplaza la distancia entre centros AABB.
- Jugador y manchas conservan su ubicación real; se verifica su acceso, no la geometría vieja.
- La entrada conserva la traba; sólo se abren puertas interiores para medir circulación.
- Soltar sobre tacho, cerca del contenedor o por su boca no cuenta. Se recupera la bolsa y se usa clic izquierdo con tapa completamente abierta.
- El clic izquierdo con tapa cerrada/girando conserva lo sostenido; abrir con derecho no lo tira.
- El acomodador se prueba en copia externa, nunca sobre fuente para esta comprobación.
- Copias, scripts de evidencia y logs quedan fuera de los checkouts; motor/Blender/capturas respetan la cola del lote y el árbol se congela desde encolar hasta terminar.

## Resultado de implementación

Cabeza integrada y publicada: `eb8ac2b2a5fca71166a7ea4330667e43fd863fd2`; cambio de arte `abb895d82155a4e2017bf8be682a9925dcf6e377`. El diff propio contra cd5 contiene exactamente BLEND, GLB, huella, EXR y LMBake; el diff protegido es vacío y el árbol termina limpio.

Primera convergencia formal: **7/7 nodos verdes sin salteos, 738,3 s**. Conteo inmediato: **228/228 suites, 1.750/1.750 casos**, cero errores/fallos/flaky/skipped/orphans de las suites Godot. El harness termina OK con su única omisión interna heredada; no se saltea ningún nodo de verificar.py. El pipeline de producto pasó a la primera. Las sondas iniciales invalidadas y sus correcciones se conservan aparte y no se presentan como pruebas verdes.

Se conservan godot.log y todos los stdout/stderr crudos incluso en verde. Las 58 líneas ERROR/WARNING de la convergencia son idénticas, en orden, a la base validada #364: negativos deliberados de cableado, firma 141 ObjectDB/100 recursos y PagedAllocator. El verbose del protocolo de bolsas identifica su firma separada 29/6 como recursos de audio/playback; esos assets no cambian. Los diagnósticos se publican y no se eliminan ni se declaran apagados sin recursos.

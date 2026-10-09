# Diagnóstico ObjectDB / StringNames / material, bases d610 y 02e

ROOT C: d61094cf6c80f9e425c08a089f8d3a9dc505b0b1. Sin modificaciones versionadas.
Godot: D:/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe.
Todas las sondas usan FIFO, --headless --verbose y stderr=STDOUT desde subprocess; PID, APPDATA y argumentos en JSON.

## Primer bundle (terminó 4 s)

| Caso | Exit | ObjectDB | StringNames | Detalle |
|---|---|---|---|---|
| motor mínimo / proyecto externo vacío | 0 | 0 | 0 | SceneTree.quit() |
| mismo motor mínimo sobre ROOT C | 0 | 0 | 38 | Sin suite ni carga explícita de addon |
| gdUnit tarea_test | 0 | 0 | 38 | 1/1 suite y 6/6 casos, cero errores/salteos/huérfanos |
| carga directa de ClassDoubler | 0 | 0 | 38 | DOUBLER_CARGADO=true, sin mocks ni escena de juego |

Los 38 nombres Variant no prueban la causa de la instancia RefCounted0. Su lista se reproduce sin gdUnit ni ObjectDB.
Mini proyecto movido tras finalizar motores a C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/b-obj-proyecto-vacio; rutas originales permanecen en JSON como historia.

## Historia: bundles inicialmente encolados

- b-obj-runtime: carga_en_segundo_plano_test, indicacion_del_foco_test y calentamiento_de_shaders_test, separados por proceso. Reports res://reports/b-obj-<caso>.
- b-obj-failed: ResourceLoader.load_threaded_request de ruta inexistente, espera estado FAILED, compara no retirar vs load_threaded_get aun FAILED. Imprime estado antes/después y espera cuatro process_frames antes de salir.

## Historia: hipótesis inicial anterior a las comparaciones

CargaEnSegundoPlano._process sólo llama load_threaded_get con LOADED. FAILED borra _ruta mediante _terminar; el comentario del productor dice que el motor conserva cada pedido hasta retirarlo. El caso funcional ruta inexistente puede dejar pendiente su pedido, distinto de una fuga de mocks. El código propio no usa p_use_sub_threads=true.

Fuentes primarias exploradas: https://github.com/godotengine/godot/issues/120661 y https://github.com/godotengine/godot/pull/121025 describen LoadToken RefCounted0 con subthreads true en 4.7, que no equivale a demostrar este origen. La comparación local decide antes de atribuirlo al motor.

## Bundles terminados posteriores

Runtime (13 s):
- carga_en_segundo_plano_test: 1/1, 7/7; 13 RefCounted reference0 al salir en proceso frío, sin recursos retenidos ni material null.
- indicacion_del_foco_test: 1/1, 3/3; 0 ObjectDB, 0 material null.
- calentamiento_de_shaders_test: 1/1, 19/19; 0 ObjectDB, 0 material null.

FAILED nativo (1 s):
- REQUEST=0, espera ESTADO_FINAL=2 (FAILED), sin get deja ESTADO_DESPUES=2 y una instancia RefCounted reference0.
- Mismo script/proyecto y cuatro frames, con get incluso FAILED devuelve null y ESTADO_DESPUES=0 (INVALID_RESOURCE); cero ObjectDB.
- Prueba causal de pedido FAILED no retirado. El coordinador autorizó corregir productor/mirror en bugfix independiente; no se atribuye a mocks ni engine. En aquel corte doce instancias frías adicionales aún no estaban clasificadas; la comparación fría válida posterior se detalla abajo.

Material (19 s):
- Mínimo fuera proyecto/addon, MeshInstance3D+BoxMesh sin material: free directo y remove_child/free, ambos cero material null/ObjectDB; control con material también cero.
- Focales individuales examen_con_efectos2, grupo_del_piso8, campo_de_interaccion4, contorno_del_util4, sombreado_de_liquidos4, aristas_del_producto3: todos casos verdes, cero material null/ObjectDB.
- No clasifica aún los24 globales. Una malla sin material explícito es montaje válido por material default, no motivo para asignar materiales a ciegas.

Pendiente b-obj-valid: comparación síncrona/async/get y consumidor/free, más caso free existente aislado por -i otros seis (exclusiones diagnósticas explícitas, no prueba suite completa). CLI local GdUnitTestCIRunner no expone -tc, sí -i suite:caso.
Pendiente b-obj-native-material: geometría nativa Label3D/TextMesh/ShaderMaterial vacío/material duplicado y BoxMesh control, con -d del comando verificar. Sondas previas no incluyeron -d; es otra variable a descartar.

Hasta ese corte no hubo cambios tracked ni de addons. Los cortes posteriores y la excepción documental se detallan a continuación.

## Comparación fría y retiro correcto de cargas válidas (terminada)

`b-obj-valid-resultados.json` conserva PID, APPDATA, argumentos y logs fusionados. `b-obj-hashes.json` conserva SHA256 de los scripts y productor medido.

| Caso | Estado después de get | RefCounted reference0 |
|---|---|---:|
| load síncrono de pantalla_de_cierre | no aplica | 0 |
| request/get nativo frío de pantalla_de_cierre | INVALID_RESOURCE=0 | 10 |
| request/get bloqueante de pantalla_de_pausa | INVALID_RESOURCE=0 | 0 |
| productor real cargando cierre, lista1 y free | INVALID_RESOURCE=0 | 8 |
| productor real free mientras carga pausa | INVALID_RESOURCE=0 | 0 |
| caso existente de free, aislado con -i otros seis | 1/1 caso verde | 0 |

La carga fría válida puede dejar instancias con reference0 pese a retirar correctamente el pedido. Se reprodujo con API nativa y sin GdUnit/productor. El número depende de qué recursos llegaron fríos al hilo. No equivale a identificar la misma causa interna de un issue upstream con subthreads=true; no justifica cambiar la API ni hacer fallback síncrono. La fuga FAILED propia demostrada por comparación previa sigue separada y el coordinador la corrige.

## Geometría nativa y grupos terminados

Sondas de BoxMesh, Label3D, TextMesh, ShaderMaterial vacío y material_override duplicado: todos cero material null/ObjectDB. Incluyen -d/remote-debug del verificar; el control remoto inválido produce dos errores basales explícitos de conexión.

Grupos `b-obj-grupos-resultados.json`:
- sistemas: 24/24 suites y 252/252 casos, cero material null, 14 RefCounted fríos.
- ui: 6/6 suites y 43/43 casos, cero material null/ObjectDB.
- objetos: 29/29 suites y 170/170 casos, cinco material null, cero ObjectDB. Excluye explícitamente caja_que_se_lleva_test, balde_que_se_apoya_test y producto_soltado_test; sólo aislamiento diagnóstico.
- Los cinco errores de objetos ocurren en AfterStage/free de caja_de_productos_test: tamaño, textura por producto, genérica, filtrado y no estiramiento.

Excepción histórica de congelación: el coordinador había aplicado ocho Markdown DNI13→DPI14 antes de recibir aviso del enqueue de grupos. Ningún GD, escena, test ni runtime cambió y HEAD era d610. Estos grupos diagnostican el runtime d610, pero no acreditan árbol entero congelado. Posteriormente se confirmó HEAD02e3562c1acb9dc4c768c9b33da2155b69792fdf libre y limpio para el siguiente bundle. El diff d610→02e de src/test/addons está vacío.

## Surface override: reproducción causal fuera del juego y addon

Bundle FIFO `b-obj-surface-bundle.log`, 6 s, código0. HEAD02e confirmado antes/después, sin cambios tracked. `b-obj-surface-resultados.json` conserva comando/PID/APPDATA/exit/duración. Los archivos `b-obj-surface.gd` y `b-obj-surface.py` son externos; el proyecto vacío está en Temp.

| Caso | material null | ObjectDB |
|---|---:|---:|
| caja_de_productos_test focal completo, 15/15 casos verdes | 5 | 0 |
| CAJA real, dos productos, free inmediato | 1 | 0 |
| CAJA real, cuatro process_frames antes de free | 1 | 0 |
| CAJA real, set_surface_override_material(0,null) antes de free | 0 | 0 |
| Proyecto vacío: BoxMesh compartido, dos MeshInstance3D, material de superficie duplicado, free | 1 | 0 |
| Mismo BoxMesh, cuatro process_frames antes de free | 1 | 0 |
| Proyecto vacío: ArrayMesh equivalente + material de superficie duplicado, free | 1 | 0 |
| Mismo ArrayMesh, cuatro process_frames antes de free | 1 | 0 |
| ArrayMesh, set_surface_override_material(0,null) antes de free | 0 | 0 |

El montaje nativo usa sólo StandardMaterial3D, BoxMesh/ArrayMesh y MeshInstance3D; no hay addon, assets ni código del juego. El stack fusionado señala `_probar` línea43, `nodo.free()`, seguido de `material_get_instance_shader_parameters (servers/rendering/dummy/storage/material_storage.cpp:264)`. Cada proceso lleva sólo dos errores de conexión basales más el material null cuando corresponde. No hubo recursos retenidos.

La diferencia respecto de las primeras sondas es `set_surface_override_material`, no `material_override`. La API documenta el material asociado a la instancia. La reproducción permite clasificar este mensaje como dependencia del renderer dummy al destruir un montaje válido; no demuestra todavía dónde están los otros19 mensajes del full. El control clear demuestra el punto de interacción, no autoriza aplicar ese workaround a producción/tests.

Fuentes primarias:
- https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html#class-meshinstance3d-method-set-surface-override-material
- https://raw.githubusercontent.com/godotengine/godot/4.7/scene/3d/mesh_instance_3d.cpp (set_surface_override_material, líneas349–357)
- https://raw.githubusercontent.com/godotengine/godot/4.7/servers/rendering/dummy/storage/material_storage.cpp (material_get_instance_shader_parameters, líneas262–266)

ROOT C fue liberado al coordinador inmediatamente después del bundle. Pendiente: ubicar los19 restantes mediante focales fusionados; ninguna atribución por cercanía en raw de stdout/stderr concatenados.


## Caja que se lleva: focal completa terminada

FIFO esperó575s detrás de e-fixtures-full2, luego proceso72.06s (suite68.711s), 1/1suite20/20casos verdes y código0. HEAD02e antes/después y diff tracked final vacío; ROOT liberado inmediatamente. Raw fusionado: b-obj-caja-llevada.log; metadata: b-obj-caja-llevada-resultados.json; XML preservado: b-obj-caja-llevada-results.xml. Sin ScriptError, objetos ni recursos retenidos; dos errores basales de conexión remota explícitos.

Doce material null, todos con free_instance/GdUnitTools85→gc126 en el caso activo entre STARTED y PASSED. Matriz exacta de casos, líneas y stack en b-obj-material-proof.json. El número es12, no19. Junto con cinco de caja_de_productos localiza17; siete restantes aún sin origen concreto. La suma de focales separados no se vende como equivalencia temporal exacta de stderr concatenado del full.

Siguiente propuesta enviada al coordinador, pendiente confirmación ROOT libre antes de encolar: balde_que_se_apoya_test7casos20.770s y producto_soltado_test2casos10.078s, únicos dos excluidos restantes del grupoobjetos. No hubo workaround ni modificación de fuente/tests/addon/escenas/arte.

## Descartes restantes de objetos y siguiente grupo

Bundle b-obj-resto-bundle.log esperó27s detrás de a-304-verde-ampliado, terminó38s código0. ROOT02e sin diff tracked y liberado al coordinador. Balde7/7 (suite21.107s/proceso24.41s) y producto2/2 (suite10.171s/proceso13.42s), ambos cero material null/ObjectDB/recursos/ScriptError. Dos errores basales de conexión por proceso. XML preservados b-obj-resto-balde-results.xml y b-obj-resto-producto-results.xml; perfiles/PID/args en b-obj-resto-resultados.json.

Los siete pendientes no aparecen en los dos excluidos restantes de objetos. El coordinador confirmó ROOT02e libre y freeze completo para grupo39suites294casos,57.726s estimados. Encolado b-obj-escenas: -a test/escenas, excluye32suitesobjetos ya medidas y seis pesadas (lo_soltado_fuera_de_los_solidos, agarre_fisico, reposicion_manual, hoja_que_arrastra, giro_parejo, contenedor_de_basura). Lista exacta b-obj-escenas-plan.json. Espera FIFO detrás de a-304-full-primera. Sólo diagnóstico, no reemplaza verificación integral ni descarta las seis suites excluidas.

## Grupo39 terminado y corte final del diagnostico B

Esperó687s detrás de a-304-full-primera; proceso71.13s, suite63.716s, 39/39suites294/294casos verdes, código0. ROOT02e antes/después y diff tracked vacío. ROOT liberado inmediatamente. Log fusionado b-obj-escenas.log; metadata b-obj-escenas-resultados.json; XML preservado b-obj-escenas-results.xml.

Dos avisos materialNULL adicionales, siempre GC/free85 dentro del caso activo:
- raw4048: casilleros_a_la_vista_test / test_ningun_casillero_vacio_se_dibuja_sin_la_mira_encima.
- raw5451: contorno_de_los_muebles_test / test_una_caja_chica_soltada_hacia_una_bandeja_no_queda_adentro_de_la_gondola.

Matriz final B: etiquetas5 + caja_llevada12 + escenas2 =19localizados; cinco pendientes en seis suites pesadas excluidas. Cero ObjectDB/recursos/ScriptError. El raw no está limpio: conserva dos outsideTree,98sin_volumen y guardDisposition conocidos de la base ROOT; C corrige las fixtures por separado.

El coordinador decidió no correr ahora las seis pesadas: RED3/GREEN45 y FULL3completo191 de C serán contraste determinante. Si FULL3elimina globalmente materialNULL/ObjectDB/recursos, eso verifica la eliminación global tras el fix; NO asigna a casos los cinco focos que B no observó. No habrá otras sondas Godot de B salvo nueva necesidad demostrada. B queda sólo preparación externa305-308 hasta309certificado.

Ningún archivo tracked cambió durante este diagnóstico B. Todos los proyectos temporales quedan fuera de checkout; scripts/logs/JSON externos conservados. La excepción histórica de los ocho MD durante grupo45s está documentada, no se disimula como freeze completo.

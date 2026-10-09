# Brief completo: calentamiento y fixtures válidos

Tipo: bugfix independiente, autorizado por el padre en este lote. Sin issue nuevo ni cambio de spec.
Base explícita: `d61094cf6c80f9e425c08a089f8d3a9dc505b0b1`; diagnóstico capturado en `69ee390a75f4ff2016c9a0aebceb4fb6f5981b06`.
Única diferencia entre esas bases: oración de documentación y espejo AGENTS; fuente de estos siete archivos idéntica.
Rama: `bugfix/64-309-calentamiento-y-fixtures-validos`.
Worktree reutilizado limpio: `D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-64-309-export`.
PR contra `harness/64-309-actualizar-el-preflight`, preservando PR345 y su rama remota.

El XML de la corrida completa dio 191/191 suites y 1496/1496 casos sin fallos, pero su stderr conserva errores.
Una escena vacía válida llega a `_encuadrar` y asigna `Camera3D.size=0`. El contrato existente exige que termine igual.
Otros errores provienen de fixtures que consultan transforms globales sin montar nodos o de metadata ausente.
El fix conserva las aserciones del comportamiento y hace verificables los diagnósticos deliberados.

## Alcance cerrado y conteo medido de métodos públicos

| Archivo autorizado | Públicos de raíz, incluidos hooks | Casos |
|---|---:|---:|
| `src/sistemas/marco/calentamiento_de_shaders.gd` | 2 | 0 |
| `test/sistemas/marco/calentamiento_de_shaders_test.gd` | 19 | 19 |
| `test/escenas/volumen_de_los_solidos_test.gd` | 5 | 5 |
| `test/escenas/indicacion_del_foco_test.gd` | 3 | 3 |
| `test/escenas/objetos/mancha_en_el_piso_test.gd` | 11 | 11 |
| `test/sistemas/investigacion/examen_test.gd` | 20 | 20 |
| `test/sistemas/tareas/ventanilla_test.gd` | 15 | 14 |

No se agregan métodos públicos ni suites. El caso vacío existente se refuerza para dar rojo por aserción antes del fix.
No se escriben escenas, specs, assets, addons, project.godot, herramientas o SKILL.md.
Los 24 errores de material en GC y la fuga ObjectDB quedan pendientes del aislamiento verbose del padre.
No hay parche material por conjetura ni eliminación de diagnósticos del motor.

## Criterios concretos

- F1: una escena vacía termina, deja progreso completo y no emite error. `test_una_escena_sin_objetos_termina_igual`.
  Rojo primero con `await assert_error(func(): calentamiento.calentar(escena)).is_success()` antes de modificar producción.
- F2: el fixture MultiMesh dibuja una instancia real por material; se preserva el recuento tras dos avances.
  `test_el_material_de_un_multimesh_cuenta_como_nuevo`, añadiendo formato 3D y una instancia identidad.
- F3: metadata ausente sigue sin eximir; la exención vacía tampoco exime y la razón escrita sí.
  Los cinco casos de `volumen_de_los_solidos_test.gd` conservan sus resultados con default String vacía.
- F4: el doble de jugador de la prueba de señales usa la escena y sus hijos reales montados antes del transform global.
  Se conservan señal enfocada/perdida, HUD y material_overlay; se afirma que está montado.
- F5: el ciclo limpia/sucia de la mancha se ejerce montada; visibilidad y colisión conservan sus cuatro aserciones.
- F6: falta de cableado de Examen emite exactamente su push_error esperado, sin revelar ni iniciar examen.
- F7: los cuatro métodos de Ventanilla sin cablear emiten cada uno su push_error esperado, sin señales ni atención.
- F8: verificar.py completo 7/7 sin salteos y conteo.py inmediatamente; conservar raw del motor y revisar callbacks/GC.
  Ningún reporte verde por XML0 si el raw contiene errores no explicados.

## Reglas aplicadas

AGENTS raíz → CLAUDE.md; `.claude/rules/gdscript.md`; `src/sistemas/AGENTS.md`;
`test/AGENTS.md`; `test/sistemas/AGENTS.md`; `src/escenas/AGENTS.md`/presentacion como contexto readonly.
Skills implement-feature y diagnóstico leídas. El padre mantiene las correcciones al lazo y SKILL.md.
Índice MCP consultado, pero indexa el principal: los conteos arriba provienen de Git en la base explícita.
No nuevas reglas del juego: la cámara adapta el dibujo, y los demás cambios arreglan premisas/diagnósticos de tests.

## Verificación serial y evidencia

Toda importación/ejecución Godot pasa por turno.py y la cola absoluta del preámbulo.
Cada llamada inyecta GODOT_BIN y Scripts de Python; focales APPDATA aislado en `.godot/usuario_de_los_tests`.
Rojo y verde usan `-rd res://reports/fix-fixtures`; la salida raw y códigos se conservan fuera del worktree.
El rojo debe fallar F1 por `p_size`, sin fallo de parseo. Luego producción sólo evita escribir un size inválido
y preserva el resto del calentamiento/restauración/terminado. Suites focales de estos seis archivos después.
Commit y push antes de FULL; FULL mediante wrapper externo `padre-verificar-con-log.py`, que conserva stdout/stderr
del nodo tests en verde. Luego conteo inmediato y PR con criterios/resultados reales y límites pendientes.
Los diagnósticos remotos deliberados y assert_error se distinguen por causa. Sin motor paralelo ni editor ajeno detenido.

## Dependencias y coordinación

Esta rama parte de HARN, independiente de los cambios jugables de A/B. La futura entrega309 espera A304 certificado.
Si llega A304 mientras corre este fix, coordinar carril y preservar ambos worktrees; no adelantarse sobre almacen.tscn.
Las copias de fuente sólo quedan en este directorio externo Temp como archivos de texto para revisión.


## Revisión autorizada tras prueba FAILED: alcance final nueve .gd

El padre autorizó estas dos rutas adicionales después de comparar el mismo request externo,
sin addon ni código de juego. Sin load_threaded_get: estadoFAILED2 y una fugaRefCounted0.
Con get aun FAILED: devuelve null, estadoINVALID0 y ninguna fugaObjectDB. Ambos exit0.
La señal fallo no demuestra retiro del pedido; _terminar borraba la ruta antes de retirarlo.

| Ruta añadida | Públicos medidos | Casos |
|---|---:|---:|
| `src/sistemas/marco/carga_en_segundo_plano.gd` | 2 | 0 |
| `test/sistemas/marco/carga_en_segundo_plano_test.gd` | 7 | 7 |

Fuente adicional leída íntegra; aplican src/sistemas/AGENTS.md y test/sistemas/AGENTS.md,
tests.md y gdscript.md ya leídos. Consumidor real único: src/escenas/menu_de_inicio.gd,
que conecta lista/fallo, pide al aparecer y vuelve a pedir tras error. Test de consumidor:
test/escenas/carga_del_almacen_test.gd (se lee, no se edita). Referencias locales/src/test/docs
medidas con git grep e índiceMCP; ningún documento de arquitectura decide otra semántica.
El comentario de _notification ya requiere retirar los pedidos del motor para no dejarlos activos.
Sin cambios de UI, señal, firma, cache, spec, asset ni addon. No atajo ResourceLoader.exists.

- F9: geometría válida pequeña conserva el ancho exacto del encuadre. Se refuerza el caso existente
  de material reemplazado con ejeX mayor explícito; rojo contra clamp1, luego setter sólo ancho válido.
- F10: después de fallo emitido, el pedido ha sido retirado (ResourceLoader devuelve INVALID).
  Rojo reforzando test_una_ruta_que_no_existe_emite_fallo_una_sola_vez antes de producción.
  Conservar fallo1/listas0, progreso previo, reintentos y todos los demás casos existentes.
  _process retira LOADED y FAILED antes de _terminar; INVALID no llama get y request!=OK conserva su guard.
- F11: tras los verdes focales, repetir giro_parejo_test en FIFO con contexto readonly externo
  CPU/memoria/usuarioaislado. No modificar esa suite ni su umbral para adaptar el resultado.
  FULL2 final sólo después de diagnóstico de los12Objetos adicionales en el loader frío por B.

FULL1 histórico terminó6/7 en695.3s: nodo tests con191/191suites,1496casos,1failure/0errors,
único FAILED giro_parejo_test.test_una_caja_contra_la_pared_se_corre_sin_escalones:
un cuadro quieto entre vecinos que se mueven, de102. CopiaXML y raw preservados. No se afirma verde.
Ese archivo no forma parte de las nueve rutas autorizadas y no se toca a ciegas.
Red inicial del vacío y verdes72casos quedan como historia; fuente final requerirá su propio FULL/conteo/raw.
Los24materiales de GC aún no se atribuyen y no reciben parche; el padre/B siguen aislándolos.

## Ampliación propuesta v3: lifecycle de material (pendiente autorización exacta)

FULL2 de nueve GD terminó 7/7, 694.5 s, con conteo inmediato 191/191, 1496 casos y
cero fallos/errores/skips. El raw no tiene ObjectDB/resources y conserva 24 materialNULL.
Se archiva completo; no se reemplaza por una eventual corrida de once GD.

B reprodujo materialNULL fuera de juego y addon: MeshInstance3D con malla compartida y
material duplicado como override de superficie, al liberar. La caja real también reproduce.
Limpiar ese override antes de free elimina el error. Sus focales atribuyen 5 a caja_de_productos
y 12 a caja_que_se_lleva; quedan 7 por atribuir. No se afirma que los 24 tengan esa causa aún.

La sonda externa autorizada compara fuente original y subclase PREDELETE: ambas pasan
16 comprobaciones de etiqueta/material propio, malla compartida, reparent, producto/datos,
material genérico intacto antes/después de free. Original da exactamente un materialNULL;
PREDELETE da cero errores. Ambas cero fugas/recursos. Las copias guardadas para comparar
identidad se liberan antes de free, para no alterar el ciclo de vida medido.

| Ruta propuesta | Públicos antes/después | Casos antes/después |
|---|---:|---:|
| `src/escenas/objetos/caja_de_productos.gd` | 7/7 | 0/0 |
| `test/escenas/objetos/caja_de_productos_test.gd` | 15/15 | 15/15 |

Se leyeron ambas fuentes completas, src/escenas/AGENTS.md y presentación; aplican también
test/AGENTS.md, tests.md y gdscript.md ya leídos. Consumidores de juego: almacen.gd y
puestos/reposicion_manual.gd. La caja no declara class_name y el hook es privado.
Ninguna escena, spec, asset, import, addon, skill ni firma pública entra al alcance.

F12: cambiar una caja rotulada de padre conserva identidad de material, textura, producto y
datos; la malla/material genérico compartidos no se modifican. Limpiar sólo en PREDELETE,
nunca _exit_tree, para conservar las etiquetas al agarrar/devolver y durante reparent.

F13: destruir dos cajas con la misma malla y materiales propios instalados no produce error
del motor. Sustituir el antitest lexical anti-if/match por este caso funcional de reparent/free,
sin ocultar el cambio. RED debe fallar por materialNULL durante free real, sin ParseError;
GREEN debe conservar todas las premisas y eliminarlo. Quince casos/públicos permanecen.
El veto lexical no demuestra políticas de cupos: éstas permanecen en dominio y sus lectores,
y no se modifica ninguna decisión de stock, clic, producto o cupo. No se rodea el veto.

F14: liberar una caja que nunca entró al árbol también queda sin error; get_node_or_null
protege el lifecycle sin asumir _ready. El guard sólo toca override de superficie 0 de Malla,
sin borrar la malla fuente ni su material genérico.

Tras autorización exacta y clasificación B restante, escribir test primero, RED en FIFO,
parche mínimo, GREEN de caja_de_productos y caja_que_se_lleva completos, más consumidores
de reposición identificados. Commit/push antes de FULL3 nuevo head, conteo inmediato y
revisión raw. No emitir PR final ni declarar listo con material inesperado sin clasificar.

Autorización posterior del padre: aplicar ahora exactamente estas dos rutas adicionales,
test primero/RED válido, PREDELETE mínimo y GREEN. La causal externa 1→0 y los diecisiete
errores atribuidos bastan para corregir lo demostrado. Los focales balde7 y producto2 dieron
cero material; los siete restantes siguen bajo aislamiento readonly de B, sin afirmar misma
causa. No correr FULL3 final ni emitir PR final hasta clasificar esos siete o demostrar raw
completo cero material y contrastar la matriz. No ampliar más allá de once GD sin nueva prueba.


## Revision v4: RED GdUnit observado y alcance autorizado

El padre autorizo exactamente once GD. RED3 parse invalido, RED3b/c/d/e verdes inesperados se conservan como historia; ninguno se cuenta como rojo.
RED3f conserva todas las aserciones del caso de tamano y toma ownership explicito de sus dos cajas validas: detach/free dentro de assert_error.is_success, sin auto_free duplicado. Quince casos, un fallo, exit100: XML falla en test_la_caja_tiene_el_tamano_que_le_da_el_catalogo:113 por Parameter material is null. Raw b-e-red3f-suite.log; snapshot b-e-red3f-source.gd.
F13 queda cubierto por ese teardown funcional del caso existente. El caso nuevo que reemplaza el veto lexical cubre F12/F14 (reparent, identidades, texturas y recursos compartidos intactos), verde antes del parche; no se afirma rojo para ese caso.
Solo despues de ese rojo se aplica PREDELETE minimo a fuente actual: quitar override0 de Malla al destruir, nunca al salir del arbol. Publicos caja7/7; espejo15/15. Se mantienen nueve GD de55af sin editar.
Matriz readonly B: diecinueve material localizados y cinco pendientes, no diecisiete/siete; no se inventan atribuciones para los cinco. FULL3raw cero sera evidencia de eliminacion global.

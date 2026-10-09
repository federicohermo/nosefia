# Lote implementado y verificado

Los 15 issues tienen un PR propio y CI verde. El trabajo se repartió en cuatro carriles, padre, A, B y C. No se encontraron dependencias declaradas falsas.

|Issue|Carril|PR|Criterios entregados|Verificación completa|Salteos|Suites/casos|CI actual|
|---|---|---|---|---|---:|---|---|
|#64|padre|[#344](https://github.com/federicohermo/nosefia/pull/344)|AC-CTR-014, AC-INV-019|primera:7/7|0|193/193;1512/1512|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37879247621)|
|#294|A|[#346](https://github.com/federicohermo/nosefia/pull/346)|AC-PLY-054, AC-PLY-055, AC-PLY-056, AC-PLY-057, AC-INV-020, AC-STK-042|segunda:7/7|0|190/190;1497/1497|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37877255809)|
|#295|B|[#342](https://github.com/federicohermo/nosefia/pull/342)|AC-EMP-004, AC-EMP-005, AC-EMP-008|primera:7/7|0|190/190;1493/1493|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37879250921)|
|#327|C|[#343](https://github.com/federicohermo/nosefia/pull/343)|Medición/apariencia, sin spec|segunda_final:7/7|0|190/190;1494/1494|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37873718802)|
|#297|A|[#348](https://github.com/federicohermo/nosefia/pull/348)|AC-PLY-058, AC-PLY-059, AC-PLY-060, AC-PLY-061, AC-PLY-062|primera:7/7|0|191/191;1509/1509|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37880205365)|
|#298|A|[#349](https://github.com/federicohermo/nosefia/pull/349)|AC-PLY-063, AC-PLY-064, AC-PLY-065, AC-PLY-066, AC-PLY-067, AC-PLY-068, AC-PLY-069, AC-PLY-070, AC-PLY-071|primera:7/7|0|198/198;1555/1555|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37883085495)|
|#302|A|[#350](https://github.com/federicohermo/nosefia/pull/350)|AC-CTR-013, AC-CTR-021, AC-CTR-022, AC-CTR-023, AC-CTR-024, AC-CTR-025, AC-PLY-072, AC-PLY-073, AC-PLY-074, AC-PLY-075, AC-PLY-076, AC-PLY-077|cuarta:7/7|0|204/204;1587/1587|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37891492751)|
|#300|B|[#347](https://github.com/federicohermo/nosefia/pull/347)|AC-STK-024, AC-STK-025, AC-STK-026, AC-STK-052|primera:7/7|0|190/190;1498/1498|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37879254500)|
|#303|A|[#351](https://github.com/federicohermo/nosefia/pull/351)|AC-CTR-026, AC-CTR-027, AC-CTR-028, AC-CTR-029, AC-CTR-030|primera:7/7|0|204/204;1602/1602|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37897616307)|
|#304|A|[#352](https://github.com/federicohermo/nosefia/pull/352)|AC-CTR-031, AC-CTR-032, AC-CTR-033, AC-PLY-014, AC-PLY-078|primera:7/7|0|204/204;1610/1610|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37901211855)|
|#305|B|[#355](https://github.com/federicohermo/nosefia/pull/355)|AC-CLN-008, AC-CLN-009, AC-CLN-011, AC-CLN-034, AC-CLN-035, AC-CLN-036, AC-CLN-037, AC-CLN-038, AC-CLN-039, AC-STK-053, AC-PLY-043|segunda_final:7/7|0|208/208;1629/1629|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37913997909)|
|#306|B|[#356](https://github.com/federicohermo/nosefia/pull/356)|AC-EMP-017, AC-EMP-018, AC-EMP-019, AC-EMP-020, AC-EMP-021, AC-EMP-022, AC-CLN-040, AC-CLN-041, AC-CLN-042, AC-CLN-043, AC-CLN-044, AC-CLN-045, AC-CLN-046|cuarta:7/7|0|214/214;1670/1670|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37933502848)|
|#307|B|[#357](https://github.com/federicohermo/nosefia/pull/357)|AC-CLN-047, AC-CLN-048, AC-CLN-049|segunda:7/7|0|215/215;1678/1678|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37933723842)|
|#308|B|[#358](https://github.com/federicohermo/nosefia/pull/358)|AC-CLN-050, AC-CLN-051, AC-CLN-052|primera:7/7|0|216/216;1685/1685|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37936951211)|
|#309|C|[#354](https://github.com/federicohermo/nosefia/pull/354)|AC-NTF-001, AC-NTF-002, AC-NTF-003, AC-NTF-004, AC-NTF-005, AC-NTF-006, AC-NTF-007, AC-NTF-008, AC-NTF-009, AC-NTF-010|primera:7/7|0|207/207;1632/1632|[SUCCESS](https://github.com/federicohermo/nosefia/actions/runs/37906851144)|

#306 conserva sus dos primeras convergencias fallidas y sus logs/XML. La tercera pasó localmente, pero su CI falló porque no pudo montar el apilado de veintiocho cuerpos. Por indicación del usuario se retiró ese estrés redundante y sus ayudantes; las pruebas funcionales de bloqueo de tapa y descarte siguen vigentes. La cuarta convergencia corresponde a esa corrección. El ordinal de la tabla conserva todas las corridas.

En #307, la corrida local precede al rebase que hereda únicamente esa retirada de prueba. Los tres commits propios se conservaron idénticos por range-diff. Su PR distingue la cabeza nativa, con un caso más, de la CI de la cabeza actual.

Integración VERIFICADA en `48a5fa9f7217997ebd215fce52943d4ec15443eb`:7/7 en 755.0s, 217/217 suites y 1687 casos; cero fallos, errores, salteos e inestables. Conteo inmediato exit0. XML `50f159c63015420369b741695c67f5858c796cc0533211cf689bd29beb40a836`.

## Checker y decisiones

Se repitió el preflight tras el nuevo staging f17948fe y se reescribieron cuerpos completos antes de implementar: computadora con shader; notas y contenedor artísticos existentes; encuadre sobre bordes visibles a distinta profundidad. Se conservaron arte/bake y se revisaron lectores/contratos retirados.

#294 invierte el gesto manteniendo usar compartido; #297 separa hueco físico de bordes visibles; #298 reutiliza notas y hojas artísticas existentes; #302 conserva Venta y Comprador.pedido y añade Ticket físico nuevo; #303 conserva casilleros manuales vacíos y prueba popup real; #304 preserva mopa/balde y ambos inodoros; #305 tira con LEFT y abre tapa con RIGHT, según el usuario. #295 conserva la deuda oculta;306–308 se consumen con sus contratos y guardado vigentes, sin reglas de riesgo retiradas.

- checker_304: AC-PLY-014 completa mopa/inodoro (CLN029 vigente) y ticket/inodoro; ambos fixtures reales citan014, conserva otros pares/gesto. Wholebody antesSPEC/fuente.
- checker_externo_parcial: {'estado': 'PUBLICADO_PARCIAL', 'issues': [296, 219], 'proofs': ['C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/c-whole-296-219/296-whole-preparado.publicar.proof.json', 'C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/c-whole-296-219/219-whole-preparado-v2.publicar.proof.json']}
- checker_externo_final: PUBLICADO
- checker_externo_proof: D:\temporales\nosefia-batch-64-309\outside-final\index.json
- [#296](https://github.com/federicohermo/nosefia/issues/296): cuerpo completo publicado y readback exacto; hash `2caa955e9253a89cb0d40ed7832cba196508f1a6b6dab4d6530390419bd3372b`, 2026-10-09T11:10:28Z.
- [#219](https://github.com/federicohermo/nosefia/issues/219): cuerpo completo publicado y readback exacto; hash `b0289f825e200af7c286525691521cfa95cbf62c2f81fa5111ec77450397dfdb`, 2026-10-09T11:10:28Z.
- [#299](https://github.com/federicohermo/nosefia/issues/299): cuerpo completo publicado y readback exacto; hash `8d61acff45302dfcc799fd399604f13a47fb8d43167231adbb8c23cfdc83f329`, 2026-10-09T13:17:45Z.
- [#301](https://github.com/federicohermo/nosefia/issues/301): cuerpo completo publicado y readback exacto; hash `8bf63cde4e541e907d2ff15739b9dde108940d5914501163fca3e1f0daad59dd`, 2026-10-09T13:17:49Z.
- [#218](https://github.com/federicohermo/nosefia/issues/218): cuerpo completo publicado y readback exacto; hash `2e34fc334b4dd72740a64a2dd81e27a1cf3523e396dc7077e17daaf4a6bb8d5d`, 2026-10-09T13:17:52Z.

Se actualizaron los planes de #299, #301 y #218 según los contratos finales del lote. #339 conserva su dependencia de toda la pila. #296 conserva el contrato de registrar y retira un conteo circunstancial de instanciaciones. #219 retira un localizador de línea y exige revalidar sus IDs al empezar to-spec. Los cuerpos publicados y su lectura posterior constan en los archivos de evidencia. Estos issues siguen abiertos para su implementación futura.

## Lazo y correcciones independientes

Lazo [#341](https://github.com/federicohermo/nosefia/pull/341) en `5ce72b8ac17c1a2a9c216947f7005f3bd8b82d29`, CI SUCCESS:16 lecciones y seis copias verificadas. La nativa histórica y la CI de la cabeza actual se distinguen en las entregas.

1. `.claude/skills/implement-batch/SKILL.md`: Repetir preflight y reescribir el issue entero después de cambiar la base.
2. `.claude/skills/to-issue/SKILL.md`: Inspeccionar y reutilizar arte existente antes de agregar interacción.
3. `.claude/skills/implement-batch/SKILL.md`: Mantener copias completas del proyecto fuera de los checkouts.
4. `.claude/skills/to-issue/SKILL.md`: Buscar todos los lectores, call/Callable y helpers al retirar APIs.
5. `.claude/skills/to-issue/SKILL.md`: Acotar barridos para distinguir reglas retiradas de palabras ajenas.
6. `.claude/skills/to-issue/SKILL.md`: Probar que los tipos propuestos para @export sean exportables.
7. `.claude/skills/implement-batch/SKILL.md`: Congelar el árbol desde encolar hasta recibir el resultado.
8. `.claude/skills/implement-batch/SKILL.md`: Probar PCK real con --main-pack, marcador final y rechazo de errores.
9. `.claude/skills/to-issue/SKILL.md`: Medir bordes visibles y profundidad de mallas, además de rayos físicos.
10. `.claude/skills/to-issue/SKILL.md`: Comparar cada issue apilado con su base explícita.
11. `.claude/skills/to-issue/SKILL.md`: Afirmar foco y pose dibujada al guardar; abrir el PNG efectivo.
12. `.claude/skills/implement-batch/SKILL.md`: Usar res://reports y comprobar retención sin alterar addon ni tope.
13. `.claude/skills/implement-feature/SKILL.md`: Revisar callbacks y desmontaje en raw, además del XML.
14. `.claude/skills/to-issue/SKILL.md`: Verificar DPI, coordenadas y HWND propios para entrada nativa.
15. `.claude/skills/implement-feature/SKILL.md`: Sustituir prohibiciones textuales globales por pruebas funcionales y revisión.
16. `.claude/skills/implement-batch/SKILL.md`: Contrastar hashes con blobs publicados y distinguir procedencia local.

Las seis copias de `.claude/skills/to-spec/sin-deuda.md` quedaron sincronizadas y comprobadas por el harness.

También se documentó que verificar.py ignora --help y puede arrancar el motor. Se conservó esa invocación accidental como incidente. Las verificaciones formales usaron la cola compartida y mantuvieron congelados sus árboles.

El arreglo de exportación [#345](https://github.com/federicohermo/nosefia/pull/345) excluye recursos antiguos sin borrarlos. #327 midió compresión antes de que #297 retirara ese fondo. El fondo ya no se usa al final del lote.
El arreglo de fixtures [#353](https://github.com/federicohermo/nosefia/pull/353) se verificó en la cabeza final `48a5fa9f7217997ebd215fce52943d4ec15443eb`. Su evidencia histórica permanece disponible.

## Orden de merge y bases

Orden completo de los 18 PR con merge commits: [#341](https://github.com/federicohermo/nosefia/pull/341) → [#345](https://github.com/federicohermo/nosefia/pull/345) → [#343](https://github.com/federicohermo/nosefia/pull/343) → [#346](https://github.com/federicohermo/nosefia/pull/346) → [#344](https://github.com/federicohermo/nosefia/pull/344) → [#342](https://github.com/federicohermo/nosefia/pull/342) → [#347](https://github.com/federicohermo/nosefia/pull/347) → [#348](https://github.com/federicohermo/nosefia/pull/348) → [#349](https://github.com/federicohermo/nosefia/pull/349) → [#350](https://github.com/federicohermo/nosefia/pull/350) → [#351](https://github.com/federicohermo/nosefia/pull/351) → [#352](https://github.com/federicohermo/nosefia/pull/352) → [#354](https://github.com/federicohermo/nosefia/pull/354) → [#355](https://github.com/federicohermo/nosefia/pull/355) → [#356](https://github.com/federicohermo/nosefia/pull/356) → [#357](https://github.com/federicohermo/nosefia/pull/357) → [#358](https://github.com/federicohermo/nosefia/pull/358) → [#353](https://github.com/federicohermo/nosefia/pull/353).
Se conservan quince PR de issue y tres auxiliares. La rama de integración sirve para verificar el resultado conjunto; no se presenta como un PR que reúna todo el lote.
La cabeza final de 353 es `48a5fa9f7217997ebd215fce52943d4ec15443eb`, árbol `97d2e74e3377cbb4b5218d587681e109b9f68e2b`, con padres `92634ad42e264f2c05ee87c27b5b0ecea693326e` y `cd9947317ae5489e61b39b795795e059fc4e8f1c`. Frente al primer padre cambia exactamente las once rutas GDScript del arreglo. El conflicto de Mancha conserva la preparación de escena de306 y las comprobaciones del arreglo; no cambia escenas. El CI histórico de `cd9947317ae5489e61b39b795795e059fc4e8f1c` se conserva por separado de la nativa y la CI de esta cabeza final.
Pila funcional de abajo hacia arriba: [#345](https://github.com/federicohermo/nosefia/pull/345) → [#343](https://github.com/federicohermo/nosefia/pull/343) → [#346](https://github.com/federicohermo/nosefia/pull/346) → [#344](https://github.com/federicohermo/nosefia/pull/344) → [#342](https://github.com/federicohermo/nosefia/pull/342) → [#347](https://github.com/federicohermo/nosefia/pull/347) → [#348](https://github.com/federicohermo/nosefia/pull/348) → [#349](https://github.com/federicohermo/nosefia/pull/349) → [#350](https://github.com/federicohermo/nosefia/pull/350) → [#351](https://github.com/federicohermo/nosefia/pull/351) → [#352](https://github.com/federicohermo/nosefia/pull/352) → [#354](https://github.com/federicohermo/nosefia/pull/354) → [#355](https://github.com/federicohermo/nosefia/pull/355) → [#356](https://github.com/federicohermo/nosefia/pull/356) → [#357](https://github.com/federicohermo/nosefia/pull/357) → [#358](https://github.com/federicohermo/nosefia/pull/358).
El arreglo [#353](https://github.com/federicohermo/nosefia/pull/353) depende tanto del lazo [#341](https://github.com/federicohermo/nosefia/pull/341) como de la pila funcional completa. Sus conflictos GDScript se resolvieron en la integración verificada, sin reconstruir escenas.
Después de integrar cada padre con merge commit, repuntar su hijo a staging mientras la base todavía existe, revisar el diff y su CI actual, y recién entonces borrar la base. En particular, 353 va al final, después del lazo y de 308; conserva sólo su arreglo de once GDScript frente a la base integrada. Las bases que requieren ese paso son:
- [#343](https://github.com/federicohermo/nosefia/pull/343) desde `improvement/64-309-export-web-sin-recursos-antiguos`.
- [#346](https://github.com/federicohermo/nosefia/pull/346) desde `improvement/327-comprimir-fondos-ui`.
- [#344](https://github.com/federicohermo/nosefia/pull/344) desde `feature/294-clic-derecho-abre`.
- [#342](https://github.com/federicohermo/nosefia/pull/342) desde `feature/64-el-dialogo-avanza-de-a-una-entrada`.
- [#347](https://github.com/federicohermo/nosefia/pull/347) desde `feature/295-los-apercibimientos-se-acumulan-ocultos`.
- [#348](https://github.com/federicohermo/nosefia/pull/348) desde `feature/300-registrar-al-cierre`.
- [#349](https://github.com/federicohermo/nosefia/pull/349) desde `feature/297-asomarse-por-la-ventanilla`.
- [#350](https://github.com/federicohermo/nosefia/pull/350) desde `feature/298-notas-del-local`.
- [#351](https://github.com/federicohermo/nosefia/pull/351) desde `feature/302-lector-y-tickets`.
- [#352](https://github.com/federicohermo/nosefia/pull/352) desde `feature/303-modo-manual-del-programa`.
- [#354](https://github.com/federicohermo/nosefia/pull/354) desde `feature/304-ticket-al-inodoro`.
- [#355](https://github.com/federicohermo/nosefia/pull/355) desde `feature/309-notificaciones-no-invasivas`.
- [#356](https://github.com/federicohermo/nosefia/pull/356) desde `feature/305-contenedor-de-basura`.
- [#357](https://github.com/federicohermo/nosefia/pull/357) desde `feature/306-llamados-de-atencion`.
- [#358](https://github.com/federicohermo/nosefia/pull/358) desde `feature/307-llamado-del-inodoro`.
- [#353](https://github.com/federicohermo/nosefia/pull/353) desde `improvement/64-309-base-integrada`.

## Escenas y procedencia

- M: `src/escenas/almacen.tscn`
- A: `src/escenas/objetos/nota_pegada.tscn`
- A: `src/escenas/objetos/ticket.tscn`
- M: `src/escenas/puestos/audio_del_almacen.tscn`
- M: `src/escenas/puestos/estructura_del_almacen.tscn`
- M: `src/escenas/puestos/interfaz_del_almacen.tscn`
- A: `src/escenas/puestos/lector.tscn`
- A: `src/escenas/puestos/notas_del_almacen.tscn`
- M: `src/escenas/puestos/objetos_del_almacen.tscn`
- M: `src/escenas/puestos/servicios_del_almacen.tscn`
- M: `src/escenas/puestos/ventanilla.tscn`
- D: `src/escenas/puestos/zona_de_descarte.tscn`
- A: `src/ui/diegetica/capa_de_dialogo.tscn`
- A: `src/ui/diegetica/nota_encuadrada.tscn`
- M: `src/ui/diegetica/panel_de_la_ventanilla.tscn`
- A: `src/ui/diegetica/programa_de_tickets.tscn`
- M: `src/ui/hud.tscn`
- M: `src/ui/interrupciones/pantalla_de_cierre.tscn`
- A: `src/ui/pila_de_notificaciones.tscn`

Agregadas: `src/escenas/objetos/nota_pegada.tscn`, `src/escenas/objetos/ticket.tscn`, `src/escenas/puestos/lector.tscn`, `src/escenas/puestos/notas_del_almacen.tscn`, `src/ui/diegetica/capa_de_dialogo.tscn`, `src/ui/diegetica/nota_encuadrada.tscn`, `src/ui/diegetica/programa_de_tickets.tscn`, `src/ui/pila_de_notificaciones.tscn`.
Retiradas: `src/escenas/puestos/zona_de_descarte.tscn`.
La auditoría contrasta cada escena introducida por un merge con todos sus padres: no hay resultados distintos de todos ellos. No se solicita reconstrucción manual. La procedencia por blobs no demuestra por sí sola la estrategia de merge de tres vías; se conserva ese límite en el proof de auditoría.

## Capacidades y limpieza

10 capacidades activas, 312/312 criterios activos citados, cero faltantes. La cita acredita el ancla, no sustituye revisar la cobertura funcional.

- AMB: ratified, 27/27; ratificable por forma/citas: True.
- CTR: ratified, 32/32; ratificable por forma/citas: True.
- EMP: ratified, 21/21; ratificable por forma/citas: True.
- INV: ratified, 18/18; ratificable por forma/citas: True.
- NTF: ratified, 10/10; ratificable por forma/citas: True.
- PLY: ratified, 77/77; ratificable por forma/citas: True.
- SAV: ratified, 20/20; ratificable por forma/citas: True.
- SHF: ratified, 16/16; ratificable por forma/citas: True.
- CLN: ratified, 44/44; ratificable por forma/citas: True.
- STK: ratified, 47/47; ratificable por forma/citas: True.

6/6 WORKTREES PROPIOS ELIMINADOS mediante el script del lote y sus seis rutas explícitas. Se preservan checkout principal, HEAD del usuario y raíz de coordinación. Sin --todos ni limpieza de otra sesión.

## Fuentes

- entregas: `C:\Users\fede_\orca\workspaces\nosefia\darter\.claude\scratch\batch-64-309\entregas.json`, SHA256 `00448960f1458793c8e6ebad4f02442e04746397177c38bf2f6866343dd0e260`.
- auditoria: `D:\temporales\nosefia-batch-64-309\auditoria-final.json`, SHA256 `baff34ac613f07c99a9946cf7244a731d8e73cddf1508e65bec4dba082ef637d`.
- integracion: `D:\temporales\nosefia-batch-64-309\integracion-final1\manifest.json`, SHA256 `2e184a13f99fec064954a8dda485950776dcd17a082febd549f663593794d84e`.
- outside: `D:\temporales\nosefia-batch-64-309\outside-final\index.json`, SHA256 `45cda55687ba327062349b8a9cc90f611eb33dcc04c951565cc490a612967194`.
- cleanup: `C:\Users\fede_\orca\workspaces\nosefia\darter\.claude\scratch\batch-64-309\padre-limpieza-antes.json`, SHA256 `00168d274276b2fcebc8bdc622fbc83fa3152bd9b8f1d7d2709e082524cb752b`.
- limpieza_log: `C:\Users\fede_\orca\workspaces\nosefia\darter\.claude\scratch\batch-64-309\padre-limpieza.log`, SHA256 `a0bc5f00071c72ffe7af059cfc9fc2c8b160f973ccbfa0c200b9d0b1ba6a9bc1`.

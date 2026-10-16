<!-- Un issue es un plan chico y descartable: resuelve un problema puntual, con límites y
     criterios propios. Un spec es otra cosa: el contrato durable de una funcionalidad.
     Un issue cambia un spec sólo si cambia lo que el juego tiene que hacer. -->

# Los productos se agrupan por sector en las góndolas de la segunda jornada

## Contexto

- **Objetivo:** Hacer que el jugador encuentre cada producto en el sector que define Notion, con Cindolor en frío, bebidas sin refrigerar fuera de las heladeras; **Duronga permanece en góndolas** (decisión Tiago 2026-10-15) hasta reemplazo futuro — no «sólo depósito».
- **Tipo:** `feature`
- **Spec:** modifica — `specs/store-stock/store-stock.md` (por `to-spec`: sectores, excepción de Duronga y decisión explícita de filas por tanda y resolución de OQ-STK-008).
- **Rama:** `feature/434-gondolas-por-sectores`
- **Diseño:** sin pantalla. [Mapa de góndolas](https://app.notion.com/p/3f186efecd9d8096bb5beb6c93d5a676), esquema de distribución de la ficha, y columna «Sector de góndolas» del [catálogo de productos](https://app.notion.com/p/3e586efecd9d80318711c2660fd3bc70).

<!-- `feature` es el único tipo que siempre toca un spec. Un `bugfix` toca uno sólo si el bug
     era una regla que nadie había escrito. La etiqueta sale del tipo: `enhancement`, `bug`,
     `refactor` o `improvement`, y `documentation` o `accessibility` cuando aplica. -->

Coordinación de IDs del 2026-10-15: se contrastaron las ramas publicadas ae2be115 y f67509e0, anteriores a 2ec25dda, y los máximos de `git log --all -p`. Se reasignan sólo los IDs en colisión, conservando sus reglas y criterios. Los sectores usan BR-STK-043/044 y AC-STK-086/087/088/089; alcance y unicidad conserva AC-STK-085. Los números de la capacidad se reservan contra todas las historias publicadas, aunque su código todavía no esté integrado.

**Nueva reutilización de IDs detectada en el cruce de contratos.** Esta nota registra una colisión posterior; no cambia reglas, criterios ni identificadores de #434. El head histórico del carril al detectar esta colisión era `c90d1523e51816813702a27c3ae6f994f9233d5f`; no describe la cabeza actual. El contrato de la rama `feature/429-432-433-22-contratos`, en `2607fb2b2be10156b1b6a7602f8b6dacb29f44e0`, define otros comportamientos con tres IDs que #434 ya había emitido.

Cronología de los commits, con fecha de registro de git en ART (UTC−03:00), sin confundirla con una hora de publicación medida:

- [f67509e0, 15:08:41](https://github.com/federicohermo/nosefia/commit/f67509e0f030584b0e81a915c5debdb4fc04fd43): contrato anterior de los issues 429, 432, 433 y 22, incluido en la auditoría original de IDs.
- [2ec25dda, 15:09:25](https://github.com/federicohermo/nosefia/commit/2ec25dda7d069b4818e2ccb8d8efe2cacd316443): contrato del lote 425, 428, 430, 434 y 435; introduce AC-STK-085 de alcance y unicidad para #434.
- [dc83c877, 15:52:21](https://github.com/federicohermo/nosefia/commit/dc83c877a769d42aacf60f7635444941d289f22f): reserva de IDs contra las historias publicadas anteriores; registra BR-STK-043 para sectores y AC-STK-086 para su correspondencia exacta. Este cruce con f67509e0 no contenía las tres definiciones posteriores de 2607fb2b.
- [2607fb2b, 16:55:39](https://github.com/federicohermo/nosefia/commit/2607fb2b2be10156b1b6a7602f8b6dacb29f44e0): `specs(444): activar Fede y Mia con pedidos fijos y dialogos propios`; agrega las siguientes definiciones incompatibles bajo IDs existentes.

| ID reutilizado | Significado ya emitido por #434 | Significado del contrato posterior 2607fb2b |
|---|---|---|
| BR-STK-043 | La exhibición se agrupa por sector | El pedido fijo admite mercadería sin góndola y distingue Poético |
| AC-STK-085 | El nuevo reparto conserva alcance y unicidad | Duronga se obtiene sin casilleros |
| AC-STK-086 | Cada sector contiene exactamente sus productos | Poético vendible conserva su identidad después de limpiar |

La auditoría cruzada conserva ambos enunciados y sus SHAs; la coordinación se resuelve antes de integrar los contratos. #434 conserva BR-STK-043/044 y AC-STK-085/086/087/088/089, y sus tests siguen apuntando a esos significados. Esta nota no renumera el carril ni modifica la rama ajena. **OQ-STK-008 fue resuelta por la confirmación final del dueño que se registra abajo**; esta nota de colisiones conserva todos los identificadores y no cambia la rama ajena.

**Decisión explícita de filas — OQ-STK-008 resuelta.** Después de revisar la comparación de
una y dos filas, el dueño aclaró finalmente «Sí, dos para Actroncito y Prongles» y observó
«pero ya tienen dos». Se conservan las dos hileras que esos productos ya tienen en el arte
vigente, tanto principales como fijas; se corrige el contrato antiguo que aún les exigía una.
La confirmación final acota la frase universal anterior: no se exige convertir todos los
productos a dos filas. No se crea una hilera nueva de Actroncito o Prongles como novedad.

La elección corresponde a la segunda opción medida: Cosa de Maní, Flin Puf, Burbaloo,
Marranos y Poético tienen una fila en todas sus tandas. Amargadito tiene una fila sólo en su
principal A.sur.1 y conserva dos en su fija A.sur.0. Fernet tiene principal H1.sur.1 doble y
fija H1.sur.0 simple; Oaaaa tiene principal A.norte.2 doble y fija A.norte.3 simple. Los demás
productos exhibidos conservan dos filas. AC-STK-030 y AC-STK-031 distinguen cada tanda,
porque las fijas simples de Fernet y Oaaaa y la principal simple de Amargadito no son
excepciones globales por producto.

El [paquete original medido](https://github.com/federicohermo/nosefia/blob/a63b5df190c575d8b667b6beb659744b74d39810/README.md)
y la [comparación revisada de Actroncito y Prongles](https://github.com/federicohermo/nosefia/blob/cc2226d907b2de6cba8c362188e0671ca018b261/comparacion-filas/README.md)
conservan imágenes, crudos, fuentes y manifiestos. La comparación es una copia de
visualización de poses medidas, no el reparto final generado. Dorado es la fila delantera
y azul la posterior; cada par comparte cámara, escala y poses. Sus 90 archivos publicados
se conservarán al añadir la entrega final.

La decisión de filas ya no bloquea el contrato. La regeneración de recursos espera la base
final de #428, que escribe los contornos de la estructura: #434 se apila después, conserva
esos contornos y exige estructura byteidéntica antes de cualquier escritura de salidas.
Los cupos y alcance finales siguen sujetos a generar y validar el nuevo reparto completo.
OQ-STK-007 sigue reservada para niveles/alturas; esta elección no autoriza cambiarlos.

## Criterios de aceptación

<!-- Los de este issue: binarios y con los valores que deciden. Mueren con el issue.
     Si el issue toca un spec, acá van también los `AC-<COD>-###` que agrega o cambia: ésos
     sí duran, y un test los cita. -->

[GJ-40](https://app.notion.com/p/3f886efecd9d80c8a3ede370ae1f5456) pide ordenar según Mapa de góndolas e incorporar las texturas faltantes. En HEAD `0989ef27`, las 32 cajas ya tienen textura: 19 del artista y 13 con el logo de su envase (#264, cerrado). No se encontró arte nuevo de esas trece. Ese apartado no autoriza inventar reemplazos; los originales ya disponibles se conservan. El trabajo concreto pendiente es el reparto por sectores.

**Mapa cerrado por sectores, sin cambiar alturas.** La medición del modelo original confirma cuatro niveles tanto laterales como de cabecera: 0 y 3 llevan tandas fijas, 1 y 2 principales reponibles. El antiguo detector confundía las chapas superiores inclinadas con laterales; corregirlo conserva la geometría, las alturas, el alcance y los niveles reponibles originales. La cantidad «cuatro» y la frase «primera de los cuatro estantes» de la ficha no se convierten en permiso para reconstruir los muebles: la resolución de ese detalle queda registrada como pregunta local del diseño, sin bloquear los sectores definidos.

- [ ] Las dos islas se agrupan como el esquema: la primera reúne almacén, cereales y una mitad de snacks dulces junto a cereales, con bebidas sin refrigerar en una cabecera; la segunda reúne los otros snacks dulces, snacks salados y golosinas. Malbardo y Amargadito conservan su sector de cabecera de la primera isla. Las correspondencias se verifican con la tabla siguiente, usando los IDs vigentes, sin renombrar productos en este issue.

| Sector y destino | Productos actuales |
|---|---|
| Heladera 1 | Pura-Cola (`CORACOLA`), Fernet God (`FERNET_GOD`) |
| Heladera 2 | Cindolor (`CINDOLOR`), Mayonchis (`MAYONCHIS`) |
| Estantería de no comestibles | Actroncito (`ACTRONCITO`), Durextra (`DUREXTRA`), Poético (`POETICO`) |
| Cabecera de no comestibles, isla de almacén | Malbardo (`MALBARDO`) |
| Cabecera de almacén, misma isla | Amargadito (`AMARGADITO`) |
| Lado de almacén | Marolini (`MAROLINI`), Arvecor (`ARVEJAS`), Uakalas (`UAKAS`), Marranos (`MARRANOS`) |
| Lado de cereales | Zucarachas (`ZUCARACHAS`), Frot Lups (`FROTLUPS`) |
| Cabecera de bebidas sin refrigerar | Oaaaa (`OAAAA`), Terminator (`TERMINATOR`) |
| Mitad de snacks dulces junto a cereales, primera isla | Macumbas (`MACUMBAS`), Pepito (`PEPITOS`) |
| Lado de snacks dulces, segunda isla | Oremos (`OREMOS`), Petisas (`PETISAS`), Cosa de Maní (`COSA_DE_MANI`), Feel Ricky Fort (`FEEL_RICKY_FORT`) |
| Lado/cabecera de snacks salados, segunda isla | Don Saturados (`DONSATURADOS`), Progres (`PRONGLES`), Chisitos (`CHISITOS`), Laysnnt (`LAYSNTT`), Saladick (`SALADIK`) |
| Cabeceras de golosinas, segunda isla | Burbaloo (`BURBALOO`), Flim Pof (`FLINPUF`), Jorgillo (`JORGILLO`) |
| Góndolas (provisional hasta reemplazo; **no** sólo depósito — Tiago 2026-10-15) | Duronga (`DURONGA`) |

- [ ] Cindolor sale de los estantes del local y aparece en la segunda heladera; Oaaaa y Terminator salen de las heladeras y aparecen en su cabecera. Cada heladera agrupa sus dos productos en sus mitades verticales según el esquema; una heladera fuera de servicio continúa vacía.
- [ ] Duronga conserva copias, guías y casilleros en góndolas según el destino provisional del mapa (decisión de Tiago del 2026-10-15). Su caja del depósito mantiene ocho unidades. El dato detallado «Solo está en su caja…» queda subordinado a esa decisión del Mapa de góndolas hasta el reemplazo futuro del producto.
- [ ] Los otros 31 productos actuales mantienen casilleros reponibles alcanzables y sus filas fijas de referencia. Las guías de cada producto quedan en el mismo sector que sus unidades reponibles. Los niveles fijos/reponibles, la separación entre filas y las orientaciones de los envases se conservan como regla; los conteos concretos salen de la geometría medida del nuevo reparto, según la decisión explícita anterior de OQ-STK-008. Se conserva la lista de cinco del arte vigente y las excepciones por tanda medidas; la medición de encaje no decide reglas nuevas.
- [ ] Duronga tiene cupo y casilleros en góndola como los otros productos exhibidos. No se renumera `Producto.Id`. El generador conserva como capacidad separada la posibilidad de un futuro producto sólo-depósito; Duronga no usa ese estado.
- [ ] El reparto se declara en el generador versionado, se aplica al `.blend` y regenera sus recursos. No se edita sólo el `.tres` generado. El generador puede seguir aceptando productos sólo-depósito como capacidad, pero **Duronga no usa ese camino**; conserva malla fuente exportable para caja/venta como cualquier otro.
- [ ] No se modifica la regla ni el algoritmo del sorteo de #367. Usa los cupos del nuevo mapa; **Duronga tiene cupo > 0** y puede ser elegible. La jornada 2 puede vender sus pedidos (incl. Duronga de Fede) y completar reposición sin que el nuevo reparto la vuelva imposible.
- [ ] `to-spec` registra los sectores y la excepción de exhibición, acota las reglas que hoy exigen una tanda/casillero para cada producto y conserva los gestos y alturas actuales. No toma el diseño de jornadas posteriores ni incorpora los siete productos nuevos sin arte del catálogo.
- [ ] El PR muestra el recorrido de las dos islas, estantería y dos heladeras con todos los sectores legibles; el padre abre las capturas. Abrir la jornada 2 presenta el mismo mapa en nativo y en web.

### Decisiones vigentes que delimitan los criterios

- **Duronga exhibible:** permanece en el destino provisional del mapa hasta su reemplazo futuro. Tiene tanda principal, referencias fijas, cupo y casilleros como los demás productos exhibidos; no se le fuerza un bloque vacío. Su caja sigue teniendo ocho unidades.
- **Cuatro niveles interactuables:** se conservan las cuatro chapas existentes. Las tandas fijas de los niveles 0 y 3 mantienen sus unidades y su interacción; las principales de 1 y 2 conservan la reposición. Los casilleros totales suman frontales principales y fijas; el sorteo de apertura de #367 usa sólo frontales principales. Esto no cambia alturas ni resuelve OQ-STK-007.
- Se conservan Cindolor en la segunda heladera, Oaaaa/Terminator en la cabecera de bebidas sin refrigerar y el cruce completo de sectores por `Producto.Id`.
- **OQ-STK-008 está resuelta:** Actroncito y Prongles conservan sus dos hileras ya existentes; rigen la lista de cinco y las excepciones por tanda detalladas arriba. No queda una decisión de filas pendiente ni se exige una conversión universal a dos filas.
- El destino de Duronga procede del mapa y la decisión citada, no de una heurística del generador. La capacidad futura de admitir productos sólo-depósito no cambia la exhibición actual de Duronga.

## Contrato

<!-- Sólo si aparecen firmas, señales o datos nuevos. Cada uno con su capa y su tipo de
     retorno. El caso de falla va junto al de éxito. -->

- **Dato del generador:** las tablas de `lib/reparto.py` expresan sector, destino y productos sólo de depósito. Se conserva el orden completo de `PRODUCTOS` porque corresponde al enum del juego. Las reglas anteriores `FRIOS` y `DE_CABECERA` cambian para reflejar esta tabla; no se agregan heurísticas por nombre de marca.
- **Filas por tanda:** Actroncito y Prongles conservan las dos hileras ya existentes en principales y fijas. Cosa de Maní, Flin Puf, Burbaloo, Marranos y Poético tienen una fila en todas sus tandas. Amargadito tiene una fila sólo en su principal A.sur.1 y dos en su fija A.sur.0. Fernet conserva principal H1.sur.1 doble y fija inferior H1.sur.0 simple; Oaaaa conserva principal A.norte.2 doble y fija superior A.norte.3 simple. El dato explícito de filas se admite sólo en fijas; la excepción principal de Amargadito se declara aparte, sin reducir su fija. Los demás productos exhibidos tienen dos filas. No se cambian escala, ángulos, alturas ni geometría para hacerlos entrar.
- **Compatibilidad coordinada con #367:** el inventario recibe compradores, cupos totales, cupos reponibles y azar por separado. Los reponibles proceden de las filas de adelante principales; las guías abren llenas y mantienen su interacción. Un producto con principal cero no se vuelve elegible por tener guía. #434 conserva ambas fuentes de datos y no modifica el algoritmo de #367.
- **Recursos:** `DisposicionDeLaGondola` conserva listas indexadas por los 32 IDs. Duronga tiene bloques, principal, guías y casilleros derivados de su exhibición provisional; sus consultas devuelven ese cupo real. Por separado, un futuro producto declarado sólo-depósito puede tener listas vacías y cupo cero sin accesos a índices negativos. Esa capacidad no se aplica a Duronga.
- **Generación/puesto:** `disponer.py` exige la tanda principal de Duronga y deriva sus casilleros reales. La posibilidad de cero tandas se reserva a productos declarados explícitamente sólo-depósito, si se incorporan en el futuro. Para ellos conserva malla fuente, datos y recurso exportable; `reposicion_manual.gd` puede omitir bloques de cupo cero y seguir creando unidades desde cajas. No se vacía la exhibición de Duronga para ejercer esa capacidad.
- **Falla:** un producto exhibible sin tanda o con dos tandas principales sigue siendo error del generador; una marca desconocida no se asigna a un sector por defecto.

El cruce visual de implementación del 2026-10-15 comprobó que el esquema mezcla snacks dulces con cereales en una cara de la primera isla. La premisa, la tabla y BR-STK-043 se corrigen para seguir ese dibujo, no para separar categorías que la fuente no separa. La medición confirma una única estantería mural N; el antiguo identificador S no corresponde a ningún mueble de la fuente. Los tres no comestibles ocupan N sin reconstruir muebles ni duplicar una tanda principal. Los niveles que sí tienen exhibición conservan la distinción entre principales y fijas.

El esquema de Notion está descargado en el scratch de revisión como `mapa-gondolas.png`. Los siete productos del catálogo marcados sin arte (Sei Tuqui, La Monteloca, Frigordo, Gringo, Masticul, Cofloco y Chocolocas) no forman parte de los 32 modelos vigentes ni son un requisito particular definido para la jornada 2.

## Límites de archivos

<!-- La tercera fila es una lista negativa y cerrada. Un `.tscn` que otro issue en vuelo edita
     va siempre acá: un merge de tres vías sobre una escena da una escena corrupta. -->

| Categoría | Rutas |
|---|---|
| **Se escribe** | `specs/store-stock/store-stock.md`; `.claude/scripts/lib/reparto.py`, `.claude/scripts/lib/gondola.py` (selección pura del desplazamiento según intervalos geométricos inyectados; TDD en test_gondola.py), `.claude/scripts/blender/acomodar.py`, `.claude/scripts/blender/disponer.py` y sus copias idénticas `.agents/`; `.claude/scripts/tests/test_reparto.py`, `.claude/scripts/tests/test_gondola.py` y sus copias `.agents/` (invariantes del reparto, producto sin exhibición y selección pura del encaje con apoyo e intersecciones medidos); `assets/models/extraer_mallas.gd` (sólo localizar la fuente exportable también cuando no hay tanda principal, usando los datos derivados del modelo); `assets/models/SEPT_JUEGOS_PROTOTIPO.blend`, `.glb`, `.glb.fuente` y los recursos derivados de su exportación; `src/escenas/puestos/disposicion_de_la_gondola.gd` y `.tres`, `src/escenas/puestos/reposicion_manual.gd`, `src/escenas/puestos/guia_del_estante.tscn`, `src/escenas/puestos/contenido_del_estante.tscn`; `test/escenas/puestos/disposicion_de_la_gondola_test.gd`, `test/escenas/un_lugar_por_producto_test.gd`, `test/escenas/casilleros_a_la_vista_test.gd`, `test/escenas/modelo_integrado_test.gd`, `test/escenas/modelo_exportado_test.gd`, `test/escenas/generadores_del_modelo_test.gd` (sólo premisas del reparto actual, cupo cero y recursos regenerados); `test/escenas/gondolas_por_sectores_test.gd` y `.uid` (nuevos, recorrido y correspondencia de sectores) |
| **Sólo lectura** | `src/dominio/almacen/catalogo.gd`, `src/dominio/almacen/inventario.gd`, `src/dominio/almacen/estante.gd`, `src/dominio/jornada/apertura.gd` (según #367), `src/escenas/objetos/caja_de_productos.gd`, `test/escenas/objetos/caja_de_productos_test.gd`, `assets/boxes/`, `assets/source/textures/stockroom/DEPOSITO CAJAS TEXTURA/`, `.claude/scripts/exportar_modelo.py`, `export_presets.cfg` |
| **No se toca** | `src/escenas/almacen.tscn`, `src/escenas/puestos/estructura_del_almacen.tscn`, `src/escenas/puestos/objetos_del_almacen.tscn`, `src/escenas/jugador.gd`, `src/escenas/jugador.tscn`, `src/dominio/jugador/reglas_del_jugador.gd`, `specs/counter-service/`, `specs/save-and-resume/` |

Si el cambio de recurso del modelo modifica el horneado, sus derivados `src/escenas/almacen.lmbake` y `.exr` se regeneran sin editar la escena. El issue no agrega dependencia de #367: comparten consultas de cupo y casos, pero no reescriben su regla ni escena. Las escenas generadas sólo las escribe este issue dentro del lote. El generador conserva los padres de las unidades fuente y mueve sus matrices globales para mantener los NodePaths; disponer sigue recalculando sus salidas y se exige que estructura_del_almacen.tscn permanezca idéntica, no se omite una regeneración para ocultar diferencias. Una fuente de producto sin exhibición se localiza por su transform/frente del contenido generado, sin depender de un bloque principal vacío ni heurísticas de marca. El cambio de inputs contextual de #425 en casilleros_a_la_vista_test.gd se conserva al integrar.

## Verificación

<!-- Comandos que devuelven código de salida 0. El veredicto sale del código de salida,
     nunca de un grep de la salida. -->

La confirmación final del dueño ya resuelve OQ-STK-008 y se registra antes de implementar. La regeneración final espera apilar la base final de #428; los comandos siguientes verifican la entrega completa, no sólo las copias de visualización.

1. `python .claude/scripts/verificar.py`
2. PowerShell: `$env:PYTHONPATH=".claude/scripts"; python -m unittest discover -s .claude/scripts/tests -p test_reparto.py`
3. PowerShell: `$env:PYTHONPATH=".claude/scripts"; python -m unittest discover -s .claude/scripts/tests -p test_gondola.py`
4. Repetir la generación del reparto y exportación desde el `.blend` con los comandos documentados de `exportar_modelo.py` y `blender/disponer.py`; verificar que no cambia el resultado. Reimportar el `.glb` sin su caché previa según CLAUDE.md antes de confiar en la validación de las mallas.
5. El recorrido integrado de jornada 2 verifica Cindolor en heladera, Oaaaa/Terminator fuera, Duronga **en góndola** (sector mapa) y cada sector de la tabla; extraer Duronga de su caja y venderla verifica malla fuente.
6. Exportar con el preset Web versionado y comprobar el mismo recorrido, con capturas de los sectores. No se cambia el preset por fuera del repo.

## Bordes

<!-- El caso feliz lo cubre cualquier implementación. Acá van los límites: cero, uno, el
     máximo, el valor justo antes del corte, el que llega dos veces. -->

- Una caja de Duronga vacía, llena y con una unidad retirada: conserva inventario de depósito, no crea huecos invisibles ni impide cumplir reponer.
- El sorteo de #367 recibe cupos reales también para Duronga (ya no cero). Los pedidos J2 siguen dentro de las ocho unidades por caja, con margen de reposición.
- Una fila fija no puede quedarse en el sector anterior cuando se mueve su principal. Tampoco puede viajar una segunda copia horneada en el `.glb` además del MultiMesh.
- Se conserva el tamaño y la altura de los muebles. Si las medidas de un producto impiden acomodarlo en su sector manteniendo alcance, se informa el caso concreto antes de modificar geometría; no se altera el modelo completo por conveniencia.
- Falta arte original para trece etiquetas, pero todas ya tienen una identificación visible. Su reemplazo sólo se activa cuando haya originales aprobados, sin bloquear este reparto ni generar arte desde el enunciado genérico de GJ-40.
- Las fichas de mapa y productos cambian nombres comerciales respecto del código. Esta entrega cruza cada uno por ID, sin cambiar precios, pedidos ni textos de ventas.

### Diagnóstico de idempotencia del generador (sin cambio de diseño)

La primera regeneración y su repetición no produjeron textos byteidénticos. Se conservan los hashes originales, ambas exportaciones GLB, el backup candidato de la primera fuente y todos los outputs de la segunda. No se afirman recuperados los textos originales que no fueron copiados.

Una sonda Blender de sólo lectura sobre fuente original, backup y segunda fuente midió realimentación de la escala al descomponer `matrix_world` y volver a usar `to_scale()`. La corrección mecánica queda acotada al acomodador y su espejo: conservar la escala local original del artista en las lecturas y escrituras de colocación sobre los marcos rígidos medidos. No cambia redondeos globales, geometría, UV, materiales, columnas, alturas, ángulos ni el contrato de filas aprobado. No introduce metadatos ocultos.

La validación debe repetir la generación desde la fuente original y conservar TODAS las salidas de ambas pasadas por separado (cuatro textos, 32 RES, blend, GLB, huella y caché), antes de comparar sus hashes. Los textos y RES siguen requiriendo igualdad estricta de bytes; una diferencia residual del GLB exige análisis semántico documentado y no se oculta mediante tolerancias. Este diagnóstico no acredita todavía la regeneración completa ni altera las decisiones o restricciones anteriores. El TDD funcional compara el acomodador anterior c780 con la corrección sobre la misma fuente y exige estabilidad exacta de escala y matrices RNA.

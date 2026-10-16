<!-- Un issue es un plan chico y descartable: resuelve un problema puntual, con límites y
     criterios propios. Un spec es otra cosa: el contrato durable de una funcionalidad.
     Un issue cambia un spec sólo si cambia lo que el juego tiene que hacer. -->

# Las cajas respetan el borde gris y se acomodan sobre metal real en la góndola

## Contexto

- **Objetivo:** corregir los dos apoyos de cajas contenedoras documentados en GJ-52.
- **Tipo:** `bugfix`
- **Spec:** modifica — `specs/player-actions/player-actions.md`; el bug revela un borde de apoyo insuficiente que el contrato actual no declara.
- **Rama:** `bugfix/428-apoyos-de-cajas`
- **Diseño:** sin pantalla; corrección del mundo 3D, sin interfaz nueva.

<!-- `feature` es el único tipo que siempre toca un spec. Un `bugfix` toca uno sólo si el bug
     era una regla que nadie había escrito. La etiqueta sale del tipo: `enhancement`, `bug`,
     `refactor` o `improvement`, y `documentation` o `accessibility` cuando aplica. -->

Fuente: [GJ-52](https://app.notion.com/p/3fa86efecd9d80ebbfdbc900faa03a20), editada el 2026-10-15, prioridad Baja. Se inspeccionaron ambas capturas y sus captions: en los cubículos del baño la caja apoya sobre la pared blanca en lugar del borde gris; sobre el borde de la góndola queda sostenida donde debería caerse. La ficha no da pasos, coordenadas ni un umbral de estabilidad.

Base: `bc26e68435b03298bcd8fb07524b73f3671cd7cf`. Hoy `ReposicionManual._apoyar_la_caja()` elige apoyo y llama `quedarse_quieta()`, que congela el cuerpo. `_hay_apoyo()` pregunta bajo un punto. Son candidatos de diagnóstico, no causa confirmada. `BR-PLY-018` permite una superficie fija horizontal y `BR-PLY-013` exige reposo, pero ninguno fija el caso de apoyo insuficiente del borde. La corrección escribe primero ese borde mediante `to-spec`, sin convertir un número propuesto por el agente en decisión de diseño.

El issue abierto #383 amplía qué objetos admiten apoyo encima y modifica la misma regla. Este arreglo conserva su decisión cuando esté integrada; no vuelve a limitar el apoyo a cajas. #219 afecta la patada de unidades y no se absorbe aquí.

Coordinación de IDs del 2026-10-15: se contrastaron las ramas publicadas ae2be115 y f67509e0, anteriores a 2ec25dda, y los máximos de `git log --all -p`. Se reasignan sólo los IDs en colisión, conservando sus reglas y criterios. Los apoyos usan BR-PLY-040 y AC-PLY-099/100; la regresión de apoyos válidos conserva AC-PLY-095. Los números de la capacidad se reservan contra todas las historias publicadas, aunque su código todavía no esté integrado.

## Criterios de aceptación

<!-- Los de este issue: binarios y con los valores que deciden. Mueren con el issue.
     Si el issue toca un spec, acá van también los `AC-<COD>-###` que agrega o cambia: ésos
     sí duran, y un test los cita. -->

- [ ] Reproducir sobre el modelo vigente los dos encuadres de la ficha mediante el gesto real de soltar, registrar la caja, la mira, la superficie golpeada y el apoyo final. Distinguir malla visible y collider; no aceptar como prueba un rayo a una superficie distinta de la capturada.
- [ ] Al dejar la caja sobre la parte superior de la división del baño del reporte, su base queda sobre el borde gris visible, sin atravesarlo ni quedar hundida hasta la pared blanca. Las capturas muestran la base y el contacto final.
- [ ] En el borde de góndola de la segunda captura, el mismo gesto real acomoda la caja chica o grande sobre metal visible, con contacto físico correspondiente, reposo estable, mano vacía, recogida por la mira y sin superposición con sólidos. Inventario y tareas no cambian. Se conserva la recolocación elegida explícitamente por el usuario; no se exige hacer caer una caja estable.
- [ ] Antes del arreglo, `to-spec` declara los bordes reportados con sus criterios nuevos y conserva los apoyos válidos existentes. Si la medición exige decidir un umbral de estabilidad no fijado por el diseño, lo registra como pregunta abierta y obtiene la decisión del dueño antes de implementarlo; no inventa un porcentaje de huella.
- [ ] Piso, mostrador, pallet del depósito y apilado sobre otra caja conservan apoyo estable y recogida; quitar la caja inferior conserva la caída en cascada.
- [ ] El guard heredado de tres soltadas de unidades sigue rechazando el hueco de mercadería; la reserva lógica conserva orientación, escala, recogida e inventario sin crear soporte físico ni afectar heladeras.
- [ ] Los casos nuevos van en una suite temática: `caja_que_se_lleva_test.gd`, `reposicion_manual_test.gd` y `lo_soltado_fuera_de_los_solidos_test.gd` ya tienen 20 métodos públicos cada una en la base medida.


El 2026-10-15 el usuario revisó la comparación frontal y las observadoras lateral y alta,
y decidió explícitamente: «Que la acomode apoyada (recomendado)». La evidencia inmutable
está en [capturas f1ef7fbb](https://github.com/federicohermo/nosefia/tree/f1ef7fbb6e6c1fc4e82be1d606cb0b0deeab5e45),
con once blobs auditados por el coordinador. Corregir el contorno cambia el mismo gesto:
ahora encuentra metal real y recoloca la caja de forma estable. Se conserva esa interacción;
no se cambia selección ni congelación para forzar una caída. BR-PLY-040 y AC-PLY-100 se
actualizan antes de sustituir los dos tests que presuponían el contorno antiguo; también se
retira de BR-PLY-018 la referencia a esa excepción de caída. OQ-PLY-004 general sigue intacta.
La consulta puntual quedó resuelta sin asignar una pregunta abierta nueva.

V5 y su pose manual posterior siguen como diagnóstico histórico de la plataforma invisible,
no como estímulo final. V7/V9 conservan la cámara comparable; la muestra aprobada repite el
gesto real y añade sólo cámaras observadoras. La prueba final cruza triángulos dibujados y
colisión del mismo soporte, reposo, recogida real e identidad de inventario y tareas.

## Contrato

<!-- Sólo si aparecen firmas, señales o datos nuevos. Cada uno con su capa y su tipo de
     retorno. El caso de falla va junto al de éxito. -->

La escena mide el soporte y ejecuta el resultado. Si el criterio requiere una decisión nueva de estabilidad, esa regla pura se declara en `dominio/` con hechos geométricos como entrada y resultado de apoyo/caída; nombres y tipos se definen al medir el caso, sin una API especulativa. `to-spec` escribe el contrato antes de producción. El collider puede corregirse sólo si se demuestra que no coincide con el borde gris visible; no se modifica el arte para acomodar la prueba.

La reproducción nativa V5 sobre la cabeza `bc26e684` distingue ambos contactos con cuerpos
y mallas presentes: la caja descansa en la pared blanca 7 cm por debajo del riel gris; en la
cabecera sobre Saladik el contorno sostiene la base a 2,012327 m y la superficie real bajo el
centro está a 0,876890 m. Descongelar por sí solo no permite caer porque el contorno conserva
esa plataforma invisible. Las capturas y crudos originales se conservan. Estas mediciones no
declaran coordenadas artísticas como regla ni fijan un porcentaje de estabilidad.

El reemplazo del contorno requiere conservar su regeneración y sus lectores mecánicos. Se
autoriza la ampliación siguiente: helpers puros con stdlib, un CLI que lee el GLB vigente y
escribe sólo el riel y los contornos indicados, las llamadas explícitas de A/B desde el
acomodador y dos guards heredados que suponían una forma Box única. El guard de envolvente
exterior conserva holgura, bloqueo del jugador, excepciones de la malla detallada y
antiingreso; el de ancho conserva la comparación A/B y su tolerancia. Ninguno usa la unión de
AABBs como prueba de contacto: el soporte se contrasta con triángulos visibles y física.

La medición del GLB vigente confirma que A y B tienen las mismas 7280 caras triangulares y
13802 vértices, idénticos en espacio local al micrómetro. Su ancho visible común es
1,256744384765625 m; los dos Box heredados medían 1,356744 m por la holgura de 5 cm de cada
lado. La corrección mecánica aplica el mismo compuesto preciso a ambas mallas iguales y
conserva la igualdad de la misma dimensión física en AC-STK-051; no agrega aire sólo para
obtener el ancho anterior ni relaja su tolerancia. A entra como dependencia de esa lectura,
sin modificar reparto, capacidad, arte, transformaciones ni soportes válidos.

El riel en U conserva el aire entre sus brazos. Los compuestos de ambas góndolas conservan volumen,
CAPA8, el contacto visible y los vacíos; no se admite sustituirlo por un casco que rellene aire,
una malla cóncava hueca ni desactivar colisiones. GLB y vértices de Blender deben usar la misma
conversión de ejes y espacio; la regeneración es idempotente y conserva todos los bloques
ajenos de la escena. `lib/gondola.py` conserva su geometría y reparto; sólo cambia la selección de unidades
apagadas por identidades explícitas, declarada más abajo. Los lectores físicos de apoyo siguen sin cambios; la reserva lógica
de unidades se conserva mediante la ampliación acotada que se declara a continuación.


La focal del compuesto preciso revela una responsabilidad adicional del contorno heredado:
`_desatascar_lo_soltado` reservaba también el hueco comercial, donde la mercadería no tiene
cuerpo. Dos de las tres soltadas heredadas quedan ahora en aire real dentro de esa reserva,
sin penetrar los 65 sólidos. Se conserva el guard funcional y su tiempo de física: no se
relaja la envolvente ni se vuelve a llenar el hueco con un cuerpo invisible.

Se separa la reserva lógica de colocación de unidades del soporte físico de cajas. La raíz
entrega al puesto la lista existente de tres góndolas, sin modificar su escena. Para una
`UnidadDeProducto`, el primer candidato admisible debe estar libre tanto de contacto físico
como de la reserva local derivada de la malla del mueble. Se conservan los doce pasos, el
alcance y el retroceso existentes. La orientación y escala reales de `Forma` participan en
la comprobación; un centro fuera no basta si una esquina ocupa la reserva. La envolvente
orientada del envase es conservadora respecto de su convexo; se ejerce un control oblicuo
exterior para impedir el rechazo por una AABB global que rellene la esquina.

El predicado puro `ReservaDeLaGondola.se_superponen(volumen: AABB, pose: Transform3D,
reserva: AABB, marco: Transform3D) -> bool` compara las envolventes orientadas sin consultar
el motor. La escena traduce las formas y las mallas; ese predicado no recibe nodos ni decide
contacto, estabilidad, capacidad o inventario. La reserva sólo interviene en unidades sueltas
de esas tres góndolas: heladeras conservan AC-PLY-024; cajas, baldes, agua y jugador conservan
sus consultas físicas. No crea cuerpos, formas, capas ni plataformas físicas adicionales.

Antes de ampliar una recuperación posterior se mide una unidad que empieza completamente
afuera y rueda hacia el hueco. El cambio al soltar no certifica por sí solo ese recorrido.
Si exige otra política de rescate, se publica primero el alcance completo y su rojo propio;
no se agrega polling ni se mueve la unidad según la mirada actual sin esa evidencia.


La ejecución real del acomodador detectó otra lectura mecánica heredada: al apagar unidades,
el helper también quitaba dos bloques ajenos del lector de productos de la computadora.
Se conserva ese incidente antes de cualquier escritura. Los tres recursos restantes y todos
los convexos precisos eran byteidénticos; sólo desaparecían esos siete renglones ajenos.

Se autoriza `apagar_las_unidades(texto: str, rutas: Sequence[str], identidades: Sequence[str])
-> str`: las identidades de unidades son nombres declarados por el llamador, independientes
del padre y de la lista de rutas activas. El argumento es obligatorio, sin default implícito
ni importación del catálogo dentro del helper puro. El caller declara las unidades de su
catálogo; los fixtures declaran también las identidades anteriores que se retiran. Una lista
de rutas vacía conserva su resultado histórico: retira esas unidades, sin borrar lectores ni
otras referencias ajenas. Se migran todos los lectores y se ejerce TDD versionado con lector,
unidad movida de padre, cero rutas e idempotencia. No se cambia ningún selector geométrico,
reparto, intervalo, soporte o decisión de #434 en `lib/gondola.py`.


La regresión de cascada encuentra un defecto heredado de BR-PLY-015: después de retirar
realmente la caja inferior, la superior chica o grande cae y se duerme 14,488 mm dentro de
`SueloSolido`. El pareado de la cabeza anterior y la candidata conserva exactamente poses,
bases físicas y dibujadas, piso, intersección y reposo; no es una regresión del compuesto.
Eso no autoriza penetración: los guards de base ±ROCE y `_entra_entera` permanecen estrictos.
La holgura heredada de 2 cm sólo medía flotación, y no se usa como permiso de solapamiento.

`CajaDeProductos` congela al recibir `sleeping_state_changed`; el callback de la red omitía
los cuerpos ya congelados. Se autoriza corregir exclusivamente esa traducción temporal en
`RedDeSeguridad`: al recibir reposo, esperar un paso, comprobar que el cuerpo todavía existe
y sigue dormido, y revisar con la política vigente. Así la revisión lee la congelación final,
independientemente del orden de conexión. No cambia ROCE, penetration_slop, rescates,
selección del apoyo, congelación de CajaDeProductos ni el acomodo manual elegido.
El test espejo ejerce señal real congelada→rescate y despertar antes de revisar→sin rescate;
el caso heredado que esperaba revisión sincrónica incorpora esa espera conservando su
resultado. Los dos tamaños y los dieciséis casos de escena se conservan sin relajar.


La primera convergencia completa de la candidata ff9abe4b ejecutó 269/269 suites y
2072/2072 casos, con dos regresiones funcionales. Se conservan XML y crudos antes de
cualquier focal. La traza conjunta confirma dos lectores del contorno y del reposo:

- La bolsa del caso heredado AC-PLY-035 se coloca exactamente en el candidato derivado
  del golpe real. La consulta física es libre, pero la forma completa ocupa la reserva
  de gondolanueva; la posición final difiere de la caída sin mira requerida por BR-PLY-018.
  Se entrega también al jugador la misma lista de tres góndolas y se consulta el predicado
  puro existente en `_entra_entero`, conservando la consulta física. La reserva de este
  camino genérico rechaza candidatos interiores de los objetos que ya pasan por él;
  no se extiende a heladeras, rayos, soporte físico ni selección de cajas del puesto.
  El guard heredado de bolsa queda intacto, incluida su tolerancia.
- Tras un rescate real de una caja congelada y dormida, su pose cambia pero
  `apoyo_que_dejo()` conserva el lugar anterior. La cascada consulta ese dato al retirar
  una caja; no puede actualizarse al colgarla porque perdería el origen que necesita el
  puesto. `_mover` conserva la señal previa y, después de mover, llama a la capacidad
  existente `quedarse_quieta()` sólo si el cuerpo ya está congelado y dormido. No cambia
  esos estados ni introduce una política nueva. El nombre estructural se declara como
  `ReglasDeLosObjetos.METODO_QUEDARSE_QUIETA`; no se modifica CajaDeProductos.

El espejo de RedDeSeguridad incorpora primero un rojo causal que rescata una caja real
ya congelada y exige que su apoyo anotado coincida con la nueva pose. La cascada heredada
y el guard de bolsa se ejecutan sin cambiar sus aserciones. La traza externa de bolsa
terminó el diagnóstico pero filtró recursos al cerrar: se conserva como incidente,
no como prueba verde ni como fuga atribuida al producto. Las focales y la convergencia
final deben terminar sin errores nuevos ni fugas.

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | `src/sistemas/marco/red_de_seguridad.gd` sólo callback de reposo, su documentación temporal y actualización del apoyo anotado tras `_mover` mediante la capacidad existente de un cuerpo ya congelado y dormido; `src/dominio/almacen/reglas_de_los_objetos.gd` sólo la constante estructural `METODO_QUEDARSE_QUIETA`; `src/escenas/jugador.gd` sólo campo de las tres góndolas y consulta de su reserva mediante el predicado puro existente desde `_entra_entero`, conservando la consulta física; `test/sistemas/marco/red_de_seguridad_test.gd` sólo regresiones de ese callback, apoyo anotado tras rescate y espera del caso heredado, sin cambiar otras políticas;  `specs/player-actions/player-actions.md` (primer commit, por `to-spec`); `src/escenas/puestos/reposicion_manual.gd` (selección y estabilidad del apoyo, y separación mecánica de la reserva lógica de unidades en `_desatascar_lo_soltado`); `src/escenas/almacen.gd` sólo entrega de `_muebles_con_contorno` al puesto y al jugador, sin cambiar escenas ni otros flujos; `src/dominio/almacen/reserva_de_la_gondola.gd` y su espejo `test/dominio/almacen/reserva_de_la_gondola_test.gd`, con sus `.uid`, predicado puro de volúmenes orientados y TDD; `src/escenas/objetos/caja_de_productos.gd` (congelación/caída, sólo si lo demuestra la reproducción); `src/escenas/puestos/estructura_del_almacen.tscn` sólo collider del riel reportado y contornos de las dos góndolas centrales A/B: ambos pasan al mismo compuesto preciso porque sus mallas locales medidas son idénticas y el guard de ancho debe conservar la misma dimensión física; nueva suite `test/escenas/objetos/apoyos_de_bordes_de_cajas_test.gd` y `.uid`; nueva suite temática `test/escenas/puestos/reserva_de_gondolas_test.gd` y `.uid` (unidades completas, controles exteriores/heladera, inventario y recogida). Si hace falta regla pura, un módulo nuevo acotado en `src/dominio/almacen/` y espejo en `test/dominio/almacen/`, con sus `.uid`, definido al escribir el contrato. `.claude/scripts/lib/apoyos_del_modelo.py`, `.claude/scripts/actualizar_apoyos.py` y `.claude/scripts/tests/test_apoyos_del_modelo.py`, con los mismos tres archivos bajo `.agents/` (generación pura, CLI y tests); `.claude/scripts/blender/disponer.py` y espejo `.agents/scripts/blender/disponer.py` sólo import del helper, ramas explícitas A/B del bucle de contornos y declaración/paso de identidades de unidades, tras coordinar los hunks con #434; `.claude/scripts/lib/gondola.py` y espejo `.agents/scripts/lib/gondola.py` sólo firma y selección por identidad en `apagar_las_unidades`, sin cambiar otros selectores ni geometría; `.claude/scripts/tests/test_gondola.py` y espejo `.agents/scripts/tests/test_gondola.py` sólo migración de esa firma y regresiones lector/movido/vacío/idempotencia; `test/escenas/contorno_de_los_muebles_test.gd` sólo reemplazo del guard Box por unión de formas habilitadas y testigo compuesto, conservando las comprobaciones funcionales; `test/escenas/puestos/estructura_del_almacen_test.gd` sólo lectura del ancho físico del compuesto y testigo, conservando AC-STK-051 y tolerancia. |
| **Sólo lectura** | `test/escenas/reposicion_manual_test.gd`; `src/escenas/almacen.tscn`; `test/escenas/apoyos_del_modelo_test.gd`; `test/escenas/objetos/caja_que_se_lleva_test.gd`; `test/escenas/lo_soltado_fuera_de_los_solidos_test.gd`. El arte y sus medidas se usan como referencia. |
| **No se toca** | `assets/`; `src/ui/`; `src/sistemas/` salvo las dos traducciones acotadas de reposo y pose rescatada en `src/sistemas/marco/red_de_seguridad.gd`; `src/escenas/jugador.tscn`; `src/escenas/almacen.tscn`; todo `.tscn` salvo la corrección acotada de `estructura_del_almacen.tscn`; `project.godot`; `export_presets.cfg`; `specs/store-stock/store-stock.md`; balance y capacidad de cajas. |

<!-- La tercera fila es una lista negativa y cerrada. Un `.tscn` que otro issue en vuelo edita
     va siempre acá: un merge de tres vías sobre una escena da una escena corrupta. -->

## Verificación

<!-- Comandos que devuelven código de salida 0. El veredicto sale del código de salida,
     nunca de un grep de la salida. -->

1. `python .claude/scripts/verificar.py`
2. `python .claude/scripts/verificar.py --solo specs`.
3. `python .claude/scripts/verificar.py --solo tests` con `GODOT_BIN`; conservar salida cruda y conteo de suites. Repetir casos físicos de baño/góndola y regresiones de piso/mostrador/pallet/pila sobre escena completa.
4. Publicar capturas antes/después de ambos reportes, con el rayo real y la pose dibujada al guardar. Las mediciones de apoyo se derivan de la malla y sus colliders actuales.
5. Probar los helpers sin motor: riel con hueco y bisel, compuesto volumétrico sin puentes de aire, igualdad de espacio GLB/Blender, regeneración idempotente y conservación de bloques ajenos. Ejecutar guards heredados de contorno/ancho y volumen de sólidos, además del gesto real; repetir el acomodador sin revertir colliders ni arte. Conservar evidencia del contacto y del bloqueo del jugador con el compuesto.
6. `git diff --exit-code bc26e68435b03298bcd8fb07524b73f3671cd7cf -- assets src/ui src/sistemas src/escenas/jugador.tscn src/escenas/almacen.tscn project.godot export_presets.cfg specs/store-stock/store-stock.md ':(exclude)src/sistemas/marco/red_de_seguridad.gd'` — actualizar base explícita al arrancar sobre otra cabeza.

## Bordes

<!-- El caso feliz lo cubre cualquier implementación. Acá van los límites: cero, uno, el
     máximo, el valor justo antes del corte, el que llega dos veces. -->

- Caja chica y grande; el tamaño sale del catálogo y del cuerpo vigente.
- Apoyo ancho válido y borde de góndola del reporte; no hacer caer una caja estable para cumplir el segundo caso.
- Límite entre borde gris y pared blanca del baño: medir malla y colisión, sin fijar la ubicación artística en el test.
- Otra caja debajo, dos apoyos posibles y apoyo retirado después de soltar; se conserva la cascada y no se despiertan cuerpos ajenos.
- Sin lugar libre al caer: conserva la política vigente de rescate y no altera tareas, inventario ni cantidad de productos.
- Si otro carril edita `estructura_del_almacen.tscn`, serializarlo mediante dependencia explícita antes de implementar; nunca mergear esa escena en tres vías.


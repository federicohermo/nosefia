# Borrador externo: material de etiqueta al destruir caja

No aplicado, no ejecutado. La fuente E permanece congelada en 55af8724 durante FULL2.
La ampliación a once GD depende del aislamiento de los otros diecinueve errores por B y
de la autorización exacta del padre. No se modifica escena, modelo, textura ni addon.

## Evidencia y alcance leído

B reprodujo materialNULL dummy storage con dos MeshInstance3D que comparten BoxMesh o
ArrayMesh, y cada uno reemplaza la superficie por una copia del material. Libera las
instancias fuera de juego/GdUnit y aparece el mismo error. Esperar cuatro cuadros no
lo elimina; limpiar surface_override_material(0, null) antes de free lo elimina.
La caja real también reproduce fuera del addon. El focal caja_de_productos atribuye
cinco errores; los restantes diecinueve siguen pendientes de su focal caja_que_se_lleva.

Se leyeron íntegramente caja_de_productos.gd, su suite, src/escenas/AGENTS.md y la regla
de presentación. La producción tiene siete métodos públicos (interactuar,
lugar_de_origen, apoyo_que_dejo, quedarse_quieta, soltarse, volver_a_su_lugar, empujar).
Su suite tiene quince métodos públicos, todos casos. El hook _notification es privado;
reemplazar el caso lexical por uno funcional conserva quince públicos/casos.

La etiqueta se aplica en _ready a Malla por set_surface_override_material(0, rotulado).
Volver a su lugar usa reparent; limpiar en _exit_tree retiraría la etiqueta al agarrar o
devolver la caja. PREDELETE es el límite propuesto: sólo cuando se destruye la instancia.
Los consumidores de juego son almacen.gd y puestos/reposicion_manual.gd; ninguno crea
el script con .new(). Aun así, una instancia sin _ready no debe producir errores al liberar.

## Propuesta mínima condicionada

En producción, añadir _notification(que: int): si es NOTIFICATION_PREDELETE, obtener
Malla por get_node_or_null y, si existe, limpiar únicamente su override de superficie 0.
No cambiar la malla compartida ni el material genérico. No ejecutar al salir del árbol.
Este guard de lifecycle presenta recursos; no decide stock, cupos, clics ni productos.

Reemplazar honestamente test_la_caja_no_decide_nada_sobre_el_cupo: hoy lee todo el texto
y prohíbe incluso la subcadena if. No rodear ese veto con un truco sintáctico. El nuevo
caso debe ejercer dos instancias de la escena con etiqueta, guardar cada material/textura,
cambiar ambas de padre real y comprobar identidad de sus materiales, textura y producto.
Después debe liberar ambas dentro de assert_error(...).is_success(). Crear las cajas sin
auto_free, y liberar explícitamente dentro del callable para no registrar un doble free.
Los contenedores de prueba sí pueden ser auto_free. Las aserciones previas evitan un verde
vacuamente limpio que nunca instaló las etiquetas. Deben compartir la misma malla fuente
y tener materiales de etiqueta propios distintos. Al destruir, el material fuente conserva
su textura genérica. Si una caja no entró al árbol, su liberación también queda sin error.
Las referencias guardadas para comparar identidad se liberan antes del free: retener esas
copias desde la prueba podría alterar su lifetime y esconder el diagnóstico que se quiere medir.

El RED debe fallar por materialNULL durante el free real, sin ParseError, conservando las
comprobaciones del reparent. Luego el parche PREDELETE debe dar GREEN sin ese error.
La remoción del antitest no demuestra por sí sola la política de cupos: ésta sigue en el
dominio y sus suites; el PR explicará que el test lexical no admitía un guard legítimo de
liberación de recursos. Las quince pruebas restantes de etiquetas/cuerpo/interacción y las
veinte de caja llevada se ejecutarán completas, además de los lectores de reposición que
revelen los índices. El FULL final deberá revisar raw material y referencias, no sólo XML.

## Sonda externa previa

Sin aplicar el parche, una sonda puede instanciar dos cajas reales, capturar sus materiales,
reparentarlas y verificar la identidad. Luego conectar tree_exiting NO bastaría: se dispara
también durante reparent. Para aislar PREDELETE sin fuente, preparar una subclase externa
del script con sólo el hook propuesto y montarla sobre instancias reales antes de _ready.
Comparar mismo protocolo con script original y subclase, registrando error material/raw.
El driver debe fallar si pierde etiqueta en reparent o cambia el material fuente. Se encola
en turno.py; no se ejecuta durante FULL2 y no se copia ningún proyecto dentro del checkout.

Evidencia de #374, cabeza final `a9b695472165b55bd2faaab1773d139680d68c85`.

Export y capturas corresponden a `4b589ec60b56c3b21c0145aa826d7881dbd5be2e`; el diff hasta final sólo adapta un helper
heredado de tests al fundido decidido y carga el guion dentro del caso de dominio, evitando
la retención de scripts durante discovery. src/assets/project/preset no cambian. El parche exacto
está en diff-producto-a-final.patch. La primera full terminó 6/7 por tres aserciones de esa
suite que aún esperaba carga inmediata; se conserva íntegra. La segunda full pasó7/7 pero
el crudo retuvo164ObjectDB/123recursos. La tercera full, posterior al arreglo del fixture,
es la final. No se presenta la segunda como cierre aprobado.

Verificador completo: 7/7, 239/239 suites y 1823/1823 casos; conteo inmediato al terminar.
Los logs contienen stdout y stderr de todos los nodos. Las advertencias y errores heredados
no se ocultan; comparacion-diagnosticos.json conserva el contraste completo con #373.

diagnostico-discovery/ conserva los controles equivalentes: mismo producto, misma prueba
heredada ejecutada, sólo cambia qué suites nuevas se descubren. Únicamente la suite nueva de
dominio dispara los23scripts heredados adicionales (blobs idénticos a #373, comprobados por
el padre). Cambiar su const preload por ruta y load local dentro del caso devuelve141/100
tanto con el ancla heredada como con los3casos nuevos. Ninguna aserción ni addon se alteró.
No se atribuye a _resolved_user_classes: la lectura al finalizar dio vacío y no localiza
la referencia durante discovery. Se conservan el observador que sólo mostró ayuda por su
basename y el control que abortó antes de motor por una ruta plural inexistente.

Las PNG de la raíz son capturas finales del juego nativo y de Chrome que dibuja, en
1920×1080 y 1280×720. Chrome usa CDP pasivo userGesture:false, física y reloj reales.
NUEVO → 14 pasos/7 fotos → COMENZAR → NOCHE1 → Q/chat/foto real → checkpoint real3/7
→ pausa/menú → CONTINUAR sin instrucciones. Las dos consolas completas no contienen errores.
El paquete exportado conserva el preset exacto; se aíslan únicamente plugins del editor y
main_scene en la copia externa. Las dos sondas PCK comprueban guiones y fotos reales.

fotos/ contiene los siete PNG sin editar que genera el script versionado. La aprobación del
padre corresponde a esos bytes finales. El generador comprueba cada rayo antes de escribir
y restaura las 31 poses de jornada1 antes de Intro13. El retrato original de Enrique se
conserva en producto con SHA256 22375e3b0248f68afc4c2bc215652fe09a01b7aa3a82243709b6989676919b3e.

fuentes-TDD-originales.zip conserva byte por byte los tests, el stub rojo parseable, el
mínimo verde y sus huellas. El rojo precede al mínimo verde (17 aserciones, cero script).
Las pruebas UI/escena son funcionales y no se presentan como test-first.
historico/ conserva dos fixtures sin tipo, puerto web incorrecto y los imports que retuvieron
la cadena de siete scripts por referencias estáticas de la sonda externa; no cuentan como
evidencia aprobada. Cargas dinámicas de las mismas APIs eliminaron esa retención sin tocar
producto. arnes/ conserva las fuentes usadas; paquete/ incluye huellas, no PCK/WASM completos.

procedencia-local.json registra los bytes locales previos a la normalización EOL de Git.
El manifiesto SHA256 publicado se calcula sobre TODOS los blobs remotos y se contrasta
independientemente. Sólo la normalización CRLF→LF de texto puede diferir de la procedencia
local; las PNG y el ZIP deben ser idénticos. El commit final de evidencia se informa en el PR.

# Desenfoque durante el movimiento — #427

Fuente: `bugfix/427-desenfoque-al-retroceder`, cabeza `1d71c1739ec1d27915b28cf518649414aa35b834`, base `dc83c877`.

La base nativa conserva la referencia Actroncito en cuadro, usando la escena original y la mirada del control real. El renderizador es OpenGL3 sobre RTX4050, a1280×720. Las144 muestras originales incluyen quieto, atrás, quieto, adelante, costado y giro. La máscara copia la pose física y se adelanta a la cámara interpolada; al retroceder alcanza51,921mm de diferencia. Las288 muestras corregidas repiten el recorrido con mano vacía y una unidad Marolini sostenida: diferencia máxima de posición y giro cero. Las capturas seleccionadas incluyen cuadros DURANTE el movimiento, HUD, oclusores, pausa y reanudación. Los shaders y su radio permanecen idénticos.

El rojo funcional tiene dos casos: traslación heredada de un padre interpolado con cámara OFF (falla48,93mm), y control de giro sin ancestro interpolado (pasa). El verde pasa ambos. No copia valores de materiales.

La primera completa que llegó a ejecutar verificar.py pasó7/7 nodos, sin salteos, en918,9s:266/266 suites y2035/2035 casos; conteo.py corrió inmediatamente. Los crudos de los siete nodos y el XML están en protocolo. La revisión estricta conserva los67 diagnósticos deliberados de la base, contrastados por causa y contexto; cero nuevos, ausentes, SCRIPT ERROR, Parse Error o fugas al salir. Sólo normaliza IDs efímeros y redondea coordenadas a milímetros.

Exportación: project.godot y export_presets.cfg son byteidénticos a los blobs publicados. El primer export terminó con111 recursos/162ObjectDB; la repetición exacta con plugins ON y verbose terminó limpia, con los mismos cuatro hashes de HTML/JS/WASM/PCK. No se atribuye la retención a los plugins ni se modificó el preset. El PCK contiene los32 modelos. Su primera sonda completó las comprobaciones pero retuvo4 recursos/24ObjectDB al salir e impidió iniciar la completa; tanto la repetición EXACTA de esa sonda como el control que retorna su corrutina terminaron limpios. Tampoco se atribuye una causa no reproducida a ese incidente.

El recorrido Web05 se completó en Chrome real con el PCK original, a 1920×1080 y 1280×720. Se comprobaron referencias Prongles desenfocadas, productos y estantes delanteros nítidos, HUD, retroceso y avance con mano vacía y Laysntt sostenido, pausa y reanudación. El vídeo y las capturas seleccionadas corresponden al recorrido aceptado; `web05-aceptacion-root.json` enumera los cuadros revisados.

El fixture sólo precarga un checkpoint generado por Partida real, sin sustituir el PCK ni su escena principal. La ruta `/userfs/godot/app_userdata/No se fía/partida.guardado` se deriva de config/name y de la implementación de Godot 4.7.2. Se confirmó la entrada efectiva en J2. Los 33 comandos se prepararon antes de encolar; la consola se guarda por evento. El runner limita a 180 s la espera de cada comando y a 720 s todo el proceso; cierra Chrome y Node al finalizar. Los archivos de comandos y el checkpoint permiten repetirlo.

Consola final: 0 errores/pageerror y 36 advertencias. Las advertencias se conservan íntegras y se revisaron por fase; el control430 conserva una consola de otro export con la implementación original de la máscara. La observación en ambos paquetes no se presenta como diagnóstico causal del renderizador.

Los intentos anteriores permanecen como incidentes: 01 usó una ruta incorrecta y dejó vivo Node después de cerrar Chrome; se cerró sólo ese proceso propio tras comprobar su identidad. 02 agotó su límite de 120 s sin medir la ruta. 03 entró en la escena pero expiró esperando el siguiente comando. 04 realizó parte del recorrido, confundió una coordenada de reanudación con Configuraciones y terminó por el límite de 720 s. No se usan sus capturas rotuladas como movimiento mientras estaban en pausa/configuración para demostrar los criterios. Web05 repite el protocolo con la coordenada corregida y todos los comandos disponibles desde el inicio.

La selección conserva los originales del scratch; no se editan imágenes ni crudos. `manifest.json` enumera los bytes publicados y sus SHA256; se contrasta cada archivo con su blob remoto antes de entregar.

Las copias publicables de texto usan LF. `procedencia.json` conserva los hashes anteriores y posteriores a esa normalización; los originales del scratch permanecen intactos. Las imágenes y el vídeo no se transforman.

# Evidencia visual de #429

Producto exportado: `e78fc06d19c0fcce18c964ff17edc7f5ddc9668f`, árbol medido idéntico a
`5c30cc5374801343dad202d387270b2966e9c649` antes de la completa. El código, preset, arte y PCK
permanecen originales. La completa local de5c pasó7/7,281suites/2155casos, sin Script/Parse
ni retenciones; esta carpeta no sustituye sus logs y XML.

`nativo-03/`: cinco cuadros1280×720 del PCK con motor nativo GL Compatibility, NVIDIA4050.
El fixture externo prepara cuerpo/cámara/reloj y dos cuadros originales del Sprite. Verifica
SueloSolido, cápsula prospectiva libre, foco lógico, contorno, encuadre y pose después de dibujo.
El cursor de escritorio está aislado para la ventana fuera de pantalla: no acredita WASM,
Chrome ni Pointer Lock. No se mueve el arte para componer la captura.

`protocolo.json` conserva cada transform actual y dibujado, frame, candidato físico y foco
lógico. Durante suspensión puede existir candidato físico aunque foco lógico y contorno estén
apagados. `medicion-mira.json` registra CPU por consulta nativa, no tiempos de cuadro ni Web.
La muestra con caja registra menos cuerpos en el campo que la vacía; no es comparación a
igual densidad ni demuestra por sí sola rendimiento con mano ocupada en el campo más cargado.

Intentos anteriores conservados fuera de esta publicación:01 contiene imagen inválida y un
timeout con pérdida de los pipes originales; su godot.log recuperado es suplementario.02
corrigió el suelo y produjo cuatro cuadros válidos, pero falló una afirmación del fixture que
confundía candidato físico y foco lógico durante atención.03 conserva ambos datos y pasa.

La procedencia, hashes, comandos, canales y validador completo están en
`D:/nosefia-carril-A-429-444/429-paquete-nativo-03` del registro local del lote.

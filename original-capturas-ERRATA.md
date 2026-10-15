# Capturas nativas originales — intento 03

Fuente: snapshot externo exacto de 2ec25dda. Se importó normalmente después de reutilizar
303 entradas de caché cuyos bytes de fuente/parámetros y source_md5 coincidían. No se copió
caché de escenas GLB, UID, editor ni filesystem.

Resultado: import y captura finalizaron con código 0 en 46 segundos. Once PNG en
434-capturas-original/; caption visible «Base original 2ec25dda». Ambos logs fueron leídos
completos y no contienen ERROR:, SCRIPT ERROR, Parse Error ni WARNING:.

## ERRATA — cupo_duronga no fue una medición

El fixture original impreso en 434-original-capturas-03.log contiene cupo_duronga: 0 porque
ese campo quedó como literal al retirar la aserción del fixture del reparto final.
**Ese cero NO mide el cupo del baseline y NO prueba la excepción de Duronga.**

Los crudos permanecen intactos. Se conserva exactamente el fixture usado como
434-capturar_original-03-usado.gd. El fixture editable 434-capturar_original.gd fue corregido
después de terminar el job para consultar el recurso real en futuras ejecuciones.

Las imágenes sí muestran el modelo y la disposición originales, con revisión y jornada
declaradas. Sus nombres de archivo son nombres del recorrido, no evidencia de que el reparto
nuevo se haya aplicado. Los sectores finales y el cupo cero se verificarán con recursos
regenerados y el fixture final, que consulta/asserta los datos reales.

RAM libre al iniciar: 5,647,848 KiB. Esta medición y la reutilización verificada de caché
no demuestran por sí solas la causa de los dos abortos anteriores, preservados separadamente.

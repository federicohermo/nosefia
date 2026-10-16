# Aclaración del auditor original de #435

`pruebas/revision-diagnosticos.json` se conserva sin cambios de contenido respecto de
la publicación ada7d847d7662bd0698fc13daa2e169c5f51b2e1. Su ventana de búsqueda cruzaba
el límite de cada diagnóstico: asignó los dos errores del Remote Debugger al siguiente
`test_el_rescate_usa_el_origen_de_la_noche`. Esa atribución es incorrecta.

La revisión válida es `pruebas/revision-root-estricta-final.json`, producida mediante
`protocolo/revisar_crudo_por_causas.py` sobre los mismos crudos originales. La búsqueda
de contexto termina antes del diagnóstico siguiente. Los errores iniciales conservan
sus causas reales `connect_to_host` y `create_tcp`; son los mismos de la base.
Resultado: 67 contra 67, sin nuevos/ausentes ni errores de script/parseo o retención.

El harness concatena stdout y stderr. La posición de un mensaje en ese archivo no
establece su fase temporal respecto del test impreso por stdout. Ni el informe viejo
ni el nuevo reconstruyen una cronología: no se atribuye a la ejecución de la suite
de rescate el intento del Remote Debugger ni se infiere el momento de cada rescate.

Reproducir desde esta carpeta descargada, sin ejecutar Godot:

```text
python protocolo/revisar_crudo_por_causas.py pruebas/crudo revision-reproducida.json pruebas/base-tests.log
```

El archivo de salida es nuevo. Se incluyen base y los ocho crudos verdes de la corrida
definitiva, normalizados únicamente CRLF a LF; hashes originales y publicados constan
en `huellas.json`. Código 6fbfe2af744d138f3606dd3dd94f044643f7d4a6 intacto.

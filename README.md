# Mediciones del PR #623 (carga J1→J2 en la web)

- `datos/`: JSON crudos con la plantilla web de la receta actual. `T_<base|fix|fix3>_<chrome|ff><N>`
  son 3 corridas de tiempo (`base` = commit 15b322be; `fix` = primer dedupe; `fix3` = el PR).
  `R_*` son corridas con el jugador real: agarra 3 cajas del depósito, las lleva al almacén y las
  vuelve a apoyar.
- `datos_plantilla_vieja/`: las mismas mediciones con la `web_release.zip` del 7 de octubre
  (`257ba2b4…`), que no coincide con la receta. Muestra 60 programas y un enlace tardío al jugar.
- `caja_fix/`: video y cuadros de la reproducción real en Chrome, alrededor de apoyar la primera
  caja (el nombre de cada cuadro trae `performance.now()` en ms).
- `herramientas/`: el conductor de Godot (`medicion_carga.gd`), el script de Playwright
  (`medir.mjs`), los analizadores y la instrumentación. Nada de esto está en el árbol del juego.

Cómo repetir: aplicar `instrumentacion.diff`, copiar `medicion_carga.gd` a la raíz, exportar
«Web» con una plantilla que pase `preparar_plantilla_web.py --comprobar`, servir el export con
`servir_export.py` y correr `node medir.mjs <url>?repro=0 salida.json [--firefox]`.

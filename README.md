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

## Útiles en J2→J3 (commit `d6c593e9`)

- `datos_utiles_en_j2_j3/J3_<old|new>_<chrome|ff><N>.json`: 3 corridas por celda, con `?hasta=3`.
  `old` es el PR sin el cambio (útiles en J1→J2). `new` es el PR con los útiles en J2→J3.
- Cada corrida juega J1, J2 y llega a J3. En J3, el jugador real recoge los cinco útiles, llena el
  balde en el lavatorio, lo tiñe con el jabón de la mancha, moja la mopa y pasa por la mancha.
- `herramientas/analiza3.py` analiza una corrida. `resumen3.py` imprime las medianas por celda.
  `cola5.sh` es la cola con la que se corrieron.
- Los enlaces tardíos de J3 salen de `linkProgram` después del fin del calentamiento de la
  transición. En Chrome son 6 con `old` y con `new`; en Firefox, 0.

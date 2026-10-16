# Entrega de #437 en curso

PR borrador: https://github.com/federicohermo/nosefia/pull/470.
Rama `improvement/437-sprites-compradores-jornada-2`, cabeza
`838e0baae3ed7f61f6f3190a00058a5d6c10b503`, base #433
`d8c0d8cb5a6e3d968d9cd8fd04f4a12c17829875` (incluye #429).
El worktree B quedó limpio después de commit y push. No se editaron otros worktrees.

El cambio productivo contiene las dos entradas FEDE/MIA de ANIMACIONES y los
dieciséis PNG, dos idle y procedencia. Los cuarenta archivos del commit incluyen
imports generados por Godot y dos archivos de prueba con sus UID. No cambian
escenas, pose, guiones, fábrica productiva, specs, preset ni recetas de exportación.

La procedencia y manifest final están en `437-head-manifest-B.json`;
SHA256 `6793f2a6a161f31c973f25fbc02e01aff080dc43bf1c09637635cad1f7ea7f3a`.
Se compararon los dieciséis PNG contra sus blobs en
`62390898635a04fbb1b6a29558355a5e1984684f`. El manifest también contiene los
dieciséis destinos `.ctex` exactos para comprobar ausencia antes del import nuevo.

Al agotarse C: se trasladó íntegra la carpeta propia de diecisiete originales,
de `Temp/nosefia-watch-429-444/arte437-originales` a
`D:/nosefia-carril-B-429-444/arte437-originales-retencion`, verificando los
diecisiete SHA256 antes/después. El manifest de traslado está junto a ella en
`arte437-originales-retencion-move.json`; no se descartó evidencia ni se movieron
archivos productivos, pines o crudos. Los artefactos CI se descargan en
`D:/nosefia-carril-B-429-444/ci470-838e`.

TDD y límites de evidencia:

- `437-rojo-01`: intento inválido por helper de aserción inexistente; conservado,
  no contado como rojo funcional.
- `437-rojo-02`: nueve casos ejecutados, catorce aserciones fallidas por ausencia
  de claves FEDE/MIA, cero errores XML. Los recursos ya pasaban.
- `437-verde-01`: ocho casos verdes; cuatro aserciones por una posición lateral
  sin SueloSolido. Se conserva; no se atribuye al arte.
- `437-verde-02`: nueve casos, cero fallos, errores, saltos o flaky, exit 0;
  import exit 0 y pines antes/después conservados. Sólo se corrigió la premisa
  lateral: candidatos .65/.5/.35/.2 en cada dirección, seleccionados por suelo y
  cápsula libres, antes de medir foco u oclusión. Conserva frente, ambos lados,
  píxel opaco, intersección con triángulos reales y encuadre de atención.
- El focal contiene dos ERROR de conexión al depurador por el argumento heredado
  `--remote-debug tcp://127.0.0.1:0`, también usado por verificar.py. El cierre
  verbose declara literalmente 38 StringName de tipos builtin. No registra
  SCRIPT ERROR, Parse Error, ObjectDB, recursos ni Pages retenidos. Estos canales
  permanecen íntegros; exit 0 y XML verde no se presentan como salida sin mensajes.
- El import totalmente frío Windows de la copia externa
  `D:/nosefia-carril-B-429-444/437-frio-export-01` terminó nativamente con código
  3221226356 antes del focal y de exportar. No se atribuye una causa. Se preservan
  comando, PID, ambos canales y salida cronológica. No cuenta como import aprobado.
- Chrome437 pendiente se canceló antes de ejecutar, tras verificar PID propio,
  commandline exacto, ausencia de hijos y de log de ejecución. No contó como fallo
  de producto ni generó capturas.

Por coordinación explícita de raíz, la completa local de #437 se realiza junto a
#444 sobre la integración final; no habrá otra completa individual. CI propia
`38957377068` exige la cabeza exacta y conserva checkout/import fríos Linux.
El export Windows final usa caché de base, cuya ausencia de los dieciséis nuevos
`.ctex` debe comprobarse antes de importar. No se lo denomina clon completamente
frío. Paquete, sonda y capturas compartidos se atribuyen a la cabeza integrada,
comparando bytes de los dieciséis PNG, dos idle y tabla con esta cabeza #437.

Pendientes: CI propia 7/7 y XML auditado; completa local conjunta y todos sus crudos;
export/sonda Web y capturas inspeccionadas; actualización final del PR y promoción
únicamente después de esos resultados. No se marca aceptado #437 todavía.

# Preparacion de compatibilidad 434 + foreign367

Este documento prepara una integracion futura. No se creo un worktree, no se movieron refs,
no hubo fetch ni motores y **no existe validacion funcional de la union**.

Inputs del preview: nuestro434 `c780de3e0290826236dbd7a55bb9f66659db4645`, foreign367
`43e3e0ad79f664665afbe7939c3cfcd8bd093183`, base comun
`0989ef277e615dc021cdbdf3320ea6c11b727d28`.
`compat434367-preview01/merge-tree-trivial.txt` es la salida cruda del modo legacy de tres
inputs `git merge-tree --trivial-merge`. No usa `--write-tree`. Es un preview textual, no
un merge ort definitivo ni un veredicto del motor. El estado tracked observado no cambio.

**c780 NO es fuente final434.** Ademas de esperar #428 final, su supuesto Duronga solo
deposito ya fue superado por el issue434 completo actual: Tiago confirma exhibicion hasta
reemplazo futuro. Sectores recupera el destino del mapa. La integracion no debe conservar
Duronga=0 como criterio ni inventar su destino; si debe conservar el borde GENERICO de un
producto con principal cero y guias positivas.

Actualizacion comunicada por root tras este preview: Sectores recupero directamente la
respuesta de Tiago `18:25:14Z` y el mapa, publico/releyo el issue completo coherente y
retomo su fuente tras restaurar el original y apilar428. Es informacion aportada por root;
este carril no volvio a consultar Notion ni GitHub. El pin FINAL434 sigue pendiente. No
investigar autor/hora exacta del cambio de body: conservar solo el intervalo documental
probado en `compat434367-duronga-procedencia.json`.

## Conflictos observados y decisiones de union

El preview actual muestra tres bloques con marcadores, todos en
`specs/store-stock/store-stock.md`:

1. **Provenance:** unir procedencia de #367, #425 y #434 y las decisiones confirmadas de
   filas; actualizar la procedencia de Duronga con la fuente final. No elegir una rama entera.
2. **Contrato de entrada:** conservar sector/destino/exhibicion de434 y tambien los
   casilleros totales, casilleros principales reponibles, pedidos ya construidos y azar de367.
3. **OQ-STK-005:** foreign367 la retira porque sustituye la tabla fija por sorteo J1-J5.
   Conservar esa resolucion y las otras OQ vigentes de434 por su alcance real. La zona de
   conflicto abarca OQ vecinas: no borrar todas las preguntas al elegir el lado remoto.

El cambio `status: ratified` se incorpora sin marcador desde foreign. Eso NO ratifica
automaticamente los criterios agregados por434: el estado final requiere todas sus citas y
evidencia de la union. No copiar la ratificacion como si validara la ampliacion.

La salida tambien etiqueta nueve archivos como cambiados en ambas ramas, incluidos
`almacen.gd`, `reposicion_manual.gd`, tests de jornada, casilleros, reposicion y disposicion.
Sin marcadores en esos archivos no significa compatibilidad probada. Preservar los inputs
contextuales primario/secundario y reserva de muebles de425/428; no restaurar la API de
clic derecho antigua al tomar codigo foreign. No hay conflicto `.tscn` observado con este
foreign, que no modifica escenas; cualquier conflicto de escena en un preview futuro exige
serializacion, nunca mezcla automatica de escenas.

## API que debe resultar

- `Apertura.inventario_de_la_jornada(compradores, totales, reponibles, azar)` conserva los
  cuatro argumentos de foreign367. `compradores` es una unica lista creada por la raiz;
  `TareaDeAtender.new(compradores, inventario)` recibe esos mismos objetos.
- `RepoManual.casilleros()` conserva el total de frentes principal + guias medidos del modelo.
  El getter `casilleros_reponibles()` proyecta exclusivamente
  `disposicion.filas_de_adelante[id]`, sin sumar guias ni copiar el total.
- El limite del sorteo es `min(8 - pedidos_del_producto, fila_principal)`, sin reemplazo y
  con una fuente de azar por sesion. No cambiar algoritmo, balance ni recuperar semilla guardada.
- `_armar_los_bloques()` conserva el orden: copias posteriores fijas; frentes de guias antes
  de los frentes principales. Faltantes <= principal deja completas las guias al abrir.
- **Guia llena al abrir no implica guia no interactiva:** sus casilleros delanteros siguen
  pudiendo agarrarse y reponerse; las copias posteriores siguen fijas. Una tanda de una fila
  no elimina la fila posterior de otra tanda doble del mismo producto.
- Principal=0 + guia>0: producto inelegible para faltante, cupo total>0, guia llena e
  interactiva. Total=0: no faltante ni acceso negativo. Ambos son bordes genericos; no se
  fija que Duronga sea uno de ellos en la fuente final.

## Tests que revisar al hacer la union final

Conservar los tests foreign `pedidos_compartidos_test.gd`, `sorteo_de_apertura_test.gd` y
`apertura_sorteada_test.gd`: identidad/suma de pedidos repetidos, limites 200 semillas,
guias completas y principal cero con guia. Reejecutarlos contra el recurso FINAL434.

Conservar las comprobaciones por tanda y sectores de434 y todos los bordes de geometria
428. En `disposicion_de_la_gondola_test.gd` tomar el test de 200 semillas de367 en lugar
de `Apertura.faltantes_de_la_jornada`, API eliminada. Conservar en el resto del archivo los
casos de principal vacia y filas mixtas de434, adaptando la premisa Duronga a su fuente final.
No volver a exigir una principal no vacia para todos los productos.

Agregar o identificar un test de escena de guia-only que, con apertura real de cuatro
argumentos, pruebe getter principal=0, cupo total medido, guia inicialmente llena y el ciclo
agarrar/reponer de un frontal de guia. El test generico de dominio de367 no demuestra que
la escena cree y enfoque esos casilleros. Mantener las premisas y aserciones actuales de
lectores/contexto, sin relajar tolerancias para obtener verde.

`AperturaConLugar.abrir_con_todo_el_lugar` es un fixture deliberado para dar espacio a
unidades; usa totales. No convertirlo ciegamente en el sorteo real ni usarlo como evidencia
de que la apertura real respeta guias. En los recorridos que venden, usar la apertura real
con los mismos compradores para inventario y Atencion.

## Specs e IDs

Foreign367 cambia reglas existentes BR-STK-026 y AC-STK-033/034/035; no agrega IDs STK.
El preview conserva sectores/filas de434 y sorteo de367 en sus mismos IDs, uniendo texto
cuando corresponde. `preview.json` guarda 16 IDs con texto diferente: son candidatos a
conciliacion semantica, NO 16 colisiones nuevas. No duplicar encabezados al concatenar specs.

El aviso de la OTRA historia foreign2607 sigue independiente de esta union: BR-STK-043,
AC-STK-085 y AC-STK-086 tienen significados extranjeros diferentes. Este plan no renumera
ni resuelve ese cruce, ni afirma cero colisiones actuales. La union con367 no autoriza
sobrescribir las decisiones de la historia2607 cuando se integren ambas.

## Comandos futuros, solo cuando root fije el SHA FINAL434

Los scripts estan fuera del repositorio. `$Final434` debe ser el SHA completo que root
declare final, despues de los cambios de Duronga, recursos y base428. No sustituirlo por
`HEAD`, nombre de rama o el c780 de este preview.

```powershell
$Packet = 'C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435'
$Repo = 'D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia'
$Final434 = '<SHA_FINAL434_COMPLETO_40_HEX>'
python "$Packet/compat434367_preview.py" --repo $Repo --ours $Final434 --out "$Packet/compat434367-preview-FINAL-NUEVO"
# Ejecutar lo siguiente solo tras autorizacion de root para el WT efimero:
& "$Packet/compat434367_futuro.ps1" -Final434 $Final434 -Name 'compat-434-367-final01' -EvidenceDirectory "$Packet/compat434367-merge-final01" -MainRepository $Repo
```

El segundo script crea UN worktree aislado bajo `.claude/worktrees` desde ese SHA y mergea
el foreign exacto sin commit ni push. Si hay conflicto para y preserva todo para resolverlo;
no resuelve codigo/specs, no corre motores, no borra nada ni modifica el foreign WT.

Luego de resolver manualmente, revisar estaticamente en el WT aislado:

```powershell
$Integration = "$Repo/.claude/worktrees/compat-434-367-final01"
python "$Packet/compat434367_revisar_arbol.py" --tree $Integration --final434 $Final434 --out "$Packet/compat434367-static-final01.json"
```

Ese reporte es solo estatico. Esta union efimera no es un PR ni una entrega nueva:
root coordinara FIFO para focales de API de cuatro argumentos, guia-only interactiva y
sectores/lectores contra434 FINAL. Root decidira ampliar controles si un fallo aporta un
riesgo medido. No se exige otro full/native/Web completo duplicado por este plan. El full
propio434 y la validacion completa de la integracion final del lote si siguen siendo
obligatorios por sus entregas. Congelar el arbol desde encolar hasta terminar.

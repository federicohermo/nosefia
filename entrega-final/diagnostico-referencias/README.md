# Modelo integrado: causa del conteo 38 a 70

El conteo rojo proviene de **32 nodos del contenido generado que el propio test incorpora
a su lista de geometria importada esperada**. No son 32 copias nuevas del GLB ni materiales
contados como nodos. `diagnostico-final.json` conserva los paths exactos y las huellas.

En HEAD `64f9022f6f925bfc654a29132fa4ee2d02e24254`, `Contenido` es hijo de
`Estructura/gondolanueva/StaticBody3D` y declara 32 MeshInstance3D ocultos, uno por producto,
con sus recursos `producto_*.res`. `estructura_del_almacen.tscn` es byte identica al blob ff9
y marca 38 referencias: 32 unidades fuente importadas, cinco utiles y el lector.

El cambio del test agrego la posicion global de esas 32 fuentes de Contenido a `lugares`
para representar una fuente aun sin principal. El recorrido del primer test busca todos
los MeshInstance3D de Estructura, incluidos los 32 propios de Contenido. Cada uno coincide
con su posicion por construccion y entra a `esperados`, de ahi 38 + 32 = 70. El raw existente
en lineas 183-194 contiene la lista: sus 32 extras coinciden con los 32 hijos del recurso.

El segundo test del mismo archivo ya excluye `contenido.is_ancestor_of(malla)`. Usar esa
misma frontera en el primero conserva el conteo 38, todas las fuentes GLB, la igualdad
completa de grupos, la invisibilidad y las colisiones apagadas. No cambiar 38 por 70 ni marcar
el contenido como referencia para obtener verde. Sectores implementa y valida en su focal
normal; este carril no edita el WT ni corre motores.

El GLB se leyo como JSON binario offline: tiene 243 nodos con mesh. Las 32 identidades de
referencia tienen un unico candidato cada una al comparar los nombres del archivo con
los nombres de la escena importada, quitando sufijos `-col`/`-convcol` y normalizando la
numeracion con puntos. `glb-crosscheck-sufijos.json` conserva ambos nombres y cada cuenta.
Es un cruce de nombres observado, no una afirmacion de RIDs runtime ni prueba general
de ausencia de toda geometria duplicada. El mismo focal ya dejo verdes los cuatro casos
de modelo_exportado que comprueban una fuente por producto, malla/material/UV y tamano.

`diagnostico.json` preserva el primer control de igualdad literal de nombres: devuelve
cero coincidencias porque GLB mantiene los sufijos de colision que la escena importada no
muestra. Ese resultado NO significa 32 fuentes faltantes ni duplicadas. Se conserva y se
precisa en `diagnostico-final.json`; no se borra ni se atribuye a un defecto de producto.
No hace falta un observer de RIDs para descubrir la causa ya identificada por los paths.

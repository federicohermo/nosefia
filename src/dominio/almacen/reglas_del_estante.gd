## Los valores fijos de reponer: con cuánta mercadería arranca el depósito de una noche.
##
## Es un archivo aparte de `reglas.gd` y de `reglas_de_los_objetos.gd` por el mismo criterio que
## separa a esos dos: no es de qué trata el número, es quién lo toca y probando qué. `reglas.gd`
## se toca discutiendo el balance de la noche; esto, probando si reponer se puede terminar antes
## de que se acabe la mercadería.
##
## **El cupo del estante NO vive acá**, y es la decisión que evita el mismo número escrito dos
## veces: cuántas unidades pide la góndola de cada producto ya es el `umbral` que el 005 le puso
## en el `Catalogo`, y `Inventario.faltantes()` lo usa. Un `CUPO` acá sería una copia que se
## desincroniza sin que ningún gate lo diga.
class_name ReglasDelEstante
extends RefCounted

## Cuántas unidades trae una caja del depósito. La fija la ficha de diseño de las cajas.
##
## Es también todo lo que el depósito tiene de ese producto: hay una caja por producto, y no hay
## mercadería del depósito fuera de las cajas. Por eso la caja se vacía después de entregar
## éstas, aunque la góndola tenga lugar.
##
## **Igualar el umbral del catálogo no deja margen.** Una venta antes de llenar la góndola de un
## producto deja la noche sin cómo reponerlo. De dónde sale el margen es una pregunta abierta del
## spec de la mercadería.
const UNIDADES_POR_CAJA_DEL_DEPOSITO := 8

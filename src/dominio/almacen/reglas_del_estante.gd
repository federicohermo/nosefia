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

## Con cuántas unidades de cada producto arranca el depósito.
##
## Tiene que ser **estrictamente mayor** que el umbral más alto del catálogo —hoy 6, la
## gaseosa—, y eso lo afirma el test: con exactamente el umbral, vender una unidad por la
## ventanilla dejaría reponer imposible esa noche, y el síntoma no nombraría a esta constante.
##
## 10 es un primer valor y el margen es a propósito: lo que sobra después de llenar la góndola
## es lo que se vende, así que este número también es cuánto stock hay para atender. Bajarlo
## aprieta las dos cosas a la vez.
const UNIDADES_INICIALES_EN_DEPOSITO := 10

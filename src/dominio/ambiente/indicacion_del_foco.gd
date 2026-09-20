class_name IndicacionDelFoco
extends RefCounted

const COLOR := Color("ffe5a3")
const GROSOR := 0.008
const TAMANO_DE_MIRA := 4.0
const COLOR_SIN_FOCO := Color.WHITE

## Con qué se tiñe el fantasma que marca dónde va la próxima unidad al reponer.
##
## **Rojo y no el amarillo del foco.** Con la iluminación de la noche el `ffe5a3` se perdía
## contra el blanco del estante: la marca estaba y no se leía. Es un valor aparte y no un cambio
## del `COLOR` porque ese tiñe todo lo enfocable, y el resto del local sí se lee en amarillo.
const COLOR_DE_REPOSICION := Color("ff2d20")

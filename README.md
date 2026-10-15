# #434 — evidencia previa a la decisión de filas

Medición completada el 15/10/2026 sobre la fuente original, sin guardarla ni regenerar el
reparto final. SHA256 del `.blend`:
`0c23ea7db6393ea4a0fa86088b4d4897a5d7484d81ae0c0aedf7f8e7d7213f19`.
Las alternativas están pendientes de decisión del dueño; ninguna está aplicada al arte.

## Imágenes originales

- [Marranos](original-blender-marranos.png): una fila original en principal y fija.
- [Poético](original-blender-poetico.png): una fila original en principal y fija.
- [Jorgillo](original-blender-jorgillo.png): dos filas originales. Su penetración original de
  la chapa no se preserva; el nuevo encaje medido permite dos filas sin esa penetración.
- [Fernet](original-blender-fernet.png): dos filas originales fuera de la heladera; no es la
  distribución final en frío. La etiqueta antigua S no identifica un mueble existente.
- [Amargadito y Poético en Godot original](original-nativo-amargadito-poetico.png): Amargadito
  tenía dos filas en el lateral; Poético tenía una. Es la base 2ec25dda, jornada 2.

Las cuatro imágenes de Blender usan dorado para adelante y azul para atrás. Se mostraron las
copias `guia` y se apagaron Arrays como en la receta de exportación; las 74 copias auditadas
de esos cuatro productos tienen cero modificadores Array. El JSON de copias conserva el
control. No incluye la auditoría de modificadores de todas las copias de Amargadito.

El raw nativo contiene una **errata**: `cupo_duronga: 0` era literal del fixture, no medición.
Se conservan raw y fixture exactos; ver [ERRATA](original-capturas-ERRATA.md). Estas imágenes
no prueban cupos ni sectores nuevos.

## Cierre numérico

El primer barrido conserva las 7217 poses ensayadas. El cierre añade 4518 poses en once casos,
sin variar escala, mallas, separación de filas, ángulos, alturas ni niveles del mueble.
El paso longitudinal es el milímetro ya vigente; se incluyen extremos del intervalo físico.
No se impuso un margen nuevo de cuatro milímetros a los apoyos.

| Tanda comprobada | Filas | Unidades en la tanda compartida | Poses con apoyo completo y sin choque | Mejor traslado |
|---|---:|---:|---:|---:|
| Amargadito principal A.sur.1 | 1 | 4 | 10 | 0 mm |
| Amargadito fija A.sur.0 | 2 | 8 | 121 | 0 mm |
| Oaaaa fija A.norte.3 | 1 | 9 | 65 | 0 mm |
| Actroncito y Durextra principal N.sur.2 | 2 | 28 entre ambos | 187 | 0 mm |
| Actroncito y Durextra fija N.sur.0 | 2 | 28 entre ambos | 170 | 0 mm |
| Donsaturados y Prongles principal B.oeste.2 | 2 | 36 entre ambos | 131 | 0 mm |
| Donsaturados y Prongles fija B.oeste.0 | 2 | 36 entre ambos | 125 | 0 mm |
| Uakas doble y Marranos simple principal A.oeste.1 | 2 / 1 | 15 entre ambos | 90 | 0 mm |
| Uakas doble y Marranos simple fija A.oeste.3 | 2 / 1 | 15 entre ambos | 90 | 0 mm |
| Poético principal N.sur.1 | 1 | 14 | 90 | 0 mm |
| Poético fija N.sur.3 | 1 | 14 | 90 | 0 mm |

Todas las mejores poses tienen cero choques y cero contactos fuera de la chapa. Los conteos
de esta tabla son copias geométricas; no equivalen a cupos manuales o casilleros totales.

### Opciones dobles agotadas

- Marranos doble no tiene pose válida en ninguno de los cuatro niveles de A.oeste, tampoco
  conservando solamente apoyo parcial. Choca con labio, panel o chapa superior.
- Amargadito principal A.sur.1 doble no tiene pose válida. La fila posterior choca con la
  chapa superior; la cara 106 cruza todo el ancho útil. Su fija doble sí cabe.
- Poético doble no tiene pose con apoyo completo en ningún nivel de N. En N.0/1 tampoco
  hay pose parcialmente apoyada sin choque. En N.2/3 existe una a +85 mm, pero sus 14
  unidades posteriores quedan detrás del panel: cuerpo v=280,082–466,664 mm, panel
  v=276,740 mm. La fila posterior queda dentro de la altura del panel; 42 contactos salen
  de la chapa, hasta 61,520 mm, y el cuerpo hasta 67,730 mm. Esta opción no cumple la fila
  posterior visible entera que ya exige BR025; no se rechaza por un margen nuevo de apoyo.
- Fernet fijo H1.0 doble no encuentra encaje entre puerta cerrada y techo conservados.
  La fija simple cabe; su principal H1.1 doble cabe y conserva sus copias posteriores.
- Oaaaa fija A.norte.3 doble no tiene pose válida; la simple sí. La principal A.norte.2
  doble cabe a −6 mm. Estas fijas simples no requieren una excepción global por producto.

El array `paneles` del raw de cierre quedó vacío por filtrar normales locales de BMesh tras
transformar vértices. La comprobación de Poético usa los vértices mundiales originales de la
cara 42 ya registrados en `intersecciones-originales.json` y el origen de N en
`chapas-originales.json`, sin otra sonda ni alterar el raw. Ver `poetico-proyeccion.json` y
el script que conserva el cálculo. La clasificación de niveles y las intersecciones se
verificaron con geometría; no se interpreta ese array vacío como ausencia del panel.

## Decisión acotada

Los cinco globales aprobados son Actroncito, Cosa de Maní, Prongles, Flin Puf y Burbaloo.
Los cinco del arte actual son Cosa de Maní, Flin Puf, Burbaloo, Marranos y Poético.
La unión de siete es una alternativa; no es el estado original del arte.

1. Conservar los cinco aprobados y añadir Marranos/Poético globalmente: siete productos con
   una fila en principales y fijas. Amargadito tiene una excepción sólo en A.sur.1 principal;
   su fija A.sur.0 sigue doble.
2. Seguir los cinco del arte actual: Actroncito y Prongles vuelven a dos filas en principal
   y fija, como admite el cierre. Amargadito conserva la misma excepción sólo principal.

No se propone agregar Amargadito a la lista global: también reduciría su fija doble viable.
Fernet y Oaaaa conservan principal doble y sólo sus fijas geométricas indicadas simples.
La fila frontal de las guías sigue interactuable y abre llena. Quitar copias posteriores,
manteniendo columnas y lugares frontales, no cambia `filas_de_adelante` ni los casilleros
principales o fijos. Los cupos reales y el alcance se medirán después de regenerar.

Las cuatro chapas de cabecera ya existían con patrón 0/3 fijas y 1/2 principales; corregir
la expectativa previa de tres niveles no es una decisión de diseño nueva.

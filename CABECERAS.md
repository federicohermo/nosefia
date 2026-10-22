# Corrección de cabeceras de #621

Medido en el juego real con el motor corregido `4.7.2 nosefia_classdb_1`, renderizador Compatibility.
Antes: `e37dfcc7` (mismo recurso que `207662a7`). Después: `4e8755d1`.
Jornada 1 completa para los 16; jornada 4 para la referencia de 32.
Las vistas frontales y oblicuas usan las mismas cámaras antes y después, en las cuatro cabeceras.

El retiro frontal se aplicaba por error también al ancho transversal de las puntas.
Además, se perdía el aire entre filas de la referencia al recalcular el fondo desde sus envases.
La banda lateral no reservaba ese aire ni el encuentro con las cabeceras.
Se recuperan el ancho transversal y el aire de las filas, y se mide el espacio entre caras de los 32.
Cuando un lateral no entra, su separación entre columnas y con la cabecera se adapta por el mismo factor;
las tandas que entran conservan su ritmo. Esto mantiene abiertos ambos huecos y conserva los cupos.

No cambian los retiros frontales, las 784 unidades, los cupos principales y totales,
las filas, las bases, las mitades longitudinales ni la altura de reposición.
Las heladeras y los no comestibles conservan sus transformaciones.
El generador comprueba todos los apoyos y cero intersecciones entre mallas.
No se modifica el modelo, la iluminación ni ninguna escena `.tscn`.
Se corrige el cumplimiento de BR-STK-048; no se incorpora una regla nueva.
Duronga conserva la decisión provisoria de su ubicación.

## Medidas del juego

Milímetros entre las envolventes de los vértices realmente dibujados, sin ampliar su caja al girarla.
Cada fila de esta tabla corresponde a un nivel, desde el zócalo hasta el superior.
El encuentro mide la menor distancia horizontal a otra cara a la misma altura.
La adaptación de los laterales depende del cupo que debe conservar cada mitad.
Las pequeñas diferencias respecto de 32 incluyen la inclinación original de las cabeceras.

| Cabecera | Nivel | Entre columnas antes | Después | Encuentro antes | Después |
|---|---:|---:|---:|---:|---:|
| A norte, Fernet God | 0 | 5.49 | 20.73 | 19.61 | 39.72 |
| A norte, Fernet God | 1 | 5.49 | 20.73 | 19.61 | 39.72 |
| A norte, Fernet God | 2 | 5.49 | 20.73 | 20.06 | 36.15 |
| A norte, Fernet God | 3 | 5.49 | 20.73 | 20.06 | 36.15 |
| A sur, Malbardo | 0 | 14.88 | 29.60 | 7.95 | 13.19 |
| A sur, Malbardo | 1 | 14.88 | 29.60 | 7.95 | 13.19 |
| A sur, Malbardo | 2 | 15.49 | 29.60 | 7.95 | 12.13 |
| A sur, Malbardo | 3 | 15.49 | 29.60 | 7.95 | 12.13 |
| B norte, Jorgillo | 0 | 27.30 | 28.35 | 8.02 | 20.01 |
| B norte, Jorgillo | 1 | 27.30 | 28.35 | 8.02 | 20.01 |
| B norte, Jorgillo | 2 | 24.12 | 28.35 | 8.02 | 10.53 |
| B norte, Jorgillo | 3 | 24.12 | 28.35 | 8.02 | 10.53 |
| B sur, Poético | 0 | 25.09 | 25.09 | 11.25 | 40.15 |
| B sur, Poético | 1 | 25.09 | 25.09 | 11.25 | 40.15 |
| B sur, Poético | 2 | 25.09 | 25.09 | 11.25 | 28.06 |
| B sur, Poético | 3 | 25.09 | 25.09 | 11.25 | 28.06 |

| Producto | Aire entre filas antes | Después | Referencia de 32 |
|---|---:|---:|---:|
| Fernet God | 20.00 | 50.00 | 50.00 |
| Malbardo | 19.94 | 55.90 | 55.90 |
| Jorgillo | 20.03 | 56.40 | 56.40 |

Poético conserva su única fila; su referencia en 32 está en un lateral y mantiene la misma separación.
Las siete botellas de Fernet alcanzan 20,73 mm entre columnas (32: 19,96 mm); antes quedaban en 5,49 mm.
Malbardo alcanza 29,60 mm, igual a su referencia; Jorgillo queda en 28,35 mm (32: 28,17 mm).

## Capturas

| Cabecera | Antes frontal | Después frontal | Antes oblicua | Después oblicua | 32 oblicua |
|---|---|---|---|---|---|
| A-norte | [Abrir](cabeceras-antes/A-norte.png) | [Abrir](cabeceras-despues/A-norte.png) | [Abrir](cabeceras-antes/A-norte-oblicua.png) | [Abrir](cabeceras-despues/A-norte-oblicua.png) | [Abrir](cabeceras-32/A-norte-oblicua.png) |
| A-sur | [Abrir](cabeceras-antes/A-sur.png) | [Abrir](cabeceras-despues/A-sur.png) | [Abrir](cabeceras-antes/A-sur-oblicua.png) | [Abrir](cabeceras-despues/A-sur-oblicua.png) | [Abrir](cabeceras-32/A-sur-oblicua.png) |
| B-norte | [Abrir](cabeceras-antes/B-norte.png) | [Abrir](cabeceras-despues/B-norte.png) | [Abrir](cabeceras-antes/B-norte-oblicua.png) | [Abrir](cabeceras-despues/B-norte-oblicua.png) | [Abrir](cabeceras-32/B-norte-oblicua.png) |
| B-sur | [Abrir](cabeceras-antes/B-sur.png) | [Abrir](cabeceras-despues/B-sur.png) | [Abrir](cabeceras-antes/B-sur-oblicua.png) | [Abrir](cabeceras-despues/B-sur-oblicua.png) | [Abrir](cabeceras-32/B-sur-oblicua.png) |

## Verificación

TDD: dos regresiones de reparto y la comparación del aire entre filas fallaron por sus aserciones antes del arreglo.
Pasan 16 casos del reparto de prueba, 60 de geometría pura y los cinco casos de geometría del juego,
sin errores ni nodos huérfanos, además de `gdformat` y `gdlint` sobre la suite modificada.
No se ejecutó `verificar.py` ni el árbol completo localmente.

`medir_cabeceras.gd` reproduce las vistas y las mediciones de todas las unidades dibujadas.
Ejecutar con el motor corregido desde la raíz: `--path . --script <script> -- <jornada> <salida>`.
Los JSON completos viven en cada carpeta; `cabeceras-medidas.json` resume las cuatro puntas.
El recurso anterior sigue documentado en la [galería original](README.md#galería-completa).

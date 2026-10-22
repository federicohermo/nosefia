# Columnas y aire medidos de #621

Versión vigente `a92688e5a28378bb6a7f9dea2f59d45b0ff4a214`. Antes corresponde a `30821717`, que todavía comprimía las unidades.
Spec antes del código en `d74a50cd` y `63e1c55c`. Tests en `c7a8e467`.

El usuario autorizó quitar columnas y después pidió moderar el aire. Se conserva exactamente
el ritmo de referencia de cada envase, sin estirar sus huecos, y se quita la menor cantidad
de columnas que lo permite. Si un bloque necesita algo más de media cara puede aprovechar
la holgura del otro, como en los 32. Sus centros siguen en mitades opuestas.
Los encuentros reservan la separación de referencia de sus productos vecinos antes de
calcular las columnas. Las filas y el retiro frontal conservan la referencia anterior.

El generador confirma 64 tandas y 728 unidades sin intersecciones de mallas. Había 784.
Una variante con mitades rígidas bajaba a 688 y dejaba demasiado espacio. Se descartó antes
del commit del código. La versión vigente recupera 40 unidades y conserva todas las
separaciones de referencia. No cambia muebles, modelos, luces ni escenas `.tscn`.

Las tres etapas se capturaron en el juego real, con el motor corregido 4.7.2
`nosefia_classdb_1`, Compatibility y las mismas cámaras. La jornada 1 abre completa.
La referencia de 32 es la jornada 4. Las medidas salen de los vértices realmente dibujados,
no de coordenadas copiadas de un modelo. La tabla compara el nivel inferior; los tests
verifican todos los niveles y filas.

## Ritmo y columnas

La separación está en milímetros. Las columnas son las unidades frontales de un nivel.
Los cupos se vuelven a medir desde el reparto generado.

| Producto | Columnas antes | Ahora | Separación antes | Ahora | 32 |
|---|---:|---:|---:|---:|---:|
| Arvecor | 9 | 8 | 13.32 | 15.00 | 15.00 |
| Marolini | 5 | 5 | 29.97 | 35.00 | 35.00 |
| Terminator | 11 | 11 | 8.46 | 14.92 | 14.61 |
| Zucarachas | 5 | 4 | 15.46 | 35.00 | 35.00 |
| Progres | 12 | 11 | 6.53 | 23.00 | 23.00 |
| Don Saturados | 6 | 5 | 6.70 | 25.00 | 25.00 |
| Pepito | 5 | 5 | 25.88 | 40.00 | 40.00 |
| Petisas | 6 | 5 | 16.93 | 25.00 | 25.00 |
| Fernet God | 7 | 6 | 15.67 | 20.73 | 19.96 |
| Malbardo | 7 | 6 | 24.52 | 29.60 | 29.60 |
| Jorgillo | 3 | 3 | 28.35 | 28.35 | 28.17 |
| Poético | 4 | 4 | 25.09 | 25.09 | 25.09 |

La pequeña diferencia de la proyección horizontal de Terminator y Fernet se debe a que
sus chapas de referencia están inclinadas. El generador conserva su distancia sobre la
chapa. Los tests del juego contemplan la tolerancia de apoyo del dominio para esa proyección.

Heladeras y no comestibles conservan exactamente sus transformaciones y cupos.
Se mantienen los cuatro niveles, las filas posteriores, los destinos, las dos regiones
longitudinales y la principal a altura de reposición. Duronga conserva su destino provisorio
aprobado, sin otra decisión provisoria.

## Cabeceras y encuentro con los laterales

| Cabecera | Margen lateral antes | Ahora | Encuentro mínimo antes | Ahora |
|---|---:|---:|---:|---:|
| A-norte | 23.20 | 78.38 | 10.00 | 55.37 |
| A-sur | 23.21 | 78.98 | 9.95 | 55.32 |
| B-norte | 52.65 | 52.65 | 10.01 | 53.77 |
| B-sur | 79.36 | 79.36 | 21.25 | 61.67 |

El margen se mide contra el exterior visible, incluido el labio. La reserva mínima lateral
sobre la chapa útil sigue siendo la del dominio. Quitar una columna de Fernet y Malbardo
permite conservar ese margen junto con la separación original entre columnas. No se amplía
el hueco entre unidades para llenar el espacio que deja una columna retirada.

Las filas posteriores conservan el aire de los 32. Los encuentros reales quedan entre
53,77 y 61,67 mm. La unión longitudinal queda entre 60,74 y 75,13 mm, repartiendo la holgura
sin juntar las tandas en la mitad.

## Cada encuentro, antes y después

| Cabezal y costado visto | Antes | Ahora | 32 |
|---|---|---|---|
| isla-punta-encuentro--1 | [Abrir](columnas-antes/isla-punta-encuentro--1.png) | [Abrir](columnas-despues/isla-punta-encuentro--1.png) | [Abrir](columnas-32/isla-punta-encuentro--1.png) |
| isla-punta-encuentro-1 | [Abrir](columnas-antes/isla-punta-encuentro-1.png) | [Abrir](columnas-despues/isla-punta-encuentro-1.png) | [Abrir](columnas-32/isla-punta-encuentro-1.png) |
| A-sur-encuentro--1 | [Abrir](columnas-antes/A-sur-encuentro--1.png) | [Abrir](columnas-despues/A-sur-encuentro--1.png) | [Abrir](columnas-32/A-sur-encuentro--1.png) |
| A-sur-encuentro-1 | [Abrir](columnas-antes/A-sur-encuentro-1.png) | [Abrir](columnas-despues/A-sur-encuentro-1.png) | [Abrir](columnas-32/A-sur-encuentro-1.png) |
| B-norte-encuentro--1 | [Abrir](columnas-antes/B-norte-encuentro--1.png) | [Abrir](columnas-despues/B-norte-encuentro--1.png) | [Abrir](columnas-32/B-norte-encuentro--1.png) |
| B-norte-encuentro-1 | [Abrir](columnas-antes/B-norte-encuentro-1.png) | [Abrir](columnas-despues/B-norte-encuentro-1.png) | [Abrir](columnas-32/B-norte-encuentro-1.png) |
| B-sur-encuentro--1 | [Abrir](columnas-antes/B-sur-encuentro--1.png) | [Abrir](columnas-despues/B-sur-encuentro--1.png) | [Abrir](columnas-32/B-sur-encuentro--1.png) |
| B-sur-encuentro-1 | [Abrir](columnas-antes/B-sur-encuentro-1.png) | [Abrir](columnas-despues/B-sur-encuentro-1.png) | [Abrir](columnas-32/B-sur-encuentro-1.png) |

## Todos los muebles

| Vista | Antes | Ahora | 32 |
|---|---|---|---|
| isla-costado | [Abrir](columnas-antes/isla-costado.png) | [Abrir](columnas-despues/isla-costado.png) | [Abrir](columnas-32/isla-costado.png) |
| isla-costado-detalle | [Abrir](columnas-antes/isla-costado-detalle.png) | [Abrir](columnas-despues/isla-costado-detalle.png) | [Abrir](columnas-32/isla-costado-detalle.png) |
| A-este | [Abrir](columnas-antes/A-este.png) | [Abrir](columnas-despues/A-este.png) | [Abrir](columnas-32/A-este.png) |
| isla-punta | [Abrir](columnas-antes/isla-punta.png) | [Abrir](columnas-despues/isla-punta.png) | [Abrir](columnas-32/isla-punta.png) |
| A-sur | [Abrir](columnas-antes/A-sur.png) | [Abrir](columnas-despues/A-sur.png) | [Abrir](columnas-32/A-sur.png) |
| A-sur-detalle | [Abrir](columnas-antes/A-sur-detalle.png) | [Abrir](columnas-despues/A-sur-detalle.png) | [Abrir](columnas-32/A-sur-detalle.png) |
| B-este | [Abrir](columnas-antes/B-este.png) | [Abrir](columnas-despues/B-este.png) | [Abrir](columnas-32/B-este.png) |
| B-oeste | [Abrir](columnas-antes/B-oeste.png) | [Abrir](columnas-despues/B-oeste.png) | [Abrir](columnas-32/B-oeste.png) |
| B-oeste-detalle | [Abrir](columnas-antes/B-oeste-detalle.png) | [Abrir](columnas-despues/B-oeste-detalle.png) | [Abrir](columnas-32/B-oeste-detalle.png) |
| B-norte | [Abrir](columnas-antes/B-norte.png) | [Abrir](columnas-despues/B-norte.png) | [Abrir](columnas-32/B-norte.png) |
| B-sur | [Abrir](columnas-antes/B-sur.png) | [Abrir](columnas-despues/B-sur.png) | [Abrir](columnas-32/B-sur.png) |
| heladera | [Abrir](columnas-antes/heladera.png) | [Abrir](columnas-despues/heladera.png) | [Abrir](columnas-32/heladera.png) |
| heladera-2 | [Abrir](columnas-antes/heladera-2.png) | [Abrir](columnas-despues/heladera-2.png) | [Abrir](columnas-32/heladera-2.png) |
| no-comestibles | [Abrir](columnas-antes/no-comestibles.png) | [Abrir](columnas-despues/no-comestibles.png) | [Abrir](columnas-32/no-comestibles.png) |

## Protección y reproducción

| Criterio | Test de comportamiento | Resultado local |
|---|---|---|
| AC-STK-100 | `test_quita_columnas_antes_de_comprimir_el_ritmo` y `test_cada_tanda_conserva_el_ritmo_de_su_envase_y_el_sobrante_queda_en_los_bordes` | Verde |
| AC-STK-101 | `test_aprovecha_la_cara_antes_de_quitar_otra_columna` y `test_los_laterales_tienen_ritmo_y_aire_en_la_union_de_las_mitades` | Verde |
| AC-STK-102 | `test_las_cabeceras_tienen_aire_y_margen_en_ambos_costados` y `test_el_aire_entre_filas_de_cabeceras_conserva_la_referencia` | Verde |
| AC-STK-103 | `test_la_prueba_conserva_el_retiro_frontal_del_mapa_completo`, `test_cada_unidad_dibujada_tiene_el_apoyo_de_la_malla_real` y `test_el_reparto_con_aire_no_superpone_unidades` | Verde |
| AC-STK-104 | `test_rechaza_un_tramo_que_no_admite_ni_una_columna` y `test_una_columna_por_mitad_reserva_caras_y_union` | Verde |

El test del recurso anterior falla por 90 encuentros que no conservan el aire de referencia.
El test del colocador anterior falla por conservar 3 columnas donde sólo caben 2 con la
referencia. La variante que descartaba columnas por mitades rígidas falla por conservar
4 cuando caben 5 en la cara. Después pasan 18 casos del reparto, 60 de geometría pura
y 14 del juego real y cambio de catálogo, sin errores, salteos ni huérfanos.
También pasan gdformat, gdlint y el gate de specs. No se corrió verificar.py ni el árbol
completo local. La CI de #621 verifica el conjunto completo sobre el SHA publicado.

El caso de cambio de catálogo comprueba que el cupo de reposición y sus casilleros coinciden
con el reparto de cada etapa y que volver a la etapa completa restaura sus cupos.
Los tests geométricos leen los mínimos del dominio por nombre y la referencia desde el
reparto real de 32. Las pruebas puras afirman separación y cantidad máxima que entra, sin
fijar conteos de nodos, hashes ni posiciones del modelo.

`medir_columnas.gd` reproduce las capturas con el motor corregido y
`--path . --script <script> -- <jornada> <salida>`. Cada carpeta conserva sus datos de
unidades y muebles. `columnas-medidas.json` resume los resultados.
Los reportes anteriores en AIRE.md y CABECERAS.md son históricos.

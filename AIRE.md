# Aire de laterales, cabeceras y unión central de #621

Versión actual: `30821717e306516e8452a5489c8cf704a9502492`. Spec primero: `49688d08`; regresiones: `c48e4e75`.
Antes corresponde a `4e8755d1`, la build de las dos capturas reportadas por el usuario.
Después corresponde al arreglo actual. Referencia: jornada 4, con 32 productos.
Los tres recorridos se capturaron en el juego real con el motor corregido 4.7.2 `nosefia_classdb_1`,
Compatibility, y las mismas cámaras. Jornada 1 abre completa en los recorridos de 16.

## Causa y regla

El arreglo anterior reservaba aire extra en los encuentros con las puntas a costa de las
separaciones de los laterales; sus dos bloques podían terminar tocándose en la división central.
Además había confundido el retiro frontal con el margen lateral de las cabeceras: al separar
ambos ejes se había dejado el borde lateral casi al ras.

Ahora se reserva primero el aire central y los mínimos de cada encuentro, y se distribuye el
ancho entre los dos bloques, como en el reparto completo. Si sobra ancho en una mitad se puede
aprovechar sin cambiar los productos de lado: sus centros siguen en mitades opuestas y la
frontera queda abierta. Los huecos internos conservan la referencia cuando el conjunto cabe;
si no cabe, se adaptan uniformemente sin bajar del mínimo. El generador rechaza un reparto que
no puede cumplir todos los mínimos con sus cupos. La holgura extra de una punta no comprime
las unidades de un costado.

BR-STK-049 y AC-STK-101 a AC-STK-104 protegen este comportamiento. Las distancias se leen de
las constantes de `ReglasDelEstante`; no se copian a los tests ni al generador.

| Mínimo del dominio | Milímetros |
|---|---:|
| `SEPARACION_MINIMA_DE_EXHIBICION` | 5 |
| `AIRE_MINIMO_ENTRE_CARAS` | 10 |
| `AIRE_MINIMO_ENTRE_TANDAS` | 20 |
| `MARGEN_LATERAL_DE_EXHIBICION` | 20 |
| `AIRE_MINIMO_ENTRE_FILAS` | 20 |

Se conservan las 784 unidades, los cupos principales y totales, las filas, las bases,
las dos regiones longitudinales, los destinos y la principal a altura de reposición.
El retiro frontal se conserva en cada cara. Heladeras y no comestibles conservan exactamente
sus transformaciones. No se cambia el modelo, el horneado ni ninguna escena `.tscn`.
Duronga conserva su ubicación provisoria aprobada; no se incorpora otra decisión provisoria.

## Medidas reales

Milímetros sobre la envolvente de los vértices que dibuja el juego. La tabla muestra el nivel
inferior para comparar el mismo encuadre; el test protege todos los niveles y todas las filas.
La separación de referencia corresponde al mismo producto, aunque cambie de cara en los 32.

| Producto | Entre unidades antes | Después | Referencia de 32 |
|---|---:|---:|---:|
| Arvecor | 10.90 | 13.32 | 15.00 |
| Marolini | 24.62 | 29.97 | 35.00 |
| Terminator | 3.49 | 8.46 | 14.61 |
| Zucarachas | 24.63 | 15.46 | 35.00 |
| Progres | 5.12 | 6.53 | 23.00 |
| Don Saturados | 8.04 | 6.70 | 25.00 |
| Pepito | 25.47 | 25.88 | 40.00 |
| Petisas | 8.04 | 16.93 | 25.00 |

| Lateral | Unión entre bloques antes | Después |
|---|---:|---:|
| A-oeste | -0.00 | 20.00 |
| A-este | -0.00 | 20.00 |
| B-oeste | 0.00 | 20.00 |
| B-este | 0.00 | 20.00 |

| Cabecera | Margen lateral antes | Después | Encuentro antes | Después | Entre columnas antes | Después |
|---|---:|---:|---:|---:|---:|---:|
| A-norte | 8.02 | 23.20 | 39.72 | 10.00 | 20.73 | 15.67 |
| A-sur | 7.98 | 23.21 | 13.19 | 9.95 | 29.60 | 24.52 |
| B-norte | 52.65 | 52.65 | 20.01 | 10.01 | 28.35 | 28.35 |
| B-sur | 79.36 | 79.36 | 40.15 | 21.25 | 25.09 | 25.09 |

El margen de esta tabla se mide contra el exterior visible del mueble. Incluye el labio:
la reserva sobre la chapa útil es de 20 mm por costado. La fila posterior de las cabeceras
conserva el aire ya corregido de la referencia: 50 mm en Fernet, 55,90 mm en Malbardo y
56,40 mm en Jorgillo. Poético conserva su única fila.

## Detalles de las dos regresiones

| Vista | Antes | Después | 32 |
|---|---|---|---|
| isla-costado-detalle | [Abrir](reparto-antes/isla-costado-detalle.png) | [Abrir](reparto-despues/isla-costado-detalle.png) | [Abrir](reparto-32/isla-costado-detalle.png) |
| A-sur-detalle | [Abrir](reparto-antes/A-sur-detalle.png) | [Abrir](reparto-despues/A-sur-detalle.png) | [Abrir](reparto-32/A-sur-detalle.png) |
| B-oeste-detalle | [Abrir](reparto-antes/B-oeste-detalle.png) | [Abrir](reparto-despues/B-oeste-detalle.png) | [Abrir](reparto-32/B-oeste-detalle.png) |

## Recorrido completo

| Cara | Antes | Después | 32 |
|---|---|---|---|
| isla-costado | [Abrir](reparto-antes/isla-costado.png) | [Abrir](reparto-despues/isla-costado.png) | [Abrir](reparto-32/isla-costado.png) |
| A-este | [Abrir](reparto-antes/A-este.png) | [Abrir](reparto-despues/A-este.png) | [Abrir](reparto-32/A-este.png) |
| isla-punta | [Abrir](reparto-antes/isla-punta.png) | [Abrir](reparto-despues/isla-punta.png) | [Abrir](reparto-32/isla-punta.png) |
| A-sur | [Abrir](reparto-antes/A-sur.png) | [Abrir](reparto-despues/A-sur.png) | [Abrir](reparto-32/A-sur.png) |
| B-este | [Abrir](reparto-antes/B-este.png) | [Abrir](reparto-despues/B-este.png) | [Abrir](reparto-32/B-este.png) |
| B-oeste | [Abrir](reparto-antes/B-oeste.png) | [Abrir](reparto-despues/B-oeste.png) | [Abrir](reparto-32/B-oeste.png) |
| B-norte | [Abrir](reparto-antes/B-norte.png) | [Abrir](reparto-despues/B-norte.png) | [Abrir](reparto-32/B-norte.png) |
| B-sur | [Abrir](reparto-antes/B-sur.png) | [Abrir](reparto-despues/B-sur.png) | [Abrir](reparto-32/B-sur.png) |
| heladera | [Abrir](reparto-antes/heladera.png) | [Abrir](reparto-despues/heladera.png) | [Abrir](reparto-32/heladera.png) |
| heladera-2 | [Abrir](reparto-antes/heladera-2.png) | [Abrir](reparto-despues/heladera-2.png) | [Abrir](reparto-32/heladera-2.png) |
| no-comestibles | [Abrir](reparto-antes/no-comestibles.png) | [Abrir](reparto-despues/no-comestibles.png) | [Abrir](reparto-32/no-comestibles.png) |

## Regresiones y reproducción

| Criterio | Test de comportamiento |
|---|---|
| AC-STK-101 | `test_los_laterales_tienen_ritmo_y_aire_en_la_union_de_las_mitades` y `test_el_aire_extra_de_las_puntas_no_roba_el_ritmo_y_deja_la_mitad_abierta` |
| AC-STK-102 | `test_las_cabeceras_tienen_aire_y_margen_en_ambos_costados` y `test_el_aire_entre_filas_de_cabeceras_conserva_la_referencia` |
| AC-STK-103 | `test_la_prueba_conserva_el_retiro_frontal_del_mapa_completo`, `test_cada_unidad_dibujada_tiene_el_apoyo_de_la_malla_real` y `test_el_reparto_con_aire_no_superpone_unidades` |
| AC-STK-104 | `test_rechaza_el_tramo_que_solo_cabe_borrando_el_aire` y `test_el_minimo_exacto_incluye_el_aire_de_caras_y_de_la_union` |

El recurso anterior falla las aserciones de unión central, separación mínima y margen lateral;
el colocador anterior también falla el rechazo del tramo insuficiente. Con el recurso nuevo
pasan los ocho casos del juego real sin errores ni huérfanos, 18 casos del reparto y 60 de
geometría pura. El generador vuelve a producir el mismo recurso y valida 784 unidades,
64 tandas, sus apoyos y cero intersecciones de mallas.

También pasan gdformat, gdlint y el gate de specs. No se ejecutó verificar.py ni el árbol
completo local. La CI del PR verifica el conjunto completo sobre el SHA publicado.

`medir_aire.gd` reproduce las capturas: motor corregido, `--path . --script <script> -- <jornada> <salida>`.
Los JSON conservan cada unidad dibujada y sus cupos. `aire-medidas.json` resume las distancias.
Los reportes históricos siguen en [CABECERAS.md](CABECERAS.md) y en la galería original.

# MÃ¡rgenes de las jornadas de prueba

Capturas del juego real en Godot 4.7.2 `nosefia_classdb_1`, renderizador Compatibility.
Los tres recorridos usan la misma cÃ¡mara y el mismo encuadre en cada cara.
La referencia corresponde a jornada 4. Antes y despuÃ©s corresponden a jornada 1, que abre sin faltantes.

La causa estÃ¡ en el generador de prueba. Recalculaba bandas desde los envases presentes y repartÃ­a el sobrante entre todas las unidades del estante.
La correcciÃ³n mide el retiro de cada cara y el ritmo de cada envase del mapa completo.
Centra cada tanda en su mitad y comprime uniformemente sÃ³lo cuando no cabe con ese ritmo.
Las puntas reservan el retiro dentro de la chapa real. La validaciÃ³n de mallas detecta cualquier intersecciÃ³n.

Los cupos principales y totales de las diecisÃ©is identidades coinciden antes y despuÃ©s.
Ambos recorridos dibujan 784 unidades. Se conservan filas y orientaciones.
El generador final informa 64 tandas y cero choques, sin modificar el modelo ni el horneado.

## Mediciones

Distancias en milÃ­metros sobre la envolvente real dibujada. El borde se mide desde la chapa, no desde la caja total del mueble.
La separaciÃ³n corresponde a la primera fila frontal de cada producto, incluido el zÃ³calo.
Las pequeÃ±as diferencias de la referencia en cabeceras incluyen la inclinaciÃ³n original del envase.

| Producto | Margen antes | Margen despuÃ©s | Margen de 32 | SeparaciÃ³n antes | SeparaciÃ³n despuÃ©s | SeparaciÃ³n de 32 |
|---|---:|---:|---:|---:|---:|---:|
| Arvecor | 4.50 | 47.00 | 47.00 | 25.22 | 15.00 | 15.00 |
| Marolini | 4.50 | 47.00 | 47.00 | 25.22 | 35.00 | 35.00 |
| Fernet God | 4.50 | 50.55 | 50.55 | 21.00 | 5.48 | 20.73 |
| Progres | 4.50 | 47.00 | 47.00 | 10.78 | 8.23 | 23.00 |
| Don Saturados | 4.50 | 47.00 | 47.00 | 10.78 | 16.66 | 25.00 |
| Actroncito | 4.50 | 4.50 | 1.50 | 43.59 | 43.86 | 43.86 |
| Duronga | 4.50 | 4.50 | 1.50 | 43.59 | 25.11 | 25.11 |
| Pura-Cola | 24.50 | 24.50 | 24.50 | 36.71 | 36.71 | 36.71 |
| Mayonchis | 24.50 | 24.50 | 24.50 | 91.84 | 91.84 | 91.84 |

Las heladeras se miden desde su bandeja corta, a la que se alinea el conjunto.
Don Saturados cambia de costado entre etapas. Cada margen se mide contra el borde de su propio costado.
Duronga sigue exhibida provisionalmente segÃºn el mapa aprobado. No se toma otra decisiÃ³n provisoria sobre arte ni interacciÃ³n.

## GalerÃ­a completa

| Cara | Antes, 16 | DespuÃ©s, 16 | Referencia, 32 |
|---|---|---|---|
| Isla A, oeste | [Abrir](antes-16/isla-costado.png) | [Abrir](despues-16/isla-costado.png) | [Abrir](referencia-32/isla-costado.png) |
| Isla A, este | [Abrir](antes-16/A-este.png) | [Abrir](despues-16/A-este.png) | [Abrir](referencia-32/A-este.png) |
| Isla A, norte | [Abrir](antes-16/isla-punta.png) | [Abrir](despues-16/isla-punta.png) | [Abrir](referencia-32/isla-punta.png) |
| Isla A, sur | [Abrir](antes-16/A-sur.png) | [Abrir](despues-16/A-sur.png) | [Abrir](referencia-32/A-sur.png) |
| Isla B, oeste | [Abrir](antes-16/B-oeste.png) | [Abrir](despues-16/B-oeste.png) | [Abrir](referencia-32/B-oeste.png) |
| Isla B, este | [Abrir](antes-16/B-este.png) | [Abrir](despues-16/B-este.png) | [Abrir](referencia-32/B-este.png) |
| Isla B, norte | [Abrir](antes-16/B-norte.png) | [Abrir](despues-16/B-norte.png) | [Abrir](referencia-32/B-norte.png) |
| Isla B, sur | [Abrir](antes-16/B-sur.png) | [Abrir](despues-16/B-sur.png) | [Abrir](referencia-32/B-sur.png) |
| Heladera 1 | [Abrir](antes-16/heladera.png) | [Abrir](despues-16/heladera.png) | [Abrir](referencia-32/heladera.png) |
| Heladera 2 | [Abrir](antes-16/heladera-2.png) | [Abrir](despues-16/heladera-2.png) | [Abrir](referencia-32/heladera-2.png) |
| No comestibles | [Abrir](antes-16/no-comestibles.png) | [Abrir](despues-16/no-comestibles.png) | [Abrir](referencia-32/no-comestibles.png) |

## VerificaciÃ³n

AC-STK-100 se ejerce con los tests de separaciÃ³n de `test_reparto_de_prueba.py` y la prueba del retiro frontal de `geometria_de_prueba_test.gd`.
El recurso anterior falla el test de margen del juego. El recurso nuevo pasa los cuatro casos de esa suite sin errores ni fugas.
Los trece casos puntuales del reparto y los sesenta de la geometrÃ­a pura pasan.
No se corriÃ³ verificar.py local ni el Ã¡rbol completo.

El script `medir_gondolas.gd` reproduce las capturas con el motor corregido.
Se ejecuta desde la raÃ­z del proyecto con `--path . --script <ruta del script> -- <jornada> <directorio de salida>`.
Antes usa el recurso de disposiciÃ³n de la base del PR. DespuÃ©s usa el recurso de la rama del PR.
Cada carpeta conserva las mediciones de todas las unidades dibujadas en su JSON.

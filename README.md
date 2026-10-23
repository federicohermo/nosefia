# Compradores de las jornadas 3 a 5

Capturas del juego real: motor Godot 4.7.2, renderizador Compatibility, ventana de 1280 por 720.
Cada noche se abre con una partida nueva, y el reloj salta a la hora de llegada de cada comprador.
La segunda columna es la figura en la ventanilla. La tercera es lo que dice al hablarle por primera vez.

| Noche | Comprador | Llega | Se va | Figura | Apertura |
|---|---|---|---|---|---|
| 3 | Cami | 20:03 | 22:33 | [Abrir](J3-1-Cami-llegada.png) | [Abrir](J3-1-Cami-apertura.png) |
| 3 | Tin | 01:30 | 04:00 | [Abrir](J3-2-Tin-llegada.png) | [Abrir](J3-2-Tin-apertura.png) |
| 4 | Tia | 22:00 | 01:00 | [Abrir](J4-1-Tia-llegada.png) | [Abrir](J4-1-Tia-apertura.png) |
| 4 | Fede | 04:00 | 07:00 | [Abrir](J4-2-Fede-llegada.png) | [Abrir](J4-2-Fede-apertura.png) |
| 5 | Cami | 20:30 | 23:30 | [Abrir](J5-1-Cami-llegada.png) | [Abrir](J5-1-Cami-apertura.png) |
| 5 | Mía | 05:00 | 08:00 | [Abrir](J5-2-Mia-llegada.png) | [Abrir](J5-2-Mia-apertura.png) |

`capturas.json` guarda, por comprador, la semilla de su partida, el horario en segundos desde la
apertura, los tres productos sorteados, el texto exacto de la apertura y el recurso de la figura.

Lo que se ve y lo que no:

- Cada pedido tiene tres productos distintos, y los nombres salen en amarillo.
- En la noche 3 los productos salen de los dieciséis de prueba. En las noches 4 y 5, del catálogo completo.
- La captura de Fede muestra a Tia detrás, que se está yendo: el aviso «El cliente se cansó de esperar» es el de su vencimiento.
- Cada captura nace de una partida nueva con su propia semilla. Que la misma semilla repita los pedidos lo prueban los tests, no estas imágenes.

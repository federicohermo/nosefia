# Gráfica de la computadora

Recursos de [Manada — UI](https://www.figma.com/design/SQEAfczyRvyOHokmzPOee7/Manada---UI),
extraídos el 22 de septiembre de 2026. Las escenas usan recursos locales; no dependen de Figma
durante la ejecución.

| Recurso | Origen | Uso |
|---|---|---|
| `fondo.png` | Captura de `almacen.tscn` con los modelos actuales | Fondo compartido, conservando proporciones |
| `fondo_ventanilla.png` | Captura de la ventanilla desde el interior del local | Fondo exclusivo de atención al cliente |
| `cabecera.svg` | Figma, `3:911` / `3:814` | Cabecera de 1712 × 70,3 sobre el lienzo de 1920 × 1080 |
| `linea_detalle.svg` | Figma, `3:912` / `3:446` | Separadores del detalle |
| `solapa.svg` | Figma, `3:913` / `3:448` | Solapa sobre el separador |
| `computadora.svg` | Figma, instancia `112:411` | Ícono de la opción Registro, en la navegación derecha |
| `registro.svg` | Figma, componente `3:983` | Ícono de la opción Notas, en la navegación derecha |
| `actroncito.png`, `durextra.png`, `burbaloo.png` | Mallas actuales de `assets/models/producto_*.res` | Tarjetas y detalle de los productos del día |
| `unscii-16.ttf` | [Unscii, de Viznut](https://github.com/viznut/unscii) | Tipografía local, variante 16; licencia en `LICENSE-unscii.txt` |
| `tema.tres` | Adaptación a Godot | Colores, fuente, botones, campos, paneles y estados de foco |

Las tres miniaturas son renders transparentes de 512 × 512 del modelo del juego.
Usan las mallas de `contenido_del_estante.tscn`, con la cámara orientada hacia el frente de cada
envase. No usan productos de ejemplo de Figma que no existen en el registro actual.

El fondo se capturó en Godot a 1920 × 1080, sin HUD, desde la posición inicial del jugador,
con su cámara apuntando a `(0.5, 1.0, -3.0)`. Conserva los muebles, productos y texturas actuales.
El velo azul oscuro de la escena de UI aplica el tratamiento visual de Figma sobre esa captura;
la imagen no contiene modelos ni iluminación tomados del fondo antiguo de Figma.

La adaptación conserva las acciones del juego: registrar con un clic y escribir notas libres.
Las notas usan lista y detalle; no representan logros ni pistas desbloqueables. Las cantidades,
los precios y los estados del registro salen del dominio. Las opciones Registro y Notas permanecen
visibles como íconos a la derecha, con la opción actual marcada y el nombre al pasar el cursor.
El título izquierdo sólo indica la pantalla actual. El código de Chats permanece disponible, sin
acceso desde la navegación de esta entrega.

El lienzo escala uniformemente dentro del viewport. No cambia la resolución del juego, la cámara
ni el avance del turno. El clic derecho conserva la salida al local. Esta entrega no incorpora
inicio, guardado, opciones ni logros.

La ventanilla adapta la composición de Chats (`40:64`): comprador a la izquierda, pedido en el
panel central y aviso y acciones de cobro a la derecha. Usa los datos y las señales de atención
existentes, sin agregar conversaciones, retratos, contactos ni reglas de venta. El pedido y sus
importes se muestran tal como los entrega `Atencion`; el turno sigue corriendo.

Su fondo se capturó a 1920 × 1080, sin HUD, desde `(5.35, 1.74, 6.174)`, mirando hacia
`(5.35, 1.74, 7.974)`. Muestra el hueco y el antepecho de la ventanilla desde el lugar del empleado.

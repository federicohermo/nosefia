# Gráfica de la computadora

Recursos de [Manada — UI](https://www.figma.com/design/SQEAfczyRvyOHokmzPOee7/Manada---UI),
extraídos el 22 de septiembre de 2026. Las escenas usan recursos locales; no dependen de Figma
durante la ejecución.

| Recurso | Origen | Uso |
|---|---|---|
| `fondo.png` | Figma, `3:885` / `3:378` | Fondo compartido, conservando proporciones |
| `cabecera.svg` | Figma, `3:911` / `3:814` | Cabecera de 1712 × 70,3 sobre el lienzo de 1920 × 1080 |
| `linea_detalle.svg` | Figma, `3:912` / `3:446` | Separadores del detalle |
| `solapa.svg` | Figma, `3:913` / `3:448` | Solapa sobre el separador |
| `computadora.svg` | Figma, instancia `112:411` | Identificación de la computadora en la cabecera |
| `registro.svg` | Figma, componente `3:983` | Recurso disponible para futuras pantallas |
| `actroncito.png` | Figma, `3:967` | Tarjeta y detalle del producto |
| `durextra.png`, `burbaloo.png` | Mallas actuales de `assets/models/producto_*.res` | Tarjetas y detalle de los otros productos del día |
| `unscii-16.ttf` | [Unscii, de Viznut](https://github.com/viznut/unscii) | Tipografía local, variante 16; licencia en `LICENSE-unscii.txt` |
| `tema.tres` | Adaptación a Godot | Colores, fuente, botones, campos, paneles y estados de foco |

Las miniaturas de Durextra y Burbaloo son renders transparentes de 512 × 512 del modelo del juego.
Conservan la orientación de `contenido_del_estante.tscn`. No usan productos de ejemplo de Figma
que no existen en el registro actual.

La adaptación conserva las acciones del juego: registrar con un clic y escribir notas libres.
Las notas usan lista y detalle; no representan logros ni pistas desbloqueables. Las cantidades,
los precios y los estados del registro salen del dominio. Las pestañas visibles son Registro y
Notas. El código de Chats permanece disponible, sin acceso desde la navegación de esta entrega.

El lienzo escala uniformemente dentro del viewport. No cambia la resolución del juego, la cámara
ni el avance del turno. El clic derecho conserva la salida al local. El ícono de computadora es
decorativo; no abre un menú. Esta entrega no incorpora inicio, guardado, opciones ni logros.

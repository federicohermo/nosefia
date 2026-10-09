# Gráfica de la computadora

Recursos de [Manada — UI](https://www.figma.com/design/SQEAfczyRvyOHokmzPOee7/Manada---UI),
extraídos el 22 de septiembre de 2026. Las escenas usan recursos locales; no dependen de Figma
durante la ejecución.

| Recurso | Origen | Uso |
|---|---|---|
| `fondo.png` | Captura histórica de `almacen.tscn` | Recurso conservado; la computadora actual usa un shader |
| `fondo_ventanilla.png` | Captura de la ventanilla desde el interior del local | Fondo exclusivo de atención al cliente |
| `fondo_inicio.png` | Figma, `217:533` («FONDO 4 1»), la estación de servicio de luz cálida | Fondo del menú de inicio |
| `titulo_inicio.png` | Figma, grupo `112:388` del frame «UI INICIO» (`13:1075`) | Título del menú de inicio |
| `cabecera.svg` | Figma, `3:911` / `3:814`; `13:1090` / `13:1092` es el mismo trazo | Cabecera de 1712 × 70,3 sobre el lienzo de 1920 × 1080, y las barras del menú de inicio: la de abajo, girada |
| `linea_detalle.svg` | Figma, `3:912` / `3:446` | Separadores del detalle |
| `solapa.svg` | Figma, `3:913` / `3:448` | Solapa sobre el separador |
| `puntos_de_carga.svg` | Figma, las elipses del frame «UI INICIO» (`105:97`) | Puntos del marco de la pantalla de carga, sobre el lienzo de 1920 × 1080; las líneas son `cabecera.svg` |
| `computadora.svg` | Figma, instancia `112:411` | Ícono de la opción Registro, en la navegación derecha |
| `registro.svg` | Figma, componente `3:983` | Ícono de la opción Notas, en la navegación derecha |
| `<producto>.png`, una por producto del catálogo | Mallas actuales de `assets/models/producto_*.res` | Filas de la planilla de registro |
| `unscii-16.ttf` | [Unscii, de Viznut](https://github.com/viznut/unscii) | Tipografía local, variante 16; licencia en `LICENSE-unscii.txt` |
| `tema.tres` | Adaptación a Godot | Colores, fuente, botones, campos, paneles y estados de foco |

Las miniaturas de los productos son renders transparentes de 512 × 512 del modelo del juego.
Usan las mallas de `contenido_del_estante.tscn`, con la cámara orientada hacia el frente de cada
envase. Las de las cabeceras se renderizan sin la inclinación de la rampa.
Las genera `assets/models/generar_miniaturas.gd`, con el comando de su encabezado.
No usan productos de ejemplo de Figma que no existen en el registro actual.

`fondo.png` se capturó en Godot a 1920 × 1080, sin HUD, desde `(6.58, 1.81, 6.93)`, con la
cámara apuntando a `(0.5, 1.0, -3.0)`. Es una referencia histórica del local. La computadora
actual dibuja una viñeta oscura con `src/ui/diegetica/fondo_de_computadora.gdshader`, sin cargar
esa imagen. El recurso y su importación se conservan.

La adaptación conserva las acciones del juego: anotar lo vendido con «+» y «−» y escribir notas
libres. Las notas usan lista y detalle; no representan logros ni pistas desbloqueables. Las unidades,
los precios y el total de la planilla salen del dominio. Las opciones Registro y Notas permanecen
visibles como íconos a la derecha, con la opción actual marcada y el nombre al pasar el cursor.
El título izquierdo sólo indica la pantalla actual. El código de Chats permanece disponible, sin
acceso desde la navegación de esta entrega.

El lienzo escala uniformemente dentro del viewport. No cambia la resolución del juego, la cámara
ni el avance del turno. El clic derecho conserva la salida al local. Esta entrega no incorpora
guardado, opciones ni logros.

La ventanilla adapta la composición de Chats (`40:64`): comprador a la izquierda, pedido en el
panel central y aviso y acciones de cobro a la derecha. Usa los datos y las señales de atención
existentes, sin agregar conversaciones, retratos, contactos ni reglas de venta. El pedido y sus
importes se muestran tal como los entrega `Atencion`; el turno sigue corriendo.

Su fondo se capturó a 1920 × 1080, sin HUD, desde `(5.35, 1.74, 6.174)`, mirando hacia
`(5.35, 1.74, 7.974)`. Muestra el hueco y el antepecho de la ventanilla desde el lugar del empleado.

`fondo_ventanilla.png` usa compresión de GPU de calidad normal, sin mips ni límite de tamaño.
Es una imagen opaca; en el export web Compatibility con S3TC se importa como DXT1. Conserva
los bytes del PNG, su UID, su ruta y sus 1920 × 1080 píxeles. La compresión tiene pérdida: se
revisó su apariencia con el velo azul oscuro, los textos y los controles de la escena.

DXT1 declara 1.036.800 bytes lógicos para este fondo, frente a los 8.294.400 de RGBA8. Es
almacenamiento lógico de textura, no una medición de VRAM física: excluye las copias de CPU
y la memoria interna del driver. El peso del PCK se compara por separado y no es memoria de
texturas. El fondo y el título del inicio conservan su importación actual; la prueba comprimida
del fondo de inicio mostró artefactos visibles y no fue la variante aceptada.

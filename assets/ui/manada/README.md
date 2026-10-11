# Gráfica de la computadora

Recursos de [Manada — UI](https://www.figma.com/design/SQEAfczyRvyOHokmzPOee7/Manada---UI),
extraídos el 22 de septiembre de 2026. Las escenas usan recursos locales; no dependen de Figma
durante la ejecución.

Las dos notas del corcho usan los SVG originales del frame
[notas (`482:827`)](https://www.figma.com/design/SQEAfczyRvyOHokmzPOee7/Manada---UI?node-id=482-827),
descargados el 9 de octubre de 2026 en `notas/`: papeles `482:831` y `482:833`,
títulos `482:836`, `482:869` y `482:900`, y subrayados `482:938`, `482:994` y `482:1045`.
Se conservan los archivos vectoriales sin editar. El mundo y la lectura ampliada componen
esas mismas piezas. Las hojas conservan la proporción A4 y se amplían 2,4 veces en el corcho
para poder leerlas desde el mostrador. La quinta tarea sigue saliendo de la jornada,
como pide Notion; no se fija «Ordenar cajas» por el texto de ejemplo del frame.

`notas/orange_lovely.otf` es la tipografía del frame, Orange Lovely de Origin Type,
obtenida de la distribución del autor en DaFont. Se conservan `LICENCIA.txt` y
`OriginFonts-EULA.pdf`: esa distribución permite uso personal y exige licencia para uso
comercial. La incorporación al build local no acredita una licencia comercial.

| Recurso | Origen | Uso |
|---|---|---|
| `enrique.png` | Figma, capa `511:317` del frame de instrucciones `511:302`, descargada sin editar el 2026-10-10 | Retrato de Enrique Peldaño en las instrucciones y en el celular |
| `fotos/intro-<NN>.png` | Renders del modelo jugable, generados sin editar el PNG: Intro 4 en 960 × 674, Intro 9 en 640 × 640 y las restantes en 960 × 540 | Fotos adjuntas a las instrucciones de Enrique |
| `celular.svg` | Dibujo vectorial original del proyecto, creado el 2026-10-10 | Recordatorio del celular con Q |
| `persiana_gris.tres` | Material común sobre la textura real del portón, aprobado por el usuario | Fondo de la intro y persiana de entrada de cada noche |
| `notificacion_salida.svg` | Símbolo `480:341`, aviso `477:216` de Figma, descargado sin editar el 2026-10-09 | Cliente cansado de esperar |
| `notificacion_cliente.svg` | Figma, grupo `213:191` del frame `243:150` | Símbolo original del aviso «¡HAY UN CLIENTE!» |
| `notificacion_lectura.svg` | Figma, grupo `480:319` del frame `477:243` | Cruz original del aviso «NO SE PUDO LEER» |
| `fondo.png` | Captura histórica de `almacen.tscn` | Recurso conservado; la computadora actual usa un shader |
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
El título izquierdo sólo indica la pantalla actual. Los chats se consultan en el celular, que se abre con Q; la computadora ofrece Registro y Notas.

El lienzo escala uniformemente dentro del viewport. No cambia la resolución del juego, la cámara
ni el avance del turno. El clic derecho conserva la salida al local. Esta entrega no incorpora
guardado, opciones ni logros.

La ventanilla adapta la composición de Chats (`40:64`): comprador a la izquierda, pedido en el
panel central y aviso y acciones de cobro a la derecha. Usa los datos y las señales de atención
existentes, sin agregar conversaciones, retratos, contactos ni reglas de venta. El pedido y sus
importes se muestran tal como los entrega `Atencion`; el turno sigue corriendo.

La ventanilla muestra el marco 3D real del local. Al abrir, la cámara encuadra los bordes
visibles del dintel y del antepecho a sus profundidades reales; al salir recupera su reposo.
El velo, los textos y los controles siguen delante de esa vista. No carga una imagen del local.

Las siete fotos del jefe se generan con `assets/models/generar_fotos_del_jefe.gd` desde
`almacen.tscn` en la jornada 1. El generador valida el rayo central de cada encuadre antes de
guardar; usa una estantería preparada sólo para Intro 9 y restaura las 31 poses originales
antes de Intro 13. No cambia el reparto jugable. Los PNG se conservan tal como los escribe Godot.

Desde PowerShell, con una pantalla disponible:

```powershell
& $env:GODOT_BIN --path . --rendering-driver opengl3 `
  --script assets/models/generar_fotos_del_jefe.gd -- assets/ui/manada/fotos
```

| Foto | Tema |
|---|---|
| `intro-04.png` | Nota de tareas del corcho |
| `intro-06.png` | Ventanilla |
| `intro-07.png` | Lector y caja registradora |
| `intro-08.png` | Computadora |
| `intro-09.png` | Estantería del depósito con cajas |
| `intro-11.png` | Útiles de limpieza y las dos notas del baño |
| `intro-13.png` | Depósito con las cajas de la primera noche en el piso |

Las instrucciones iniciales siguen los doce frames de Figma desde `511:302` hasta `535:1361`.
Son pantallas independientes: los primeros cuatro párrafos se agrupan de a dos y el contenido se
reemplaza sin scroll. Por aclaración del usuario, el panel de Enrique y su bocadillo permanecen
en las doce pantallas, aunque los frames posteriores al cuarto lo omitan. La navegación,
el contador y la ayuda permanecen fijos. Se inspeccionaron reacciones y motion: esos frames no
contienen transiciones ni keyframes configurados; se conserva la subida autorizada de 0,3 s.

Los recursos originales de Figma en `instrucciones/`, descargados sin editar el 2026-10-10, son:
`bocadillo.svg` (`559:1353`), `separador.svg` (`561:361`), `caja.png` (`526:1066`) y `ticket.png`
(`556:1287`). Caja y ticket son las ilustraciones auxiliares de la pantalla 5. Las siete fotos
continúan siendo capturas del juego, como pide Notion, en sus espacios correspondientes; se
conserva la foto de Intro 13 aunque el frame de Figma no la incluya. Las fotos cubren su marco
sin franjas negras y conservan su proporción; el encuadre de cada captura debe mantener visible
el objeto que ilustra. Por aclaración del usuario, la última pantalla omite «SI A JUGAR!!».

El fondo usa directamente `assets/models/SEPT_JUEGOS_PROTOTIPO_textura portón.png`, sin editar
esa textura ni el modelo. El usuario aprobó el preview «Aplicar este fondo» el 2026-10-10:
`instrucciones/porton_gris.gdshader` reproduce exactamente su recorte UV, conversión a gris y
luminosidad 0,48. Sustituye la persiana azul del prototipo por el portón real en gris.
La intro y la persiana que sube comparten `persiana_gris.tres`, textura y modo de ajuste.
La imagen azul anterior se retira para que no reaparezca en ninguna de esas vistas.

El retrato local histórico
incluía un rectángulo opaco celeste: la pantalla usa ahora `instrucciones/enrique.png`, la imagen
fuente transparente de `511:317`, sin editar. `enrique.gdshader` aplica su exposición y el blur
progresivo hacia los pies del diseño. El chat conserva su recurso histórico y no se modifica.

El encuadre de Intro 4 es ortográfico, frontal al corcho completo y sus dos notas. Intro 9
encuadra las tres alturas del estante de cajas de frente, sin objetos que lo oculten. Las
proporciones se ajustan al marco de presentación para evitar franjas negras sin perder el tema.
Intro 7 muestra la caja registradora y el lector de frente, próximos y completos en el encuadre.
Intro 11 agrupa la mopa y el balde junto a los jabones en sus posiciones jugables, con números
que corresponden a la leyenda: 1 mopa, 2 balde y 3 productos de limpieza. Intro 13 muestra las
pilas del proveedor desde el frente, con sus pallets visibles y sin estantes delante.

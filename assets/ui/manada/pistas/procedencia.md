# Fotos de pistas de jornada 2

La foto 2A es una captura del mensaje de Yasmín que dispara la pista, tal como lo dibuja el
celular. El usuario la pidió el 18 de octubre de 2026 en lugar del círculo de su contacto.
La genera `capturar_mensaje_de_yasmin.gd`, con la salida fuera del checkout.
La foto 2B se captura con `capturar_colilla.gd` sobre la colilla y el piso reales de la escena.
La malla se regenera con `assets/props/colilla/generar_colilla.py`; conserva fuente y resultado versionados.
No hay foto ni pista ficticia para 2P.

## Foto de perfil de Yasmín (pista 5B)

`yasmin-perfil.png` es la foto de perfil de Yasmín que entregó el artista, copiada sin cambios.
El usuario la eligió el 30 de octubre de 2026 como foto de la pista 5B.

| Dato | Valor |
|---|---|
| Rama de origen | `modelossupermercado` |
| Revisión fijada | `eecee1a002b0fd8624c574e556c3a62044288dbe` (27 de octubre de 2026) |
| Ruta en esa revisión | `assets/personajes/Yasmin/Yasmin_01.png` |
| Blob de git | `e9dc09ffa077a5808d58bfa993484f63b27e61d2` |
| SHA-256 | `17f2b29fb57364d75683eb9a50c7beb49a506f46de1d65f002bdbc295dc42a77` |
| Tamaño | 1086 × 1448, RGBA |

Si la tarjeta de pista recorta la imagen, el recorte se hace en la tarjeta y no en el archivo.

## La nota de Yasmín (pista 6C)

`nota-bajo-la-puerta.png` es la textura de la nota: el texto de la ficha de la pista 6C, con
letra manuscrita, sobre `assets/models/SEPT_JUEGOS_PROTOTIPO_nota sin texto.png`, el papel del
artista. Por decisión del usuario del 3 de noviembre de 2026, la hace el implementador y no un
issue de arte aparte. La genera `assets/props/nota/generar_nota.py` con la fuente Ink Free de
Windows y un azar fijo. El texto es el de la nota de la ficha, con «Yasmín» donde la ficha dice
«Jazmín».

`nota-examinada.png` es la foto de la pista: una captura de la nota examinada, con la mano y la
cámara reales del jugador, en la jornada 6 con la 5B elegida. La genera `capturar_nota.gd`, con
la salida fuera del checkout y `NOSEFIA_CAPTURA_AISLADA=741`.

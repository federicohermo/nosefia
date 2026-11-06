# Fotos de pistas

La foto 2A es una captura del mensaje de Yasmín que dispara la pista, tal como lo dibuja el
celular. El usuario la pidió el 18 de octubre de 2026 en lugar del círculo de su contacto.
La genera `capturar_mensaje_de_yasmin.gd`, con la salida fuera del checkout.
La foto 2B se captura con `capturar_colilla.gd` sobre la colilla y el piso reales de la escena.
La malla se regenera con `assets/props/colilla/generar_colilla.py`; conserva fuente y resultado versionados.
No hay foto ni pista ficticia para 2P.

## Foto de perfil de Yasmín (pista 5B)

`yasmin-perfil.png` es la foto de perfil de Yasmín que entregó el artista, copiada sin cambios.
El usuario la eligió el 30 de octubre de 2026 como foto de la pista 5B.
El artista reemplazó el archivo el 3 de noviembre de 2026 (commit `236a970a`): borró
`assets/personajes/Yasmin/Yasmin_01.png` y agregó `Yasmin.png`, un diseño nuevo.

| Dato | Valor |
|---|---|
| Rama de origen | `modelossupermercado` |
| Revisión fijada | `4eb137ae44684b0e23ca509a611dc2d660afee53` (4 de noviembre de 2026) |
| Ruta en esa revisión | `assets/personajes/Yasmin/Yasmin.png` |
| Blob de git | `66e1e215ad339b4c65a3e7976e3cd5b8f1b988b6` |
| SHA-256 | `aabe7af42805bac9fc32c5533290dfa4be8251eb22bace10c7fc7b5748744bd8` |
| Tamaño | 1254 × 1254, RGB |

Si la tarjeta de pista recorta la imagen, el recorte se hace en la tarjeta y no en el archivo.

## La nota de Yasmín (pista 6C)

`nota-bajo-la-puerta.png` es la textura frontal de la nota: el nodo `1865:867` de «Manada - UI» en
Figma («Textura frontal de la pista 6C», 1342 × 986). La exportación trae un fondo liso que no es
del papel; `assets/props/nota/generar_nota.py` pasa a transparente ese fondo y deja el papel como
está. Se tomó de la captura que entrega Figma (1342 × 987), de SHA-256
`6165afbb02a508129b19803c3b1e791a84db18286d62c8cac8c93605dfa3ffd9`. `nota-dorso.png` es el mismo
contorno en blanco, de la misma generación. El texto es el de la ficha, con «Yasmín» donde la
ficha dice «Jazmín».

`nota-examinada.png` es la foto de la pista: una captura de la nota examinada, con la mano y la
cámara reales del jugador, en la jornada 6 con la 5B elegida. La genera `capturar_nota.gd`, con
la salida fuera del checkout y `NOSEFIA_CAPTURA_AISLADA=741`.

## El documento impreso (pista 6B)

`documento-impreso.png` es la textura frontal del documento: el nodo `1865:1063` de «Manada - UI»
en Figma («Textura frontal de la pista 6B», 967 × 1310). La exportación trae un fondo liso que no
es del papel; `assets/props/documento/generar_documento.py` pasa a transparente ese fondo y deja el
papel como está. La exportación original pesa lo que pesa su SHA-256:
`9b48a2c392ea3eef9dbbeef6e70104dd70d59d4b16973b7764e51aff47d1dbdb`. `documento-dorso.png` es el
mismo contorno en blanco, de la misma generación.

`documento-examinado.png` es la foto de la pista: una captura del documento examinado, con la mano
y la cámara reales del jugador, en la jornada 6 con la 5A elegida. La genera
`capturar_documento.gd`, con la salida fuera del checkout y `NOSEFIA_CAPTURA_AISLADA=789`.

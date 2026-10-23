# Procedencia de los sprites de Fede y Mía

Los dieciséis PNG proceden de la revisión fijada
[`62390898635a04fbb1b6a29558355a5e1984684f`](https://github.com/federicohermo/nosefia/tree/62390898635a04fbb1b6a29558355a5e1984684f/assets/personajes)
de los originales indicados por el usuario en `modelossupermercado` para #437.
La copia inicial conservó exactamente los bytes de cada blob de esa revisión. Las imágenes
no se recortaron, reescalaron ni recomprimieron, y no se modificó su alfa. Los archivos de Cami
permanecen fuera de esta entrega.

Los PNG de uso reciben después la [limpieza reproducible del alfa](README.md#limpieza-del-alfa).
Los hashes de la tabla identifican los originales anteriores a esa limpieza.

Cada PNG tiene 1086 × 1448 píxeles, profundidad de 8 bits y tipo de color PNG 6 (RGBA).
Se verificaron la firma, el encabezado y los CRC de todos sus chunks, además de SHA-256
y la igualdad binaria contra el blob Git original.

| Ruta original en la revisión fijada | Ruta de uso en el juego | Blob Git original | SHA-256 del PNG original |
|---|---|---|---|
| `assets/personajes/Fede/Fede 01.png` | `assets/characters/fede/01.png` | `aa376a28e75570905b8478807dcb30dd235c1f8b` | `e2f3b77484e9eadf18c208a4280c64388e69a164b5cb856743f773b561524d06` |
| `assets/personajes/Fede/Fede 02.png` | `assets/characters/fede/02.png` | `cc6b1d41c0a2e97dde7565bfd8c360a981cc17db` | `65edcdc00a3be9e2898957c8a9cf1a32a5e1d4ef253759b82f3d0ee40add16d5` |
| `assets/personajes/Fede/Fede 03.png` | `assets/characters/fede/03.png` | `54573bc26265a17e3aa00061acee1cc00c49116d` | `21f8eb974f8e597fd11ebe8990155318d1438dc150dc7c1d2a13665f1dbc6229` |
| `assets/personajes/Fede/Fede 04.png` | `assets/characters/fede/04.png` | `9b68a0757f81820be98892b8ded12afd947f0c78` | `5d3758d1560b8f97d522f78dbcfd36414fa8871e63a67d31dfb65c2c220fd967` |
| `assets/personajes/Fede/Fede 05.png` | `assets/characters/fede/05.png` | `c9cd80286899c28991a846ed812eeceb969810c5` | `7d105511e96ce0be061ee2a29ca17508c50617f1fff7af67b1ce64c18a49ede9` |
| `assets/personajes/Fede/Fede 06.png` | `assets/characters/fede/06.png` | `302982a7705dd98d06a516bd3ff2516ba74085ef` | `e3e9ce5595acbb80fcde979eac8804b4834da52bcf90770e5c3561c831c4b675` |
| `assets/personajes/Fede/Fede 07.png` | `assets/characters/fede/07.png` | `16b2d5f6d188895e4779fe34db815db2191f7cb2` | `fba41cdb83d9b4348a7b9167037ce84d766d508717c3156b491997b21c7da86c` |
| `assets/personajes/Fede/Fede 08.png` | `assets/characters/fede/08.png` | `ce8632a15cfbdaf51f87aa23f39e23b8a5ed6585` | `10c98fcd0f51324f2bc4d176df743af5303fd886939a96def1b1c279fcdcba09` |
| `assets/personajes/Mia/miaidle_01.png` | `assets/characters/mia/01.png` | `7a829d5423942e617bd6950e4476054745e03e26` | `908de72357f180f3184c0cdcfe0d14f501ccda2ed99b4afa44565c0b51fdd580` |
| `assets/personajes/Mia/miaidle_02.png` | `assets/characters/mia/02.png` | `40c17e521b1c3f43b75561d3cfa0a67c58b69166` | `f5114c392b0c2fb4e4f4276614982759e8a46a0add8ad7bcef1b3efed5cab1e4` |
| `assets/personajes/Mia/miaidle_03.png` | `assets/characters/mia/03.png` | `88e8987a758554d630fb2d78f93227538e14a2f7` | `bfbaade048cca58903047dcdeba0e5aad4268760efd215c649050b3b2eb584e7` |
| `assets/personajes/Mia/miaidle_04.png` | `assets/characters/mia/04.png` | `d1aa1e703f7fbe85360e54a10efa19a663188b59` | `0302a97b51afb0140080180a31a69ae42eb83d88c11eb6da0c7955270336c509` |
| `assets/personajes/Mia/miaidle_05.png` | `assets/characters/mia/05.png` | `92ab73b32b8eb8cf6728e3100d69ec6760059479` | `bdb1645019c7b390682b527c8cacd8b67aecdf2b7c783cd886fe4c3cd0548485` |
| `assets/personajes/Mia/miaidle_06.png` | `assets/characters/mia/06.png` | `2c6a5c2e6cbaef7cfca01c27ff9201504be536af` | `92cfbb5eab8025b1c3b7f1a3d7e5c9919d06c2d576e7ab138b9567a439e02238` |
| `assets/personajes/Mia/miaidle_07.png` | `assets/characters/mia/07.png` | `e6d14e63cb4704538192ea2c681b99cdf9acaecf` | `f7721f7eb358687edc768afe18c8ef558b8ae58cae90e89b394f464912498096` |
| `assets/personajes/Mia/miaidle_08.png` | `assets/characters/mia/08.png` | `77d3a20537f8444e83e48e5faa2ab44917a76344` | `83ad7bb3964807c0eaf1607f8602b32c14f93508957cb5868cf9e43fff64d506` |

Cada carpeta de destino contiene `01.png` a `08.png` e `idle.tres`.
Los `SpriteFrames` se escribieron siguiendo el formato existente de Martín y Tiago en
[`5c30cc5374801343dad202d387270b2966e9c649`](https://github.com/federicohermo/nosefia/commit/5c30cc5374801343dad202d387270b2966e9c649),
entregado por #429: una animación `idle`, ocho cuadros en orden 01–08, bucle activo,
velocidad `2.0` y duración relativa `1.0` por cuadro. Sólo se adaptaron las rutas de
textura a `res://assets/characters/fede/` y `res://assets/characters/mia/`.
Se conserva el ritmo existente; no se deduce uno nuevo de un video.

La preparación estática no inventa UIDs ni archivos de importación. Godot genera
los `.png.import` al importar estos PNG en el carril de implementación. La validación
estática de bytes y del recurso no sustituye la carga real de `SpriteFrames`, las pruebas
de identidad/foco/oclusión ni la comprobación del paquete Web que corresponden a #437.
La tabla de presentación y la activación de agenda se implementan en sus issues dueños.

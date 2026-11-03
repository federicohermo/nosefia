# Procedencia de los sprites de Enrique

Los seis PNG proceden de la revisión fijada
[`46313c330d6529a7918cb8b1070a016efa267cc9`](https://github.com/federicohermo/nosefia/tree/46313c330d6529a7918cb8b1070a016efa267cc9/assets/personajes/Enrique%20Pelda%C3%B1o)
de `modelossupermercado`.
La copia inicial conserva los bytes de cada blob, incluida la resolución y el alfa.
Cada original mide 1086 × 1448 píxeles, con ocho bits por canal y color RGBA, sobre fondo transparente.

`enrique_07.png` de la rama es idéntico byte a byte a `enrique_01.png` (blob
`0b33076d79f4940dc43a18293fc12f8918402dc0`). No se copia: el bucle de seis cuadros cierra en 01.

Los PNG de uso reciben después la [limpieza compartida del alfa](README.md#limpieza-del-alfa).
Los hashes siguientes identifican los originales anteriores a la limpieza.
La limpieza conserva dimensiones y RGB. No se recortan ni se reescalan las figuras.

| Ruta original en la revisión fijada | Ruta de uso en el juego | Blob Git original | SHA-256 del PNG original |
|---|---|---|---|
| `assets/personajes/Enrique Peldaño/enrique_01.png` | `assets/characters/enrique/01.png` | `0b33076d79f4940dc43a18293fc12f8918402dc0` | `37ff00444fa114a65711a82849df6f05062cadbd2b32a74297bd0bd3424b8690` |
| `assets/personajes/Enrique Peldaño/enrique_02.png` | `assets/characters/enrique/02.png` | `27fd9a47d1774a887cfe6cab60d9dd0f476d0897` | `8c3453d976d900a974768fc0c3bae0d414983a44459d74ff89e39369a9a18bab` |
| `assets/personajes/Enrique Peldaño/enrique_03.png` | `assets/characters/enrique/03.png` | `53800976dc1e2c25e2afb5499d33791a4a668a9e` | `d3e9455b87b3637a846b859bf801059ee50d8adeda24bb8d64f75a9b8c1f58ea` |
| `assets/personajes/Enrique Peldaño/enrique_04.png` | `assets/characters/enrique/04.png` | `e9853ad75a535795a7f0468c27b5246a2b3252f7` | `1c39600db18a689076f33b4d62ee545dbc90cb02e86c18a7bec30eaf96312593` |
| `assets/personajes/Enrique Peldaño/enrique_05.png` | `assets/characters/enrique/05.png` | `13ebebfaa6fd6981a853d027f5ecb6ec957ea87b` | `af293f23ca2df3cf42d655d1e5557235b605ab80a01e6155fdb1ee99cc8b0eb7` |
| `assets/personajes/Enrique Peldaño/enrique_06.png` | `assets/characters/enrique/06.png` | `e240251eea96bc9d76c5ff2417e78141c7687ce3` | `716aeea7c4cd43ac460b0d6291e2fce21f8a52f6b3f053df1814358453c12d91` |

`enrique/idle.tres` conserva el ritmo de los compradores: seis cuadros en orden 01 a 06,
bucle activo, velocidad 2.0 y duración relativa 1.0. El ciclo dura 3 s.
Godot genera los `.png.import`. Usan compresión con pérdida, modo 1 y calidad 0.7, como los compradores.
La pantalla de instrucciones lo reproduce con `AnimatedSprite2D`, escala 455 / 1086, en el lugar de `1676:1052`.

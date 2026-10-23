# Procedencia de los sprites de Cami

Los ocho PNG proceden de la revisión fijada
[`62390898635a04fbb1b6a29558355a5e1984684f`](https://github.com/federicohermo/nosefia/tree/62390898635a04fbb1b6a29558355a5e1984684f/assets/personajes/Cami)
de `modelossupermercado`.
La copia inicial conserva los bytes de cada blob, incluida la resolución y el alfa.
Se verificaron SHA-256, igualdad binaria, cabecera PNG y CRC de todos los chunks.
Cada original mide 1086 × 1448 píxeles, con ocho bits por canal y color RGBA.

Los PNG de uso reciben después la [limpieza compartida del alfa](README.md#limpieza-del-alfa).
Los hashes siguientes identifican los originales anteriores a la limpieza.
La limpieza conserva dimensiones y RGB. No se recortan ni se reescalan las figuras.
Una segunda aplicación no modifica los PNG limpios.

| Ruta original en la revisión fijada | Ruta de uso en el juego | Blob Git original | SHA-256 del PNG original |
|---|---|---|---|
| `assets/personajes/Cami/cami idle_01.png` | `assets/characters/cami/01.png` | `c2cfafb0579a39d187d49e3a77025941f1f6f8c6` | `882d1cb8a3e34a49ca61c24e2e4b209674c98277d159007384702f66da330e19` |
| `assets/personajes/Cami/cami idle_02.png` | `assets/characters/cami/02.png` | `57782638c45b5695fe01af59f8f2a633e2dcff50` | `eee9981e7cc48fcc83dd53097d1e8e71fd316169c4c7d49094b3cc03b6321860` |
| `assets/personajes/Cami/cami idle_03.png` | `assets/characters/cami/03.png` | `048a05634b73bd83948224c627160a455433d880` | `d7e7126a7694001005689d3c219a4fb4fb5b3f6fbfb78b4a9d8197bba28a06f1` |
| `assets/personajes/Cami/cami idle_04.png` | `assets/characters/cami/04.png` | `565167fc309dfa6c24dfc900db5e562e4dfe38df` | `0191efcad35024548ef425f38df65ba519a5ef107dffb749c6f6f9935f3d35f0` |
| `assets/personajes/Cami/cami idle_05.png` | `assets/characters/cami/05.png` | `c0ebf6beb94a484782fa826799b2bd213806d366` | `25fc62b1f915e8973ea73c7144aee61ac2ae7475f5c7c6d3caf2b6e5c8c5a3bb` |
| `assets/personajes/Cami/cami idle_06.png` | `assets/characters/cami/06.png` | `2bec1a2c36ef5527c5d6c0039b1342d05aecae1c` | `878d1e0058f9648d817a953092bcc9ed336493f9399355197ea337b08ccf61d6` |
| `assets/personajes/Cami/cami idle_07.png` | `assets/characters/cami/07.png` | `626cf2ef32e5fcd2ee0550dc4fee098e3780d88d` | `888fa245c8c11701b0f56e695559f69cb34cc1c191cc003d315d71abcaf2b3e6` |
| `assets/personajes/Cami/cami idle_08.png` | `assets/characters/cami/08.png` | `c52dc72f0ee84544d389e210c0174cbb9b409de6` | `65acada5e3575d1e282db00b31a7741f3f2d9196c4ce1fa82e38defa66402590` |

`cami/idle.tres` conserva el ritmo de Fede y Mía, incorporado por #437.
Tiene ocho cuadros en orden 01 a 08, bucle activo, velocidad 2.0 y duración relativa 1.0.
Godot genera los `.png.import`. Usan compresión con pérdida, modo 1 y calidad 0.7,
como Fede y Mía después de `2959b38c`.

# Audio

De dónde sale cada audio de `assets/audio/` y cómo entra al repo. Qué suena con cada evento lo
dice la tabla de sonidos del dominio, no este doc.

## Cómo entra un audio

1. El original sale de la rama `Sonidos`, que usa el equipo de sonido. No se mergea entera: se
   extraen sólo los archivos del cambio, con `git show <revisión>:assets/audio/<archivo>`.
2. `python .claude/scripts/comprimir_audio.py` lo convierte según el prefijo. `AMB_` y `MUS_`
   pasan a Ogg Vorbis. `SFX_` queda en WAV mono de 22 050 Hz y 16 bits.
3. `--import` de Godot escribe su `.import`. Un audio en bucle lleva `loop=true` en ese archivo.
4. Se corre el compresor otra vez: no tiene que cambiar ningún byte.

El compresor no normaliza el nivel. El nivel lo decide el artista en el original.

## Procedencia

| Archivos | Revisión de `Sonidos` | Conversión |
|---|---|---|
| `SFX_OBJETO_Caja_Alzar.wav`, `SFX_OBJETO_Caja_Dejar.wav`, `SFX_OBJETO_Bolsa_Dejar.wav`, `SFX_NOLEV_Inodoro.wav`, `SFX_INTERFAZ_Celular_Mensaje_Enviado.wav`, `SFX_OBJETO_Mopa_Limpiar.wav` | `a2d6c45e3549a7dfac45c37c870eab5ff81485e8` | WAV mono de 22 050 Hz |
| `AMB_PROXIMIDAD_Exterior.wav` → `.ogg` | `a2d6c45e3549a7dfac45c37c870eab5ff81485e8` | Vorbis mono de 64 kbps, en bucle |
| `MUS_MenuPrincipal.wav` → `.ogg` | `a2d6c45e3549a7dfac45c37c870eab5ff81485e8` | Vorbis estéreo de 80 kbps, en bucle |

Los audios anteriores a esta tabla no registran su revisión.

## Atribución

`MUS_MenuPrincipal`: Remix de Floating on bad conscience by Victor_Natas —
https://freesound.org/s/626545/ — License: Attribution 4.0

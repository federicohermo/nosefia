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

| `SFX_OBJETO_Bolsa_Alzar.wav`, `SFX_OBJETO_BotellaPlastica_Alzar.wav`, `SFX_OBJETO_BotellaPlastica_Dejar.wav`, `SFX_OBJETO_Cajita_Alzar.wav`, `SFX_OBJETO_Cajita_Dejar.wav`, `SFX_OBJETO_Lata_Alzar.wav`, `SFX_OBJETO_Lata_Dejar.wav`, `SFX_OBJETO_Mopa_Alzar.wav` | `a2d6c45e3549a7dfac45c37c870eab5ff81485e8` | WAV mono de 22 050 Hz |
| `SFX_OBJETO_Mopa_Dejar.wav`, `SFX_OBJETO_BotellaVidrio_Alzar.wav`, `SFX_OBJETO_BotellaVidrio_Dejar.wav`, `SFX_OBJETO_CajaCereales_Alzar.wav`, `SFX_OBJETO_CajaCereales_Dejar.wav`, `SFX_OBJETO_Balde_AlzarVacio.wav`, `SFX_OBJETO_Balde_DejarVacio.wav`, `SFX_OBJETO_Basura_Contenedor.wav`, `SFX_OBJETO_Basura_SacarBolsa.wav`, `SFX_OBJETO_Balde_VertirJabon.wav`, `SFX_INTERFAZ_Celular_Mensaje_Recibido.wav`, `SFX_INTERFAZ_PersianaSube.wav`, `SFX_INTERFAZ_PersianaBaja.wav` | `a2d6c45e3549a7dfac45c37c870eab5ff81485e8` | WAV mono de 22 050 Hz |
| `AMB_PROXIMIDAD_Neon.ogg` | `a2d6c45e3549a7dfac45c37c870eab5ff81485e8` | Vorbis mono de 64 kbps, sin recorte, en bucle |

Los audios anteriores a esta tabla no registran su revisión.

**El neón nuevo llega como Ogg de 30 s y 140 kbps.** El compresor no recodifica un Ogg, y
`BUCLES` recortaría con los tiempos del original anterior. Se pasó a 64 kbps con las mismas
banderas del compresor y sin el filtro de recorte. Los niveles son los del artista.

## Qué audio reemplaza a cuál

| Antes | Ahora | Dónde suena |
|---|---|---|
| `SFX_OBJETO_Mopa_DejarYLimpiar` | `SFX_OBJETO_Mopa_Dejar` | La mopa toca algo, se coloca o se devuelve |
| `SFX_OBJETO_Mopa_DejarYLimpiar` | `SFX_OBJETO_Mopa_Limpiar` | Una pasada de la mopa |
| `SFX_OBJETO_Jabon_VertirEnBalde` | `SFX_OBJETO_Balde_VertirJabon` | Un jabón tiñe el agua |
| `SFX_INTERFAZ_Celular_Mensaje_A` y `_B` | `SFX_INTERFAZ_Celular_Mensaje_Recibido` | Llega un mensaje, siempre el mismo |
| `SFX_NOLEV_Basura_SacarBolsa` | `SFX_OBJETO_Basura_SacarBolsa` | Se saca una bolsa del tacho, en lugar de alzarla |
| (sin audio) | `SFX_OBJETO_Basura_Contenedor` | Se desecha algo aceptado en el contenedor |
| `SFX_NOLEV_Puerta_Garage` | `SFX_INTERFAZ_PersianaSube` y `SFX_INTERFAZ_PersianaBaja` | La persiana de la noche, uno por movimiento |
| `SFX_OBJETO_Balde_Alzar` y `_Dejar` | `SFX_OBJETO_Balde_AlzarVacio` y `_DejarVacio` | El balde sin agua |
| `SFX_OBJETO_Cajita_*` y `_BotellaPlastica_*` | `SFX_OBJETO_CajaCereales_*` y `_BotellaVidrio_*` | Los cereales y el Fernet God |

`SFX_NOLEV_Puerta_Garage` sigue en el portón trabado, y `SFX_PERSONAJE_Paso1`–`Paso4` no se
tocaron. Alzar una bolsa suelta sigue sonando `SFX_OBJETO_Bolsa_Alzar`.

## Cómo se prueba el cambio

Los tests verifican cuatro cosas:

- Qué stream pide cada gesto.
- Que el balde se elige por su agua.
- El contexto de sacar una bolsa.
- Que una segunda corrida del compresor no cambia bytes.

**La escucha comparada no la hace un test.** El driver de los tests no mezcla. Una persona
tiene que escuchar estos recorridos en la build web, contra la versión anterior:

- El neón.
- La mopa: tocar, colocar y pasar.
- La botella de vidrio y la caja de cereales: alzar y dejar.
- El balde vacío y el balde lleno.
- La persiana al subir y al bajar.
- Un mensaje nuevo en el celular.
- Sacar una bolsa y desechar algo.

## Atribución

`MUS_MenuPrincipal`: Remix de Floating on bad conscience by Victor_Natas —
https://freesound.org/s/626545/ — License: Attribution 4.0

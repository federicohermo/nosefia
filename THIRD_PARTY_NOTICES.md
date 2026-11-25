# Avisos de terceros

Este archivo lista los componentes de terceros presentes en el repositorio o en sus builds exportados, junto con sus licencias y atribuciones obligatorias. Ninguna licencia propia del repositorio reemplaza las licencias originales listadas acá.

## Motor y librerías de código

| Componente | Ubicación / distribución | Autor / proyecto | Licencia | Notas |
|---|---|---|---|---|
| Godot Engine `4.7.2-stable` (incluye Jolt Physics y FreeType) | Parches en `.github/patches/`; binarios y plantilla web en GitHub Releases y build de Vercel | Juan Linietsky, Ariel Manzur y contribuidores de Godot Engine | MIT (y licencias de terceros de Godot, como FTL para FreeType) | Los builds compilados deben incluir `LICENSE.txt` y `COPYRIGHT.txt` de Godot. Los parches propios incluyen el backport de `godotengine/godot#123546` (MIT). |
| `gdUnit4` v6.2.1 | `addons/gdUnit4/` (excluido del export web) | Mike Schulze (`Copyright (c) 2023 Mike Schulze`) | MIT | Texto completo en `addons/gdUnit4/LICENSE`. |
| Logo por defecto de Godot (`icon.svg`) | `icon.svg` (exportado al build web) | Andrea Calabró / Godot Engine | CC BY 4.0 | Atribución requerida mientras no se reemplace por un ícono propio del juego. |

## Fuentes tipográficas

| Archivo | Fuente y autor | Licencia | Condiciones |
|---|---|---|---|
| `assets/ui/clock/DSEG7Classic-Regular.ttf` | DSEG7 Classic v0.46 por keshikan (`Copyright (c) 2017, keshikan`, `http://www.keshikan.net`) | SIL Open Font License 1.1 | Reserved Font Name: `"DSEG"`. Texto completo en `assets/ui/clock/LICENSE.txt`. |
| `assets/ui/manada/celular/simbolos_de_chat.ttf` | Subconjunto modificado de Google Noto (`Copyright 2013 Google LLC`, `http://www.google.com/get/noto/`) | SIL Open Font License 1.1 | Sin Reserved Font Name. Texto completo en `assets/ui/manada/celular/LICENSE-simbolos_de_chat.txt`. |
| `assets/ui/manada/unscii-16.ttf` | Unscii 16 v1.0 por Viznut (`http://viznut.fi/unscii/`, variante no-full de 3.212 glifos) | Dominio público / CC0 según `assets/ui/manada/LICENSE-unscii.txt` | Solo los archivos derivados de GNU Unifont (`unscii-16-full.*`, no incluidos aquí) caen bajo GPL. |

## Assets con atribución obligatoria (CC BY 4.0)

### Puerta metálica de depósito (`puerta depósito solo jefe`)

- **Ubicación:** `assets/source/third-party/puerta depósito solo jefe/` y derivadas en `assets/source/textures/furniture/Puerta/` y `assets/models/SEPT_JUEGOS_PROTOTIPO_{textura,puerta_solo_empleados,puerta_productos_de_limpieza}.png`.
- **Licencia:** CC BY 4.0 (`http://creativecommons.org/licenses/by/4.0/`).
- **Cambios realizados:** Localización de los carteles a "SOLO EMPLEADOS" y "PRODUCTOS DE LIMPIEZA" y ajustes en manijas/textura.
- **Atribución:** This work is based on "psx "employees only" metal door" (`https://sketchfab.com/3d-models/psx-employees-only-metal-door-8bb63f0b0c454fe1b030ce6eb1031598`) by zynxeror (`https://sketchfab.com/zynxeror`) licensed under CC-BY-4.0 (`http://creativecommons.org/licenses/by/4.0/`).

### Música del menú principal (`MUS_MenuPrincipal.ogg`)

- **Ubicación:** `assets/audio/MUS_MenuPrincipal.ogg` (documentado en `docs/guides/audio.md`).
- **Licencia:** CC BY 4.0 (`https://creativecommons.org/licenses/by/4.0/`).
- **Cambios realizados:** Remix y compresión a Ogg Vorbis en bucle.
- **Atribución:** Remix de "Floating on bad conscience" por Victor_Natas (`https://freesound.org/s/626545/`), bajo licencia Attribution 4.0.

### Balde de pollo frito (sin uso en runtime)

- **Ubicación:** `assets/source/third-party/low_poly_bucket_of_fried_chicken_psx_n64_style/`.
- **Licencia:** CC BY 4.0 (`http://creativecommons.org/licenses/by/4.0/`).
- **Atribución:** This work is based on "Low Poly Bucket of Fried Chicken PSX N64 style" (`https://sketchfab.com/3d-models/low-poly-bucket-of-fried-chicken-psx-n64-style-7751bf7591b84e9892cb745c814b2086`) by zhya (`https://sketchfab.com/zzzhya`) licensed under CC-BY-4.0 (`http://creativecommons.org/licenses/by/4.0/`).

## Assets en dominio público (CC0 1.0)

No exigen atribución legal, pero se registran por trazabilidad:

- **Screaming Brain Studios** (`assets/source/third-party/128x128/`, `assets/source/third-party/License.txt`): CC0 1.0 Universal.
- **Daniel Jurys**, PSX Waste (`assets/source/third-party/psx-waste/SOURCE.md`, `https://daniel-jurys.itch.io/psx-waste`): CC0 1.0 Universal.
- **yethiel**, Trashcan (`assets/source/third-party/trashcan-yethiel/SOURCE.md`, `https://opengameart.org/content/trashcan`): CC0.
- **Omie's Assets**, Office Set (`assets/source/textures/computer/omie/LICENSE.txt`, `https://omies-assets.itch.io/omies-assets-office-set`): CC0.
- **ambientCG / Lennart Demes** (`Plastic001`, `Plastic012A`, `Plastic012B`, `Bricks066`, `Fingerprints005` bajo `assets/source/textures/`): CC0 1.0 Universal.
- **Poly Haven** (`concrete_floor_worn_001` por Dimitrios Savva y Rico Cilliers; `corrugated_iron_02` por Jenelle van Heerden y Sergej Majboroda; `interior_tiles` por Charlotte Baglioni; `painted_plaster_wall` por Amal Kumar; `oak_veneer_01` por Jenelle van Heerden): CC0 1.0 Universal.

## Pendiente de limpieza antes de publicar el repositorio

Los siguientes archivos están hoy en el repositorio bajo licencias propietarias, solo para uso personal o sin procedencia verificada. No están cubiertos por la licencia MIT del archivo `LICENSE` y deben eliminarse o reemplazarse antes de abrir el repositorio públicamente:

1. `addons/godot_mcp/` ("Godot MCP Pro" v1.16.0): plugin comercial sin archivo `LICENSE`, con tres scripts registrados como autoload en `project.godot` y empaquetados en el export web.
2. `assets/ui/manada/notas/orange_lovely.otf` y sus tres texturas horneadas (`SEPT_JUEGOS_PROTOTIPO_tareas_jornada_1.png`, `_mantener_local_ordenado.png` y `_fuera_de_servicio_manuscrito_papel.png`): fuente solo para uso personal (`assets/ui/manada/notas/LICENCIA.txt`).
3. `assets/source/textures/bathroom/poliigon/6956-ivory/1K/` y derivadas `bano_ivory_oscuro_*` (`assets/source/textures/bathroom/final/procedencia.json` y `assets/models/`): texturas de Poliigon no redistribuibles en un repositorio público.
4. `assets/models/Crowbar/psx_crowbar/`, `assets/source/third-party/psx_trash_can/` y `assets/source/third-party/water_bottle/`: modelos bajo Sketchfab Standard, que prohíbe redistribuir los archivos 3D sueltos en un repositorio público.
5. Procedencia sin documentar: 63 archivos de `assets/audio/` (todos excepto `MUS_MenuPrincipal.ogg`) y 4 texturas en `assets/source/third-party/128x128/Bricks/` (`concreto2_baseColor.png`, `marble_baseColor.jpeg`, `piso_baseColor.png`, `techo1_baseColor.jpeg`).

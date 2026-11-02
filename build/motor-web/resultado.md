# Otro motor para la web: el almacén medido en tres motores

Corrida del 2026-11-02, rama `improvement/motor-web`. Equipo: Windows 11, RTX 4050 Laptop, Chrome 156
y Firefox 157 (el de Playwright). Ventana a la vista, sin sonido, 1536×760.

## La respuesta

**Elegí PlayCanvas, con la lógica de Godot corriendo sin dibujar.** PlayCanvas dibuja el almacén. Es el
que mejor midió en todo lo que importa para el jugador. Tiene un límite que hay que saber: no trae
geometría virtual, y Three.js sí tiene una librería para eso. Más abajo está qué cambiaría la elección.

Con el mismo almacén, las mismas texturas y el mismo lightmap, en Chrome:

| | Godot WebGL2 (la web de hoy) | Three.js WebGPU | Three.js WebGL2 | **PlayCanvas WebGL2** |
|---|---:|---:|---:|---:|
| Ver el almacén, primera visita | 12,7 s | 3,5 s | 8,7 s | **2,0 s** |
| Segunda visita | 11,0 s | 2,4 s | 1,7 s | **0,5 s** |
| Memoria de todo Chrome | 1.601 MB | 899 MB | 766 MB | **736 MB** |
| Cuadro en la góndola, sin tope de cuadros | 4,38 ms | 3,58 ms | 5,01 ms | **0,96 ms** |
| Ver el almacén con la CPU 4 veces más lenta | 88 s | 11,2 s | 14,0 s | **2,8 s** |
| Cuadro con la CPU 4 veces más lenta | 25,7 ms | 22,3 ms | 29,6 ms | **5,9 ms** |
| Firefox, ver el almacén, primera visita | 22,5 s | 15,8 s | 26,7 s | **3,9 s** |

Cada celda es la mediana de 5 corridas. Salvo la segunda visita de Godot, la CPU lenta y Firefox con
Godot, que son 3. Los rangos y el comando están en «Qué se midió».

**Los bytes casi no dependen del motor.** El prototipo baja 19,8 MiB y la web de hoy 45,4 MiB. Pero la web
de hoy lleva audio, personajes, UI y el panorama de afuera, que el prototipo no tiene. Lo mismo que lleva
el prototipo pesa unos 25 MiB en Godot. Cambiar de motor ahorra unos 5 de esos 25 MiB y los 4,7 MiB del
wasm de Godot. El resto es contenido. El tope de 100 MB de Vercel no molesta: el archivo más grande del
prototipo pesa 54 MB sin comprimir (19,6 con brotli).

**La imagen sale igual de cerca en los dos prototipos.** Diferencia media contra la web de hoy: de 10 a 22
sobre 255, según la vista. Casi toda viene de lo que los prototipos no tienen (la calle, el stock de la
partida y los reflejos del baño), no del lightmap. Mirá `comparacion.png`.

**La geometría virtual no alcanza hoy para elegir.** Ningún motor la entrega en la web con atómicos de 64
bits. Three.js tiene una librería de la comunidad que no los necesita. Detalle en la unidad 1.

**Lo que cambiaría la elección:** si la geometría virtual va antes que la carga rápida, Three.js. Ninguno
está probado en Safari.

**Primera etapa del port:** dejar el volcado del almacén como paso del export y publicar la página de
PlayCanvas que ya anda. Detalle en la unidad 4.

## Qué se midió, y cómo

Cada lado se midió **cinco veces, alternando el orden en cada ronda**, con un perfil de Chrome nuevo por
corrida. Los cuatro salen del mismo servidor de prueba, con brotli de calidad 11, `ETag` y
`Cache-Control: public, max-age=0, must-revalidate`, como pide `vercel.json`. Chrome con
`CalculateNativeWinOcclusion` apagado y `--mute-audio`. Firefox con `media.volume_scale=0` y
`widget.windows.window_occlusion_tracking.enabled=false`. Puertos 8121 y 8123.

**«Ver el almacén» es lo mismo en los cuatro:** desde que arranca la navegación hasta el primer cuadro con
todos los programas compilados. En Godot incluye el menú, el clic en «Nuevo juego» y el calentamiento,
que son parte de lo que espera la persona. En los visores no hay menú.

**Con vsync a 144 Hz** (la espera que ve una persona), mediana y rango:

| | Primera visita | Segunda visita | Memoria de Chrome | Bytes |
|---|---|---|---|---|
| Godot WebGL2 | 12,66 s (12,59–13,02) | 11,03 s (10,49–11,32), 3 corridas | 1.601 MB (1.589–1.638) | 45,4 MiB |
| Three.js WebGPU | 3,50 s (3,48–3,53) | 2,39 s (2,34–2,42) | 899 MB (895–911) | 19,8 MiB |
| Three.js WebGL2 | 8,67 s (8,43–9,23) | 1,72 s (1,68–2,11) | 766 MB (762–773) | 19,8 MiB |
| PlayCanvas WebGL2 | 2,00 s (1,95–3,80) | 0,51 s (0,50–0,53) | 736 MB (731–745) | 20,0 MiB |

En PlayCanvas, dos de cinco corridas dieron 3,7 y 3,8 s en vez de 2,0 s. No sé por qué. Sospecho que el
caché de sombreadores de la GPU cambia de una corrida a otra, y es una sospecha.

**Sin tope de cuadros** (`--disable-gpu-vsync --disable-frame-rate-limit`), en la góndola. «p95» es el
cuadro que supera al 95 % de los demás:

| | Mediana | p95 | Peor p95 de las seis vistas | Cuadro más largo |
|---|---|---|---|---|
| Godot WebGL2 | 4,38 ms (4,31–4,47) | 5,71 ms | no medido | 9,9 ms, caminando |
| Three.js WebGPU | 3,58 ms (3,49–3,61) | 4,22 ms | 4,22 ms | 5,3 ms |
| Three.js WebGL2 | 5,01 ms (4,69–5,02) | 6,16 ms | 6,16 ms | 6,2 ms |
| PlayCanvas WebGL2 | 0,96 ms (0,90–1,01) | 1,81 ms | 2,69 ms | 21,0 ms |

El cuadro de 21 ms de PlayCanvas sale en las cinco corridas sin tope de cuadros y no sale con vsync. No lo
investigué.

**CPU 4 veces más lenta** (CDP, 3 corridas, sin tope de cuadros): el cuadro de PlayCanvas pasa de 0,96 a
5,9 ms y el de Three.js de 3,58 a 22,3 ms. Los dos escalan unas 6 veces. **Eso dice que el cuadro está
limitado por la CPU y no por la GPU.** Por qué PlayCanvas gasta cuatro veces menos CPU por cuadro no lo
perfilé: es una diferencia medida y no una causa.

**Firefox 157, con tope de cuadros** (5 corridas; Godot 3):

| | Primera visita | Segunda visita |
|---|---|---|
| Godot WebGL2 | 22,5 s (22,1–22,6) | no medida |
| Three.js WebGPU | 15,8 s (15,5–16,2) | 7,9 s (7,7–8,4) |
| Three.js WebGL2 | 26,7 s (26,6–27,6) | 28,7 s (26,6–29,1) |
| PlayCanvas WebGL2 | 3,9 s (3,85–4,60) | 3,4 s (3,41–3,50) |

Firefox no enlaza programas en paralelo. Three.js lo paga entero.

### Por qué PlayCanvas carga más rápido (el número explicado)

- **Programas de GPU enlazados en WebGL2:** PlayCanvas 8 (15 fuentes distintas), Three.js 31 (42 fuentes),
  Godot unos 100 según [rendimiento](../../docs/guides/rendimiento.md).
- **Las luces de área mandan en Three.js.** Sin las 9 luces de área, Three.js WebGL2 carga en 2,5 s en
  vez de 8,7 s, y WebGPU en 2,3 s en vez de 3,5 s. Con las 9, cada material enlaza un sombreador con las
  25 luces desenrolladas. PlayCanvas las recorre con un bucle de datos y enlaza lo mismo con las 25.
- **Las luces de área de PlayCanvas sí alumbran.** Sin ellas, la góndola cambia 1,74 sobre 255 en
  PlayCanvas y 1,74 en Three.js.
- **Las sondas no cuestan carga:** sin ellas, Three.js WebGL2 sigue en 8,7 s.
- **Lo que no probé:** el addon `ClusteredLighting` de Three.js podría acercarlo. Está en
  `examples/jsm/lighting`.
- **Piso de PlayCanvas:** la segunda visita tarda 0,5 s. El 1,5 s de diferencia con la primera es bajar y
  subir 20 MB y compilar 8 programas en frío.

## La imagen

`comparacion.png`: Godot, Three.js y PlayCanvas en las seis vistas, con la misma pose de cámara que tenía
el juego, a 1536×760. Las poses salen del juego real (`herramientas/poses.mjs`).

Diferencia media contra Godot, de 0 a 255 (`herramientas/comparar.py`):

| Vista | Three.js | PlayCanvas |
|---|---:|---:|
| Mostrador | 15,5 | 15,5 |
| Góndola | 15,3 | 16,0 |
| Pasillo | 13,7 | 14,8 |
| Heladera | 19,5 | 22,3 |
| Depósito | 10,1 | 11,9 |
| Baño | 11,4 | 13,1 |

Miré las seis imágenes de cada prototipo antes de darlas por buenas. Lo que se ve igual: paredes, pisos y
techos horneados con su verde, el relieve de los ladrillos, las luces del techo, el bloom, la niebla, los
muebles y los productos con sus etiquetas. Lo que se ve distinto:

- **La calle.** Detrás de los vidrios hay un color liso en vez del panorama.
- **El stock.** Los prototipos dibujan la góndola por defecto. La captura de Godot es de `?jornada=3`.
- **Los reflejos del baño.** Godot refleja el piso; los prototipos no.
- **Las puertas del baño en PlayCanvas** salen quemadas: toman un ambiente promedio, no una sonda por copia.

## Unidad 1. El mapa de motores

Se leyó cada motor en su paquete instalado o en su documentación. Lo que no se encontró dice «faltante».
Los números de peso de Three.js y PlayCanvas se midieron armando el visor del almacén con `esbuild`.

### Three.js (r187, MIT)

- **Sombreadores.** `compileAsync` crea los pipelines antes del primer cuadro. En WebGPU usa `createRenderPipelineAsync` (`src/renderers/webgpu/utils/WebGPUPipelineUtils.js`). En el respaldo WebGL2 usa `KHR_parallel_shader_compile` (`src/renderers/webgl-fallback/WebGLBackend.js`). No trae caché propia entre visitas: lo hace el navegador. Medido: la segunda visita baja de 3,5 a 2,4 s en WebGPU y de 8,7 a 1,7 s en WebGL2.
- **Carga por partes.** `GLTFLoader`, `KTX2Loader` (Basis), Meshopt y Draco. Armar las etapas de carga es trabajo nuestro.
- **Lightmap y sondas.** `lightMap` con un segundo juego de UV. No es direccional: el direccional de Godot se escribió en TSL y anda. Sondas: `LightProbe` (una sola) y, desde esta versión, `LightProbeGrid` en `examples/jsm/lighting`. Las sondas por objeto del juego se hicieron con una textura de armónicos y un índice por instancia.
- **Luces de área.** `RectAreaLight` con LTC. En WebGPU hay que llamar a `RectAreaLightNode.setLTC(RectAreaLightTexturesLib.init())`. El prototipo anterior no lo hacía, y por eso las luces de área «rompían la compilación».
- **WebGPU y respaldo.** `WebGPURenderer` cae solo a WebGL2 con el mismo código y los mismos materiales. La guía oficial lo llama todavía experimental ([manual](https://threejs.org/manual/en/webgpurenderer)). `ShaderMaterial` y `onBeforeCompile` no andan con él: se usa TSL.
- **Geometría virtual.** No trae. Existe `three-virtual-geometry` 0.1.3 (comunidad, MIT): LOD por clusters y culling en compute, **raster por hardware**, sin atómicos de 64 bits. Sólo mallas estáticas y **un solo canal UV** ([README](https://cdn.jsdelivr.net/npm/three-virtual-geometry@0.1.3/README.md)). Sus cifras (5,7 mil millones de triángulos a 160–230 FPS en un MacBook M4 Pro) son del autor. En `examples/jsm/libs` hay `meshopt_clusterizer` para armar meshlets.
- **Peso.** El visor completo, empaquetado y sin código muerto: 1,0 MB, 0,26 MB con brotli.
- **Licencia y costo.** MIT. No hay editor, ni física, ni audio, ni UI: eso se elige aparte.

### PlayCanvas (2.23.3, MIT)

- **Sombreadores.** En WebGL2 detecta `KHR_parallel_shader_compile` (`webgl-graphics-device.js`). Medido: 2,0 s la primera visita (1,95–3,8) y 0,5 s la segunda. Compila pocos programas porque el material horneado es uno solo. En WebGPU traduce GLSL a WGSL con `glslang` y `twgsl` si no se le da WGSL ([ShaderUtils](https://developer.playcanvas.com/user-manual/graphics/)).
- **Carga por partes.** Assets y escenas con su cargador y su editor. No se probó.
- **Lightmap y sondas.** `StandardMaterial.lightMap` con su canal de UV; es una sola textura y su luz direccional es la del horneador propio. No hay sondas por objeto: sólo `ambientSH`, una por escena. Aceptan DXT1/3/5, BC6 y BC7; **BC5 no existe** (los mapas de normales de Godot son BC5).
- **Luces de área.** Rectángulo, disco y esfera. Piden cargar las tablas LTC con `setAreaLightLuts`; el motor no las trae.
- **WebGPU y respaldo.** WebGPU figura como «Beta» en la guía oficial. El respaldo es WebGL2. El prototipo corre sólo en WebGL2.
- **Geometría virtual.** No encontré nada en la guía ni en la API: faltante.
- **Peso.** El visor completo: 1,0 MB, 0,22 MB con brotli.
- **Licencia y costo.** El motor es MIT. El editor en la nube es de pago; el frontend del editor se abrió con MIT en 2025.

### Babylon.js (9.33.1, Apache-2.0)

- **Sombreadores.** Compila en paralelo con la extensión de WebGL (`thinEngine.pure.js`) y crea los pipelines de WebGPU en forma asíncrona (`webgpuCacheRenderPipeline.js`). Si recibe GLSL en WebGPU, lo traduce a WGSL y baja una librería WASM. `NodeMaterial` genera los dos lenguajes ([doc](https://doc.babylonjs.com/setup/support/webGPU/webGPUWGSL)).
- **Carga por partes.** `AssetContainer`, glTF y KTX2.
- **Lightmap y sondas.** Lightmap con segundo UV. No encontré sondas por objeto: faltante.
- **Luces de área.** `RectAreaLight`, **sin sombras** ([doc](https://doc.babylonjs.com/features/featuresDeepDive/lights/lights_introduction)). Tope por defecto de 4 luces por material, que se puede subir.
- **WebGPU y respaldo.** Los dos motores conviven. No se puede pasar una escena ya armada de uno a otro. «Snapshot rendering» graba los dibujos de un cuadro y los repite; sólo en WebGPU, sólo con escena estática ([doc](https://doc.babylonjs.com/setup/support/webGPU/webGPUOptimization/webGPUSnapshotRendering)).
- **Geometría virtual.** No hay meshlets en `Meshes/`: faltante.
- **Texturas BC crudas.** El motor conoce BC6H, pero no hay una vía simple para subir bytes BC ya hechos. Habría que pasar por KTX2.
- **Peso.** No lo armé: faltante.
- **Licencia y costo.** Apache-2.0, sin costo.

### Unity 6.6 con WebGPU

- **Estado.** Una nota de terceros dice que WebGPU dejó de ser experimental en 6000.6 ([Cinevva](https://app.cinevva.com/news/2026-09-01-unity-6-6-webgpu-production)). La documentación oficial de 6.6 todavía marca la página como Beta. Entra por «Graphics APIs» con WebGL2 de respaldo.
- **Luz.** Sólo luz horneada, y **sólo lightmaps no direccionales** ([límites oficiales](https://docs.unity.com/en-us/engine/6000.6/manual/platform-specific/webgl/develop/graphics/web-gpu/limitations)). Perdería el relieve que da hoy el lightmap direccional. Sondas y luces de área: la página no las nombra.
- **Sombreadores.** La página pide no incluir variantes de más por la poca memoria. Sin Int64 ni `Wave*` en HLSL. Algunas extensiones y formatos no existen en Safari ni en Firefox.
- **Geometría virtual.** No hay un equivalente de Nanite en lo que leí. Int64 no existe en HLSL para la web.
- **Peso.** Un proyecto vacío con URP pesa unos 10,7 MB (3,7 de datos y 6,9 de código). Con mucho recorte, de 2 a 3 MB ([notas de Aras P.](https://gist.github.com/aras-p/740c2d4f9977ce92b7de72b1394dd365)). El almacén y el juego van aparte.
- **Licencia y costo.** Gratis hasta 200.000 USD de ingresos. Pro cuesta 2.310 USD por puesto y por año ([Unity](https://unity.com/products/pricing-updates)). El cobro por instalación se canceló en 2024.

### Bevy (0.19, MIT o Apache-2.0)

- **Geometría virtual.** Trae meshlets, pero el plugin pide `TEXTURE_INT64_ATOMIC` y «works only on the Vulkan and Metal backends» ([fuente](https://raw.githubusercontent.com/bevyengine/bevy/main/crates/bevy_pbr/src/meshlet/mod.rs)). **No corre en la web.**
- **Peso.** Un hilo de 2023 habla de unos 22 MB sin optimizar y 12 MB con recortes duros ([hilo](https://axebps-redlib.hf.space/r/rust/comments/13lb0h8/bevy_webgpu/jkpa8mx/?context=3)). Es un dato viejo y de segunda mano.
- **Costo de portar.** Todo el juego se reescribe en Rust. No lo probé.

### Otros

No hizo falta sumar otro motor. Los datos ya separan a Three.js y PlayCanvas del resto por carga, peso y trabajo de portar.

### La puerta a mejor geometría (pregunta 3)

- **Atómicos de 64 bits.** La propuesta de WebGPU está **aceptada y fusionada** en la especificación: `atomic_vec2u_min_max`, con `atomicStoreMin` y `atomicStoreMax` sobre `vec2u`, sólo en buffers de almacenamiento ([propuesta](https://github.com/gpuweb/gpuweb/blob/main/proposals/atomic-64-min-max.md)). Dawn la implementa para Vulkan, Metal y D3D12 ([commit D3D12](https://dawn.googlesource.com/dawn/+/e2f0828f7c6919dba0521a47c19fc44df88dbadc)). **No encontré un navegador que la entregue**: faltante.
- **Hardware.** Vulkan: 87,7 % de Linux y 31 % de Android tienen la función en 1.2. Metal: sólo Apple 9 en adelante. D3D12: Shader Model 6.6.
- **Sin atómicos de 64 bits.** Hay dos caminos que ya existen en la web. Uno es el raster por hardware de `three-virtual-geometry`. El otro es el raster por software de [nanite-webgpu](https://github.com/Scthe/nanite-webgpu), que empaqueta profundidad y normal en 32 bits con 16 de profundidad y ve artefactos.
- **Mesh shaders.** No están en WebGPU. La petición está en el hito posterior a la versión 1 ([issue 3015](https://github.com/gpuweb/gpuweb/issues/3015)). Existen sólo en `wgpu` nativo, con una marca experimental.
- **Qué motor la tiene o la puede tener.** Hoy, ninguno entrega meshlets con raster de 64 bits en el navegador. **Three.js** es el único con una librería que corre en WebGPU de hoy, con los límites de arriba. **Bevy** la tiene en nativo y no en la web. **Unity** declara que no soporta Int64 en la web.
- **Choque con este juego.** El almacén horneado necesita dos canales UV (textura y lightmap). `three-virtual-geometry` admite uno. Serviría para productos y utilería sin lightmap, no para las paredes y los muebles.

## Unidad 2. Cómo se porta un juego en GDScript

### Cuánto hay que portar (medido con `estructura.py` y `wc`)

| Qué | Cantidad |
|---|---:|
| GDScript en `src/` | 28.512 líneas en 210 archivos |
| de ellas, `dominio/` (puro) | 10.119 líneas en 112 archivos |
| `sistemas/` | 4.403 líneas en 29 archivos |
| `ui/` | 3.618 líneas en 22 archivos |
| `escenas/` | 10.372 líneas en 47 archivos |
| Escenas `.tscn` | 45 |
| Tests en `test/` | 79.967 líneas en 427 archivos |
| Criterios de spec citados (`AC-…`) | 727 líneas en `specs/` |
| Sombreadores propios | 25 archivos, 803 líneas |
| Harness en Python (`.claude/scripts`) | 30.068 líneas |

El dominio puro es chico. Lo grande son los tests, que triplican al código.

### Los caminos

| Camino | Qué se rompe | Costo por jugador | Riesgo |
|---|---|---|---|
| **A. Reescribir todo en el motor nuevo** (TypeScript) | Los 427 tests de gdUnit4, los gates de capas y de specs, y la regla «Godot es donde se prueba»: quedan dos códigos que hay que mantener iguales. | El mejor: sin runtime de Godot. | Alto. Cada regla del juego existe dos veces. |
| **B. Godot sin dibujo en wasm para la lógica, y el motor nuevo sólo dibuja** | Hay que espejar al motor nuevo todo lo que se mueve (cámara, mano, puertas, utilería, copias de producto) y la UI. Los `SubViewport` de las pantallas del celular y de la computadora no se pueden compartir sin una lectura de la GPU por cuadro. | El wasm de Godot (4,9 MB con brotli) y sus 2,1 s de arranque siguen. | Medio. Los tests, los gates y los 727 criterios siguen valiendo. |
| **C. Traducir GDScript a TypeScript** | Hace falta una capa que imite la API de Godot (nodos, señales, `Timer`, `Tween`, física, audio). Es reescribir un pedazo de Godot. | Bueno: un paquete de JavaScript. | Alto. El traductor tiene que cubrir `sistemas/` y `escenas/`, no sólo el dominio. |
| **D. Quedarse en Godot y sacar la ganancia del motor** | Nada se rompe. | Es lo que ya se midió: 12,7 s para ver el almacén. | Bajo, sin ganancia nueva. |

Quién mantiene qué: en A y C el equipo mantiene un solo código de juego, en TypeScript, y Godot queda de editor de escenas. En B se mantienen los dos: GDScript para las reglas y un visor para el dibujo. Esa mitad nueva es chica y la genera una herramienta (el volcado de este prototipo).

## Unidad 3. Los prototipos

Las mediciones de los prototipos están arriba, en «Qué se midió». Acá está qué lleva cada uno.

Los dos prototipos dibujan **el mismo almacén**. Salen de los mismos datos, que vuelca `herramientas/volcar.gd` desde las escenas reales del repo y del `.lmbake`. Las texturas son **los mismos bytes BC** que el motor de Godot ya importó. No se recomprimió nada.

### Qué llevan

| Pieza | Three.js (WebGPU o WebGL2) | PlayCanvas (WebGL2) |
|---|---|---|
| Estructura, 195 mallas visibles | sí | sí |
| Lightmap, las 4 capas (L0 y L1) en BC6H | sí, como Godot | sí, como Godot (GLSL propio) |
| Productos: 345 copias de 32 productos, instanciadas | sí | sí |
| Sondas del `.lmbake` | sí, una fila de 9 armónicos **por copia** | no por copia: un promedio para toda la escena |
| 25 luces en tiempo real sobre lo que no tiene lightmap | sí: 13 focos, 3 puntuales y **9 luces de área reales** | sí, las mismas 25 y las 9 de área |
| Mapas de normales BC5 | sí | **no**: PlayCanvas no tiene BC5 |
| Niebla, tono de Godot, ajustes y bloom del juego | sí | sí |

### Lo que no llevan

- El exterior (la calle y su panorama) y sus sombreadores propios.
- Los otros 24 sombreadores propios: contornos, agua, manchas, vidrio.
- Los reflejos del baño.
- La lógica, la UI, el audio y la física.
- El stock de la partida: dibujan la góndola de la disposición por defecto, no la de `?jornada=3`.

### Calibración

Dos números salen de comparar contra las capturas de la web de hoy, no del código de Godot:

- el lightmap se multiplica por **6** (única constante para las seis vistas);
- las luces y el ambiente de lo dinámico se escalan a mano en PlayCanvas (×2,5) y con π en Three.js.

La fórmula del lightmap direccional es `L0 × (0,282 + 0,326 × (L1 · normal))`, con L1 guardado como `(v − 0,5) × 2`. Es una **hipótesis verificada por la imagen**: sin la capa L1 los pisos salen negros, y con L1 sin escalar por L0 salen grises. Con L1 relativo a L0 salen verdosos como en Godot.

### Dos errores que cambian la lectura del prototipo anterior

- En Three.js, `a.mix(b, t)` toma `a` como el **factor** de mezcla. El visor anterior lo usaba como si `a` fuera el primer color. Eso, junto con aplicar el gamma dos veces, lo dejaba «más claro y más plano». No era un límite del motor.
- La luz de área necesita `RectAreaLightNode.setLTC(RectAreaLightTexturesLib.init())`. Sin esa línea rompe la compilación de **todos** los materiales.

## Unidad 4. La recomendación

**Un motor: PlayCanvas. Un camino: la lógica de Godot corre sin dibujar y PlayCanvas dibuja.**

### Por qué PlayCanvas

- **Carga.** 2,0 s contra 12,7 s en Chrome. 3,9 s contra 22,5 s en Firefox.
- **CPU.** Cuatro veces menos por cuadro. Con la CPU lenta, 5,9 ms contra 25,7 ms.
- **Memoria.** 736 MB contra 1.601 MB.
- **Navegadores.** WebGL2 anda igual en Chrome y Firefox, que se midieron. Safari 15 o más tiene WebGL2
  ([Unity lo cita](https://docs.unity3d.com/6000.6/Documentation/Manual/webgl-browsercompatibility.html)),
  pero no lo probé.
- **Peso del motor.** 0,22 MB con brotli, contra 4,9 MB del wasm de Godot.
- **Licencia.** MIT. Sin costo por jugador ni por puesto.
- **Trae lo que no es dibujo:** entidades, carga de assets, UI, audio e integración con física (Ammo).
  Se usa por etapas, sólo si hace falta.

### Por qué no los otros

- **Three.js, segundo.** Carga más lento (3,5 s en WebGPU, 8,7 s en WebGL2) y gasta cuatro veces más CPU
  por cuadro. Es una biblioteca: no trae editor, física ni audio. Su `WebGPURenderer` sigue marcado como
  experimental. Su ventaja es una: la geometría virtual de la comunidad.
- **Babylon.js.** No lo prototipé. No sube bytes BC ya hechos sin pasar por KTX2, no encontré sondas por
  objeto y sus luces de área no dan sombra. No apareció un dato que lo pusiera por encima.
- **Unity 6.6.** Sólo lightmaps no direccionales: perdería el relieve que hoy da el direccional. Un proyecto
  vacío pesa unos 10,7 MB. Pro cuesta 2.310 USD por puesto y por año.
- **Bevy.** Sus meshlets no corren en la web, y el juego se reescribe en Rust.

### Por qué ese camino

El juego son 28.512 líneas de GDScript, 427 archivos de tests con 79.967 líneas y 727 criterios de spec.
Dejar la lógica en Godot **no rompe nada de eso**. Lo que se porta es el dibujo, y eso es lo que el
prototipo ya probó. Godot sigue siendo donde se desarrolla y se prueba.

**Quién mantiene qué.** El equipo del juego sigue con GDScript, los tests y los gates, sin cambios. La
mitad nueva es el volcado de escenas y la página de PlayCanvas. La produce una herramienta, no una
persona escribiendo escenas dos veces.

**Costo por jugador con este camino** (estimación, sin medir): unos 40 MiB en vez de 45,4. Ver el almacén
en 4 a 5 s en vez de 12,7: el arranque de Godot se midió en 2,1 s hasta el menú, y el almacén de
PlayCanvas en 2,0 s, y las dos esperas corren a la vez. La memoria del Godot sin dibujo **no se midió**.

**Riesgos, de mayor a menor:**

1. **La plantilla web de Godot dibuja siempre.** Correr sin 3D pide un parche de la plantilla. No lo probé.
2. **El espejo del estado.** Todo lo que se mueve (cámara, mano, puertas, utilería, copias de producto,
   tickets) y la UI tienen que llegar a PlayCanvas. Los `SubViewport` de las pantallas del celular y de
   la computadora no se pueden compartir sin leer la GPU cada cuadro.
3. **El volcado lee el `.lmbake` en binario.** Su desplazamiento cambió entre dos horneados y hubo que
   buscarlo. Hay que sacar esos datos en el momento de hornear, desde el editor.
4. **El prototipo no es el juego.** No tiene lógica, UI ni audio. Las cargas medidas son el piso, no el
   techo.
5. **Un solo navegador con la GPU buena.** Chrome y Firefox en una RTX 4050. No hay GPU integrada, ni
   Safari, ni Android.

### Las etapas

**Etapa 0 (hecha en esta corrida).** Los dos prototipos y sus herramientas, en `build/motor-web/`.

**Etapa 1, la primera: el almacén en PlayCanvas, como paso del export.**

- Mover `volcar.gd`, `atlas.py` y `empaquetar_texturas.py` a `.claude/scripts/`.
- Sacar del editor los rectángulos y las sondas del horneado, en vez de leer el `.lmbake` en binario.
- Sondas por copia en PlayCanvas, con un fragmento de sombreador propio.
- Normales BC5: pasarlas a un formato que PlayCanvas acepte.
- Agregar el exterior y sus sombreadores propios.
- Publicar la página junto a la build de Godot.
- **Cómo se verifica:** diferencia media menor o igual a 12 sobre 255 en las seis vistas, **contra la
  captura de Godot de la misma revisión**, nunca contra una foto guardada. Ver el almacén en menos de
  5 s en Chrome y en Firefox. Ningún cuadro de más de 50 ms al recorrer las seis vistas.

**Etapa 2: Godot sin dibujar, y el puente.** Parche de la plantilla para no crear el rasterizador 3D. Un
puente de estado para lo que se mueve. Las entradas del jugador pasan de PlayCanvas a Godot. Se verifica
con un turno entero jugado en la página nueva.

**Etapa 3: la UI y las pantallas del celular.** Pasan a PlayCanvas o a HTML. Después de esta etapa el wasm
de Godot ya no necesita su rasterizador.

**Etapa 4, sólo si las medidas lo piden: traducir `dominio/` a TypeScript.** Es el único trabajo que
quita el wasm de Godot. Se hace por las capas del repo (`dominio`, `sistemas`, `ui`, `escenas`) y los
mismos 727 criterios corren contra las dos versiones. Se decide cuando se mida cuánto pesa el Godot sin
dibujo: hoy se sabe que arranca en 2,1 s y pesa 4,7 MiB.

**Aparte: texturas KTX2 con Basis.** Un solo formato para Chrome, Firefox, Safari, iOS y Android. Hoy las
texturas son BC, que sólo sirve en escritorio, igual que la web de hoy. No medí cuánto bajaría el peso.

## Decisiones que tomé sin consultar

1. **Prototipé Three.js y PlayCanvas.** Dejé afuera Babylon.js, Unity y Bevy por las razones de la
   unidad 4. No hizo falta sumar otro motor.
2. **El visor de Three.js se reescribió** sobre el prototipo anterior. Cambió el lightmap, las sondas, las
   luces de área, el tono y las texturas.
3. **Las texturas son las BC que Godot ya importó.** Así los bytes y la imagen se comparan sin que cambie
   la compresión. Una textura del modelo (`gondola_paleta.png`) no estaba importada y se dibuja sin ella.
4. **Los datos salen de la copia importada de `copia-webgl2`** y no de este worktree, porque este no tiene
   caché de importación. Su `src/` difiere en cinco archivos: el corte de luz, la descarga del mapa oscuro
   y el bloom. **El bloom del export de Godot es el barato, de 9 lecturas. Los visores usan el de 25
   lecturas de este worktree.** Eso juega en contra de los visores y a favor de Godot.
5. **La cámara de cada vista se leyó del juego real** (ojo a 1,80 m, 75° de campo vertical).
6. **Tres constantes se calibraron a ojo contra las capturas de Godot:** lightmap ×6 en los dos visores, y
   la luz de lo dinámico (×π en Three.js, ×2,5 en PlayCanvas). Quedan escritas en `visor.js`.
7. **Los cuatro lados se miden contra el mismo servidor**, también Godot, para que el caché y los headers
   no cambien entre lados.
8. **«Ver el almacén» termina en el primer cuadro con todo compilado.** Es el mismo criterio para todos.
9. **Unifiqué el grafo de los materiales horneados en Three.js.** Bajó de 64 a 39 programas y el cambio
   fue de 3,8 a 3,5 s. Rehice las dos campañas de Three.js con esa versión.
10. **En PlayCanvas dejé WebGL2 solamente.** Mi material horneado está en GLSL y no escribí la versión WGSL.
11. **No toqué `src/`, `test/` ni `project.godot`.** Todo vive en `build/motor-web/`.
12. **No cerré procesos ajenos.** Sólo paré mis servidores de prueba.

## Lo que no se pudo medir o no hice

- **Safari.** No hay un Mac. WebGL2 y WebGPU en Safari quedan sin probar.
- **PlayCanvas con WebGPU.** El motor lo marca como beta y mi sombreador no tiene versión WGSL.
- **GPU integrada, Android y iOS.** Sólo una RTX 4050.
- **El juego entero.** Sin lógica, UI, audio, calle, reflejos ni los otros 24 sombreadores propios.
- **Memoria de Godot sin dibujo, y el costo del puente de estado.** Son la base del camino elegido y no
  los medí.
- **Qué gasta la CPU de Three.js y de PlayCanvas.** Medí la diferencia, no la causa.
- **El tirón de 21 ms de PlayCanvas** sin tope de cuadros.
- **Babylon.js.** Peso del motor y una prueba con el almacén.
- **Firefox sin tope de cuadros.** Los tiempos de cuadro de Firefox son de vsync y no dicen nada.
- **Cuánto bajan los bytes con KTX2.**
- **Atómicos de 64 bits en un navegador.** Leí la propuesta aceptada y el código de Dawn. No encontré
  un navegador que la entregue, y eso no prueba que ninguno la tenga.

## Dónde está cada cosa

Todo en `build/motor-web/` (la carpeta está en `.gitignore`: se sumó con `git add -f`).

| Qué | Dónde |
|---|---|
| Esta respuesta | `resultado.md` |
| Las seis vistas, lado a lado | `comparacion.png` y `capturas/` |
| Cada corrida, en JSON | `medidas/campana/` (Chrome), `medidas/extra/` (segunda visita, CPU lenta, Firefox) |
| Tablas ya resumidas | `medidas/resumen-vsync.md`, `resumen-libre.md`, `resumen-extra.md` |
| Peso de lo comparable en Godot | `medidas/bytes-godot-comparables.json` |
| Visor de Three.js | `three/visor/visor.js`, página `three/visor/bundle.html` |
| Visor de PlayCanvas | `pc/visor/visor.js`, página `pc/visor/bundle.html` |
| Volcado de escenas y lightmap | `herramientas/volcar.gd`, `herramientas/atlas.py` |
| Texturas BC y lightmap en BC6H | `herramientas/empaquetar_texturas.py` |
| Medición y campañas | `herramientas/medir_visor.mjs`, `medir_godot.mjs`, `campana.sh`, `campana2.sh` |
| Cuenta de programas | `herramientas/contar_programas.mjs` |
| Imagen | `herramientas/capturar.mjs`, `comparar.py`, `lado.py`, `poses.mjs` |

Cómo se repite, desde `build/motor-web/`:

```powershell
# 1. Volcar el almacén desde una copia importada del proyecto y empaquetar
& $env:GODOT_BIN --headless --path <copia-importada> --script <ruta>/herramientas/volcar.gd -- <ruta>/datos/
python herramientas/atlas.py
python herramientas/empaquetar_texturas.py <copia-importada> datos
# 2. Empaquetar los visores
cd three; npx esbuild visor/visor.js --bundle --minify --format=esm --outfile=dist/visor.js `
  --alias:three=./node_modules/three/build/three.webgpu.js --alias:three/webgpu=./node_modules/three/build/three.webgpu.js `
  --alias:three/tsl=./node_modules/three/build/three.tsl.js --alias:three/addons=./node_modules/three/examples/jsm
cd ../pc; npx esbuild visor/visor.js --bundle --minify --format=esm --outfile=dist/visor.js
# 3. Servir, mirar y medir
node three/servir.mjs . 8121
node herramientas/capturar.mjs "http://127.0.0.1:8121/pc/visor/bundle.html?vista=gondola" capturas/pc-gondola.png
herramientas/campana.sh 5 vsync        # primera y segunda visita
herramientas/campana.sh 5 libre        # tiempo de cuadro sin tope
```

`campana.sh` espera la web de Godot en el puerto 8123 (`node three/servir.mjs <export/web> 8123
--ya-comprimidos=index.pck,mapa_del_corte.pck`).

## Lo que sólo decide el usuario

1. **PlayCanvas o Three.js.** Recomiendo PlayCanvas. Si la geometría virtual va antes que la carga, la
   respuesta es Three.js.
2. **Empezar la etapa 1.** Es la primera que toca el repo fuera de `build/`: mueve herramientas a
   `.claude/scripts/` y suma un paso al despliegue.
3. **La etapa 2 toca `src/`, los tests y la plantilla web de Godot.** Hace falta una decisión explícita.
4. **Si se paga el editor de PlayCanvas.** No hace falta para nada de lo medido. El motor se usa por código.
5. **Pasar las texturas a KTX2.** Cambia el flujo de arte, y es lo que habilita Safari y los celulares.
6. **Quién prueba en Safari.** Hay que hacerlo en un Mac antes de prometer nada.

FIN DEL MOTOR WEB

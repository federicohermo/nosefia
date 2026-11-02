# Despliegue

**Cada push a `main` deja una web jugable.** El juego se exporta a Web con Godot headless en
GitHub Actions, y se publica en Vercel. Después se verifica que se juegue, que es la mitad que
no es obvia.

| Qué | Dónde |
|---|---|
| El workflow | [`.github/workflows/desplegar.yml`](../../.github/workflows/desplegar.yml) |
| El preset | `export_presets.cfg`, el preset de plataforma Web: nombre y destino están ahí |
| Los headers | `vercel.json` |
| La versión del motor | `.godot-version` |
| La preparación de la plantilla web | [`.github/scripts/preparar_plantilla_web.py`](../../.github/scripts/preparar_plantilla_web.py) |
| El parche y la receta de compilación | [`.github/patches/godot-web-compilacion.json`](../../.github/patches/godot-web-compilacion.json) |
| El veredicto del export | `.claude/scripts/verificar_export.py` |
| La compresión del `.pck` | `.github/scripts/comprimir_pck.mjs`, y el `Content-Encoding` en `vercel.json` |
| El veredicto de la URL | `.claude/scripts/verificar_despliegue.py` |
| El humo en un navegador | `.github/scripts/humo_en_navegador.mjs` |

## Qué lo dispara

**Un push a `main`, y nada más.** `staging` recibe cada PR de spec, así que desplegar desde ahí
publicaría trabajo a medio integrar sobre la URL que mira la cátedra — ver
[ramas](./ramas.md). Para rehacer una entrega sin inventar un commit está el
`workflow_dispatch`: Actions → *desplegar* → *Run workflow*.

## Los secretos

Van en **Settings → Secrets and variables → Actions**. Sin cualquiera de ellos el workflow
**falla en el primer paso nombrándolo**, antes de preparar la plantilla. La alternativa es
enterarse tarde, por un error de la CLI que no lo nombra.

| Secreto | De dónde sale |
|---|---|
| `VERCEL_TOKEN` | Vercel → Account Settings → Tokens → *Create* |
| `VERCEL_ORG_ID` | `vercel link` en local, y sale en `.vercel/project.json` como `orgId` |
| `VERCEL_PROJECT_ID` | el mismo archivo, `projectId` |

`.vercel/` está en el `.gitignore`: es donde la CLI escribe ese vínculo, y adentro va el `orgId`
de la cuenta.

## Y apagarle la Deployment Protection al proyecto

**Un proyecto de Vercel nace con la protección encendida.** Con eso, los archivos del juego
contestan `302` a `vercel.com/sso-api` en vez de servirse. Los dos verificadores de abajo salen
rojos aunque el export esté perfecto: no llegan a mirar el juego, miran una pantalla de login.

Se apaga en **Project → Settings → Deployment Protection**. Si la producción tiene que quedar
protegida, hay que darle a la CI un `VERCEL_AUTOMATION_BYPASS_SECRET` y mandarlo en cada
petición. Pero entonces *nadie de afuera puede jugar*. Con la protección puesta,
`verificar_despliegue.py` nombra cada `302` y su destino.

## El `.pck` viaja comprimido, y Vercel rechaza lo que pasa de 100 MB

**Vercel no acepta un archivo de más de 100 MB.** Medido el 2026-11-01 con la CLI 65.2.0: subir
el export tal como lo escribe Godot termina con `Error: File size limit exceeded (100 MB)`, y no
queda deploy. El `.pck` de este juego pesa **113.233.684 bytes**, así que sin comprimirlo no se
publica.

`comprimir_pck.mjs` lo comprime en el lugar con brotli, a **43.706.584**. El nombre no cambia; lo
que cambia es el cuerpo. `vercel.json` manda `Content-Encoding: br` **sólo para `/index.pck`**,
porque el `.wasm`, el `.js` y el `.html` viajan sin comprimir y los comprime el CDN.

Es un par, como el de los hilos, y las dos mitades viven en archivos distintos:

- **El cuerpo**, en el archivo que deja el paso de compresión.
- **El header**, en `vercel.json`.

Separados, el navegador le entrega al motor un cuerpo comprimido como si fuera un paquete. **El
juego queda en negro con el deploy en verde.** Por eso lo atan tres verificadores.
`verificar_export.py` comprueba que el archivo no sea el `.pck` crudo. También que el total
declarado en `index.html` sea el descomprimido: por ese número divide la barra de carga. `test_despliegue.py`
cruza `vercel.json` con `CODIFICADOS` en las dos direcciones. Y `verificar_despliegue.py` mira
el header en la URL publicada.

**La codificación se lee de `vercel.json`, no se escribe dos veces.** El compresor saca de ahí
qué archivo comprimir y con qué. Es el mismo lugar de donde sale el header: no pueden separarse
sin tocar un archivo.

**Brotli y no gzip.** Medido sobre el mismo `.pck`: brotli calidad 11 deja 43.706.584 bytes y
gzip nivel 9, 51.416.380. Son 7,7 MB menos, un 15 %. Sobre la descarga entera, donde el `.pck`
es el 85 %, es la diferencia entre 50,7 MB y 58,4 MB. Cuesta tres minutos de compilación por
deploy y un decodificador que la stdlib de Python no tiene. Por eso el compresor vive en
`.github/scripts/`, donde la stdlib de node sí lo trae. La comparación completa está en
`build/medicion-web/resultado.md`.

**El `.pck` no se vuelve a comprimir dos veces.** El paso intenta descomprimir antes de
comprimir. Si lo que hay ya es un paquete, no lo toca. Comprimir un cuerpo ya comprimido deja un
archivo que el navegador descomprime una vez y entrega basura. Ese error no tiene síntoma hasta
que el juego no arranca.

**Y comprime y verifica antes de escribir.** Descomprime lo que acaba de comprimir. Exige que
empiece con `GDPC` y que mida lo que `index.html` declara. Si algo no cierra, sale distinto de
cero sin tocar el archivo.

`servir_export.py` aplica los headers de `vercel.json` **por ruta**, como Vercel. Si el `.pck`
de la carpeta pesa lo mismo que declara su `index.html`, no está comprimido. Entonces lo sirve
sin el header y lo avisa por stderr. Medir un export recién salido de Godot creyendo que se mide
el que se publica es el otro modo de falla.

## El mapa de la noche del corte viaja en su propio paquete

El horneado oscuro —`almacen_sin_luz.exr` y su `.lmbake`— pesa 17,27 MB de los 113 del `.pck` y
sólo lo usa la sexta noche. Se saca del paquete principal y viaja en `mapa_del_corte.pck`, que se
arma con `.github/scripts/armar_paquete_del_mapa.gd`. Son tres archivos: el `.lmbake`, el
`.exr.import` y la textura importada. **No se arma con un preset de exportación**:
`--export-pack` empaqueta todo el proyecto y el paquete salía de 113 MB en vez de 17.

**El `.exr.import` es obligatorio.** El `.lmbake` referencia la textura por su ruta fuente. Sin
la metadata de importación el motor contesta «No loader found for resource». El local se queda
sin su horneado oscuro.

- **Cuándo se baja:** al abrir la jornada del corte, en segundo plano, por `HTTPRequest`. La
  regla vive en `src/dominio/almacen/mapa_del_corte.gd` y el sistema que la ejecuta en
  `src/sistemas/marco/descarga_del_mapa.gd`.
- **Si no llega:** reintenta con espera creciente y la oscuridad no se aplica hasta que el
  paquete está montado. El almacén tapa la espera con la pantalla de carga. Sin el horneado, el
  local se quedaría sin luz horneada y la noche del corte se vería rota.
- **Los gates lo miran igual que al principal.** `verificar_export.py` lo exige como
  obligatorio. `verificar_despliegue.py` le pide el `Content-Encoding` en la URL publicada,
  porque también se comprime con brotli.

En escritorio y en los tests no hay nada que bajar: el mapa sigue dentro del juego y la regla
arranca lista.

## Los tres veredictos, y por qué no alcanza con uno

**El código de salida del export no dice nada.** `--export-release "Web"` puede terminar con
`Program crashed with signal 11` y **devolver 0**. Un paso de CI que mire el `$?` sale verde con
un directorio a medio escribir. Por eso el export corre con `|| true`, y quien decide es
`verificar_export.py`. Qué archivos pide y qué tamaños acepta lo declara `lib/despliegue.py`.

**Contestar 200 no es servir un juego.** `verificar_despliegue.py <URL>` le pide los archivos
del juego a la URL publicada. Falla si alguno da 404, si falta un header de aislamiento, si el
`Cache-Control` no revalida o si el `.wasm` no viene con su tipo.

**Y cargar no es arrancar.** `humo_en_navegador.mjs` abre la URL en un Chromium de verdad.
Falla si `crossOriginIsolated` es `false`, si el overlay de carga sigue en la página o si hubo
un error de consola. Es el único paso que mira lo que ve una persona: los dos de arriba
pueden estar en verde con la pantalla en negro.

## El par preset↔headers

**Es un par, y las dos mitades viven en archivos distintos.** El preset exporta con hilos
(`variant/thread_support=true`), y el `index.js` que genera Godot usa `SharedArrayBuffer`. Sin
los headers de aislamiento que manda `vercel.json`, el deploy contesta 200, el HTML carga y
**el juego aborta antes de dibujar un pixel**.

Apagar los hilos sin sacar los headers, o al revés, es un cambio de una línea que nadie nota.
Por eso lo ata un gate: `.claude/scripts/tests/test_despliegue.py` cruza los dos archivos y
pone rojo el nodo `harness` en las dos direcciones.

Y el `Cache-Control` va con `must-revalidate` porque **ningún archivo que Godot exporta lleva
hash en el nombre**: siempre `index.wasm`, `index.pck`, `index.js`. Un caché largo le serviría
la build anterior a quien ya entró una vez — que en una cátedra es el docente que vuelve a
mirar.

## Por qué exporta Actions y no Vercel

Los runners de Vercel no tienen Godot, y las export templates no entran en su build cache: se
bajarían enteras en *cada* deploy. El caché de Actions sí las aguanta. Vercel recibe un
directorio ya construido. Los límites de cada caché están en la documentación de cada
servicio.

### Y por eso `vercel.json` apaga el deploy automático de Git

El proyecto **está vinculado al repo**. Sin apagarlo, la integración de Vercel construye **la
raíz** en cada push: sin Godot, sin export, sin juego. No falla: publica un sitio que
contesta **404**.

Y con `desplegar.yml` en `main` serían **dos caminos publicando sobre el mismo proyecto en el
mismo push**. El alias de producción queda para el que termine último: el juego o el 404.

```json
"git": { "deploymentEnabled": false }
```

Lo ata `test_despliegue.py`, porque es una línea que se borra sin querer. El síntoma, un 404 en
producción con Actions en verde, no la nombra. La opción es de
[Git configuration](https://vercel.com/docs/project-configuration/git-configuration), y sólo
gobierna los deploys **automáticos**: el `vercel deploy` explícito del workflow sigue andando.

## La plantilla web

El preset usa `res://build/templates/web_release.zip` como `custom_template/release`. La plantilla
incluye el parche de compilación de shaders medido en [rendimiento](../guides/rendimiento.md).
El editor usa Godot oficial. El export de debug usa la plantilla oficial. El motor nativo
conserva su código.

La preparación corrige también la copia del framebuffer de Emscripten: consulta si el recorte
está habilitado con `isEnabled`, conservando su estado al terminar de copiar. La consulta con
`getParameter` sincronizaba con la GPU en cada cuadro y produjo bloqueos medidos en la partida.
Se corrige el JavaScript generado del ZIP, sin modificar el WASM. El preparador rechaza una
plantilla que conserve esa consulta o cambie el código esperado de la copia. La CI prueba que
el export conserva tanto el recorte habilitado como el deshabilitado y el framebuffer anterior.

El parche hace estas cosas, todas bajo `WEB_ENABLED`:

- **No compila las variantes predeterminadas** de un shader. Compila sólo la que pide un dibujo.
- **Enlaza los shaders de escena en paralelo**, con `KHR_parallel_shader_compile`. Publica la
  cola de programas en `window.godot_programas_en_cola`, y el calentamiento la espera. Sin la
  extensión, compila al primer uso.
- **Consulta el estado de la copia de pantalla sólo al crearla.** El motor lo consultaba en cada
  cuadro en que un material 3D lee la pantalla o la profundidad. En el navegador, esa consulta
  espera a la GPU: medido el 2026-10-14, entre 1 y 2,4 ms del hilo principal por cuadro.
- **No separa variantes por luces omni y focos.** Un bucle de luces vacío dibuja igual que uno
  apagado, y cada variante es un enlace más.
- **Aproxima la luz de área con un punto representativo.** El código LTC exacto era la mayor
  parte del tiempo de enlace de cada variante iluminada. Firefox no tiene enlace en paralelo y
  compila uno por uno: medido el 2026-10-18 sobre los shaders del juego, de 56 s a 24,5 s.
- **Puede apagar las luces de área sin enlace en paralelo**, con la opción de proyecto
  `rendering/web/area_lights_need_parallel_link`. El juego la prende: hoy sólo Firefox cae en
  ese caso. Medido el 2026-10-19, la carga baja de 36 s a 25 s, y la imagen cambia menos de 1
  sobre 255.
- **No separa variantes por sondas de reflejo.** Una sonda sin caja no aporta nada: la variante
  de dos sondas dibuja igual que la de una o la de ninguna. Cada material enlaza una variante y
  no tres. Medido el 2026-10-19, Firefox enlaza 94 programas en vez de 133, y la preparación
  baja de 21 s a 14 s.
- **Un material sin luz no separa variantes por luces ni por lightmaps.** Su código no los usa.

La receta también apaga los módulos del motor que el juego no usa. Son red, navegación 2D,
física 2D, XR, CSG, glTF y video, y los cargadores de imágenes que sólo usa el importador. La
navegación 3D queda: el addon del editor nombra sus monitores, y sin ella su script no compila.
Brotli queda: la fuente por defecto del motor viene en WOFF2. Usa el servidor de texto simple,
sin ICU. El motor compila menos y el WASM pesa menos. Si el juego empieza a usar uno de esos
módulos, hay que sacarlo de `OPCIONES` en el preparador.

`test_plantilla_web.py` falla si el parche agrega una línea fuera de `WEB_ENABLED`.

`preparar_plantilla_web.py` lee la receta del repo. Comprueba la versión del motor y las
huellas de la fuente y del parche. La receta trae la huella de cada archivo que el parche toca,
sin tocar y modificado. El preparador las comprueba antes y después de aplicarlo. Un archivo
del parche sin huella en la receta frena la preparación. Sin argumentos, valida la plantilla
guardada en `build/templates` y compila cuando falta o quedó desactualizada. La receta fija el
SDK y las opciones de compilación. Los ZIP generados quedan fuera de Git.

La primera compilación local medida tarda unos 30 minutos. Las siguientes preparaciones
reutilizan la plantilla validada. Actions guarda `build/templates` en caché. Su clave incluye
la versión, el parche, la receta y el script. Restaurar la caché no reemplaza las comprobaciones.
El workflow prepara la plantilla con `--jobs 2` para limitar la memoria de compilación.

Los objetos compilados quedan en `build/godot-web/cache-de-scons`, acá y en la caché de
Actions. SCons reusa un objeto sólo si sus entradas son idénticas. Cambiar el parche recompila
los archivos que toca, no el motor entero.

Para importar una plantilla local ya compilada, correr el comando de abajo. El ZIP tiene que
ser el que la receta declara en `plantilla_local`:

```bash
python .github/scripts/preparar_plantilla_web.py --desde tmp/godot-web/web-enlace-en-paralelo.zip
```

Para comprobar la plantilla guardada sin compilar, correr:

```bash
python .github/scripts/preparar_plantilla_web.py --comprobar
```

## Rehacerlo a mano

Para publicar sin pasar por Actions, o para reproducir un fallo del workflow, es esto. Va desde
la raíz del repo, con `GODOT_BIN` apuntando a la versión de `.godot-version`:

```bash
python .github/scripts/preparar_plantilla_web.py
mkdir -p export/web
"$GODOT_BIN" --headless --path . --export-release "Web" export/web/index.html || true
node .github/scripts/comprimir_pck.mjs export/web
python .claude/scripts/verificar_export.py export/web   # el veredicto NO es el $? de arriba
python .github/scripts/preparar_plantilla_web.py --verificar-export export/web

cp vercel.json export/web/
vercel deploy export/web --prod --yes --token "$VERCEL_TOKEN"

python .claude/scripts/verificar_despliegue.py https://<proyecto>.vercel.app
node .github/scripts/humo_en_navegador.mjs https://<proyecto>.vercel.app
```

`--verificar-export` comprueba que `index.wasm` corresponde a la plantilla preparada.
`verificar_export.py` comprueba que el directorio contiene un export completo. Ambos deben pasar.

Las plantillas oficiales de debug se instalan desde **Editor → Manage Export Templates** o en
`~/.local/share/godot/export_templates/<version>.stable/`. El directorio lleva punto, no guion.
La preparación anterior produce la plantilla de release que usa este preset.

## El motor WebGPU, que todavía no se entrega

**La entrega sigue siendo WebGL2.** El motor WebGPU se construye y se exporta aparte, a mano, y no
publica nada. Ni `desplegar.yml`, ni `.godot-version`, ni el renderizador de `project.godot`
cambian por él. Cambiar la entrega es una decisión de una persona.

| Qué | Dónde |
|---|---|
| La receta: commit del fork, SDK y opciones | [`.github/patches/godot-webgpu-compilacion.json`](../../.github/patches/godot-webgpu-compilacion.json) |
| Los cambios nuestros sobre el fork | [`.github/patches/godot-webgpu.patch`](../../.github/patches/godot-webgpu.patch) |
| Compilar la plantilla y el editor | [`.github/scripts/preparar_motor_webgpu.py`](../../.github/scripts/preparar_motor_webgpu.py) |
| Exportar el juego con ese motor | [`.github/scripts/exportar_webgpu.py`](../../.github/scripts/exportar_webgpu.py) |
| La página que elige entre WebGPU y WebGL2 | [`.github/webgpu/elegir_motor.html`](../../.github/webgpu/elegir_motor.html) |
| El workflow manual | [`.github/workflows/construir-webgpu.yml`](../../.github/workflows/construir-webgpu.yml) |

**La fuente no vive en este repositorio ni en uno nuestro.** Es el fork de Shane Gadsby
(`Shane-Gadsby/godotwebgpu`), fijado por commit y por la huella de su ZIP. El parche se aplica
encima. Publicar el motor en un repositorio propio lo decide el usuario. Si el parche se edita, se
regenera desde el repositorio del motor:

```bash
python .github/scripts/preparar_motor_webgpu.py --regenerar <repo-del-motor>
```

### Cómo se reconstruye

```bash
python .github/scripts/preparar_motor_webgpu.py            # la plantilla web, en build/templates/
python .github/scripts/preparar_motor_webgpu.py --editor   # el editor de Linux, en build/godot-webgpu/editor/
GODOT_WEBGPU_BIN=<editor> xvfb-run -a python .github/scripts/exportar_webgpu.py <carpeta-nueva>
```

La plantilla y el editor tienen que salir **del mismo árbol**. El hash de versión del motor entra
en la clave de cada sombreador que el export hornea. Con dos hashes distintos, el paquete de
sombreadores no coincide con ninguno y el navegador los compila todos al cargar. El motor avisa en
la consola. Para usar un editor ya compilado de otro commit, la plantilla se compila con
`GODOT_VERSION_HASH_OVERRIDE=<hash del editor>`.

**En Windows sin MSVC ni g++** no se compilan las herramientas nativas. Se usan las ya hechas:

```bash
python .github/scripts/preparar_motor_webgpu.py --herramientas <carpeta con glslangValidator y wgsl_convert_cli>
```

### Las variantes

- **Sin hilos** es la variante por defecto. No necesita los headers de aislamiento y llena la ventana.
- **Con hilos** (`--hilos`) usa `SharedArrayBuffer`, como la web de hoy. Con `--sin-hilo-de-render`
  el dibujo queda en el hilo principal.
- **Con hilos y hilo de render propio** es el modo por defecto de `--hilos`. Dibuja en un trabajador
  y no hay tirones aunque la CPU sea lenta. El canvas queda fijo en el tamaño del proyecto, escalado
  con barras negras: no sigue a la ventana.

El renderizador es Forward Mobile. Forward+ carga en el doble de tiempo y usa más memoria.

**En WebGPU el juego no calienta shaders.** El motor compila cada variante en segundo plano y dibuja
con el sombreador general mientras tanto. La compilación no desaparece: pasa de detrás del menú a los
segundos entre el clic y el almacén. El criterio está en `calentamiento_de_shaders.gd`.

### Qué cambia el parche

- **Las mallas conservan sus datos** en la web. Antes, leerlas de forma síncrona devolvía vacío
  hasta que llegaba la lectura de la GPU, y una malla que nunca se dibuja no la recibe.
  `Mesh.surface_get_arrays()` y `MeshDataTool` vuelven a ser síncronos.
- **El `MultiMesh` conserva el último buffer** que recibió, por la misma razón. La interpolación
  de física lo lee y lo vuelve a escribir.
- **Los arreglos de texturas comprimidos** se empaquetan con el paso que el driver lee. Sin esto,
  el atlas de lightmap (BC6H, cuatro capas) dejaba el piso y el fondo del almacén en negro.
- **`tick()` y `pre_draw()` del servidor de render** van al hilo de render. Sin esto, con hilos, la
  interpolación de física escribía desde el hilo equivocado y el juego no llegaba al menú.
- **El HTML de la plantilla** respeta el tamaño de canvas del preset. El del fork lo fuerza fijo,
  con barras negras. Sólo la variante con hilo de render propio conserva el canvas fijo, porque su
  canvas no sigue a la ventana.
- **El build reutiliza `wgsl_convert_cli`** si ya existe, y `GODOT_VERSION_HASH_OVERRIDE` fija el
  hash de versión.

### Lo que el exportador hace por vos

- **Trabaja en una copia aislada** del último commit. El árbol del juego sigue en Godot 4.7.2 y no
  mezcla su caché de importación con la del 4.8.
- **Escribe el renderizador en la copia.** El editor borra de `project.godot` la línea
  `renderer/rendering_method` cuando vale `forward_plus`, el valor por defecto. Quien alterna
  renderizadores en una copia sin saberlo prueba siempre Forward+.
- **Saca `addons/godot_mcp/commands`.** El preset ya lo excluye del paquete, pero el horneador lee
  todos los scripts. Al encontrar `sdfgi_enabled` ahí, horneaba las variantes de SDFGI de
  Forward+. El `.shaders.pck` salía con 112 MB más.
- **Exporta con ventana.** `--headless` no hornea sombreadores. En Linux sin pantalla alcanza con
  Xvfb y Vulkan por software.
- **Arma el paquete del mapa del corte** con el mismo editor. Sus texturas se importan con el
  motor 4.8, y no sirven las del 4.7.2.

### Cómo se publicaría

La página `elegir_motor.html` va en la raíz y manda a `webgpu/` o a `webgl2/`, con la consulta
intacta. Decide antes de bajar nada: pide el adaptador, comprueba `texture-compression-bc` y
crea un dispositivo. Cualquier falla manda a WebGL2. `?motor=webgl2` o `?motor=webgpu` fuerzan la
elección.

Cada carpeta lleva su `vercel.json` aparte, porque los paquetes viajan comprimidos y el
`Content-Encoding` va por ruta. Con la raíz en dos carpetas, las rutas de `vercel.json` cambian a
`/webgl2/index.pck`, `/webgpu/index.pck`, `/webgpu/index.shaders.pck` y los dos
`mapa_del_corte.pck`. Los verificadores de despliegue leen la raíz. Hay que enseñarles las dos
carpetas antes de publicar así.

### Lo que no se probó en una CI real

El workflow `construir-webgpu.yml` compila la plantilla y el editor y exporta con Xvfb y lavapipe.
**No corrió en GitHub Actions**: no se puede lanzar un workflow manual que todavía no está en la
rama por defecto. Lo que sí se corrió: el parche aplica sobre el ZIP de la receta con sus huellas,
y la plantilla y el exportador salen de las mismas funciones que usa el workflow, en Windows.
Lo que falta mirar en la primera corrida es el tiempo del editor de Linux y que lavapipe alcance
para hornear.

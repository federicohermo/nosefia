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

El parche hace dos cosas, las dos bajo `WEB_ENABLED`:

- **No compila las variantes predeterminadas** de un shader. Compila sólo la que pide un dibujo.
- **Enlaza los shaders de escena en paralelo**, con `KHR_parallel_shader_compile`. Publica la
  cola de programas en `window.godot_programas_en_cola`, y el calentamiento la espera. Sin la
  extensión, compila al primer uso.

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

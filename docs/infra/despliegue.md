# Despliegue

**Cada push a `main` deja una web jugable.** El juego se exporta a Web con Godot headless en
GitHub Actions, se publica en Vercel, y después se verifica que se juegue — que es la mitad que
no es obvia.

| Qué | Dónde |
|---|---|
| El workflow | [`.github/workflows/desplegar.yml`](../../.github/workflows/desplegar.yml) |
| El preset | `export_presets.cfg`, preset `Web`, exporta a `export/web/index.html` |
| Los headers | `vercel.json` |
| La versión del motor | `.godot-version` — **el único lugar donde está escrita** |
| El veredicto del export | `.claude/scripts/verificar_export.py` |
| El veredicto de la URL | `.claude/scripts/verificar_despliegue.py` |
| El humo en un navegador | `.github/scripts/humo_en_navegador.mjs` |

## Qué lo dispara

**Un push a `main`, y nada más.** `staging` recibe cada PR de spec, así que desplegar desde ahí
publicaría trabajo a medio integrar sobre la URL que mira la cátedra — ver
[ramas](./ramas.md). Para rehacer una entrega sin inventar un commit está el
`workflow_dispatch`: Actions → *desplegar* → *Run workflow*.

## Los secretos

Los tres van en **Settings → Secrets and variables → Actions**. Sin cualquiera de ellos el
workflow **falla en el primer paso nombrándolo**, antes de bajar un giga de templates: la
alternativa —enterarse media hora después por un error de la CLI que no lo nombra, o peor, no
desplegar y salir en verde— es exactamente el modo de falla que este repo persigue.

| Secreto | De dónde sale |
|---|---|
| `VERCEL_TOKEN` | Vercel → Account Settings → Tokens → *Create* |
| `VERCEL_ORG_ID` | `vercel link` en local, y sale en `.vercel/project.json` como `orgId` |
| `VERCEL_PROJECT_ID` | el mismo archivo, `projectId` |

`.vercel/` está en el `.gitignore`: es donde la CLI escribe ese vínculo, y adentro va el `orgId`
de la cuenta.

## Y apagarle la Deployment Protection al proyecto

**Un proyecto de Vercel nace con la protección encendida**, y con eso los cuatro archivos
contestan `302` a `vercel.com/sso-api` en vez de servirse. Los dos verificadores de abajo salen
rojos aunque el export esté perfecto: no llegan a mirar el juego, miran una pantalla de login.

Se apaga en **Project → Settings → Deployment Protection**. Si la producción tiene que quedar
protegida, hay que darle a la CI un `VERCEL_AUTOMATION_BYPASS_SECRET` y mandarlo en cada
petición — pero entonces *nadie de afuera puede jugar*, que es lo que este spec existe para
lograr.

Medido el 2026-09-07 contra el proyecto de este repo, con la protección puesta:
`verificar_despliegue.py` nombra los cuatro `302` y su destino.

## Los tres veredictos, y por qué no alcanza con uno

**El código de salida del export no dice nada.** Medido: `--export-release "Web"` termina con
`Program crashed with signal 11` y **devuelve 0**. Un paso de CI que mire el `$?` sale verde con
un directorio a medio escribir, así que el export corre con `|| true` y quien decide es
`verificar_export.py`: que estén `index.html`, `index.wasm` e `index.pck`, que el `.wasm` pase
un piso de 10 MB y que el directorio no pase de 90.

**Contestar 200 no es servir un juego.** `verificar_despliegue.py <URL>` le pide los cuatro
archivos a la URL publicada y falla si alguno da 404, si falta uno de los dos headers de
aislamiento, si el `Cache-Control` no trae `must-revalidate` o si el `.wasm` no viene como
`application/wasm`.

**Y cargar no es arrancar.** `humo_en_navegador.mjs` abre la URL en un Chromium de verdad y
falla si `crossOriginIsolated` es `false`, si el overlay de carga de Godot sigue en la página o
si hubo un error de consola. Es el único paso que mira lo que ve una persona: los dos de arriba
pueden estar en verde con la pantalla en negro.

## El par preset↔headers

**Es un par, y las dos mitades viven en archivos distintos.** El preset exporta con hilos
(`variant/thread_support=true`) y el `index.js` que genera Godot nombra `SharedArrayBuffer` 15
veces: sin los dos headers de aislamiento que manda `vercel.json` —
`Cross-Origin-Opener-Policy: same-origin` y `Cross-Origin-Embedder-Policy: require-corp`— el
deploy contesta 200, el HTML carga y **el juego aborta antes de dibujar un pixel**.

Apagar los hilos sin sacar los headers, o al revés, es un cambio de una línea que nadie nota.
Por eso lo ata un gate: `.claude/scripts/tests/test_despliegue.py` cruza los dos archivos y
pone rojo el nodo `harness` en las dos direcciones.

Y el `Cache-Control` va con `must-revalidate` porque **ningún archivo que Godot exporta lleva
hash en el nombre**: siempre `index.wasm`, `index.pck`, `index.js`. Un caché largo le serviría
la build anterior a quien ya entró una vez — que en una cátedra es el docente que vuelve a
mirar.

## Por qué exporta Actions y no Vercel

Los runners de Vercel no tienen Godot, y las export templates son **1,2 GB** (1.281.349.702
bytes, medidos el 2026-09-06) contra un build cache de **1 GB**: no entran, así que se bajarían
enteras en *cada* deploy, para siempre. El caché de Actions es de 10 GB por repositorio. Vercel
recibe un directorio ya construido.

**Los tres tamaños de este párrafo viven acá y en ningún otro lado**: los encabezados de
`verify.yml` y de `desplegar.yml` apuntan a este documento en vez de re-tipearlos. El de las
templates se mueve con cada bump de `.godot-version`, y escrito en tres archivos envejece en dos
sin que nadie los cruce.

### Y por eso `vercel.json` apaga el deploy automático de Git

El proyecto **está vinculado al repo**, así que sin apagarlo la integración de Vercel construye
**la raíz** en cada push: sin Godot, sin export, sin juego. No falla — publica. Medido el
2026-09-07 contra el proyecto de este repo: la producción, desplegada desde `staging` por la
integración, contestaba **404**.

Y con `desplegar.yml` en `main` serían **dos caminos publicando sobre el mismo proyecto en el
mismo push**, con el alias de producción para el que termine último: o el juego, o el 404, según
la carrera.

```json
"git": { "deploymentEnabled": false }
```

Lo ata `test_despliegue.py`, porque es una línea que se borra sin querer y el síntoma —un 404 en
producción mientras Actions dice verde— no la nombra. La opción es de
[Git configuration](https://vercel.com/docs/project-configuration/git-configuration), y sólo
gobierna los deploys **automáticos**: el `vercel deploy` explícito del workflow sigue andando.

## Rehacerlo a mano

Cuando hay que publicar sin pasar por Actions —o reproducir un fallo del workflow—, es esto,
desde la raíz del repo y con las export templates de la versión que diga `.godot-version` ya
instaladas:

```bash
mkdir -p export/web
"$GODOT_BIN" --headless --path . --export-release "Web" export/web/index.html || true
python .claude/scripts/verificar_export.py export/web   # el veredicto NO es el $? de arriba

cp vercel.json export/web/
vercel deploy export/web --prod --yes --token "$VERCEL_TOKEN"

python .claude/scripts/verificar_despliegue.py https://<proyecto>.vercel.app
node .github/scripts/humo_en_navegador.mjs https://<proyecto>.vercel.app
```

Las templates se bajan una vez desde el editor (**Editor → Manage Export Templates**) o a mano
a `~/.local/share/godot/export_templates/<version>.stable/` — con **punto** y no con guion, que
es como se llama la release: puesto con el nombre equivocado, Godot dice que faltan.

## Lo que todavía no se corrió

**El proyecto de Vercel ya existe**, y el 2026-09-07 se corrió `verificar_despliegue.py` contra
una URL viva: contestó rojo nombrando los cuatro `302` de la Deployment Protection. O sea que el
verificador **sí llega a una publicación real y la juzga** — eso dejó de ser una afirmación sobre
el código.

Lo que sigue sin correrse es el resto de la cadena, y falta por dos cosas concretas:

- **Los tres secretos no están cargados** (`gh secret list` no devuelve ninguno el 2026-09-07),
  así que `desplegar.yml` todavía no puede publicar. El workflow falla en su primer paso
  nombrando cuál falta, que es lo que se diseñó.
- **La protección del deploy sigue puesta**, así que aunque se publicara, la URL contestaría el
  `302` de arriba.

Con esas dos, la primera corrida de `desplegar` sobre `main` cierra el humo en navegador, que es
lo único que nunca se ejerció: `humo_en_navegador.mjs` no corrió nunca, ni acá ni en CI.

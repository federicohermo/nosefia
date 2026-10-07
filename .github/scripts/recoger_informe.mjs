// Abrir el export web de un escenario de medición y guardar el informe que imprime.
//
//     python .github/scripts/servir_export.py <destino>/web 8060     (en otra terminal)
//     node .github/scripts/recoger_informe.mjs http://localhost:8060 reports/informe.json
//     node .github/scripts/recoger_informe.mjs <URL> <salida.json> --espera-s 120 --sin-limite-de-cuadros
//
// El export sale de `exportar_escenario.py`. Sirve para los escenarios de `test/performance/`
// que se miden solos: en la web no hay `res://reports/`, y el informe sale por la consola.
// Dónde se instala Playwright y cómo se comparan dos revisiones: docs/guides/rendimiento.md.
//
// ## El protocolo con el escenario
//
// - El escenario imprime una línea `[informe] {json}` al terminar. Es lo que se guarda, junto
//   con el navegador, el renderer y la resolución.
// - `[captura] nombre` pide una foto: queda en `<salida sin .json>-nombre.png`, y después
//   `window.__capturas` sube en uno. El escenario lo espera con `JavaScriptBridge.eval`.
// - `window.__subidas_de_buffers` cuenta las llamadas a `bufferData` y `bufferSubData` de
//   WebGL2 desde la carga. El escenario lo lee igual, antes y después de cada etapa.
//
// Chrome corre sin ventana, con ANGLE D3D11 en Windows. `--sin-limite-de-cuadros` saca la
// sincronización: con ella, todo lo que tarde menos que el monitor mide igual.
//
// Falla con renderizado por software, con un error de la página o del juego, y si el informe
// no llega a tiempo. No es un gate y no tiene umbral: el número depende de la máquina.

import { writeFileSync } from 'node:fs';
import { chromium } from 'playwright';

const posicionales = [];
let espera = 300;
let sinLimite = false;
const opciones = process.argv.slice(2);
for (let i = 0; i < opciones.length; i++) {
  if (opciones[i] === '--espera-s') espera = Number(opciones[++i]);
  else if (opciones[i] === '--sin-limite-de-cuadros') sinLimite = true;
  else posicionales.push(opciones[i]);
}
const [url, salida] = posicionales;
if (!url || !salida) {
  console.error(
    'uso: node .github/scripts/recoger_informe.mjs <URL> <salida.json> [--espera-s N] [--sin-limite-de-cuadros]'
  );
  process.exit(2);
}

const CONTAR_SUBIDAS = () => {
  window.__subidas_de_buffers = 0;
  window.__capturas = 0;
  for (const nombre of ['bufferData', 'bufferSubData']) {
    const original = WebGL2RenderingContext.prototype[nombre];
    WebGL2RenderingContext.prototype[nombre] = function (...args) {
      window.__subidas_de_buffers++;
      return original.apply(this, args);
    };
  }
};

const navegador = await chromium.launch({
  channel: 'chrome',
  headless: true,
  args: [
    '--window-size=1600,900',
    '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
    '--disable-background-timer-throttling',
    ...(sinLimite ? ['--disable-frame-rate-limit', '--disable-gpu-vsync'] : []),
    ...(process.platform === 'win32' ? ['--use-angle=d3d11'] : []),
  ],
});

let codigo = 0;
try {
  const contexto = await navegador.newContext({ viewport: { width: 1536, height: 760 } });
  const pagina = await contexto.newPage();
  await pagina.addInitScript(CONTAR_SUBIDAS);
  const errores = [];
  const capturas = [];
  let pendiente = Promise.resolve();
  const informe = new Promise((listo, falla) => {
    pagina.on('pageerror', (error) => falla(new Error(`error de la página: ${error.message}`)));
    pagina.on('console', (mensaje) => {
      const texto = mensaje.text();
      if (texto.startsWith('[informe] ')) {
        try {
          listo(JSON.parse(texto.slice('[informe] '.length)));
        } catch (error) {
          falla(new Error(`el informe no es JSON: ${error.message}`));
        }
      } else if (texto.startsWith('[captura] ')) {
        const nombre = texto.slice('[captura] '.length).trim();
        const archivo = `${salida.replace(/\.json$/, '')}-${nombre}.png`;
        pendiente = pendiente
          .then(() => pagina.screenshot({ path: archivo }))
          .then(() => pagina.evaluate(() => window.__capturas++))
          .then(() => capturas.push(archivo))
          .catch(falla);
      } else if (mensaje.type() === 'error' || /SCRIPT ERROR|^ERROR:/.test(texto)) {
        errores.push(texto);
      } else {
        console.log(texto);
      }
    });
  });
  await pagina.goto(url, { waitUntil: 'load', timeout: espera * 1000 });
  const gpu = await pagina.evaluate(() => {
    const gl = document.createElement('canvas').getContext('webgl2');
    const info = gl?.getExtension('WEBGL_debug_renderer_info');
    return info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : null;
  });
  if (!gpu || /swiftshader|llvmpipe|software|basic render driver|warp/i.test(gpu)) {
    throw new Error(`la medición exige GPU real; renderer: ${gpu}`);
  }
  let temporizador;
  const plazo = new Promise((_, falla) => {
    temporizador = setTimeout(
      () => falla(new Error([`no llegó el informe en ${espera} s`, ...errores].join('\n'))),
      espera * 1000
    );
  });
  const datos = await Promise.race([informe, plazo]).finally(() => clearTimeout(temporizador));
  await pendiente;
  if (errores.length) throw new Error(`el juego informó errores:\n${errores.join('\n')}`);
  const lienzo = await pagina.evaluate(() => {
    const canvas = document.querySelector('canvas');
    return `${canvas.width}x${canvas.height}`;
  });
  writeFileSync(
    salida,
    JSON.stringify(
      {
        url,
        fecha: new Date().toISOString(),
        condiciones: {
          navegador: navegador.version(),
          renderer: gpu,
          viewport: '1536x760',
          lienzo,
          sinVentana: true,
          sinLimiteDeCuadros: sinLimite,
        },
        capturas,
        informe: datos,
      },
      null,
      1
    )
  );
  console.log(`guardado en ${salida}`);
} catch (error) {
  console.error(error.message);
  codigo = 1;
} finally {
  await navegador.close();
}
process.exit(codigo);

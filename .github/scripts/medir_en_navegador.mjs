// Medir cuánto tarda un cuadro del juego publicado, con la CPU frenada como en una máquina floja.
//
//     npm install --no-save playwright
//     node .github/scripts/medir_en_navegador.mjs https://nosefia.vercel.app
//     node .github/scripts/medir_en_navegador.mjs https://nosefia.vercel.app 1,4,6 salida.json
//
// ## Por qué existe
//
// El juego corre en la web, y el escritorio no dice cómo corre ahí: medido el 2026-09-21, el
// mismo roce contra una góndola costaba 5 ms por paso en escritorio y llevaba el cuadro de la web
// a 80 ms. Lo que se mide acá es lo que ve una persona: el tiempo entre dos cuadros del
// navegador, en un Chrome de verdad, contra la URL publicada.
//
// ## Qué simula y qué no
//
// - **La CPU sí.** Chrome la frena por el protocolo de DevTools. Las tasas 4 y 6 son estrés
//   sintético; no representan un modelo de equipo ni prueban qué componente limita el juego.
// - **La GPU no.** No se emula. Sin GPU —con el dibujo por software— el juego ni llega a
//   dibujar. Una GPU floja se mide en una máquina que la tenga, con este mismo comando.
//
// ## Qué mide
//
// El juego abre en el menú de inicio. El script elige «Nuevo juego», que en la web cae al 56 % del
// alto del lienzo, y mide el almacén.
//
// Desde donde arranca el jugador, que muestra el local entero: es la vista más cara. Tres
// gestos por cada velocidad de CPU: quieto, caminando de costado y girando sobre sí mismo.
// De cada uno, los cuadros por segundo y el tiempo entre cuadros: mediana, p95 y máximo.
//
// **Abre una ventana y tiene que quedar a la vista**: un navegador no dibuja cuadros de una
// pestaña tapada o minimizada, y la medición sale vacía.
//
// No es un gate y no tiene umbral: el número depende de la máquina. Sirve para comparar un
// cambio contra el anterior en el mismo equipo. Entre dos corridas iguales hay un 20 % de ruido.

import { writeFileSync } from 'node:fs';
import { cpus, platform, release, totalmem } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { chromium } from 'playwright';

const ESPERA = 180_000;
const ALTURA_DE_NUEVO_JUEGO = 0.56;
const AVISO_DEL_MENU = '[carga] menú visible';
const AVISO_DEL_ALMACEN = '[carga] almacén en pantalla';

const url = process.argv[2];
if (!url) {
  console.error('uso: node .github/scripts/medir_en_navegador.mjs <URL> [tasas] [salida.json]');
  process.exit(2);
}
const tasas = (process.argv[3] ?? '1,4,6').split(',').map(Number);
const salida = process.argv[4];

// El motor escucha `pointermove` sobre `window` y las teclas sobre el canvas, y sólo gira la
// cámara con el cursor capturado. Un navegador manejado no puede capturarlo, así que se le
// contesta al motor que ya lo está.
const GANCHOS_DE_ENTRADA = () => {
  // El motor pide la captura mientras entra al árbol, antes del aviso del almacén.
  Object.defineProperty(document, 'pointerLockElement', {
    configurable: true,
    get: () => document.querySelector('canvas'),
  });
  Element.prototype.requestPointerLock = function () {
    setTimeout(() => document.dispatchEvent(new Event('pointerlockchange')), 0);
    return Promise.resolve();
  };
  document.exitPointerLock = function () {};
};

const GANCHOS = () => {
  const canvas = document.querySelector('canvas');
  document.dispatchEvent(new Event('pointerlockchange'));

  const pausa = (ms) => new Promise((listo) => setTimeout(listo, ms));
  window.__girar = async (dx, pasos) => {
    for (let i = 0; i < pasos; i++) {
      window.dispatchEvent(
        new PointerEvent('pointermove', {
          bubbles: true,
          movementX: dx / pasos,
          movementY: 0,
          clientX: 600,
          clientY: 300,
          pointerType: 'mouse',
        })
      );
      await pausa(30);
    }
  };
  window.__apretar = (code, key) => {
    const tecla = { code, key, bubbles: true };
    canvas.dispatchEvent(new KeyboardEvent('keydown', tecla));
    return () => canvas.dispatchEvent(new KeyboardEvent('keyup', tecla));
  };

  const cuadros = [];
  (function anotar(ahora) {
    cuadros.push(ahora);
    if (cuadros.length > 20000) cuadros.shift();
    requestAnimationFrame(anotar);
  })(performance.now());

  window.__medir = async (ms) => {
    await pausa(300);
    const desde = performance.now();
    await pausa(ms);
    const tiempos = cuadros.filter((t) => t >= desde);
    const entre = tiempos.slice(1).map((t, i) => t - tiempos[i]);
    entre.sort((a, b) => a - b);
    if (entre.length < 3) return null;
    const en = (q) => +entre[Math.floor((entre.length - 1) * q)].toFixed(1);
    const duracion = tiempos[tiempos.length - 1] - tiempos[0];
    return { fps: Math.round((1000 * (tiempos.length - 1)) / duracion), p50: en(0.5), p95: en(0.95), max: en(1) };
  };

  const gl = document.createElement('canvas').getContext('webgl2');
  const info = gl && gl.getExtension('WEBGL_debug_renderer_info');
  return {
    gpu: info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : 'desconocida',
    canvas: `${canvas.width}x${canvas.height}`,
    ventana: `${innerWidth}x${innerHeight}`,
    escala: devicePixelRatio,
    navegador: navigator.userAgent,
    procesadoresLogicos: navigator.hardwareConcurrency,
  };
};

const GESTOS = {
  quieto: () => window.__medir(4000),
  caminando: async () => {
    const soltar = window.__apretar('KeyA', 'a');
    const medido = await window.__medir(2500);
    soltar();
    const volver = window.__apretar('KeyD', 'd');
    await new Promise((listo) => setTimeout(listo, 2800));
    volver();
    return medido;
  },
  girando: async () => {
    const medido = window.__medir(3000);
    await window.__girar(1200, 60);
    await window.__girar(-1200, 60);
    return medido;
  },
};

// El aviso llega después del calentamiento. Un caché caliente puede no dejar ningún hueco
// entre cuadros; esperar ese hueco confundía la carga con el juego o vencía el plazo.
function esperarAviso(pagina, texto) {
  return pagina.waitForEvent('console', {
    predicate: (mensaje) => mensaje.text().includes(texto),
    timeout: ESPERA,
  });
}

// Sin tope de cuadros: con el vsync puesto, todo lo que tarde menos que el monitor mide igual.
const navegador = await chromium.launch({
  channel: 'chrome',
  headless: false,
  args: [
    '--window-size=1600,900',
    '--disable-frame-rate-limit',
    '--disable-gpu-vsync',
    '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
  ],
});
const pagina = await navegador.newPage({ viewport: { width: 1536, height: 760 } });
// Se coloca antes de cargar Godot: moverlo al primer clic podía girar la cámara del juego.
await pagina.mouse.move(768, 760 * ALTURA_DE_NUEVO_JUEGO);
await pagina.addInitScript(GANCHOS_DE_ENTRADA);
const filas = [];
let equipo = {};
const carga = {};
const desde = Date.now();
const etapa = (nombre) => console.log(`[medición] ${nombre}: ${Date.now() - desde} ms`);
const foto = async (nombre) => {
  if (!salida) return;
  const archivo = `${basename(salida, '.json')}-${nombre}.png`;
  await pagina.screenshot({ path: join(dirname(salida), archivo) });
};
try {
  const menu = esperarAviso(pagina, AVISO_DEL_MENU).then(() => {
    carga.menu = Date.now() - desde;
    etapa('menú visible');
  });
  etapa('navegación');
  await Promise.all([pagina.goto(url, { waitUntil: 'load', timeout: ESPERA }), menu]);
  await pagina.waitForSelector('#status', { state: 'detached', timeout: ESPERA });
  carga.overlay = Date.now() - desde;
  // El aviso antecede al primer dibujo: el botón debe existir cuando llega el clic.
  await pagina.evaluate(
    () => new Promise((listo) => requestAnimationFrame(() => requestAnimationFrame(listo)))
  );
  const lienzo = await pagina.locator('canvas').boundingBox();
  const almacen = esperarAviso(pagina, AVISO_DEL_ALMACEN);
  await Promise.all([
    pagina.mouse.click(
      lienzo.x + lienzo.width / 2,
      lienzo.y + lienzo.height * ALTURA_DE_NUEVO_JUEGO
    ),
    almacen,
  ]);
  carga.almacen = Date.now() - desde;
  etapa('almacén visible');
  equipo = await pagina.evaluate(GANCHOS);
  equipo.host = {
    sistema: platform(),
    version: release(),
    cpu: cpus()[0]?.model ?? 'desconocida',
    procesadoresLogicos: cpus().length,
    memoriaBytes: totalmem(),
  };
  console.log(`GPU: ${equipo.gpu}\ncanvas: ${equipo.canvas}\n`);
  // Las fotos de entrada quedan fuera del intervalo medido: capturarlas altera un cuadro.
  await foto('inicio');
  await pagina.evaluate(() => window.__girar(250, 12));
  await foto('giro-de-prueba');
  await pagina.evaluate(() => window.__girar(-250, 12));
  await pagina.evaluate(async () => {
    const soltar = window.__apretar('KeyA', 'a');
    await new Promise((listo) => setTimeout(listo, 600));
    soltar();
  });
  await foto('paso-de-prueba');
  await pagina.evaluate(async () => {
    const soltar = window.__apretar('KeyD', 'd');
    await new Promise((listo) => setTimeout(listo, 600));
    soltar();
  });
  etapa('entrada preparada');

  const devtools = await pagina.context().newCDPSession(pagina);
  for (const tasa of tasas) {
    await devtools.send('Emulation.setCPUThrottlingRate', { rate: tasa });
    await pagina.waitForTimeout(1500);
    for (const [gesto, medir] of Object.entries(GESTOS)) {
      const medido = await pagina.evaluate(medir);
      if (medido === null) {
        console.error(
          `CPU x${tasa}, ${gesto}: no hubo cuadros. La ventana tiene que quedar a la vista.`
        );
        process.exitCode = 1;
        continue;
      }
      filas.push({ cpu: tasa, gesto, ...medido });
      console.log(
        `CPU x${tasa}  ${gesto.padEnd(10)} ${String(medido.fps).padStart(4)} fps   ` +
          `p50 ${medido.p50} ms   p95 ${medido.p95} ms   max ${medido.max} ms`
      );
    }
  }
  await foto('fin');
} finally {
  await navegador.close();
}

if (salida) {
  writeFileSync(
    salida,
    JSON.stringify({ url, fecha: new Date().toISOString(), equipo, carga, filas }, null, 1)
  );
  console.log(`\nguardado en ${salida}`);
}

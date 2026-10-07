// Medir cuánto tarda el juego en mostrar el menú y en entrar al almacén, en un Chrome de verdad.
//
//     npm install --no-save playwright
//     python .github/scripts/servir_export.py export/web 8060     (en otra terminal)
//     node .github/scripts/medir_la_carga.mjs http://localhost:8060
//     node .github/scripts/medir_la_carga.mjs http://localhost:8060 reports/carga.json
//     node .github/scripts/medir_la_carga.mjs http://localhost:8060 reports/carga.json --sin-ventana
//
// ## Qué mide
//
// Tres tiempos, todos desde la navegación:
//
// - **overlay:** el shell de Godot saca `#status` del DOM. Hasta ahí, el navegador bajó el
//   `.wasm` y el `.pck` enteros.
// - **menú:** el juego escribe `[carga] menú visible` en la consola.
// - **almacén:** el juego escribe `[carga] almacén en pantalla`. El script elige «Nuevo juego»
//   apenas ve el aviso del menú. El clic va a la altura del botón con la ventana de 1536×760
//   que abre el script: con otro tamaño, el botón queda en otro lado.
//
// Y dos conteos, entre el clic y el aviso del almacén:
//
// - **programas:** las llamadas a `linkProgram` de WebGL2.
// - **fuentes_distintas:** los pares distintos de fuentes de vértices y de fragmentos entre
//   esos programas.
//
// Hace tres corridas con contextos HTTP nuevos dentro del mismo Chrome. El navegador puede
// conservar su caché de shaders entre corridas: la primera y las siguientes se informan aparte.
// Usa la sincronización de cuadros habitual del navegador; quitarla para medir FPS puede
// aumentar la contención durante la lectura de recursos y falsear la espera de carga.
//
// **Abre una ventana y tiene que quedar a la vista**: un Chrome tapado casi no pide cuadros.
// --sin-ventana evita esa pausa para medir la carga mientras se usa otra aplicación. Registra
// el renderer real y falla si Chrome usa renderizado por software. No mide la presentación
// de una ventana ni reemplaza un benchmark de FPS durante la partida.
//
// No es un gate y no tiene umbral: el número depende de la máquina. Sirve para comparar un
// cambio contra el anterior en el mismo equipo.

import { writeFileSync } from 'node:fs';
import { chromium } from 'playwright';

const ESPERA = 180_000;
const CORRIDAS = 3;
const AVISO_DEL_MENU = '[carga] menú visible';
const AVISO_DEL_ALMACEN = '[carga] almacén en pantalla';
const ALTURA_DE_NUEVO_JUEGO = 0.56;

const argumentos = process.argv.slice(2).filter((argumento) => argumento !== '--sin-ventana');
const url = argumentos[0];
if (!url) {
  console.error('uso: node .github/scripts/medir_la_carga.mjs <URL> [salida.json]');
  process.exit(2);
}
const salida = argumentos[1];
const sinVentana = process.argv.includes('--sin-ventana');

const navegador = await chromium.launch({
  channel: 'chrome',
  headless: sinVentana,
  args: [
    '--window-size=1600,900',
    '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
    '--disable-background-timer-throttling',
    ...(sinVentana && process.platform === 'win32' ? ['--use-angle=d3d11'] : []),
  ],
});

function aviso(pagina, texto) {
  return new Promise((listo) => {
    pagina.on('console', (mensaje) => {
      if (mensaje.text().includes(texto)) listo(Date.now());
    });
  });
}

function dentroDe(promesa, que) {
  let temporizador;
  const plazo = new Promise((_, falla) =>
    temporizador = setTimeout(() => falla(new Error(`no llegó ${que} en ${ESPERA / 1000} s`)), ESPERA)
  );
  return Promise.race([promesa, plazo]).finally(() => clearTimeout(temporizador));
}

// Corre en la página, antes que el juego. Dos programas con el mismo par de fuentes cuestan
// una sola compilación: Chrome reutiliza la primera.
function contarEnlaces() {
  const enlaces = (window.__enlaces = { programas: 0, fuentes: new Set() });
  const enlazar = WebGL2RenderingContext.prototype.linkProgram;
  WebGL2RenderingContext.prototype.linkProgram = function (programa) {
    enlaces.programas++;
    const fuentes = this.getAttachedShaders(programa).map(
      (shader) => `${this.getShaderParameter(shader, this.SHADER_TYPE)}\n${this.getShaderSource(shader)}`
    );
    enlaces.fuentes.add(fuentes.sort().join('\0'));
    return enlazar.call(this, programa);
  };
}

async function corrida() {
  const contexto = await navegador.newContext({ viewport: { width: 1536, height: 760 } });
  const pagina = await contexto.newPage();
  await pagina.addInitScript(contarEnlaces);
  try {
    await pagina.mouse.move(768, 760 * ALTURA_DE_NUEVO_JUEGO);
    const menu = aviso(pagina, AVISO_DEL_MENU);
    const almacen = aviso(pagina, AVISO_DEL_ALMACEN);
    const desde = Date.now();
    await pagina.goto(url, { waitUntil: 'load', timeout: ESPERA });
    await pagina.waitForSelector('#status', { state: 'detached', timeout: ESPERA });
    const overlay = Date.now() - desde;
    const gpu = await pagina.evaluate(() => {
      const gl = document.createElement('canvas').getContext('webgl2');
      const info = gl?.getExtension('WEBGL_debug_renderer_info');
      return info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : null;
    });
    if (sinVentana && (!gpu || /swiftshader|llvmpipe|software|basic render driver|warp/i.test(gpu))) {
      throw new Error(`la medición sin ventana exige GPU real; renderer: ${gpu}`);
    }
    const vioElMenu = (await dentroDe(menu, 'el aviso del menú')) - desde;
    // El aviso sale antes del primer cuadro del menú: se espera ese cuadro para que el botón
    // ya esté dibujado cuando llega el clic.
    await pagina.evaluate(
      () => new Promise((listo) => requestAnimationFrame(() => requestAnimationFrame(listo)))
    );
    const lienzo = await pagina.locator('canvas').boundingBox();
    await pagina.evaluate(() => {
      window.__enlaces.programas = 0;
      window.__enlaces.fuentes.clear();
    });
    const clic = Date.now() - desde;
    await pagina.mouse.click(
      lienzo.x + lienzo.width / 2,
      lienzo.y + lienzo.height * ALTURA_DE_NUEVO_JUEGO
    );
    const entro = (await dentroDe(almacen, 'el aviso del almacén')) - desde;
    const enlaces = await pagina.evaluate(() => ({
      programas: window.__enlaces.programas,
      fuentes_distintas: window.__enlaces.fuentes.size,
    }));
    return { overlay, menu: vioElMenu, clic, almacen: entro, desdeElClic: entro - clic, gpu, ...enlaces };
  } finally {
    await contexto.close();
  }
}

function mediana(valores) {
  const orden = [...valores].sort((a, b) => a - b);
  return orden[Math.floor(orden.length / 2)];
}

const corridas = [];
try {
  for (let i = 0; i < CORRIDAS; i++) {
    const medida = await corrida();
    corridas.push(medida);
    console.log(
      `corrida ${i + 1}: overlay ${medida.overlay} ms   menú ${medida.menu} ms   ` +
        `almacén ${medida.almacen} ms`
    );
  }
} finally {
  await navegador.close();
}

const medianas = Object.fromEntries(
  ['overlay', 'menu', 'almacen'].map((clave) => [clave, mediana(corridas.map((c) => c[clave]))])
);
console.log(
  `\nmediana: overlay ${medianas.overlay} ms   menú ${medianas.menu} ms   ` +
    `almacén ${medianas.almacen} ms`
);
console.log(
  `desde el clic: primera ${corridas[0].desdeElClic} ms; ` +
    `siguientes ${corridas.slice(1).map((c) => c.desdeElClic + ' ms').join(', ')}`
);
console.log(
  `programas y fuentes distintas: ${corridas.map((c) => `${c.programas} y ${c.fuentes_distintas}`).join('; ')}`
);

if (salida) {
  writeFileSync(salida, JSON.stringify({ url, fecha: new Date().toISOString(), corridas, medianas,
    condiciones: { navegador: navegador.version(), viewport: { ancho: 1536, alto: 760 },
      sincronizacionHabitual: true, cpuLimitada: false, contextosHTTPNuevos: true,
      sinVentana,
      cacheDeShadersCompartida: 'posible dentro del mismo navegador' } }, null, 1));
  console.log(`guardado en ${salida}`);
}

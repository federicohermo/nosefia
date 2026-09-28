// Medir cuánto tarda el juego en mostrar el menú y en entrar al almacén, en un Chrome de verdad.
//
//     npm install --no-save playwright
//     python .github/scripts/servir_export.py export/web 8060     (en otra terminal)
//     node .github/scripts/medir_la_carga.mjs http://localhost:8060
//     node .github/scripts/medir_la_carga.mjs http://localhost:8060 reports/carga.json
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
// Hace tres corridas, cada una con el caché vacío, y da la mediana de cada tiempo.
//
// **Abre una ventana y tiene que quedar a la vista**: un Chrome tapado casi no pide cuadros.
//
// No es un gate y no tiene umbral: el número depende de la máquina. Sirve para comparar un
// cambio contra el anterior en el mismo equipo.

import { writeFileSync } from 'node:fs';
import { chromium } from 'playwright';

const ESPERA = 180_000;
const CORRIDAS = 3;
const AVISO_DEL_MENU = '[carga] menú visible';
const AVISO_DEL_ALMACEN = '[carga] almacén en pantalla';
const ALTURA_DE_NUEVO_JUEGO = 0.6;

const url = process.argv[2];
if (!url) {
  console.error('uso: node .github/scripts/medir_la_carga.mjs <URL> [salida.json]');
  process.exit(2);
}
const salida = process.argv[3];

const navegador = await chromium.launch({
  channel: 'chrome',
  headless: false,
  args: [
    '--window-size=1600,900',
    '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
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
  const plazo = new Promise((_, falla) =>
    setTimeout(() => falla(new Error(`no llegó ${que} en ${ESPERA / 1000} s`)), ESPERA)
  );
  return Promise.race([promesa, plazo]);
}

async function corrida() {
  const contexto = await navegador.newContext({ viewport: { width: 1536, height: 760 } });
  const pagina = await contexto.newPage();
  try {
    const menu = aviso(pagina, AVISO_DEL_MENU);
    const almacen = aviso(pagina, AVISO_DEL_ALMACEN);
    const desde = Date.now();
    await pagina.goto(url, { waitUntil: 'load', timeout: ESPERA });
    await pagina.waitForSelector('#status', { state: 'detached', timeout: ESPERA });
    const overlay = Date.now() - desde;
    const vioElMenu = (await dentroDe(menu, 'el aviso del menú')) - desde;
    // El aviso sale antes del primer cuadro del menú: se espera ese cuadro para que el botón
    // ya esté dibujado cuando llega el clic.
    await pagina.evaluate(
      () => new Promise((listo) => requestAnimationFrame(() => requestAnimationFrame(listo)))
    );
    const lienzo = await pagina.locator('canvas').boundingBox();
    await pagina.mouse.click(
      lienzo.x + lienzo.width / 2,
      lienzo.y + lienzo.height * ALTURA_DE_NUEVO_JUEGO
    );
    const entro = (await dentroDe(almacen, 'el aviso del almacén')) - desde;
    return { overlay, menu: vioElMenu, almacen: entro };
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

if (salida) {
  writeFileSync(salida, JSON.stringify({ url, fecha: new Date().toISOString(), corridas, medianas }, null, 1));
  console.log(`guardado en ${salida}`);
}

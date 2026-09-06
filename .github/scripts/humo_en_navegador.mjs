// Abrir la URL publicada en un Chromium de verdad y fallar si el juego no arrancó.
//
//     node .github/scripts/humo_en_navegador.mjs https://<proyecto>.vercel.app
//
// Es el único paso de todo el despliegue que mira lo que ve una persona. Todo lo de más
// arriba —que el export dejó los archivos, que la URL contesta 200 con los dos headers— puede
// estar en verde con la pantalla en negro: el `index.js` que genera Godot nombra
// `SharedArrayBuffer` 15 veces y aborta al arrancar si el aislamiento no está, y eso pasa
// DESPUÉS de que el HTML cargó. HTTP no lo puede ver.
//
// ## Los tres testigos, y por qué hacen falta los tres
//
// 1. `crossOriginIsolated` — es la pregunta que el propio motor le hace al navegador. Los
//    headers pueden estar en la respuesta y el aislamiento no valer igual (un iframe, un
//    recurso de otro origen sin CORP), y entonces `SharedArrayBuffer` no existe.
// 2. Que el overlay `#status` desaparezca — el shell de Godot lo **saca del DOM** recién
//    cuando `startGame` resolvió. Que el canvas exista no dice nada: está en el HTML desde el
//    primer byte, vacío y negro, y así se queda si el motor no arrancó.
// 3. Que no haya errores de consola ni excepciones — un `abort()` de WebAssembly no cambia el
//    DOM: deja la página exactamente como estaba, cargando para siempre.
//
// El punto 2 está atado a la forma del shell que Godot genera, y eso hay que decirlo: si un
// release futuro cambia el overlay, este paso se pone rojo con un deploy sano. Se rompe hacia
// el lado correcto —bloquea una publicación en vez de bendecir una rota— y el mensaje dice
// exactamente qué esperaba, que es lo que hace que se arregle en minutos.

import { chromium } from 'playwright';

const ESPERA = 120_000; // Un `.wasm` de decenas de megas sobre el CDN, en un runner compartido.

const url = process.argv[2];
if (!url) {
  console.error('uso: node .github/scripts/humo_en_navegador.mjs <URL>');
  process.exit(2);
}

const navegador = await chromium.launch();
const pagina = await navegador.newPage();

const errores = [];
pagina.on('pageerror', (error) => errores.push(`excepción: ${error.message}`));
pagina.on('console', (mensaje) => {
  if (mensaje.type() === 'error') errores.push(`consola: ${mensaje.text()}`);
});

const problemas = [];
try {
  const respuesta = await pagina.goto(url, { waitUntil: 'load', timeout: ESPERA });
  if (!respuesta || !respuesta.ok()) {
    problemas.push(`la URL contestó ${respuesta ? respuesta.status() : 'nada'}.`);
  }

  const aislado = await pagina.evaluate(() => window.crossOriginIsolated === true);
  if (!aislado) {
    problemas.push(
      '`crossOriginIsolated` es false: el navegador no aplicó el aislamiento, así que ' +
        '`SharedArrayBuffer` no existe y el motor aborta antes de dibujar un pixel.'
    );
  }

  try {
    await pagina.waitForFunction(() => !document.getElementById('status'), null, {
      timeout: ESPERA,
    });
  } catch {
    // El aviso del propio shell vale más que el timeout: cuando el arranque falla, Godot
    // escribe ahí el motivo en castellano de máquina.
    const aviso = await pagina
      .evaluate(() => document.getElementById('status-notice')?.innerText?.trim() ?? '')
      .catch(() => '');
    problemas.push(
      `el juego no arrancó en ${ESPERA / 1000}s: el overlay de carga sigue en la página` +
        (aviso ? `, y dice: «${aviso}»` : ' y no dice por qué.')
    );
  }
} finally {
  await navegador.close();
}

for (const error of errores) problemas.push(error);

if (problemas.length > 0) {
  console.error(`«${url}» carga pero no se juega:\n`);
  for (const problema of problemas) console.error(`  - ${problema}`);
  console.error('\nPublicar no es haber publicado.');
  process.exit(1);
}

console.log(`«${url}» arrancó: aislado, sin errores y con el overlay de carga fuera.`);

// Inventariar las texturas de WebGL que el juego tiene vivas en el menú y en el almacén.
//
//     python .github/scripts/servir_export.py export/web 8060     (en otra terminal)
//     node .github/scripts/medir_memoria_de_texturas.mjs http://localhost:8060 reports/memoria-texturas.json
//     node .github/scripts/medir_memoria_de_texturas.mjs http://localhost:8060 reports/memoria-texturas.json --sin-ventana
//
// ## Qué estima
//
// Anota en la página cada llamada de WebGL2 que define, actualiza o borra una textura. Con eso
// arma dos inventarios: uno al aviso `[carga] menú visible` y otro al aviso
// `[carga] almacén en pantalla`, después de elegir «Nuevo juego». Cada fila es una textura
// viva, con sus dimensiones, su formato, sus mips, sus capas y sus bytes estimados. Las
// texturas que el motor usa como destino de renderizado entran como cualquier otra.
//
// El PCK y el WASM se informan aparte, con sus bytes y su SHA-256. Son tamaño en disco, no
// memoria de texturas, y no entran en ningún total.
//
// ## Qué no mide
//
// - La VRAM física, la memoria del driver y las copias en CPU. El número es el tamaño nominal
//   de cada formato: el driver puede alinear, convertir o duplicar.
// - Los renderbuffers y el framebuffer del lienzo.
// - Los contextos que no son WebGL2. El motor sólo usa WebGL2.
// - Si WebGL aceptó la llamada. Una definición que el navegador rechaza se cuenta igual.
//
// Un formato que no está en las tablas queda sin bytes, y la fase sale con
// `cobertura_completa` en falso. Lo mismo con un contexto perdido.
//
// ## Qué rechaza
//
// Sale con 1 y sin escribir el JSON si falta un aviso, si el juego escribe un error, si Chrome
// dibuja por software o si el juego no anuncia la versión del motor.
//
// Usa un contexto de navegador nuevo: no lee ni escribe el guardado de nadie. El clic va a la
// altura de «Nuevo juego» con la vista de 1536×760 que abre el script.
//
// No es un gate y no tiene umbral. Sirve para comparar un export contra otro.

import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { chromium } from 'playwright';
import {
  ENLACE_POR_DESTINO,
  FASES,
  METODOS,
  NIVELES_DE_MIPS,
  NO_MIDE,
  aplicar,
  crearRegistro,
  esRenderizadoPorSoftware,
  inventario,
  motivosDeRechazo,
  perderContexto,
} from './lib/memoria_de_texturas.mjs';

const ESPERA = 180_000;
const AVISO_DEL_MENU = '[carga] menú visible';
const AVISO_DEL_ALMACEN = '[carga] almacén en pantalla';
const ALTURA_DE_NUEVO_JUEGO = 0.56;
const VISTA = { width: 1536, height: 760 };

const argumentos = process.argv.slice(2).filter((argumento) => argumento !== '--sin-ventana');
const [url, salida] = argumentos;
if (!url || !salida) {
  console.error(
    'uso: node .github/scripts/medir_memoria_de_texturas.mjs <URL> <salida.json> [--sin-ventana]'
  );
  process.exit(2);
}
const sinVentana = process.argv.includes('--sin-ventana');

// Corre en la página antes que el motor, y sólo anota: qué textura estaba enlazada y los
// argumentos numéricos de la llamada. Qué significan lo decide el módulo.
const ANOTAR_LLAMADAS = ({ metodos, enlaces, nivelesDeMips }) => {
  const contextos = [];
  const texturas = new WeakMap();
  const llamadas = [];
  let ultima = 0;
  const resumir = (valor) => {
    if (typeof valor === 'number') return valor;
    if (typeof valor?.width === 'number') return { ancho: valor.width, alto: valor.height };
    return null;
  };
  for (const metodo of metodos) {
    const original = WebGL2RenderingContext.prototype[metodo];
    WebGL2RenderingContext.prototype[metodo] = function (...args) {
      const resultado = original.apply(this, args);
      const enlace = enlaces[args[0]];
      const textura =
        metodo === 'deleteTexture' ? args[0] : enlace ? this.getParameter(enlace) : null;
      if (!textura) return resultado;
      if (!texturas.has(textura)) texturas.set(textura, ++ultima);
      if (!contextos.includes(this)) contextos.push(this);
      const anotados =
        metodo === 'generateMipmap'
          ? [args[0], ...nivelesDeMips.map((nivel) => this.getTexParameter(args[0], nivel))]
          : args.map(resumir);
      llamadas.push({
        contexto: contextos.indexOf(this) + 1,
        textura: texturas.get(textura),
        metodo,
        args: anotados,
      });
      return resultado;
    };
  }
  window.__vaciarLlamadasDeTexturas = () => ({
    llamadas: llamadas.splice(0),
    perdidos: contextos.flatMap((gl, indice) => (gl.isContextLost() ? [indice + 1] : [])),
  });
};

function aviso(pagina, texto) {
  return new Promise((listo) => {
    pagina.on('console', (mensaje) => {
      if (mensaje.text().includes(texto)) listo();
    });
  });
}

function dentroDe(promesa, que) {
  let temporizador;
  const plazo = new Promise((_, falla) => {
    temporizador = setTimeout(
      () => falla(new Error(`no llegó ${que} en ${ESPERA / 1000} s`)),
      ESPERA
    );
  });
  return Promise.race([promesa, plazo]).finally(() => clearTimeout(temporizador));
}

async function huella(direccion) {
  const respuesta = await fetch(direccion);
  if (!respuesta.ok) throw new Error(`${direccion} contestó ${respuesta.status}`);
  const contenido = Buffer.from(await respuesta.arrayBuffer());
  return {
    archivo: new URL(direccion).pathname.split('/').pop(),
    bytes: contenido.length,
    sha256: createHash('sha256').update(contenido).digest('hex'),
  };
}

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

const registro = crearRegistro();
const errores = [];
const fases = {};
const pedidos = {};
const condiciones = {
  motor: null,
  navegador: navegador.version(),
  renderer: null,
  vista: `${VISTA.width}x${VISTA.height}`,
  lienzo: null,
  sin_ventana: sinVentana,
};
let exportEnDisco;

async function fotografiar(pagina) {
  // El aviso sale antes del cuadro que anuncia: se espera ese cuadro.
  await pagina.evaluate(
    () => new Promise((listo) => requestAnimationFrame(() => requestAnimationFrame(listo)))
  );
  const { llamadas, perdidos } = await pagina.evaluate(() => window.__vaciarLlamadasDeTexturas());
  for (const llamada of llamadas) aplicar(registro, llamada);
  for (const contexto of perdidos) perderContexto(registro, contexto);
  return inventario(registro);
}

async function medir() {
  const contexto = await navegador.newContext({ viewport: VISTA });
  const pagina = await contexto.newPage();
  await pagina.addInitScript(ANOTAR_LLAMADAS, {
    metodos: METODOS,
    enlaces: ENLACE_POR_DESTINO,
    nivelesDeMips: NIVELES_DE_MIPS,
  });
  pagina.on('pageerror', (error) => errores.push(error.message));
  pagina.on('console', (mensaje) => {
    const texto = mensaje.text();
    if (mensaje.type() === 'error') errores.push(texto);
    condiciones.motor ??= /^Godot Engine v(\S+)/.exec(texto)?.[1] ?? null;
  });
  pagina.on('request', (pedido) => {
    const extension = /\.(pck|wasm)$/.exec(new URL(pedido.url()).pathname)?.[1];
    if (extension) pedidos[extension] = pedido.url();
  });
  const menu = aviso(pagina, AVISO_DEL_MENU);
  const almacen = aviso(pagina, AVISO_DEL_ALMACEN);
  // El cursor se coloca antes de cargar el motor: moverlo al clic puede girar la cámara.
  await pagina.mouse.move(VISTA.width / 2, VISTA.height * ALTURA_DE_NUEVO_JUEGO);
  await pagina.goto(url, { waitUntil: 'load', timeout: ESPERA });
  condiciones.renderer = await pagina.evaluate(() => {
    const gl = document.createElement('canvas').getContext('webgl2');
    const info = gl?.getExtension('WEBGL_debug_renderer_info');
    return info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : null;
  });
  // Sin GPU real no vale la pena esperar al juego. El motivo lo arma `motivosDeRechazo`.
  if (esRenderizadoPorSoftware(condiciones.renderer)) return;

  await dentroDe(menu, 'el aviso del menú');
  fases.menu = await fotografiar(pagina);
  const lienzo = await pagina.locator('canvas').boundingBox();
  await pagina.mouse.click(
    lienzo.x + lienzo.width / 2,
    lienzo.y + lienzo.height * ALTURA_DE_NUEVO_JUEGO
  );
  await dentroDe(almacen, 'el aviso del almacén');
  fases.almacen = await fotografiar(pagina);
  condiciones.lienzo = await pagina.evaluate(() => {
    const canvas = document.querySelector('canvas');
    return `${canvas.width}x${canvas.height}`;
  });
  if (!pedidos.pck || !pedidos.wasm) throw new Error('la página no pidió su PCK o su WASM');
  exportEnDisco = { pck: await huella(pedidos.pck), wasm: await huella(pedidos.wasm) };
}

const motivos = [];
try {
  await medir();
} catch (error) {
  motivos.push(error.message);
} finally {
  await navegador.close();
}
motivos.push(...motivosDeRechazo({ ...condiciones, errores, fases }));
if (motivos.length) {
  console.error('no hay informe:');
  for (const motivo of motivos) console.error(`  - ${motivo}`);
  process.exit(1);
}

for (const fase of FASES) {
  const { cantidad, bytes_estimados, MiB_estimados, formatos_desconocidos, contextos_perdidos } =
    fases[fase];
  console.log(`${fase}: ${cantidad} texturas, ${bytes_estimados} bytes (${MiB_estimados} MiB)`);
  for (const { formato, imagenes } of formatos_desconocidos) {
    console.error(`  cobertura incompleta: ${imagenes} imágenes de formato ${formato} sin medir`);
  }
  for (const contexto of contextos_perdidos) {
    console.error(`  cobertura incompleta: se perdió el contexto ${contexto}`);
  }
}
for (const { archivo, bytes } of Object.values(exportEnDisco)) {
  console.log(`${archivo}: ${bytes} bytes en disco, que no son memoria de texturas`);
}

mkdirSync(dirname(salida), { recursive: true });
writeFileSync(
  salida,
  JSON.stringify(
    {
      url,
      fecha: new Date().toISOString(),
      condiciones,
      export_en_disco: exportEnDisco,
      no_mide: NO_MIDE,
      fases,
    },
    null,
    1
  )
);
console.log(`guardado en ${salida}`);

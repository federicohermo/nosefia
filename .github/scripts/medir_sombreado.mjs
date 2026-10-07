// Comparar el costo de GPU y la imagen del shader de agua y manchas entre dos exports web.
//
//     npm install --no-save playwright
//     python .github/scripts/servir_export.py <export base>/web 8060        (en otra terminal)
//     python .github/scripts/servir_export.py <export propuesta>/web 8061   (en otra terminal)
//     node .github/scripts/medir_sombreado.mjs --base http://localhost:8060 \
//       --propuesta http://localhost:8061 --casos agua --salida reports/agua.json
//
// Los dos exports tienen `test/performance/medir_sombreado.tscn` como escena principal, y
// difieren sólo en el shader que se compara.
//
// ## Qué mide
//
// Por cada caso, el escenario dibuja el shader sobre un panel que ocupa la vista. El script
// espera 25 cuadros, mide 60 y saca una captura. Cada llamada de dibujo va adentro de una
// consulta `TIME_ELAPSED` de WebGL2, y el tiempo de un cuadro es la suma de las suyas. Una
// sola consulta por cuadro contaría también las esperas de la GPU entre un comando y otro.
// Un cuadro con una consulta disjunta o sin resultado no cuenta.
//
// Hace tres rondas, y cada una carga los dos exports de nuevo. El orden se alterna: lo que
// se mide segundo encuentra la GPU en otro estado que lo que se mide primero.
//
// Chrome dibuja sin tope de cuadros. Con el tope, la GPU casi no trabaja, y el mismo export
// midió varias veces más en unas cargas que en otras. Aun sin tope queda ruido: medir un
// export contra sí mismo dice cuánto, y una diferencia menor que ésa no es una mejora.
//
// ## Cuándo falla
//
// Sale con 1 si la captura de un caso cambia entre los dos exports más que la tolerancia de
// ese caso, si Chrome dibuja por software, si no hay consultas de tiempo, o si el juego
// informa un error. No compara milisegundos: el número depende del equipo.
//
// Chrome corre sin ventana, con ANGLE D3D11 en Windows.

import { mkdirSync, writeFileSync } from 'node:fs';
import { cpus } from 'node:os';
import { dirname } from 'node:path';
import { parseArgs } from 'node:util';
import { chromium } from 'playwright';
import {
  decodificarPng,
  diferenciaRgb,
  mediana,
  mismaImagen,
  tiemposPorCuadro,
} from './lib/consultas_gpu.mjs';

const ESPERA = 180_000;
const RONDAS = 3;
const CUADROS_DE_ESPERA = 25;
const CUADROS_MEDIDOS = 60;
// El primer caso de una carga recién abierta midió más del doble que el mismo caso después.
const CALENTAMIENTO_MS = 2000;
const VISTA = { width: 1536, height: 760 };

// Los nombres son los de `casos()` en `test/performance/medir_sombreado.gd`. Un caso `aparte`
// es un control: el cambio no lo optimiza, y se informa separado. `tolerancia` es cuánto
// puede cambiar su captura; sin ella, la captura tiene que ser idéntica.
const CASOS = {
  agua: [
    { nombre: 'agua_de_malla' },
    { nombre: 'agua_en_mezcla' },
    { nombre: 'agua_sin_color' },
    { nombre: 'agua_del_bano', aparte: true },
  ],
};

const { values: opciones } = parseArgs({
  options: {
    base: { type: 'string' },
    propuesta: { type: 'string' },
    casos: { type: 'string' },
    salida: { type: 'string' },
  },
});
const casos = CASOS[opciones.casos];
if (!opciones.base || !opciones.propuesta || !opciones.salida || !casos) {
  console.error(
    'uso: node .github/scripts/medir_sombreado.mjs --base <URL> --propuesta <URL> ' +
      `--casos <${Object.keys(CASOS).join('|')}> --salida <salida.json>`
  );
  process.exit(2);
}
const copias = { base: opciones.base, propuesta: opciones.propuesta };

// Corre antes que el motor: envuelve cada llamada de dibujo en una consulta de tiempo de GPU.
const GANCHOS = () => {
  const PLAZO_DE_RESULTADOS = 120;
  const DIBUJOS = ['drawArrays', 'drawElements', 'drawArraysInstanced', 'drawElementsInstanced'];
  let cuadro = 0;
  let medicion = null;

  const recoger = () => {
    const { gl, extension, consultas } = medicion;
    // La marca cubre todo lo que estaba pendiente desde la lectura anterior.
    const disjunta = gl.getParameter(extension.GPU_DISJOINT_EXT);
    for (const pendiente of medicion.pendientes) pendiente.disjunta ||= disjunta;
    medicion.pendientes = medicion.pendientes.filter(({ consulta, ...resto }) => {
      if (!gl.getQueryParameter(consulta, gl.QUERY_RESULT_AVAILABLE)) return true;
      consultas.push({ ...resto, ns: gl.getQueryParameter(consulta, gl.QUERY_RESULT) });
      gl.deleteQuery(consulta);
      return false;
    });
    const vencio = cuadro >= medicion.hasta + PLAZO_DE_RESULTADOS;
    if (cuadro < medicion.hasta || (medicion.pendientes.length && !vencio)) return;
    for (const { consulta, ...resto } of medicion.pendientes) {
      consultas.push({ ...resto, ns: null });
      gl.deleteQuery(consulta);
    }
    medicion.lista(consultas);
    medicion = null;
  };

  for (const nombre of DIBUJOS) {
    const dibujar = WebGL2RenderingContext.prototype[nombre];
    WebGL2RenderingContext.prototype[nombre] = function (...argumentos) {
      const mide = medicion?.gl === this && cuadro >= medicion.desde && cuadro < medicion.hasta;
      if (!mide) return dibujar.apply(this, argumentos);
      const consulta = this.createQuery();
      this.beginQuery(medicion.extension.TIME_ELAPSED_EXT, consulta);
      try {
        return dibujar.apply(this, argumentos);
      } finally {
        this.endQuery(medicion.extension.TIME_ELAPSED_EXT);
        medicion.pendientes.push({ cuadro, consulta, disjunta: false });
      }
    };
  }

  // El navegador llama a este pedido y al del motor una vez por cuadro, siempre en el mismo
  // orden: todos los dibujos de un cuadro del motor quedan con el mismo número.
  const alCuadro = () => {
    cuadro++;
    if (medicion) recoger();
    requestAnimationFrame(alCuadro);
  };
  requestAnimationFrame(alCuadro);

  window.__medirGpu = (espera, cuadros) =>
    new Promise((lista, falla) => {
      // Un lienzo devuelve siempre su mismo contexto: éste es el del motor.
      const gl = document.querySelector('canvas').getContext('webgl2');
      const extension = gl?.getExtension('EXT_disjoint_timer_query_webgl2');
      if (!extension) {
        falla(new Error('el navegador no ofrece consultas de tiempo de GPU'));
        return;
      }
      // Un corte anterior al pedido no invalida lo que se va a medir.
      gl.getParameter(extension.GPU_DISJOINT_EXT);
      const desde = cuadro + 1 + espera;
      const hasta = desde + cuadros;
      medicion = { gl, extension, desde, hasta, pendientes: [], consultas: [], lista };
    });
};

const navegador = await chromium.launch({
  channel: 'chrome',
  headless: true,
  args: [
    '--window-size=1600,900',
    '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
    '--disable-background-timer-throttling',
    '--disable-frame-rate-limit',
    '--disable-gpu-vsync',
    ...(process.platform === 'win32' ? ['--use-angle=d3d11'] : []),
  ],
});

const condiciones = {
  navegador: navegador.version(),
  cpu: cpus()[0]?.model ?? 'desconocida',
  vista: `${VISTA.width}x${VISTA.height}`,
  cuadrosDeEspera: CUADROS_DE_ESPERA,
  cuadrosMedidos: CUADROS_MEDIDOS,
  calentamientoMs: CALENTAMIENTO_MS,
  sinVentana: true,
  sinLimiteDeCuadros: true,
};

// Una carga nueva de un export: mide y captura todos los casos, en el orden declarado.
async function cargar(url, prefijo) {
  const contexto = await navegador.newContext({ viewport: VISTA });
  const pagina = await contexto.newPage();
  const errores = [];
  pagina.on('pageerror', (error) => errores.push(error.message));
  pagina.on('console', (mensaje) => {
    if (mensaje.type() === 'error' || /SCRIPT ERROR|^ERROR:/.test(mensaje.text())) {
      errores.push(mensaje.text());
    }
  });
  try {
    await pagina.addInitScript(GANCHOS);
    await pagina.goto(url, { waitUntil: 'load', timeout: ESPERA });
    const renderer = await pagina.evaluate(() => {
      const gl = document.createElement('canvas').getContext('webgl2');
      const info = gl?.getExtension('WEBGL_debug_renderer_info');
      return info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : null;
    });
    if (!renderer || /swiftshader|llvmpipe|software|basic render driver|warp/i.test(renderer)) {
      throw new Error(`la medición exige GPU real; renderer: ${renderer}`);
    }
    condiciones.renderer = renderer;
    await pagina.waitForFunction(() => typeof window.mostrar_caso === 'function', null, {
      timeout: ESPERA,
    });
    condiciones.lienzo = await pagina.evaluate(() => {
      const lienzo = document.querySelector('canvas');
      return `${lienzo.width}x${lienzo.height}`;
    });
    await pagina.waitForTimeout(CALENTAMIENTO_MS);
    const medidos = {};
    for (const { nombre } of casos) {
      const mostrado = await pagina.evaluate((caso) => {
        window.mostrar_caso(caso);
        return window.caso_mostrado;
      }, nombre);
      if (mostrado !== nombre) throw new Error(`el escenario no mostró «${nombre}»`);
      const consultas = await pagina.evaluate(
        ([espera, cuadros]) => window.__medirGpu(espera, cuadros),
        [CUADROS_DE_ESPERA, CUADROS_MEDIDOS]
      );
      const tiempos = tiemposPorCuadro(consultas);
      const captura = `${prefijo}-${nombre}.png`;
      const imagen = decodificarPng(await pagina.screenshot({ path: captura }));
      medidos[nombre] = { medianaMs: mediana(tiempos), validas: tiempos.length, captura, imagen };
    }
    if (errores.length) throw new Error('el juego informó errores');
    return medidos;
  } catch (error) {
    throw new Error([`${url}: ${error.message}`, ...errores].join('\n'));
  } finally {
    await contexto.close();
  }
}

const rondas = [];
let cambioLaImagen = false;
let codigo = 0;
try {
  mkdirSync(dirname(opciones.salida), { recursive: true });
  for (let ronda = 1; ronda <= RONDAS; ronda++) {
    const orden = ronda % 2 ? ['base', 'propuesta'] : ['propuesta', 'base'];
    const medidos = {};
    for (const copia of orden) {
      const prefijo = `${opciones.salida.replace(/\.json$/, '')}-ronda${ronda}-${copia}`;
      medidos[copia] = await cargar(copias[copia], prefijo);
    }
    console.log(`ronda ${ronda}: ${orden.join(', ')}`);
    const resultados = {};
    for (const { nombre, tolerancia } of casos) {
      const { imagen: deLaBase, ...base } = medidos.base[nombre];
      const { imagen: deLaPropuesta, ...propuesta } = medidos.propuesta[nombre];
      const diferencia = diferenciaRgb(deLaBase, deLaPropuesta);
      const igual = mismaImagen(diferencia, tolerancia);
      cambioLaImagen ||= !igual;
      resultados[nombre] = { base, propuesta, imagen: { ...diferencia, igual } };
      console.log(
        `  ${nombre.padEnd(16)} base ${base.medianaMs.toFixed(6)} ms (${base.validas})   ` +
          `propuesta ${propuesta.medianaMs.toFixed(6)} ms (${propuesta.validas})   ` +
          `imagen: ${diferencia.pixeles} px, ${diferencia.niveles} niveles` +
          (igual ? '' : '   CAMBIÓ')
      );
    }
    rondas.push({ orden, casos: resultados });
  }

  const medianas = {};
  console.log('\nmediana de las rondas');
  for (const { nombre, aparte } of casos) {
    medianas[nombre] = Object.fromEntries(
      Object.keys(copias).map((copia) => [
        copia,
        mediana(rondas.map((ronda) => ronda.casos[nombre][copia].medianaMs)),
      ])
    );
    console.log(
      `  ${nombre.padEnd(16)} base ${medianas[nombre].base.toFixed(6)} ms   ` +
        `propuesta ${medianas[nombre].propuesta.toFixed(6)} ms` +
        (aparte ? '   (control, aparte)' : '')
    );
  }

  writeFileSync(
    opciones.salida,
    JSON.stringify(
      { fecha: new Date().toISOString(), ...copias, casos, condiciones, rondas, medianas },
      null,
      1
    )
  );
  console.log(`\nguardado en ${opciones.salida}`);
  if (cambioLaImagen) {
    console.error('La imagen cambió entre la base y la propuesta.');
    codigo = 1;
  }
} catch (error) {
  console.error(error.message);
  codigo = 1;
} finally {
  await navegador.close();
}
process.exit(codigo);

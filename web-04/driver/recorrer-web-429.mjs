// Sólo Chrome suministra mouse/teclado. CDP userGesture:false observa o prepara fixture.
import {createRequire} from 'node:module';
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';

const [url, out, fixturePath] = process.argv.slice(2);
const require = createRequire('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/runner429.cjs');
const {chromium} = require('playwright');
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
mkdirSync(out, {recursive:true});
const records = [], actions = [];
let browser;
const persist = () => {
  writeFileSync(resolve(out, 'consola.json'), JSON.stringify(records,null,2));
  writeFileSync(resolve(out, 'recorrido.json'), JSON.stringify(actions,null,2));
};
const note = (type,text) => { records.push({type,text,time:Date.now()}); persist(); };
const requireTrue = (condition,message) => { if(!condition) throw new Error(message); };
const delay = ms => new Promise(r => setTimeout(r,ms));
const timer = setTimeout(() => { note('runner-error','Límite total de 300 segundos'); void browser?.close().finally(()=>process.exit(124)); },300000);
try {
  browser = await chromium.launch({channel:'chrome',headless:false,args:[
    '--window-size=1280,720','--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding','--disable-background-timer-throttling'
  ]});
  const context = await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  page.on('console',m=>note(m.type(),m.text()));
  page.on('pageerror',e=>note('pageerror',e.message));
  const read = async expression => {
    const {result,exceptionDetails} = await cdp.send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true,userGesture:false});
    if(exceptionDetails) throw new Error(JSON.stringify(exceptionDetails));
    return result.value;
  };
  const until = async (predicate,description,timeout=30000) => {
    const end = Date.now()+timeout;
    while(Date.now()<end) { const value = await predicate(); if(value) return value; await delay(100); }
    throw new Error('Timeout: '+description);
  };
  const state = () => read('window.__429_state || null');
  async function snapshot(name,cursor,expected={}) {
    const frames = await read('new Promise(resolve=>{let n=0;const end=performance.now()+1000;function next(){n++;if(performance.now()<end)requestAnimationFrame(next);else resolve(n)}requestAnimationFrame(next)})');
    const dom = await read('({visible:document.visibilityState,aislado:crossOriginIsolated,cursor:!!document.pointerLockElement,ancho:innerWidth,alto:innerHeight,activo:navigator.userActivation.isActive})');
    const game = await state();
    actions.push({snapshot:name,frames,dom,game}); persist();
    requireTrue(frames>=2 && dom.visible==='visible' && dom.aislado, 'Chrome no dibuja/aislamiento incorrecto: '+name);
    requireTrue(dom.ancho===1280 && dom.alto===720, 'Viewport incorrecto');
    if(typeof cursor==='boolean') requireTrue(dom.cursor===cursor,'Pointer Lock incorrecto: '+name);
    if(game) {
      requireTrue(game.fallos.length===0 && game.suelo && game.capsula_libre && !game.vidrio && game.capa_generica===0, 'Premisa física inválida: '+name+' '+JSON.stringify(game));
      for(const [key,value] of Object.entries(expected)) requireTrue(game[key]===value, `${name}: ${key}=${game[key]}, esperado ${value}`);
      const numbers = value => value.match(/[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?/g).map(Number);
      const current = numbers(game.camara_actual), drawn = numbers(game.camara_dibujada);
      requireTrue(current.length===12 && drawn.length===12 && Math.max(...current.map((v,i)=>Math.abs(v-drawn[i])))<.001,'La cámara dibujada difiere de la efectiva');
    }
    await page.screenshot({path:resolve(out,name+'.png')});
    console.log('CAPTURA_WEB_429 '+name+' '+JSON.stringify(dom));
    return game;
  }
  async function click(button='left') {
    actions.push({entrada:'mouse',button,x:640,y:360,time:Date.now()}); persist();
    await page.mouse.click(640,360,{button});
    await delay(250);
  }
  async function key(key) {
    actions.push({entrada:'teclado',key,time:Date.now()}); persist();
    await page.keyboard.press(key); await delay(250);
  }

  // Recorrido 1: HTML/PCK/main de producción originales, sin --script ni checkpoint.
  actions.push({recorrido:'main-original',url,args:[]}); persist();
  await page.goto(url,{waitUntil:'load',timeout:180000});
  await until(()=>read('!document.getElementById("status")'),'shell lista',180000);
  await until(()=>records.some(r=>r.text.includes('[carga] menú visible')),'main muestra menú');
  await snapshot('00-main-menu',false);
  actions.push({entrada:'mouse',button:'left',x:640,y:407,objetivo:'Nuevo juego: coordenada observada en PNG00'}); persist();
  await page.mouse.click(640,407); await delay(800);
  await snapshot('01-main-instrucciones',false);
  for(let step=0;step<16;step++) {
    if(records.some(r=>r.text.includes('[carga] almacén en pantalla'))) break;
    actions.push({entrada:'mouse',button:'left',x:1107,y:591,objetivo:'Siguiente/OK',paso:step}); persist();
    await page.mouse.click(1107,591); await delay(600);
  }
  await until(()=>records.some(r=>r.text.includes('[carga] almacén en pantalla')),'main abre almacén');
  await snapshot('02-main-almacen');

  // Recorrido 2: mismo export; sólo shell de esta URL agrega fixture externo.
  const fixture = readFileSync(fixturePath);
  const fixtureScene = readFileSync(resolve(fixturePath, '..', 'fixture429.tscn'));
  const fixtureOverride = readFileSync(resolve(fixturePath, '..', 'override.cfg'));
  await page.route('**/index.html*', async route => {
    const response = await route.fetch();
    const original = await response.text();
    requireTrue(/engine\.startGame\(\s*\{/.test(original),'Shell sin startGame objeto');
    const html = original.replace(/engine\.startGame\(\s*\{/,
      `engine.preloadFile(new Uint8Array(${JSON.stringify([...fixture])}), '/fixture429.gd');\nengine.preloadFile(new Uint8Array(${JSON.stringify([...fixtureScene])}), '/fixture429.tscn');\nengine.preloadFile(new Uint8Array(${JSON.stringify([...fixtureOverride])}), '/override.cfg');\nengine.startGame({args:[],`);
    actions.push({recorrido:'fixture-externo',montaje:'override.cfg: application/run/main_scene',fixture_sha256:sha(fixture),scene_sha256:sha(fixtureScene),override_sha256:sha(fixtureOverride),args:[],html_original_sha256:sha(original),html_servido_sha256:sha(html)}); persist();
    await route.fulfill({response,body:html});
  });
  await page.goto(url+'?fixture429=1',{waitUntil:'load',timeout:180000});
  await until(async()=>{const s=await state();return s?.etapa==='hueco' && s;},'fixture en suelo');
  let commandId=0;
  const prepare = async command => {
    const id = ++commandId;
    actions.push({preparacion:{id,...command},userGesture:false}); persist();
    await read('window.__429_command = '+JSON.stringify({id,...command}));
    return until(async()=>{const s=await state();return s?.id===id && s;},'fixture '+command.accion);
  };
  await snapshot('03-hueco',false,{panel:false,contorno:false});
  await click();
  await snapshot('04-hueco-cursor',true,{panel:false,suspendido:false});
  await prepare({accion:'llegar'});
  await until(async()=>{const s=await state();return s?.foco.endsWith('/Comprador/Objetivo');},'foco Tin');
  await snapshot('05-frame-0',true,{frame:0,contorno:true,frame_del_contorno:true});
  await prepare({accion:'cuadro',cuadro:3});
  await snapshot('06-frame-3',true,{frame:3,contorno:true,frame_del_contorno:true});
  await prepare({accion:'cuadro',cuadro:0});
  for(const [side,name] of [[-1,'07-lateral-izquierdo'],[1,'08-lateral-derecho']]) {
    await prepare({accion:'lateral',lado:side});
    await snapshot(name,true,{contorno:true,frame_del_contorno:true});
  }
  await prepare({accion:'centro'});
  await prepare({accion:'oculto'});
  await snapshot('09-antepecho',true,{contorno:false});
  await prepare({accion:'centro'});
  await prepare({accion:'caja'});
  const before = await snapshot('10-antes-primer-clic',true,{panel:false,indice:-1,compras:0,soltados:0});
  requireTrue(before.mano!=='0' && before.pedido!=='0','No se preparó la caja/pedido real');
  await click();
  const initial = await snapshot('11-primera-entrada',false,{panel:true,suspendido:true,indice:0,contorno:false});
  requireTrue(initial.mano===before.mano && initial.pedido===before.pedido && initial.entrada.length>0, 'Primer clic saltó o alteró identidad');
  await click('right');
  await snapshot('12-derecho-no-cierra',false,{indice:0,panel:true,mano:before.mano});
  await key('Escape');
  await snapshot('13-pausa',false,{pausa:true,indice:0,mano:before.mano});
  await key('Escape');
  await snapshot('14-resume',false,{pausa:false,indice:0,mano:before.mano});
  for(const index of [1,2]) { await click(); await snapshot('15-entrada-'+index,false,{indice:index,panel:true,mano:before.mano}); }
  await click();
  await snapshot('16-ultimo-clic-retorna',true,{panel:false,suspendido:false,terminado:true,mano:before.mano,pedido:before.pedido,compras:0,soltados:0,finales:1});
  // Repetición confirma una conversación posterior y retorno sin nuevo clic de captura.
  await prepare({accion:'centro'});
  await click();
  await snapshot('17-objeto-no-pedido',false,{panel:true,indice:0,mano:before.mano,compras:0,soltados:0});
  await click();
  await snapshot('18-retorno-rechazo',true,{panel:false,suspendido:false,mano:before.mano,finales:2});
  await prepare({accion:'fin'});
  const errors = records.filter(r=>r.type==='error'||r.type==='pageerror'||/SCRIPT ERROR|Parse Error|(^|\s)ERROR:/.test(r.text));
  requireTrue(errors.length===0,'Consola con errores: '+JSON.stringify(errors));
  writeFileSync(resolve(out,'resultado.json'),JSON.stringify({exit_code:0,errors,scope:'Main original: arranque. Fixture externo: pose/reloj/frames y observación; callbacks y Pointer Lock conservados; todas las entradas de juego suministradas por Chrome.'},null,2));
  console.log('RECORRIDO_WEB_429_OK');
} catch(error) {
  note('runner-error',error.stack||String(error));
  writeFileSync(resolve(out,'resultado.json'),JSON.stringify({exit_code:1,error:String(error)},null,2));
  process.exitCode=1;
} finally {
  clearTimeout(timer); persist();
  await browser?.close();
}

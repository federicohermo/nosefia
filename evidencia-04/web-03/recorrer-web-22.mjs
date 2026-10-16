import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
const [url,out,fixturePath]=process.argv.slice(2);
const require=createRequire('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/runner22.cjs');
const {chromium}=require('playwright');
const sha=x=>createHash('sha256').update(x).digest('hex');
mkdirSync(out,{recursive:true});
const logs=[],actions=[];
const persist=()=>{writeFileSync(resolve(out,'consola.json'),JSON.stringify(logs,null,2));writeFileSync(resolve(out,'recorrido.json'),JSON.stringify(actions,null,2));};
const demand=(v,m)=>{if(!v)throw new Error(m);};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
let browser;
const timer=setTimeout(()=>{void browser?.close().finally(()=>process.exit(124));},420000);
try{
 browser=await chromium.launch({channel:'chrome',headless:false,args:['--disable-backgrounding-occluded-windows','--disable-renderer-backgrounding','--disable-background-timer-throttling']});
 for(const [width,height] of [[1280,720],[1920,1080]]){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:1});
  const page=await context.newPage(); const cdp=await context.newCDPSession(page);
  page.on('console',m=>{logs.push({width,type:m.type(),text:m.text()});persist();});
  page.on('pageerror',e=>{logs.push({width,type:'pageerror',text:e.message});persist();});
  const read=async expression=>{const {result,exceptionDetails}=await cdp.send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true,userGesture:false});if(exceptionDetails)throw new Error(JSON.stringify(exceptionDetails));return result.value;};
  const until=async(fn,label,timeout=45000)=>{const end=Date.now()+timeout;while(Date.now()<end){const s=await fn();if(s)return s;await delay(100);}throw new Error('Timeout: '+label);};
  const state=()=>read('window.__22_state || null');
  async function shot(name,cursor,expected={}){
   const frames=await read('new Promise(r=>{let n=0;let end=performance.now()+500;function f(){n++;if(performance.now()<end)requestAnimationFrame(f);else r(n)}requestAnimationFrame(f)})');
   const dom=await read('({visible:document.visibilityState,aislado:crossOriginIsolated,cursor:!!document.pointerLockElement,ancho:innerWidth,alto:innerHeight})');
   const game=await state();actions.push({snapshot:`web-${width}-${name}`,frames,dom,game});persist();
   demand(frames>=2&&dom.visible==='visible'&&dom.aislado,'Chrome inactivo: '+name);
   demand(dom.ancho===width&&dom.alto===height,'Viewport: '+name);
   if(typeof cursor==='boolean')demand(dom.cursor===cursor,'Pointer Lock: '+name);
   if(game){demand(game.fallos.length===0,'Fixture: '+JSON.stringify(game.fallos));for(const [k,v]of Object.entries(expected))demand(JSON.stringify(game[k])===JSON.stringify(v),name+': '+k+'='+JSON.stringify(game[k]));}
   await page.screenshot({path:resolve(out,`web-${width}-${name}.png`)});return game;
  }
  const click=async point=>{actions.push({width,entrada:'mouse',punto:point});persist();await page.mouse.click(point[0],point[1]);await delay(350);};
  const key=async key=>{actions.push({width,entrada:'teclado',key});persist();await page.keyboard.press(key);await delay(400);};
  const wheel=async delta=>{await page.mouse.move(width/2,height/2);actions.push({width,entrada:'rueda',delta});persist();await page.mouse.wheel(0,delta);await delay(300);};
  if(width===1280){
   await page.goto(url,{waitUntil:'load',timeout:180000});
   await until(()=>logs.some(l=>l.text.includes('[carga] menú visible')),'menú main original',180000);
   await shot('main-menu-original',false);
  }
  const fixture=readFileSync(fixturePath),scene=readFileSync(resolve(fixturePath,'..','fixture22.tscn')),override=readFileSync(resolve(fixturePath,'..','override.cfg'));
  await page.route('**/index.html*',async route=>{
   const response=await route.fetch();const original=await response.text();demand(/engine\.startGame\(\s*\{/.test(original),'Shell sin startGame objeto');
   const html=original.replace(/engine\.startGame\(\s*\{/,
    `engine.preloadFile(new Uint8Array(${JSON.stringify([...fixture])}), '/fixture22.gd');\nengine.preloadFile(new Uint8Array(${JSON.stringify([...scene])}), '/fixture22.tscn');\nengine.preloadFile(new Uint8Array(${JSON.stringify([...override])}), '/override.cfg');\nengine.startGame({args:[],`);
   actions.push({width,montaje:'override.cfg externo, mismo PCK',html_original_sha256:sha(original),html_servido_sha256:sha(html),fixture_sha256:sha(fixture),scene_sha256:sha(scene),override_sha256:sha(override),args:[]});persist();await route.fulfill({response,body:html});
  });
  await page.goto(url+'?fixture22='+width,{waitUntil:'load',timeout:180000});
  await until(async()=>{const s=await state();return s?.etapa==='colilla'&&s;},'fixture físico J2',180000);
  await shot('colilla-suelo',false,{pistas:[],notas:0,colilla_en_mano:false});
  await key('e');await until(async()=>{const s=await state();return s?.pensamientos.length===1;},'E examina');
  await shot('colilla-examinada-sin-pista',true,{pistas:[],notas:0,colilla_en_mano:false});
  await click([width/2,height/2]);await until(async()=>{const s=await state();return s?.colilla_en_mano&&s.pistas.length===1;},'agarre aceptado');
  await shot('colilla-levantada-2B',true,{pistas:['2B'],notas:2,nuevas:['2B']});
  await key('q');let s=await until(async()=>{const s=await state();return s?.abierto&&s.pantalla===0&&s.menu.length===2&&s;},'menú J2 real');
  demand(!s.menu.some(x=>x.quien===4),'Notas apareció J2');await shot('menu-j2-sin-notas',false);
  await click(s.menu.find(x=>x.quien===3).punto);await until(async()=>{const s=await state();return s?.chat===3&&s.puntos.tramo&&s;},'Yasmín frase');
  await wheel(-2000);s=await state();
  for(let n=0;n<16&&(s.puntos.tramo[1]<s.puntos.min_y+6||s.puntos.tramo[1]>s.puntos.max_y-6);n++){
   await wheel(s.puntos.tramo[1]<s.puntos.min_y+6?-150:150);s=await state();
  }
  demand(s.puntos.tramo[1]>=s.puntos.min_y+6&&s.puntos.tramo[1]<=s.puntos.max_y-6,'Tramo fuera del scroll visible');
  await click(s.puntos.prefijo);await shot('yasmin-prefijo-sin-pista',false,{pistas:['2B']});
  s=await state();await click(s.puntos.tramo);await click(s.puntos.tramo);
  await until(async()=>{const s=await state();return s?.notas===4;},'dos pares Notas');
  await shot('yasmin-tramo-2A-idempotente',false,{pistas:['2B','2A'],notas:4,nuevas:['2B','2A']});
  await key('q');await until(async()=>!(await state())?.abierto,'celular baja');
  let command=0;
  const prepare=async accion=>{const id=++command;actions.push({width,preparacion:{id,accion},userGesture:false});persist();await read('window.__22_command='+JSON.stringify({id,accion}));return until(async()=>{const s=await state();return s?.id===id&&s;},accion);};
  await prepare('cerrar');await prepare('fijar_notas');await wheel(-2400);
  await shot('notas-j2-hoy',false,{fijo:true,chat:4,rotulos:['HOY'],jornada:3,notas:4});
  for(const index of [0,2]){
   s=await state();for(let n=0;n<12&&!s.fotos.find(f=>f.indice===index)?.visible;n++){const f=s.fotos.find(f=>f.indice===index);await wheel(f&&f.punto[1]<height/2?-250:250);s=await state();}
   const f=s.fotos.find(f=>f.indice===index);demand(f?.visible,'Foto fuera de scroll '+index);const scroll=s.scroll;
   await shot('notas-par-'+index,false);await click(f.punto);s=await shot('notas-foto-'+index,false,{pantalla:2});
   demand(index===0?s.adjunto.includes('colilla'):s.adjunto.includes('Yasmín'),'Adjunto de otra pista');
   await click(s.cerrar_foto);await shot('notas-scroll-conservado-'+index,false,{pantalla:1,scroll});
  }
  await key('q');await shot('notas-fijas-q-bloqueada',false,{abierto:true,fijo:true,notas:4});
  await prepare('abrir3');await key('q');s=await until(async()=>{const s=await state();return s?.pantalla===0&&s.menu.length===3&&s;},'menú J3');
  await shot('menu-j3-con-notas',false,{jornada:3,notas:4});await click(s.menu.find(x=>x.quien===4).punto);await wheel(-2400);
  await shot('notas-j3-ayer',false,{fijo:false,chat:4,rotulos:['AYER'],pistas:['2B','2A'],notas:4});
  await prepare('fin');await context.close();
 }
 const errors=logs.filter(l=>l.type==='error'||l.type==='pageerror'||/SCRIPT ERROR|Parse Error|(^|\s)ERROR:/.test(l.text));demand(!errors.length,'Consola con errores '+JSON.stringify(errors));
 writeFileSync(resolve(out,'resultado.json'),JSON.stringify({exit_code:0,errors,scope:'Main original y fixture externo explícito de Partida J2: pose/reloj/apertura/fijación, sin registrar pistas por código. E, agarre, frase lila, scroll, fotos y menú mediante entradas reales Chrome. PCK idéntico, sin persistencia436.'},null,2));
}catch(e){logs.push({type:'runner-error',text:e.stack||String(e)});writeFileSync(resolve(out,'resultado.json'),JSON.stringify({exit_code:1,error:String(e)},null,2));process.exitCode=1;}
finally{clearTimeout(timer);persist();await browser?.close();}

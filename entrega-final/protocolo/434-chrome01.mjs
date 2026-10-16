import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
const [main,base,out,checkpoint]=process.argv.slice(2);
const {chromium}=createRequire(resolve(main,'runner434.cjs'))('playwright');
mkdirSync(out,{recursive:true});
const browser=await chromium.launch({channel:'chrome',headless:false,args:['--window-size=1920,1080','--disable-backgrounding-occluded-windows','--disable-renderer-backgrounding','--disable-background-timer-throttling']});
const logs=[],actions=[];
function save(){writeFileSync(resolve(out,'consola.json'),JSON.stringify(logs,null,2));writeFileSync(resolve(out,'acciones.json'),JSON.stringify(actions,null,2));}
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function until(test,ms,label){const end=Date.now()+ms;while(!test()){if(Date.now()>end)throw Error('Timeout '+label);await delay(100);}}
async function setup(kind){
 const context=await browser.newContext({viewport:{width:1920,height:1080},deviceScaleFactor:1,recordVideo:{dir:resolve(out,'video-'+kind),size:{width:1920,height:1080}}});
 const page=await context.newPage();
 page.on('console',m=>{logs.push({paquete:kind,type:m.type(),text:m.text(),time:Date.now()});save();});
 page.on('pageerror',e=>{logs.push({paquete:kind,type:'pageerror',text:e.message,time:Date.now()});save();});
 const cdp=await context.newCDPSession(page);
 async function read(expression){const {result,exceptionDetails}=await cdp.send('Runtime.evaluate',{expression,userGesture:false,returnByValue:true,awaitPromise:true});if(exceptionDetails)throw Error(JSON.stringify(exceptionDetails));return result.value;}
 async function snap(name){
  const frames=await read('new Promise(resolve=>{let n=0;const end=performance.now()+1000;function tick(){n++;if(performance.now()<end)requestAnimationFrame(tick);else resolve(n)}requestAnimationFrame(tick)})');
  const state=await read('({visible:document.visibilityState,width:innerWidth,height:innerHeight,isolated:crossOriginIsolated,pointer:!!document.pointerLockElement})');
  if(frames<2||state.visible!=='visible'||!state.isolated)throw Error('Sin dibujo activo');
  await page.screenshot({path:resolve(out,name+'.png')});actions.push({paquete:kind,snapshot:name,frames,state});save();console.log('434_CHROME_PNG '+name);
 }
 return {context,page,snap};
}
let failure=null;
try{
 const real=await setup('real');
 const bytes=readFileSync(checkpoint);
 const config=readFileSync(resolve(main,'project.godot'),'utf8');
 const name=JSON.parse(config.match(/^config\/name=(".*")$/m)[1]);
 if(/^config\/use_custom_user_dir=true$/m.test(config))throw Error('Revisar userdir');
 const userpath='/userfs/godot/app_userdata/'+name+'/partida.guardado';
 await real.page.route('**/index.html',async route=>{const response=await route.fetch();const html=await response.text();if(!html.includes('engine.startGame('))throw Error('Shell distinto');await route.fulfill({response,body:html.replace('engine.startGame(',`engine.preloadFile(new Uint8Array(${JSON.stringify([...bytes])}),${JSON.stringify(userpath)});\nengine.startGame(`)});});
 actions.push({fixture:'Checkpoint J2 de Partida real; preload HTML, PCK/main/config intactos',sha256:createHash('sha256').update(bytes).digest('hex'),userpath});save();
 await real.page.goto(base+'/export-real/index.html',{waitUntil:'load',timeout:120000});
 await real.page.waitForFunction(()=>!document.getElementById('status'),null,{timeout:120000});
 await real.snap('real-1920-menu');
 await real.page.mouse.click(960,537);
 actions.push({paquete:'real',click:[960,537],wait_ms:60000});save();
 await delay(60000);
 await real.snap('real-1920-j2-entrada');
 await real.page.mouse.click(960,540);
 for(const [key,ms] of [['w',3650],['a',900]]){await real.page.keyboard.down(key);try{await delay(ms);}finally{await real.page.keyboard.up(key);}actions.push({paquete:'real',hold:key,ms});save();}
 await real.snap('real-1920-j2-pasillo');
 await real.page.setViewportSize({width:1280,height:720});await delay(1000);await real.snap('real-1280-j2-pasillo');
 await real.context.close();
 const visual=await setup('camara-diagnostica');
 await visual.page.goto(base+'/export-capturas02/index.html',{waitUntil:'load',timeout:120000});
 await visual.page.waitForFunction(()=>!document.getElementById('status'),null,{timeout:120000});
 function views(){return logs.filter(x=>x.paquete==='camara-diagnostica'&&x.text.startsWith('434_VISTA:')).map(x=>JSON.parse(x.text.slice('434_VISTA:'.length)));}
 await until(()=>views().some(x=>x.indice===0),120000,'primer sector');
 for(const [w,h] of [[1920,1080],[1280,720]]){
  if(w===1280){await visual.page.setViewportSize({width:w,height:h});let count=views().length;await visual.page.keyboard.press('ArrowLeft');await until(()=>views().slice(count).some(x=>x.indice===0),15000,'reset sector');}
  for(let i=0;i<11;i++){
   const view=views().at(-1);if(view.indice!==i||view.jornada!==2||view.cupo_duronga<=0)throw Error('Vista inválida '+JSON.stringify(view));
   actions.push({paquete:'camara-diagnostica',resolucion:[w,h],vista:view});save();
   await visual.snap(`mapa-${w}-${view.nombre}`);
   let count=views().length;
   await visual.page.keyboard.press('ArrowRight');
   if(i<10)await until(()=>views().slice(count).some(x=>x.indice===i+1),15000,'sector '+(i+1));
   else await until(()=>logs.some(x=>x.paquete==='camara-diagnostica'&&x.text==='434_MAPA_COMPLETO_OK'),15000,'marcador final');
  }
 }
 const data=logs.find(x=>x.paquete==='camara-diagnostica'&&x.text.startsWith('434_DATOS_MAPA:'));
 if(!data)throw Error('Sin datos mapa');
 const products=JSON.parse(data.text.slice('434_DATOS_MAPA:'.length));
 if(products.length!==32||products.some(x=>x.principal<=0||x.frente_principal<=0))throw Error('Datos incompletos');
 writeFileSync(resolve(out,'productos.json'),JSON.stringify(products,null,2));
 await visual.context.close();
}catch(error){failure=String(error);console.error(failure);}
finally{save();await browser.close();}
const errors=logs.filter(x=>x.type==='error'||x.type==='pageerror'||/SCRIPT ERROR|Parse Error|(^|\s)ERROR:/.test(x.text));
writeFileSync(resolve(out,'resultado.json'),JSON.stringify({failure,errores:errors,capturas:actions.filter(x=>x.snapshot).length,limite:'4 vistas de paquete real con teclado; 22 vistas de otro PCK con cámara diagnóstica. No prueba paseo a pie por todos los sectores.'},null,2));
console.log('434_CHROME01_FINAL errors='+errors.length+' failure='+failure);
process.exit(failure||errors.length?1:0);

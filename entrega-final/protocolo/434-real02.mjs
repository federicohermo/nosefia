import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
const [main,url,out,checkpoint]=process.argv.slice(2);
const {chromium}=createRequire(resolve(main,'runner434.cjs'))('playwright');
mkdirSync(out,{recursive:true});
const browser=await chromium.launch({channel:'chrome',headless:false,args:['--window-size=1920,1080','--disable-backgrounding-occluded-windows','--disable-renderer-backgrounding','--disable-background-timer-throttling']});
const context=await browser.newContext({viewport:{width:1920,height:1080},deviceScaleFactor:1,recordVideo:{dir:resolve(out,'video'),size:{width:1920,height:1080}}});
const page=await context.newPage();
const logs=[],actions=[];
const save=()=>{writeFileSync(resolve(out,'consola.json'),JSON.stringify(logs,null,2));writeFileSync(resolve(out,'acciones.json'),JSON.stringify(actions,null,2));};
page.on('console',m=>{logs.push({type:m.type(),text:m.text(),time:Date.now()});save();});
page.on('pageerror',e=>{logs.push({type:'pageerror',text:e.message,time:Date.now()});save();});
const cdp=await context.newCDPSession(page);
async function read(expression){const {result,exceptionDetails}=await cdp.send('Runtime.evaluate',{expression,userGesture:false,returnByValue:true,awaitPromise:true});if(exceptionDetails)throw Error(JSON.stringify(exceptionDetails));return result.value;}
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function state(){return read('({visible:document.visibilityState,focus:document.hasFocus(),width:innerWidth,height:innerHeight,pointer:!!document.pointerLockElement,canvas:document.querySelectorAll("canvas").length,active:navigator.userActivation.isActive,isolated:crossOriginIsolated})');}
async function snap(name){const frames=await read('new Promise(resolve=>{let n=0;const end=performance.now()+1000;function tick(){n++;if(performance.now()<end)requestAnimationFrame(tick);else resolve(n)}requestAnimationFrame(tick)})');const current=await state();if(frames<2||current.visible!=='visible'||!current.isolated)throw Error('Sin dibujo');await page.screenshot({path:resolve(out,name+'.png')});actions.push({snapshot:name,frames,state:current});save();console.log(name);}
let failure=null;
try{
 const bytes=readFileSync(checkpoint);
 const config=readFileSync(resolve(main,'project.godot'),'utf8');const name=JSON.parse(config.match(/^config\/name=(".*")$/m)[1]);const path='/userfs/godot/app_userdata/'+name+'/partida.guardado';
 await page.route('**/index.html',async route=>{const response=await route.fetch();const html=await response.text();if(!html.includes('engine.startGame('))throw Error('Shell distinto');await route.fulfill({response,body:html.replace('engine.startGame(',`engine.preloadFile(new Uint8Array(${JSON.stringify([...bytes])}),${JSON.stringify(path)});\nengine.startGame(`)});});
 await page.goto(url,{waitUntil:'load',timeout:120000});await page.waitForFunction(()=>!document.getElementById('status'),null,{timeout:120000});
 await page.bringToFront();await cdp.send('Page.bringToFront');await page.mouse.move(960,537);await snap('real02-1920-menu');
 await page.mouse.down();await page.mouse.up();await wait(60000);await snap('real02-1920-j2-entrada');
 await page.bringToFront();await cdp.send('Page.bringToFront');
 // No mouseMoved al comenzar: la posición ya se fijó mientras el menú tenía el control.
 await page.mouse.down();await page.mouse.up();await wait(1000);
 actions.push({antes_de_caminar:await state()});save();
 if(!(await state()).pointer)throw Error('Chrome no capturó el mouse; no se camina sin esa premisa');
 for(const [key,ms] of [['w',1000],['w',1000],['w',1000],['w',650],['a',900]]){await page.keyboard.down(key);try{await wait(ms);}finally{await page.keyboard.up(key);}actions.push({hold:key,ms});save();}
 await snap('real02-1920-j2-pasillo');
 await page.setViewportSize({width:1280,height:720});await wait(1000);await snap('real02-1280-j2-pasillo');
 await page.keyboard.press('Escape');await wait(1000);
 actions.push({antes_de_cerrar:await state()});save();
}catch(error){failure=String(error);console.error(failure);}
finally{save();await browser.close();}
const errors=logs.filter(x=>x.type==='error'||x.type==='pageerror'||/SCRIPT ERROR|Parse Error|(^|\s)ERROR:/.test(x.text));
writeFileSync(resolve(out,'resultado.json'),JSON.stringify({failure,errors,capturas:actions.filter(x=>x.snapshot).length},null,2));
console.log('434_REAL02_FINAL '+JSON.stringify({failure,errors:errors.length}));process.exit(failure||errors.length?1:0);

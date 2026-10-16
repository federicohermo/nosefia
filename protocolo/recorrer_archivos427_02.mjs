// Bajo turno.py; comandos JSON por stdin. El paquete y main quedan originales.
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

const [wt,url,out,checkpoint] = process.argv.slice(2);
const require = createRequire(resolve(wt,'runner427.cjs'));
const {chromium} = require('playwright');
mkdirSync(out,{recursive:true});
const registros=[];
const acciones=[];
const navegador=await chromium.launch({channel:'chrome',headless:false,args:[
  '--window-size=1920,1080','--disable-backgrounding-occluded-windows',
  '--disable-renderer-backgrounding','--disable-background-timer-throttling',
]});
process.on('uncaughtException', async error=>{console.error(String(error)); await navegador.close().catch(()=>{}); process.exit(1);});
const context=await navegador.newContext({viewport:{width:1920,height:1080},deviceScaleFactor:1,recordVideo:{dir:resolve(out,'video'),size:{width:1920,height:1080}}});
const pagina=await context.newPage();
const cdp=await context.newCDPSession(pagina);
async function leer(expression) {
  const {result,exceptionDetails}=await cdp.send('Runtime.evaluate',{
    expression,awaitPromise:true,returnByValue:true,userGesture:false,
  });
  if(exceptionDetails) throw new Error(JSON.stringify(exceptionDetails));
  return result.value;
}
pagina.on('console',m=>registros.push({type:m.type(),text:m.text(),time:Date.now()}));
pagina.on('pageerror',e=>registros.push({type:'pageerror',text:e.message,time:Date.now()}));
let fase='ruta';
let rutaUsuario=null;
const bytes=readFileSync(checkpoint);
const sha=createHash('sha256').update(bytes).digest('hex');
const sondaRuta='extends SceneTree\nfunc _initialize() -> void:\n\tprint("DIAGNOSTICO427_USERDIR ", OS.get_user_data_dir())\n\tquit(0)\n';
await pagina.route('**/index.html',async route=>{
  const r=await route.fetch();
  const html=await r.text();
  const llamada='engine.startGame({';
  if(!html.includes(llamada)) throw new Error('Shell cambio de forma');
  let inyeccion;
  if(fase==='ruta') {
    inyeccion=`engine.preloadFile(new Uint8Array(${JSON.stringify([...Buffer.from(sondaRuta)])}), '/diagnostico427_ruta.gd');\nengine.startGame({args:['--script','/diagnostico427_ruta.gd'],`;
  } else {
    inyeccion=`engine.preloadFile(new Uint8Array(${JSON.stringify([...bytes])}), ${JSON.stringify(rutaUsuario+'/partida.guardado')});\nengine.startGame({`;
  }
  await route.fulfill({response:r,body:html.replace(llamada,inyeccion)});
});
await pagina.goto(url,{waitUntil:'load',timeout:120000});
const limiteRuta=Date.now()+120000;
while(!registros.some(x=>x.text.startsWith('DIAGNOSTICO427_USERDIR '))) {
  if(Date.now()>limiteRuta) throw new Error('Timeout de sonda userdir');
  await new Promise(r=>setTimeout(r,100));
}
rutaUsuario=registros.find(x=>x.text.startsWith('DIAGNOSTICO427_USERDIR ')).text.slice('DIAGNOSTICO427_USERDIR '.length).trim();
if(!rutaUsuario.startsWith('/userfs/')) throw new Error('Ruta inesperada '+rutaUsuario);
acciones.push({fixture:'checkpoint de Partida real',sha256:sha,path:rutaUsuario+'/partida.guardado',ruta_medida_en_paquete:true});
console.log('RUTA427_MEDIDA '+rutaUsuario);
fase='juego';
await pagina.goto(url,{waitUntil:'load',timeout:120000});
await pagina.waitForFunction(()=>!document.getElementById('status'),null,{timeout:120000});
async function snapshot(nombre, movimiento=false) {
  const cuadros=await leer(`new Promise(resolve=>{let n=0;const fin=performance.now()+${movimiento?30:1000};function paso(){n++;if(performance.now()<fin)requestAnimationFrame(paso);else resolve(n)}requestAnimationFrame(paso)})`);
  const estado=await leer(`({visible:document.visibilityState,ancho:innerWidth,alto:innerHeight,aislado:crossOriginIsolated,cursor:!!document.pointerLockElement,activo:navigator.userActivation.isActive})`);
  if(cuadros<2 || estado.visible!=='visible') throw new Error('Chrome no dibuja');
  await pagina.screenshot({path:resolve(out,`${nombre}.png`)});
  acciones.push({snapshot:nombre,cuadros,estado});
  writeFileSync(resolve(out,'consola.json'),JSON.stringify(registros,null,2));
  writeFileSync(resolve(out,'recorrido.json'),JSON.stringify(acciones,null,2));
  console.log('CAPTURA427 '+nombre+' '+JSON.stringify(estado));
}
await snapshot('web-1920-inicio');
console.log('RECORRIDO427_LISTO');
const comandos=resolve(out,'comandos'); mkdirSync(comandos,{recursive:true});
async function* entradaDeArchivos() {
  let n=1;
  while(true) {
    const archivo=resolve(comandos,String(n).padStart(4,'0')+'.json');
    const limite=Date.now()+90000;
    while(!existsSync(archivo)) {
      if(Date.now()>limite) throw new Error('Timeout esperando comando '+n);
      await new Promise(r=>setTimeout(r,100));
    }
    yield readFileSync(archivo,'utf8');
    writeFileSync(resolve(comandos,String(n).padStart(4,'0')+'.ack'),'ok');
    n++;
  }
}
const entrada=entradaDeArchivos();
let fallo=null;
try {
  for await(const linea of entrada) {
    const cmd=JSON.parse(linea);
    acciones.push(cmd);
    if(cmd.click) await pagina.mouse.click(...cmd.click);
    if(cmd.move) await pagina.mouse.move(...cmd.move);
    if(cmd.relative) await cdp.send('Input.dispatchMouseEvent',{type:'mouseMoved',x:960,y:540,movementX:cmd.relative[0],movementY:cmd.relative[1]});
    if(cmd.hold) {
      const inicio=Date.now();
      await pagina.keyboard.down(cmd.hold.key);
      try {
        for(const paso of cmd.hold.pasos) {
          await new Promise(r=>setTimeout(r,paso.ms));
          if(paso.snapshot) await snapshot(paso.snapshot,true);
          acciones.push({durante:cmd.hold.key,transcurrido:Date.now()-inicio});
        }
      } finally {await pagina.keyboard.up(cmd.hold.key);}
    }
    if(cmd.wheel) await pagina.mouse.wheel(...cmd.wheel);
    if(cmd.key) await pagina.keyboard.press(cmd.key);
    if(cmd.size) await pagina.setViewportSize({width:cmd.size[0],height:cmd.size[1]});
    if(cmd.wait) await new Promise(r=>setTimeout(r,cmd.wait));
    if(cmd.snapshot) await snapshot(cmd.snapshot);
    if(cmd.fin) break;
    console.log('RECORRIDO427_PASO');
  }
} catch(error) {
  fallo=String(error); console.error(fallo);
} finally {
  writeFileSync(resolve(out,'consola.json'),JSON.stringify(registros,null,2));
  writeFileSync(resolve(out,'recorrido.json'),JSON.stringify(acciones,null,2));
  await navegador.close();
}
const errores=registros.filter(x=>x.type==='error'||x.type==='pageerror'||/SCRIPT ERROR|Parse Error|(^|\s)ERROR:/.test(x.text));
console.log('RECORRIDO427_FINAL errores='+errores.length);
if(errores.length) console.error(JSON.stringify(errores));
process.exit(errores.length || fallo ? 1 : 0);

// Bajo turno.py; comandos JSON por archivos. El paquete y main quedan originales.
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

const [wt,url,out,checkpoint] = process.argv.slice(2);
const require = createRequire(resolve(wt,'runner431.cjs'));
const {chromium} = require('playwright');
mkdirSync(out,{recursive:true});
const registros=[];
const acciones=[];
let listo=false;
let ultimaAccion=Date.now();
let navegador;
function registrar(type,text) {
  registros.push({type,text,time:Date.now()});
  writeFileSync(resolve(out,'consola.json'),JSON.stringify(registros,null,2));
}
async function vencer(motivo) {
  registrar('runner-error',motivo);
  console.error('RECORRIDO431_TIMEOUT '+motivo);
  const salida=setTimeout(()=>process.exit(1),10000);
  try { if(navegador) await navegador.close(); } finally { clearTimeout(salida); process.exit(1); }
}
setTimeout(()=>void vencer('limite total de 360 segundos'),360000);
setInterval(()=>{if(listo && Date.now()-ultimaAccion>90000) void vencer('90 segundos sin comando');},1000);
navegador=await chromium.launch({channel:'chrome',headless:false,args:[
  '--window-size=1920,1080','--disable-backgrounding-occluded-windows',
  '--disable-renderer-backgrounding','--disable-background-timer-throttling',
]});
const context=await navegador.newContext({viewport:{width:1920,height:1080},deviceScaleFactor:1});
const pagina=await context.newPage();
const cdp=await context.newCDPSession(pagina);
async function leer(expression) {
  const {result,exceptionDetails}=await cdp.send('Runtime.evaluate',{
    expression,awaitPromise:true,returnByValue:true,userGesture:false,
  });
  if(exceptionDetails) throw new Error(JSON.stringify(exceptionDetails));
  return result.value;
}
pagina.on('console',m=>registrar(m.type(),m.text()));
pagina.on('pageerror',e=>registrar('pageerror',e.message));
if(checkpoint) {
  const bytes=readFileSync(checkpoint);
  const sha=createHash('sha256').update(bytes).digest('hex');
  await pagina.route('**/index.html',async route=>{
    const r=await route.fetch();
    const html=await r.text();
    if(!html.includes('engine.startGame(')) throw new Error('Shell cambió de forma');
    const inyeccion=`engine.preloadFile(new Uint8Array(${JSON.stringify([...bytes])}), '/userfs/godot/app_userdata/No se fía/partida.guardado');\nengine.startGame(`;
    await route.fulfill({response:r,body:html.replace('engine.startGame(',inyeccion)});
  });
  acciones.push({fixture:'checkpoint de Partida real',sha256:sha,path:'/userfs/godot/app_userdata/No se fía/partida.guardado'});
}
await pagina.goto(url,{waitUntil:'load',timeout:180000});
await pagina.waitForFunction(()=>!document.getElementById('status'),null,{timeout:180000});
async function snapshot(nombre) {
  const cuadros=await leer(`new Promise(resolve=>{let n=0;const fin=performance.now()+1000;function paso(){n++;if(performance.now()<fin)requestAnimationFrame(paso);else resolve(n)}requestAnimationFrame(paso)})`);
  const estado=await leer(`({visible:document.visibilityState,ancho:innerWidth,alto:innerHeight,aislado:crossOriginIsolated,cursor:!!document.pointerLockElement,activo:navigator.userActivation.isActive})`);
  acciones.push({medicion:nombre,cuadros,estado});
  writeFileSync(resolve(out,'recorrido.json'),JSON.stringify(acciones,null,2));
  if(cuadros<2 || estado.visible!=='visible') throw new Error('Chrome no dibuja '+JSON.stringify({cuadros,estado}));
  await pagina.screenshot({path:resolve(out,`${nombre}.png`)});
  acciones.push({snapshot:nombre,cuadros,estado});
  writeFileSync(resolve(out,'consola.json'),JSON.stringify(registros,null,2));
  writeFileSync(resolve(out,'recorrido.json'),JSON.stringify(acciones,null,2));
  console.log('CAPTURA431 '+nombre+' '+JSON.stringify(estado));
}
await snapshot('web-1920-inicio');
console.log('RECORRIDO431_LISTO');
listo=true; ultimaAccion=Date.now();
const comandos=resolve(out,'comandos'); mkdirSync(comandos,{recursive:true});
async function* entradaDeArchivos() { let n=1; while(true) { const archivo=resolve(comandos, String(n).padStart(4,'0')+'.json'); while(!existsSync(archivo)) await new Promise(r=>setTimeout(r,100)); yield readFileSync(archivo,'utf8'); n++; } }
const entrada=entradaDeArchivos();
try {
  for await(const linea of entrada) {
    const cmd=JSON.parse(linea);
    ultimaAccion=Date.now();
    acciones.push(cmd);
    if(cmd.click) await pagina.mouse.click(...cmd.click);
    if(cmd.move) await pagina.mouse.move(...cmd.move);
    if(cmd.wheel) await pagina.mouse.wheel(...cmd.wheel);
    if(cmd.key) await pagina.keyboard.press(cmd.key);
    if(cmd.size) await pagina.setViewportSize({width:cmd.size[0],height:cmd.size[1]});
    if(cmd.wait) await new Promise(r=>setTimeout(r,cmd.wait));
    if(cmd.snapshot) await snapshot(cmd.snapshot);
    if(cmd.fin) break;
    console.log('RECORRIDO431_PASO');
  }
} finally {
  writeFileSync(resolve(out,'consola.json'),JSON.stringify(registros,null,2));
  writeFileSync(resolve(out,'recorrido.json'),JSON.stringify(acciones,null,2));
  await navegador.close();
}
const errores=registros.filter(x=>x.type==='error'||x.type==='pageerror'||/SCRIPT ERROR|Parse Error|(^|\s)ERROR:/.test(x.text));
console.log('RECORRIDO431_FINAL errores='+errores.length);
if(errores.length) console.error(JSON.stringify(errores));
process.exit(errores.length ? 1 : 0);

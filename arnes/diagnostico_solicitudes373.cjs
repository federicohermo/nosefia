const { chromium } = require('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/node_modules/playwright');
const fs=require('fs');const path=require('path');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:false,args:['--disable-backgrounding-occluded-windows','--disable-renderer-backgrounding']});
 try {
 for(const width of [1920,1280]){
  const context=await browser.newContext({viewport:{width,height:width*9/16}});
  const page=await context.newPage();const errores=[];const fases=[];const inicio=Date.now();
  const destino=path.join(__dirname,`373-solicitudes-${width}.json`);
  page.on('pageerror',e=>errores.push({ms:Date.now()-inicio,error:e.message}));
  await page.addInitScript(()=>{
   const original=Element.prototype.requestPointerLock;
   window.solicitudes373={total:0,activas:0,primeras:[]};
   Element.prototype.requestPointerLock=function(...args){
    const s=window.solicitudes373;const activa=navigator.userActivation.isActive;
    s.total++;if(activa)s.activas++;
    if(s.primeras.length<100)s.primeras.push({ms:performance.now(),activa,ha_interactuado:navigator.userActivation.hasBeenActive,foco:document.hasFocus(),conectado:this.isConnected,cursor:document.pointerLockElement?.id||null});
    return original.apply(this,args);
   };
  });
  const cdp=await context.newCDPSession(page);
  const leer=async(fn,arg)=>{const r=await cdp.send('Runtime.evaluate',{expression:`(${fn.toString()})(${JSON.stringify(arg)??''})`,returnByValue:true,awaitPromise:true,userGesture:false});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
  const esperar=async(fn,tiempo=180000)=>{const fin=Date.now()+tiempo;while(Date.now()<fin){if(await leer(fn))return;await new Promise(r=>setTimeout(r,100));}throw Error('Timeout '+fn.toString());};
  const medir=async fase=>{fases.push(await leer(fase=>({fase,ms:performance.now(),solicitudes:window.solicitudes373,cursor:document.pointerLockElement?.id||null,estado:window.nosefia373_estado}),fase));fs.writeFileSync(destino,JSON.stringify({fases,errores},null,2));};
  try {
   await page.goto('http://127.0.0.1:8373',{timeout:120000});
   await esperar(()=>window.nosefia373_estado?.botones?.some(b=>b.texto==='NUEVO JUEGO'));
   await page.bringToFront();await page.locator('canvas').focus();await medir('menu');
   const b=await leer(()=>window.nosefia373_estado.botones.find(b=>b.texto==='NUEVO JUEGO'));
   await page.mouse.click(b.x,b.y);await medir('clic_nuevo');
   await esperar(()=>window.nosefia373_estado?.alma);await medir('almacen_listo');
   await page.waitForTimeout(3000);await medir('entrada_terminada');
   await page.mouse.click(10,width*9/32);await esperar(()=>document.pointerLockElement===document.querySelector('canvas'),15000);await medir('clic_canvas_captura');
   await page.keyboard.press('KeyQ');await esperar(()=>document.pointerLockElement===null,15000);await medir('q_suelta');
   await page.keyboard.press('KeyQ');await esperar(()=>document.pointerLockElement===document.querySelector('canvas'),15000);await medir('q_recaptura');
  } finally {await medir('fin');await context.close();}
 }
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

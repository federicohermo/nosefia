const { chromium } = require('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/node_modules/playwright');
const fs = require('fs');
const path = require('path');
const scratch = __dirname;
const destino = path.join(scratch, 'capturas374');
const textos = JSON.parse(fs.readFileSync(path.join(scratch, 'textos374.json'), 'utf8'));
fs.mkdirSync(destino, {recursive:true});

(async () => {
  const navegador = await chromium.launch({channel:'chrome', headless:false, args:[
    '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding'
  ]});
  const mediciones = {};
  try {
    for (const [width,height] of [[1920,1080],[1280,720]]) {
      const context = await navegador.newContext({viewport:{width,height}, deviceScaleFactor:1});
      const page = await context.newPage();
      const consola=[], errores=[], estados=[];
      const inicio=Date.now();
      page.on('console', m=>{consola.push((Date.now()-inicio)+'ms '+m.type()+': '+m.text());if(m.type()==='error'||/SCRIPT ERROR:|^ERROR:/.test(m.text()))errores.push(m.text());});
      page.on('pageerror', e=>{consola.push((Date.now()-inicio)+'ms pageerror: '+e.message);errores.push(e.message);});
      try {
        await page.goto('http://127.0.0.1:8374', {waitUntil:'load',timeout:120000});
        const cdp=await context.newCDPSession(page);
        const leer=async(fn,arg)=>{
          const r=await cdp.send('Runtime.evaluate',{expression:`(${fn.toString()})(${JSON.stringify(arg)??''})`,returnByValue:true,awaitPromise:true,userGesture:false});
          if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));
          return r.result.value;
        };
        const esperar=async(fn,tiempo=120000,arg)=>{
          console.log('Espera pasiva374:',fn.toString());
          const fin=Date.now()+tiempo;
          while(Date.now()<fin){if(await leer(fn,arg))return;await new Promise(r=>setTimeout(r,100));}
          throw Error('Timeout pasivo374: '+fn.toString());
        };
        const estado=()=>leer(()=>window.nosefia374_estado);
        const registrar=async fase=>{
          const dato=await leer(fase=>({fase,tiempo:performance.now(),tomado:document.pointerLockElement===document.querySelector('canvas'),hasFocus:document.hasFocus(),estado:window.nosefia374_estado}),fase);
          estados.push(dato);
          fs.writeFileSync(path.join(destino,`web-estados-${width}.json`),JSON.stringify(estados,null,2));
          return dato;
        };
        const clic=async texto=>{
          const b=(await estado()).botones.find(b=>b.texto===texto&&b.habilitado);
          if(!b||b.x<0||b.x>width||b.y<0||b.y>height)throw Error('Botón inaccesible: '+texto+' '+JSON.stringify(b));
          await page.mouse.click(b.x,b.y);
        };
        await esperar(()=>window.nosefia374_estado?.botones?.some(b=>b.texto==='NUEVO JUEGO'));
        if(!await leer(()=>crossOriginIsolated))throw Error('Falta aislamiento del servidor');
        await page.bringToFront();
        await page.locator('canvas').focus();
        await esperar(()=>document.hasFocus()&&document.visibilityState==='visible',10000);
        await clic('NUEVO JUEGO');
        await esperar(()=>window.nosefia374_estado?.instrucciones?.visible,180000);
        await page.waitForTimeout(400);
        let actual=await estado();
        if(actual.instrucciones.pasos.length!==1||actual.placa.visible||actual.botones.some(b=>b.texto==='Volver'))throw Error('Inicio de instrucciones incorrecto');
        const presupuesto=actual.presupuesto;
        await registrar('instrucciones_primero');
        const raf=await leer(()=>new Promise(resolve=>{let n=0;const t=performance.now();function f(){n++;if(performance.now()-t<1000)requestAnimationFrame(f);else resolve(n);}requestAnimationFrame(f);}));
        if(raf<2)throw Error('Chrome no dibuja: '+raf);
        await page.screenshot({path:path.join(destino,`web-instrucciones-primero-${width}.png`)});
        for(let cantidad=2;cantidad<=14;cantidad++){
          await clic('Siguiente');
          await esperar(n=>window.nosefia374_estado.instrucciones.pasos.length===n,120000,cantidad);
          await page.waitForTimeout(180);
          actual=await estado();
          if(actual.presupuesto!==presupuesto)throw Error('La lectura cobró tiempo');
          actual.instrucciones.pasos.forEach((paso,i)=>{
            if(paso.texto!==textos[i]||paso.texto_dibujado!==textos[i].replace(/\[\/?b\]/g,''))throw Error('Texto distinto en paso '+(i+1));
            if(paso.foto&&!paso.foto_antes_del_texto)throw Error('Foto después del texto');
          });
          if(cantidad===4){
            if(!actual.instrucciones.pasos[3].foto.endsWith('intro-04.png'))throw Error('Falta foto real de corcho');
            await page.screenshot({path:path.join(destino,`web-instrucciones-foto-${width}.png`)});
          }
        }
        actual=await estado();
        const fotos=actual.instrucciones.pasos.filter(p=>p.foto).map(p=>p.foto);
        if(fotos.length!==7||new Set(fotos).size!==7)throw Error('Faltan fotos reales: '+JSON.stringify(fotos));
        if(!actual.botones.some(b=>b.texto==='Comenzar'))throw Error('El paso14 no ofrece Comenzar');
        await registrar('instrucciones_ultimo');
        await page.screenshot({path:path.join(destino,`web-instrucciones-ultimo-${width}.png`)});
        await clic('Comenzar');
        await esperar(()=>!window.nosefia374_estado.instrucciones.visible&&window.nosefia374_estado.placa.visible);
        actual=await estado();
        if(actual.placa.texto!=='NOCHE 1'||actual.presupuesto!==presupuesto)throw Error('Comenzar no entra con presupuesto conservado');
        await registrar('placa_noche1');
        await page.screenshot({path:path.join(destino,`web-noche-1-${width}.png`)});
        await esperar(()=>!window.nosefia374_estado.placa.visible);
        await page.waitForTimeout(1600);
        if(await leer(()=>document.pointerLockElement!==null))throw Error('La placa pidió captura sin gesto');
        await page.keyboard.press('KeyQ');
        await esperar(()=>window.nosefia374_estado.abierto&&window.nosefia374_estado.pantalla===0);
        await page.waitForTimeout(350);
        const jefe=(await estado()).botones.find(b=>b.nombre==='Enrique Peldaño');
        if(!jefe)throw Error('Falta contacto Enrique Peldaño');
        await page.mouse.click(jefe.x,jefe.y);
        await esperar(()=>window.nosefia374_estado.pantalla===1);
        await page.waitForTimeout(300);
        await page.screenshot({path:path.join(destino,`web-chat-enrique-${width}.png`)});
        await page.mouse.move(width/2,height/2);
        for(let i=0;i<12&&(await estado()).fotos.length===0;i++){
          await page.mouse.wheel(0,-250);
          await page.waitForTimeout(150);
        }
        actual=await estado();
        if(actual.fotos.length===0)throw Error('No se alcanza ninguna foto del guion con rueda');
        await page.mouse.click(...actual.fotos.at(-1));
        await esperar(()=>window.nosefia374_estado.pantalla===2);
        await page.waitForTimeout(250);
        actual=await estado();
        if(!fotos.includes(actual.foto_ampliada.ruta)||!actual.foto_ampliada.texto)throw Error('La foto ampliada no pertenece al guion o perdió su adjunto');
        await registrar('foto_real_en_celular');
        await page.screenshot({path:path.join(destino,`web-foto-enrique-${width}.png`)});
        await page.mouse.click(10,height/2);
        await esperar(()=>window.nosefia374_estado.pantalla===1);
        await page.keyboard.press('KeyQ');
        await esperar(()=>!window.nosefia374_estado.abierto);
        await esperar(()=>document.pointerLockElement===document.querySelector('canvas'));
        await leer(()=>window.nosefia374_accion='checkpoint');
        await esperar(()=>window.nosefia374_accion==='');
        await page.keyboard.press('Escape');
        await esperar(()=>window.nosefia374_estado.pausa);
        await esperar(()=>document.pointerLockElement===null);
        await clic('VOLVER AL MENÚ');
        await esperar(()=>!window.nosefia374_estado.alma&&window.nosefia374_estado.botones.some(b=>b.texto==='CONTINUAR'&&b.habilitado));
        await clic('CONTINUAR');
        await esperar(()=>window.nosefia374_estado.alma&&window.nosefia374_estado.placa.visible,180000);
        actual=await estado();
        if(actual.jornada!==3||actual.medios!==7||actual.instrucciones.visible||actual.placa.texto!=='NOCHE 3')throw Error('CONTINUAR no conserva checkpoint o muestra intro');
        await registrar('continuar_sin_instrucciones');
        await page.screenshot({path:path.join(destino,`web-continuar-noche-3-${width}.png`)});
        await esperar(()=>!window.nosefia374_estado.placa.visible);
        await page.waitForTimeout(1600);
        if(errores.length)throw Error(errores.join('\n'));
        mediciones[width]={raf,presupuestoAntes:presupuesto,fotos,estados,errores};
      } finally {
        fs.writeFileSync(path.join(destino,`web-consola-${width}.log`),consola.join('\n'));
        fs.writeFileSync(path.join(destino,'web-medidas.json'),JSON.stringify(mediciones,null,2));
        await context.close();
      }
    }
    console.log(JSON.stringify(mediciones,null,2));
  } finally {await navegador.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

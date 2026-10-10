const { chromium } = require('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/node_modules/playwright');
const fs = require('fs');
const path = require('path');
const scratch = __dirname;
const destino = path.join(scratch, 'capturas373');
fs.mkdirSync(destino, {recursive:true});

(async () => {
  const navegador = await chromium.launch({channel:'chrome', headless:false, args:[
    '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding',
    '--window-size=1920,1080', '--disable-gpu-vsync', '--disable-frame-rate-limit'
  ]});
  const mediciones = {};
  try {
    for (const [width,height] of [[1920,1080],[1280,720]]) {
      const context = await navegador.newContext({viewport:{width,height}, deviceScaleFactor:1});
      const page = await context.newPage();
      const consola = [];
      const focos = [];
      const errores = [];
      page.on('console', m => {consola.push(m.type()+': '+m.text()); if(m.type()==='error'||/SCRIPT ERROR:|^ERROR:/.test(m.text())) errores.push(m.text());});
      page.on('pageerror', e => {consola.push('pageerror: '+e.message); errores.push(e.message);});
      try {
      await page.goto('http://127.0.0.1:8373', {waitUntil:'load',timeout:120000});
      await page.waitForFunction(() => window.nosefia373_estado?.botones?.some(b=>b.texto==='NUEVO JUEGO'),null,{timeout:120000});
      if (!(await page.evaluate(()=>crossOriginIsolated))) throw Error('Sin aislamiento');
      const observarFoco = async (fase) => {
        focos.push(await page.evaluate(fase=>({fase,hasFocus:document.hasFocus(),visibility:document.visibilityState,activo:document.activeElement?.tagName,canvasConectado:document.querySelector('canvas')?.isConnected}),fase));
        fs.writeFileSync(path.join(destino,`web-foco-${width}.json`),JSON.stringify(focos,null,2));
      };
      await observarFoco('antes_de_activar');
      await page.bringToFront();
      await page.locator('canvas').focus();
      await observarFoco('antes_de_nuevo_juego');
      await page.waitForFunction(()=>document.hasFocus()&&document.visibilityState==='visible',null,{timeout:10000});
      const boton = await page.evaluate(()=>window.nosefia373_estado.botones.find(b=>b.texto==='NUEVO JUEGO'));
      await page.mouse.click(boton.x,boton.y);
      await page.waitForFunction(()=>window.nosefia373_estado?.alma,null,{timeout:180000});
      await page.waitForTimeout(3000);
      await page.evaluate(()=>window.nosefia373_accion='congelar');
      await page.waitForTimeout(500);
      const raf = await page.evaluate(()=>new Promise(resolve=>{let n=0;const t=performance.now();function f(){n++;if(performance.now()-t<1000)requestAnimationFrame(f);else resolve(n);}requestAnimationFrame(f);}));
      if(raf<2)throw Error(`Chrome no dibuja: ${raf} RAF/s`);
      await page.screenshot({path:path.join(destino,`web-cerrado-${width}.png`)});
      await page.keyboard.press('KeyQ');
      await page.waitForFunction(()=>window.nosefia373_estado.abierto&&window.nosefia373_estado.pantalla===0);
      await page.waitForTimeout(500);
      let estado=await page.evaluate(()=>window.nosefia373_estado);
      const [x,y,w,h]=estado.rect;
      if(Math.abs(w/h-9/16)>0.0001||Math.abs(x+w/2-width/2)>1||Math.abs(y+h/2-height/2)>1)throw Error('Aspecto/centro incorrecto '+estado.rect);
      await page.screenshot({path:path.join(destino,`web-menu-${width}.png`)});
      await page.evaluate(()=>window.nosefia373_accion='sin_velo');
      await page.waitForTimeout(200);
      await page.screenshot({path:path.join(destino,`web-menu-sin-velo-${width}.png`)});
      await page.evaluate(()=>window.nosefia373_accion='con_velo');
      await page.waitForTimeout(200);
      const chat=estado.botones.find(b=>b.nombre);
      if(!chat)throw Error('No hay contactos del guión en el paquete');
      await page.mouse.click(chat.x,chat.y);
      await page.waitForFunction(()=>window.nosefia373_estado.pantalla===1);
      await page.waitForTimeout(200);
      await page.screenshot({path:path.join(destino,`web-chat-${width}.png`)});
      await page.evaluate(()=>window.nosefia373_accion='foto');
      await page.waitForFunction(()=>window.nosefia373_estado.fotos.length>0);
      await page.waitForTimeout(400);
      estado=await page.evaluate(()=>window.nosefia373_estado);
      await page.mouse.click(...estado.fotos.at(-1));
      await page.waitForFunction(()=>window.nosefia373_estado.pantalla===2);
      await page.waitForTimeout(200);
      estado=await page.evaluate(()=>window.nosefia373_estado);
      const adjunto=estado.adjunto;
      if(!adjunto?.cabe_texto||!adjunto.cabe_imagen||adjunto.altura_del_nodo<adjunto.altura_de_contenido-1||adjunto.altura_de_imagen<=0||!adjunto.texto.includes('[b]organices las cajas[/b]')||adjunto.texto_dibujado.includes('[b]'))throw Error('Foto o adjunto largo recortado '+JSON.stringify(adjunto));
      await page.screenshot({path:path.join(destino,`web-foto-${width}.png`)});
      const antes=estado.scroll;
      await page.mouse.click(10,Math.floor(height/2));
      await page.waitForFunction(()=>window.nosefia373_estado.pantalla===1);
      const despues=await page.evaluate(()=>window.nosefia373_estado.scroll);
      if(antes!==despues)throw Error('El clic de foto cambió el scroll');
      mediciones[width]={focos,raf,rect:estado.rect,scrollAntes:antes,scrollDespues:despues,adjunto,errores};
      fs.writeFileSync(path.join(destino,`web-consola-${width}.log`),consola.join('\n'));
      if(errores.length)throw Error(errores.join('\n'));
      } finally {
        fs.writeFileSync(path.join(destino,`web-consola-${width}.log`),consola.join('\n'));
        fs.writeFileSync(path.join(destino,'web-medidas.json'),JSON.stringify(mediciones,null,2));
        await context.close();
      }
    }
    fs.writeFileSync(path.join(destino,'web-medidas.json'),JSON.stringify(mediciones,null,2));
    console.log(JSON.stringify(mediciones,null,2));
  } finally {await navegador.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

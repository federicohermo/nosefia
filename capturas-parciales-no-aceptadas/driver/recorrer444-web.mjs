// El fixture prepara/observa; sólo Chrome suministra los clics del juego.
import {createRequire} from 'node:module';
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';

const [url, output, exportDir, expectedPck, head] = process.argv.slice(2);
if(!url || !output || !exportDir || !/^[a-f0-9]{64}$/.test(expectedPck||'') || !head) throw Error('Uso: node recorrer444-web.mjs URL OUTPUT EXPORT_DIR PCK_SHA256 HEAD');
const own = dirname(fileURLToPath(import.meta.url));
const require = createRequire('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/runner429.cjs');
const {chromium} = require('playwright');
const sha = data => createHash('sha256').update(data).digest('hex');
const pins = () => Object.fromEntries(['index.html','index.js','index.wasm','index.pck'].map(name=>[name,sha(readFileSync(resolve(exportDir,name)))]));
const original = pins();
if(original['index.pck']!==expectedPck) throw Error('PCK distinto del pin autorizado');
mkdirSync(output,{recursive:false});
const records=[], actions=[];
const persist = () => {
  writeFileSync(resolve(output,'consola.json'),JSON.stringify(records,null,2));
  writeFileSync(resolve(output,'recorrido.json'),JSON.stringify(actions,null,2));
};
const note=(type,text)=>{records.push({type,text,time:Date.now()});persist();};
const demand=(condition,message)=>{if(!condition)throw Error(message);};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
let browser, finalCode=1, remotePck;
const timer=setTimeout(()=>{note('runner-error','Límite de300segundos');void browser?.close();},300000);
try {
  remotePck=sha(new Uint8Array(await (await fetch(new URL('index.pck',url))).arrayBuffer()));
  demand(remotePck===expectedPck,'El servidor entrega otro PCK');
  browser=await chromium.launch({channel:'chrome',headless:false,args:['--window-size=1280,720','--disable-backgrounding-occluded-windows','--disable-renderer-backgrounding','--disable-background-timer-throttling']});
  const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
  const page=await context.newPage(), cdp=await context.newCDPSession(page);
  page.on('console',m=>note(m.type(),m.text()));
  page.on('pageerror',e=>note('pageerror',e.stack||e.message));
  const read=async expression=>{
    const result=await cdp.send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true,userGesture:false});
    if(result.exceptionDetails) throw Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  const until=async predicate=>{const end=Date.now()+120000;while(Date.now()<end){const value=await predicate();if(value)return value;await delay(100);}throw Error('Timeout esperando estado444');};
  const state=()=>read('window.__444_state || null');
  const payloads=[['fixture444.gd','/fixture444.gd'],['fixture444.tscn','/fixture444.tscn'],['override.cfg','/override.cfg']].map(([name,path])=>({name,path,bytes:readFileSync(resolve(own,name))}));
  await page.route('**/index.html*',async route=>{
    const response=await route.fetch(), html=await response.text();
    demand(sha(html)===original['index.html'],'HTML servido distinto del export fijado');
    demand(/engine\.startGame\(\s*\{/.test(html),'No se encuentra startGame');
    const preloads=payloads.map(item=>`engine.preloadFile(new Uint8Array(${JSON.stringify([...item.bytes])}), ${JSON.stringify(item.path)});`).join('\n');
    const served=html.replace(/engine\.startGame\(\s*\{/,preloads+'\nengine.startGame({args:[],');
    actions.push({montaje:'override-Node',html_original_sha256:sha(html),html_servido_sha256:sha(served),preloads:payloads.map(item=>({path:item.path,sha256:sha(item.bytes)})),args:[]});persist();
    await route.fulfill({response,body:served});
  });
  await page.goto(url+'?fixture444=1',{waitUntil:'load',timeout:180000});
  await until(async()=>{const s=await state();return s?.etapa==='jornada2'&&s;});
  let commandId=0;
  const prepare=async command=>{
    const id=++commandId;
    actions.push({preparacion:{id,...command},userGesture:false});persist();
    await read('window.__444_command = '+JSON.stringify({id,...command}));
    return until(async()=>{const s=await state();return s?.id===id&&s;});
  };
  const click=async()=>{actions.push({input:'mouse',button:'left',x:640,y:360});persist();await page.mouse.click(640,360);await delay(350);};
  const snapshot=async(name,expected={},capture=false,pointer=null)=>{
    await delay(250);
    const frames=await read('new Promise(resolve=>{let n=0;function f(){if(++n<4)requestAnimationFrame(f);else resolve(n)}requestAnimationFrame(f)})');
    const game=await prepare({accion:'observar'}), dom=await read('({visible:document.visibilityState,aislado:crossOriginIsolated,pointer:!!document.pointerLockElement,ancho:innerWidth,alto:innerHeight})');
    actions.push({snapshot:name,game,dom,frames});persist();
    demand(game&&game.fallos.length===0&&game.suelo&&game.capsula_libre,'Premisa física inválida: '+name);
    demand(dom.visible==='visible'&&dom.aislado&&dom.ancho===1280&&dom.alto===720,'Viewport/aislamiento incorrecto');
    if(pointer!==null)demand(dom.pointer===pointer,'Pointer Lock incorrecto: '+name);
    const numbers=text=>text.match(/[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?/g).map(Number);
    const current=numbers(game.camara_actual),drawn=numbers(game.camara_dibujada);
    demand(current.length===12&&drawn.length===12&&Math.max(...current.map((v,i)=>Math.abs(v-drawn[i])))<.001,'Cámara efectiva/dibujada difiere');
    for(const [key,value]of Object.entries(expected))demand(game[key]===value,`${name}: ${key}=${game[key]}, esperado${value}`);
    if(game.panel)demand(game.foco_logico===0&&!game.contorno&&game.texto_panel===game.entrada,'Diálogo no dibujado o foco lógico activo');
    if(game.contorno)demand(game.foco_logico!==0&&game.foco_fisico.endsWith('/Comprador/Objetivo'),'Contorno sin foco lógico del comprador');
    if(capture)await page.screenshot({path:resolve(output,name+'.png')});
    return game;
  };
  for(const [buyer,name,initialCount,finalCount,saleCount]of [['fede','Fede',3,2,1],['mia','Mía',1,3,2]]){
    await prepare({accion:buyer});
    const arrival=await snapshot(buyer+'-presencia',{nombre:name,panel:false,visible:true,contorno:true,sprite:`res://assets/characters/${buyer}/idle.tres`},true);
    demand(arrival.iniciales.length===initialCount&&arrival.despedidas.length===finalCount,'Bloques cambiados');
    await prepare({accion:'unidad',indice:0});
    const held=await snapshot(buyer+'-unidad-preparada',{panel:false});
    demand(held.mano!=='0'&&held.identidad_mano!=='0','No hay unidad real en mano');
    await click();
    for(let index=0;index<initialCount;index++){
      const game=await snapshot(buyer+'-inicial-'+index,{panel:true,indice:index,entrada:arrival.iniciales[index],mano:held.mano,identidad_mano:held.identidad_mano,pedido:held.pedido,vendida:false},index===0||index===initialCount-1,false);
      if(index===initialCount-1){for(const product of buyer==='fede'?['Poético','Progres','Duronga']:['Terminator','Fernet God','Actroncito'])demand(game.texto_panel.includes('[color=#e4f850]'+product+'[/color]'),'Falta amarillo'+product);demand(!game.texto_panel.includes('[b]')&&!game.texto_panel.includes('[url'),'Formato añadido');}
      await click();
    }
    await snapshot(buyer+'-retorno-inicial',{panel:false,suspendido:false,visible:true,mano:held.mano,identidad_mano:held.identidad_mano,vendida:false},true,true);
    await click();
    await snapshot(buyer+'-entrega-0',{mano:'0',vendida:false});
    for(const index of [1,2]){await prepare({accion:'unidad',indice:index});await click();await snapshot(buyer+'-entrega-'+index,{mano:'0',vendida:false});}
    await prepare({accion:'ticket'});
    await click();
    for(let index=0;index<finalCount;index++){
      await snapshot(buyer+'-despedida-'+index,{panel:true,indice:index,entrada:arrival.despedidas[index],vendida:true,despachada:false,compras:saleCount,mano:'0'},index===0,false);
      await click();
    }
    await snapshot(buyer+'-retorno-final',{panel:false,suspendido:false,visible:false,vendida:true,despachada:true,compras:saleCount,mano:'0'},true,true);
  }
  await prepare({accion:'fin'});
  await snapshot('fin',{etapa:'fin',compras:2,finales:4,soltados:0});
  await until(()=>records.some(row=>row.text.includes('CAPTURAS_444_FIXTURE_OK')));
  const errors=records.filter(row=>row.type==='error'||row.type==='pageerror'||/SCRIPT ERROR|Parse Error|(^|\s)ERROR:/.test(row.text));
  demand(errors.length===0,'Errores en consola:'+JSON.stringify(errors));
  finalCode=0;
  console.log('CAPTURAS_WEB_444_OK');
}catch(error){note('runner-error',error.stack||String(error));process.exitCode=1;}
finally{
  clearTimeout(timer);persist();await browser?.close();
  const after=pins(),unchanged=JSON.stringify(original)===JSON.stringify(after);
  if(!unchanged){finalCode=1;process.exitCode=1;}
  writeFileSync(resolve(output,'resultado.json'),JSON.stringify({exit_code:finalCode,head,pck_sha256:expectedPck,remote_pck_sha256:remotePck,original,after,export_unchanged:unchanged,scope:'Fixture externo: preparación/observación; clics Chrome reales, CDP userGesture:false; no reemplaza prueba del main original.'},null,2));
}

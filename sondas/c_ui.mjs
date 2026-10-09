import {createRequire} from 'node:module';
import {join} from 'node:path';
import {mkdirSync,writeFileSync} from 'node:fs';
const root='D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia';
const require=createRequire(join(root,'package.json'));
const {chromium}=require('playwright');
const [url,output,size='1920x1080']=process.argv.slice(2);
const [width,height]=size.split('x').map(Number);
mkdirSync(output,{recursive:true});
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--use-angle=d3d11','--disable-backgrounding-occluded-windows','--disable-renderer-backgrounding','--disable-background-timer-throttling']});
const context=await browser.newContext({viewport:{width,height}});
const page=await context.newPage();
const result={url,browser:browser.version(),viewport:size,errors:[],captures:[],apertura_cierre:[]};
let complete=false;
page.on('pageerror',e=>result.errors.push(e.message));
page.on('console',async message=>{
 const text=message.text(); console.log(text);
 if(message.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(text))result.errors.push(text);
 if(text.startsWith('[apertura-cierre]'))result.apertura_cierre.push(text);
 if(text.startsWith('[dinamicos]'))result.dinamicos=text;
 if(text.startsWith('[recursos]'))result.recursos=text;
 if(text.startsWith('[etapa] ')){
  const name=text.slice(8);
  try{
   const frames=await page.evaluate(()=>new Promise(resolve=>{let n=0;const start=performance.now();function tick(t){n++;if(t-start>1000)resolve(n);else requestAnimationFrame(tick)}requestAnimationFrame(tick)}));
   if(frames<10)throw new Error(`sólo ${frames} cuadros/s`);
   await page.locator('canvas').screenshot({path:join(output,`${name}.png`)});
   result.captures.push({name,frames});
   await page.evaluate(n=>window.__capturada=n,name);
  }catch(e){result.errors.push(e.message);complete=true;}
 }
 if(text.startsWith('[fin]'))complete=true;
});
try{
 await page.goto(url,{waitUntil:'load',timeout:180000});
 result.renderer=await page.evaluate(()=>{const gl=document.createElement('canvas').getContext('webgl2');const ext=gl.getExtension('WEBGL_debug_renderer_info');return gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)});
 if(/swiftshader|software|warp/i.test(result.renderer))throw new Error(result.renderer);
 const deadline=Date.now()+180000;
 while(!complete&&Date.now()<deadline)await page.waitForTimeout(100);
 if(!complete||!result.recursos||!result.dinamicos||result.captures.length!==3||result.apertura_cierre.length!==2||result.errors.length)throw new Error('capturas/apertura-cierre/dinámicos incompletos o errores');
}catch(e){result.errors.push(e.message);process.exitCode=1;}
finally{writeFileSync(join(output,'ui.json'),JSON.stringify(result,null,2));await browser.close();}

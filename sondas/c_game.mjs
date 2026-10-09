import {createRequire} from 'node:module';
import {join} from 'node:path';
import {mkdirSync,writeFileSync} from 'node:fs';
const require=createRequire('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/package.json');
const {chromium}=require('playwright');
const [url,output]=process.argv.slice(2);mkdirSync(output,{recursive:true});
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--use-angle=d3d11','--disable-backgrounding-occluded-windows','--disable-renderer-backgrounding','--disable-background-timer-throttling']});
const context=await browser.newContext({viewport:{width:1920,height:1080}});const page=await context.newPage();
const result={errors:[],captures:[],browser:browser.version(),viewport:'1920x1080'};let menu=false,store=false;
page.on('pageerror',e=>result.errors.push(e.message));
page.on('console',m=>{const text=m.text();console.log(text);if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(text))result.errors.push(text);if(text.includes('[carga] menú visible'))menu=true;if(text.includes('[carga] almacén en pantalla'))store=true;});
async function until(check){const end=Date.now()+180000;while(!check()&&Date.now()<end)await page.waitForTimeout(100);if(!check())throw new Error('no llegó pantalla');}
async function capture(name){await page.evaluate(()=>new Promise(resolve=>{let frames=0;function next(){if(++frames===35)resolve();else requestAnimationFrame(next)}requestAnimationFrame(next)}));await page.locator('canvas').screenshot({path:join(output,name+'.png')});result.captures.push(name);}
try{
 await page.goto(url,{waitUntil:'load',timeout:180000});await until(()=>menu);
 result.renderer=await page.evaluate(()=>{const gl=document.createElement('canvas').getContext('webgl2');return gl.getParameter(gl.getExtension('WEBGL_debug_renderer_info').UNMASKED_RENDERER_WEBGL)});
 if(/software|swiftshader|warp/i.test(result.renderer))throw new Error('renderizado software');
 await capture('inicio-real');await page.mouse.click(960,1080*.56);await until(()=>store);await capture('almacen-real');
 if(result.errors.length)throw new Error('errores del juego');
}catch(e){result.errors.push(e.message);process.exitCode=1;}
finally{writeFileSync(join(output,'recorrido.json'),JSON.stringify(result,null,2));await browser.close();}

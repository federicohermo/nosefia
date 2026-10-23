import { chromium, firefox } from '../../node_modules/playwright/index.mjs';
import { writeFileSync, mkdirSync } from 'node:fs';
const [fase, nombre, puerto] = process.argv.slice(2);
const carpeta = `reports/barra/evidencia/${fase}-${nombre}`;
mkdirSync(carpeta, {recursive:true});
const browser = await (nombre === 'chrome' ? chromium : firefox).launch({headless:true, ...(nombre === 'chrome' ? {channel:'chrome', args:['--use-angle=d3d11','--disable-background-timer-throttling']} : {})});
const page = await browser.newPage({viewport:{width:1536,height:864}});
const log=[];
page.on('console', m=>{log.push(m.text()); if (/repro|ERROR|Error/.test(m.text())) console.log(m.text());});
page.on('pageerror', e=>{log.push(String(e));console.log(String(e));});
try {
 await page.goto(`http://localhost:${puerto}`, {timeout:180000});
 await page.waitForFunction(()=>window.__listoJ2, null, {timeout:300000});
 await page.screenshot({path:`${carpeta}/j2.png`});
 console.log('J2 lista, cerrar');
 await page.evaluate(()=>{window.__barra=[];window.__cerrarJ2=true;});
 await page.waitForFunction(()=>window.__barra?.some(v=>v[3]===1),null,{timeout:120000});
 await page.screenshot({path:`${carpeta}/transicion.png`});
 await page.waitForFunction(()=>window.__abierta===3,null,{timeout:240000});
 await page.screenshot({path:`${carpeta}/j3.png`});
 const valores = await page.evaluate(()=>window.__barra.filter(v=>v[3]===1));
 const retrocesos=valores.filter((v,i)=>i>0&&v[2]<valores[i-1][2]);
 const datos = {fase,navegador:nombre,version:browser.version(),url:page.url(),valores,retrocesos};
 writeFileSync(`${carpeta}/valores.json`,JSON.stringify(datos,null,2));
 console.log(JSON.stringify({fase,nombre,muestras:valores.length,retrocesos:retrocesos.length,ejemplos:retrocesos.slice(0,3)}));
} catch(e){await page.screenshot({path:`${carpeta}/error.png`}).catch(()=>{}); throw e;}
finally {writeFileSync(`${carpeta}/consola.txt`,log.join('\n'));await browser.close();}

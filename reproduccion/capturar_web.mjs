import { chromium } from 'playwright';
import { mkdir, writeFile } from 'node:fs/promises';

const phase = process.argv[2] ?? 'antes';
const browser = await chromium.launch({channel: 'msedge', headless: false});
const page = await browser.newPage({viewport: {width: 1280, height: 960}});
const logs = [];
let ready;
const loaded = new Promise(resolve => { ready = resolve; });
page.on('console', m => { logs.push(m.text()); console.log(m.text()); if (m.text().includes('CAPTURA_LISTA')) ready(); });
page.on('pageerror', e => console.log('PAGE_ERROR', e.message));
await mkdir(`tmp/capturas/${phase}`, {recursive: true});
await page.goto(process.argv[3] ?? 'http://localhost:8064', {timeout: 120000});
await page.waitForFunction(() => !document.getElementById('status'), {timeout: 120000});
await Promise.race([loaded, new Promise((_, reject) => setTimeout(() => reject(new Error('Fixture not ready')), 180000).unref())]);
await page.screenshot({path: `tmp/capturas/${phase}/inicial.png`});
for (const [key, name] of [['1','martin'], ['2','tiago'], ['3','fede'], ['4','mia']]) {
  await page.keyboard.press(key);
  await page.keyboard.press('9');
  await page.waitForTimeout(700);
  await page.screenshot({path: `tmp/capturas/${phase}/${name}-foco.png`});
  await page.keyboard.press('0');
  await page.waitForTimeout(700);
  await page.screenshot({path: `tmp/capturas/${phase}/${name}-sin-foco.png`});
}
await writeFile(`tmp/capturas/${phase}/consola.txt`, logs.join('\n'));
await browser.close();

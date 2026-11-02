// Entra al juego de Godot (web), lleva al jugador a cada vista de vistas.json y guarda la pose real de la cámara.
// Uso: node poses.mjs <url> <vistas.json> <salida.json>
import { chromium } from 'playwright';
import { readFileSync, writeFileSync } from 'node:fs';
const [url, archivo, salida] = process.argv.slice(2);
const vistas = JSON.parse(readFileSync(archivo, 'utf8'));
const nav = await chromium.launch({ channel: 'chrome', headless: false, args: ['--mute-audio', '--disable-features=CalculateNativeWinOcclusion', '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding'] });
const pag = await nav.newPage({ viewport: { width: 1536, height: 760 } });
const lineas = [];
pag.on('console', (m) => lineas.push(m.text()));
const esperar = async (t, ms) => { const d = Date.now(); while (Date.now() - d < ms) { if (lineas.some((l) => l.includes(t))) return true; await pag.waitForTimeout(300); } return false; };
await pag.goto(url);
await esperar('[carga] menú visible', 240000);
await esperar('[carga] almacén calentado', 240000);
await pag.waitForTimeout(1500);
await pag.mouse.move(768, 430); await pag.mouse.down(); await pag.waitForTimeout(100); await pag.mouse.up();
await esperar('[carga] almacén en pantalla', 240000);
await pag.waitForTimeout(2000);
for (let i = 0; i < 8; i++) { await pag.mouse.click(1258, 624); await pag.waitForTimeout(1000); }
await pag.waitForTimeout(3000);
const poses = {};
for (const v of vistas) {
  const yaw = Math.atan2(-(v.a[0] - v.de[0]), -(v.a[2] - v.de[1]));
  await pag.evaluate(([x, z, yaw, a]) => window.ir_godot(x, z, yaw, a[0], a[1], a[2]), [v.de[0], v.de[1], yaw, v.a]);
  await pag.waitForTimeout(2500);
  await pag.evaluate(() => window.expr_godot('str(get_viewport().get_camera_3d().global_transform) + "|" + str(get_viewport().get_camera_3d().fov) + "|" + str(get_viewport().get_camera_3d().near) + "|" + str(get_viewport().get_camera_3d().far)'));
  await pag.waitForTimeout(500);
  poses[v.n] = await pag.evaluate(() => window.expr_txt);
}
writeFileSync(salida, JSON.stringify(poses, null, 1));
console.log(JSON.stringify(poses, null, 1));
await nav.close();

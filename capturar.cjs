const { chromium, firefox } = require('playwright');
const { mkdirSync, writeFileSync, readFileSync } = require('node:fs');
const { createHash } = require('node:crypto');
const assert = require('node:assert/strict');

async function main() {
  const kind = process.argv[2];
  const browser = await (kind === 'chrome' ? chromium : firefox).launch(
    kind === 'chrome' ? { channel: 'chrome', headless: true } : { headless: true }
  );
  const folder = `reports/cami-631/evidencia/${kind}`;
  mkdirSync(folder, { recursive: true });
  const errors = [];
  const log = [];
  const states = [];
  try {
    const context = await browser.newContext({ viewport: { width: 1536, height: 760 } });
    const page = await context.newPage();
    await page.bringToFront();
    page.on('console', message => {
      log.push(message.text());
      if (message.type() === 'error') errors.push(message.text());
      writeFileSync(`${folder}/console.log`, log.join('\n'));
    });
    page.on('pageerror', error => errors.push(String(error)));
    const ready = page.waitForEvent('console', { predicate: m => m.text().includes('[cami] ready'), timeout: 180000 });
    await page.goto('http://localhost:8631/captura/', { timeout: 180000 });
    await ready;
    await page.waitForSelector('#status', { state: 'hidden', timeout: 180000 });
    const gpu = await page.evaluate(() => {
      const gl = document.createElement('canvas').getContext('webgl2');
      const info = gl.getExtension('WEBGL_debug_renderer_info');
      return gl.getParameter(info.UNMASKED_RENDERER_WEBGL);
    });
    assert(!/swiftshader|llvmpipe|software/i.test(gpu), gpu);
    for (const command of ['front', 'left', 'right', ...Array.from({ length: 8 }, (_, i) => `frame${i}`),
      'transparent', 'front', 'talk', 'world', 'fede', 'reset']) {
      await page.evaluate(command => { window.camiState = null; window.camiCommand = command; }, command);
      await page.waitForFunction(command => window.camiState?.command === command, command, { timeout: 20000 });
      const state = await page.evaluate(() => window.camiState);
      states.push(state);
      assert(state.visible);
      assert.equal(state.cached_images, 40);
      assert.equal(state.frames.length, 8);
      const character = command === 'fede' ? 'fede' : 'cami';
      assert.equal(state.resource, `res://assets/characters/${character}/idle.tres`);
      state.frames.forEach((frame, index) => {
        assert.equal(frame.path, `res://assets/characters/${character}/${String(index + 1).padStart(2, '0')}.png`);
        assert.equal(frame.width, 1086);
        assert.equal(frame.height, 1448);
      });
      if (Object.keys(state.pose).length) {
        assert(state.pose.piso && state.pose.capsula);
        assert.equal(state.pose.objetivo, command !== 'transparent');
        assert(state.pose.angulo < 0.005);
        assert.equal(state.outline, command !== 'transparent');
      }
      if (command === 'talk') assert(state.panel);
      if (command === 'world') assert(!state.panel);
      if (command === 'reset') assert.equal(state.retreats, 0);
      await page.screenshot({ path: `${folder}/${command}.png` });
    }
    assert.equal(errors.length, 0, JSON.stringify(errors));
    const pck = createHash('sha256').update(readFileSync('export/cami/index.pck')).digest('hex');
    const fixturePck = createHash('sha256').update(readFileSync('export/captura/index.pck')).digest('hex');
    writeFileSync(`${folder}/resultado.json`, JSON.stringify({ browser: browser.version(), gpu, pck, fixturePck, states, errors }, null, 2));
    console.log(`${kind}: ${states.length} states passed; ${gpu}`);
  } finally {
    await browser.close();
    writeFileSync(`${folder}/errors.json`, JSON.stringify(errors, null, 2));
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });

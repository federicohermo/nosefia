// Vuelca las tablas LTC de Three.js (las de Heitz) a datos/ltc.json, para las luces de área de PlayCanvas.
import { RectAreaLightTexturesLib } from '../three/node_modules/three/examples/jsm/lights/RectAreaLightTexturesLib.js';
import { writeFileSync } from 'node:fs';
const ltc = RectAreaLightTexturesLib.init();
writeFileSync(new URL('../datos/ltc.json', import.meta.url), JSON.stringify({ a: Array.from(ltc.LTC_FLOAT_1.image.data), b: Array.from(ltc.LTC_FLOAT_2.image.data), w: ltc.LTC_FLOAT_1.image.width }));

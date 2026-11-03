#!/usr/bin/env bash
# Empaqueta los visores con esbuild. Uso: empaquetar.sh [three|pc]   (sin argumento, los dos)
set -e
# DBG=1 arma visor.dbg.js sin minificar, para leer los nombres de las funciones en un perfil.
MIN="--minify"; SAL=visor.js; if [ -n "${DBG:-}" ]; then MIN=""; SAL=visor.dbg.js; fi
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-three}" = three ] || [ -z "${1:-}" ]; then
  (cd "$RAIZ/three" && npx esbuild visor/visor.js --bundle $MIN --format=esm --outfile=dist/$SAL \
    --alias:three=./node_modules/three/build/three.webgpu.js --alias:three/webgpu=./node_modules/three/build/three.webgpu.js \
    --alias:three/tsl=./node_modules/three/build/three.tsl.js --alias:three/addons=./node_modules/three/examples/jsm --log-level=warning)
fi
if [ "${1:-pc}" = pc ] || [ -z "${1:-}" ]; then
  (cd "$RAIZ/pc" && npx esbuild visor/visor.js --bundle $MIN --format=esm --outfile=dist/$SAL --log-level=warning)
fi

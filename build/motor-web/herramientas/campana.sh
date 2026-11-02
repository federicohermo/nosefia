#!/usr/bin/env bash
# Uso: campana.sh <rondas> <modo: vsync|libre> [lados]   (alterna G T W P / P W T G en cada ronda)
# G: web de hoy (Godot 4.7.2, WebGL2) · T: Three.js WebGPU · W: Three.js WebGL2 · P: PlayCanvas WebGL2
rondas=$1; modo=$2; lados=${3:-"G T W P"}
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
ARNES=/c/Users/fede_/.cache/nosefia/arnes
extra=""; [ "$modo" = "libre" ] && extra="--sin-limite"
seg=6; [ "$modo" = "vsync" ] && seg=3
for r in $(seq 1 $rondas); do
  if [ $((r % 2)) -eq 1 ]; then orden=$lados; else orden=$(echo $lados | tr ' ' '\n' | tac | tr '\n' ' '); fi
  for l in $orden; do
    out="$RAIZ/medidas/campana/$modo-r$r-$l.json"
    echo "ronda $r lado $l $(date +%T)"
    case $l in
      G) (cd $ARNES && node medir.mjs "http://127.0.0.1:8123/index.html" "$out" --etiqueta=G $extra) 2>&1 | tail -1 ;;
      T) node "$RAIZ/herramientas/medir_visor.mjs" "http://127.0.0.1:8121/three/visor/bundle.html?api=webgpu" "$out" 8121 --etiqueta=T --segundos=$seg $extra 2>&1 | tail -1 ;;
      W) node "$RAIZ/herramientas/medir_visor.mjs" "http://127.0.0.1:8121/three/visor/bundle.html?api=webgl2" "$out" 8121 --etiqueta=W --segundos=$seg $extra 2>&1 | tail -1 ;;
      P) node "$RAIZ/herramientas/medir_visor.mjs" "http://127.0.0.1:8121/pc/visor/bundle.html" "$out" 8121 --etiqueta=P --segundos=$seg $extra 2>&1 | tail -1 ;;
    esac
  done
done
echo FIN

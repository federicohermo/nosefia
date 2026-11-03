#!/usr/bin/env bash
# Campaña de la etapa 1. Uso: campana3.sh <modo> [rondas]
#   vsync   Chrome con tope de cuadros: primera y segunda visita, bytes y memoria (G T W P)
#   libre   Chrome sin tope: tiempo de cuadro y CPU por cuadro (G T W P y X, Y: los dos de Three sin las palancas)
#   cpu4    Chrome con la CPU 4 veces más lenta, sin tope (G T W P)
#   ff      Firefox con tope: primera y segunda visita (G T W P)
# Alterna el orden en cada ronda. G es la web de hoy y espera en el puerto 8123 (ver el resultado.md).
modo=$1; rondas=${2:-5}
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
ARNES=/c/Users/fede_/.cache/nosefia/arnes
V="$RAIZ/herramientas/medir_visor.mjs"
M="$RAIZ/medidas/etapa1"; mkdir -p "$M"
B=http://127.0.0.1:8121
SIN="luces=nativas&fusion=0&bundle=0"
case $modo in
  vsync) lados="G T W P"; extra=""; seg=3 ;;
  libre) lados="G T W P X Y"; extra="--sin-limite"; seg=6 ;;
  cpu4)  lados="G T W P"; extra="--sin-limite --cpu=4"; seg=4 ;;
  ff)    lados="G T W P"; extra="--firefox"; seg=3 ;;
  *) echo "modo desconocido"; exit 1 ;;
esac
for r in $(seq 1 $rondas); do
  if [ $((r % 2)) -eq 1 ]; then orden=$lados; else orden=$(echo $lados | tr ' ' '\n' | tac | tr '\n' ' '); fi
  for l in $orden; do
    out="$M/$modo-r$r-$l.json"
    echo "ronda $r lado $l $(date +%T)"
    una=""; [ "$modo" = "cpu4" ] && una="--una-visita"
    case $l in
      G) if [ "$modo" = ff ]; then
           (cd $ARNES && node "$RAIZ/herramientas/medir_godot.mjs" "http://127.0.0.1:8123/index.html" "$out" --etiqueta=G $extra --segundos=$seg) 2>&1 | tail -1
         else
           (cd $ARNES && node medir.mjs "http://127.0.0.1:8123/index.html" "$out" --etiqueta=G $extra --segundos=$seg) 2>&1 | tail -1
         fi ;;
      T) node $V "$B/three/visor/bundle.html?api=webgpu" "$out" 8121 --etiqueta=T --segundos=$seg $extra $una 2>&1 | tail -1 ;;
      W) node $V "$B/three/visor/bundle.html?api=webgl2" "$out" 8121 --etiqueta=W --segundos=$seg $extra $una 2>&1 | tail -1 ;;
      X) node $V "$B/three/visor/bundle.html?api=webgpu&$SIN" "$out" 8121 --etiqueta=X --segundos=$seg $extra $una 2>&1 | tail -1 ;;
      Y) node $V "$B/three/visor/bundle.html?api=webgl2&$SIN" "$out" 8121 --etiqueta=Y --segundos=$seg $extra $una 2>&1 | tail -1 ;;
      P) node $V "$B/pc/visor/bundle.html" "$out" 8121 --etiqueta=P --segundos=$seg $extra $una 2>&1 | tail -1 ;;
    esac
  done
done
echo FIN

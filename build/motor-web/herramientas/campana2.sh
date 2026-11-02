#!/usr/bin/env bash
# Fases extra: A) segunda visita de Godot, B) CPU frenada 4 veces, C) Firefox.
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
ARNES=/c/Users/fede_/.cache/nosefia/arnes
M="$RAIZ/medidas/extra"; mkdir -p "$M"
V="$RAIZ/herramientas/medir_visor.mjs"
url_t="http://127.0.0.1:8121/three/visor/bundle.html?api=webgpu"
url_w="http://127.0.0.1:8121/three/visor/bundle.html?api=webgl2"
url_p="http://127.0.0.1:8121/pc/visor/bundle.html"
fase=$1
if [ "$fase" = "A" ]; then
  for r in 1 2 3; do
    perfil=$(mktemp -d)
    echo "A ronda $r primera"; (cd $ARNES && node "$RAIZ/herramientas/medir_godot.mjs" "http://127.0.0.1:8123/index.html" "$M/godot-2visita-r$r-1.json" --etiqueta=G1 --perfil="$perfil" --segundos=3) 2>&1 | tail -1
    echo "A ronda $r segunda"; (cd $ARNES && node "$RAIZ/herramientas/medir_godot.mjs" "http://127.0.0.1:8123/index.html" "$M/godot-2visita-r$r-2.json" --etiqueta=G2 --perfil="$perfil" --segundos=3) 2>&1 | tail -1
    rm -rf "$perfil"
  done
fi
if [ "$fase" = "B" ]; then
  for r in 1 2 3; do
    if [ $((r % 2)) -eq 1 ]; then orden="G T W P"; else orden="P W T G"; fi
    for l in $orden; do
      echo "B ronda $r lado $l"
      case $l in
        G) (cd $ARNES && node "$RAIZ/herramientas/medir_godot.mjs" "http://127.0.0.1:8123/index.html" "$M/cpu4-r$r-G.json" --etiqueta=G --sin-limite --cpu=4 --segundos=4) 2>&1 | tail -1 ;;
        T) node $V "$url_t" "$M/cpu4-r$r-T.json" 8121 --etiqueta=T --sin-limite --cpu=4 --segundos=4 --una-visita 2>&1 | tail -1 ;;
        W) node $V "$url_w" "$M/cpu4-r$r-W.json" 8121 --etiqueta=W --sin-limite --cpu=4 --segundos=4 --una-visita 2>&1 | tail -1 ;;
        P) node $V "$url_p" "$M/cpu4-r$r-P.json" 8121 --etiqueta=P --sin-limite --cpu=4 --segundos=4 --una-visita 2>&1 | tail -1 ;;
      esac
    done
  done
fi
if [ "$fase" = "C" ]; then
  for r in 1 2 3 4 5; do
    if [ $((r % 2)) -eq 1 ]; then orden="G T W P"; else orden="P W T G"; fi
    for l in $orden; do
      [ "$l" = "G" ] && [ $r -gt 3 ] && continue
      echo "C ronda $r lado $l"
      case $l in
        G) (cd $ARNES && node "$RAIZ/herramientas/medir_godot.mjs" "http://127.0.0.1:8123/index.html" "$M/ff-r$r-G.json" --etiqueta=G --firefox --segundos=3) 2>&1 | tail -1 ;;
        T) node $V "$url_t" "$M/ff-r$r-T.json" 8121 --etiqueta=T --firefox --segundos=3 2>&1 | tail -1 ;;
        W) node $V "$url_w" "$M/ff-r$r-W.json" 8121 --etiqueta=W --firefox --segundos=3 2>&1 | tail -1 ;;
        P) node $V "$url_p" "$M/ff-r$r-P.json" 8121 --etiqueta=P --firefox --segundos=3 2>&1 | tail -1 ;;
      esac
    done
  done
fi
echo FIN

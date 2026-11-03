#!/usr/bin/env bash
# Apaga de a una cada palanca de Three.js y mide carga y CPU por cuadro (Chrome, sin tope).
# Uso: ablacion.sh [rondas]    Escribe medidas/etapa1/abl-r<ronda>-<api>-<variante>.json
rondas=${1:-3}
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
V="$RAIZ/herramientas/medir_visor.mjs"
M="$RAIZ/medidas/etapa1"; mkdir -p "$M"
B=http://127.0.0.1:8121/three/visor/bundle.html
for r in $(seq 1 $rondas); do
  for api in webgl2 webgpu; do
    variantes="todo luces=nativas fusion=0"
    [ "$api" = webgpu ] && variantes="$variantes bundle=0"
    if [ $((r % 2)) -eq 0 ]; then variantes=$(echo $variantes | tr ' ' '\n' | tac | tr '\n' ' '); fi
    for v in $variantes; do
      q="api=$api"; [ "$v" != todo ] && q="$q&$v"
      nombre=$(echo "$v" | tr '=' '-')
      echo "ronda $r $api $v $(date +%T)"
      node $V "$B?$q" "$M/abl-r$r-$api-$nombre.json" 8121 --etiqueta=$nombre --sin-limite --una-visita --segundos=4 2>&1 | tail -1
    done
  done
done
echo FIN

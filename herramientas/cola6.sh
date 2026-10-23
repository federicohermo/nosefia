#!/bin/bash
cd "$(dirname "$0")"
export ESPERA_MS=240000
L=cola6.log; : > $L
for i in 1 2 3; do node medir.mjs "http://localhost:8078/index.html?hasta=3" J3F_new_chrome$i.json >> $L 2>&1; echo "J3F_new_chrome$i" >> $L; done
for i in 1 2 3; do node medir.mjs "http://localhost:8079/index.html?hasta=3" J3F_old_chrome$i.json >> $L 2>&1; echo "J3F_old_chrome$i" >> $L; done
for i in 1 2 3; do node medir.mjs "http://localhost:8078/index.html?hasta=3" J3F_new_ff$i.json --firefox >> $L 2>&1; echo "J3F_new_ff$i" >> $L; done
for i in 1 2 3; do node medir.mjs "http://localhost:8079/index.html?hasta=3" J3F_old_ff$i.json --firefox >> $L 2>&1; echo "J3F_old_ff$i" >> $L; done
echo FIN >> $L

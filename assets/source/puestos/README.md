# Caja registradora, lector y ticket

Estas tres piezas salen de `modelossupermercado`, revisión
`379df911f49eafffc273fcaa84490d848b620f1c`, archivo
`assets/models/SEPT_JUEGOS_PROTOTIPO.blend` (blob
`c864e56c5729a205c79858d1dd631debb7195dd0`).

`caja_registradora.blend` conserva las mallas, UV, materiales y transformaciones del artista;
sólo se retiraron los objetos ajenos. Sus tres imágenes están empaquetadas a resolución
original. El modelo completo del almacén conserva su fuente y exportación anteriores.

Para exportar estas piezas con Blender 5.2.1, desde la raíz del repositorio:

```powershell
blender assets/source/puestos/caja_registradora.blend --background --python-exit-code 1 --python .claude/scripts/blender/exportar_caja.py -- assets/models
```

El exportador aplica la transformación de cada pieza en metros, corrige el sentido de las
caras al aplicar la escala negativa del lector y centra el papel para levantarlo. Conserva
las UV y limita las imágenes exportadas a 1024 píxeles. No guarda cambios en la fuente.

Al reimportar los tres GLB en Godot, `assets/models/importar_caja.gd` guarda las mallas `.res`
y las colisiones estáticas que usan las escenas. El ticket recibe una colisión fina propia
y se dibuja por ambas caras. Las posiciones en el juego se ajustan al escritorio vigente;
el papel aparece sólo al imprimir y su salida se anima desde la caja.

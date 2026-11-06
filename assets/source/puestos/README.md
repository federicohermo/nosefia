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

El exportador evalúa la malla antes de aplicar la transformación original en metros,
conserva las UV y limita las imágenes exportadas a 1024 píxeles. Refleja X para usar
el mismo espacio que el escritorio vigente y corrige el sentido de las caras. Centra
el papel para levantarlo. No guarda cambios en la fuente.

Al reimportar los tres GLB en Godot, `assets/models/importar_caja.gd` guarda las mallas `.res`
y las colisiones estáticas que usan las escenas. El ticket recibe una colisión fina propia
y se dibuja por ambas caras.

La registradora, el lector y el ticket conservan el tamaño y la disposición del artista,
sin ampliaciones ni giros adicionales. El ticket sólo se ve más grande mientras se lo lleva o
se lo examina, y lo escala el juego sin tocar el modelo. La correspondencia con el escritorio del juego es
`(x, y, z) = (4.43 - x_blender, z_blender, -y_blender - 1.532)`. El escritorio, el reloj
y la computadora comparten esa correspondencia. El papel aparece sólo al imprimir y
su salida se anima hasta la posición original del ticket del artista.

Clic derecho en el lector registra el producto sostenido sin abrir una pantalla. Clic derecho
en la registradora abre el generador. Desde la jornada 6 el lector se reemplaza por
su hueco y el programa pasa a modo manual.

## El hueco del lector

Desde la jornada 6, el lector se reemplaza por `hueco_del_lector.blend`: el marco roto que dejó
al arrancarlo, el pasacables del fondo y seis cables cortados con el cobre a la vista. No sale
del artista: lo arma entero `.claude/scripts/blender/hueco_del_lector.py`, que también lo exporta.
Un cambio se hace en ese script, no en el `.blend`, porque la corrida siguiente lo reemplaza.

```powershell
blender --background --factory-startup --python-exit-code 1 --python .claude/scripts/blender/hueco_del_lector.py
```

Los colores salen de una paleta de 16 px, con un color por celda. Su textura no se repite, como
la del frente del lector: así los dos materiales comparten el programa del shader, y la jornada 6
no compila uno nuevo en la web. El hueco es redondo, como la base del lector, y su forma de
choque es un cilindro del mismo radio, en `lector.tscn`. `importar_caja.gd` guarda sólo la malla.

## El router del wifi

Sale de `modelossupermercado`, revisión `4eb137ae44684b0e23ca509a611dc2d660afee53`, archivo
`assets/source/SEPT_JUEGOS_PROTOTIPO.blend` (blob `abcf9bb192ad765c57b666a89cf32bd78119a410`). Son
cinco objetos del artista: `router-col`, `antenas-col`, `luces_botones-col`, `patasrouter-col` y
`powerrouter_col`. El cuerpo, las antenas y las luces comparten un solo atlas pixelado; las patas
y el botón de encendido llevan un color.

Las tres imágenes del atlas son las del artista, una por estado, en `assets/models/router/`:

| Estado | Archivo | Origen en la rama (blob) |
|---|---|---|
| Con wifi: luces verdes | `router_prendido.png` | `router estilo.png` (`67315810`) |
| Apagado o sin energía: luces apagadas | `router_apagado.png` | `router apagado.png` (`fa4d0c8c`) |
| Descompuesto con luz: luces rojas | `router_descompuesto.png` | `router luz roja (sin señal).png` (`3caf6246`) |

`textura router`, la versión sin pixelar, no se usa. Las imágenes conservan su tamaño: el atlas
tiene píxeles de 6 px y reducirlo los deforma.

`router.blend` deja sólo esos cinco objetos, con el atlas empaquetado. Se arma desde el `.blend`
del artista en esa revisión, y se exporta con Blender 5.2:

```powershell
blender SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 --python .claude/scripts/blender/extraer_router.py -- assets/source/puestos/router.blend
blender assets/source/puestos/router.blend --background --python-exit-code 1 --python .claude/scripts/blender/exportar_router.py -- assets/models
```

La exportación une las cinco piezas en una sola malla con un material por pieza, con la misma
correspondencia que la caja registradora. El GLB no lleva imágenes: el estado del router cambia la
textura de los tres materiales con luces (`router_cuerpo`, `router_antenas` y `router_luces`) y no
la malla. `importar_caja.gd` guarda `router.res` y su colisión convexa al importar.

El router va donde lo dejó el artista, sobre el escritorio, con la correspondencia de la caja
registradora y el corrimiento del escritorio vigente: la computadora y el teclado están
`(0.25, 0.2269, 0)` más allá que en la fuente. El cuerpo queda en `(1.4774, 1.2071, 5.0256)`.

## Las cajas del proveedor

La caja de cartón del proveedor y la caja de madera de Fernet God salen de `modelossupermercado`,
revisión `4eb137ae44684b0e23ca509a611dc2d660afee53`. Los `.blend` y las imágenes son los del
artista, sin tocar: se copiaron con su disposición de carpetas, porque el `.blend` enlaza las
imágenes por ruta relativa.

| Archivo en la rama (`assets/models/Cajas_jornada7/`) | Blob | Acá |
|---|---|---|
| `CajaProveedor.blend` | `2e81dc4d050e6a6b62d3d37377cdc6edd22ae813` | `caja_del_proveedor.blend` |
| `Texturas caja proveedor/caja proveedor uvs.png` | `8a3b50e3b5eb30ce7603f2c9a0bbc5a1c1b2f5c7` | igual |
| `CajaDeMadera.blend` | `34d28bb3a9d9f235822d6ec20bafbd09b38de8e0` | `caja_de_madera.blend` |
| `Texturas caja madera/textura madera frontal.png` | `01ae9e0037a68bfa3958bfe034456960db26b22d` | igual |
| `Texturas caja madera/textura madera laterales.png` | `1c881f7973fc8561cfd27e3bfea3a642d16a7438` | igual |

Cada `.blend` se exporta a un GLB con una sola malla y un material por pieza, con Blender 5.2,
desde la raíz del repositorio:

```powershell
blender assets/source/puestos/caja_del_proveedor.blend --background --python-exit-code 1 --python .claude/scripts/blender/exportar_cajas_del_proveedor.py -- assets/models caja_del_proveedor
blender assets/source/puestos/caja_de_madera.blend --background --python-exit-code 1 --python .claude/scripts/blender/exportar_cajas_del_proveedor.py -- assets/models caja_de_madera
```

El exportador evalúa los modificadores antes de aplicar la transformación, apoya la malla en el
piso con el centro de su base en el origen y limita las imágenes a 1024 píxeles. Conserva la
escala del artista: la caja del proveedor mide lo que dos cajas contenedoras grandes una al lado
de la otra, así que la escena la escala como a una caja de productos grande. La textura del
cartón conserva las etiquetas y los símbolos del artista, y la caja de madera trae su tapa.

Al reimportar los GLB, `assets/models/importar_caja.gd` guarda las mallas `.res` y su casco
convexo de colisión: lo levantable se apoya sobre el casco.

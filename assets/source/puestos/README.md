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

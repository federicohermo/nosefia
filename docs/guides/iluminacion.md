# Iluminación

Los muebles toman la luz de un lightmap horneado. Los productos y las cajas la toman de las
sondas del horneado y de las mismas luces en tiempo real.

## Por qué

- En Compatibility, una luz de área no da sombra y atraviesa las paredes. El horneado respeta
  las paredes.
- Compatibility alumbra cada objeto con un tope de luces. Una luz por estante lo pasa.
- Cada luz con sombra vuelve a dibujar todo lo que alumbra. Horneada, la luz no cuesta nada
  sobre los muebles.

Cómo se mide el costo de las luces, en [rendimiento](./rendimiento.md).

## Cómo está armado

- **Las luces viven en `ambiente_del_almacen.tscn`, en modo `Static`.** Las de heladera, en
  `estructura_del_almacen.tscn`. Una luz `Static` se hornea sobre los muebles y se dibuja en
  tiempo real sobre lo que no tiene lightmap. No van en `almacen.tscn`: esa escena sólo cablea,
  y su test lo cobra.
- **El `LightmapGI` cuelga de la raíz de `almacen.tscn`.** Hornea el subárbol de su padre. Sus
  datos viven al lado: `almacen.lmbake`, `almacen.exr` y `almacen.exr.import`. Los tres se
  commitean. El `.import` dice en cuántas capas se corta el atlas: sin él, otra máquina lo corta
  mal.
- **El modelo se importa con `Static Lightmaps`.** Eso le da a cada malla el segundo juego de UV
  que pide el horneado. El tamaño del texel está en la misma importación.
- **Todo lo que no viene del modelo lleva GI `Dynamic`.** Sin UV2 no se hornea, y con GI
  estático queda negro. Lo dinámico toma la luz de las sondas.
- **Lo que gira también lleva GI `Dynamic`, aunque venga del modelo:** las hojas que abren y la
  tapa del contenedor. Horneadas, dejarían su sombra en la posición en la que se hornearon.
- **Los pallets de la entrega también son dinámicos:** aparecen con las cajas de la primera
  noche y se retiran en la siguiente. Reutilizan la madera del pallet de piso y reciben luz de
  las sondas; no dejan sombras permanentes en el horneado.
- **Los estantes del fondo interceptan la luz cenital del depósito.** Su madera inferior
  necesita luz rebotada para leerse. Se ajustan los plafones del depósito y su energía indirecta
  y se vuelve a hornear. El brillo global, la niebla y el bloom conservan sus valores.
- **Un grupo de productos toma esa luz en un solo punto: el centro de su caja.** La interpola
  entre las cuatro sondas del tetraedro que lo contiene. El horneador reparte las sondas por los
  bordes de las mallas. Muchas caen adentro de una pared o de un mueble, abajo del piso o arriba
  del techo. Un tetraedro cruza la pared y mezcla las dos puntas.
- **La luz de afuera también entra en el horneado con luz.** Los vidrios que dan a la calle emiten,
  igual que en el horneado del corte (`CorteDeLuz.emitir_por_los_vidrios`). Antes de guardar la
  escena, el horneador los devuelve a su estado. El cielo del horneado queda como estaba.
- **El horneador reescribe cada sonda que no está adentro de un ambiente** con el promedio de sus
  vecinas de adentro (`addons/hornear/sondas.gd`). Una sonda está adentro si hacia los seis lados
  ve primero el frente de una superficie horneada, o un vidrio o una hoja que abre. Una sonda de
  adentro no se toca aunque esté negra: es la luz de un ambiente oscuro. Un horneado hecho a mano
  desde el editor no pasa por ese paso.

## Los reflejos de los metales

El entorno no refleja el cielo (`reflected_light_source` apagado). Un metal sólo recibe reflejo de
las `ReflectionProbe` del local. Sin reflejo se ve negro: su luz difusa es el color base por uno
menos el metal. La sonda del salón (`ReflejosDelSalon`) lleva intensidad 1,0. Con 0,65, las bases
de las mesas salían grises mate. Con 3,0, el plástico de las botellas se bordeaba de rosa: reflejaba
las cajas rojas. La sonda se captura una vez. Su
intensidad es un factor y no cuesta nada por cuadro.

Un metal con huecos refleja el local entero: la grilla de las cabeceras (metal 0,5) se teñía del
rojo de los productos. Es un dieléctrico rugoso. La base de las mesas es un metal de 0,9 con el
cromo de las barandas.

La luz de afuera es verde azulada, y un rojo bajo ella sale casi negro: las franjas rojas de los
estantes también emiten (`lib/gondolas.py`). **La paleta y su imagen de emisión miden 5×1 y se
importan sin comprimir.** Comprimidas a VRAM, la build web y la de escritorio perdían el rojo y
las ménsulas salían negras. Una corrida headless importa sin comprimir y no lo muestra: se mide
con `--main-pack` sobre el `.pck` exportado.

## Cómo se hornea

El exportador aplica `blender/separar_hojas_de_entrada.py` antes de generar el modelo. Ese paso
reconstruye las dos hojas de entrada con el vidrio como hijo y el origen en cada bisagra.
Para actualizar también la fuente visible en Blender, se ejecuta ese script sobre el `.blend`
con `-- --aplicar`. Editar las hojas a mano se pierde al exportar.

```bash
python .claude/scripts/hornear.py
```

Qué hace y qué necesita lo dice el encabezado del script. Se corre cada vez que cambia el
modelo, una luz o el `LightmapGI`. Se commitea lo que deja: el `.lmbake`, el `.exr` y el
`.exr.import`. **Lo demás que el editor re-serializa al guardar, el script lo devuelve.** Sin
eso, `almacen.tscn` quedaba con un override por cada volumen de la estructura, y el override
congela su posición.
En Linux sin pantalla ni GPU anda con Xvfb y el Vulkan por software de Mesa; el comando está en
el encabezado. El error de OpenGL que obliga a hornear con Vulkan es el
[reporte 94407 de Godot](https://github.com/godotengine/godot/issues/94407).

**Los dos horneados reparan sus líneas solos.** `hornear.py` llama al reparador después de cada
horneado, sin un paso a mano. También se puede correr suelto:

```bash
blender --background --python-exit-code 1     --python .claude/scripts/blender/reparar_lineas_del_mapa_de_luz.py -- --aplicar
```

El horneador deja, en una fila o una columna del atlas, texeles con la mitad de la luz de sus
vecinos. En el local es una raya oscura de 5 cm sobre una pared o cruzando el cielorraso. Cambia
de lugar cada vez que cambia la malla del edificio, y volver a hornear no la saca. **La causa no
está identificada**: el script corrige el resultado e imprime qué reparó. Sin `--aplicar` sólo
informa, y si el horneado no trae líneas no escribe nada. Qué mide y cómo guarda, en su encabezado.

Los mandos:

- la energía de cada luz, en su escena;
- `generate_probes_subdiv`, en el `LightmapGI`;
- el tamaño del texel, en la importación del modelo;
- la resolución de paredes y pisos, en la malla `almacen` de `estructura_del_almacen.tscn`.
  Evita que el filtrado del lightmap dibuje una franja verde al pie de la pared del depósito;
- la escala del texel de una malla chica (`gi_lightmap_texel_scale`), en
  `estructura_del_almacen.tscn`.

## La sombra de apoyo

Las góndolas son chapas finas y sus estantes de abajo quedan abiertos al pasillo. La luz entra
por ahí, y el piso al pie del mueble se hornea tan claro como el del pasillo: el mueble parece
flotar. Para oscurecerlo, el horneado con luz usa **obstáculos**: volúmenes que sólo existen
mientras se hornea. No están en `almacen.tscn`, ni en el `.lmbake`, ni en el juego.

- **De dónde salen.** De las mallas de las góndolas que la escena tiene al hornear
  (`addons/hornear/apoyo.gd`). Bajo cada estante que queda a menos de 30 cm del piso, un volumen
  del piso hasta su cara de abajo. No hay una tabla de coordenadas: si una góndola se mueve y se
  vuelve a hornear, su sombra la sigue. Los productos de exhibición, los portaprecios, los
  separadores finos, las mesas y las sillas no entran.
- **Por qué sólo durante el horneado.** Un obstáculo en la escena taparía la luz de lo que toma las
  sondas, y los productos se verían distintos. Las sondas del `.lmbake` son las del horneado sin
  obstáculos: la mercadería no cambia de brillo.
- **Cómo se aplica.** `hornear.py` hornea dos veces: el local de siempre y el mismo con
  obstáculos. Del segundo sólo se toma el atlas. `addons/hornear/mezclar_horneados.gd` lo mezcla
  con el primero, pieza por pieza, porque cada horneado ubica las mallas en el atlas a su manera.
  El resultado reemplaza a `almacen.exr`. El `.lmbake` es el del primero.
- **Dónde está el nivel.** `NIVEL_DE_APOYO`, en `lib/horneado.py`: de 0 a 1. Con 0 el atlas es el
  horneado de siempre y no hay segundo horneado. Con 1 es el horneado con obstáculos entero, que al
  usuario le pareció demasiado oscuro. Hoy vale el nivel que eligió jugando una build de prueba.
- **Qué no se commitea.** El segundo horneado (`almacen_con_apoyo.*`) lo borra el script al
  terminar, también si falla. Si algo falla a mitad de camino, `almacen.lmbake` y `almacen.exr`
  quedan como estaban.
- **Cada atlas se repara antes de mezclarlos**, y el resultado se repara de nuevo. Una raya
  mezclada deja de valer la mitad de sus vecinas y el reparador ya no la ve.
- **El horneado de la noche del corte de luz no cambia:** se hornea sin obstáculos.

## La oclusión de contacto de lo que se levanta

Lo que se mueve no tiene lightmap, así que la sombra de apoyo horneada no le sirve. La caja de
productos y el balde llevan una oclusión de contacto dinámica. Nada va horneado en el objeto: al
levantarlo el efecto se va. Es un prototipo, y el usuario decide jugándolo si se extiende.

`oclusion_de_contacto.gd` cuelga del objeto y lanza un rayo hacia abajo desde su base. Con lo que
encuentra hace dos cosas:

- **El objeto oscurece lo de abajo.** Una mancha negra con alfa sobre esa superficie, del tamaño
  de su huella (`sombra_de_contacto.gdshader`). Sigue la normal de la superficie y se corta en el
  borde de lo que lo sostiene. En Compatibility los `Decal` no funcionan: la mancha es un plano.
  Se apaga con la propiedad `activa` del nodo, que está en el grupo `oclusion_de_contacto`.
- **Lo de abajo oscurece al objeto.** Escribe en los materiales de la malla la altura de esa
  superficie. El shader (`oclusion_de_contacto.gdshaderinc`) oscurece las caras de abajo y el pie
  de los costados. Se apaga con `intensidad` en 0. Lo comparten el shader de
  los productos de la góndola y el de la manija del balde.

**Todo va en uniformes del material, nunca en `instance uniform`.** En la web (Compatibility)
el shader los recibe en cero: el efecto no se ve y ningún test de GDScript lo nota, porque
`get_instance_shader_parameter` devuelve lo que se escribió. Por eso cada caja y cada balde lleva
sus propios materiales.

Más lejos de `radio` de cualquier superficie no hay efecto. **El rayo corre mientras el objeto
se mueve y una vez al quedar quieto**: se entera por el aviso de que cambió su transformación.
Un objeto quieto no tira ninguno. Las dos propiedades del nodo, `radio` e `intensidad`, valen para el
objeto y para la mancha, y dejan el efecto al día al cambiarlas. Con el objeto apoyado, la mancha se
abre hacia afuera de su huella el mismo `radio` que el objeto se oscurece hacia arriba. Levantado, el
borde suma medio metro más por cada metro de altura.

## El horneado de la noche del corte de luz

La séptima noche se corta la luz. La oscuridad **no** apaga el `LightmapGI`: el local tiene un
segundo horneado, `almacen_sin_luz.lmbake` y `almacen_sin_luz.exr`. Lleva la luz de emergencia
sobre el tablero eléctrico y la de afuera. Al cortarse, `corte_de_luz.gd` le cambia los datos al
mismo `LightmapGI`; al restablecerse, le devuelve los de siempre. Cambian juntos los muebles y
las sondas de los productos.

- **Qué queda encendido:** la luz del grupo `luz_de_emergencia`, que es `LuzDelTablero`, y la
  luz de afuera. Las demás luces, los materiales emisivos de las lámparas, la niebla y los
  reflejos se apagan en tiempo real: no salen del horneado.
- **La luz de afuera la emiten los vidrios que dan a la calle.** En el horneado oscuro, el
  horneador les pone un material emisivo, el mismo del horneado con luz, y le saca el cielo al
  `LightmapGI` (`corte_de_luz.gd`).
  Las sondas guardan esa luz con su dirección: un producto que mira al ventanal recibe más que uno
  que mira adentro del local. El juego no lo ve: la escena no se guarda.
- **El cielo del horneado no sirve.** Alumbra también abajo del piso y arriba del techo. Desde ahí
  entra por las juntas de las paredes y por las sondas de afuera. El baño mostraba franjas claras
  al pie de las paredes. Lo que está cerca del piso tomaba la luz del cielo.
- **Una luz puntual afuera tampoco.** Una sonda guarda la luz que llega de las superficies, nunca
  la directa de una luz. El rebote llega desde el estante alumbrado, adentro del local.
- **La emergencia tiene más energía, alcance y ángulo** que los de su escena, para alumbrar el
  depósito alrededor del tablero. Los valores están en `corte_de_luz.gd`. Valen para este
  horneado y, mientras dura el corte, para el juego. Así las cajas y los objetos del depósito la
  reciben igual que los muebles. Durante el corte también da sombra, para que no atraviese la
  pared del depósito hacia las heladeras.
- **Qué se apaga lo dice un solo archivo**, `corte_de_luz.gd`. Lo usa el juego al cortar y lo
  usa el horneador al hornear, así que no pueden diferir.
- **Se hornea aparte**, con `python .claude/scripts/hornear.py --sin-luz`. Apaga el local en la
  copia del editor, no guarda la escena y deja el `.lmbake`, el `.exr` y su `.import`. Se
  commitean. Hay que volver a correrlo cuando cambia el modelo, una luz o el `LightmapGI`, igual
  que el horneado con luz.
- **El atlas viaja con 1024 px de lado, no con los 2048 que deja el horneador.** Es una imagen casi
  negra. Con 2048 px pesaba 16,8 MB en el export, y con 1024 px pesa 4,2 MB. Sin eso, el export web
  pasaba el techo de 150 MiB. `hornear.py --sin-luz` lo reduce solo, **después** de reparar las
  líneas. El reparador reconoce una línea por su huella de un texel. Al promediar bloques de 2 por 2
  esa huella se repartiría entre dos. El lado es `LADO_DEL_ATLAS_SIN_LUZ`, en `lib/horneado.py`. El
  paso es `blender/reducir_mapa_de_luz.py`. **El horneado con luz no se reduce.** El costo: el borde
  entre dos piezas vecinas del atlas pierde la mitad de su margen. Una pieza que toma luz de su
  vecina la mezcla un poco más.

## Qué lo verifica

`test/escenas/apoyo_del_horneado_test.gd` y `test/escenas/mezcla_de_horneados_test.gd`: de qué
caras salen los obstáculos y cómo se mezclan los dos atlas. `test_horneado.py` y `test_hornear.py`:
el nivel, el orden de los pasos y que un horneado a medias deje los archivos como estaban.
`test_reducir_mapa_de_luz.py`: que el atlas se reduzca por bloques, sin mezclar capas.

`test/escenas/iluminacion_horneada_test.gd`: que el `LightmapGI` tenga datos, y que ninguna
malla con GI estático se haya quedado afuera del horneado. También que ninguna hoja que abre
haya entrado. En headless el `.lmbake` se carga sin sondas. Por eso
`test/escenas/sondas_del_horneado.gd` las lee del archivo y las muestrea como el motor. Con eso,
`corte_de_luz_en_el_almacen_test.gd` verifica que la cara del ventanal reciba más luz que la de
adentro.

`test/escenas/luz_durante_el_corte_test.gd` clasifica cada objeto visible del local por de dónde
toma la luz (`luz_de_cada_objeto.gd`). Durante el corte, todo toma la luz del horneado, salvo lo
que la emite. Nada toma de las sondas más luz que las de adentro de su ambiente.
`test/escenas/listar_la_luz.gd` imprime esa clasificación.

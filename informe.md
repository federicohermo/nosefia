# Evidencia de #301: tacho grande junto a la entrada

Base de arte y escena: `e6a109833690c064c228cd04d9bc2d8c2ecf92c6`.
Implementación de arte: `abb895d82155a4e2017bf8be682a9925dcf6e377`.
Base del PR y convergencia: `cd5f93c38dfc140398759c52431bcece29985fd9` (#364); cabeza integrada `eb8ac2b2a5fca71166a7ea4330667e43fd863fd2`.
El diff e6..cd5 en modelos, escenas geométricas y horneado es vacío. Las capturas e
inventarios corresponden al arte aplicado sobre e6; el full se ejecuta con #364 incorporado.
Las primeras sondas se prepararon en `20ac5e21e2d52c5ac47b1b258c56a04448d7df9e`;
el diff de `assets/` y `src/` entre ambas bases es vacío. El carril avanzó limpio por ff-only
antes de escribir la fuente. La identidad de esos recursos hace aplicables las sondas
base/candidato medidas en 20ac; las sondas finales corresponden al arte aplicado sobre e6.

El plan completo con el destino medido se publicó en #301 antes de aplicar. Se conserva en
`plan-publicado-antes-de-aplicar.md`. La base histórica 48a5fa9 también medía 2,604476 m,
pero no se usó para restaurar arte ni como base del PR.

Corrección de procedencia: el plan previo decía que las sondas base/candidato se repetían en
e6. Corrieron en 20ac, antes del avance limpio a e6. Su validez para e6 se acredita con el
diff vacío de assets/src; las sondas finales sí corresponden al arte aplicado sobre e6.
La primera publicación y el plan previo se conservan; este informe y el issue actual corrigen
esa descripción sin inventar una corrida.

## Resultado medido

| Medida Godot | Base | Implementación |
|---|---|---|
| Origen tacho XYZ | (7,2723594; 0,50373936; 5,2499995) | (6,6123595; 0,50373936; 5,6999993) |
| Centro AABB tacho XZ | (7,2799993; 5,2499995) | (6,6199994; 5,6999993) |
| Centro AABB entrada XZ | (4,910000; 6,330000) | Igual |
| Distancia de centros XZ | **2,604475975 m, rojo** | **1,822360396 m, verde (≤2 m)** |
| Cápsula inicial | Sin intersecciones | Sin intersecciones |
| Celdas alcanzadas, paso 0,20 m | 3.697 | 3.696 |
| Acceso a cuatro puertas interiores/cabinas, ventanilla y mostrador | Seis puntos derivados de escena | Los mismos seis puntos y distancias |
| Cinco apoyos bajo el tacho | Altura de piso vigente | SueloSolido; separación 0,000000209 m |

La grilla nace en el spawn real y cada enlace barre la cápsula real con `cast_motion`.
Se aceptan superficies horizontales de la estructura al nivel del piso medido, incluida la
alfombra real de entrada; se rechazan muebles altos, exterior e intersecciones. La entrada
permanece trabada. Sólo se abren las puertas interiores para este recorrido.

`base-escena.json`, `candidato-escena.json` y `final-escena.json` incluyen las transformadas
mundiales/ancestros y las formas de la escena real. `comparacion-escena.json` certifica
1.751 Node3D, 793 estructurales: sólo cambian la transformada del tacho y las mundiales de sus
tres descendientes. Las formas locales, mallas y materiales son idénticos. No cambia el
contenedor del depósito, su tapa ni los dos tachos chicos.

## Fuente y pipeline

Sobre una copia externa del BLEND se midió el desplazamiento Blender (-0,66; -0,45; 0),
equivalente a Godot (-0,66; 0; +0,45). `acomodar.py` se ejecutó sobre esa copia externa y
conservó exactamente el tacho. La fuente vigente se guardó en su lugar; de 842 objetos sólo
cambió esa posición. Se conservan inventarios y hashes semánticos en `blend-*.json`.

Los scripts originales `exportar_modelo.py` y `hornear.py` ejecutaron sus pipelines completos.
Blender 5.2.1, Godot 4.7.2 y GPU NVIDIA RTX4050. El horneado tardó 6.580 ms y rellenó 952 de
1.254 sondas negras. El editor restauró las reserializaciones ajenas mediante el pipeline.
El diff de producto tiene sólo BLEND, GLB, huella, EXR y LMBake. No cambiaron escenas,
imágenes, productos, código, tests, specs, reglas ni interacciones.

`comparacion-glb.json`: 240 nodos, 295 superficies y 80 imágenes con los mismos píxeles.
POSITION y NORMAL tienen delta cero. Las únicas diferencias de serialización restantes son
UV: máximo 1,1920929e-7 / 4,7683716e-7. Se verifica mismo conjunto de nodos, jerarquía,
materiales, índices y atributos; sólo se permite la traslación del tacho. La huella se
contrasta con el SHA-256 del BLEND nuevo.

## Capturas

- `base-arranque.png` / `final-arranque.png`: misma posición y orientación de arranque.
- `base-desde-arranque-hacia-entrada.png` / `final-desde-arranque-hacia-entrada.png`: desde el
  mismo spawn hacia el tacho y la entrada.
- `base-posicion-y-sombras.png` / `final-posicion-y-sombras.png`: misma cámara fija, posición
  anterior y nueva. El piso anterior no conserva una huella y el tacho nuevo recibe luz.

El padre abrió las tres capturas finales y la referencia base y confirmó colocación/luz.
No se editaron imágenes para producir estas capturas: son cuadros renderizados del juego.

## Bolsas e interacción

`bolsas.json` conserva la ejecución del protocolo con cuerpos reales:

1. Soltar sobre el tacho: queda en (6,619992; 0,985438; 5,700003), sin contar y recogible.
2. Soltar cerca del contenedor: sin contar y recogible.
3. Soltar por la boca completamente abierta: sin contar y recogible.
4. Recuperarla y hacer izquierdo con tapa cerrada/girando: conserva la bolsa, cuenta cero.
5. Abrir con derecho: cuenta cero. Izquierdo con tapa completamente abierta: cuenta una y la
   retira de la mano. El tacho no pertenece a `interactuable` ni tiene `interactuar`.

## Diagnósticos y procedencia

Las sondas iniciales invalidadas se conservan bajo `incidentes/`, nunca como prueba verde:
`process_mode=DISABLED` retiraba cuerpos del mundo; otra versión redondeaba la grilla a una
celda ajena al spawn; otra omitía la alfombra como apoyo. Los scripts definitivos corrigen
esas premisas y afirman sus resultados. No se cambió ningún test del juego ni su umbral.

Las sondas headless cortas mostraron 24 ObjectDB/4 recursos al salir y el protocolo bolsas
29/6; los logs crudos se conservan. La sonda de apoyo con `--verbose` completó el mismo
marcador sin ObjectDB/recursos vivos y sólo anunció 38 StringNames del motor. La clasificación
del protocolo identifica 29 instancias de audio/playback y 6 recursos de audio: los WAV
de sacar/alzar bolsa, MUS_Tema1 y AMB_PROXIMIDAD_Neon con sus OggPacketSequence.
No se modifican recursos de audio. Se preservan el log verbose y clasificacion-bolsas.json;
no se afirma que ese apagado queda libre de recursos. La convergencia completa se publica
junto con sus logs, sin eliminar los diagnósticos por el código de salida 0.

La convergencia completa reproduce, en el mismo orden, las 58 líneas ERROR/WARNING de
`364-final-tests.log`: negativos deliberados de cableado, firma heredada 141 ObjectDB/100
recursos y dos diagnósticos PagedAllocator. No aparece ninguna línea nueva. Se publica el
log base de comparación y `clasificacion-convergencia.json`, además del log final íntegro.

`manifiesto.json` distingue hashes de los blobs publicados de hashes locales de procedencia.
El publicador vuelve a descargar cada archivo por una URL fijada al commit, compara sus
bytes con el blob remoto y verifica la cabeza final de `capturas/301`.

## Convergencia final

La primera corrida formal de verificar.py pasó **7/7 sin salteos en 738.3 s**.
El conteo inmediato confirma **228/228 suites y 1750/1750 casos**,
con cero errores, fallos, flaky, skipped y orphans de las suites. Se conservan los siete logs
crudos de nodos, importación y godot.log incluso en verde. La cabeza probada es eb8ac2b2.

Los intentos invalidados de sondas físicas se describen arriba y no se presentan como pruebas
verdes. El pipeline de producto pasó a la primera; la convergencia formal pasó a la primera.
La firma de apagado del runner se revisa aparte de los resultados de suites.

# Rendimiento de la reposición

Desde la raíz, con `GODOT_BIN` apuntando al ejecutable de Godot:

```powershell
& $env:GODOT_BIN --path . --rendering-method gl_compatibility --resolution 1000x750 test/performance/medir_reposicion.tscn
```

La escena termina sola y guarda `reports/rendimiento-reposicion.json`. Copiar el archivo antes
de repetir: cada ejecución lo reemplaza. No usar `--headless`, `--fixed-fps` ni ejecutar otros
tests a la vez. Para comparar cambios, repetir en el mismo equipo, con la misma configuración
y sin otras aplicaciones que carguen CPU o GPU. Hacer tres corridas y conservar las tres.

## Qué mide

Quince casos: 100, 500 y 2000 productos en estantes con MultiMesh, cayendo con cuerpos físicos
y en reposo sobre el piso. Cada caso del piso compara dibujo individual y agrupado con los
mismos cuerpos. Carga los modelos, sus colisiones y el grupo del piso desde el juego.
No cambia los cupos del juego.

La escena aislada usa cámara fija, luz sin sombras y una cuadrícula de productos sobre un
piso sólido. Calienta materiales un segundo. Luego toma muestras durante tres segundos.
En caída incluye los impactos y la transición al reposo. Para el caso de reposo espera cinco
segundos a que los cuerpos se duerman solos, como en el juego. No simula una pila compacta ni
la lógica de interacción.

El JSON incluye:

- Tiempo entre cuadros: mediana (p50), p95, p99 y máximo, en milisegundos.
- Tiempo de física p95, muestreado por paso físico.
- Mediana de llamadas de dibujo y máximo de cuerpos físicos activos.
- Máximo de memoria estática del proceso, en MiB. Incluye la herramienta; no es RAM total ni VRAM.
- Cantidad de muestras, fecha, commit, Godot, CPU, GPU, sistema, resolución y renderizador.

VSync y el límite de FPS se desactivan durante la medición. Un tiempo menor es mejor.
El p95 deja por debajo al 95 % de las muestras. No se debe convertir este resultado en una
promesa de FPS del local completo o del navegador.

## Qué verifica la CI

Comprueba cantidades, uso de colisiones y cálculo de percentiles. No ejecuta la medición de
GPU ni exige tiempos iguales en equipos distintos. Las métricas de memoria pueden no estar
disponibles en una exportación release; el informe identifica la compilación usada.

Las métricas del motor se describen en la
[documentación de Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html).

## Medición del 13 de septiembre de 2026

Tres corridas en Windows, Ryzen 7 7435HS, RTX 4050 Laptop, Godot 4.7.2 debug,
Compatibility y 1000 × 750. No se ejecutaron otros tests a la vez. El editor seguía abierto;
la ventana de medición estaba fuera de pantalla. Son referencias locales, no un equipo aislado.

Mediana del p95 entre cuadros de las tres corridas, en milisegundos:

| Productos | Estantes | Cayendo | En reposo |
|---|---:|---:|---:|
| 100 | 0,99 | 1,24 | 1,57 |
| 500 | 1,02 | 2,87 | 2,13 |
| 2000 | 0,94 | 16,83 | 5,08 |

Los estantes mantuvieron ocho llamadas de dibujo. En el piso hubo una por unidad.
El p95 con 2000 cuerpos cayendo varió entre 14,92 y 17,29 ms. Los casos de reposo registraron
cero cuerpos activos. La variación entre corridas impide interpretar diferencias pequeñas
como mejoras.

Los [JSON originales](../performance/reposicion-2026-09-13.json) conservan las métricas,
el commit base, la existencia de cambios locales y el hash del script medido.

## Comparación del piso con la misma física

Tres corridas adicionales, con la misma configuración: 45 casos. El prototipo medido quedó
registrado en `4b0270d` y se trasladó al juego. Cada producto conserva su cuerpo, forma convexa
y CCD. La sincronización de instancias está incluida en los tiempos.

Mediana del p95 entre cuadros, en milisegundos:

| Productos | Cayendo individual | Cayendo agrupado | Reposo individual | Reposo agrupado |
|---|---:|---:|---:|---:|
| 100 | 1,20 | 1,10 | 1,09 | 0,93 |
| 500 | 2,63 | 1,44 | 2,46 | 1,14 |
| 2000 | 16,95 | 3,36 | 5,19 | 1,58 |

Con 2000 cuerpos cayendo, el p99 bajó de 27,44 a 18,44 ms. En reposo bajó de 5,94 a 4,84 ms.
Con 100 cuerpos cayendo, el p99 fue prácticamente igual: 1,59 y 1,62 ms.

El dibujo agrupado mantuvo ocho llamadas, pero **no redujo el trabajo de física**: con 2000
cuerpos cayendo, el p95 del monitor de física subió de 18,76 a 28,27 ms. En reposo subió de
0,29 a 5,49 ms por la revisión de cuerpos y contornos. No sumar ni restar estos percentiles
entre sí. El beneficio medido está en el tiempo entre cuadros, sobre todo con muchas unidades;
no significa que cualquier cantidad de cuerpos activos sea viable.

Los [JSON de la comparación](../performance/piso-multimesh-2026-09-13.json) conservan también
los p99, máximos y cantidades de pasos físicos. La integración mantiene la malla individual
del producto enfocado para conservar su contorno.

## Medición en la web, con la CPU frenada

El juego se publica en la web, y el escritorio no dice cómo corre ahí. Este comando abre la URL
publicada en un Chrome de verdad y mide el tiempo entre cuadros con la CPU frenada:

```bash
npm install --no-save playwright
node .github/scripts/medir_en_navegador.mjs https://nosefia.vercel.app
node .github/scripts/medir_en_navegador.mjs https://nosefia.vercel.app 1,4,6 reports/web.json
```

La ventana tiene que quedar a la vista: un navegador no dibuja una pestaña tapada. Mide desde
donde arranca el jugador, que muestra el local entero y es la vista más cara.

- **Simula la CPU y no la GPU.** Frenar 4 veces es de guía una notebook de oficina de hace unos
  años, y 6 veces una máquina floja. Una GPU floja se mide en una máquina que la tenga.
- **No es un gate.** El número depende del equipo. Sirve para comparar un cambio contra el
  anterior en la misma máquina.
- **Con la CPU frenada el ruido es grande**: dos corridas iguales a 6 veces dieron 33 y 45 FPS.
  Hacer tres corridas y mirar la mediana.

Referencia del 2026-09-21, v5.1.0, Ryzen 7 7435HS y RTX 4050, quieto mirando el local:

| CPU | FPS | p50 | p95 |
|---|---:|---:|---:|
| Normal | 244 | 3,9 ms | 5,9 ms |
| 4 veces más lenta | 82 | 11,6 ms | 30,5 ms |
| 6 veces más lenta | 33 a 45 | 21 a 31 ms | 38 a 48 ms |

## Medición de las luces

```powershell
& $env:GODOT_BIN --path . --rendering-method gl_compatibility --resolution 1536x760 test/performance/medir_luces.tscn
```

La escena termina sola y guarda `reports/rendimiento-luces.json`. Carga el local entero, apaga
las luces del juego y prueba luces omni, de foco y de área: 1, 2, 4, 8 y 16, con sombra y sin
sombra. Las cuelga del techo, repartidas, con alcance para alumbrar todo lo que se ve. Mide
desde donde arranca el jugador. De cada caso guarda el tiempo de GPU, el de CPU de dibujo, el
tiempo entre cuadros y las llamadas de dibujo.

**El tiempo de GPU crece con los píxeles.** Con el doble de resolución por lado, el costo de
las luces se multiplica por tres. Comparar siempre con la misma resolución.

### Referencia del 2026-09-21

Ryzen 7 7435HS, RTX 4050 Laptop, Godot 4.7.2 debug, Compatibility, 1536 × 760. El local sin
ninguna luz cuesta 0,21 ms de GPU y 88 llamadas de dibujo. Las ocho luces del juego —seis de
área y dos omni con sombra— cuestan 1,10 ms y 104 llamadas.

GPU en milisegundos, sin sombra:

| Luces | Omni | Foco | Área |
|---:|---:|---:|---:|
| 1 | 0,25 | 0,26 | 0,34 |
| 2 | 0,26 | 0,31 | 0,48 |
| 4 | 0,29 | 0,31 | 0,77 |
| 8 | 0,42 | 0,48 | 1,45 |
| 16 | 0,43 | 0,47 | 1,50 |

Con sombra, omni: GPU en milisegundos y llamadas de dibujo.

| Luces | GPU | Llamadas |
|---:|---:|---:|
| 1 | 0,25 | 88 |
| 2 | 0,34 | 133 |
| 4 | 0,48 | 243 |
| 8 | 0,85 | 494 |
| 16 | 0,89 | 548 |

Lo que dicen los números:

- **Una luz de área cuesta cinco veces una omni**: 0,15 ms contra 0,03 ms. Las dos escalan
  derecho con la cantidad.
- **Después de 8 no crece porque no se dibujan más.** Compatibility alumbra cada objeto con 8
  luces como mucho, y 32 en toda la vista. La novena luz sobre el piso no cuesta nada porque no
  alumbra. Los dos topes son ajustes del proyecto, y subirlos sube el costo.
- **La sombra se paga en llamadas de dibujo, y eso es CPU.** Cada luz con sombra vuelve a
  dibujar todo lo que alumbra: acá, unas 50 llamadas por luz. En la web una llamada cuesta
  0,012 ms, así que ocho luces con sombra son unos 5 ms de CPU por cuadro.
- **Una luz de área no da sombra en Compatibility**: prenderla no cambia nada. Por eso
  atraviesa las paredes.
- **No hay un recurso que agrupe luces como `MultiMesh` agrupa mallas.** El agrupado de luces
  es de Forward+, que no corre en la web. Lo que saca el costo es hornear la luz en un lightmap.

Los [JSON originales](../performance/luces-2026-09-21.json) conservan todos los casos.

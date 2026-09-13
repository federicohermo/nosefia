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
mismos cuerpos. Carga los ocho modelos, sus colisiones y el grupo del piso desde el juego.
No cambia los cupos del juego.

La escena aislada usa cámara fija, luz sin sombras y una cuadrícula de productos sobre un
piso sólido. Calienta materiales un segundo. Luego toma muestras durante tres segundos.
En caída incluye los impactos y la transición al reposo. Para el caso de reposo espera cinco
segundos y duerme los cuerpos. No simula una pila compacta ni la lógica de interacción.

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
[documentación de Performance](https://docs.godotengine.org/en/4.5/classes/class_performance.html).

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

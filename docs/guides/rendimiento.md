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

Nueve casos: 100, 500 y 2000 productos en estantes con MultiMesh, cayendo con cuerpos físicos
y en reposo sobre el piso. Carga los ocho modelos y sus colisiones desde la reposición real.
No cambia los cupos del juego.

La escena aislada usa cámara fija, luz sin sombras y una cuadrícula de productos sobre un
piso sólido. Calienta materiales un segundo. Luego toma muestras durante tres segundos.
En caída incluye los impactos y la transición al reposo. Para el caso de reposo espera cinco
segundos y duerme los cuerpos. No simula una pila compacta ni la lógica de interacción.

El JSON incluye:

- Tiempo entre cuadros: mediana (p50) y p95, en milisegundos.
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

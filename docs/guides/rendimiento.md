# Rendimiento

Cómo se mide y dónde queda el resultado. Los números no van en este doc: van al PR que los
usa, junto con el equipo y el commit.

## Dónde queda el resultado

Cada `test/performance/medir_*.gd` escribe su JSON en `reports/`, que está en `.gitignore`. Una
corrida reemplaza el archivo de la anterior: copiarlo antes de repetir. El JSON registra el
commit, el motor, el equipo y el renderizador de la corrida.

## Cómo se corre una medición de escritorio

Desde la raíz, con `GODOT_BIN` declarada:

```powershell
& $env:GODOT_BIN --path . --rendering-method gl_compatibility --resolution 1000x750 test/performance/medir_reposicion.tscn
& $env:GODOT_BIN --path . --rendering-method gl_compatibility --resolution 1536x760 test/performance/medir_luces.tscn
```

La escena termina sola. Los casos los declaran las constantes de su `.gd`. Las métricas son las
claves del JSON que escribe.

- No usar `--headless` ni `--fixed-fps`. No correr otros tests a la vez.
- Para comparar dos cambios, medir en el mismo equipo, con la misma resolución y sin otras
  aplicaciones que carguen la CPU o la GPU.
- Hacer tres corridas y comparar la mediana. La variación entre corridas tapa las diferencias
  chicas.
- El tiempo de GPU crece con los píxeles. Comparar siempre con la misma resolución.
- No convertir un resultado en una promesa de FPS del local completo o del navegador.

Las métricas del motor se describen en la
[documentación de Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html).

## Qué verifica la CI

Cada escena de medición tiene su `*_test.gd` al lado. Comprueba cantidades, uso de colisiones y
cálculo de percentiles. No corre la medición de GPU ni exige tiempos iguales en equipos
distintos.

## Medición en la web, con la CPU frenada

El escritorio no dice cómo corre el juego publicado. `.github/scripts/medir_en_navegador.mjs`
abre la URL en un Chrome de verdad y mide el tiempo entre cuadros con la CPU frenada. Cómo se
corre, qué simula y qué no, está en su encabezado. El último argumento es el JSON de salida:
ponerlo en `reports/`.

- **La ventana tiene que quedar a la vista.** Un navegador no dibuja una pestaña tapada.
- **No es un gate.** El número depende del equipo. Sirve para comparar un cambio contra el
  anterior en la misma máquina.
- **Con la CPU frenada el ruido es grande.** Hacer tres corridas y mirar la mediana.

## Lo que ya se sabe de las luces

- Compatibility alumbra cada objeto con un tope de luces, y la vista entera con otro. Los dos
  topes son ajustes del proyecto, y subirlos sube el costo.
- Cada luz con sombra vuelve a dibujar todo lo que alumbra. La sombra se paga en llamadas de
  dibujo, y eso es CPU.
- Una luz de área no da sombra en Compatibility, y atraviesa las paredes.
- Ningún recurso agrupa luces como `MultiMesh` agrupa mallas. El agrupado de luces es de
  Forward+, que no corre en la web. Lo que saca el costo es hornear la luz:
  [iluminación](./iluminacion.md).

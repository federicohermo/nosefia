# Rendimiento

Cómo se mide y dónde queda el resultado. Los números no van en este doc: van al PR que los
usa, junto con el equipo y el commit. La excepción es la carga en la web, que registra su base
y su medición final.

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

## La carga en la web

`.github/scripts/medir_la_carga.mjs` mide tres tiempos desde la navegación: el overlay de
Godot fuera, el aviso `[carga] menú visible` y el aviso `[carga] almacén en pantalla`. Elige
«Nuevo juego» apenas ve el primer aviso. Hace tres corridas con el caché vacío y da la mediana.
Mide un export local, servido con los headers de `vercel.json`:

```powershell
& $env:GODOT_BIN --headless --path . --export-release "Web" export/web/index.html
python .github/scripts/servir_export.py export/web 8060
node .github/scripts/medir_la_carga.mjs http://localhost:8060 reports/carga.json
```

- **El directorio del export tiene que existir antes.** Sin él, el export falla y devuelve 0.
- **Un reporte de gdUnit4 en `reports/` entra al `.pck`.** El export incluye todo recurso del
  proyecto. Borrar `reports/` antes de exportar para medir.

Medido el 2026-09-27 en una notebook con AMD Ryzen 7 7435HS, NVIDIA GeForce RTX 4050 Laptop
y 24 GB, con Chrome. Las dos filas se midieron una detrás de la otra. Mediana de tres
corridas, en milisegundos:

| Medición | Overlay fuera | Menú visible | Almacén en pantalla |
|---|---|---|---|
| Base: el almacén carga al elegir «Nuevo juego» | 1051 | 1020 | 2426 |
| Final: el almacén carga detrás del menú | 1039 | 1003 | 2828 |

- **El menú aparece igual.** La carga en segundo plano no lo demora.
- **Con el clic inmediato, entrar tarda unos 400 ms más.** La carga en otro hilo tarda más que
  en el principal. Mientras tanto, el jugador ve la pantalla «Cargando...».
- **Con el almacén ya cargado, entrar tarda 807 ms desde el clic.** Sin la carga en segundo
  plano, 1257 ms. Es el caso de un jugador que se queda en el menú más de dos segundos. Es una
  sola corrida de cada lado, con el clic cinco segundos después del aviso del menú.
- **Mientras carga, el menú sigue dibujando.** En los tres segundos después del aviso del menú,
  el peor hueco entre dos cuadros del navegador fue de 9 ms.

## Lo que ya se sabe de las luces

- Compatibility alumbra cada objeto con un tope de luces, y la vista entera con otro. Los dos
  topes son ajustes del proyecto, y subirlos sube el costo.
- Cada luz con sombra vuelve a dibujar todo lo que alumbra. La sombra se paga en llamadas de
  dibujo, y eso es CPU.
- Una luz de área no da sombra en Compatibility, y atraviesa las paredes.
- Ningún recurso agrupa luces como `MultiMesh` agrupa mallas. El agrupado de luces es de
  Forward+, que no corre en la web. Lo que saca el costo es hornear la luz:
  [iluminación](./iluminacion.md).

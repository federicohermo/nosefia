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
«Nuevo juego» apenas ve el primer aviso. Hace tres corridas con contextos HTTP nuevos dentro
del mismo Chrome. El navegador puede conservar su caché de shaders entre corridas. No son tres
cargas frías. El JSON conserva cada corrida y la mediana, que mezcla la primera con las siguientes.
Mide con la sincronización habitual de cuadros y sin limitar la CPU. Usa un export local,
servido con los headers de `vercel.json`:

```powershell
& $env:GODOT_BIN --headless --path . --export-release "Web" export/web/index.html
python .github/scripts/servir_export.py export/web 8060
node .github/scripts/medir_la_carga.mjs http://localhost:8060 reports/carga.json
```

- **El directorio del export tiene que existir antes.** Sin él, el export falla y devuelve 0.

Para medir sin dejar Chrome a la vista, agregar `--sin-ventana` después de la ruta del JSON:

```powershell
node .github/scripts/medir_la_carga.mjs http://localhost:8060 reports/carga.json --sin-ventana
```

El script registra el renderizador de GPU y rechaza la medición sin ventana si Chrome usa
renderizado por software o no identifica la GPU. Este modo mide la carga, no la presentación
de una ventana ni los FPS durante la partida. Comparar corridas con el mismo modo y renderizador.

**El aviso del almacén sale cuando el jugador lo ve**, al final del calentamiento de shaders.
Los tiempos de carga de `medir_en_navegador.mjs` usan cuadros sin límite para medir FPS.
No compararlos con las esperas de `medir_la_carga.mjs`.

## Los shaders en la web

Compatibility compila programas GL al usar los shaders y sus variantes. En la web, esa
compilación puede frenar el navegador. Por eso el almacén se calienta detrás de la pantalla de
carga. El calentamiento dibuja los objetos que pueden aparecer en la partida, incluidos los
ocultos. Excluye las mallas de referencia que ya tienen un reemplazo en producción.

Godot 4.7.2 declara cuatro variantes predeterminadas: color y profundidad, cada una con y sin
instancing. Las de color incluyen todos los tipos de luces. Lo declara
[`scene.glsl` del motor](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/shaders/scene.glsl).
Compartir un shader evita duplicar sus programas predeterminados. No demuestra que todas las
variantes posibles ya se hayan compilado.

Medido el 2026-09-28 en la misma notebook, con Chrome. Es el tiempo desde el clic en «Nuevo
juego», con el almacén ya cargado, hasta el aviso del almacén:

| Visita | Sin calentar | Con el calentamiento |
|---|---|---|
| Primera, con el caché vacío | 27–29 s, con la barra llena y la imagen congelada | 33 s, con la barra avanzando |
| Segunda, con el caché de Chrome | 3,5 s | 3,9 s |

Estos tiempos y los siguientes conteos son históricos. No describen el motor ni la escena
actuales.

- En el recorrido medido el 2026-09-28 no se registraron compilaciones después de entrar con
  calentamiento. Sin calentamiento, el primer cuadro compilaba 88 programas y aparecían otros
  durante el juego. El resultado cubre ese recorrido, no todos los gestos posibles.
- En aquella corrida, los 20 programas más caros correspondían a variantes predeterminadas
  que no se usaban después. Cada una costaba alrededor de 1,1 s.
- La prueba de aquella fecha no registró una mejora al bajar `max_lights_per_object` a 2 y
  `max_renderable_lights` a 16. No demuestra que esos ajustes sean irrelevantes en otras
  versiones o escenas.
- El caché de Chrome puede reducir la espera, pero no reemplaza al calentamiento. Una
  actualización del navegador o del driver puede invalidarlo.

## Medición del 2026-10-05

Comparación del export anterior con el export que comparte shaders de contornos, agua y
manchas. El calentamiento excluye las referencias reemplazadas y el PCK excluye capturas y
exports anteriores. La comparación conserva la configuración de luces y las texturas.

Ambos exports usan Godot 4.7.2, Chrome 154 y una RTX 4050 mediante ANGLE D3D11, a 1536×760.
Se midió sin ventana, con la sincronización habitual de cuadros y sin limitar la CPU.
Se alternaron los dos exports en tres pares. Cada corrida abrió Chrome con un perfil nuevo.
No se limpió la caché del driver.

Los tiempos van desde el clic en «Nuevo juego» hasta `[carga] almacén en pantalla`:

| Par | Anterior | Final |
|---|---|---|
| 1 | 64,913 s | 58,054 s |
| 2 | 64,176 s | 55,706 s |
| 3 | 62,831 s | 55,202 s |
| Mediana | 64,176 s | 55,706 s |

La mediana baja 8,470 s, un 13,2 % en este equipo y estas condiciones. El PCK pasa de
49.631.148 a 43.589.692 bytes: 6.041.456 bytes menos, un 12,2 %.

Una prueba separada del export final conserva el mismo Chrome y abre contextos HTTP nuevos.
La primera entrada tarda 57,254 s desde el clic. Las siguientes tardan 6,506 y 6,337 s.
Esos tiempos con caché compartida se informan aparte de la comparación con perfiles nuevos.

La validación pasa 60 de 60 casos en 11 suites y los seis nodos restantes de verificación.
Las comparaciones de GPU cubren 23 poses de agua, manchas y contornos, con diferencia RGB cero.
Esas poses verifican la conservación de la imagen en los casos comparados. No cubren todas
las vistas posibles.

## Lo que ya se sabe de las luces

- Compatibility limita las luces de cada tipo por objeto y por vista. Los dos topes son
  ajustes del proyecto, y subirlos sube el costo.
- Reducir `rendering/limits/opengl/max_lights_per_object` puede cambiar la imagen del baño:
  los focos se superponen sobre útiles, agua y hojas móviles que no tienen lightmap. Una mejora
  de carga exige comparar también su iluminación desde distintas posiciones.
- Cada luz con sombra vuelve a dibujar todo lo que alumbra. La sombra se paga en llamadas de
  dibujo, y eso es CPU.
- Una luz de área no da sombra en Compatibility, y atraviesa las paredes.
- Ningún recurso agrupa luces como `MultiMesh` agrupa mallas. El agrupado de luces es de
  Forward+, que no corre en la web. Lo que saca el costo es hornear la luz:
  [iluminación](./iluminacion.md).

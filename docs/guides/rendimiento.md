# Rendimiento

Cómo se mide y dónde queda el resultado. Los números no van en este doc: van al PR que los
usa, junto con el equipo y el commit. La excepción es la carga en la web, que registra su base
y su medición final.

## Dónde queda el resultado

Un escenario de `test/performance/` que corre en escritorio escribe su JSON en `reports/`, que
está en `.gitignore`. Una corrida reemplaza el archivo de la anterior: copiarlo antes de repetir.
El JSON registra el commit, el motor y el equipo de la corrida. El escenario que dibuja registra
también el renderizador.

En la web no existe `res://reports/`. Ahí el escenario imprime su informe, y lo guarda el script
de `.github/scripts/` que abre el export.

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

## Comparar dos revisiones de un escenario en la web

`.github/scripts/exportar_escenario.py` exporta una revisión con un escenario como escena
principal, en una copia aislada. Cómo arma la copia está en su encabezado. La plantilla web
tiene que estar preparada.

```powershell
python .github/scripts/exportar_escenario.py <base> res://test/performance/<escenario>.tscn <carpeta>/base
python .github/scripts/exportar_escenario.py <propuesta> res://test/performance/<escenario>.tscn <carpeta>/propuesta
python .github/scripts/servir_export.py <carpeta>/base/web 8060
node .github/scripts/recoger_informe.mjs http://localhost:8060 reports/base-1.json
```

`recoger_informe.mjs` guarda el informe que el escenario imprime. El protocolo entre los dos
está en su encabezado. Un escenario con runner propio usa ese runner.

- **La copia lleva sólo lo commiteado.** Commitear primero el escenario y después el cambio: son
  las dos revisiones que se comparan.
- **Dos cargas del mismo export no miden igual.** Medir primero la base contra sí misma. Esa
  diferencia es el ruido entre cargas, y un cambio menor que ella no se demostró.
- **Un caso de control en la misma carga cancela ese ruido.** Dividir cada caso por el control
  de su carga, y comparar los cocientes.
- **Alternar el orden en cada ronda:** base y propuesta, después propuesta y base.
- **Medir el tiempo de GPU con `--sin-limite-de-cuadros`.** Con la sincronización puesta, el
  mismo export mide varias veces más en unas cargas que en otras.
- **Mirar que el puerto esté libre antes de servir.** Windows deja a dos servidores escuchar el
  mismo puerto, y el navegador cae en cualquiera de los dos.
- **Playwright se instala en el checkout principal, no en un worktree.** Node lo encuentra
  subiendo. Con `node_modules/` adentro de un árbol sin caché de importación, Godot se cayó al
  importar.

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
python .github/scripts/preparar_plantilla_web.py
& $env:GODOT_BIN --headless --path . --export-release "Web" export/web/index.html
python .claude/scripts/verificar_export.py export/web
python .github/scripts/preparar_plantilla_web.py --verificar-export export/web
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

### Los programas que enlaza la carga

Cada corrida informa también dos conteos, tomados entre el clic y el aviso del almacén:

- **`programas`:** las llamadas a `linkProgram` de WebGL2.
- **`fuentes_distintas`:** los pares distintos de fuentes de vértices y de fragmentos entre
  esos programas.

Dos programas con el mismo par cuestan una sola compilación: Chrome reutiliza la primera. La
resta de los dos campos son enlaces repetidos. Las tres corridas informan los mismos conteos:
el juego pide los mismos programas con la caché de Chrome llena.

Medido el 2026-10-07 sobre `staging`, sin ventana y con un perfil nuevo por llamada. Usa
Chrome 154 y una RTX 4050 mediante ANGLE D3D11, a 1536×760. El importador del modelo deja a los
seis materiales con relieve del depósito con dos caras y con la rugosidad en el canal verde.
Antes repartían tres combinaciones de caras y de canal, y ahora comparten una:

| Export | `programas` | `fuentes_distintas` |
|---|---|---|
| `staging` | 68 | 66 |
| Con los materiales del depósito unificados | 64 | 60 |

`desdeElClic` de la primera corrida, en tres pares alternados:

| Par | `staging` | Unificados |
|---|---|---|
| 1 | 34,781 s | 31,002 s |
| 2 | 32,968 s | 29,881 s |
| 3 | 33,334 s | 32,163 s |

La menor diferencia de un par es 1,171 s. La dispersión de cada export es mayor: 1,813 y
2,282 s. Los pares no demuestran una mejora de tiempo: el cambio baja programas.

## La memoria de texturas en la web

`.github/scripts/medir_memoria_de_texturas.mjs` hace el inventario de las texturas de WebGL que
el juego tiene vivas en dos momentos: al aviso `[carga] menú visible` y al aviso
`[carga] almacén en pantalla`. Usa el mismo export local que la medición de carga:

```powershell
python .github/scripts/servir_export.py export/web 8060
node .github/scripts/medir_memoria_de_texturas.mjs http://localhost:8060 reports/memoria-texturas.json --sin-ventana
```

Cada fase del JSON lista sus texturas con dimensiones, formato, mips, capas y bytes estimados,
y da el total en bytes y en MiB. El PCK y el WASM van aparte, en `export_en_disco`, con sus
bytes y su SHA-256: son tamaño en disco, no memoria de texturas. El JSON registra también el
motor, el navegador, el renderizador y la resolución.

- **Es el almacenamiento lógico que el juego le declara a WebGL.** Suma cada nivel, capa y
  cara. Incluye las texturas que se usan como destino de renderizado.
- **Excluye** los renderbuffers, las copias en CPU y la memoria del driver.
- **Menos bytes lógicos no prueban menos VRAM física.** El driver puede guardar un formato en
  otro más grande: ANGLE con Direct3D 11 puede guardar RGB8 como RGBA8, según su
  [tabla de formatos](https://chromium.googlesource.com/angle/angle/+/d9c1710779d15239f3882b2bdbd5e65db369b04e/src/libANGLE/renderer/d3d/d3d11/texture_format_table_autogen.cpp).
- **Un formato que el script no conoce queda sin bytes**, y no se suma como cero. La fase sale
  con `cobertura_completa` en falso. Lo mismo pasa con un contexto WebGL perdido.
- **Rechaza la corrida** si falta un aviso, si el juego escribe un error o si Chrome dibuja por
  software. Sale con código distinto de cero y no escribe el JSON.
- **No es un gate.** Los totales cambian con el arte. Sirven para comparar un export con otro.

Lo que decide vive en `.github/scripts/lib/memoria_de_texturas.mjs`. Sus casos no corren en
`verificar.py` ni en la CI. Se corren a mano:

```powershell
node --test .github/scripts/tests/memoria_de_texturas_test.mjs
```

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

### Comparación de la plantilla web

El parche del repo evita compilar variantes predeterminadas que la partida no solicita.
Modifica `_initialize_version` sólo bajo `WEB_ENABLED`. Conserva la compilación síncrona al
primer uso. El camino nativo queda intacto. La referencia es
[`shader_gles3.cpp` del commit fijado](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/gles3/shader_gles3.cpp).

Ese parche no enlazaba en paralelo: lo que se mide en esta sección es anterior. Hoy la plantilla
enlaza los shaders de escena con `KHR_parallel_shader_compile`. Está medido en
[el enlace en paralelo](#el-enlace-en-paralelo).

Se comparan la plantilla base y la modificada con el mismo PCK de 43.589.692 bytes.
Los exports conservan los recursos, la iluminación y las texturas. Se usa Chrome 154,
RTX 4050 mediante ANGLE D3D11, 1536×760, sincronización habitual de cuadros y CPU sin límite.
Las cuatro corridas alternan base/modificada y modificada/base. Cada una abre un perfil nuevo.
No se limpia la caché del driver. Estas mediciones preceden la corrección posterior del
calentamiento.

Los tiempos van desde el clic en «Nuevo juego» hasta el aviso del almacén:

| Par | Base | Modificada |
|---|---|---|
| 1 | 64,823 s | 29,305 s |
| 2 | 64,974 s | 26,955 s |
| Mediana | 64,8985 s | 28,130 s |

La mediana baja un 56,65 % en estas condiciones. El PCK idéntico permite comparar el cambio
de plantilla sin atribuir la mejora a un paquete más pequeño.

Una prueba del export actual conserva el mismo Chrome y abre contextos HTTP nuevos.
La primera entrada tarda 33,586 s desde el clic. Las siguientes tardan 5,761 y 5,882 s.
El navegador comparte caché entre esas entradas. Un perfil nuevo tampoco garantiza una GPU
sin caché del driver.

La validación del calentamiento pasa 14 de 14 casos de gdUnit4. La validación de GPU cubre
15 de 15 casos con jugador, útiles, productos y agua. El recorrido medido no registra llamadas
GL superiores a 50 ms después del calentamiento. Esa muestra no cubre todos los equipos ni
todas las variantes posibles de la partida.

El preset de release usa esta plantilla. La preparación y las comprobaciones antes de exportar
se describen en [despliegue](../infra/despliegue.md).

Después de integrar el preset, se repite la medición sin nuestros tests en ejecución.
El control conserva el mismo PCK y JavaScript del export nuevo. Sólo cambia el WASM y su
tamaño declarado en el HTML. Las dos mediciones son secuenciales, sin alternar el orden.
Conservan Chrome, GPU, resolución y sincronización. No se controlan los otros procesos de
la máquina ni se limpia la caché del driver.

La primera entrada tarda 141,381 s con la plantilla base y 77,699 s con la optimizada.
Las siguientes tardan 9,225 y 8,664 s con la base, y 17,501 y 6,488 s con la optimizada.
Cada grupo conserva su Chrome y puede compartir caché de shaders. Estos datos confirman
una carga menor en la primera entrada de esa comparación. No reproducen los tiempos absolutos
anteriores ni demuestran la causa de su variación. Tampoco prueban una ventaja en cada carga
con caché.

Los datos crudos quedan en `reports/plantilla-integrada-base-carga.json` y
`reports/plantilla-integrada-carga-sin-tests.json`. El resumen queda en
`reports/plantilla-integrada-resumen.json`.

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

## El enlace en paralelo

La plantilla web enlaza los programas de los shaders de escena con la extensión
[`KHR_parallel_shader_compile`](https://registry.khronos.org/webgl/extensions/KHR_parallel_shader_compile/).
El motor pide el programa y no consulta su estado: esa consulta es la que frena el cuadro. Al
empezar cada cuadro pregunta qué programas terminaron. Una superficie con su programa en cola
no se dibuja ese cuadro.

- **Sólo cambian los shaders de escena.** El lienzo, el cielo, las copias y los efectos compilan
  al primer uso, como antes.
- **Sin la extensión, el motor compila como antes**, y el calentamiento destapa como antes.
- **La plantilla publica la cola** en `window.godot_programas_en_cola`. Sin la extensión, queda
  sin definir.
- **Un programa que falla sale de la cola.** El motor lo compila otra vez en el momento, e
  informa el error con su fuente.

El calentamiento lee esa cola. Cada pasada destapa todos sus objetos en un cuadro, y las tres
pasadas se enlazan a la vez. El aviso del almacén espera a que la cola quede vacía.

**Entrar con la cola ocupada frena el juego.** Lo que compila al primer uso espera detrás de la
cola. En una sonda sin esa espera, dos consultas de `getShaderParameter` tardaron 1.094 y 955 ms
al entrar, con 35 programas en cola. En la base, las dos consultas de ese momento suman 4 ms.

`medir_la_carga.mjs` informa `cuadro_mas_largo_ms` en cada corrida. Es el mayor tiempo entre dos
`requestAnimationFrame` seguidos, desde el clic hasta el aviso del almacén. Con
`--sin-enlace-en-paralelo`, la página niega la extensión y la plantilla compila como antes:

```powershell
node .github/scripts/medir_la_carga.mjs http://localhost:8060 reports/carga.json --sin-ventana --sin-enlace-en-paralelo
```

### Medición del 2026-10-07

La base es `staging` en `1ab2a058`, con la plantilla anterior. La rama cambia la plantilla y el
calentamiento. Las dos usan Godot 4.7.2, Chrome 154 sin ventana y una RTX 4050 mediante ANGLE
D3D11, a 1536×760. El procesador es un Ryzen 7 7435HS de 16 hilos.

Se midieron tres pares alternados: base y rama, rama y base, base y rama. Cada medición abre
Chrome con un perfil nuevo y compara su primera corrida. No se limpió la caché del driver. La
máquina estaba en uso: la CPU marcaba entre el 4 y el 37 % antes de cada medición.

| Par | Base, desde el clic | Rama, desde el clic | Base, cuadro más largo | Rama, cuadro más largo |
|---|---|---|---|---|
| 1 | 33,145 s | 12,393 s | 2.292 ms | 1.188 ms |
| 2 | 42,985 s | 11,875 s | 6.715 ms | 1.153 ms |
| 3 | 32,194 s | 11,599 s | 2.340 ms | 1.090 ms |

- **La segunda y la tercera corrida** comparten la caché de Chrome. Tardan entre 5,164 y 5,513 s
  en la base, y entre 2,735 y 3,068 s en la rama.
- **Una tanda anterior del mismo día** midió 43,395, 39,425 y 40,181 s en la base. En la rama
  midió 12,372, 10,502 y 10,709 s. En esa tanda no se registró el uso de la CPU.
- **El cuadro más largo de la rama es el que instancia el almacén.** Dura alrededor de un segundo
  también con la caché llena, en la base y en la rama. El enlace no lo cambia.
- **Con `--sin-enlace-en-paralelo`**, la primera corrida de la rama tarda 37,073 s desde el clic.
  Su cuadro más largo dura 2.771 ms.

Una sonda cronometró cada llamada de WebGL2 entre el clic y el aviso. La base y la rama enlazan
68 programas. En la base, las 68 consultas de `LINK_STATUS` suman 26,9 s. En la rama no llegan a
1 ms, y 5.995 consultas de `COMPLETION_STATUS_KHR` suman 21 ms. La sonda agrega su propio costo:
sus tiempos totales no se comparan con los de la tabla.

Lo que esta medición no cubre:

- **Otro equipo.** El enlace en paralelo usa los hilos libres: una máquina con menos hilos gana
  menos.
- **El primer dibujo de cada programa.** Las pasadas no esperan entre sí, y un programa puede
  terminar con su objeto ya tapado. Una sonda que sí esperaba dibujó los 68 programas apenas
  terminaron. Después del pedido, ningún cuadro pasó de 105 ms. Esa sonda tardó 11,0 s, contra
  9,7 s sin esperar.
- **Una variante que el calentamiento no dibuja.** En la partida se pide en paralelo, y su objeto
  aparece cuando el programa termina.

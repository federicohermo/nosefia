---
name: implement-feature
description: "Implementa UN cambio de No se fía — un issue, o un spec recién escrito sin issue — con TDD obligatorio y verificado, y verificar.py como nodo de convergencia. Cierra con el PR abierto, los criterios del issue cumplidos y cada criterio del spec citado por un test. Para dos o más issues de una, implement-batch."
argument-hint: "[NN del issue | capability con spec sin issue]"
---

# implement-feature — No se fía

**Lo que se implementa es un issue**, o un spec que se escribió sin issue. El issue es el plan
de esta vez: qué se toca y cómo se sabe que está. El spec —`specs/<capability>/<capability>.md`—
es el contrato que queda. Muchos issues no tocan ningún spec.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md). Lo propio de implementar es el
lazo: **si acá aparece un problema de planteo, el defecto no es de este issue — es del skill que
lo dejó salir así**, y se corrigen los dos en esta corrida.

## Antes de arrancar

```bash
gh issue view <N>                                  # el plan entero
git checkout staging && git pull
git checkout -b <tipo>/<N>-<descripcion-kebab>
```

**El prefijo de la rama es el tipo del issue**, y el hook sólo deja escribir en `src/` desde
`feature/`, `bugfix/`, `refactor/` e `improvement/`. `feature/` es para código que parte de
un spec: si el spec todavía no está escrito, primero `to-spec`, en esta misma rama. Un
`bugfix` que escribe la regla que faltaba también toca un spec, y va igual en `bugfix/`: el
prefijo sale del tipo, no de si hay spec. Lo que no toca `src/` se nombra por lo que toca —
`harness/` o `docs/`.

Si el issue ya tiene rama, no la vuelvas a crear: puede haberla abierto otra sesión, y ahí lo que
corresponde es un worktree propio sobre esa rama. **Un worktree se abre sólo en
`.claude/worktrees/<nombre>` del checkout principal**, y lo bloquea un hook si va a otro lado:
es el único lugar que limpia `limpiar_worktrees.py`.

**Si el cambio toca un spec, leelo entero, no sólo sus criterios nuevos.** Las reglas de la
capacidad son el marco: un criterio que se cumple rompiendo otra regla no está cumplido.

## Los límites del issue son límites

La tabla de **límites de archivo** del issue no es una sugerencia: la fila «No se toca» es una
lista negativa y cerrada. Si el trabajo pide escribir algo de esa fila, **eso es un hallazgo sobre
el issue** y se descarga por la 2 o la 4 de `sin-deuda.md` — no se escribe igual.

Los `.tscn` compartidos son el caso caro: **una escena no se mergea.** Dos issues que tocan la
misma escena se ordenan, no se paralelizan.

## El test va primero, y el gate lo verifica

Esto es lo que más cambia respecto de un repo cualquiera. En Godot **no hay cobertura**, así que
la disciplina no se sostiene sola: la sostienen cuatro reglas que
`python .claude/scripts/gate_de_tests.py` verifica, y que están explicadas con su modo de falla en
`.claude/scripts/lib/tdd.py`.

Para cada cosa que toca `src/dominio/` o `src/sistemas/`:

1. **Escribí `test/<capa>/<nombre>_test.gd` primero** y corrélo: tiene que fallar, y fallar por lo
   que se espera. Un rojo de `nonexistent function` no verifica nada — verifica que el archivo no
   existe.
2. Lo mínimo para que pase.
3. Limpiar, con el test de testigo.

**El nombre del test cita su criterio**, y se escribe ahí mismo y no al final:

```gdscript
func test_dos_jornadas_graves_seguidas_despiden() -> void:  # AC-EMP-004
```

**Una prueba de arquitectura no prohíbe toda condición en una cáscara.** En #306 del
2026-10-09, un test heredado rechazaba cualquier `if`, `elif` o `match` en la raíz: también
impedía excluir cuerpos ya entregados o comprobar una referencia antes de leerla. La cáscara
traduce esos hechos; el dominio decide sus consecuencias. Antes de editar, declará en el issue
el reemplazo del test textual, conservá sus comprobaciones útiles y ejercé los resultados en
pruebas funcionales y puras. No eludas la expresión regular con otra sintaxis ni afirmes que
una cita de método demuestra la delegación: eso también requiere revisar la fuente.

**Un detector de cifras reconoce el literal completo antes de clasificarlo.** En #369,
un guard de enteros de balance buscaba `\b\d+\b` y trató los decimales geométricos
`2.0` y `0.02` como enteros. La corrección conserva los archivos vigilados y el testigo
de una copia `JORNADAS := 5`, y agrega decimales y exponentes que no son enteros.
No se mueve la consulta física a otro archivo sólo para eludir un barrido defectuoso.

**Un test que compara dos lecturas del mismo cuadro tiene que forzar la escritura antes de leer.**
`await get_tree().process_frame` sigue **antes** del `_process` de los nodos. Leer justo después
del `await` compara la escritura del cuadro anterior contra el instante de éste. Medido el
2026-09-14: 30,98 mm de desfasaje aparente con el arreglo ya puesto, que se lee como que el
arreglo no alcanza. O se llama al método a mano antes de leer, o se comparan dos instantes
declarados distintos.

**Una sonda física conserva los cuerpos que mide.** `process_mode = DISABLED` sobre la raíz
también retira sus `CollisionObject3D` de la simulación: un recorrido vacío no certifica un
pasillo libre. En #301, esa forma de congelar el juego produjo cero celdas transitables.
Detené sólo los procesos que alteran la pose y afirmá primero que la cápsula encuentra su piso
y los obstáculos conocidos. La sonda inválida se conserva, pero no cuenta como evidencia.

**La mira se ejerce después de sincronizar sus áreas.** Teletransportar al jugador y consultar
`Area3D.get_overlapping_bodies()` en el mismo cuadro puede devolver el conjunto anterior.
En #369, un rayo directo encontraba la caja mientras la mira real todavía no la veía.
Esperá cuadros de física, comprobá el campo actualizado y ejercé la mira real. En una pila,
probá puntos de las caras visibles: el centro puede estar tapado aunque otra cara sea accesible.

**Un test que mide lo que se dibuja tiene dos trampas más**, medidas el 2026-09-24:

- **En headless, `Engine.max_fps` no da cuadros parejos.** Con tope en 144, los cuadros alternan
  entre 0,3 y 15,5 ms. Todo lo que depende del tiempo sale desparejo aunque en el juego sea
  parejo. El ritmo se marca con un nodo que espera activo hasta el cuadro siguiente.
- **`get_global_transform_interpolated()` en una rama sin nada interpolado devuelve un valor
  viejo.** Un nodo sin interpolar hijo de uno interpolado sí hereda su dibujo. Se lee lo
  interpolado si el nodo o algún ancestro `is_physics_interpolated_and_enabled()`.

**Y un tirón que se ve en pantalla se mide también contra la entrada**, no sólo contra el
dibujo: cuántos eventos del mouse llegan por cuadro. En el #187 la cámara hacía exactamente lo
que pedía el mouse, y el escalón venía de un mouse de 125 Hz contra una pantalla de 144.

**Si algo no se puede probar sin levantar una escena, no va en esas dos capas.** Va en `ui/` o en
`escenas/`, que son cáscara — y entonces la regla que tenía adentro hay que bajarla al dominio.
Ésa es la conversación que el gate fuerza, y es la que hace que el juego se pueda probar.

**Lo que se mira en la web se mira en un Chrome que dibuja.** Un Chrome manejado por Playwright
que queda tapado por otra ventana casi no pide cuadros: dos capturas seguidas salen iguales. En el
#181 el agua parecía quieta en la web, y el juego no llegó a 240 cuadros en 20 segundos. Va con
`--disable-backgrounding-occluded-windows` y `--disable-renderer-backgrounding`, y antes de leer
una captura se cuentan los `requestAnimationFrame` de un segundo.

**No excluyas texturas del export por una búsqueda de texto vacía.** Godot extrae las
imágenes del GLB y el modelo importado las referencia también desde recursos binarios. En #339,
excluirlas redujo el paquete y dejó el local sin texturas. Conservá esas dependencias y verificá
una partida nueva en el navegador, observando la consola también después de salir del menú.
El humo de arranque termina antes de ese recorrido. Un build local no exige publicar en Vercel:
el límite de tamaño de publicación no justifica quitar arte necesario.

**El import frío de una copia de export puede retener recursos de plugins del editor.**
En #373, los 111 recursos retenidos eran de `addons/`; el mismo árbol importó sin errores ni
fugas al desactivar sólo `editor_plugins` en la copia externa. Antes de aislarlos, identificá
los recursos con `--verbose` y conservá ambos intentos. No se modifica el checkout, el preset
versionado ni el juego para eludir el diagnóstico. El paquete resultante todavía exige el
chequeo externo, su marcador final y la interacción en Chrome sin errores; no se ignoran
errores de scripts ni dependencias faltantes.

**Los recursos de diálogo se verifican también dentro del paquete exportado.** En #339, los
tests y las capturas del checkout mostraban las nueve entradas, pero el recurso binario del
PCK conservaba sólo los recordatorios: las conversaciones quedaban vacías. Ejecutá el chequeo
externo `.github/scripts/verificar_dialogos_exportados.gd` con `--main-pack` desde la carpeta
del export, además del recorrido de interacción. No des por resuelto un reporte del build
porque la misma conversación funcione desde el checkout.

## Cuando lo que escribís es un gate sobre prosa

Una parte de lo que este repo verifica no es código: es que un `.md` diga algo. Tres cosas se
pisaron ahí, las tres medidas el 2026-09-06, y las tres cuestan una vuelta entera porque el rojo
miente sobre su causa.

- **Aplaná los saltos de línea antes de buscar.** Los docs van cortados a 100 columnas, así que la
  frase que buscás cae partida y el test da rojo diciendo que el doc no lo dice **cuando sí lo
  dice**. Va `re.sub(r"\s+", " ", texto)` antes de comparar, y se compara por párrafo.
- **Si el criterio pide que N documentos nombren un verificador, la cadena tiene que incluir QUÉ
  verifica.** Buscar `` `gate_de_capas.py` `` a secas dio verde sobre el archivo que venía a
  corregirse, porque ya lo nombraba **de otra cosa**.
- **La falsificación se mide con el nodo en verde de base, y el par se toma en la misma corrida.**
  Primero verde, después rojo con el cambio, después verde otra vez, seguido.

## La dirección de dependencia la verifica otro gate

`dominio/` → `sistemas/` → `ui/` → `escenas/`, sólo hacia abajo. Y **cuenta también nombrar un
`class_name` de otra capa**, que en Godot es la forma normal de escribir código y no deja rastro
en ningún import: por eso el gate construye el índice y busca los identificadores.

Si te frena, la salida no es una excepción: es mover la decisión hacia abajo, o pasar el dato por
parámetro en vez de ir a buscarlo.

## El nodo de convergencia es `verificar.py`, no los tests

```bash
python .claude/scripts/verificar.py
```

**Commiteá y pusheá antes de correrlo.** Tarda minutos, y en ese tiempo otra sesión puede
cerrar su lote y borrar worktrees. Lo que está en el remoto no se pierde. Medido el
2026-09-27: un carril perdió el issue entero, hecho y sin commit, a mitad de la corrida.

Corre los siete nodos en paralelo: `lint`, `formato`, `capas`, `tdd`, `specs`, `harness` y
`tests`. Correr sólo la suite de gdUnit4 deja afuera los gates, que son justamente los que cuidan
lo que en este motor nadie más cuida.

**Guardá su salida en un archivo.** El nodo `tests` rojo imprime la corrida entera, y la
herramienta la corta antes del test que falló. Medido el 2026-09-26.

**El XML sin errores no certifica los callbacks ni el desmontaje.** Conservá también la salida
cruda del motor en verde. En #302, emitir un array sin tipo abortaba un callback fuera del
contador de errores del caso y la ausencia de audio pasaba por accidente. El fixture entrega
los tipos de la señal y afirma que su receptor se ejecutó, además del resultado. Un error nuevo
o una fuga se corrige aunque el XML diga cero; los diagnósticos deliberados del debugger o de
un `assert_error` se identifican por su causa, sin descartar otras líneas `ERROR`.

La salida cruda incluye **stdout y stderr del subproceso**, también en la base anterior al
cambio. El archivo `godot.log` no los reemplaza: en el lote del 2026-10-10 omitió los avisos
de recursos al salir que sí estaban en stderr. Sin ambos canales de la base no se puede
atribuir un diagnóstico al cambio sólo porque su XML siga verde.

**Un nodo salteado no es un nodo verde**, y el reporte lo distingue. Pero `tests` sin `GODOT_BIN`
**no se saltea: sale rojo** — ese salteo vale sólo mientras no exista un solo `*_test.gd`, y hay
muchos.

**Y el conteo crudo confirma que corrió todo.** Desde gdUnit4 6.2.1, una suite que no parsea corta
la corrida entera con 105, y el nodo `tests` sale rojo. Con la versión de antes se descartaba en
silencio y el nodo salía verde. Medido el 2026-09-30, en `.claude/rules/tests.md`. El conteo
crudo sigue siendo el control, y `verificar.py` **no lo imprime**:

```powershell
& $env:GODOT_BIN --path . --headless -s -d --remote-debug tcp://127.0.0.1:0 `
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --continue --ignoreHeadlessMode `
  -rd res://reports 2>$null | Select-String "Executed test suites"
```

**Va en PowerShell y no en Bash**, porque en un worktree aislado Bash rechaza cualquier forma de
invocar Godot como comando. **Y el `2>$null` no se saca**: PowerShell no pasa el stderr de Godot
por `Select-String`, y sin él la corrida devuelve 4,5 MB. Medido el 2026-09-24.

Esta vista filtrada sólo presenta el conteo; no reemplaza el archivo crudo de la corrida ni
su veredicto. Los errores fuera del contador se revisan en ese archivo completo.

Ese `(N/N)` tiene que dar igual que `find test -name '*_test.gd' | wc -l`. Si da menos, hay una
suite que no corrió.

**El escalón que cuesta una vuelta:** crear el `.gd` no alcanza para que su test lo vea. Un
`class_name` nuevo no entra al registro global hasta que se vuelve a correr
`& $env:GODOT_BIN --headless --path . --import --quit`, desde PowerShell, y hasta entonces el error
es `Parse Error: Identifier "X" not declared` **con el archivo ya escrito en disco**, y la
corrida entera sale con 105. Re-importá después de crear cada archivo con `class_name` nuevo.

**Y el rojo del paso 1 se lee en la salida cruda.** Desde 6.2.1, un caso que aborta por un error
de script sale `FAILED`, con el error contado. Con la versión de antes salía `PASSED`: el
2026-09-01 dio **4 de 5 casos en verde** con la escena sin escribir. Pero un `FAILED` por un error
de script no es todavía el rojo que se espera. El «falla por lo que se espera» se verifica en el
`ERROR: Failed loading resource` de la salida cruda. Ese `ERROR:` va por stderr: se lee corriendo
sólo esa suite, con `-a <ruta>` y sin `2>$null`. Los dos `ERROR:` de `--remote-debug` no son un
fallo.

**Y `--import` reescribe `project.godot`.** El editor no guarda un ajuste igual a su valor por
defecto: lo borra del archivo. Medido el 2026-09-14 con
`common/physics_ticks_per_second=60` escrito a mano: la línea desaparece; con `=90` se conserva.
Después de editar `project.godot`, corré `--import` y volvé a leer el archivo antes de dar el
criterio por cerrado.

## Cuando el issue o el contrato no alcanzan — el lazo

**Para cuando llegás acá no debería quedar ninguna duda de planteo.** Se resuelven en `to-issue`
y en `to-spec`, que es donde cuestan un párrafo. Una duda que aparece implementando es
evidencia de que uno de esos dos tiene un agujero.

La descarga son dos mitades, las dos en esta corrida:

1. **Corregí lo que falta** —el criterio que no se puede ver fallar, el límite de archivo mal
   medido, la regla que estaba en la capa equivocada—. Si es del contrato, se edita
   `specs/<capability>/<capability>.md` **en este mismo PR**. Si es del issue, se edita el issue
   con `gh issue edit <N>`.
2. **Corregí el `SKILL.md` que lo permitió**, con la regla que lo habría atajado. La tabla de
   correspondencias está en [`sin-deuda.md`](sin-deuda.md), y **si no entra en ninguna fila,
   agregá la fila**.

Va al reporte como sección propia. **Es el entregable más caro de la corrida y el más fácil de
saltear**, porque no lo reclama ningún test ni ningún PR.

**Nunca se ajusta el contrato para que coincida con el código.** Si difieren, eso es el hallazgo:
se corrige el código.

## Al cerrar

- **Cada criterio del spec que el cambio agrega o cambia, nombrado por el test que lo verifica**
  —`# AC-EMP-004`, con el código de la capacidad—, en `test/` o en `.claude/scripts/tests/`. Es
  el ancla anti-deuda que cobra el gate.
- **Cada criterio propio del issue, cumplido y marcado en el issue.** Esos no llevan ID ni se
  citan: mueren con el issue.
- **Si la capacidad quedó con todos sus criterios citados, pasala a `ratified`** en el frontmatter
  del spec, en este PR. Desde ahí el gate la cobra.
- `python .claude/scripts/verificar.py` en verde, sin nodos salteados.
- **El PR declara, por cada `AC-<COD>-###`, `AC → test → resultado`**, y lleva `Closes #N` si hay
  issue.
- **Si el cambio redefine un gesto, buscá los casos que lo ejercen en el estado nuevo** y corré
  esas suites sueltas antes de `verificar.py`. En el #176, dos clics seguidos sobre la misma caja
  pasaron de «no hace nada» a «devuelve la unidad», y un caso de `reposicion_manual_test.gd` que
  afirmaba lo viejo costó una corrida entera en 6/7.
- **Si una llegada pasa de abrir una interfaz a depender del reloj, revisá también los
  fixtures de notificaciones, sonido y caja que piden atender.** En #339 seguían esperando
  un comprador inmediato. La primera jornada debe ejercerse avanzando su reloj; las pruebas
  del recorrido anterior deben declarar una jornada que lo conserve.
- **Si completar una tarea pasa a exigir ventas, revisá los fixtures de cierre que marcan
  tareas a mano.** En #339, los casos de descarte y tickets fingían una noche impecable sin
  vender. Deben aislar el reparto anterior o realizar las compras; no debilitar la regla nueva
  ni cambiar los apercibimientos esperados para absorber una tarea que quedó pendiente.
- **Lo que aparece implementando se hace, no se anota.** Un issue incompleto no se cierra abriendo
  otro issue: se completa.
- **Un reparto nuevo exige revisar los supuestos de los tests que leen el modelo.** Buscá
  cantidades literales y `visible_instance_count` en esas suites antes de la corrida completa.
  En el #282, el fixture dejaba ocho huecos y Actron empezaba con tres unidades: reponer una
  debía afirmar stock inicial más uno. Si cambia la cara de un producto, medí el frente de
  su etiqueta en Blender y conservá el umbral del test, sin deducir el frente del reparto.
- **Las capturas que pide el issue van al PR, no a la rama.** Suben a la rama huérfana
  `capturas/<N>` con `python .claude/skills/implement-feature/scripts/capturas_a_rama.py <N>
  <carpeta>`, y el PR las muestra por su URL de `raw.githubusercontent.com`. El script existe
  porque desde un worktree el guard rechaza `git -C` sobre otro.
- **Un generador que reemplaza el trabajo a mano del artista se prueba contra lo que hizo el
  artista**, en todo lo que el issue no pide cambiar. En el #262, el acomodador apoyaba cada
  unidad de plano sobre la chapa, y en las rampas de las cabeceras las echó hacia adelante: el
  artista las tenía hacia atrás. Lo vio el usuario, no un test.
- **Una previsualización también valida antes de renderizar.** Si el acomodador detecta un
  choque o pierde una tanda, el script aborta y no publica la captura. En el #282, al quitar
  el saliente inferior, una previsualización siguió después del error y mostró el estante de
  N vacío. Se corrigió midiendo el fondo necesario de todos los niveles y verificando que
  conservara cada tanda. Una captura de un reparto inválido no sirve para pedir aprobación.
  Al ejecutar Python en Blender, pasá `--python-exit-code 1` antes de `--python`: sin ese
  parámetro, una excepción del script puede devolver código 0. Medido también en el #282.
- **Lo que genera un recurso commiteado va al repo con él**, con su test. Un recurso sin su
  generador sólo se puede editar a mano, y el cambio siguiente lo escribe de nuevo desde cero. La
  disposición de la góndola, sus dos escenas y sus 71 mallas salían de un acomodador que vivió en
  el scratch de una sesión: el #262 tuvo que escribirlo otra vez.
- Si el trabajo falsificó algo que la documentación afirma en presente, actualizá `docs/`,
  `.claude/rules/` y `CLAUDE.md`.

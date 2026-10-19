# Verificación

```bash
python .claude/scripts/verificar.py
```

Es **el nodo de convergencia**: lo único que hay que correr antes de un PR, y lo mismo que
corre la CI.

## Los nodos

Los declara `NODOS`, en `verificar.py`. Cada `nodo_*` de ese archivo dice qué corre, y cada gate
dice en su encabezado qué caza. Corren **en paralelo**: son procesos independientes y ninguno
depende de la salida de otro.

La CI llama al script y no enumera los nodos. Una segunda lista en el workflow seguiría
corriendo la vieja el día que se agregue un nodo, y en verde.

En GitHub Actions, las suites de Godot se reparten entre seis runners independientes:

```bash
python .claude/scripts/verificar.py --particion-tests 0/6
```

El índice empieza en cero. La última partición corre también los demás nodos; las otras sólo
corren sus suites. En el reparto actual es más liviana y deja CPU libre en la partición más larga.
La asignación prioriza las suites más lentas y las agrega al runner con menor carga estimada.
Usa las duraciones medidas de veinte suites y reserva margen para los demás nodos en la última partición.
Las suites nuevas reciben un costo estimado por defecto. Los tiempos orientan el reparto;
el inventario sigue saliendo de todos los archivos `_test.gd` actuales.
El orden es determinista y conserva la selección en Windows y Linux.
Cada runner importa sus recursos y tiene sus propios datos de usuario y reportes. El check
obligatorio `verify` sólo pasa cuando pasan las seis particiones.
Cada partición tiene un límite de veinte minutos. Si lo agota, el check falla.

Los nombres de los jobs señalan sus suites principales:

| Partición | Nombre |
| --- | --- |
| 0 | Cajas y agarre |
| 1 | Reposición y puestos |
| 2 | Apoyos y cierre |
| 3 | Arrastre y colisiones |
| 4 | Giro y balde |
| 5 | Limpieza y validaciones |

Cada partición incluye también suites de otras áreas, asignadas por duración estimada.
La última corre además los demás checks del proyecto.
Revisar los nombres si cambia la asignación de las suites principales.

Sin `--particion-tests`, el comando conserva la ejecución completa en un solo checkout.

## Motor nativo corregido

Godot 4.7.2 recibe el bloqueo de escritura del [PR oficial #123546](https://github.com/godotengine/godot/pull/123546) en el getter de valores predeterminados de `ClassDB`.
La [receta nativa](../../.github/patches/godot-native-compilacion.json) fija fuente, parche, compilador y opciones.
El preparador comprueba las fuentes antes y después del parche, y los hashes de cada binario al restaurarlo.
La importación multihilo permanece habilitada con el motor corregido.
El alcance es la carrera reproducida del getter, sin prometer seguridad de hilos para todos los accesos de `ClassDB`.
La causa de los timeouts anteriores de Linux sigue sin confirmarse.

Las seis particiones comienzan en paralelo, sin esperar un job de preparación del motor.
Cada una restaura o descarga el mismo motor Linux publicado y valida la receta y los hashes contra el lock versionado.
Cada máquina necesita su propia copia del ejecutable.
El trabajo acumulado incluye esas transferencias, aunque se solapen en el tiempo.
Si se expulsa la caché, vuelve a descargarlo. `verify` nunca compila el editor.
Una release ausente o incompatible produce un fallo, sin iniciar una construcción.
Cada partición limita a tres minutos la descarga y validación del motor.
Esos pasos forman parte del tiempo total de CI.

La construcción y las ocho reproducciones concurrentes pertenecen al workflow manual `construir-godot-nativo`.
Se ejecuta al cambiar la receta del motor, antes de actualizar el lock que consumen las verificaciones.

El [flujo local](./motor_nativo.md) usa la misma receta para Windows y Linux.
La plantilla web mantiene sus parches y su validación independientes del editor nativo.

## Paso fijo en pruebas físicas

Las suites `lo_soltado_fuera_de_los_solidos_test.gd` y `agarre_fisico_test.gd` observan pasos de física y estados espaciales.
El verificador las ejecuta con `--fixed-fps 60`, sin esperar que transcurra el tiempo real de cada paso.
La frecuencia física sigue en 60 Hz y `time_scale` conserva su valor normal.
Los casos, bucles y aserciones permanecen completos.

Las demás suites conservan el reloj habitual, incluidas las de tiempo real e interpolación a 144 Hz.
Agregar una suite no la incorpora automáticamente al modo de paso fijo.
Al modificar las dos suites auditadas o la temporización del código que ejercen, revisar su contrato temporal.
Una aserción sobre reloj real o cuadros de presentación requiere ejecución normal o una nueva comparación de equivalencia.
La lista de suites auditadas vive en `lib/particiones_de_tests.py`.

Cada partición ejecuta hasta dos grupos secuenciales, `normal` y `fisica60`, después de una única importación.
El comando local usa los mismos grupos.
Cada grupo genera su propio JUnit en una carpeta nueva y exige cobertura exacta de las suites seleccionadas.
Un grupo fallido o sin reporte mantiene rojo el nodo completo, aunque el otro pase.
`grupos.json` registra el plan; `cobertura.txt` y `salida-gdunit4.log` conservan el resultado del nodo.

## Reutilizar importaciones entre revisiones

Cada partición restaura `.godot/imported` con una clave exacta por contenido.
La clave incluye nombres y bytes de recursos, opciones de importación, addons, identidad del motor nativo, sistema operativo concreto y arquitectura.
El helper `.github/scripts/cache_importaciones.py` concentra esa selección y la política de compatibilidad.
Cambiar scripts normales de `src/` o `test/` conserva la clave, incluso al agregar clases.
Cambiar modelos, materiales, shaders o recursos externos a `assets/` produce otra clave.
Los cambios del propio helper también invalidan la caché.

Cada worker obtiene el checkout actual y ejecuta siempre la importación del verificador.
Los índices de clases y UID, los datos de usuario y los reportes se generan en ese worker.
Sólo la partición cero publica importaciones después de pasar su verificación y encontrar una clave ausente.
Cada partición prepara su propio motor e importaciones. No depende de un productor previo.

Los importadores `importar_modelo.gd` e `importar_caja.gd` tienen hashes auditados en el helper.
Un importador cambiado, desconocido o un nuevo `EditorImportPlugin` desactiva el reuso hasta actualizar esa política.
El material precargado `vidrio_del_local.tres` también se controla.
Si incorpora scripts u otros materiales dependientes, la verificación trabaja en frío hasta auditar esas dependencias.
Los materiales y escenas de ejecución ajenos a ese importador no activan esa restricción.

El importador de caja escribe recursos versionados fuera de `.godot/imported`.
Para regenerarlos, cada worker elimina las salidas importadas declaradas por los tres GLB de caja antes de verificar.
La caché nunca restaura esos recursos versionados.

Una ausencia, un error del servicio o una coincidencia parcial limpia las importaciones restauradas y continúa con una verificación fría.
No se usan claves aproximadas.
La disponibilidad también depende del alcance de ramas y la retención de GitHub Actions.
Las PR pueden leer la caché de su rama base. Una caché creada dentro de una PR sirve para sus siguientes corridas.
El primer push a `staging` puede preparar en frío y publicar una caché para futuras PR dirigidas a esa rama.
El archivo `reports/cache-importaciones.json` registra clave, revisión actual, compatibilidad y acierto real de cada partición.
`reports/cache-recursos.sha256` conserva las huellas de los recursos derivados para comparar corridas frías y cálidas.
El resumen del job muestra ese estado aunque falle la verificación posterior.
Un acierto reutiliza trabajo de importación; los tests y su cotejo JUnit se ejecutan nuevamente.

## Medir el reparto en Actions

El workflow manual `medir-verificacion.yml` compara cantidades de particiones sin cambiar
el workflow habitual. Recibe la cantidad, el modo de preparación y una etiqueta de corrida.

```bash
gh workflow run medir-verificacion.yml --ref <rama> \
  -f particiones=6 -f preparacion=independiente -f etiqueta=ronda-1
```

El modo `independiente` prepara e importa en cada runner. `compartida` prepara una copia
completa y la distribuye. `importaciones` distribuye sólo la caché de recursos importados;
cada runner instala sus herramientas. Las copias restauradas validan revisión y entorno,
y siempre pasan por la importación incremental del motor antes de probar.

El job «Preparación compartida» sólo corre en los dos modos que distribuyen un artefacto.
Que se saltee en el modo independiente no saltea la preparación de cada runner.
La programación `serial` espera a que termine ese job antes de iniciar los workers.
`solapada` inicia los workers mientras el productor prepara. Adelantan el trabajo propio
de su modo y esperan la publicación del snapshot en la misma VM antes de restaurarlo.
`reutilizada` recibe `corrida_previa`, omite el productor y restaura su snapshot. Exige que
esa corrida haya terminado con éxito en la misma rama y revisión. Si el artefacto no existe,
expiró o es incompatible, falla sin sustituirlo por una preparación fría.

```bash
gh workflow run medir-verificacion.yml --ref <rama> \
  -f particiones=6 -f preparacion=importaciones -f programacion=solapada -f etiqueta=semilla
gh workflow run medir-verificacion.yml --ref <rama> \
  -f particiones=6 -f preparacion=importaciones -f programacion=reutilizada \
  -f corrida_previa=<run-exitoso> -f etiqueta=reuso-1
```

El tipo y el intento identifican el snapshot. Los workers registran su origen, ID inmutable,
edad y espera, y validan el commit objetivo fuera del paquete restaurado. La reutilización
mide una preparación ya disponible para la misma revisión; no evalúa hits ante cambios de
juego. Su costo inicial se informa aparte de la latencia de cada uso posterior.

Cada worker registra el equipo, las versiones, las suites seleccionadas y el tiempo de pared
y CPU del motor. Los artefactos `medicion-worker-*` contienen esos datos y el XML JUnit.
`medicion-preparacion` registra la importación común. Los artefactos duran un día.

Para decidir, conservar el mismo código de juego y comparar al menos cinco corridas por
opción, alternando el orden. Medir desde la creación del workflow hasta el final de su último
job, incluida la preparación. Cotejar la unión de suites y casos con la referencia, exigir
cero errores, fallos y saltos, y distinguir las muestras con cola por capacidad.
Una diferencia menor que la variación entre corridas no demuestra una mejora.

El [informe de preparación](../../.github/benchmarks/preparacion-2026-10-19.md) compara solapamiento y reuso previo.
Conserva también el costo de generar los snapshots y las limitaciones de la muestra.

## Un nodo salteado no es un nodo verde

El principio está en la [constitución](../architecture/constitution.md). El reporte distingue
`salteado` de `ok`, y cada salteo dice **qué no miró y cómo hacer que mire**. Las condiciones
de cada salteo son las llamadas a `_saltear` de `verificar.py`.

**El ancla AC↔test no se saltea: cambia de fuerza con el estado del spec.** Sobre un `ratified`,
un criterio sin test es rojo. Sobre un `draft`, el gate cuenta cuántos faltan y lo imprime.
Cobrarle a todo spec escrito haría que nadie escriba el contrato de una capacidad nueva.

## Sobre el nodo `tests`

El veredicto es el código de salida del proceso de Godot, no el texto del reporte. Cada flag de
la invocación lleva su porqué en un comentario de `nodo_tests`. Los reportes van a `reports/`,
que está en `.gitignore`.

Desde gdUnit4 6.2.1, una suite que no parsea corta la corrida con 105 y el nodo sale rojo. El
conteo crudo sigue siendo el control de que corrió todo. Cómo leerlo, en
[la regla de tests](../../.claude/rules/tests.md).

Cada partición coteja sus suites con el XML JUnit recién generado.
El nodo falla si falta una suite, se repite, sobra alguna o no tiene casos,
aunque Godot termine con cero.
Los artefactos `reports-gdunit4-<índice>` incluyen la selección esperada, el resultado del cotejo,
la salida de gdUnit4 y sus reportes. No se aceptan XML de una ejecución anterior.

## Lo que esta verificación NO cubre

- **No hay cobertura de código.** Godot no instrumenta GDScript. Qué la reemplaza y qué se
  pierde, en [TDD sin cobertura](./tdd.md).
- **No verifica que un test ejerza el criterio que cita.** El nodo `specs` verifica la **cita**.
  Un `# AC-EMP-004` en un test que no afirma nada pasa igual.
- **Verifica poco de las escenas.** De un `.tscn` mira lo que cobran `lib/escenas.py` y los
  tests de `test/escenas/`. El resto se ve abriendo el juego.
- **No verifica que el juego sea divertido**, ni que una tarea del turno se sienta bien. Eso es
  playtesting, y no tiene gate a propósito.

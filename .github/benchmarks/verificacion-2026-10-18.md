# Particiones de verificación en GitHub Actions

Medición del 18 de octubre de 2026. La propuesta usa seis particiones independientes.

## Confirmación

Recomiendo seis particiones para esta carga. Frente a cuatro, la mediana baja de 7:43 a
6:26, 77 segundos y un 16,6 %. Ocho registra 6:16, diez segundos menos que seis. Con cinco
muestras por opción no se demostró esa ventaja al nivel del 5 %. Seis ocupa dos runners menos por corrida.

Los [datos de cada corrida](verificacion-2026-10-18.json) y los
[datos por worker](verificacion-2026-10-18-workers.csv) conservan revisión, equipo, cola,
tiempos y resultado. Son 27 intentos, con 25 corridas completas y dos canceladas por timeout.

| Particiones | Muestras completas sin cola | Mediana | Rango | Mediana del tiempo acumulado de jobs |
|---:|---:|---:|---:|---:|
| 4 | 5 | 7:43 | 7:33 a 8:00 | 1.689 s |
| 6 | 5 | 6:26 | 6:09 a 6:55 | 1.976 s |
| 8 | 5 | 6:16 | 5:30 a 6:19 | 2.377 s |

Estas medianas usan sólo la confirmación. La prueba exacta bilateral de suma de rangos,
con rangos medios para empates, da p = 0,00794 entre cuatro y seis, y p = 0,06349 entre seis
y ocho. No demostrar una diferencia entre seis y ocho no prueba que rindan igual.
El rango de seis abarca 46 segundos y el de ocho 49, frente a diez segundos entre medianas.

Seis consume una mediana de 287 segundos más de ocupación que cuatro, a cambio de la menor
espera. Ocho suma otros 401 segundos de ocupación respecto de seis. La elección busca el
menor reparto confirmado que mejora la espera sin agregar runners por una ganancia no demostrada.
Cinco, siete, doce y dieciséis sólo tuvieron pilotos. No se afirma un óptimo global entre todos
los enteros ni para futuros inventarios de tests.

## Exploración

Cada fila es una sola corrida. Sirvieron para acotar las candidatas, no para atribuirles una mediana estable.

| Preparación | Particiones | Total | Run |
|---|---:|---:|---|
| Independiente | 4 | 7:34 | [39153732626](https://github.com/federicohermo/nosefia/actions/runs/39153732626) |
| Independiente | 5 | 6:34 | [39157240535](https://github.com/federicohermo/nosefia/actions/runs/39157240535) |
| Independiente | 6 | 6:20 | [39155074388](https://github.com/federicohermo/nosefia/actions/runs/39155074388) |
| Independiente | 7 | 6:22 | [39157772284](https://github.com/federicohermo/nosefia/actions/runs/39157772284) |
| Independiente | 8 | 5:46 | [39155612044](https://github.com/federicohermo/nosefia/actions/runs/39155612044) |
| Independiente | 12 | 6:14 | [39156089841](https://github.com/federicohermo/nosefia/actions/runs/39156089841) |
| Independiente | 16 | 6:43 | [39156594503](https://github.com/federicohermo/nosefia/actions/runs/39156594503) |

La suite `test/escenas/lo_soltado_fuera_de_los_solidos_test.gd` tarda unos 187 segundos en JUnit
y unos 189 dentro del proceso que la ejecuta. Ya queda sola en los valores probados desde seis.
Agregar grupos conserva ese trabajo indivisible con el repartidor actual. La suite espera
cuadros de física durante sus pruebas.

La importación también pesa. En los pilotos, el worker de esa suite importó en 107 segundos
con ocho particiones y una CPU Xeon 6973P-C. Con doce y dieciséis importó en unos 137 segundos
sobre EPYC 7763. Parte de la mejor muestra de ocho corresponde al equipo recibido.
En nuevas repeticiones puede terminar último otro grupo por el costo de su preparación e importación.

Los runners registraron cuatro CPU lógicas y varios modelos de EPYC y Xeon. La importación fría
usó varias CPU; los tests incluyen esperas de física. Ni el modelo de CPU ni su carga estuvieron fijados.
La imagen observada fue Ubuntu 24, versión `20261012.334.1`.
En el piloto de siete, el worker de la suite larga importó en 139 segundos de pared y consumió
448 segundos de CPU. Los tests tardaron 190 segundos de pared y unos 40 de CPU. Es coherente
con la espera de cuadros que aparece en el código de esa suite.
Con dieciséis, el checkout del worker de la suite larga tardó 42 segundos. Otra repetición de seis
tuvo 58 segundos de checkout en ese worker, frente a 25 en los demás. Ese dato se conserva.

## Preparar una vez

Se verificaron dos diseños que esperan la preparación común antes de iniciar los workers.
Cada worker restaura una copia privada, valida revisión y entorno y pasa por una importación
incremental antes de ejecutar sus suites. Los dos ejecutaron el mismo trabajo de tests.

| Diseño | Particiones | Total | Tiempo acumulado de jobs | Referencia independiente |
|---|---:|---:|---:|---|
| Copia completa | 4 | 9:10 | 1.507 s | 7:34 y 1.676 s |
| Sólo importaciones | 7 | 6:49 | 1.517 s | 6:22 y 2.218 s |

La [copia completa](https://github.com/federicohermo/nosefia/actions/runs/39154336452)
incluye código, metadatos de Git que usa el harness, herramientas y recursos importados.
El paquete comprimido pesa unos 1,59 GB y descargarlo tardó entre 35 y 80 segundos por worker.

El [paquete de importaciones](https://github.com/federicohermo/nosefia/actions/runs/39158309811)
pesa unos 49 MB. Su preparación común ocupó 156 segundos. Los workers descargaron el paquete
en uno a tres segundos e importaron de manera incremental en unos seis a dieciséis segundos.
En el worker de la suite larga, esa importación pasó de 139 a ocho segundos entre esos dos pilotos.

Es posible preparar una vez y ahorrar tiempo acumulado de los jobs. Estas muestras únicas
tardaron más hasta el resultado. No establecen una mediana para los diseños compartidos.
No prueban solapar trabajo de los workers con la preparación ni restaurar una preparación
de una corrida anterior. Esas alternativas podrían dar otro resultado y no se midieron.

El [seguimiento del 19 de octubre](preparacion-2026-10-19.md) mide ambas alternativas con seis particiones.
Sus resultados distinguen la primera preparación de los reusos de una misma revisión.

## Intentos que no completaron el trabajo

La confirmación tuvo cinco corridas completas sin cola para cada opción. Además, cuatro y
ocho tuvieron una cancelación por timeout cada una. Ocho tuvo también la corrida completa
con cola de 238 segundos, informada por separado.

Los runs [39161426701](https://github.com/federicohermo/nosefia/actions/runs/39161426701)
de ocho y [39162317738](https://github.com/federicohermo/nosefia/actions/runs/39162317738)
de cuatro agotaron el límite de veinte minutos de sus workers de checks. GitHub lo registra
en sus anotaciones. Sus tiempos totales fueron 20:32 y 20:31, respectivamente.

En ambos workers cancelados quedaron vacíos `godot.jsonl` y `verificar.log`, sin JUnit ni
`worker.json`. No se registró una invocación del motor completada. Por la secuencia del
verificador, eso apunta a una importación sin terminar. No se obtuvo una captura de CPU o
stack de esos procesos para determinar la causa. Los intentos se conservan en
`rejected_trials`, con sus resultados parciales. No cuentan como éxitos ni como pruebas de
que la cantidad de particiones causó el cuelgue. La propuesta de seis no corrige esa causa desconocida.
El workflow habitual adopta el mismo límite de veinte minutos por partición para liberar el
runner con un resultado rojo cuando una ejecución excede ese tiempo.

## Método y límites

Se fijó el juego en `d72aae87217482bc6f336ec8d894547c98048338`. Todas las muestras válidas
conservaron los árboles de `src`, `test` y `assets` y ejecutaron las mismas 304 suites de Godot
una sola vez, con 2.287 casos y cero errores, fallos o saltos en JUnit.
Los demás nodos del verificador corren en la última partición.

El tiempo total va de `created_at` del workflow al último `completed_at` de sus jobs.
Incluye preparación, checkout, herramientas, importación, tests, publicación de reportes y resultado.
El tiempo acumulado suma las duraciones de jobs ejecutados; no es una factura ni una suma de CPU.
El medidor llama al mismo `verificar.py` y registra tiempos de pared y CPU por invocación del motor.

La confirmación rota el orden de lanzamiento de las configuraciones. Usa VMs distintas y
espera a que una configuración termine sus descargas antes de lanzar la siguiente.
A partir de la segunda ronda consulta la ocupación visible del repositorio antes de cada despacho, con un presupuesto
conservador de veinte jobs y un lugar reservado. No detiene workflows ajenos.
Al prolongarse un worker de ocho en la cuarta ronda, los controles finales se adelantaron
con la misma regla de capacidad. Las muestras pendientes de ocho se coordinaron del mismo modo.

Se conservan todas las muestras correctas. Para las medianas sin cola se exige que ningún job
ejecutado espere más de quince segundos entre su creación y su inicio. Las muestras excluidas
se repiten. La primera confirmación de ocho tuvo 238 segundos de cola y un total de 8:54,
y queda identificada en la evidencia. La variación de checkout sin cola sí entra en las medianas.

La conclusión se limita a esta carga, este repartidor y los tamaños medidos. Una muestra rápida
en un equipo distinto no demuestra una mejora del reparto. Un cambio importante en las suites
o en la imagen del runner requiere repetir la comparación. La medición incorpora los jobs de plan y resultado del medidor;
los tiempos absolutos del workflow habitual pueden diferir.

## Repetir

Desde una rama con el medidor y la revisión de juego a comparar:

```bash
gh workflow run medir-verificacion.yml --ref <rama> \
  -f particiones=6 -f preparacion=independiente -f etiqueta=ronda-1
```

Repetir con las cantidades candidatas y etiquetas distintas. Descargar `medicion-worker-*`
y `medicion-preparacion` antes de un día. Cotejar la unión de XML contra la referencia antes
de aceptar un tiempo. Los datos conservados deben incluir run, SHA, equipo, cola, fases,
inventario y resultado de tests. El workflow permite repetir los modos `compartida` e `importaciones`.

## Criterios aplicados

- **Model the Domain.** Los modos y el manifiesto distinguen la copia completa de las importaciones.
- **Build the Lever.** El workflow manual deja una medición reproducible para otros repartos.
- **Explain the Number.** La decisión usa el tiempo total, la importación, los tests y la cola.
- **Separate Before Serializing Shared State.** Cada runner escribe en su propia copia restaurada.
- **Sequence Work into Verifiable Units.** Se verificó cada piloto antes de acotar y repetir candidatas.

## Revisión de la evidencia

Una revisión independiente recalculó los tiempos, las medianas y las pruebas de rangos desde
los datos conservados. También cotejó las rutas de suites y los nombres de casos de las 25
corridas completas: el inventario coincide. No encontró bloqueos en la evidencia ni en la
propagación de fallos del workflow.

La revisión usó el modelo heredado del agente principal. No hubo diversidad entre familias
de modelos disponible. La validación de la CI habitual contra el merge del PR se informa
por separado; esta comparación de rendimiento conserva el juego congelado indicado arriba.

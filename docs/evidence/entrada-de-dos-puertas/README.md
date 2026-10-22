# Entrada de dos puertas

La salida de J1 abre ambas hojas sobre sus bisagras exteriores. El jugador mira al centro
del vano y la noche espera a que ambas terminen de abrirse. J4 comienza con las dos cerradas.

## Capturas del juego

[J1 con ambas hojas abiertas](j1-dos-hojas-abiertas.png).
[J4 cargada desde guardado con ambas hojas cerradas](j4-dos-hojas-cerradas.png).

Son capturas del viewport del juego nativo con el motor corregido y Compatibility. El fixture
completa las tareas de J1, enfoca la hoja izquierda con la mira real y envía el clic primario.
Captura cuando ambas alcanzan `Puerta.ANGULO_ABIERTA`. Para J4 carga un guardado nuevo de esa
jornada y mira las puertas antes de interactuar. No reemplaza mallas, materiales ni luces.

Se reproducen desde la raíz, con datos de usuario aislados:

```powershell
$env:APPDATA = "$PWD/.godot/usuario_de_capturas"
& build/godot-native/windows-x86_64/godot.windows.editor.x86_64.console.exe `
  --path . --script test/escenas/capturar_salida_por_entrada.gd --resolution 1280x720
```

## Causas comprobadas

- La release tenía los dos marcos dibujados dentro de una sola malla. El giro arrastraba
  ambos sobre la bisagra izquierda y dejaba el vidrio en su posición original. El canto
  izquierdo conservaba su altura en ejecución. El aspecto de hoja desprendida venía del
  conjunto que giraba y del vidrio inmóvil, sin una traslación vertical de la puerta.
- La mirada se calculaba desde el centro de esa malla. Ahora usa el punto medio de las
  bisagras del vano, independiente de las hojas y sus herrajes.
- El reinicio de jornada llamaba a `cerrar_de_golpe()` sólo para las puertas de su lista.
  La entrada no estaba incluida. Tras salir de J3, la ejecución conservaba la apertura
  completa en J4. Cargar J4 en una escena nueva ya empezaba cerrado en la release.

## Contrato y pruebas

El primer commit, `2536e2a8`, actualiza BR-SHF-025, AC-SHF-043 a 046 y player-actions.
El segundo, `83011b8d`, conserva las pruebas que fallan antes de la corrección.

| Criterio | Prueba y resultado local |
| --- | --- |
| AC-SHF-043 | `animacion_de_salida_test.gd` verifica bisagras, sentido y espera de ambas. `entrada_con_vidrio_test.gd` verifica vidrio móvil y ausencia de cruces con los paños fijos. Pasan. |
| AC-SHF-044 | `test_salida_gira_abre_ambas_y_cierra_una_vez` parte de una vista con suavizado pendiente y comprueba la dirección al centro del vano. Pasa. |
| AC-SHF-045 | `test_pausar_cada_etapa_conserva_la_secuencia_y_la_mano` observa ángulo y transformación de ambas hojas durante la pausa. Pasa. |
| AC-SHF-046 | Los casos de transición J3 a J4, carga y reintento desde el mismo guardado comprueban ambas hojas cerradas. El cierre único y el cierre por tiempo conservan sus pruebas. Pasan. |
| AC-PLY-103 y AC-PLY-104 | J4 rechaza la salida desde cualquiera de las hojas. Cualquiera de ellas inicia la apertura de ambas en J1. La salida conserva el objeto sostenido. Pasan. |

La corrida final local ejecutó 47 casos de ocho suites puntuales, sin errores, fallos,
salteos ni nodos huérfanos. Incluye las suites de puertas, apoyos del modelo, iluminación
horneada e inicio de jornada. También pasan `gdformat` y `gdlint` sobre los GDScript tocados.
El modelo se exportó completo, se borró su caché de importación y se ejecutó `--import`.
Después se regeneraron el atlas y los datos de iluminación.

La importación final devuelve cero. Al cerrar el editor, gdUnit4 informa recursos de su
addon retenidos. El detalle verbose no incluye recursos del juego. La corrida de los 47
casos y las capturas del juego terminan sin esos diagnósticos.

## Decisión provisoria y entrega

[Notion, 3. Mapa del local](https://app.notion.com/p/3e586efecd9d80ffa836de777f4884e5)
permite terminar J1 a J3 por la entrada y la describe como una puerta que nunca se abre.
El pedido del usuario establece las dos hojas y su animación. La elección de abrir hacia
afuera queda como decisión provisoria porque el pedido sólo exige el mismo lado para ambas.

La rama se entrega al orquestador para integrarla en el PR #617. La CI corresponde a esa
integración. Esta corrección no abre un PR propio.

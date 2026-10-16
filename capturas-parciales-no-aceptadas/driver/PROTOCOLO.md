# Capturas externas de #444

Preparación estática, sin motor ni Chrome. No afirma capturas válidas ni éxito del recorrido.
Raíz ejecuta después de fijar el PCK productivo de la cabeza final y aceptar #433/#437.
No cambiar receta, preset, PCK, arte, callbacks de cursor ni archivos de ningún checkout.

## Contenido y fuentes

- `fixture444.gd`: Node externo, prepara Partida J2 en memoria, horario, pose y objetos reales.
  Los nueve textos exactos se copiaron de la sonda de raíz
  `R/preparacion-444/.github/scripts/verificar_dialogos_jornada_2_exportados.gd`.
  No implementa guardado #436 ni modifica el guardado del usuario.
- La rama Web obtiene `JavaScriptBridge` por nombre mediante `Engine.get_singleton`, sin
  referenciar un identificador exclusivo de Web cuando el mismo fixture carga en nativo.
  Fuente: [documentación oficial](https://docs.godotengine.org/en/4.7/classes/class_javascriptbridge.html).
- `fixture444.tscn` y `override.cfg`: montaje Web externo sobre el mismo paquete. La vía
  override+Node arrancó en Chrome42903 según A; el recorrido444 aún no se ejecutó.
- `recorrer444-web.mjs`: clics reales de Chrome; CDP `userGesture:false` sólo prepara/observa.
- `nativo444.gd` y `recorrer444-nativo.py`: montaje por script externo y clics Win32 reales
  en el centro del cliente de la ventana del PID creado. Mantiene el cursor productivo.

Se reutilizó la guía espacial medida por A en429 nativa03: pie relativo al sprite a1.3,
rayo acotado alrededor de la altura original del jugador, exigir SueloSolido y cápsula libre
antes de ubicar. No se fija el suelo en0.102237 ni se usa el rayo desde+3m que chocó la losa.
El punto opaco se calcula sobre los ocho frames actuales de cada figura. La mirada pasa por
Control.orientar/girar con sensibilidad real; la cámara efectiva/dibujada se contrasta postdraw.
Fede/Mía requieren medir esa premisa en sus recursos reales; no se hereda un píxel de Tin.

No se prueba un supuesto punto oculto en el centro del antepecho desde ojo alto: A midió que
podía seguir visible. Este driver mínimo no incluye aquel comando. Una futura ampliación de
oclusión debe exigir intersección previa con triángulos reales del antepecho, sin usar el propio
`admite_foco_en(false)` como oráculo para buscar el punto.

## Recorrido

Fede20:30 y Mía05:00 comparten una apertura J2 real. Cada atención se recorre completa:

1. Figura propia con interfaz cerrada, foco y contorno reales.
2. Retirar la primera unidad del pedido real antes del primer clic. El clic inicial conserva
   cuerpo, identidad y pedido; tres/una entradas, destacadas en amarillo y sin negrita/pista.
3. Último clic de inicial devuelve la vista y conserva la unidad en mano, sin venderla.
4. Entregar esa unidad por clic real, extraer/entregar las otras dos y tomar el ticket físico
   generado por CajaRegistradora. El último clic vende y abre la primera despedida.
5. Dos/tres entradas finales, presencia hasta el último avance, venta única y retorno.

Se guardan al menos las cuatro capturas inicial/despedida Fede/Mía. Además se capturan el pedido
amarillo de Fede y ambos retornos finales; las nueve entradas y todos los estados quedan en
el recorrido JSON. Cada observación espera sincronización física y dibujo. Durante diálogo
se exige foco lógico apagado y contorno nulo; el candidato físico crudo puede seguir presente.
Al terminar se exigen dos ventas, cuatro retornos de conversación y seis unidades reales con
descuento único de depósito. Nada del fixture llama a interacciones de atención o captura del
cursor: sólo los drivers emiten inputs, y la preparación usa reposición e impresora productivas.

## Ejecutar Web

Servidor aislado de raíz/A, apuntando a la carpeta **web real** con index.html/js/wasm/pck.
La carpeta output debe ser nueva y quedar fuera de checkouts:

```text
node D:/nosefia-carril-B-429-444/444-capturas-driver-01/recorrer444-web.mjs URL_DEL_INDEX OUTPUT_NUEVO CARPETA_WEB SHA256_PCK HEAD_PRODUCTIVO
```

El runner fija SHA256 HTML/JS/WASM/PCK antes/después y verifica también el PCK que entrega
el servidor. Intercepta sólo HTML para precargar tres archivos externos y conserva argsvacíos.
No ejecuta el main original: ese arranque sigue teniendo su evidencia separada. Produce
consola completa, estados, PNG y resultado; exige CAPTURAS_444_FIXTURE_OK y CAPTURAS_WEB_444_OK.

## Ejecutar nativo

Usar el ejecutable real del motor Godot, evitando un launcher `_console.exe` que cree una
ventana con otro PID. El driver exige que la ventana activa pertenezca al proceso creado;
si no puede demostrarlo, falla sin enviar clics a ventanas ajenas.

```text
python D:/nosefia-carril-B-429-444/444-capturas-driver-01/recorrer444-nativo.py --godot MOTOR_EXE --pck PCK_PRODUCTIVO --sha256 SHA256_PCK --head HEAD_PRODUCTIVO --output OUTPUT_NUEVO
```

El perfil APPDATA y archivos de control/capturas son exclusivos del intento. Se escribe sólo
en output; PCK se lee por --main-pack y su hash se contrasta antes/después. La ventana es real
y los clics Win32 pasan por callbacks productivos. Al terminar pide salida natural al fixture
y conserva ambos canales del motor. En error/timeout sólo termina el PID/árbol que él creó,
con log explícito; esa interrupción no es convergencia de producto ni sustituye la sonda de raíz.

Ambos recorridos tienen límite total300segundos. Ejecutar con la cola común y conservar todos
los intentos/crudos; no dispararlos desde esta preparación estática ni añadir otra full.
Revisar PNG, pose/foco postdraw, textos completos y crudos aun con resultado0. El driver no
se acredita como una prueba de ausencia de retenciones sólo porque haya terminado sus capturas.

## Pins

`manifest.json` contiene SHA256 de todos los archivos y fuentes. `estatico.log` conserva
gdformat--check/gdlint/node--check y compilación sintáctica Python. B3990 permanece limpio.
La carpeta queda congelada tras entregar los hashes; copiar a un intento propio antes de
adaptar una premisa que falle, conservando el original y explicando el delta.

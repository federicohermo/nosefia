# Preflight del carril 370

Sólo lectura; sin motor, cambios de checkout, issue publicado ni PR. Mapa inicial consultado.
La base del código observado es comber/harness; volver a medir lectores y geometría cuando el
padre entregue la base que integra 301 y 369. Contratos completos del lote salen de
feature/364-369-373-374-370-contratos y el cuerpo actual del issue está en issue-370.md.

## Cableado medido

- TareaDeLaBasura.de_la_jornada() tiene tres lectores directos: almacen.gd,
  tarea_de_la_basura_test.gd y recolector_de_basura_test.gd. Los tres pasarán jornada explícita.
- El dominio conserva ids y depositadas; la extracción necesita otro estado independiente,
  para no confundir sacar con depositar ni regenerar una bolsa al rescatarla.
- Agarre guarda capas/máscara al tomar, pone ambas en cero y las restaura al soltar.
  Por eso mantener capas originales de las bolsas y deshabilitar sólo sus CollisionShape3D
  mientras están en tacho. Al emitirse bolsa_sacada, habilitar la forma: ya está sostenida
  con capas cero, y al soltar recuperará el cuerpo físico original.
- ObjetoAgarrable guarda origen, visibilidad, capas y freeze en _ready. Su reset vuelve a
  ese estado. Las poses de origen de los tres nodos deberán medirse desde los tachos finales
  de 301; no conservar el viejo depósito ni trasladar un origen privado en runtime.
- Los tres StaticBody3D importados están bajo sus MeshInstance3D. Necesitan mallas=[..]
  con node_paths para que MarcoDelObjetivo contornee la malla real.
- El script del tacho expondrá interactuar()->null para consumir izquierdo. No tendrá usar()
  ni accionar(): así derecho seguirá hacia jugador.uso_pedido y el cableado de la raíz.
- Conectar a los tres cuerpos existentes, sin editar almacen.tscn. La raíz puede obtenerlos
  por sus tres rutas existentes y asignar al recolector el array de bolsas ya cableado.
- RedDeSeguridad no revisa colisiones desactivadas. El rescate usa lugar_de_origen() y mueve
  sólo cuerpo físico, sin resetear dominio. Verificar id estable, tacho agotado y recogida
  con izquierdo después de rescatar una bolsa previamente extraída.

## TDD y criterio

1. Primer rojo observable con firma existente: al abrir primera jornada, afirmar cero bolsas
   del dominio y ninguna bolsa visible/física en escena. Hoy son tres, sin depender de clase
   ausente ni error de parseo. Guardar stdout/stderr completo en cola.
2. Actualizar firma de apertura y fixtures de dominio: jornada2, tres tachos con identidades
   distintas; jornadas1/3/4/5, cero. AC-CLN-007. Mantener rechazos/idempotencia de depositar.
3. Probar extracción con las APIs mínimas: mano ocupada conserva todo, primera extracción
   válida entrega id y agota tacho, repetición no entrega ni deposita. AC-CLN-053.
4. Probar sistema sin escena: cuerpos tipados Node3D con datos, Agarre real auto_free y puntos
   cableados; señal tipada ejecutada una vez, misma instancia y tiempo sin consumo.
5. Escena nueva tachos_de_basura_test: desde piso transitable derivado del modelo, cuerpo
   libre, rayo/campo enfoca tacho y contorno real, bolsa no intercepta. Derecho toma cuerpo
   correcto; repetir o usar otro tacho ocupado conserva estado. AC-CLN-054/055.
6. Izquierdo, suspensión, otras jornadas, rescate y cierre con la tercera por turno en tacho,
   piso/mano. Tercera bolsa al contenedor completa y HUD+1; dos no. AC-CLN-056/057/012/038.
7. Distancia contenedor desde tachos, no bolsas antiguas ni coordenadas históricas. AC-CLN-008.
8. Nota: Tirar la basura en dominio, hoja física y quinto renglón de jornada2. AC-PLY-069.

Nuevos IDs ya entregados por contrato: AC-CLN-053 a057. No renumerar.

## Suites de inversión

El barrido actual da20 archivos. Ejecutarlos primero tras invertir la apertura; adaptar sólo
los rojos entre las rutas condicionales del issue, conservando la intención original y
registrando el resultado inicial. Helper nuevo bolsa_en_la_mano.gd abre jornada2 real y extrae
la bolsa por uso del tacho, evitando agarrar un cuerpo oculto de jornada1.

- cierre_del_almacen, agarre_fisico, consecuencias_del_contenedor, hoja_que_arrastra
- giro_parejo (código/fixture/umbrales sólo lectura), jornada_integrada
- lo_soltado_fuera_de_los_solidos, modelo_integrado (sólo lectura)
- reposicion_completa, red_de_seguridad_integrada, reposicion_manual, uso_en_el_almacen
- puestos/caja_registradora, contenedor_de_basura, lector, notas_del_almacen
- puestos/tiro_al_contenedor, tapa_del_contenedor
- objetos/ubicacion_en_el_deposito, utiles_de_limpieza

campo_de_interaccion instancia bolsa genérica propia y probablemente no necesite cambios;
igual está autorizada condicionalmente si su corrida arroja un rojo relacionado.
Modelo integrado sólo cobra array3 y enlaces: preservar cuerpos persistentes en el árbol,
ocultos y sin forma física en noches ajenas, satisface esa arquitectura sin tocar la suite.

## Capturas

Seis PNG: local/escritorio/baño, antes/después, jornada2. Búsqueda geométrica desde anillos
alrededor del bounds real: soporte de piso por rayo, cápsula de jugador libre, ojo a altura
real, mira/rayo contra cuerpo de tacho y dentro de alcance. Antes de guardar CADA cuadro,
revalidar foco y pose final dibujada; mantener luz horneada y HUD reales. No usar vista aérea
ni coordenadas inventadas. Guardar manifest de pose/foco/id/tacho/estado junto con imágenes
en scratch370-capturas, subir con capturas_a_rama.py370 y pedir al padre abrir cada PNG.

## Lazo descargado en preflight

giro_parejo_test.gd tenía comentario que situaba bolsas en depósito mientras quedaba en Sólo
lectura. Padre revisó/publicó cuerpo entero370 con permiso de cambiar sólo ese comentario;
código/fixture/umbrales permanecen Sólo lectura. Copia preparada370-issue-alcance.md.
Fila existente sin-deuda sobre comentario fuera de Se escribe que explica regla cambiada.

Pendiente exclusivamente de recibir worktree y base301+369 del padre antes de implementar.

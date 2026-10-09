# Evidencia de #302

Cabeza final congelada: `6e338bc118bb49aa9666790f461a7ab7fac968fd`; fuente idéntica a `2cba60f1`, rama `feature/302-lector-y-tickets`, sobre #298 `b22e7f8f`.
Contrato primero: `3ebe4b60`. El papel físico nuevo tiene UID `uid://cfd31mjhg3kml`;
`Venta` conserva `uid://ccoidrsttssyg` y el comprador conserva `pedido()`.

## Capturas finales

Las dos resoluciones, 1920×1080 y 1280×720, muestran el programa vacío y con tres
productos (Marolini, Marolini, Feel Ricky Fort), la caja, el lector y el papel en su
ranura. Las diez imágenes `302-*.png` corresponden al árbol congelado.
`a-302-capturas-foco-final-2.log` comprueba pose global e interpolada, cámara actual, proyección centrada y foco real de los tres cuerpos en ambas resoluciones (doce comprobaciones), y exige los marcadores de captura y desmontaje limpio;
salió 0, sin ERROR ni recursos en uso. El primer montaje, `a-302-capturas.log`, fue
rechazado porque liberaba un papel todavía enfocado: el fixture final limpia el foco
con `suspender()` antes de liberar su montaje, sin cambiar producción.

## Premisa física anterior a la fuente

`a-302-geometria.log` mide la escala de la caja y la tapa del mostrador sobre #298.
`a-302-ranura-final.log` verifica 22 sitios para caja y lector, 28 para el papel,
apoyo real del lector, cápsula libre, alcance y foco efectivo. La ranura local
(-0,475; 0,49; 0,395) gira 90° en Y; la pose mundial es ortonormal y el papel
mide 0,06 × 0,10 × 0,005 m. Su origen de rescate coincide con la pose inicial;
no se superpone con sólidos. El montaje temporal termina sin errores ni fugas.
Las tres imágenes `sonda-302-*.png` corresponden a esta medición de base.

## TDD

- El primer intento de carga `a-302-rojo.log` salió105: un tipo inferido del fixture
  y recursos fuera del bloque inicial de la escena. Es diagnóstico, no testigo TDD.
- Rojo válido `a-302-rojo-2.log`:7/7 suites,51/51 casos,101 fallos de aserción,
  cero errores, huérfanos o salteos;2,612s,report12.
- Verde ampliado `a-302-verde.log`:13/13 suites,123/123 casos, cero fallos,
  errores, huérfanos o salteos;15,806s,report13.
- Rojo de cableado adicional `a-302-rojo-cableado.log`:1/1suite,5/5casos,
  9 fallos de aserción, cero errores/huérfanos/salteos;429ms,report14.
  Ejercita las tres operaciones sin generador y la ausencia de señales.

- Rojo adicional de piso `a-302-rojo-piso.log`:1/1 suite,8/8 casos,tres fallos de eliminación,0errores/salteos/huérfanos;2,397s,report16. El papel apoya primero sobre el piso real; limpiar sin efecto sólo falla al retirarlos.
- Verde final `a-302-verde-final.log`:13/13 suites,124/124 casos,0fallos/errores/salteos/huérfanos;16,879s,report17.

## Dos convergencias completas verdes

1. Primera sobre `2cba60f1`:7/7sin salteos702,9s; conteo inmediato204/204suites,1587casos0fallos/errores/salteos/inestables;report15, `a-302-verificar-primera.log`, `full-primera-results.xml`.
2. Segunda FINAL sobre `6e338bc1`:7/7sin salteos703,3s; conteo inmediato204/204suites,1587casos0fallos/errores/salteos/inestables;report18, `a-302-verificar-final.log`, `full-final-results.xml`.

La segunda incorpora sólo el fixture de papel realmente apoyado; producción permanece idéntica a la primera cabeza. El recapturado final es posterior a ambas y no cambia tracked.

Las imágenes `evidencia/caja-sin-foco-anterior-*.png` son diagnóstico descartado: la primera captura no conservaba la pose dibujada. `a-302-capturas-foco-final.log` conserva el primer intento invalidado por un tipo inferido del fixture. Ninguno reemplaza la recaptura final verificada visualmente.

# Premisa física de la carga del contenedor

Base medida: `01bda52fac0e92b191e7c367086c9a7798e0d895`.
Diagnóstico `b-306-carga1`: una suite/un caso, 28 cuerpos reales, 27 recolocados antes
de la caída; sólo siete dentro. El primer rayo pega en el borde superior, no en el hueco.
No atribuye la variación a IDs ni a una falla del motor.

Propuesta limitada a `test/escenas/puestos/contenedor_de_basura_test.gd`, sin nuevos casos:

- La prueba de contención y cierre conserva las 28 unidades reales del productor de reposición,
  sus formas/materiales, colisiones, gravedad, grupos y red de seguridad.
- Tras retirarlas y soltarlas por Agarre, establece explícitamente la pose de arranque de cada
  caída sobre la boca. El test verifica contención física; no mide el gesto de soltado apuntado.
  Los gestos de #305 siguen cubiertos por sus suites originales.
- El alto se deriva del límite mundial de la malla del cuerpo del contenedor y de los cuerpos
  ya cargados, más el mínimo vertical de la forma real de la nueva unidad y el roce vigente.
  Conserva la orientación de cada cuerpo y los puntos XZ de carga actuales.
- Antes de avanzar física afirma forma libre con su máscara y exclusión propia. Parte sin
  velocidad lineal ni angular. No desactiva colisiones, gravedad ni seguridad; no fuerza cuerpos
  a través de paredes o tapa, ni cambia parámetros del juego.
- Conserva la caída y espera físicas, más de seis cuerpos dentro antes de cerrar, bloqueo de
  la tapa por la carga, ausencia de penetración de tapa y tolerancia original del cuerpo.
- No baja el umbral, no retira aserciones, no toca Jugador, Agarre, geometría ni arte.

Requiere whole306 publicado antes de aplicar el fixture. Luego suite original completa y FULL3
formal, preservando FULL1 y FULL2 fallidos. Los diagnósticos filtrados no son verificación final.

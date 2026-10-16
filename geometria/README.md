# Candidato de colisión A/B — 65 convexos

Investigación externa para #428, sin editar ningún worktree ni ejecutar motores. La
implementación y sus pruebas físicas pertenecen a `controles_425`. No resuelve OQ-STK-008.

El helper `convexos_gondola.py` recibe triángulos locales de Godot (Y arriba) y devuelve
65 conjuntos de puntos. Usa sólo Python estándar. El consumidor forma un casco convexo
por conjunto; NumPy/SciPy/Shapely se usaron únicamente para las auditorías externas.
No hay padding, escala nueva, cambio de máscaras ni modificación del arte.

Los 65 volúmenes son 11 del armazón, 38 de las 16 chapas y 16 escuadras. El armazón separa
espina, paneles y patas; cada pata conserva el cambio de piso junto al panel. Las chapas
separan superficie de apoyo y portaprecio. Las seis cabeceras delgadas conservan además
el quiebre entre rampa y pestaña posterior horizontal. Los cortes salen de caras fuente.
No se afirma un mínimo global matemático. Ninguna de las piezas queda contenida por otra.

## Fuentes y ejes

- GLB original del worktree de #428, sin modificar, identificado por SHA en cada JSON.
- `../medicion-ejes/blender-local-evaluado.json`, producido por el turno Blender02 de #428.
  Las versiones **evaluadas** A/B tienen 7280 triángulos, ya convertidos mediante
  `punto_en_godot`; incluyen `BEVEL`. La versión `data` de 1392 triángulos no sirve aquí.
- 81 componentes por aristas: 33 sólidas cerradas y 48 etiquetas planas de dos triángulos.
  Las planas tienen exclusivamente material «GONDOLA | Etiqueta por grupo de productos»;
  no son metal ni aportan volumen. El ancho metálico es 1,255350113 m. El ancho total
  visual 1,256744385 m incluye etiquetas que sobresalen 0,7 mm por lado.

`comparacion-blender-glb.json` compara GLB local con Blender evaluado A/B: distancia entre
nubes de vértices cero, delta de bbox cero, delta de volumen cero y violación mutua de
planos menor que 4,45e-16 m. No exige el mismo orden o diagonal de triangulación.

`comparacion-pointsets.json` compara los puntos **raw**, sin reducirlos mediante SciPy:
5270 puntos en 65 grupos, idénticos byte a byte después de `round(..., 9)`, normalización
de cero negativo a `0.0` y orden lexicográfico de grupos por bbox/puntos. SHA canónico:
`347549cabdb258bc56e77f75e80d44740b14479b8f7921c5b75d8bf36e0f9dde`.
La primera diferencia de representación `-0.0` está preservada en su JSON separado.
No hace falta implementar un casco 3D ni eliminar puntos redundantes para esa identidad.

## Verificación geométrica

`cobertura-65.json` recorta **cada triángulo completo** contra los cascos correspondientes,
une las áreas de los recortes sobre el plano del triángulo y las compara con su área
fuente. Cubre 7184/7184 triángulos físicos; área descubierta total 2,37e-14 m². Los otros
96 triángulos son las etiquetas planas identificadas. No es una prueba sólo de vértices.

Se calcularon los volúmenes orientados fuente y los solapes convexos mediante planos/LP.
Hay 16 solapes por pares y cero triples. La suma de volúmenes fuente por componente es
4,604419121 m³; la suma de sus uniones convexas es 4,642528435 m³. **No son el volumen de
la unión global:** componentes originales distintas también pueden superponerse.

`grilla-65.json` conserva 43860 rectas en tres ejes, con intervalos sólidos completos,
cero rayos con material faltante y cero paridades impares fuente. Se midieron 116646
puntos de los intervalos añadidos (extremos y mitad); peor distancia euclídea exacta
punto-triángulo: **3,000006 mm**, en el bisel de la espina. El raw de todos esos puntos
está en `grilla-65-puntos.json`. La grilla no es una cota continua de Hausdorff.

Bajo el COM real de V5 `(4.106407, 2.316035, -4.081867)`, el apoyo del candidato coincide
con la malla en Y=0,876889828 m. El antiguo contorno sostenía allí en Y=2,012327 m.
Las referencias de Saladik y cabecera también coinciden. Faltan las pruebas de contacto,
bloqueo del jugador y rendimiento en Godot; estos resultados no sustituyen ese cierre.

## Intentos conservados

- Casco global y cascos por componente rellenaban aire; no se entregan como solución.
- Primera partición de 55 pasó cuatro rayos, pero el control completo detectó un puente
  de 5,115 m³ en la espina. Incluir caras que sólo tocaban el plano del recorte como si
  ocuparan volumen causaba ese puente. Se corrigió la selección y se conservaron rojos.
- 55 convexos corregidos: cobertura completa, pero relleno de 11,7494 mm bajo el quiebre
  posterior de cabeceras. Se separaron sus dos planos reales: 61 convexos.
- 61 convexos: relleno de 6,2736 mm bajo el cambio de piso de una pata. Cuatro cortes
  derivados de esa transición producen los 65 actuales, sin atomizar toda la malla.
- El intento `certificado-continuo-65.json` **no da una cota útil**: extender planos de
  biseles lejanos recorta metros del convexo interior. Su máximo conservador de 3,09 m
  no es una penetración medida del candidato. También hubo triángulos numéricamente
  degenerados al triangular ese interior. Se conservan script/log/JSON; no se usa para
  declarar el cumplimiento continuo del roce de 4 mm.

## Reproducción sin motores

Desde esta carpeta externa, con las dependencias de auditoría ya instaladas:

1. `python generar-candidato65.py` reproduce exactamente los 65 cascos auditados en un
   archivo **nuevo**, sin sobrescribir `candidato-65.json`.
2. `python comparar-evaluada.py` y `python comparar-pointsets.py` contrastan la fuente
   Blender existente, sin ejecutar Blender.
3. `python verificar-cobertura.py --candidate candidato-65.json --output cobertura-65`
4. `python verificar-grilla.py --candidate candidato-65.json --output grilla-65`

No ejecutar el intento de certificado como prueba de aceptación. El helper y el candidato
quedan congelados para revisión de #428. Las entradas de colas y los assets no se tocaron.

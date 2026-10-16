# #426 — productos extraídos visibles

Fuente `e3f9aafcc2fdf65757b2ecd9da18126518f4322c` sobre la base #425 `bc26e68435b03298bcd8fb07524b73f3671cd7cf`. Windows, Godot 4.7.2, OpenGL API 3.3.0 NVIDIA 591.66 - Compatibility - Using Device: NVIDIA - NVIDIA GeForce RTX 4050 Laptop GPU.

Aceptación visual del control06 por el padre: Root abrió y aceptó personalmente los 16 PNG de criterios de nativo06: Saladik en mano/piso/foco/recogida/devolución; Jorgillo 1/6/7/8 e intermedia; mixtos nueve en quieto/costado/giro. Mundo y unidades visibles; ojo solicitado/real del lado interior del depósito; FINAL fallo=false y salida0. nativo05 sigue negro al cambiar sólo orientación y se conserva como incidente.

Estos son **recorridos de diagnóstico**, no reproducciones confirmadas de los reportes
originales: sus fichas no aportaban pasos ni versión. Se documentan por separado, sin causa
común atribuida y sin cambios artificiales en producción.

- GJ-23: tres Marolini, tres Saladik y tres Laysntt; extraer/soltar, caminar de costado y girar,
  conservando dibujo único y cuerpos; el origen de los grupos queda fuera del cuadro.
- GJ-24: Saladik caja→mano→piso; caída, enfoque/pérdida de foco, recogida y devolución. Las
  imágenes aceptadas son las de `nativo-06/`, con cámara fuera del espesor visual de pared.
- GJ-25: Jorgillo hasta sexta, séptima, octava y caja completa; atraviesa la capacidad inicial
  y comprueba cada índice, recogida intermedia y conservación de las otras unidades.

`crudo-02/` conserva todos los nodos, import y XML: 7/7, 267/267 suites y 2044/2044 casos.
La revisión contra #425 conserva 67 diagnósticos deliberados, sin nuevos errores/fugas.
Los controles anteriores están en `incidentes/`: su marcador funcional no acepta por sí
solo las PNG negras de Saladik. La lectura de triángulos ubica aquellas cámaras dentro de
la pared; no demuestra una causa de los reportes GJ-23/24/25 originales. Se conserva también
el incidente de parseo inicial y el control05 de orientación, sin mezclar sus resultados.

`protocolo/` conserva fixtures, wrappers y fuentes versionadas para repetir los recorridos.
Las capturas de diagnóstico no sustituyen las pruebas de transferencia ni el conteo crudo.

Sólo las **copias de texto** se normalizaron a LF, sin recodificar ni reemplazar caracteres;
las fuentes originales permanecen intactas. `manifest.json` relaciona hash/bytes originales
y publicados de cada carga, salvo él mismo. El inventario externo `426-entrega-inventario.json`
incluye también los bytes del manifiesto para auditar todos los blobs de la publicación.

# Lectura de la cámara de #426, sin motor

`python medir.py` lee el GLB de la revisión e3f9aafc y el recorrido original del control04.
No ejecuta Godot/Blender, cambia luces/GI ni modifica los fixtures02/04/05. Sólo escribe
`lectura.json` en este directorio externo. Los hashes de las cuatro entradas quedan allí.

Se decodifican las posiciones e índices reales de los 748 triángulos de `almacen-col`, con
sus matrices glTF, materiales y vértices mundiales. Se calculan baricéntricas de la proyección
XY del ojo y las intersecciones del rayo visual, usando la precisión de la pose publicada en
`recorrido.json`. No es una consulta a colliders de Godot ni una medición de la iluminación.

Las cinco capturas `gj24-*` tienen el ojo dentro del espesor visual: cara exterior en
z=−7,870003904, cara interior en z=−8,253290361 y ojo en z≈−7,903344. En `gj24-mano`, las
baricéntricas XY lo sitúan dentro de los triángulos191 y8 de esas dos caras: está33,340mm
dentro de la exterior y349,946mm delante de la interior. Ambos materiales son opacos y
`doubleSided=true`. La cara interior intersecta el rayo visual a0,435066m en mano,0,586034m
en caída y0,706302m enfocado; queda antes de los objetos que se pretendía mostrar.

Las otras14capturas registradas están fuera de ese espesor. En las tomas buenas del piso,
el ojo está en z≈−8,653301 y la primera intersección del casco es el suelo a1,834620m.
La ubicación del ojo está confundida con el orden de escenarios: Saladik en la instancia
mixta vuelve a enfocarse desde la misma posición, pero allí no hay una captura de su mano.
Por eso las imágenes disponibles no aíslan una falla exclusiva de la primera instancia.

Control posterior propuesto al padre: conservar luz/GI, ubicar cámara y cuerpo en piso libre
del lado interior del depósito, fuera del espesor, y repetir el gesto real. El control05 que
sólo cambia la orientación permanece intacto en su turno. Hasta medir ese control de ubicación,
esto identifica una premisa visual inválida del fixture; no atribuye una causa de producción.

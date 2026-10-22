# Compradores de la primera jornada

Los PNG originales se copiaron de `origin/modelossupermercado`, revisión
`379df911f49eafffc273fcaa84490d848b620f1c`.

| Destino | Origen (01 a 08, en orden) |
|---|---|
| `martin/` | `assets/personajes/Martin/nuevomartin-idle NN.png` |
| `tiago/` | `assets/personajes/Tia/Tia-idle NN.png` |

## Limpieza del alfa

El recorte original deja píxeles con alfa de 1 a 3 sobre 255 fuera de la figura.
El contorno de foco los convierte en manchas opacas.
El script compartido limpia esos valores en todos los cuadros junto a un `idle.tres`.
Después elimina islas separadas cuya opacidad máxima no supera 13 sobre 255.
La conectividad considera los ocho vecinos, incluidas las diagonales.
Conserva las dimensiones, todos los canales RGB y el alfa superior a 3 de la figura conectada.
Una segunda aplicación no vuelve a guardar los PNG limpios.

```powershell
& $env:GODOT_BIN --headless --path . --script .github/scripts/limpiar_alfa_compradores.gd
& $env:GODOT_BIN --headless --path . --script .github/scripts/limpiar_alfa_compradores.gd -- --aplicar
```

La primera llamada sólo informa. La segunda guarda la limpieza.
Los originales de Fede y Mía están identificados en [su procedencia](jornada_2_origen.md).

Los textos salen de [Manada — UI](https://www.figma.com/design/SQEAfczyRvyOHokmzPOee7/Manada---UI?node-id=510-240).
Las capas de Martín están superpuestas al marco como hermanas en la página: texto inicial
`510:245`, `510:251`, `510:256`, despedida `510:261`, rechazos `568:655` y `568:663`.
Tiago usa `510:267`, `510:271`, `510:278`, `510:282`, `510:286` y rechazo `571:678`.
El recordatorio no está en Figma: une el pedido con el «Quiero» de los rechazos.

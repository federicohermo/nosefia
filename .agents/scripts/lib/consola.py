"""Que la salida en español no rompa el script en Windows.

## El bug, tal cual apareció

`verificar.py` corrió bien, imprimió los seis nodos, y **después** se cayó:

    UnicodeEncodeError: 'charmap' codec can't encode characters in position 2-3

Cuando la salida de Python en Windows no va a una consola sino a una tubería o a un archivo
—que es como la lee la CI, y como la lee un agente—, el encoding por defecto es el del
sistema: en una instalación en español, **cp1252**. Ahí no entran ni `──` ni `→`, y las
vocales acentuadas entran a veces. O sea que **todo este harness, que está escrito en
español, se cae al imprimir su propio reporte**.

Lo peor no es el reporte de `verificar.py`: es el gate del hook. Su mensaje de bloqueo dice
«La rama … no nombra un spec», con acento, y se lo escribe a stdout como JSON. Sin esto,
bloquear se convierte en caerse — y un hook que se cae en vez de contestar es un hook que
alguien apaga.

## Por qué `errors="replace"` y no `strict`

Porque el que llama a esto está por imprimir un reporte, y perder una tilde es infinitamente
mejor que perder el reporte. La corrección de verdad es el `utf-8`; el `replace` es el
seguro para el carácter que igual no entre.
"""

import sys


def configurar() -> None:
    """Pone stdout y stderr en UTF-8. Se llama una vez, al principio de cada script."""
    for flujo in (sys.stdout, sys.stderr):
        # `reconfigure` existe desde 3.7 en los flujos de texto, pero un flujo redirigido por
        # un test puede ser un `StringIO`, que no lo tiene. Que un doble no lo soporte no es
        # motivo para que el script se caiga.
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")

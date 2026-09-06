"""Que la URL publicada sirva un juego, y no una página que carga para siempre.

    python .claude/scripts/verificar_despliegue.py https://<proyecto>.vercel.app

Sale **0** si los cuatro archivos contestan 200 con los dos headers de aislamiento, el
`Cache-Control` con `must-revalidate` y el `.wasm` con su `Content-Type`; **1** en cuanto uno
de los cuatro falle. Es la mitad HTTP de «publicar no es haber publicado»: la otra —que el
juego arranque de verdad en un navegador— la corre `.github/scripts/humo_en_navegador.mjs`,
porque un deploy sano por HTTP todavía puede quedar negro en pantalla.

Lo que decide vive en `lib/despliegue.py` —y ahí están los tests, con la respuesta inyectada—;
acá está la red y el código de salida.
"""

import os
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.despliegue import Respuesta, problemas_de_la_publicacion  # noqa: E402

#: Cuánto se espera cada pedido. Un despliegue recién hecho puede tardar en propagarse, pero
#: colgarse para siempre en la CI es peor que fallar: un job que no termina no avisa nada.
ESPERA = 30


def pedir(url: str) -> Respuesta:
    """Un `HEAD` a la URL. Lo que se mira son los headers y el estado, no el cuerpo.

    Es `HEAD` y no `GET` por una razón medida: el `.wasm` son decenas de megas y este script
    corre en cada deploy. Bajarlo para leer su `Content-Type` sería bajar el juego entero
    cuatro veces por publicación.

    Un 404 **no es una excepción**: es la respuesta que este script existe para ver, así que el
    `HTTPError` se traduce a un `Respuesta` en vez de subir. Lo que sí sube es no poder
    preguntar —DNS, TLS, la red—, que es otra cosa y se reporta como tal.
    """
    peticion = urllib.request.Request(url, method="HEAD")
    try:
        with urllib.request.urlopen(peticion, timeout=ESPERA) as respuesta:
            return Respuesta(respuesta.status, dict(respuesta.headers))
    except urllib.error.HTTPError as error:
        return Respuesta(error.code, dict(error.headers or {}))


def main() -> None:
    if len(sys.argv) != 2:
        print("uso: verificar_despliegue.py <URL>", file=sys.stderr)
        sys.exit(2)

    url = sys.argv[1]
    try:
        problemas = problemas_de_la_publicacion(url, pedir)
    except urllib.error.URLError as error:
        print(f"no se pudo preguntarle a `{url}`: {error.reason}")
        sys.exit(1)

    if not problemas:
        print(f"`{url}` sirve un juego: los cuatro archivos, los dos headers y el `.wasm`.")
        sys.exit(0)

    for problema in problemas:
        print(problema)
    print(
        f"\n{len(problemas)} {'problema' if len(problemas) == 1 else 'problemas'} en la "
        "publicación. El deploy puede estar en verde igual: contestar 200 no es servir un juego."
    )
    sys.exit(1)


if __name__ == "__main__":
    main()

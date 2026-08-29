"""Lanzar `gh` diciendo qué falta cuando falta, en vez de tirar un `FileNotFoundError` crudo.

Los cuatro scripts que hablan con GitHub invocan `gh`. Sin `gh` en el PATH eso muere con un
traceback que **no nombra ni a `gh` ni al PATH** y no dice qué hacer.

## Por qué duele más de lo que parece

`specs/[0-9]*/` está en el `.gitignore`, así que un clone nuevo llega sin un solo spec.
Hidratar es el único camino a los criterios de aceptación: sin `gh`, un agente que va a
revisar o implementar un spec **lee un directorio vacío, no encuentra los AC y sigue igual**
— que es la peor forma de este bug, porque el trabajo termina y reporta.

## Las dos mitades, y por qué son dos

1. **Buscar `gh` donde suele estar.** En Windows el instalador lo deja en
   `C:\\Program Files\\GitHub CLI\\` y **no agrega la carpeta al PATH**. Encontrarlo ahí
   convierte un fallo duro en un aviso.
2. **Y si tampoco está, morir diciendo cómo salir.** Un error que no dice qué hacer produce
   el reflejo de buscar cómo esquivarlo.

## Por qué el entorno se inyecta

Por lo mismo que en `rutas_protegidas.py`: el modo de falla que importa es «no hay `gh` en
esta máquina», y una máquina que sí lo tiene no puede fabricarlo. Con `ejecutar`, `existe` y
`plataforma` por parámetro, los tres caminos —lo encuentra en el PATH, lo rescata de una
ubicación conocida, no lo encuentra— se prueban sin tocar el PATH del que corre los tests.
"""

import os
import subprocess
import sys
from collections.abc import Callable, Sequence

#: Dónde deja `gh.exe` el instalador de Windows, en orden de preferencia.
#:
#: Son las dos rutas del instalador oficial —64 y 32 bits—. Deliberadamente **no** se busca
#: por todo el disco: esto es un rescate para la instalación estándar, no un localizador. Si
#: alguien lo instaló en otro lado, el mensaje le dice que lo agregue al PATH, que es la
#: solución que además arregla todas las otras herramientas.
UBICACIONES_WINDOWS: tuple[str, ...] = (
    r"C:\Program Files\GitHub CLI\gh.exe",
    r"C:\Program Files (x86)\GitHub CLI\gh.exe",
)


def mensaje_sin_gh(plataforma: str) -> str:
    """El mensaje de «no hay `gh`», que es lo único que se lleva el que lo lea.

    Dice las tres cosas que el traceback no decía: **qué** falta, **dónde suele estar** y
    **cómo seguir**. La ubicación sólo se nombra en Windows porque en POSIX el gestor de
    paquetes ya lo pone en el PATH y la línea sería ruido.
    """
    if plataforma == "win32":
        ubicaciones = "\n".join(f"  {u}" for u in UBICACIONES_WINDOWS)
        donde = (
            "\nEn Windows el instalador lo deja en una de estas y NO la agrega al PATH:\n"
            f"{ubicaciones}\n"
            "Si está ahí, agregá esa carpeta al PATH de usuario y abrí una terminal nueva.\n"
        )
    else:
        donde = "\n"

    return (
        "No se encontró `gh`, el CLI de GitHub, y sin él este script no puede leer los issues.\n"
        f"{donde}"
        "\nSi no está instalado: https://cli.github.com — y después `gh auth login`."
    )


def mensaje_sin_sesion(salida_de_gh: str) -> str:
    """El mensaje de «`gh` está pero no hay sesión».

    Es el otro fallo que se confunde con «el script está roto»: `gh` existe, arranca, y
    contesta que no hay credenciales. Sin esta rama, el que lo lea ve un exit distinto de
    cero y la salida de `gh` mezclada con el traceback.
    """
    return (
        "`gh` está instalado pero la sesión de GitHub no sirve para esta consulta.\n"
        f"Lo que contestó:\n{salida_de_gh.strip()}\n\n"
        "La salida es `gh auth login` (o `gh auth status` para ver qué cuenta está activa)."
    )


def crear_gh(
    ejecutar: Callable[[str, Sequence[str], str | None], str],
    existe: Callable[[str], bool],
    plataforma: str,
    avisar: Callable[[str], None],
    morir: Callable[[str], None],
) -> Callable[[Sequence[str], str | None], str]:
    """Un lanzador de `gh` que explica sus fallos.

    El ejecutable se resuelve **perezosamente y una sola vez**: la primera llamada usa `gh` a
    secas para que el PATH gane cuando lo hay, y sólo si eso no lo encuentra se busca en las
    ubicaciones conocidas. Resolverlo por adelantado invertiría esa preferencia y podría
    elegir una instalación vieja del disco por sobre la que el PATH declara.
    """
    estado = {"bin": "gh", "rescatado": False}

    def lanzar(args: Sequence[str], entrada: str | None = None) -> str:
        try:
            return ejecutar(estado["bin"], args, entrada)
        except FileNotFoundError:
            pass
        except subprocess.CalledProcessError as e:
            # `gh` corrió y falló. La sesión es el motivo que se puede nombrar; cualquier
            # otro se deja subir tal cual, porque inventarle una explicación a un fallo que
            # no se reconoce es peor que mostrar el original.
            stderr = e.stderr if isinstance(e.stderr, str) else ""
            if any(p in stderr.lower() for p in ("auth login", "not logged", "authentication")):
                morir(mensaje_sin_sesion(stderr))
            raise

        # Ya se rescató una vez y volvió a faltar: la ubicación conocida tampoco sirve.
        if estado["rescatado"]:
            morir(mensaje_sin_gh(plataforma))

        candidato = None
        if plataforma == "win32":
            candidato = next((u for u in UBICACIONES_WINDOWS if existe(u)), None)
        if candidato is None:
            morir(mensaje_sin_gh(plataforma))

        avisar(
            f"aviso: `gh` no está en el PATH; se usa {candidato}.\n"
            "       Agregá esa carpeta al PATH para que el resto de las herramientas también lo vea."
        )
        estado["bin"] = candidato
        estado["rescatado"] = True

        # El reintento va protegido: un archivo que existe pero no se puede ejecutar —un
        # `gh.exe` de otra arquitectura, un enlace roto— vuelve a dar `FileNotFoundError` y
        # se escaparía crudo, que es exactamente el error que este módulo existe para no
        # dejar salir. El guardia de `rescatado` no alcanza: recién corre en la llamada
        # SIGUIENTE, y acá no hay ninguna.
        try:
            return ejecutar(estado["bin"], args, entrada)
        except FileNotFoundError:
            morir(mensaje_sin_gh(plataforma))
            raise  # `morir` no vuelve; esto es para el type checker y para un doble mal escrito.

    return lanzar


def _ejecutar(binario: str, args: Sequence[str], entrada: str | None) -> str:
    resultado = subprocess.run(
        [binario, *args],
        input=entrada,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    return resultado.stdout


def _morir(mensaje: str) -> None:
    print(f"\n{mensaje}\n", file=sys.stderr)
    sys.exit(1)


#: El lanzador con el entorno del proceso, que es el que usan los scripts.
#:
#: Vive acá y no en cada script por el mismo motivo por el que existe el módulo: el cableado
#: es idéntico en los cuatro, y escribirlo cuatro veces es la forma de que uno quede sin el
#: rescate el día que alguien toque otro.
gh = crear_gh(
    ejecutar=_ejecutar,
    existe=os.path.isfile,
    plataforma=sys.platform,
    # A `stderr` y no a `stdout`: la salida de estos scripts es un reporte que se lee de
    # corrido, y un aviso en el medio lo ensucia sin que nadie lo distinga de una línea de
    # progreso.
    avisar=lambda m: print(m, file=sys.stderr),
    morir=_morir,
)


def gh_json(args: Sequence[str]) -> object:
    """`gh` devolviendo JSON ya parseado. Es la forma en que lo usan los cuatro scripts."""
    import json

    return json.loads(gh(args))

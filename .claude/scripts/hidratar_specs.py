"""Trae los specs desde sus issues y reconstruye `specs/NNN-<slug>/`.

El registro **vive en GitHub Issues** y `specs/[0-9]*/` está en el `.gitignore`. O sea que un
clone nuevo, y sobre todo un **worktree**, no los tiene: `git worktree add` hace checkout de
lo trackeado, y un archivo ignorado no viaja.

Eso rompe en silencio a cualquier agente que corra en su propio worktree y lea
`specs/NNN-…/spec.md` desde ahí: **lee un directorio vacío, no encuentra los criterios de
aceptación y revisa igual**. Este script es lo que lo cierra.

## Explícito y no un hook

Se corre a mano. Un hook en `worktree add` bajaría N issues cada vez, es lento y falla sin
red — y falla **en medio de otra cosa**, que es donde un error se lee como ruido. Explícito,
el fallo está a la vista.

## El default trae los que están EN VUELO, no todos

El caso normal es querer **uno**: el que se está implementando. Traer los cerrados también son
N llamadas a `gh` y un montón de archivos para leer uno.

Las tres formas **declaran cuántas saltearon y por qué**: un default que trae menos y no lo
dice se lee como «ese spec no existe», que es peor que traer de más.

Uso:
    python .claude/scripts/hidratar_specs.py            # los que estén en vuelo y falten
    python .claude/scripts/hidratar_specs.py 007 012    # sólo ésos, estén como estén
    python .claude/scripts/hidratar_specs.py --todos    # todos los que falten
    python .claude/scripts/hidratar_specs.py --forzar   # rehace los que ya están
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.gh import gh  # noqa: E402
from lib.repo import RAIZ, REPO  # noqa: E402
from lib.specs import archivo_de_comentario, carpeta_existente, en_vuelo, leer_mapa  # noqa: E402

SPECS = RAIZ / "specs"


def ya_en_disco() -> list[str]:
    """Las carpetas de spec que ya están, para no crear una segunda al cambiar un título."""
    return [
        e.name
        for e in SPECS.iterdir()
        if e.is_dir() and re.match(r"^\d{3}-", e.name)
    ]


def main() -> None:
    args = sys.argv[1:]
    forzar = "--forzar" in args
    todos = "--todos" in args
    pedidos = [a for a in args if re.fullmatch(r"\d{3}", a)]

    # `leer_mapa` grita si el archivo está roto, en vez de devolver un mapa sin entradas — que
    # se leería como «no hay nada que hidratar», que es lo contrario de lo que pasa.
    mapa = leer_mapa((SPECS / "mapa.json").read_text(encoding="utf-8"))
    ids = sorted(mapa)

    # Un `NNN` que no está en el mapa **no se ignora**: se dice. Pedir un spec que el registro
    # no conoce es un número mal escrito o un spec sin publicar, y las dos veces la respuesta
    # útil es el aviso y no una corrida vacía.
    desconocidos = [i for i in pedidos if i not in ids]
    if desconocidos:
        print(
            f"OJO: {', '.join(desconocidos)} no tiene entrada en specs/mapa.json — "
            "¿el número está bien?"
        )

    if pedidos:
        a_hidratar = [i for i in ids if i in pedidos]
        motivo_del_recorte = "no los pediste"
    else:
        a_hidratar = [i for i in ids if todos or en_vuelo(mapa[i]["estado"])]
        motivo_del_recorte = "ya están cerrados — `--todos` los trae"

    salteados = len(ids) - len(a_hidratar)
    hechos = 0
    ya_estaban = 0

    for id_spec in a_hidratar:
        entrada = mapa[id_spec]

        # La que ya esté manda sobre el nombre del mapa: emparejar por `NNN` es lo que evita
        # una segunda carpeta para el mismo spec cuando una caché vieja quedó con otro nombre.
        #
        # Y va ANTES del `gh`: la corrida típica es «los que falten» sobre un checkout casi
        # completo, así que preguntar primero ahorra las llamadas de red que después se iban a
        # descartar.
        nombre = carpeta_existente(ya_en_disco(), id_spec)

        # Una caché con el nombre viejo se RENOMBRA. Sin esta rama, volver a hidratar —hasta
        # con `--forzar`— reescribiría adentro de la carpeta vieja y nunca la renombraría:
        # seguir el consejo no cambiaría nada.
        if nombre is not None and nombre != entrada["carpeta"]:
            if (SPECS / entrada["carpeta"]).exists():
                # Dos carpetas con el mismo NNN es el estado que `carpeta_existente` viene a
                # evitar. Renombrar encima tiraría un error que no dice esto, así que se dice.
                print(
                    f"{id_spec}  OJO: conviven {nombre}/ y {entrada['carpeta']}/ — "
                    "borrar la que sobra a mano"
                )
            else:
                (SPECS / nombre).rename(SPECS / entrada["carpeta"])
                print(
                    f"{id_spec}  renombrada {nombre}/ → {entrada['carpeta']}/  "
                    "(el mapa manda sobre el nombre)"
                )

        # El nombre sale del MAPA y no del título ni del disco, y el renombrado de arriba es lo
        # que hace que eso sea cierto.
        destino = entrada["carpeta"]
        if nombre is not None and not forzar:
            ya_estaban += 1
            print(f"{id_spec}  ya está ({destino}/)")
            continue

        datos = json.loads(
            gh(
                ["issue", "view", str(entrada["issue"]), "--repo", REPO,
                 "--json", "title,body,comments"]
            )
        )

        carpeta = SPECS / destino
        carpeta.mkdir(parents=True, exist_ok=True)
        (carpeta / "spec.md").write_text(datos["body"], encoding="utf-8")

        n = 1
        for c in datos["comments"]:
            archivo = archivo_de_comentario(c["body"])
            # Un comentario sin el encabezado no es un archivo: es una discusión del issue, y
            # ésas NO se escriben al disco. Es la única forma de distinguirlos, y por eso el
            # encabezado que pone `publicar_spec.py` no es decorativo.
            if archivo is None:
                continue
            (carpeta / archivo[0]).write_text(archivo[1], encoding="utf-8")
            n += 1

        hechos += 1
        print(f"{id_spec}  #{entrada['issue']} → {destino}/  ({n} archivos)")

    # El resumen dice las TRES cantidades y no sólo la primera. La que importa es la tercera:
    # sin ella, un default que mira 1 de 20 se ve igual que un registro de 1.
    partes = [f"hidratados: {hechos} de {len(a_hidratar)}"]
    if ya_estaban:
        partes.append(f"{ya_estaban} ya estaban")
    if salteados:
        partes.append(f"{salteados} salteados ({motivo_del_recorte})")
    print(f"\n{'; '.join(partes)}")


if __name__ == "__main__":
    main()

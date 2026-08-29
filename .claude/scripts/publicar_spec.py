"""Publica los specs de `specs/NNN-…/` como issues de GitHub.

## Por qué `gh` y no el MCP de GitHub

Por el contexto. Por el MCP, cada archivo tiene que pasar por el contexto del agente dos
veces —al leerlo y al escribirlo como parámetro—, y el modo de falla es el peor posible:
quedarse a mitad, con la mitad de los issues creados y el mapa incompleto. Con `gh` el
contenido va del disco a la API sin pasar por el medio.

## Dos fases, y por qué no una

Los specs se citan entre sí. Para traducir `./005-…/spec.md` a la URL de su issue hace falta
que el issue del 005 ya exista, así que **no se puede traducir en la misma pasada que crea**.

    fase `crear`     — un issue por spec, con un cuerpo mínimo, y se anota el mapa.
    fase `publicar`  — con el mapa completo, se sube el contenido ya traducido.

El mapa se persiste en disco entre las dos, así que la fase 2 se puede repetir sin volver a
crear nada. Las dos son idempotentes a propósito: una API que se llama muchas veces falla a
la mitad alguna vez.

Uso:
    python .claude/scripts/publicar_spec.py crear     [--dry]
    python .claude/scripts/publicar_spec.py publicar  [--dry]
"""

import json
import os
import re
import sys
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.gh import gh as lanzar_gh  # noqa: E402
from lib.repo import RAIZ, REPO  # noqa: E402
from lib.specs import (  # noqa: E402
    NOMBRE_PUBLICABLE,
    en_vuelo,
    escribir_mapa,
    estado_de,
    leer_mapa,
    origen_de,
    traducir,
)

SPECS = RAIZ / "specs"

#: **El mapa es uno solo y está trackeado.** Es a la vez la fuente y el buffer entre crear el
#: issue y anotar su fila: si esas dos cosas vivieran en archivos distintos y el buffer
#: estuviera en un directorio ignorado, vaciar `specs/` —que es lo normal, es caché— lo
#: borraría, y la corrida siguiente de `crear` no reconocería ni un spec. Serían N issues
#: duplicados sin un solo error.
MAPA_JSON = SPECS / "mapa.json"

#: El `spec.md` va al body del issue; todo el resto va como comentario.
CUERPO = "spec.md"

#: Los `.md` de la carpeta que NO son el body, en orden de lectura.
#:
#: Los tres canónicos van primero y en su orden; cualquier otro va detrás, alfabético. Que la
#: lista no sea cerrada es el punto: un spec puede agregar un `baseline.md` con una medición
#: previa o un `reparto.md`, y una lista hardcodeada lo dejaría **afuera sin decir nada** —o
#: sea perdido, porque `specs/[0-9]*/` está ignorado y la hidratación siguiente se lo lleva
#: puesto.
CANONICOS = ("research.md", "plan.md", "tasks.md")

#: El límite de un body y de un comentario de GitHub.
#:
#: Si algún día se pasa, se parte en dos comentarios — pero que falle fuerte y no que GitHub
#: lo trunque en silencio.
LIMITE_DE_COMENTARIO = 65536


def carpetas_de_specs() -> list[str]:
    return sorted(
        e.name
        for e in SPECS.iterdir()
        if e.is_dir() and len(e.name) > 3 and e.name[:3].isdigit() and e.name[3] == "-"
    )


def comentarios_de(carpeta: str) -> list[str]:
    """Los `.md` publicables de una carpeta, en orden de lectura.

    Lo que no entra en el alfabeto **grita** en vez de quedar afuera en silencio, y no es
    exageración: `specs/[0-9]*/` está ignorado, así que un `.md` no publicado no queda «para
    la próxima» — se pierde en la hidratación siguiente. El arreglo es renombrar el archivo.
    """
    todos = [f.name for f in (SPECS / carpeta).iterdir() if f.suffix == ".md" and f.name != CUERPO]
    afuera = [f for f in todos if not NOMBRE_PUBLICABLE.match(f)]
    if afuera:
        raise SystemExit(
            f"{carpeta}: {', '.join(afuera)} no se puede publicar y specs/ está ignorado, así que "
            "se perdería al hidratar. El nombre va en minúsculas, dígitos y guiones: [a-z0-9-]+.md"
        )
    extras = sorted(f for f in todos if f not in CANONICOS)
    return [f for f in CANONICOS if f in todos] + extras


def titulo_de(carpeta: str) -> str:
    """`# Spec 007 — La ventanilla` → el título del issue, tal cual."""
    primera = (SPECS / carpeta / CUERPO).read_text(encoding="utf-8").splitlines()[0]
    titulo = primera.lstrip("#").strip()
    if not titulo:
        raise SystemExit(f"{carpeta}/{CUERPO} no arranca con un encabezado")
    return titulo


def origen_de_carpeta(carpeta: str) -> list[int] | None:
    """Los issues que el spec declara saldar, o `None` si no declara ninguno."""
    return origen_de((SPECS / carpeta / CUERPO).read_text(encoding="utf-8"))


def main() -> None:
    fase = sys.argv[1] if len(sys.argv) > 1 else ""
    dry = "--dry" in sys.argv

    if fase not in ("crear", "publicar"):
        print("uso: python .claude/scripts/publicar_spec.py crear|publicar [--dry]", file=sys.stderr)
        sys.exit(1)

    def gh(args: list[str], entrada: str | None = None) -> str:
        if dry:
            extra = f"(+{len(entrada)}B)" if entrada else ""
            print(f"   [dry] gh {' '.join(args[:6])} {extra}")
            return "DRY"
        return lanzar_gh(args, entrada).strip()

    def guardar_mapa(mapa: dict) -> None:
        """**En `--dry` no se escribe.**

        No es prolijidad: un mapa con los números en 0 haría que la corrida de verdad viera
        «ya existe» para todos y no creara ninguno, dejando el trabajo hecho a medias sin un
        solo error. Es el mismo «fallar en verde» que este script existe para no cometer.
        """
        if dry:
            return
        MAPA_JSON.write_text(escribir_mapa(mapa), encoding="utf-8")

    carpetas = carpetas_de_specs()
    mapa = leer_mapa(MAPA_JSON.read_text(encoding="utf-8"))

    if fase == "crear":
        crear(carpetas, mapa, gh, guardar_mapa, dry)
    else:
        publicar(carpetas, mapa, gh, dry)


def crear(carpetas, mapa, gh, guardar_mapa, dry) -> None:
    for carpeta in carpetas:
        id_spec = carpeta[:3]
        if id_spec in mapa:
            print(f"{id_spec}  ya existe → #{mapa[id_spec]['issue']}")
            continue

        # **Todo lo que lee el disco va ANTES del `issue create`**, y no es orden estético:
        # crear el issue es lo único irreversible del bucle. Un `**Origen:**` que no nombra
        # ningún `#N` hace gritar a `origen_de` —a propósito—, y si ese grito saliera después
        # del `create`, el issue ya existiría con el mapa sin su fila: la corrida siguiente no
        # reconocería el spec y abriría un issue DUPLICADO.
        titulo = titulo_de(carpeta)
        origen = origen_de_carpeta(carpeta)

        url = gh(
            [
                "issue", "create", "--repo", REPO,
                "--title", titulo,
                # Cuerpo mínimo a propósito: el de verdad lo sube la fase 2, ya traducido. Si
                # esto quedara publicado por un fallo a mitad, dice que le falta.
                "--body",
                f"Spec `{carpeta}`. El contenido lo sube la fase 2 de `publicar_spec.py`.",
            ]
        )
        numero = 0 if dry else int(url.rstrip("/").rsplit("/", 1)[-1])

        mapa[id_spec] = {
            "issue": numero,
            "carpeta": carpeta,
            # La fecha es la de hoy: es el día en que el spec se escribió, y publicarlo es el
            # mismo día.
            "fecha": date.today().isoformat(),
            # Un spec recién publicado no puede estar en otro estado.
            "estado": "Propuesto",
            "titulo": titulo,
        }
        # El sexto campo, y **sólo si el spec lo declara**: sin la línea `**Origen:**` la fila
        # no trae el campo, no lo trae vacío.
        if origen is not None:
            mapa[id_spec]["origen"] = origen
        guardar_mapa(mapa)
        print(f"{id_spec}  creado → #{numero}")

    # **`origen` se reconcilia en cada corrida, y es el único campo de la fila que lo hace.**
    # Los otros cinco describen la publicación o son cosas que el spec no vuelve a decir.
    # `origen` sí: es una línea del `spec.md`, y `specs/README.md` la declara la fuente única.
    # Sin esto la declaración sería falsa apenas el spec queda publicado — el bucle de arriba
    # cortocircuita en `continue`, así que agregar o corregir el `**Origen:**` después no
    # llegaría NUNCA al mapa, y nada compararía los dos.
    #
    # Va DESPUÉS del bucle que crea, por el mismo motivo que allá arriba las dos lecturas de
    # disco van antes del `create`: `origen_de` grita ante un `**Origen:**` mal escrito, y un
    # spec viejo roto en la caché no tiene por qué impedir que se publique uno nuevo.
    #
    # Y mira sólo las carpetas que están en disco: `specs/` es caché, así que un spec no
    # hidratado no dice nada sobre su `origen` — y «no dice» no es «no tiene».
    def muestra(o):
        return "(sin origen)" if o is None else ", ".join(f"#{n}" for n in o)

    reconciliados = 0
    for carpeta in carpetas:
        id_spec = carpeta[:3]
        declarado = origen_de_carpeta(carpeta)
        en_el_mapa = mapa[id_spec].get("origen")
        if declarado == en_el_mapa:
            continue
        if declarado is None:
            mapa[id_spec].pop("origen", None)
        else:
            mapa[id_spec]["origen"] = declarado
        guardar_mapa(mapa)
        reconciliados += 1
        print(f"{id_spec}  origen: {muestra(en_el_mapa)} → {muestra(declarado)}")

    print(f"\nmapa: {len(mapa)} specs en {MAPA_JSON}")
    print(
        f"{len(carpetas)} carpetas hidratadas, {reconciliados} con el `origen` puesto al día "
        "contra su `spec.md`"
    )


def publicar(carpetas, mapa, gh, dry) -> None:
    faltan = [c for c in carpetas if c[:3] not in mapa]
    if faltan:
        raise SystemExit(f"el mapa no tiene: {', '.join(faltan)} — corré la fase «crear» primero")

    for carpeta in carpetas:
        id_spec = carpeta[:3]
        numero = mapa[id_spec]["issue"]

        gh(
            ["issue", "edit", str(numero), "--repo", REPO, "--body-file", "-"],
            traducir((SPECS / carpeta / CUERPO).read_text(encoding="utf-8"), mapa, REPO),
        )

        # Los comentarios que ya están, por el archivo que representan. **Sin esto el script
        # no es idempotente**: `gh issue comment` AGREGA uno nuevo cada vez, así que una
        # segunda corrida deja 6 comentarios donde tiene que haber 3. Y no falla: duplicar en
        # silencio es peor que romper.
        if dry:
            actual = {"comments": [], "state": "OPEN"}
        else:
            actual = json.loads(
                gh(["issue", "view", str(numero), "--repo", REPO, "--json", "comments,state"])
            )

        ya_estan: dict[str, str] = {}
        for c in actual["comments"]:
            # El mismo alfabeto que `NOMBRE_PUBLICABLE`, sin el ancla de fin: acá lo que sigue
            # es el cuerpo del archivo. Si esto reconociera menos nombres que los que se
            # suben, la segunda corrida no vería el comentario que ella misma escribió y
            # agregaría uno nuevo.
            m = re.match(r"^##\s+`([a-z0-9-]+\.md)`", c["body"])
            if m:
                ya_estan[m.group(1)] = c["url"].rsplit("-", 1)[-1]

        n = 0
        for archivo in comentarios_de(carpeta):
            ruta = SPECS / carpeta / archivo
            cuerpo = f"## `{archivo}`\n\n{traducir(ruta.read_text(encoding='utf-8'), mapa, REPO)}"
            bytes_ = len(cuerpo.encode("utf-8"))
            if bytes_ > LIMITE_DE_COMENTARIO:
                raise SystemExit(f"{carpeta}/{archivo}: {bytes_} B, no entra en un comentario")

            existente = ya_estan.get(archivo)
            if existente:
                gh(
                    ["api", "--method", "PATCH", f"repos/{REPO}/issues/comments/{existente}",
                     "--field", "body=@-", "--silent"],
                    cuerpo,
                )
            else:
                gh(["issue", "comment", str(numero), "--repo", REPO, "--body-file", "-"], cuerpo)
            n += 1

        # Los terminales y los implementados se cierran; `Propuesto` queda abierto.
        #
        # **Un estado que no se pudo leer NO cierra.** Sin esta guarda, un spec que todavía no
        # tiene fila caería en el `else` y se cerraría — que es lo contrario de lo correcto,
        # porque un spec recién escrito es justamente el que tiene que quedar abierto.
        #
        # Y **sólo si está abierto**: `gh issue close` sobre uno ya cerrado devuelve error, así
        # que sin esa condición el script se cae en la segunda corrida.
        estado = estado_de(mapa, id_spec)
        if estado is None:
            print(f"{id_spec}  SIN ESTADO en el registro: se deja abierto y no se toca")
        elif not en_vuelo(estado) and actual["state"] == "OPEN":
            gh(
                ["issue", "close", str(numero), "--repo", REPO, "--reason",
                 "not planned" if estado == "Descartado" else "completed"]
            )
        print(f"{id_spec}  #{numero}  body + {n} comentarios  [{estado}]")


if __name__ == "__main__":
    main()

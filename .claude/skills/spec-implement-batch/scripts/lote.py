"""Insumo del Paso 2 de spec-review-batch: de qué se agarra un spec del lote y qué le mueve otro.

Uso, desde cualquier lado —la raíz sale de `__file__`, no del CWD—, y son las tres formas del
`argument-hint` del skill:

    python .claude/skills/spec-review-batch/scripts/lote.py 001 002 003
    python .claude/skills/spec-review-batch/scripts/lote.py 001-003
    python .claude/skills/spec-review-batch/scripts/lote.py --propuestos

El SKILL.md lo **inyecta** al cargar, así que su salida llega con el skill ya puesto en vez de
costar un turno de tool. Por eso entiende las tres formas: recibe crudo lo que el usuario tipeó,
y `--dry` —que es un flag del skill y no del script— se ignora en vez de rechazarse.

Emite tres bloques, y ninguno es una conclusión:

  1. matriz archivo x spec   — qué archivo tocan dos o más specs. Dice **dónde mirar**, nada más:
                               dos specs en regiones lejanas del mismo `.gd` no se contradicen.
                               La excepción es el `.tscn`, y por eso sale marcado aparte: un
                               merge de tres vías sobre una escena no da un conflicto, da una
                               escena corrupta. Ahí compartir el archivo **sí** es la conclusión.
  2. tareas que lo citan     — las líneas, con número, de cada archivo compartido. Es lo que
                               decide si los dos specs escriben la misma función o no, y es
                               también donde se ve si el de abajo cita una línea que el de
                               arriba reescribe: esa cita está podrida por construcción.
  3. números que se mueven   — los pares `X -> Y` de cada línea de tarea. En el repo del que sale
                               este harness los devolvía una tool del dominio; acá no hay ninguna,
                               así que salen de acá o no salen. Es la arista que ningún `preload`
                               ni ningún `class_name` delata.

Lo que NO hace, a propósito: decidir. Filtrar las menciones que vienen de una tarea de
documentación depende del verbo de la tarea, y un script que lo adivine se equivoca en silencio.
"""

import re
import sys
from pathlib import Path

# La raíz sale de buscar `.claude/scripts/lib` hacia arriba, y NO de un `parents[N]` fijo: este
# archivo vive además copiado adentro de cada skill que lo usa —que es la regla: un skill trae su
# propia implementación—, y ahí la profundidad es otra. Un índice fijo lo ata a una ubicación y
# rompe la copia con un `ModuleNotFoundError` que no nombra ni al skill ni a la copia.
RAIZ = next(
    p for p in Path(__file__).resolve().parents if (p / ".claude" / "scripts" / "lib").is_dir()
)

# El harness vive en `.claude/scripts/`, y de ahí sale `configurar()`. Sin eso, la primera tilde
# de este archivo tira el script abajo cuando la salida va a una tubería —que es cómo la lee un
# agente— porque el encoding por defecto en esta máquina es cp1252.
sys.path.insert(0, str(RAIZ / ".claude" / "scripts"))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.specs import leer_mapa  # noqa: E402

SPECS = RAIZ / "specs"

# El `[A-Za-z0-9_-]` antes del punto descarta las menciones a la extensión suelta («los `.gd` de
# la capa»), que si no entran a la matriz como un archivo llamado «.gd».
#
# `yml|yaml` está por una ceguera medida el 2026-09-02 sobre el lote 026 + 027: los dos specs
# escribían `.github/workflows/verify.yml` —uno le fijaba la versión de Godot, el otro le sacaba
# la variable entera— y la matriz no lo listó. Un workflow es de los archivos que más se comparten
# entre specs de infraestructura, y era el único que la matriz no podía ver.
#
# Y el `(?::\d+(?:-\d+)?)?` del final es la otra mitad de esa misma medición: `tasks.md` cita
# tanto `` `CLAUDE.md` `` como `` `CLAUDE.md:28` ``, y la segunda forma no matcheaba. El número
# queda FUERA del grupo a propósito: si entrara, el mismo archivo citado desde dos líneas
# distintas serían dos filas de la matriz y ninguna saldría marcada como compartida — la
# ceguera se cambiaría por una más difícil de ver.
CITA = re.compile(r"`([^`]*[A-Za-z0-9_-]\.(?:gd|tscn|tres|py|md|json|cfg|yml|yaml))(?::\d+(?:-\d+)?)?`")

# Los cuatro archivos que todo spec tiene adentro de su carpeta: citados sin ruta son suyos, y
# contarlos como compartidos pondría a los N specs del lote pisándose el `tasks.md`.
PROPIOS = frozenset(("spec.md", "research.md", "plan.md", "tasks.md", "README.md"))


def es_propio(cita: str) -> bool:
    """Si la cita es a un archivo de la carpeta del propio spec, y por lo tanto no es una arista.

    **Sólo cuando viene sin ruta.** El filtro comparaba el basename, y con eso se llevaba puesto
    `docs/README.md` —medido el 2026-09-02: los dos specs del lote 026 + 027 lo editan, el 026
    reescribiendo una sección entera y el 027 insertando en otra, y la matriz no lo listó—. Una
    cita con barra nombra un archivo del repo, nunca el `README.md` de una carpeta de spec.
    """
    return "/" not in cita and cita in PROPIOS

LINEA_DE_TAREA = re.compile(r"^\s*-\s*\[[ xX]\]\s")
ID_DE_TAREA = re.compile(r"\bT\d{3}\b")

# El par se escribe `44 -> **63**`, con el énfasis de markdown adentro, así que un grep del
# número pelado se lo pierde. Y la coma decimal es real —`4,0 -> 11,8`—: el par se emite como
# texto y no como número justamente porque un `float()` la convierte en un error.
PAR = re.compile(r"(\d+(?:[.,]\d+)?)\s*(?:\*\*)?\s*(?:→|->)\s*(?:\*\*)?\s*(\d+(?:[.,]\d+)?)")


def _morir(mensaje: str, codigo: int = 2) -> None:
    print(mensaje, file=sys.stderr)
    sys.exit(codigo)


def expandir(args: list[str]) -> list[str]:
    """Las tres formas del `argument-hint`, a una lista de `NNN`."""
    ids: list[str] = []
    for a in args:
        if a == "--dry":
            continue
        if a == "--propuestos":
            # El estado sale de `specs/mapa.json`, que es la fuente única. `leer_mapa` grita si
            # el archivo está roto en vez de devolver un mapa vacío, que se leería como «no hay
            # nada Propuesto» — o sea la conclusión contraria, y en verde.
            mapa = leer_mapa((SPECS / "mapa.json").read_text(encoding="utf-8"))
            ids += [i for i, e in mapa.items() if e["estado"] == "Propuesto"]
            continue
        if re.fullmatch(r"\d{3}-\d{3}", a):
            lo, hi = a.split("-")
            ids += [f"{n:03d}" for n in range(int(lo), int(hi) + 1)]
            continue
        if re.fullmatch(r"\d{3}", a):
            ids.append(a)
            continue
        _morir(f"argumento no reconocido: {a}")
    return sorted(set(ids))


def carpeta_de(id_spec: str) -> Path:
    encontradas = sorted(d for d in SPECS.glob(f"{id_spec}-*") if d.is_dir())
    if not encontradas:
        # La causa más probable NO es que el spec no exista: `specs/[0-9]*/` está en el
        # `.gitignore`, así que el directorio es una caché que este checkout puede no haber
        # hidratado todavía. Decir «no hay spec 003» manda a buscar el error al lugar
        # equivocado, y en un worktree recién creado manda ahí siempre.
        _morir(
            f"no hay spec {id_spec} en specs/.\n"
            "  Si el spec existe, falta hidratarlo en este checkout:\n"
            f"    python .claude/scripts/hidratar_specs.py {id_spec}",
            codigo=1,
        )
    return encontradas[0]


def main() -> None:
    ids = expandir(sys.argv[1:])

    if not ids:
        _morir(
            f"el lote quedó vacío: ningún spec coincide con «{' '.join(sys.argv[1:])}».\n"
            "  Con --propuestos, quiere decir que specs/mapa.json no tiene ninguno en ese estado."
        )
    if len(ids) < 2:
        _morir(
            "uso: lote.py <NNN NNN ...> | <NNN-MMM> | --propuestos\n"
            f"  Con un spec solo no hay lote que cruzar: eso es /spec-review. ({ids[0]})"
        )

    # Los specs se resuelven TODOS antes de emitir nada. Un `NNN` sin hidratar tiene que matar el
    # script acá y no a mitad de la matriz: una matriz cortada se lee como «estos specs no
    # comparten ningún archivo», que es la conclusión contraria y sale en verde.
    tareas = {i: (carpeta_de(i) / "tasks.md") for i in ids}
    faltan = [i for i, p in tareas.items() if not p.is_file()]
    if faltan:
        _morir(f"sin tasks.md: {', '.join(faltan)}. ¿La hidratación quedó a medias?", codigo=1)

    lineas = {i: p.read_text(encoding="utf-8").splitlines() for i, p in tareas.items()}

    # Basename a propósito: un `tasks.md` cita el mismo archivo como `src/dominio/turno.gd` y
    # como `turno.gd`, y contarlos aparte parte una colisión en dos.
    citados: dict[str, set[str]] = {}
    for i, texto in lineas.items():
        for linea in texto:
            for cita in CITA.findall(linea):
                if es_propio(cita):
                    continue
                nombre = cita.rsplit("/", 1)[-1]
                # Un basename que además es el de un archivo de spec se muestra con su ruta:
                # `docs/README.md` y `specs/README.md` son dos archivos, y colapsarlos en una
                # fila llamada `README.md` inventaría una arista donde no la hay.
                if nombre in PROPIOS:
                    nombre = cita
                citados.setdefault(nombre, set()).add(i)

    print("== matriz archivo x spec ==")
    for nombre in sorted(citados):
        duenios = " ".join(sorted(citados[nombre]))
        marca = ""
        if len(citados[nombre]) > 1:
            marca = (
                "   <- ESCENA COMPARTIDA: se ordena, no se paraleliza"
                if nombre.endswith(".tscn")
                else "   <- compartido"
            )
        print(f"{nombre:<34}{duenios}{marca}")

    compartidos = sorted(n for n, d in citados.items() if len(d) > 1)

    print()
    print("== tareas que citan cada archivo compartido ==")
    if not compartidos:
        print("  ninguno: los specs del lote no se nombran el mismo archivo.")
    for nombre in compartidos:
        print(f"--- {nombre}")
        for i in ids:
            for n, linea in enumerate(lineas[i], 1):
                if nombre in linea:
                    print(f"  {i}:{n}: {linea.strip()}")

    print()
    print("== numeros que un spec mueve (X -> Y) ==")
    # Sólo la LÍNEA de la tarea, nunca su prosa de abajo. En el repo del que sale este harness la
    # diferencia estaba medida: 7 pares reales en la línea contra 25 contando las continuaciones,
    # y los 18 de más eran frecuencias y números de spec que inventan una dependencia dura donde
    # no hay ninguna.
    hubo = False
    for i in ids:
        for linea in lineas[i]:
            if not LINEA_DE_TAREA.match(linea):
                continue
            par = PAR.search(linea)
            if not par:
                continue
            tarea = ID_DE_TAREA.search(linea)
            etiqueta = tarea.group(0) if tarea else "????"
            print(f"  {i} {etiqueta}  {par.group(1)} -> {par.group(2)}")
            hubo = True
    if not hubo:
        print("  ninguno: ninguna tarea del lote declara mover un valor de X a Y.")


if __name__ == "__main__":
    main()

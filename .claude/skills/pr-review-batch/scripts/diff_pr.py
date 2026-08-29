"""Materializa el diff de UN PR y mide qué ejes se revisan.

Corre adentro del worktree del agente, ya parado en la cabeza del PR.

Uso, desde la raíz del worktree:

    python .claude/skills/pr-review-batch/scripts/diff_pr.py <rama-base> <dir-salida> [<rama-head>]

El tercer argumento es opcional y por defecto es `HEAD`. Existe para que el **padre** pueda medir
un PR sin checkout —cuántas líneas, qué ejes, si toca escenas— y decidir con eso el ancho del
abanico. Un agente adentro de su worktree lo omite.

**La rama base es el `baseRefName` del PR, NO `staging`**, y por eso entra como argumento sin
default: si el lote está apilado, diffear contra `staging` mete los commits del PR de abajo y el
review se llena de hallazgos que son de otro.

Emite los archivos del diff, el gate de ejes y dos bloques propios de este repo: las afirmaciones
numéricas que el diff agrega, y **las escenas que toca**.

## Sobre los umbrales de los ejes

Están **declarados, no medidos**. En el repo del que sale este harness salieron de contar
hallazgos sobre corridas reales; acá todavía no hay ninguna corrida, así que son un punto de
partida razonable y hay que tratarlos como tal. La primera corrida que los contradiga los mueve —
y ahí sí quedan medidos, con su fecha.
"""

import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(RAIZ / ".claude" / "scripts"))

from lib.consola import configurar  # noqa: E402

configurar()

# Lo generado y lo vendorizado se saca y sale gratis. `addons/gdUnit4/` son 272 archivos que
# `.gitattributes` ya marca `linguist-vendored`: un PR que actualiza el addon no se revisa
# archivo por archivo, se revisa mirando la versión.
EXCLUIDOS = [
    ":(exclude)addons/gdUnit4/*",
    ":(exclude).godot/*",
    ":(exclude)reportes/*",
    ":(exclude)export/*",
    ":(exclude)build/*",
    ":(exclude)*.import",
]

PROSA = re.compile(r"\.(md|txt)$")
ESCENA = re.compile(r"\.(tscn|tres)$")

# En GDScript y en Python el comentario es `#`. La segunda alternativa es la línea de docstring
# de los scripts del harness, que es prosa igual aunque no lleve `#`.
COMENTARIO = re.compile(r"^[ \t]*#")

# La numeración ESTRUCTURAL de este repo, que nunca es una afirmación falsable sobre el árbol:
# el ID de una tarea, el número de un issue, el de un spec, el de un paso de un skill, y el
# marcador de una lista ordenada. Se sacan de la línea ANTES de preguntar si queda algún dígito.
#
# **Es el único filtro que este script aplica, y es sobre vocabulario documentado del repo, no
# sobre el sentido de la frase.** Medido sobre el PR #6 el 2026-08-28: **149 líneas candidatas
# sin el filtro contra 44 con él**, o sea 105 que eran `Paso N`, `#N`, `T0NN` y encabezados
# numerados. Un bloque de 149 líneas donde 105 son ruido no se lee, y un bloque que no se lee es
# un eje apagado.
#
# Lo que queda **sigue teniendo ruido a propósito**: una referencia a un spec escrita en prosa
# («el 002 cita cosas que el 001 crea») pasa el filtro, porque sacarla pediría descartar todo
# número de tres dígitos y ahí se irían los umbrales reales. Es una lista de candidatos, no una
# conclusión.
ESTRUCTURALES = re.compile(
    r"\bT\d{3}\b|#\d+|\b(?:Paso|clase|AC)\s?\d+|\bspecs?/?\s?\d{3}\b|\b\d{3}-[a-z]"
    r"|^[ \t]*\d+[.)]\s|^[ \t]*#+\s+\d+\s*[·.)-]|\[0-9\]"
)


def morir(mensaje: str, codigo: int = 1) -> None:
    print(mensaje, file=sys.stderr)
    sys.exit(codigo)


def git(*args: str) -> str:
    hecho = subprocess.run(
        ["git", *args], capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if hecho.returncode != 0:
        morir(f"ABORT: git {' '.join(args)} -> {hecho.stderr.strip()}")
    return hecho.stdout


def existe(ref: str) -> bool:
    return (
        subprocess.run(
            ["git", "rev-parse", "--verify", "--quiet", ref], capture_output=True
        ).returncode
        == 0
    )


def main() -> None:
    if len(sys.argv) < 3:
        morir(
            "uso: diff_pr.py <rama-base> <dir-salida> [<rama-head>]\n"
            "  La base es el baseRefName del PR, no `staging`: si el lote esta apilado, "
            "diffear contra staging mete los commits del PR de abajo.",
            codigo=2,
        )

    base, salida = sys.argv[1], Path(sys.argv[2])
    cabeza = sys.argv[3] if len(sys.argv) > 3 else "HEAD"
    salida.mkdir(parents=True, exist_ok=True)

    if subprocess.run(["git", "fetch", "origin", "--quiet"], capture_output=True).returncode != 0:
        print("WARN: `git fetch` fallo; se usa el estado local", file=sys.stderr)

    ref = f"origin/{base}" if existe(f"origin/{base}") else base
    if not existe(ref):
        morir(f"ABORT: no existe ni `{base}` ni `origin/{base}`")
    if not existe(cabeza):
        morir(f"ABORT: no existe la cabeza `{cabeza}`")

    mb = git("merge-base", ref, cabeza).strip()
    if not mb:
        morir(f"ABORT: sin merge-base contra {ref}")

    def diffear(*extra: str) -> str:
        return git("diff", *extra, f"{mb}..{cabeza}", "--", ".", *EXCLUIDOS)

    (salida / "pr.diff").write_text(diffear(), encoding="utf-8")
    archivos = [a for a in diffear("--name-only").splitlines() if a]
    (salida / "pr.files").write_text("\n".join(archivos) + "\n", encoding="utf-8")
    (salida / "pr.stat").write_text(diffear("--stat"), encoding="utf-8")

    docs = [a for a in archivos if PROSA.search(a)]
    escenas = [a for a in archivos if ESCENA.search(a)]
    codigo = [a for a in archivos if not PROSA.search(a) and not ESCENA.search(a)]
    for nombre, lista in (("pr.docs", docs), ("pr.escenas", escenas), ("pr.code", codigo)):
        (salida / nombre).write_text("".join(f"{a}\n" for a in lista), encoding="utf-8")

    diff = (salida / "pr.diff").read_text(encoding="utf-8")
    lineas = diff.count("\n")

    print(f"base_ref={ref}")
    print(f"head_ref={cabeza}")
    print(f"merge_base={mb}")
    for nombre in ("pr.diff", "pr.stat", "pr.files", "pr.code", "pr.docs", "pr.escenas"):
        print(f"{nombre.replace('.', '_')}_path={salida / nombre}")
    print(f"diff_lines={lineas}")
    print(f"files_changed={len(archivos)}")
    print(f"code_files={len(codigo)}")
    print(f"doc_files={len(docs)}")
    print(f"scene_files={len(escenas)}")

    if lineas > 1500:
        print("diff_size=grande")
        print("WARN: > 1500 lineas — NO lo leas entero. Triagea con el stat", file=sys.stderr)
    else:
        print("diff_size=ok")

    agregadas = [l[1:] for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
    texto_agregado = "\n".join(agregadas)

    # `push_error`/`push_warning` son la forma que este repo acepta para que algo sobreviva al
    # commit: un `print` no. Un diff que agrega ramas de error sin ninguno de los dos es
    # justamente lo que el eje busca.
    errores = len(re.findall(r"push_error|push_warning|assert\(|if not |else:", texto_agregado))
    tipos = len(re.findall(r"^\s*(class_name|enum |signal |func )", texto_agregado, re.M))
    coment = len([l for l in agregadas if COMENTARIO.match(l)])

    print()
    print("== ejes (umbral DECLARADO, no medido; un eje en 'no' NO se revisa) ==")
    print("correctness+convenciones : SI (siempre)")
    print("capas                    : SI (siempre; ver el SKILL.md)")
    print(f"manejo de errores        : {'SI' if errores >= 3 else 'no'}  ({errores}, umbral 3)")
    print(f"firmas y tipos           : {'SI' if tipos >= 2 else 'no'}  ({tipos}, umbral 2)")
    hay_prosa = coment >= 5 or len(docs) >= 1
    print(
        f"prosa (docs+comentarios) : {'SI' if hay_prosa else 'no'}  "
        f"({coment} comentarios, {len(docs)} .md)"
    )
    print(f"escenas                  : {'SI' if escenas else 'no'}  ({len(escenas)} .tscn/.tres)")

    print()
    print("== escenas que toca este PR ==")
    if not escenas:
        print("  (ninguna)")
    else:
        for a in escenas:
            print(f"  {a}")
        print()
        print("  OJO: un .tscn no se mergea. `.gitattributes` marca `binary` los .png y los .ogg")
        print("  con ese mismo argumento, pero NO los .tscn, asi que git los va a mergear igual y")
        print("  el resultado es una escena corrupta, no un conflicto. Si otro PR del lote toca")
        print("  alguna de estas, va al reporte del padre y NO se resuelve sola.")

    print()
    print("== afirmaciones numericas que el diff AGREGA ==")
    # El eje que más rinde en un repo que trata la prosa como parte del contrato: una línea de
    # doc o de comentario con un número adentro es una afirmación falsable. Este bloque no dice
    # cuál está mal — dice cuáles hay que cruzar contra el spec del PR, que es donde suele estar
    # el número corregido.
    archivo = ""
    encontradas: list[str] = []
    for linea in diff.splitlines():
        if linea.startswith("+++ b/"):
            archivo = linea[6:]
            continue
        if linea.startswith("+++") or not linea.startswith("+"):
            continue
        cuerpo = linea[1:]
        es_prosa = bool(PROSA.search(archivo)) or bool(COMENTARIO.match(cuerpo))
        if not es_prosa or re.fullmatch(r"[\s|:#-]*", cuerpo):
            continue
        if re.search(r"\d", ESTRUCTURALES.sub(" ", cuerpo)):
            encontradas.append(f"{archivo}: {cuerpo[:150]}")
    if not encontradas:
        print("  (ninguna)")
    for e in encontradas[:60]:
        print(e)
    if len(encontradas) > 60:
        print(f"  ... y {len(encontradas) - 60} mas (grepea el resto vos)")

    print()
    print("-- pr.stat --")
    print((salida / "pr.stat").read_text(encoding="utf-8"), end="")


if __name__ == "__main__":
    main()

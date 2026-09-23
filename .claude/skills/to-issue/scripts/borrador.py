"""Arranca el borrador de un issue desde el template, y lo revisa antes de publicarlo.

Uso, desde la raíz del repo:

    python .claude/skills/to-issue/scripts/borrador.py nuevo <archivo>
    python .claude/skills/to-issue/scripts/borrador.py revisar <archivo>
    python .claude/skills/to-issue/scripts/borrador.py numerar <archivo> <número>

`nuevo` copia `.github/ISSUE_TEMPLATE/task-brief.md` sin su encabezado YAML, que es de GitHub y
no del issue. No pisa un archivo que ya existe: ahí puede haber un borrador llenado.

`revisar` sale con 1 y nombra cada problema si el borrador no respeta el template. Existe porque
escribir el issue de memoria **se ve igual** que copiarlo: una sección que falta o una inventada
no las nota nadie hasta que una persona lee el issue publicado.

`numerar` escribe el número que GitHub le dio al issue donde el borrador dice `<issue>`, y
revisa otra vez sin dejar pasar nada. Es el único hueco que `revisar` tolera: antes de publicar,
el número no existe.

Las secciones y los huecos se leen del template en cada corrida. Una lista escrita acá se
separaría del template el día que alguien lo edite.
"""

import re
import sys
from pathlib import Path

# La raíz sale de buscar `.github/ISSUE_TEMPLATE` hacia arriba, y no de un `parents[N]` fijo:
# un índice fijo ata el script a la profundidad de la carpeta del skill.
RAIZ = next(
    p for p in Path(__file__).resolve().parents if (p / ".github" / "ISSUE_TEMPLATE").is_dir()
)
TEMPLATE = RAIZ / ".github" / "ISSUE_TEMPLATE" / "task-brief.md"

COMENTARIO = re.compile(r"<!--.*?-->", re.DOTALL)
# Un hueco es `<algo>` en una sola línea. `<!--` no cuenta: los comentarios se sacan antes.
HUECO = re.compile(r"<[^<>\n!][^<>\n]*>")
SECCION = re.compile(r"^## (.+)$", re.MULTILINE)
TITULO = re.compile(r"^# (.+)$", re.MULTILINE)
# Los campos del contexto: `- **Tipo:** ...`. Copiados tal cual, son la consigna y no la respuesta.
CAMPO = re.compile(r"^- \*\*[^*]+:\*\*.*$", re.MULTILINE)
# El hueco de la rama que se llena después de publicar. Es el nombre que usa el template.
NUMERO = "<issue>"


def sin_encabezado(texto: str) -> str:
    """El template sin el bloque `---` de arriba, que GitHub usa para listarlo."""
    if not texto.startswith("---"):
        return texto
    fin = texto.index("\n---", 3)
    return texto[fin + len("\n---") :].lstrip("\n")


def _sin_comentarios(texto: str) -> str:
    # Cada comentario deja sus saltos de línea, para que el número de línea que se reporta sea
    # el del archivo.
    return COMENTARIO.sub(lambda m: "\n" * m.group(0).count("\n"), texto)


def numerar(borrador: str, numero: int) -> str:
    return borrador.replace(NUMERO, str(numero))


def problemas(borrador: str, plantilla: str, publicado: bool = True) -> list[str]:
    """Lo que le falta al borrador para respetar el template. Vacía si está listo.

    Con `publicado=False` deja pasar el hueco del número, que todavía no existe.
    """
    visible = _sin_comentarios(borrador)
    hallados: list[str] = []

    esperadas = SECCION.findall(_sin_comentarios(plantilla))
    presentes = SECCION.findall(visible)
    for seccion in esperadas:
        if seccion not in presentes:
            hallados.append(f"falta la sección «## {seccion}»")
    for seccion in presentes:
        if seccion not in esperadas:
            hallados.append(f"la sección «## {seccion}» no está en el template")
    if not hallados and presentes != esperadas:
        hallados.append(
            "las secciones no van en el orden del template: " + ", ".join(esperadas)
        )

    titulos = TITULO.findall(visible)
    if len(titulos) != 1:
        hallados.append(f"tiene que haber un solo título «# ...», y hay {len(titulos)}")

    for numero, linea in enumerate(visible.splitlines(), 1):
        for hueco in dict.fromkeys(HUECO.findall(linea)):
            if hueco == NUMERO and not publicado:
                continue
            hallados.append(f"línea {numero}: queda el hueco {hueco} sin llenar")

    campos_del_template = set(CAMPO.findall(_sin_comentarios(plantilla)))
    for campo in CAMPO.findall(visible):
        if campo in campos_del_template:
            hallados.append(f"el campo quedó como en el template: {campo}")

    return hallados


def _uso_valido(argumentos: list[str]) -> bool:
    if len(argumentos) == 2:
        return argumentos[0] in ("nuevo", "revisar")
    return len(argumentos) == 3 and argumentos[0] == "numerar" and argumentos[2].isdigit()


def main(argumentos: list[str]) -> int:
    if not _uso_valido(argumentos):
        print(__doc__, file=sys.stderr)
        return 2
    accion, archivo = argumentos[0], Path(argumentos[1])
    plantilla = sin_encabezado(TEMPLATE.read_text(encoding="utf-8"))

    if accion == "nuevo":
        if archivo.exists():
            print(f"{archivo} ya existe: no se pisa un borrador.", file=sys.stderr)
            return 1
        archivo.parent.mkdir(parents=True, exist_ok=True)
        archivo.write_bytes(plantilla.encode("utf-8"))
        print(f"Borrador creado desde el template: {archivo}")
        return 0

    texto = archivo.read_text(encoding="utf-8")
    if accion == "numerar":
        texto = numerar(texto, int(argumentos[2]))
        archivo.write_bytes(texto.encode("utf-8"))
    hallados = problemas(texto, plantilla, publicado=accion == "numerar")
    if hallados:
        print(f"{archivo} no respeta el template:", file=sys.stderr)
        for hallado in hallados:
            print(f"  - {hallado}", file=sys.stderr)
        return 1
    print(f"{archivo} respeta el template.")
    return 0


if __name__ == "__main__":
    for flujo in (sys.stdout, sys.stderr):
        # En Windows, una tubería sale en cp1252 y cualquier acento tira el script abajo.
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main(sys.argv[1:]))

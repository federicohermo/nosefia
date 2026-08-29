"""El gate: no se edita el producto sin un spec detrás de la rama.

Corre como hook `PreToolUse` sobre `Edit|Write|MultiEdit|Bash`. Recibe el payload del hook
por stdin y contesta por stdout con `permissionDecision`.

## Por qué existe

`CLAUDE.md` y `specs/README.md` documentan el flujo —cuatro archivos, `publicar_spec.py`, la
rama recién después— pero es prosa, y la prosa no frena a nadie. En el repo del que sale este
harness, la sesión que abrió un spec reportó un bug y el agente abrió una rama y editó el
dominio sin spec y sin issue: nada se lo impidió.

Es el mismo hallazgo que mueve una convención de la documentación al linter, un nivel más
arriba: la regla que dice cómo EMPIEZA un cambio también tiene que ser ejecutable.

## Cuatro decisiones que no son obvias

1. **Mira la edición y no el commit.** Sobre el commit llega tarde: el trabajo ya está hecho,
   y el costo de volver atrás es lo que hace que la salida sea saltearlo. Sobre la edición,
   cumplir cuesta cero — todavía no se escribió nada.

2. **Si algo falla, DEJA PASAR y lo dice.** Un gate que rompe la sesión entera se desactiva
   el mismo día, y ahí no queda gate. Falla abierto a propósito: lo que protege es una
   convención, no un secreto.

3. **El mensaje dice cómo salir.** Bloquear sin decir qué hacer produce el reflejo de buscar
   cómo saltear el bloqueo, que es el fracaso completo del gate.

4. **Mira también lo que escribe `Bash`.** Un gate sólo sobre `Edit|Write|MultiEdit` tiene el
   agujero del tamaño de `sed -i`, y encima es un agujero DIRIGIDO: negarle `Edit` a un
   agente lo empuja justo hacia la redirección. Lo que se mira es un conjunto declarado de
   formas de escritura, no un parser de shell — ver `destinos_de_bash`.
"""

import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.repo import PROTEGIDAS, RAIZ, RAMAS_COMPARTIDAS  # noqa: E402
from lib.rutas_protegidas import esta_protegida  # noqa: E402

#: Las ramas que pasan: `feature/NNN-…` con `NNN` en el mapa.
RAMA_DE_SPEC = re.compile(r"^feature/(\d{3})-")

COMO_SALIR = (
    "Si el spec no existe, la salida es el skill `spec-create`: medir, escribir los cuatro "
    "archivos en `specs/<NNN>-<kebab>/`, publicarlos con "
    "`python .claude/scripts/publicar_spec.py crear` y `publicar`, y commitear SÓLO "
    "`specs/mapa.json` a `staging`. Si el spec YA está publicado, lo que falta es la rama, que "
    "la abre el implementador: `git checkout -b feature/<NNN>-<kebab>` con el `NNN` que el mapa "
    "ya tiene. Si el cambio de verdad no necesita spec —un typo, un bump de versión, revertir "
    "el commit anterior— el skill lo dice por escrito, pero la rama igual no puede ser `main` "
    "ni `staging`."
)


def _responder(decision: str, motivo: str | None = None) -> None:
    salida: dict[str, object] = {
        "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": decision}
    }
    # `permissionDecisionReason` sólo cuando hay algo que declarar: un gate que no pudo correr
    # tiene que decirlo, y uno que decidió que no le tocaba, no.
    if motivo:
        salida["hookSpecificOutput"]["permissionDecisionReason"] = motivo  # type: ignore[index]
    print(json.dumps(salida, ensure_ascii=False))
    sys.exit(0)


def pasar(motivo: str | None = None) -> None:
    """Deja pasar, y opcionalmente cuenta por qué. Es la salida por defecto de todo fallo."""
    _responder("allow", motivo)


def bloquear(motivo: str) -> None:
    _responder("deny", motivo)


def _desentrecomillar(token: str) -> str:
    """Quita las comillas que envuelven a un token de shell, si las tiene."""
    if len(token) >= 2 and token[0] == token[-1] and token[0] in "\"'":
        return token[1:-1]
    return token


#: Los comandos que ESCRIBEN, y de qué argumentos sale el destino.
#:
#: `cp` y `mv` escriben SÓLO su último argumento —el origen es lectura, y contarlo bloquearía
#: un `cp src/dominio/turno.gd /tmp/` legítimo—; `rm` destruye todos los suyos; y `sed`
#: escribe únicamente con `-i`. El script de `sed` (`s/a/b/`) queda en la lista de candidatos,
#: pero no resuelve bajo ninguna carpeta protegida, así que distinguirlo no haría falta ni
#: aunque fuera gratis.
ESCRITORES = {
    "tee": lambda args, flags: args,
    "cp": lambda args, flags: args[-1:],
    "mv": lambda args, flags: args[-1:],
    "rm": lambda args, flags: args,
    "truncate": lambda args, flags: args,
    "sed": lambda args, flags: args if any(f.startswith("-i") for f in flags) else [],
}

_REDIRECCION = re.compile(r">>?\s*(?!&)(\"[^\"]*\"|'[^']*'|[^\s;&|<>()]+)")
_TOKENS = re.compile(r"\"[^\"]*\"|'[^']*'|\S+")


def destinos_de_bash(comando: str) -> list[str]:
    """Los archivos que un comando de `Bash` escribe.

    Es DETECCIÓN y no un parser de shell: reconoce las formas que se usan de verdad
    —redirección, `sed -i`, `tee`, `cp`/`mv`/`rm`/`truncate`— y **no pretende ser
    exhaustiva**. Un `python -c` que abra el archivo pasa, y está bien que pase: la decisión 2
    del encabezado vale igual acá, y un gate que intente parsear shell de verdad se equivoca
    en la dirección cara, que es bloquear lo que no debía.
    """
    destinos: list[str] = []

    # La redirección se busca sobre el string entero y no por segmento: no necesita ningún
    # comando conocido adelante, que es lo que la vuelve el escape más corto de todos. El
    # `(?!&)` deja afuera `2>&1`, que redirige un descriptor y no un archivo.
    for m in _REDIRECCION.finditer(comando):
        destinos.append(_desentrecomillar(m.group(1)))

    # Y los comandos, por segmento: en `cat turno.gd | tee src/dominio/turno.gd` el destino es
    # del segundo, y mirar el comando entero de una lo atribuiría al primero.
    for segmento in re.split(r"[;\n]|\|\|?|&&", comando):
        tokens = [_desentrecomillar(t) for t in _TOKENS.findall(segmento)]
        if not tokens:
            continue
        # `/usr/bin/sed` es `sed`: comparar el token entero dejaría pasar la ruta absoluta.
        nombre = re.split(r"[/\\]", tokens[0])[-1]
        escritor = ESCRITORES.get(nombre)
        if escritor is None:
            continue
        resto = tokens[1:]
        args = [t for t in resto if not t.startswith("-")]
        flags = [t for t in resto if t.startswith("-")]
        destinos.extend(escritor(args, flags))

    return destinos


def rutas_del_payload(crudo: str) -> list[str] | None:
    """Las rutas que el payload va a escribir, o `None` si no se pudo leer ninguna.

    `None` NO es «ninguna»: es «no se pudo decidir», y el llamador lo DECLARA. Un `Bash` que
    de verdad no escribe nada devuelve `[]`, que sí es una respuesta y pasa callado.
    """
    try:
        payload = json.loads(crudo)
        herramienta = payload.get("tool_name")
        entrada = payload.get("tool_input") or {}
        if herramienta == "Bash":
            comando = entrada.get("command")
            return destinos_de_bash(comando) if isinstance(comando, str) else None
        ruta = entrada.get("file_path")
        return [ruta] if isinstance(ruta, str) and ruta else None
    except (json.JSONDecodeError, AttributeError, TypeError):
        return None


def main() -> None:
    rutas = rutas_del_payload(sys.stdin.read())

    # Sin ruta legible no hay nada que decidir. Pasa, pero lo DICE: un payload que cambiara de
    # forma dejaría el gate mudo para siempre, y esta línea es la que lo delata.
    if rutas is None:
        pasar(
            "gate-de-spec: el payload no trae `file_path` ni `command`, no se pudo verificar la rama"
        )

    # La primera protegida es la que nombra el mensaje. Alcanza con una: el comando se bloquea
    # entero, y listar las cinco de un `rm -rf` no cambia lo que hay que hacer.
    ruta = next(
        (r for r in rutas if esta_protegida(os.path, str(RAIZ), list(PROTEGIDAS), r)), None
    )
    if ruta is None:
        pasar()

    try:
        rama = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=RAIZ,
            capture_output=True,
            text=True,
            timeout=5,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pasar("gate-de-spec: no se pudo leer la rama con git, no se verificó")

    if rama in RAMAS_COMPARTIDAS:
        bloquear(f"No se edita `{ruta}` desde `{rama}`. {COMO_SALIR}")

    m = RAMA_DE_SPEC.match(rama)
    if m is None:
        bloquear(
            f"La rama `{rama}` no nombra un spec, y `{ruta}` está protegida. La rama que pasa se "
            f"llama `feature/<NNN>-<kebab>`. {COMO_SALIR}"
        )

    id_spec = m.group(1)
    try:
        mapa = json.loads((RAIZ / "specs" / "mapa.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        pasar("gate-de-spec: no se pudo leer `specs/mapa.json`, no se verificó el spec de la rama")

    if id_spec not in mapa:
        bloquear(
            f"La rama `{rama}` dice ser del spec {id_spec}, que no tiene entrada en "
            f"`specs/mapa.json`. O el spec no se publicó todavía, o el número está mal. {COMO_SALIR}"
        )

    pasar()


if __name__ == "__main__":
    main()

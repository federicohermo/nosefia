"""El gate: no se edita el producto sin un spec detrás de la rama.

Corre como hook `PreToolUse` sobre `Edit|Write|MultiEdit|Bash|PowerShell`. Recibe el payload
del hook por stdin y contesta por stdout con `permissionDecision`.

## Por qué existe

`CLAUDE.md` y `specs/README.md` documentan el flujo —tres archivos, `publicar_spec.py`, la
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

4. **Mira también lo que escriben `Bash` y `PowerShell`.** Un gate sólo sobre
   `Edit|Write|MultiEdit` tiene el agujero del tamaño de `sed -i`, y encima es un agujero
   DIRIGIDO: negarle `Edit` a un agente lo empuja justo hacia la redirección. Lo que se mira
   es un conjunto declarado de formas de escritura, no un parser de shell — ver
   `destinos_del_comando`.

   **`PowerShell` entró después, y por evidencia.** Montando este harness, un bug de este
   mismo gate dejó la sesión encerrada, y la salida fue escribir archivos con la herramienta
   de PowerShell: una herramienta que el matcher no nombraba. O sea que el gate se salteaba
   solo con cambiar de herramienta, sin proponérselo.

5. **Mira el NOMBRE de la rama y no `specs/mapa.json`.** Hasta el 2026-09-08 exigía que el
   `NNN` de la rama ya tuviera entrada en el mapa, o sea que para escribir la primera línea de
   código había que haber abierto el issue de GitHub y commiteado el mapa a `staging`. Un gate
   que obliga a pedir permiso antes de empezar es un gate que se apaga.

   **El cruce no desapareció: se mudó**, a `ElSpecDeLaRamaExiste` de
   `tests/test_criterios_de_la_rama.py`, que corre en el nodo `harness` con el PR todavía
   abierto. Ahí llega igual de a tiempo y no frena la primera edición. **El derivador no lo
   cobra** —lo dice él mismo: un PR cuya rama nombra un `NNN` ausente del mapa «no agrega
   nada»— así que sin ese test el cruce se caía del repo sin que nada lo reclamara: medido el
   2026-09-08, una rama de un spec inexistente dejaba el gate en `OK (skipped=2)`.
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

#: Los tres prefijos que pueden editar el producto.
#:
#: Son los de la convención de Atlassian —`feature`, `bugfix`, `hotfix`— y no una invención de
#: acá: quien llega de afuera ya sabe qué significan. **Sólo `feature/` pide el `NNN`**, porque
#: es el único que sale de un spec siempre; exigírselo a `bugfix/` y `hotfix/` los obligaría a
#: inventar un número. El `bugfix/` que sí sale de un spec puede llevarlo igual, y
#: `derivar_mapa.py` lo levanta.
PREFIJOS_DEL_PRODUCTO = ("feature/", "bugfix/", "hotfix/")

#: Los prefijos de lo que NO toca `src/`, declarados para que el mensaje pueda ofrecerlos.
#:
#: **El gate no los verifica, y no podría**: sólo protege `src/`, así que una rama `docs/` que
#: edita documentación no le pasa ni cerca. Están acá porque bloquear sin decir cómo salir
#: produce el reflejo de saltear el bloqueo, y «renombrá la rama» sin decir a qué no es salida.
#: Cada uno nombra QUÉ toca, en vez de ser el cajón de sastre que era `chore/`.
PREFIJOS_SIN_PRODUCTO = ("harness/", "docs/", "ci/")

#: `feature/NNN-…`, con el `NNN` de `specs/mapa.json` en TRES dígitos.
#:
#: Tres y no «los que haya» porque el mapa los escribe así y `derivar_mapa.py` los lee así:
#: aceptar `feature/38-…` dejaría pasar una rama cuyo número no va a matchear nunca, y el spec
#: no aterrizaría sin que nada lo diga.
RAMA_DE_SPEC = re.compile(r"^feature/\d{3}-.+$")


def _lista(prefijos: tuple[str, ...]) -> str:
    """`a`, `b` y `c` — para que el mensaje se lea como una frase y no como un array."""
    entrecomillados = [f"`{p}`" for p in prefijos]
    return "%s y %s" % (", ".join(entrecomillados[:-1]), entrecomillados[-1])


#: El único mensaje que dice cómo salir, y **se arma con las dos listas de arriba**.
#:
#: Escribir los prefijos otra vez acá sería la segunda copia de un conjunto cerrado, y la que
#: se pudre: el día que entre un cuarto prefijo, el código lo aceptaría y el mensaje seguiría
#: nombrando tres.
COMO_SALIR = (
    "Al producto lo tocan %s, y `feature/` es el único que además nombra su spec: "
    "`feature/<NNN>-<kebab>`, con el `NNN` de `specs/mapa.json` en tres dígitos. Lo que NO toca "
    "`src/` se nombra por lo que toca: %s. **El spec se puede publicar después**: este gate ya "
    "no lo exige, sólo pide que la rama diga de qué spec es. Si el spec no existe todavía, el "
    "skill que lo escribe es `spec-create`."
) % (_lista(PREFIJOS_DEL_PRODUCTO), _lista(PREFIJOS_SIN_PRODUCTO))


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

#: Los cmdlets de PowerShell que escriben, y de dónde sale su destino.
#:
#: **Existen porque `PowerShell` es una herramienta aparte de `Bash` en este entorno**, y el
#: matcher del hook la ignoraba. El agujero no es hipotético: montando este harness quedé
#: encerrado por un bug del propio hook y salí escribiendo archivos con la herramienta de
#: PowerShell — o sea que el gate se saltea solo con cambiar de herramienta.
#:
#: Un cmdlet no se parsea como un comando POSIX: el destino puede venir por parámetro nombrado
#: (`-Path`, `-FilePath`, `-Destination`) o por posición, así que cada entrada declara la
#: posición de su destino y los parámetros que lo nombran.
#:
#: **Los parámetros dependen del cmdlet y ésa es la parte que no es obvia**: en `Copy-Item` el
#: `-Path` es el ORIGEN, que se lee. Una lista única de nombres hacía que
#: `Copy-Item -Path a.gd -Destination src/x.gd` reportara `a.gd` — o sea el archivo que no se
#: toca— y dejara pasar el que sí. Lo encontró su test.
_CMDLETS_QUE_ESCRIBEN = {
    # Escriben donde apuntan: el destino es el primer posicional o el `-Path`.
    "set-content": (0, ("-path", "-filepath", "-literalpath")),
    "add-content": (0, ("-path", "-filepath", "-literalpath")),
    "clear-content": (0, ("-path", "-filepath", "-literalpath")),
    "out-file": (0, ("-path", "-filepath", "-literalpath")),
    "new-item": (0, ("-path", "-filepath", "-literalpath")),
    "remove-item": (0, ("-path", "-filepath", "-literalpath")),
    # Acá el destino es el SEGUNDO posicional o el `-Destination`: el primero es el origen, que
    # se lee. Es el mismo criterio que `cp` y `mv`.
    "copy-item": (1, ("-destination",)),
    "move-item": (1, ("-destination",)),
    "rename-item": (1, ("-newname",)),
}

_REDIRECCION = re.compile(r">>?\s*(?!&)(\"[^\"]*\"|'[^']*'|[^\s;&|<>()]+)")
_TOKENS = re.compile(r"\"[^\"]*\"|'[^']*'|\S+")


def _destino_de_cmdlet(resto: list[str], posicion: int, parametros: tuple[str, ...]) -> list[str]:
    """El destino de un cmdlet: el parámetro nombrado si está, y si no, los posicionales.

    **Cuando no hay parámetro nombrado devuelve TODOS los candidatos, no uno.** Intentar
    quedarse con «el posicional número N» obliga a saber qué parámetros llevan valor y cuáles
    son interruptores, y equivocarse ahí sale caro **hacia el lado malo**: con
    `Remove-Item -Force src`, tratar a `-Force` como si consumiera un valor se come el `src` y
    el gate deja pasar un borrado de verdad.

    Devolver de más no cuesta nada: un candidato que no es una ruta protegida —un `utf8`, un
    `"hola"`— no resuelve bajo ninguna carpeta vigilada y se descarta solo. Es el mismo criterio
    con el que `sed` deja su script `s/a/b/` en la lista.

    Lo único que se saca es el ORIGEN de los cmdlets que copian o mueven, que es lectura:
    contarlo bloquearía un `Copy-Item src/x.gd C:/tmp/` legítimo.
    """
    for i, token in enumerate(resto):
        if token.lower() in parametros and i + 1 < len(resto):
            return [resto[i + 1]]
    posicionales = [t for t in resto if not t.startswith("-")]
    return posicionales[posicion:]


def destinos_del_comando(comando: str) -> list[str]:
    """Los archivos que un comando de `Bash` o de `PowerShell` escribe.

    Es DETECCIÓN y no un parser de shell: reconoce las formas que se usan de verdad
    —redirección, `sed -i`, `tee`, `cp`/`mv`/`rm`/`truncate`, y los cmdlets de PowerShell que
    escriben— y **no pretende ser exhaustiva**. Un `python -c` que abra el archivo pasa, y un
    `[System.IO.File]::WriteAllText(...)` también. Está bien que pasen: la decisión 2 del
    encabezado vale igual acá, y un gate que intente parsear shell de verdad se equivoca en la
    dirección cara, que es bloquear lo que no debía.

    Las dos sintaxis se miran juntas y no según de qué herramienta vino el payload. Distinguir
    no aportaría nada —ningún comando de bash se llama `Set-Content`— y en cambio agregaría una
    forma de equivocarse: la de mirar la lista equivocada.
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
        resto = tokens[1:]

        escritor = ESCRITORES.get(nombre)
        if escritor is not None:
            args = [t for t in resto if not t.startswith("-")]
            flags = [t for t in resto if t.startswith("-")]
            destinos.extend(escritor(args, flags))
            continue

        # Los cmdlets van en minúsculas porque PowerShell no distingue mayúsculas: `Set-Content`
        # y `set-content` son el mismo cmdlet, y comparar sensible dejaría pasar la segunda.
        cmdlet = _CMDLETS_QUE_ESCRIBEN.get(nombre.lower())
        if cmdlet is not None:
            posicion, parametros = cmdlet
            destinos.extend(_destino_de_cmdlet(resto, posicion, parametros))

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
        # Las dos herramientas que traen un comando en vez de una ruta. `PowerShell` entró
        # después de comprobar en vivo que el gate se saltea solo con cambiar de herramienta.
        if herramienta in ("Bash", "PowerShell"):
            comando = entrada.get("command")
            return destinos_del_comando(comando) if isinstance(comando, str) else None
        ruta = entrada.get("file_path")
        return [ruta] if isinstance(ruta, str) and ruta else None
    except (json.JSONDecodeError, AttributeError, TypeError):
        return None


def payload_cwd(crudo: str) -> str | None:
    """El `cwd` que declara el payload del hook, o `None`.

    Es lo único que dice desde qué árbol se escribe una ruta relativa: el hook corre con el cwd
    del checkout principal, así que sin esto un `src/x.gd` mandado desde un worktree se resuelve
    contra el árbol equivocado. Que falte no es un error — se cae en `RAIZ`.
    """
    try:
        valor = json.loads(crudo).get("cwd")
    except (json.JSONDecodeError, AttributeError, TypeError):
        return None
    return valor if isinstance(valor, str) and valor else None


def raiz_que_manda(ruta: str, cwd: str | None) -> str:
    """El árbol de git al que pertenece `ruta`, que **no siempre es el checkout principal**.

    `RAIZ` sale de dónde vive este archivo (`lib/repo.py`), así que con un worktree el gate
    miraba el árbol equivocado, y de las dos formas. **Medido el 2026-09-07** contra
    `.claude/worktrees/pr-76`, parado en `feature/016-…` con el principal en `staging`:

    - Ruta **absoluta** al worktree: `allow`. Relativa a `RAIZ` es
      `.claude/worktrees/pr-76/src/…`, que no empieza con `src/`, así que `esta_protegida()`
      decía que no le tocaba. **El gate estaba apagado adentro de cada worktree**, que es donde
      `pr-review-batch` y `spec-implement-batch` escriben todo su código.
    - La **misma** ruta relativa: `deny` nombrando `staging`, la rama del principal, con el
      worktree parado en una rama que sí tenía spec.

    El `cwd` del payload es lo único que desambigua una ruta relativa: el hook corre con el cwd
    del checkout principal, y `src/x.gd` no dice a cuál de los dos árboles apunta.

    Falla hacia `RAIZ`, como todo el resto del gate: sin árbol legible se mira el principal en
    vez de reventar.
    """
    base = cwd or str(RAIZ)
    absoluta = os.path.normpath(os.path.join(base, ruta))
    carpeta = absoluta if os.path.isdir(absoluta) else os.path.dirname(absoluta)
    # Sube hasta la primera carpeta que exista: la ruta puede ser de un archivo que se está por
    # crear, y `git -C` sobre una carpeta inexistente falla.
    while carpeta and not os.path.isdir(carpeta):
        padre = os.path.dirname(carpeta)
        if padre == carpeta:
            break
        carpeta = padre
    try:
        salida = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=carpeta or str(RAIZ),
            capture_output=True,
            text=True,
            timeout=5,
            check=True,
        )
    except (OSError, subprocess.SubprocessError):
        return str(RAIZ)
    return salida.stdout.strip() or str(RAIZ)


def motivo_del_bloqueo(rama: str, ruta: str) -> str | None:
    """Por qué `rama` no puede editar `ruta`, o `None` si puede.

    Es pura y recibe el nombre de la rama en vez de leerlo de git **para que se pueda
    ejercer**: el veredicto de punta a punta no puede probar esto, porque habría que pararse en
    cada rama de verdad y un test que cambia de rama rompe la sesión que lo corre.
    """
    # `staging` es la rama default del repositorio: adonde apunta cada clone fresco y cada
    # `gh pr create`, o sea el lugar más fácil de todo el repo donde quedarse parado sin
    # haberlo decidido. Lleva mensaje propio porque el genérico —«esa rama no puede tocar el
    # producto»— se lee como una invitación a RENOMBRARLA, que es lo peor que se le puede hacer
    # a la rama de integración. El problema no es cómo se llama, es dónde estás parado.
    if rama in RAMAS_COMPARTIDAS:
        return f"No se edita `{ruta}` desde `{rama}`. {COMO_SALIR}"

    if not rama.startswith(PREFIJOS_DEL_PRODUCTO):
        return (
            f"La rama `{rama}` no puede editar `{ruta}`. Si el cambio de verdad no es del "
            f"producto, entonces la rama está bien y el archivo está mal. {COMO_SALIR}"
        )

    # Sólo `feature/`: es el único de los tres que sale de un spec siempre.
    if rama.startswith("feature/") and RAMA_DE_SPEC.match(rama) is None:
        return (
            f"La rama `{rama}` es de feature y no nombra su spec: se llama "
            f"`feature/<NNN>-<kebab>`, con el `NNN` en tres dígitos. De ahí lo sacan este gate "
            f"y `derivar_mapa.py`, así que un número mal escrito no aterriza el spec. "
            f"{COMO_SALIR}"
        )

    return None


def main() -> None:
    crudo = sys.stdin.read()
    rutas = rutas_del_payload(crudo)

    # Sin ruta legible no hay nada que decidir. Pasa, pero lo DICE: un payload que cambiara de
    # forma dejaría el gate mudo para siempre, y esta línea es la que lo delata.
    if rutas is None:
        pasar(
            "gate-de-spec: el payload no trae `file_path` ni `command`, no se pudo verificar la rama"
        )

    # La primera protegida es la que nombra el mensaje. Alcanza con una: el comando se bloquea
    # entero, y listar las cinco de un `rm -rf` no cambia lo que hay que hacer.
    # La raíz se resuelve **por archivo tocado** y no una sola vez: en un worktree, `RAIZ` es el
    # checkout principal y mirar contra ella apaga el gate. Ver `raiz_que_manda`.
    cwd = payload_cwd(crudo)
    raiz = str(RAIZ)
    ruta = None
    for r in rutas:
        de_r = raiz_que_manda(r, cwd)
        if esta_protegida(os.path, de_r, list(PROTEGIDAS), r):
            ruta, raiz = r, de_r
            break
    if ruta is None:
        pasar()

    try:
        rama = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=raiz,
            capture_output=True,
            text=True,
            timeout=5,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pasar("gate-de-spec: no se pudo leer la rama con git, no se verificó")

    motivo = motivo_del_bloqueo(rama, ruta)
    if motivo is not None:
        bloquear(motivo)

    pasar()


if __name__ == "__main__":
    main()

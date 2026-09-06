"""Lo puro de las herramientas de specs: `publicar_spec.py`, `hidratar_specs.py`,
`derivar_mapa.py` y `deuda.py`.

**Existe para que tenga tests.** Mientras esta lógica vive adentro de un script ejecutable
no hay forma de cubrirla, porque importarlo lo corre. Los cuatro scripts de arriba son el
cableado —disco, red, `sys.exit`— y acá está lo que decide.

Nada de este archivo toca el disco ni la red: son strings a strings. Lo verifica
`.claude/scripts/tests/test_specs.py`.

Este harness es un port del de `pentomino-games`. Cuando un comentario cita una medición,
dice de dónde sale: las de ese repo se nombran como suyas, porque son la evidencia de por
qué la regla existe, no mediciones de este proyecto.
"""

import json
import re
from typing import Any

# ── El registro ───────────────────────────────────────────────────────────────

#: Los campos que toda entrada del mapa declara, con el tipo que se espera de cada uno.
#:
#: `origen` no está acá y no es un olvido: es opcional y es una lista, o sea que no entra
#: en «un campo, un tipo escalar». Se valida aparte, en `_validar_origen`.
CAMPOS: dict[str, type] = {
    "issue": int,
    "carpeta": str,
    "fecha": str,
    "estado": str,
    "titulo": str,
}

#: Los estados que un spec puede tener, en orden de ciclo de vida y no alfabético.
#:
#: `Propuesto` lo escribe `publicar_spec.py crear`; los otros tres los deriva
#: `derivar_mapa.py` o son una decisión humana sobre el destino del spec. **No hay un
#: estado "En curso"**, y eso es deliberado: ningún paso del flujo lo escribiría, así que
#: sería un tercer punto de escritura manual — el mecanismo que este registro existe para
#: evitar. Que un spec haya empezado se ve en que tiene rama, no en el mapa.
ESTADOS: tuple[str, ...] = ("Propuesto", "Implementado", "Descartado", "Superado")

#: Los estados de los que **no sale más trabajo**: el spec aterrizó, se abandonó o lo
#: reemplazó otro. Su issue está cerrado.
_CERRADOS: frozenset[str] = frozenset({"Implementado", "Descartado", "Superado"})

#: Los estados que **no los mueve un merge**, y por eso quedan afuera del cruce contra el
#: PR — no del cruce contra el issue.
#:
#: Un `Superado` puede tener su PR mergeado y eso no dice nada de su estado: lo superó otro
#: spec después. Un `Descartado` puede no tener ninguno. Los dos son decisiones humanas
#: sobre el destino del spec, no consecuencias de que el código haya aterrizado.
#:
#: No es lo mismo que `_CERRADOS`, que son tres: allá la pregunta es si el spec sigue en
#: vuelo, acá es si un merge puede cambiarle el estado.
NO_LOS_MUEVE_UN_MERGE: frozenset[str] = frozenset({"Descartado", "Superado"})

#: De qué spec es una rama: `feature/007-la-ventanilla` → `007`.
#:
#: El prefijo se deja abierto (`[^/]+`) a propósito: la convención dice `feature/`, pero un
#: spec puede aterrizar por una rama `fix/` o `chore/`, y un patrón que sólo aceptara
#: `feature/` los perdería sin decirlo.
#:
#: Vive acá y no en cada script porque lo leen dos: el derivador que **escribe** el estado y
#: el gate que lo **confirma**. Dos copias que se separen dan un gate que confirma un
#: cálculo que ya no es el suyo, en verde.
RAMA_DE_SPEC = re.compile(r"^[^/]+/(\d{3})-")

#: Cuántos issues y cuántos PR se le piden a `gh`, **y es uno solo para todos los lectores**.
#:
#: `gh` pagina hasta el límite y **no avisa que cortó**, así que pedir de menos convierte una
#: lista incompleta en un dato que parece completo. Los tres consumidores —el derivador, el
#: censo de deuda y el gate del mapa— comparan contra este número para saber si la respuesta
#: sirve.
LIMITE_DE_LISTA = 1000

#: Los PR que aterrizaron **a mano**: figuran `CLOSED` y no `MERGED`, pero su merge está
#: igual en la rama de integración.
#:
#: Está vacía y es una lista y no una regla porque no hay ninguna: la API no distingue un PR
#: mergeado fuera de GitHub de uno abandonado —los dos dicen `CLOSED`—, así que lo único
#: honesto es nombrar los casos uno por uno cuando aparezcan. Si algún día se mergea a mano,
#: el que grita es el gate del mapa: el registro dirá `Propuesto` con el issue cerrado, que
#: es un rojo con una pregunta real detrás —¿ese PR implementó el spec?— y se contesta
#: agregando el número acá.
ATERRIZARON_A_MANO: frozenset[int] = frozenset()

#: El alfabeto de un `.md` publicable de un spec, y **el mismo de los dos lados**.
#:
#: Lo comparten `archivo_de_comentario` —que reconoce el encabezado al bajar— y el
#: `comentarios_de` de `publicar_spec.py` —que elige qué subir—. Que sea uno solo es el
#: punto: si el publicador aceptara más nombres que el lector, un archivo se subiría y no
#: volvería nunca; si aceptara menos, se perdería sin decirlo — y como `specs/[0-9]*/` está
#: ignorado, perderse quiere decir perderse de verdad en la hidratación siguiente.
#:
#: Es estrecho a propósito —minúsculas, dígitos y guiones— porque es también lo que
#: distingue un archivo de una DISCUSIÓN del issue: un comentario escrito a mano no arranca
#: con ``## `algo.md` ``.
NOMBRE_PUBLICABLE = re.compile(r"^[a-z0-9-]+\.md$")


def en_vuelo(estado: str) -> bool:
    """Si el spec sigue en vuelo, o sea si de él todavía puede salir trabajo.

    Lo usan tres consumidores y por motivos distintos —`hidratar_specs.py` para elegir qué
    traer por default, `publicar_spec.py` para decidir si cierra el issue, y el gate del
    mapa para saber qué estado del issue esperar—, y ésa es exactamente la razón de que
    viva una sola vez: con una copia escrita a mano en cada uno, sacar un estado del
    conjunto deja a los otros mirando uno que ya no existe, en verde.

    Un estado que no está en `ESTADOS` cuenta como en vuelo: lo desconocido no cierra nada.
    Que además sea ilegal lo dice el gate del mapa, que es quien tiene que gritar.
    """
    return estado not in _CERRADOS


def _validar_origen(id_spec: str, entrada: dict[str, Any]) -> None:
    """Que `origen` sea una lista de números de issue con al menos uno, si está.

    O se valida acá o no se valida nunca, y «nunca» tiene un modo de falla conocido: un
    `origen: 127` —un número suelto en vez de una lista— entra al registro **en silencio** y
    el error aparece tres pasos más allá, cuando el consumidor itera sobre un entero.
    """
    if "origen" not in entrada:
        return
    origen = entrada["origen"]
    if not isinstance(origen, list):
        raise ValueError(f"specs/mapa.json: la entrada {id_spec} trae `origen` y no es una lista.")
    if len(origen) == 0:
        # Una lista vacía no es «no tiene origen»: eso se dice omitiendo el campo. Aceptar
        # las dos formas es aceptar que el día que una se lea y la otra no, nadie se entere.
        raise ValueError(
            f"specs/mapa.json: la entrada {id_spec} trae `origen` vacío: omitilo en vez de vaciarlo."
        )
    for numero in origen:
        # Entero positivo, no «número» a secas: los issues se indexan por entero positivo,
        # así que un `"127"`, un `0` o un `1.5` no encuentran a nadie y el error sale como
        # «ese issue no existe», que es mentira y le echa la culpa a GitHub. La escritura no
        # puede producirlos —`origen_de` matchea `#(\d+)`— y por eso justamente hay que
        # atajarlos: la única vía de entrada es una mano editando el mapa.
        if isinstance(numero, bool) or not isinstance(numero, int) or numero <= 0:
            raise ValueError(
                f"specs/mapa.json: la entrada {id_spec} trae un `origen` que no es un número de issue."
            )


def leer_mapa(texto: str) -> dict[str, dict[str, Any]]:
    """`specs/mapa.json` parseado, y **grita** ante un mapa vacío, roto o incompleto.

    El grito es el punto. Un registro que devuelve `{}` cuando el formato cambió no reporta
    un error: reporta un registro vacío, y eso se lee como «no hay specs» — que es la
    respuesta contraria a la verdadera. El que lee el registro tiene que poder distinguir
    «roto» de «vacío», y también de «incompleto».
    """
    try:
        crudo = json.loads(texto)
    except json.JSONDecodeError as e:
        raise ValueError(f"specs/mapa.json no es JSON válido: {e}") from e

    if not isinstance(crudo, dict):
        raise ValueError('specs/mapa.json tiene que ser un objeto `{ "NNN": {…} }`.')

    for id_spec, entrada in crudo.items():
        if not isinstance(entrada, dict):
            raise ValueError(f"specs/mapa.json: la entrada {id_spec} no es un objeto.")
        for campo, tipo in CAMPOS.items():
            valor = entrada.get(campo)
            # `bool` es subclase de `int` en Python: sin excluirlo, `issue: true` pasa.
            if isinstance(valor, bool) or not isinstance(valor, tipo):
                raise ValueError(
                    f"specs/mapa.json: la entrada {id_spec} no trae `{campo}` como {tipo.__name__}."
                )
        _validar_origen(id_spec, entrada)

    return crudo


def escribir_mapa(mapa: dict[str, dict[str, Any]]) -> str:
    """El texto de `specs/mapa.json`: **una entrada por línea**, ordenadas por `NNN`.

    Devuelve el texto en vez de escribir el archivo para que se pueda testear sin tocar el
    disco: el `write_text` queda del lado de cada script.

    **El formato no es estética.** Con un JSON indentado cada entrada ocupa siete líneas, así
    que agregar un spec da un diff de siete y cambiar un estado da uno que hay que leer con
    lupa. Así cada cambio es exactamente la línea del spec que cambió — que es lo que hace
    revisable el commit que la Action de `mapa.yml` hace sola.
    """
    cuerpo = ",\n".join(
        f'  "{id_spec}": {json.dumps(mapa[id_spec], ensure_ascii=False, separators=(",", ":"))}'
        for id_spec in sorted(mapa)
    )
    return f"{{\n{cuerpo}\n}}\n"


def estado_de(mapa: dict[str, dict[str, Any]], id_spec: str) -> str | None:
    """El estado que el registro declara para un spec, o `None` si no tiene entrada.

    Ese `None` no es un detalle: un spec recién escrito **todavía no** está en el mapa, y
    confundirlo con un estado terminal es lo que cierra su issue apenas nace.
    """
    entrada = mapa.get(id_spec)
    return entrada["estado"] if entrada else None


def url_de_issue(repo: str, numero: int) -> str:
    """La URL de un issue. El repo se pasa: este archivo no habla con git ni con la red."""
    return f"https://github.com/{repo}/issues/{numero}"


# ── Publicar e hidratar ───────────────────────────────────────────────────────

#: El encabezado que `publicar_spec.py` le pone a cada comentario para decir qué archivo es.
#:
#: El separador se escribe entero en vez de un `\\s*` codicioso, y las dos partes tienen
#: motivo. `\\s*` se come **todas** las líneas en blanco que sigan, así que un archivo que
#: arrancara con una línea vacía volvería del issue sin ella y el round-trip byte por byte
#: dejaría de valer. Y el `\\r` va explícito porque la API devuelve CRLF: sin eso el corte
#: deja un retorno de carro colgado adelante.
_ENCABEZADO_DE_COMENTARIO = re.compile(r"^##\s+`([a-z0-9-]+\.md)`[^\S\r\n]*\r?\n(?:\r?\n)?")


def archivo_de_comentario(cuerpo: str) -> tuple[str, str] | None:
    """Un comentario del issue vuelve a ser su archivo: `(nombre, contenido)`.

    Devuelve `None` cuando no lleva el encabezado, y eso es lo que distingue un archivo de
    una **discusión** del issue: sin esto, el primer comentario que alguien escriba a mano se
    escribiría al disco como si fuera parte del spec.
    """
    m = _ENCABEZADO_DE_COMENTARIO.match(cuerpo)
    if m is None:
        return None
    return m.group(1), cuerpo[m.end() :]


#: Las referencias a otro spec por ruta, en las dos formas que existen: la relativa desde
#: adentro de `specs/` (`./005-…/spec.md`) y la que llega desde afuera (`specs/005-…/spec.md`).
#:
#: **El `(?!:\d)` del final no es cosmético: sin él esto destruye mediciones.** Una cita con
#: rango —`specs/016-…/research.md:59-60`, la forma en que este repo apunta a una medición—
#: matcheaba hasta el `.md` y dejaba el `:59-60` pegado a la URL, produciendo
#: `…/issues/20:59-60`, que no lleva a ninguna parte. Y como `hidratar_specs.py` escribe al
#: disco lo que el issue tiene, la URL rota **volvía** y pisaba la ruta original: para cuando
#: se ve, la referencia ya no se puede reconstruir. Medido el 2026-09-06 — ocho citas así en
#: el 007 y el 013, todas perdidas. Un issue no tiene número de línea, así que la traducción
#: no puede preservar lo que la cita quería decir: se deja verbatim.
_CITA_A_SPEC = re.compile(r"(?:\.{1,2}/)*(?:specs/)?(\d{3})-[a-z0-9-]+/[a-z0-9-]+\.md(?!:\d)")


def traducir(texto: str, mapa: dict[str, dict[str, Any]], repo: str) -> str:
    """Traduce las referencias a otro spec por la URL de su issue.

    **Es lo que permite no tocar un solo archivo de `specs/[0-9]*/`**: un spec mergeado no se
    reescribe, así que la traducción pasa a la publicación. Lo que no está en el mapa se deja
    como estaba.

    El nombre del archivo se acepta con el mismo alfabeto que se publica y no con una lista
    de cuatro: si acá entraran menos nombres, un enlace a un archivo extra —un `baseline.md`,
    un `reparto.md`— se subiría al issue **verbatim**, o sea una ruta relativa a un directorio
    ignorado: un enlace muerto.
    """

    def reemplazo(m: re.Match[str]) -> str:
        entrada = mapa.get(m.group(1))
        return url_de_issue(repo, entrada["issue"]) if entrada else m.group(0)

    return _CITA_A_SPEC.sub(reemplazo, texto)


def carpeta_existente(carpetas: list[str], id_spec: str) -> str | None:
    """La carpeta de un spec entre las que ya están, emparejando por `NNN`.

    **Por el número y no por el nombre completo.** El mapa dice cómo se llama, pero una caché
    hidratada antes de un cambio de título puede tener otro nombre, y tratar ese nombre viejo
    como «el spec no está» crearía una SEGUNDA carpeta para el mismo spec — dos carpetas con
    el mismo `NNN`, que hacen que todo lo que cuente specs los cuente dos veces sin avisar.
    """
    for carpeta in carpetas:
        if carpeta.startswith(f"{id_spec}-"):
            return carpeta
    return None


_LINEA_DE_ORIGEN = re.compile(r"^\*\*Origen:\*\*(.*)$", re.MULTILINE)


def origen_de(spec: str) -> list[int] | None:
    """Los issues que un `spec.md` declara **saldar**, de su línea `**Origen:** #127, #124`.

    Tres decisiones, y las tres son sobre qué NO cuenta:

    - **Sólo el encabezado**, o sea antes del primer `##`. Un `#127` suelto en la prosa no es
      un origen: si lo fuera, un spec que cita un issue como *contexto* de una medición que no
      arregla quedaría declarando un origen que no salda, y el gate daría rojo sobre un spec
      correcto.
    - **Sin la línea, `None`**, que el llamador traduce a no escribir el campo. No a
      `origen: []`, que `leer_mapa` rechaza.
    - **Con la línea y sin ningún `#N`, grita.** Un `**Origen:** el issue del inventario` es un
      error de quien escribe el spec, y devolver `[]` lo convierte en un spec sin vínculo, en
      silencio.
    """
    encabezado = re.split(r"^##\s", spec, maxsplit=1, flags=re.MULTILINE)[0]
    linea = _LINEA_DE_ORIGEN.search(encabezado)
    if linea is None:
        return None
    numeros = [int(n) for n in re.findall(r"#(\d+)", linea.group(1))]
    if not numeros:
        raise ValueError(
            f'el `**Origen:**` del spec no nombra ningún issue: "{linea.group(0).strip()}"'
        )
    return numeros


# ── Derivar el mapa desde los PR ──────────────────────────────────────────────


def agrupar_prs_por_spec(prs: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    """Los PR agrupados por el `NNN` de su rama. Los que no nombran un spec no entran."""
    por_spec: dict[str, list[dict[str, Any]]] = {}
    for pr in prs:
        m = RAMA_DE_SPEC.match(pr["headRefName"])
        if m is None:
            continue
        por_spec.setdefault(m.group(1), []).append(pr)
    return por_spec


def aterrizo(prs: list[dict[str, Any]] | None) -> bool:
    """Si el trabajo de un spec llegó a la rama de integración.

    **`MERGED`, o uno de los que aterrizaron a mano.** Un `CLOSED` a secas NO cuenta, y el
    motivo es que esta regla la lee un **escritor** que commitea: si un `feature/044-x` se
    abre y se cierra sin mergear, contarlo derivaría el 044 a `Implementado`, y a partir de
    ahí el cruce contra el issue —abierto— pondría en rojo todos los PR siguientes, incluidos
    los que no tocan nada de esto. Arreglar el mapa a mano no serviría: el push siguiente lo
    vuelve a escribir.

    El error queda del lado barato: un PR abandonado deja el spec en `Propuesto`, que es lo
    que era.
    """
    return any(pr["state"] == "MERGED" or pr["number"] in ATERRIZARON_A_MANO for pr in (prs or []))


def derivar_mapa(
    mapa: dict[str, dict[str, Any]],
    issues: dict[int, dict[str, Any]],
    prs_por_spec: dict[str, list[dict[str, Any]]],
) -> tuple[dict[str, dict[str, Any]], list[tuple[str, str, str, str]]]:
    """El mapa que se deduce de los PR y los issues, y la lista de lo que cambió.

    Devuelve `(mapa_derivado, correcciones)`, donde cada corrección es
    `(id_spec, campo, de, a)`.

    **El estado de un spec no es un dato que alguien escribe: es una consecuencia.** Su PR
    aterrizó o no, y eso no lo escribe nadie a mano.

    Lo que NO se deriva, y por qué:

    - **`carpeta`**, porque no es derivable del título: los dos se escriben aparte y se
      separan. Un árbol recién hidratado que la dedujera inventaría carpetas que ninguna cita
      del repo conoce.
    - **`fecha`**, porque es cuándo se escribió el spec, no cuándo aterrizó.
    - **`issue`**, porque es la clave que une las dos fuentes: derivarlo sería derivar de sí
      mismo.
    - **`origen`**, porque es una declaración de intención —qué issue de deuda SALDA este
      spec— y no una consecuencia observable: GitHub no distingue «lo cierra» de «lo
      menciona». Lo conserva la copia de abajo.
    - **Las entradas que no están.** Un spec entra al registro con `publicar_spec.py crear` y
      no de otra forma. Un PR cuya rama nombra un `NNN` ausente del mapa no agrega nada: es
      una rama mal nombrada o un spec sin publicar, y las dos veces inventarle una entrada
      sería peor que la falta.

    Y un issue que no está en el diccionario **deja el título como estaba** en vez de
    vaciarlo: ahí la respuesta cierta es «no lo pude leer», y quien grita por un spec que
    apunta a un issue inexistente es el gate, que tiene el mensaje para decirlo.
    """
    correcciones: list[tuple[str, str, str, str]] = []
    derivado: dict[str, dict[str, Any]] = {}

    for id_spec, entrada in mapa.items():
        if entrada["estado"] in NO_LOS_MUEVE_UN_MERGE:
            estado = entrada["estado"]
        else:
            estado = "Implementado" if aterrizo(prs_por_spec.get(id_spec)) else "Propuesto"

        issue = issues.get(entrada["issue"])
        titulo = issue["title"] if issue else entrada["titulo"]

        if estado != entrada["estado"]:
            correcciones.append((id_spec, "estado", entrada["estado"], estado))
        if titulo != entrada["titulo"]:
            correcciones.append((id_spec, "titulo", entrada["titulo"], titulo))

        # Copia y sobrescritura, no un dict literal nuevo: en Python un dict conserva el
        # orden de inserción y reasignar una clave que ya existe NO la mueve de lugar. Así
        # los campos salen en el orden con el que la fila se generó, y cambiar un estado da
        # un diff de una línea en vez de una línea reordenada.
        nueva = dict(entrada)
        nueva["estado"] = estado
        nueva["titulo"] = titulo
        derivado[id_spec] = nueva

    return derivado, correcciones


# ── El censo de deuda ─────────────────────────────────────────────────────────


def deuda_del_censo(
    issues: list[dict[str, Any]], mapa: dict[str, dict[str, Any]]
) -> list[dict[str, Any]]:
    """Los issues que **ningún spec reclama**: ni son el issue de un spec ni figuran en el
    `origen` de ninguno. O sea, la deuda que hay para promover.

    Es una resta de conjuntos y nada más, y esa pobreza es el punto: **puro, sin red**, así
    que se prueba con dos listas escritas a mano. Quien habla con `gh` es `deuda.py`.

    `origen` cuenta igual que `issue` porque las dos formas son «este issue ya tiene dueño».
    Sin esa mitad, el censo seguiría mostrando lo que un spec acaba de reclamar.
    """
    reclamados: set[int] = set()
    for entrada in mapa.values():
        reclamados.add(entrada["issue"])
        reclamados.update(entrada.get("origen", []))
    return [i for i in issues if i["number"] not in reclamados]


# ── El texto de un spec ───────────────────────────────────────────────────────
#
# Lo leen DOS gates y por eso vive acá: el de la convención —los techos de palabras, sobre
# los specs en vuelo que estén en disco— y el de los criterios de la rama —que cada `ACn`
# esté citado por un test—. Dos copias que se separen dan dos gates que dicen contar lo
# mismo y cuentan distinto, y el que se equivoca es siempre el que nadie mira.

#: El encabezado del bloque de criterios, que es lo que parte el `spec.md` en sus dos
#: mitades con techos distintos.
ENCABEZADO_DE_AC = re.compile(r"^##\s+Criterios de aceptaci[oó]n\s*$", re.MULTILINE)

#: Un criterio, tal como el resto del repo lo nombra: `AC1`, `AC17`.
AC = re.compile(r"\bAC(\d+)\b")

#: Qué cuenta como palabra: un token con al menos una letra o un dígito.
#:
#: La definición importa porque el techo se apoya en ella. Sin esto, un «—», un `**` suelto y
#: el `-` de cada viñeta cuentan como palabras, y entonces el techo se lo lleva el markdown en
#: vez de la prosa — o sea que reescribir una lista como párrafo «ahorra» palabras sin haber
#: sacado ni una idea.
PALABRA = re.compile(r"[0-9A-Za-zÀ-ÖØ-öø-ÿ]")

#: Un comentario de markdown, que acá es **andamio y no contenido**.
#:
#: Es lo que `specs/plantilla/` usa para explicar cada rubro, y lo que quien escribe el spec
#: borra. Contarlo lo vuelve una plantilla inusable, y no es una hipótesis: medido el
#: 2026-09-06, su `plan.md` daba **386 palabras contra un techo de 250** sin una sola palabra
#: propia, y su `### Rutas` declaraba intocables `src/`, `reglas.gd` y `tasks.md` —todas
#: citadas por la prosa que explica el rubro, incluida la que ese mismo párrafo dice que NO
#: va—. O sea que copiar la plantilla arrancaba con dos gates en rojo.
#:
#: No abre una vía de evasión del techo: un comentario no se ve en el issue renderizado, así
#: que las palabras que se «ahorran» ahí no le llegan a nadie.
COMENTARIO_MD = re.compile(r"<!--.*?-->", re.DOTALL)


def sin_comentarios(texto: str) -> str:
    """El texto sin sus comentarios de markdown."""
    return COMENTARIO_MD.sub("", texto)


def palabras(texto: str) -> int:
    """Las palabras de un texto en markdown: los tokens que tienen letra o dígito.

    Sin lo que viva en un comentario, que es andamio de la plantilla y no texto del spec.
    """
    return sum(1 for token in sin_comentarios(texto).split() if PALABRA.search(token))


def partir_spec(texto: str) -> tuple[str, str]:
    """El `spec.md` partido en `(prosa, bloque de criterios)`.

    **El encabezado `## Criterios de aceptación` cuenta del lado de los criterios**, y no es
    un detalle de tres palabras: es lo que hace que mover el encabezado no mueva palabras de
    un techo al otro.

    Un `spec.md` sin ese encabezado devuelve todo como prosa y el bloque vacío. No se ataja
    acá: un spec sin criterios lo caza el techo de prosa o el gate de criterios, y duplicar
    la regla la deja con dos mensajes distintos para el mismo defecto.

    **Los encabezados de adentro de un bloque cercado no cortan**, que es el mismo agujero
    que `sin_cercados()` cierra para el `plan.md`. Un `spec.md` que muestra el formato de un
    spec —el 003 lo hace con el suyo— se partía por el encabezado del EJEMPLO: la prosa se
    quedaba con los criterios reales, el bloque salía vacío, y entonces su techo dejaba de
    morder y `acs_de()` contestaba cero criterios sobre un spec que los tiene.
    """
    inicio, fin = _corte_del_bloque(texto)
    if inicio is None:
        return texto, ""
    if fin is None:
        return texto[:inicio], texto[inicio:]
    return texto[:inicio] + texto[fin:], texto[inicio:fin]


def _corte_del_bloque(texto: str) -> tuple[int | None, int | None]:
    """Dónde empieza el bloque de criterios y dónde el `##` que lo cierra, sin contar cercados.

    Los dos son offsets en el texto original —y no en una copia limpia— porque `partir_spec()`
    devuelve las dos mitades verbatim: `_criterios()` las vuelve a buscar ahí para numerar sus
    líneas, y un slice de otro texto le daría un número que no existe en el archivo.
    """
    inicio: int | None = None
    offset = 0
    for linea, dentro in _con_cerca(texto):
        largo = len(linea) + 1
        if not dentro:
            if inicio is None:
                if ENCABEZADO_DE_AC.match(linea):
                    inicio = offset
            elif offset > inicio and linea.startswith("## "):
                return inicio, offset
        offset += largo
    return inicio, None


def acs_de(spec_md: str) -> list[str]:
    """Los criterios que un `spec.md` declara, en orden y sin repetir.

    Sólo los del bloque de criterios: un `AC3` citado en la prosa del problema es una
    referencia a otro spec, no una promesa de éste.
    """
    _, criterios = partir_spec(spec_md)
    vistos: list[str] = []
    for numero in AC.findall(criterios):
        nombre = f"AC{int(numero)}"
        if nombre not in vistos:
            vistos.append(nombre)
    return vistos


def acs_sin_test(numero: str, acs: list[str], textos: list[str]) -> list[str]:
    """Los criterios que ningún test nombra, con la cita **calificada por el número del spec**.

    La cita es `NNN-ACn` —`030-AC1`— y no `AC1` a secas. No es estilo: `AC1` es el nombre que
    usa **todo** spec, así que con la cita pelada el primer test que escribiera `AC1` dejaría
    cubierto el `AC1` de todos los specs que vengan después, para siempre. El gate no podría
    volver a fallar, que es exactamente el gate apagado que parece encendido que este ancla
    vino a cerrar.

    **Por nombre**, que es lo que hace accionable el rojo: «falta 030-AC4» se arregla; «hay un
    criterio sin test» hay que ir a buscarlo.
    """
    return [ac for ac in acs if not any(re.search(rf"\b{numero}-{ac}\b", texto) for texto in textos)]


# ── La estructura del `plan.md` ───────────────────────────────────────────────

#: Una línea que abre o cierra un bloque cercado, con backticks o con tildes.
CERCA = re.compile(r"^\s{0,3}(```+|~~~+)")

#: Un encabezado markdown.
ENCABEZADO_MD = re.compile(r"^#{1,6}\s")


def _con_cerca(texto: str):
    """Cada línea con si está adentro de un bloque cercado. Las cercas mismas cuentan adentro."""
    adentro = False
    for linea in texto.splitlines():
        if CERCA.match(linea):
            adentro = not adentro
            yield linea, True
            continue
        yield linea, adentro


def estados_reescritos(base: dict, rama: dict) -> list[str]:
    """Los specs cuyo `estado` la rama cambió respecto de la base, ya escritos para el rojo.

    **Una fila nueva no cuenta.** Abrir un spec escribe el mapa —es lo que hace
    `publicar_spec.py crear`— así que exigir que el mapa no se toque prohibiría el flujo. Lo
    que no se escribe a mano es el estado de un spec **que ya estaba**: ése lo deriva
    `.github/workflows/mapa.yml` del PR que aterrizó.

    Sin esto la regla se evade escribiendo el archivo: un spec en vuelo al que le pongan
    `Implementado` deja de ser mirado por `test_convencion_de_specs.py` —`es_adr()` lo saltea
    por ADR— y ninguna herramienta lo dice. Tres archivos del repo afirmaban que este gate
    existía antes de que existiera.
    """
    return [
        f"{numero}: `{base[numero].get('estado')}` → `{fila.get('estado')}`"
        for numero, fila in sorted(rama.items())
        if numero in base and base[numero].get("estado") != fila.get("estado")
    ]


#: Un encabezado markdown, con su texto.
ENCABEZADO_CON_TEXTO = re.compile(r"^#{1,6}\s+(.*?)\s*$")


def encabezados_con_linea(texto: str) -> list[tuple[int, str]]:
    """Los encabezados de un `.md`, como `(número de línea, texto)`, sin los cercados.

    **Un encabezado adentro de un bloque cercado es un ejemplo, no una sección**, y contarlo da
    rojo sobre un archivo correcto: el `research.md` que muestre un `## Pendientes` para
    explicar que está prohibido queda acusado de tenerlo. La línea se conserva porque el rojo
    la nombra —`spec.md:41` se abre; «hay una sección que aplaza» hay que ir a buscarla—.
    """
    return [
        (numero, m.group(1))
        for numero, (linea, dentro) in enumerate(_con_cerca(texto), 1)
        if not dentro and (m := ENCABEZADO_CON_TEXTO.match(linea))
    ]


def cercado_sin_cerrar(texto: str) -> bool:
    """Si el texto deja un bloque cercado abierto.

    Es el modo de falla más silencioso de este parser y por eso tiene su propio rojo: con una
    cerca huérfana, `sin_cercados()` se come **todo lo que sigue**, así que un `### Rutas`
    escrito después devuelve cero rutas y `test_rutas_del_plan.py` se saltea con cara de haber
    mirado. Medido el 2026-09-06 — `sin_cercados("a\\n```\\nb\\nc\\n")` devuelve `"a"`.
    """
    return sum(1 for linea in texto.splitlines() if CERCA.match(linea)) % 2 == 1


def sin_cercados(texto: str) -> str:
    """El texto sin lo que vive adentro de un bloque cercado.

    Existe porque un barrido de encabezados cuenta como sección un ejemplo pegado adentro de un
    bloque: el `plan.md` del 003 muestra el formato de una entrada de troubleshooting con un
    encabezado de ejemplo, y la primera versión de este barrido lo reportó como sección rota.
    Medido el 2026-09-06.
    """
    return "\n".join(l for l, dentro in _con_cerca(texto) if not dentro)


def sin_encabezados(texto: str) -> str:
    """El texto sin sus líneas de encabezado, **conservando las de adentro de un bloque**.

    Lo usa el techo del `plan.md`, y el porqué es una medición: el margen contra las 250
    palabras era **cero** —el 012 tenía exactamente 250— así que rotular la estructura costaba
    un rojo. El techo limita el **contenido**; no le cobra peaje a los encabezados que el
    formato ahora exige.

    Un encabezado adentro de un bloque cercado **sí cuenta**: ahí es un ejemplo, o sea texto que
    el autor escribió, y descontarlo le regalaría palabras a quien lo pegue.
    """
    return "\n".join(
        l for l, dentro in _con_cerca(texto) if dentro or not ENCABEZADO_MD.match(l)
    )


#: Los tres encabezados que un `plan.md` declara, exactos y en este orden.
#:
#: Son los que 23 de 23 specs en vuelo ya tenían el 2026-09-06 —la convención existía y no la
#: exigía nadie— y el primero lo lee `spec-implement/SKILL.md` **por nombre**. Un skill que
#: depende de una sección que se cumple por costumbre es la forma en que este repo se rompe.
ENCABEZADOS_DEL_PLAN = ("## Orden obligado", "## Qué NO se toca", "## Criterio de terminado")

#: El rótulo de la mitad cruzable del `## Qué NO se toca`. Opcional: cuatro specs —013, 020,
#: 021 y 027— sólo declaran invariantes, y exigirles una ruta los pondría en rojo estando bien.
RUBRO_DE_RUTAS = "### Rutas"

#: Lo que cuenta como ruta adentro de ese rubro: una cita entre backticks con extensión conocida
#: o terminada en `/`.
#:
#: **Va con rótulo y no por inferencia sobre el párrafo entero**, y eso es medido: el `plan.md`
#: del 012 cita `.claude/rules/dominio.md` como la *fuente* de una lista, no como un archivo
#: prohibido. Inferir la prohibición de la forma de la cita lo habría declarado intocable, y el
#: cruce contra el diff daría rojo sobre un PR correcto.
RUTA = re.compile(r"`([^`]+?\.(?:gd|tscn|tres|py|md|json|cfg|yml|yaml|godot|sh)|[^`]+?/)`")


def encabezados_del_plan(texto: str) -> list[str]:
    """Los `##` de un `plan.md`, ya sin lo cercado ni lo comentado, normalizados a una línea."""
    return [
        l.strip() for l in sin_cercados(sin_comentarios(texto)).splitlines() if l.startswith("## ")
    ]


def rutas_intocables(texto: str) -> list[str]:
    """Las rutas que el `### Rutas` del plan declara, en orden y sin repetir.

    Devuelve `[]` cuando el rubro no está, que es un estado normal y no un defecto: un spec
    puede restringir sólo invariantes.

    **Lo comentado no prohíbe nada**: el párrafo que explica el rubro cita rutas para
    ilustrarlo —el de la plantilla citaba hasta la que dice que NO va acá— y contarlas deja al
    spec prohibiendo `src/` antes de escribir una línea propia.
    """
    cuerpo = sin_cercados(sin_comentarios(texto))
    # **Por línea entera y no por substring**: `#### Rutas` CONTIENE `### Rutas`, así que un
    # rubro de otro nivel se leía como éste y sus citas pasaban a ser prohibiciones. Y sin el
    # `$`, un `### Rutas del research` también entraba. La forma vieja además pedía un `\n`
    # detrás, o sea que el rubro como última línea del archivo no se encontraba — callado.
    rubro = re.search(rf"^{re.escape(RUBRO_DE_RUTAS)}\s*$", cuerpo, re.MULTILINE)
    if rubro is None:
        return []
    resto = cuerpo[rubro.end() :]
    corte = re.search(r"^#{2,3}\s", resto, re.MULTILINE)
    if corte:
        resto = resto[: corte.start()]
    vistas: list[str] = []
    for ruta in RUTA.findall(resto):
        if ruta not in vistas:
            vistas.append(ruta)
    return vistas

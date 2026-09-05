"""El gate de la convención de specs, sobre los que estén hidratados en disco.

`specs/[0-9]*/` es caché: en un clone nuevo no hay ninguno y este archivo entero se saltea.
Eso está bien, y por eso **se declara**: un gate que mira cero specs y dice «OK» es
indistinguible de uno que los miró todos, que es la peor respuesta posible.

Para que mire todo el árbol hace falta traerlo:

    python .claude/scripts/hidratar_specs.py --todos

**Hay dos regímenes y el número decide cuál.** Los specs ≤ 029 se escribieron con cuatro
archivos y su ancla anti-deuda es la casilla; del 030 en adelante son tres archivos con techo
de palabras y el ancla es AC↔test. El corte es por número y no por qué archivos hay en disco,
que es lo único que no se puede evadir escribiendo el archivo que falta.
"""

import re
import unittest

from lib.repo import RAIZ
from lib.specs import leer_mapa

SPECS = RAIZ / "specs"

#: El primer spec del régimen nuevo. **Es 030 y no 029**, y está medido: una carpeta de tres
#: archivos rompe seis tests del gate vigente, así que el 029 —que es el spec que estrena esta
#: regla— no puede escribirse con ella sin dejar el nodo `harness` en rojo antes de que exista
#: su rama. Una regla que arranca en el spec que la propone no se puede publicar.
PRIMER_SPEC_NUEVO = 30

#: Los cuatro archivos del régimen viejo. Son el **piso**, no el techo.
CANONICOS = ("spec.md", "research.md", "plan.md", "tasks.md")

#: Los tres del régimen nuevo. Acá son piso **y** techo para los dos que se fueron: un
#: `plan.md` o un `tasks.md` en un spec ≥ 030 no es un archivo de más, es el régimen viejo
#: entrando por la ventana — y con él vuelve la predicción de rutas que este corte existe para
#: sacar.
CANONICOS_NUEVOS = ("spec.md", "research.md", "estrategia.md")
DESTERRADOS = ("plan.md", "tasks.md")

#: Los cuatro techos de palabras.
#:
#: **Uno cae sobre el bloque de criterios entero y no sobre cada criterio**, y ésa es la
#: decisión que hace que el techo sirva: con un límite por AC, un spec cumple escribiendo
#: veinte AC cortos, que es la misma enfermedad con carpeta nueva. Sobre el bloque, el límite
#: muerde la **cantidad**.
#:
#: Los números salen de medir el `spec.md` del 029, que es el modelo del formato: prosa 349,
#: bloque de criterios 228, `research.md` 444, `estrategia.md` 233. O sea que están calibrados
#: contra un documento que existe y entra, no elegidos de memoria. Lo verifica
#: `test_los_techos_admiten_el_spec_que_los_estrena`.
TECHO_DE_PROSA = 350
TECHO_DE_AC = 300
TECHO_DE_RESEARCH = 500
TECHO_DE_ESTRATEGIA = 250

#: El encabezado del bloque de criterios de aceptación, que es lo que parte el `spec.md` en
#: sus dos mitades con techos distintos.
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

#: `- [ ] T012 [P] Descripción`, con `[P]` opcional.
TAREA = re.compile(r"^- \[[ x]\] (T\d{3})( \[P\])? \S")

#: Una casilla que no respeta el formato: empieza como tarea y no matchea `TAREA`.
CASILLA = re.compile(r"^- \[[ x]\] ")

#: Una casilla sin marcar.
ABIERTA = re.compile(r"^- \[ \] ")

#: Un encabezado markdown, con su texto.
ENCABEZADO = re.compile(r"^#{1,6}\s+(.*?)\s*$")

#: Las secciones que aplazan trabajo, y por eso no existen acá.
#:
#: **`Fuera de alcance` no está en la lista y es deliberado**: declara una frontera —qué NO hace
#: este spec— y es lo que lo vuelve revisable. Se convierte en deuda sólo cuando algún AC del
#: propio spec depende de lo excluido, y eso ningún gate lo puede ver: lo mira el review. Lo
#: mismo con `Riesgos`, que analiza y no promete.
SECCION_QUE_APLAZA = re.compile(
    r"^(seguimiento|pendientes?|deuda|backlog|to-?do|futuro|a futuro|"
    r"pr[oó]ximos pasos|queda pendiente|para (m[aá]s adelante|despu[eé]s))\b",
    re.IGNORECASE,
)

#: Aplazar por texto adentro de una tarea. Una casilla que dice «por ahora» no es una tarea:
#: es una intención con formato de checklist, y se cierra marcándola sin haber hecho nada.
#:
#: **Son dos y no una porque el repo escribe en español.** Los marcadores de código van SIN
#: `IGNORECASE`: con él, `\bTODO\b` matchea la palabra «todo», y la primera corrida de este
#: gate se cazó a sí misma contra `T001 … todo tipo del enum tiene costo declarado`. Un gate
#: que da rojo sobre una tarea correcta se apaga en una semana, y ahí no queda gate.
MARCADOR_DE_CODIGO = re.compile(r"\bTODO\b|\bFIXME\b|\bXXX\b|\bHACK\b")

TAREA_QUE_APLAZA = re.compile(
    r"pendiente|m[aá]s adelante|a futuro|en el futuro|queda para|por ahora|provisori|"
    r"si (hay|sobra) tiempo|eventualmente|idealmente",
    re.IGNORECASE,
)

#: Una medición declarada como no hecha. El `research.md` sale de correr algo: una medición
#: aplazada es la deuda más cara del flujo, porque el plan entero se apoya en un número que
#: nadie midió y el spec igual se publica.
MEDICION_APLAZADA = re.compile(
    r"medici[oó]n pendiente|queda por medir|sin medir|no se pudo medir|falta medir|"
    r"pendiente de medir|habr[ií]a que medirlo",
    re.IGNORECASE,
)

#: El único estado en el que una casilla abierta —o un criterio sin test— es una
#: contradicción. `Descartado` y `Superado` son terminales —son historia y no se corrigen—, y
#: `Propuesto` es la cola.
CERRADO = "Implementado"

#: Dónde se busca la cita de un criterio. Son dos árboles porque este repo tiene dos suites:
#: la de gdUnit4 sobre el juego y la de unittest sobre el harness, y un spec puede caer entero
#: de cualquiera de los dos lados.
ARBOLES_DE_TEST = (RAIZ / "test", RAIZ / ".claude" / "scripts" / "tests")


def numero_de(carpeta: str) -> int:
    """`030-el-spec-nuevo` → `30`."""
    return int(carpeta[:3])


def es_nuevo(carpeta: str) -> bool:
    return numero_de(carpeta) >= PRIMER_SPEC_NUEVO


def palabras(texto: str) -> int:
    """Las palabras de un texto en markdown: los tokens que tienen letra o dígito."""
    return sum(1 for token in texto.split() if PALABRA.search(token))


def partir_spec(texto: str) -> tuple[str, str]:
    """El `spec.md` partido en `(prosa, bloque de criterios)`.

    **El encabezado `## Criterios de aceptación` cuenta del lado de los criterios**, y no es
    un detalle de tres palabras: es lo que hace que mover el encabezado no mueva palabras de
    un techo al otro.

    Un `spec.md` sin ese encabezado devuelve todo como prosa y el bloque vacío. No se ataja
    acá: un spec sin criterios lo caza el techo de prosa o el gate de AC↔test, y duplicar la
    regla la deja con dos mensajes distintos para el mismo defecto.
    """
    corte = ENCABEZADO_DE_AC.search(texto)
    if corte is None:
        return texto, ""
    resto = texto[corte.start() :]
    # Desde el carácter 3 para no volver a matchear el propio encabezado del bloque.
    siguiente = re.search(r"^##\s", resto[3:], re.MULTILINE)
    if siguiente is None:
        return texto[: corte.start()], resto
    fin = siguiente.start() + 3
    return texto[: corte.start()] + resto[fin:], resto[:fin]


def problemas_de_forma(carpeta: str, presentes: set[str]) -> list[str]:
    """Qué archivos le faltan o le sobran a un spec, según el régimen que le toca.

    Puro —recibe el conjunto de nombres, no lee el disco— porque es la única forma de sondear
    el caso que todavía no existe en el árbol: un spec del régimen nuevo antes de que haya uno.
    """
    esperados = CANONICOS_NUEVOS if es_nuevo(carpeta) else CANONICOS
    problemas = [f"{carpeta}: falta {archivo}" for archivo in esperados if archivo not in presentes]
    if es_nuevo(carpeta):
        problemas += [
            f"{carpeta}: {archivo} es del régimen viejo y este spec es ≥ {PRIMER_SPEC_NUEVO:03d}"
            for archivo in DESTERRADOS
            if archivo in presentes
        ]
    return problemas


def problemas_de_techo(carpeta: str, archivos: dict[str, str]) -> list[str]:
    """Qué techo de palabras pasa un spec del régimen nuevo.

    Los archivos ausentes no cuentan: de ésos habla `problemas_de_forma`, y contarlos acá
    daría dos rojos por un solo defecto.
    """
    problemas: list[str] = []

    def medir(nombre: str, texto: str, techo: int, que: str) -> None:
        cuantas = palabras(texto)
        if cuantas > techo:
            problemas.append(
                f"{carpeta}/{nombre}: {que} tiene {cuantas} palabras y el techo es {techo}"
            )

    if "spec.md" in archivos:
        prosa, criterios = partir_spec(archivos["spec.md"])
        medir("spec.md", prosa, TECHO_DE_PROSA, "la prosa")
        medir("spec.md", criterios, TECHO_DE_AC, "el bloque de criterios")
    if "research.md" in archivos:
        medir("research.md", archivos["research.md"], TECHO_DE_RESEARCH, "el research")
    if "estrategia.md" in archivos:
        medir("estrategia.md", archivos["estrategia.md"], TECHO_DE_ESTRATEGIA, "la estrategia")
    return problemas


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


def acs_sin_test(acs: list[str], textos: list[str]) -> list[str]:
    """Los criterios que ningún test nombra.

    **Por nombre**, que es lo que hace accionable el rojo: «falta AC4» se arregla; «hay un
    criterio sin test» hay que ir a buscarlo.
    """
    return [ac for ac in acs if not any(re.search(rf"\b{ac}\b", texto) for texto in textos)]


def hidratados() -> list[str]:
    if not SPECS.is_dir():
        return []
    return sorted(e.name for e in SPECS.iterdir() if e.is_dir() and re.match(r"^\d{3}-", e.name))


def textos_de_test() -> list[str]:
    return [
        archivo.read_text(encoding="utf-8", errors="replace")
        for arbol in ARBOLES_DE_TEST
        if arbol.is_dir()
        for archivo in arbol.rglob("*")
        if archivo.is_file() and archivo.suffix in (".gd", ".py")
    ]


class Convencion(unittest.TestCase):
    """El gate sobre el árbol hidratado."""

    def setUp(self):
        self.carpetas = hidratados()
        if not self.carpetas:
            self.skipTest(
                "no hay ningún spec hidratado en disco: este gate NO miró nada. "
                "`python .claude/scripts/hidratar_specs.py --todos` los trae."
            )
        # La partición que decide qué regla mira a quién. Las reglas de casillas leen el
        # `tasks.md`, que en el régimen nuevo no existe: sin partir acá, cada una abriría un
        # archivo ausente y el gate se caería con un `FileNotFoundError` en vez de decir qué
        # está mal.
        self.viejas = [c for c in self.carpetas if not es_nuevo(c)]
        self.nuevas = [c for c in self.carpetas if es_nuevo(c)]

    def _canonicos(self, carpeta: str) -> tuple[str, ...]:
        return CANONICOS_NUEVOS if es_nuevo(carpeta) else CANONICOS

    def _cerrados_en_disco(self) -> list[tuple[str, str]]:
        """Los specs `Implementado` que además están hidratados, como `(NNN, carpeta)`.

        Los que no están en disco quedan afuera: este gate no los puede mirar, y el `setUp` ya
        declaró que el árbol puede estar incompleto.
        """
        mapa = leer_mapa((SPECS / "mapa.json").read_text(encoding="utf-8"))
        return [
            (numero, fila["carpeta"])
            for numero, fila in mapa.items()
            if fila.get("estado") == CERRADO and fila.get("carpeta") in self.carpetas
        ]

    def test_cada_spec_tiene_los_archivos_de_su_regimen(self):
        for carpeta in self.carpetas:
            presentes = {f.name for f in (SPECS / carpeta).iterdir() if f.is_file()}
            self.assertEqual(problemas_de_forma(carpeta, presentes), [], carpeta)

    def test_el_spec_arranca_con_su_encabezado(self):
        # De esa línea sale el título del issue: sin ella, `publicar_spec.py` no tiene qué
        # publicar.
        for carpeta in self.carpetas:
            primera = (SPECS / carpeta / "spec.md").read_text(encoding="utf-8").splitlines()[0]
            self.assertTrue(primera.startswith("# "), f"{carpeta}/spec.md: «{primera[:40]}»")

    def test_ningun_spec_nuevo_pasa_un_techo_de_palabras(self):
        # El techo es lo que reemplaza al `tasks.md` como límite de tamaño: sin él, el formato
        # nuevo es el viejo con un archivo menos.
        for carpeta in self.nuevas:
            archivos = {
                nombre: (SPECS / carpeta / nombre).read_text(encoding="utf-8")
                for nombre in CANONICOS_NUEVOS
                if (SPECS / carpeta / nombre).is_file()
            }
            self.assertEqual(problemas_de_techo(carpeta, archivos), [], carpeta)

    def test_todas_las_casillas_respetan_el_formato_de_tarea(self):
        for carpeta in self.viejas:
            texto = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                if CASILLA.match(linea):
                    self.assertRegex(linea, TAREA, f"{carpeta}/tasks.md:{numero}")

    def test_los_ids_de_tarea_no_se_repiten(self):
        # Los IDs son estables: no se renumeran al insertar una tarea nueva, se sigue contando.
        # Un ID libre no molesta a nadie; uno reusado rompe la referencia que otra tarea le
        # hacía, y el `spec_write` que la marca ya no sabe cuál de las dos es.
        for carpeta in self.viejas:
            texto = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            ids = TAREA.findall(texto)
            solos = [i[0] for i in ids]
            self.assertEqual(len(solos), len(set(solos)), f"{carpeta}/tasks.md tiene IDs repetidos")

    def test_ninguna_tarea_pide_una_persona(self):
        # Una tarea que se cierra mirando o escuchando no la puede cerrar un agente, y en la
        # práctica no la cierra nadie: en el repo del que sale este harness eran 137 casillas
        # marcadas así en 35 specs, y sólo 6 se cerraron alguna vez. O sea que el marcador no
        # significaba «espera a una persona» sino «no se va a hacer, pero queda escrito».
        #
        # La salida son dos y anotarlo no es ninguna: o la verificación se vuelve verificable
        # —un test, una medición, un valor que un gate pueda leer— y entonces es una tarea
        # normal que bloquea como cualquier otra, o no se escribe.
        pide_persona = re.compile(
            r"\[M\]|a ojo|de o[ií]do|escuchar|mirar la pantalla|captura", re.IGNORECASE
        )
        for carpeta in self.viejas:
            texto = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                if CASILLA.match(linea):
                    self.assertNotRegex(linea, pide_persona, f"{carpeta}/tasks.md:{numero}")

    def test_ningun_spec_tiene_una_seccion_que_aplaza(self):
        # `## Seguimiento` era la puerta de atrás: un lugar adentro del spec donde escribir
        # trabajo que no se iba a hacer. Cerrarla por nombre no alcanzaba —la sección vuelve
        # llamándose `## Pendientes` o `## Próximos pasos` y hace exactamente lo mismo—, así
        # que lo que se prohíbe es la operación, no el título.
        #
        # Mira todos los archivos del régimen que le toque y no sólo el que lleva las tareas:
        # un `## Deuda` en el `research.md` aplaza igual, y era donde no miraba nadie.
        for carpeta in self.carpetas:
            for archivo in self._canonicos(carpeta):
                texto = (SPECS / carpeta / archivo).read_text(encoding="utf-8")
                for numero, linea in enumerate(texto.splitlines(), 1):
                    encabezado = ENCABEZADO.match(linea)
                    if encabezado:
                        self.assertNotRegex(
                            encabezado.group(1),
                            SECCION_QUE_APLAZA,
                            f"{carpeta}/{archivo}:{numero} aplaza trabajo en una sección. "
                            "La descarga no es anotarlo: ver .claude/doctrina/sin-deuda.md",
                        )

    def test_ninguna_tarea_aplaza_por_texto(self):
        # Una casilla que dice «por ahora» o «TODO» se cierra marcándola sin haber hecho nada,
        # y encima cuenta como tarea cumplida en el conteo del cierre. El `[M]` de
        # `test_ninguna_tarea_pide_una_persona` era el mismo agujero con otra sintaxis.
        for carpeta in self.viejas:
            texto = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                if CASILLA.match(linea):
                    self.assertNotRegex(linea, TAREA_QUE_APLAZA, f"{carpeta}/tasks.md:{numero}")
                    self.assertNotRegex(linea, MARCADOR_DE_CODIGO, f"{carpeta}/tasks.md:{numero}")

    def test_ningun_research_deja_una_medicion_sin_hacer(self):
        # El `research.md` sale de correr algo: es la regla que hace estimable al spec. Una
        # medición declarada como pendiente es la deuda más cara del flujo, porque el plan
        # entero se apoya en un número que nadie midió y el spec **igual se publica** — o sea
        # que el agujero viaja hasta la implementación disfrazado de decisión tomada.
        #
        # Es la única regla de contenido que cruza los dos regímenes: el `research.md` no se va
        # con el `tasks.md`, y medir en vez de suponer nunca dependió del formato.
        for carpeta in self.carpetas:
            texto = (SPECS / carpeta / "research.md").read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                self.assertNotRegex(
                    linea,
                    MEDICION_APLAZADA,
                    f"{carpeta}/research.md:{numero}: una medición declarada como no hecha. "
                    "O se corre, o el spec no la necesitaba.",
                )

    def test_un_spec_viejo_implementado_no_tiene_casillas_abiertas(self):
        # El ancla anti-deuda del régimen viejo, y la única de esas reglas que mira el registro
        # además del archivo: un spec `Implementado` con una casilla abierta ES la deuda
        # invisible, porque el ítem hereda el estado del spec y el spec dice que ya está.
        #
        # Los terminales (`Descartado`, `Superado`) no se miran: son historia. `Propuesto` es
        # la cola, y una casilla abierta ahí es lo normal.
        #
        # Falla también si el disco quedó atrás del issue, y eso es una feature: `specs/` es
        # caché, así que un `tasks.md` viejo es indistinguible de un spec que mintió. Las dos
        # salidas están en el mensaje.
        for numero, carpeta in self._cerrados_en_disco():
            if es_nuevo(carpeta):
                continue
            tareas = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            abiertas = [linea for linea in tareas.splitlines() if ABIERTA.match(linea)]
            self.assertEqual(
                abiertas,
                [],
                f"el spec {numero} está `{CERRADO}` y su tasks.md tiene "
                f"{len(abiertas)} casilla(s) abierta(s): {abiertas[:3]}. "
                "O falta implementarlas, o falta devolver las marcas al issue con "
                "`publicar_spec.py publicar` y rehidratar.",
            )

    def test_un_spec_nuevo_implementado_tiene_cada_ac_nombrado_por_un_test(self):
        # El ancla anti-deuda del régimen nuevo, y **es más fuerte que la que reemplaza**: una
        # casilla se marca a mano, y quien la marca es el mismo que decide si el trabajo está
        # hecho. Un test que nombra el criterio lo tiene que escribir alguien, corre en cada
        # push, y se rompe solo cuando el código deja de cumplirlo.
        #
        # Lo que verifica es la CITA, no que el test ejerza el criterio: un `AC4` en el nombre
        # o en un comentario alcanza. Es un piso y hay que decirlo — el techo, que el test
        # realmente falle cuando el criterio no se cumple, no lo puede ver ninguna herramienta.
        textos = textos_de_test()
        for numero, carpeta in self._cerrados_en_disco():
            if not es_nuevo(carpeta):
                continue
            acs = acs_de((SPECS / carpeta / "spec.md").read_text(encoding="utf-8"))
            self.assertNotEqual(
                acs, [], f"el spec {numero} está `{CERRADO}` y no declara ningún criterio."
            )
            faltan = acs_sin_test(acs, textos)
            self.assertEqual(
                faltan,
                [],
                f"el spec {numero} está `{CERRADO}` y ningún test nombra {', '.join(faltan)}. "
                "Cada criterio se cita desde el test que lo verifica, en test/ o en "
                ".claude/scripts/tests/.",
            )


class RegimenNuevo(unittest.TestCase):
    """Las sondas del régimen nuevo, sin tocar el disco.

    **Existen porque todavía no hay ningún spec ≥ 030**, así que las reglas de arriba corren
    sobre una lista vacía y pasarían igual si estuvieran rotas. Un gate que estrena una regla
    sin un caso que la vea fallar es una regla que nadie probó.
    """

    def test_acepta_los_tres_archivos(self):  # AC1
        self.assertEqual(
            problemas_de_forma("030-x", {"spec.md", "research.md", "estrategia.md"}), []
        )

    def test_rechaza_si_falta_la_estrategia(self):  # AC1
        self.assertTrue(problemas_de_forma("030-x", {"spec.md", "research.md"}))

    def test_rechaza_un_tasks_de_mas(self):  # AC1
        self.assertTrue(
            problemas_de_forma("030-x", {"spec.md", "research.md", "estrategia.md", "tasks.md"})
        )

    def test_un_spec_viejo_sigue_pidiendo_los_cuatro(self):  # AC2
        self.assertTrue(problemas_de_forma("029-x", {"spec.md", "research.md", "estrategia.md"}))
        self.assertEqual(
            problemas_de_forma("029-x", {"spec.md", "research.md", "plan.md", "tasks.md"}), []
        )

    def test_cada_techo_muerde(self):  # AC1
        largo = " ".join(["hola"] * 600)
        casos = {
            "la prosa": {"spec.md": f"# T\n\n{largo}\n"},
            "el bloque de criterios": {
                "spec.md": f"# T\n\n## Criterios de aceptación\n\n{largo}\n"
            },
            "el research": {"research.md": largo},
            "la estrategia": {"estrategia.md": largo},
        }
        for que, archivos in casos.items():
            problemas = problemas_de_techo("030-x", archivos)
            self.assertTrue(problemas, que)
            self.assertIn(que, problemas[0])

    def test_los_techos_admiten_el_spec_que_los_estrena(self):  # AC1
        # El 029 es el modelo del formato y los cuatro números salieron de medirlo. Un techo
        # que no lo admitiera estaría calibrado contra un documento imaginario, y el primer
        # spec que lo intentara descubriría que la regla no es cumplible.
        carpeta = "029-el-spec-se-achica-a-un-prompt"
        if not (SPECS / carpeta).is_dir():
            self.skipTest(f"{carpeta} no está hidratado")
        leer = lambda nombre: (SPECS / carpeta / nombre).read_text(encoding="utf-8")
        self.assertEqual(
            problemas_de_techo(
                "030-sonda",
                {
                    "spec.md": leer("spec.md"),
                    "research.md": leer("research.md"),
                    # El `plan.md` del 029 está escrito con la forma del `estrategia.md`.
                    "estrategia.md": leer("plan.md"),
                },
            ),
            [],
        )

    def test_el_encabezado_de_los_criterios_cuenta_de_su_lado(self):  # AC1
        prosa, criterios = partir_spec(
            "# T\n\nuno dos\n\n## Criterios de aceptación\n\n- AC1 tres\n"
        )
        self.assertEqual(palabras(prosa), 3)
        self.assertEqual(palabras(criterios), 5)

    def test_los_criterios_salen_de_su_bloque_y_no_de_la_prosa(self):  # AC3
        texto = (
            "# T\n\nel AC9 de otro spec\n\n"
            "## Criterios de aceptación\n\n- **AC2** — x\n- **AC1** — y\n"
        )
        self.assertEqual(acs_de(texto), ["AC2", "AC1"])

    def test_un_ac_sin_test_se_nombra(self):  # AC3
        self.assertEqual(acs_sin_test(["AC1", "AC2"], ["mira el AC1"]), ["AC2"])

    def test_un_ac_no_lo_cubre_un_prefijo(self):  # AC3
        # `AC1` no lo cubre un test que dice `AC12`: sin el `\b`, el criterio 1 quedaría
        # cubierto por cualquier criterio de dos dígitos que empiece con 1.
        self.assertEqual(acs_sin_test(["AC1"], ["verifica el AC12"]), ["AC1"])


if __name__ == "__main__":
    unittest.main()

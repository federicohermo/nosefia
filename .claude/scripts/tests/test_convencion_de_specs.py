"""El gate de la convención de specs, sobre los que estén hidratados en disco.

`specs/[0-9]*/` es caché: en un clone nuevo no hay ninguno y este archivo entero se saltea.
Eso está bien, y por eso **se declara**: un gate que mira cero specs y dice «OK» es
indistinguible de uno que los miró todos, que es la peor respuesta posible.

Para que mire todo lo que hay que mirar alcanza con:

    python .claude/scripts/hidratar_specs.py

**Hay un solo régimen.** Todo spec del que todavía pueda salir trabajo tiene tres archivos
—`spec.md`, `research.md`, `plan.md`—, cuatro techos de palabras y ninguna casilla. El
`tasks.md` no existe: era predicción específica y equivocada, y la medición está en
`specs/README.md`.

**Lo que este gate NO mira son los terminales**, y ésa es la única partición que quedó. Un
spec `Implementado`, `Descartado` o `Superado` es un **ADR**: registro de qué se decidió y
con qué evidencia. No se reescribe, no se hidrata por default, y si alguien lo trae a mano
—`hidratar_specs.py 025`— este gate lo saltea en vez de exigirle un formato que se inventó
después. Juzgar historia con la regla de hoy no arregla nada y da un rojo que no se puede
cerrar.

**La partición sale del `estado` del mapa y no del número ni del disco.** El estado no lo
escribe nadie a mano: lo deriva `.github/workflows/mapa.yml` del PR que aterrizó, y el gate
del mapa prohíbe tocarlo adentro del PR que lo justifica. O sea que esta regla no se evade
escribiendo un archivo — que era el argumento del corte por número que esto reemplaza. Una
carpeta **sin fila en el mapa** se mira igual: es un spec que se está escribiendo y todavía
no se publicó, que es justo cuando conviene mirarlo.

El ancla anti-deuda —cada `ACn` citado por un test como `NNN-ACn`— **no vive acá**: pedía
tener en disco specs ya cerrados. Se mudó al PR, que es donde el spec y sus tests están
juntos: `test_criterios_de_la_rama.py`.
"""

import re
import unittest

from lib.repo import RAIZ
from lib.specs import (
    ENCABEZADOS_DEL_PLAN,
    acs_de,
    rutas_intocables,
    en_vuelo,
    encabezados_del_plan,
    leer_mapa,
    palabras,
    partir_spec,
    sin_encabezados,
)

SPECS = RAIZ / "specs"

#: Los tres archivos de un spec. Son piso **y** techo para el que se fue: un `tasks.md` no es
#: un archivo de más, es el régimen viejo entrando por la ventana — y con él vuelve la
#: predicción de rutas que el formato nuevo existe para sacar.
CANONICOS = ("spec.md", "research.md", "plan.md")
DESTERRADOS = ("tasks.md",)

#: Los cuatro techos de palabras.
#:
#: **Uno cae sobre el bloque de criterios entero y no sobre cada criterio**, y ésa es la
#: decisión que hace que el techo sirva: con un límite por AC, un spec cumple escribiendo
#: veinte AC cortos, que es la misma enfermedad con carpeta nueva. Sobre el bloque, el límite
#: muerde la **cantidad**.
#:
#: Los números salen de medir el `spec.md` del 029, que es el modelo del formato: prosa 350,
#: bloque de criterios 228, `research.md` 444, `plan.md` 233 —medido con `palabras()` el
#: 2026-09-05—. O sea que están calibrados contra un documento que existe y entra, no elegidos
#: de memoria. Que sigan siendo cumplibles ya no necesita un test aparte: hay specs reales en
#: disco y `test_ningun_spec_pasa_un_techo_de_palabras` corre sobre todos ellos, así que bajar
#: un techo a un número que nadie puede cumplir da rojo ahí mismo.
TECHO_DE_PROSA = 350
TECHO_DE_AC = 300
TECHO_DE_RESEARCH = 500
TECHO_DE_PLAN = 250

#: Un encabezado markdown, con su texto.
ENCABEZADO = re.compile(r"^#{1,6}\s+(.*?)\s*$")

#: Las secciones que aplazan trabajo, y por eso no existen acá.
#:
#: **`Fuera de alcance` no está en la lista y es deliberado**: declara una frontera —qué NO
#: hace este spec— y es lo que lo vuelve revisable. Se convierte en deuda sólo cuando algún AC
#: del propio spec depende de lo excluido, y eso ningún gate lo puede ver: lo mira el review.
#: Lo mismo con `Riesgos`, que analiza y no promete.
SECCION_QUE_APLAZA = re.compile(
    r"^(seguimiento|pendientes?|deuda|backlog|to-?do|futuro|a futuro|"
    r"pr[oó]ximos pasos|queda pendiente|para (m[aá]s adelante|despu[eé]s))\b",
    re.IGNORECASE,
)

#: Aplazar por texto adentro de un criterio. Un AC que dice «por ahora» no es un criterio: es
#: una intención, y se da por cumplido sin haber hecho nada.
#:
#: **Son dos y no una porque el repo escribe en español.** Los marcadores de código van SIN
#: `IGNORECASE`: con él, `\bTODO\b` matchea la palabra «todo», y la primera corrida de esta
#: regla se cazó a sí misma contra `todo tipo del enum tiene costo declarado`. Un gate que da
#: rojo sobre un criterio correcto se apaga en una semana, y ahí no queda gate.
MARCADOR_DE_CODIGO = re.compile(r"\bTODO\b|\bFIXME\b|\bXXX\b|\bHACK\b")

TEXTO_QUE_APLAZA = re.compile(
    r"pendiente|m[aá]s adelante|a futuro|en el futuro|queda para|por ahora|provisori|"
    r"si (hay|sobra) tiempo|eventualmente|idealmente",
    re.IGNORECASE,
)

#: Un criterio que se cierra mirando o escuchando no lo cierra nadie. En el repo del que sale
#: este harness eran 137 casillas marcadas `[M]` en 35 specs, y sólo 6 se cerraron alguna vez:
#: el marcador no significaba «espera a una persona» sino «no se va a hacer, pero queda
#: escrito».
#:
#: **La regla se mudó de la casilla al criterio y por eso sigue viva.** Era la única de las
#: cuatro del régimen viejo que no dependía del `tasks.md` para tener sentido: lo que
#: verificaba no era el formato de la casilla, era que la verificación fuera posible. Su
#: sujeto natural es el AC, que es lo que ahora dice cuándo el spec está hecho.
#:
#: Las salidas son dos y anotarlo no es ninguna: o el criterio se vuelve verificable —un test,
#: una medición, un valor que un gate pueda leer— o no se escribe.
#: **`captura` va con «de pantalla» y no suelto**, y es medido: la primera corrida de esta regla
#: dio rojo sobre «un `int` **capturado** por un lambda de GDScript», que es un criterio
#: perfectamente verificable. Un gate que da rojo sobre un criterio correcto se apaga en una
#: semana — el mismo motivo por el que `TODO` va sin `IGNORECASE`.
PIDE_UNA_PERSONA = re.compile(
    r"\[M\]|a ojo|de o[ií]do|escuchar|mirar la pantalla|captura de pantalla", re.IGNORECASE
)

#: Una medición declarada como no hecha. El `research.md` sale de correr algo: una medición
#: aplazada es la deuda más cara del flujo, porque el plan entero se apoya en un número que
#: nadie midió y el spec igual se publica.
MEDICION_APLAZADA = re.compile(
    r"medici[oó]n pendiente|queda por medir|sin medir|no se pudo medir|falta medir|"
    r"pendiente de medir|habr[ií]a que medirlo",
    re.IGNORECASE,
)


def numero_de(carpeta: str) -> str:
    """`030-el-spec-nuevo` → `030`."""
    return carpeta[:3]


def es_adr(carpeta: str, mapa: dict) -> bool:
    """Si esta carpeta es historia y no cola de trabajo.

    Una carpeta que el mapa no conoce **no es un ADR**: es un spec que se está escribiendo y
    todavía no se publicó. La polaridad importa — el default es mirar, y la excepción hay que
    ganársela con una fila que diga que el spec terminó.
    """
    fila = mapa.get(numero_de(carpeta))
    return fila is not None and not en_vuelo(fila.get("estado", ""))


def problemas_de_forma(carpeta: str, presentes: set[str]) -> list[str]:
    """Qué archivos le faltan o le sobran a un spec.

    Puro —recibe el conjunto de nombres, no lee el disco— porque es la única forma de sondear
    un caso que no está en el árbol.
    """
    problemas = [f"{carpeta}: falta {archivo}" for archivo in CANONICOS if archivo not in presentes]
    problemas += [
        f"{carpeta}: {archivo} es del régimen viejo, y el régimen viejo son los specs que ya "
        "aterrizaron"
        for archivo in DESTERRADOS
        if archivo in presentes
    ]
    return problemas


def problemas_de_estructura(carpeta: str, plan: str) -> list[str]:
    """Los encabezados que le faltan al `plan.md`, en el orden en que los declara el formato.

    **Falta, no sobra.** El 003 tiene un `## La forma de una entrada` propio y está bien: los
    tres son el piso, no la lista cerrada. Lo que el formato fija es que estén, porque
    `spec-implement` lee `## Orden obligado` por nombre y hasta hoy nadie lo exigía.
    """
    presentes = encabezados_del_plan(plan)
    return [
        f"{carpeta}/plan.md: falta `{encabezado}`"
        for encabezado in ENCABEZADOS_DEL_PLAN
        if encabezado not in presentes
    ]


def problemas_de_techo(carpeta: str, archivos: dict[str, str]) -> list[str]:
    """Qué techo de palabras pasa un spec.

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
    if "plan.md" in archivos:
        # **Sin las líneas de encabezado**, y es medido: con ellas adentro el margen contra las
        # 250 palabras era **cero** —el 012 tenía exactamente 250—, así que rotular la
        # estructura que este formato ahora exige costaba un rojo. El techo limita el
        # contenido; cobrarle peaje a los rótulos obligatorios lo convertiría en un impuesto a
        # escribir bien.
        medir("plan.md", sin_encabezados(archivos["plan.md"]), TECHO_DE_PLAN, "el plan")
    return problemas


def hidratados() -> list[str]:
    if not SPECS.is_dir():
        return []
    return sorted(e.name for e in SPECS.iterdir() if e.is_dir() and re.match(r"^\d{3}-", e.name))


class Convencion(unittest.TestCase):
    """El gate sobre los specs en vuelo que estén en disco."""

    def setUp(self):
        mapa = leer_mapa((SPECS / "mapa.json").read_text(encoding="utf-8"))
        todas = hidratados()
        self.carpetas = [c for c in todas if not es_adr(c, mapa)]
        if not self.carpetas:
            self.skipTest(
                f"ningún spec en vuelo hidratado en disco ({len(todas)} carpeta(s), todas ADR): "
                "este gate NO miró nada. `python .claude/scripts/hidratar_specs.py` los trae."
            )

    def _criterios(self, carpeta: str) -> list[tuple[int, str]]:
        """Las líneas del bloque de criterios, numeradas dentro del `spec.md`.

        El número es el del archivo y no el del bloque: un rojo que dice `spec.md:41` se abre;
        uno que dice «línea 6 del bloque» hay que contarlo a mano.
        """
        texto = (SPECS / carpeta / "spec.md").read_text(encoding="utf-8")
        _, criterios = partir_spec(texto)
        if not criterios:
            return []
        offset = texto[: texto.index(criterios)].count("\n")
        return [(offset + i, linea) for i, linea in enumerate(criterios.splitlines(), 1)]

    def test_cada_spec_tiene_sus_tres_archivos(self):
        for carpeta in self.carpetas:
            presentes = {f.name for f in (SPECS / carpeta).iterdir() if f.is_file()}
            self.assertEqual(problemas_de_forma(carpeta, presentes), [], carpeta)

    def test_cada_plan_declara_sus_tres_secciones(self):
        # La convención existía —23 de 23 la cumplían el 2026-09-06— y no la exigía nadie,
        # mientras `spec-implement/SKILL.md` lee `## Orden obligado` por nombre. Una sección de
        # la que depende un skill y que se cumple por costumbre dura hasta el primer apuro.
        for carpeta in self.carpetas:
            plan = (SPECS / carpeta / "plan.md")
            if not plan.is_file():
                continue
            self.assertEqual(
                problemas_de_estructura(carpeta, plan.read_text(encoding="utf-8")), [], carpeta
            )

    def test_el_spec_arranca_con_su_encabezado(self):
        # De esa línea sale el título del issue: sin ella, `publicar_spec.py` no tiene qué
        # publicar.
        for carpeta in self.carpetas:
            primera = (SPECS / carpeta / "spec.md").read_text(encoding="utf-8").splitlines()[0]
            self.assertTrue(primera.startswith("# "), f"{carpeta}/spec.md: «{primera[:40]}»")

    def test_ningun_spec_pasa_un_techo_de_palabras(self):
        # El techo es lo que reemplaza al `tasks.md` como límite de tamaño: sin él, el formato
        # nuevo es el viejo con un archivo menos.
        for carpeta in self.carpetas:
            archivos = {
                nombre: (SPECS / carpeta / nombre).read_text(encoding="utf-8")
                for nombre in CANONICOS
                if (SPECS / carpeta / nombre).is_file()
            }
            self.assertEqual(problemas_de_techo(carpeta, archivos), [], carpeta)

    def test_cada_spec_declara_al_menos_un_criterio(self):
        # Un spec sin criterios no es revisable —no dice cuándo está hecho— y encima deja sin
        # sujeto al gate de la rama, que exige un test por criterio: cero criterios es cero
        # exigencias, en verde.
        for carpeta in self.carpetas:
            acs = acs_de((SPECS / carpeta / "spec.md").read_text(encoding="utf-8"))
            self.assertNotEqual(acs, [], f"{carpeta}/spec.md no declara ningún `ACn`")

    def test_ningun_criterio_aplaza_por_texto(self):
        # Un criterio que dice «por ahora» o «TODO» se da por cumplido sin haber hecho nada, y
        # encima cuenta para el conteo del cierre.
        for carpeta in self.carpetas:
            for numero, linea in self._criterios(carpeta):
                self.assertNotRegex(linea, TEXTO_QUE_APLAZA, f"{carpeta}/spec.md:{numero}")
                self.assertNotRegex(linea, MARCADOR_DE_CODIGO, f"{carpeta}/spec.md:{numero}")

    def test_ningun_criterio_pide_una_persona(self):
        for carpeta in self.carpetas:
            for numero, linea in self._criterios(carpeta):
                self.assertNotRegex(
                    linea,
                    PIDE_UNA_PERSONA,
                    f"{carpeta}/spec.md:{numero}: un criterio que se cierra mirando o "
                    "escuchando no lo cierra nadie. O se vuelve verificable, o no se escribe.",
                )

    def test_ningun_spec_tiene_una_seccion_que_aplaza(self):
        # `## Seguimiento` era la puerta de atrás: un lugar adentro del spec donde escribir
        # trabajo que no se iba a hacer. Cerrarla por nombre no alcanzaba —la sección vuelve
        # llamándose `## Pendientes` o `## Próximos pasos` y hace exactamente lo mismo—, así
        # que lo que se prohíbe es la operación, no el título.
        #
        # Mira los tres archivos y no sólo el `spec.md`: un `## Deuda` en el `research.md`
        # aplaza igual, y era donde no miraba nadie.
        # Un archivo ausente no se lee: de ése habla `problemas_de_forma`, y caerse acá con
        # un `FileNotFoundError` taparía el rojo que sí dice qué falta.
        for carpeta in self.carpetas:
            for archivo in CANONICOS:
                if not (SPECS / carpeta / archivo).is_file():
                    continue
                texto = (SPECS / carpeta / archivo).read_text(encoding="utf-8")
                for numero, linea in enumerate(texto.splitlines(), 1):
                    encabezado = ENCABEZADO.match(linea)
                    if encabezado:
                        self.assertNotRegex(
                            encabezado.group(1),
                            SECCION_QUE_APLAZA,
                            f"{carpeta}/{archivo}:{numero} aplaza trabajo en una sección. "
                            "La descarga no es anotarlo: ver "
                            ".claude/skills/spec-create/sin-deuda.md",
                        )

    def test_ningun_research_deja_una_medicion_sin_hacer(self):
        # El `research.md` sale de correr algo: es la regla que hace estimable al spec. Una
        # medición declarada como pendiente es la deuda más cara del flujo, porque el plan
        # entero se apoya en un número que nadie midió y el spec **igual se publica** — o sea
        # que el agujero viaja hasta la implementación disfrazado de decisión tomada.
        for carpeta in self.carpetas:
            if not (SPECS / carpeta / "research.md").is_file():
                continue
            texto = (SPECS / carpeta / "research.md").read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                self.assertNotRegex(
                    linea,
                    MEDICION_APLAZADA,
                    f"{carpeta}/research.md:{numero}: una medición declarada como no hecha. "
                    "O se corre, o el spec no la necesitaba.",
                )


class LaPlantillaPasaSusPropiosGates(unittest.TestCase):
    """`specs/plantilla/` medida con las reglas que un spec copiado va a tener que cumplir.

    **Es el único de estos tests que corre siempre**, porque la plantilla está commiteada y no
    es caché: los de arriba miran lo que haya hidratado, que puede ser nada.

    Existe porque no se midió y salió cara. El 2026-09-06, recién escrita, el `plan.md` de la
    plantilla daba **386 palabras contra un techo de 250** sin una palabra propia, y su
    `### Rutas` declaraba intocables `src/`, `reglas.gd`, `tasks.md` y hasta la regla que el
    párrafo de al lado nombra como ejemplo de lo que NO va en ese rubro. O sea que copiarla
    arrancaba con dos gates en rojo y el segundo acusando al PR de tocar `src/`.

    Una plantilla que no pasa el gate que ella misma enseña a pasar no se descubre leyéndola:
    se descubre cuando alguien la usa, que es el peor momento y la persona equivocada.
    """

    def setUp(self):
        self.plantilla = SPECS / "plantilla"
        if not self.plantilla.is_dir():
            self.fail("falta specs/plantilla/: es lo que `spec-create` manda a copiar")
        self.archivos = {
            nombre: (self.plantilla / nombre).read_text(encoding="utf-8")
            for nombre in CANONICOS
            if (self.plantilla / nombre).is_file()
        }

    def test_tiene_los_tres_archivos_y_ninguno_de_mas(self):
        presentes = {f.name for f in self.plantilla.iterdir() if f.is_file()}
        self.assertEqual(problemas_de_forma("plantilla", presentes), [])

    def test_su_plan_declara_las_tres_secciones(self):
        self.assertEqual(
            problemas_de_estructura("plantilla", self.archivos["plan.md"]), []
        )

    def test_entra_en_los_cuatro_techos_sin_una_palabra_propia(self):
        # El margen es el punto: lo que sobra del techo es lo que le queda a quien escriba el
        # spec. Una plantilla que entra raspando es una plantilla que no se puede completar.
        self.assertEqual(problemas_de_techo("plantilla", self.archivos), [])

    def test_no_prohibe_ninguna_ruta(self):
        # Las rutas que la plantilla nombra son EJEMPLOS del rubro, no restricciones. Si
        # alguna se cuela afuera de un comentario, todo spec copiado hereda la prohibición —y
        # `src/` estaba entre ellas, que es lo que toca cualquier PR de feature de este repo.
        self.assertEqual(rutas_intocables(self.archivos["plan.md"]), [])

    def test_sus_criterios_de_ejemplo_pasan_las_reglas_de_un_criterio(self):
        # La plantilla enseña a escribir un AC con cuatro ejemplos. Si uno de ellos no
        # sobreviviría al gate, lo que enseña está mal.
        texto = self.archivos["spec.md"]
        self.assertNotEqual(acs_de(texto), [])
        _, criterios = partir_spec(texto)
        for numero, linea in enumerate(criterios.splitlines(), 1):
            self.assertNotRegex(linea, TEXTO_QUE_APLAZA, f"plantilla/spec.md:{numero}")
            self.assertNotRegex(linea, MARCADOR_DE_CODIGO, f"plantilla/spec.md:{numero}")
            self.assertNotRegex(linea, PIDE_UNA_PERSONA, f"plantilla/spec.md:{numero}")

    def test_ninguna_seccion_suya_aplaza_trabajo(self):
        for nombre, texto in self.archivos.items():
            for numero, linea in enumerate(texto.splitlines(), 1):
                encabezado = ENCABEZADO.match(linea)
                if encabezado:
                    self.assertNotRegex(
                        encabezado.group(1), SECCION_QUE_APLAZA, f"plantilla/{nombre}:{numero}"
                    )


class Sondas(unittest.TestCase):

    """Las reglas puras, sobre casos escritos acá.

    Existen porque las de arriba corren sobre lo que haya en disco, que puede ser nada: sin
    estas sondas, un gate roto y un árbol vacío se ven igual.
    """

    def test_acepta_los_tres_archivos(self):  # 029-AC1
        self.assertEqual(problemas_de_forma("030-x", {"spec.md", "research.md", "plan.md"}), [])

    def test_rechaza_si_falta_el_plan(self):  # 029-AC1
        self.assertTrue(problemas_de_forma("030-x", {"spec.md", "research.md"}))

    def test_rechaza_un_tasks_de_mas(self):  # 029-AC1
        self.assertTrue(
            problemas_de_forma("030-x", {"spec.md", "research.md", "plan.md", "tasks.md"})
        )

    def test_un_terminal_es_adr_y_uno_sin_fila_no(self):  # 029-AC2
        mapa = {"025": {"estado": "Implementado"}, "027": {"estado": "Propuesto"}}
        self.assertTrue(es_adr("025-lo-que-sea", mapa))
        self.assertFalse(es_adr("027-lo-que-sea", mapa))
        # El que todavía no se publicó se mira: es cuando más barato sale arreglarlo.
        self.assertFalse(es_adr("031-recien-escrito", mapa))

    def test_cada_techo_muerde(self):  # 029-AC1
        largo = " ".join(["hola"] * 600)
        casos = {
            "la prosa": {"spec.md": f"# T\n\n{largo}\n"},
            "el bloque de criterios": {
                "spec.md": f"# T\n\n## Criterios de aceptación\n\n{largo}\n"
            },
            "el research": {"research.md": largo},
            "el plan": {"plan.md": largo},
        }
        for que, archivos in casos.items():
            problemas = problemas_de_techo("030-x", archivos)
            self.assertTrue(problemas, que)
            self.assertIn(que, problemas[0])

    def test_el_plan_sin_una_de_las_tres_secciones_es_rojo(self):
        plan = "# Plan\n\n## Orden obligado\n\nx\n\n## Criterio de terminado\n\ny\n"
        self.assertEqual(
            problemas_de_estructura("031-x", plan), ["031-x/plan.md: falta `## Qué NO se toca`"]
        )

    def test_una_seccion_de_mas_no_es_rojo(self):
        # El 003 tiene un `## La forma de una entrada` propio: los tres son el piso, no la lista.
        plan = (
            "# Plan\n\n## Orden obligado\n\nx\n\n## La forma de una entrada\n\nz\n\n"
            "## Qué NO se toca\n\nw\n\n## Criterio de terminado\n\ny\n"
        )
        self.assertEqual(problemas_de_estructura("031-x", plan), [])

    def test_un_encabezado_adentro_de_un_bloque_no_cuenta_como_seccion(self):
        # Medido en el `plan.md` del 003, que muestra el formato de una entrada con un
        # encabezado de ejemplo adentro de un bloque cercado.
        plan = (
            "# Plan\n\n## Orden obligado\n\n```markdown\n## Qué NO se toca\n```\n\n"
            "## Criterio de terminado\n\ny\n"
        )
        self.assertEqual(
            problemas_de_estructura("031-x", plan), ["031-x/plan.md: falta `## Qué NO se toca`"]
        )

    def test_el_techo_del_plan_no_le_cobra_a_los_encabezados(self):
        # Los rótulos que el formato exige no gastan techo: con ellos adentro el margen del 012
        # era cero, así que estructurar el plan habría sido un rojo.
        cuerpo = " ".join(["hola"] * 248)
        plan = f"# Plan\n\n## Orden obligado\n\n{cuerpo}\n\n## Qué NO se toca\n\n## Criterio de terminado\n"
        self.assertEqual(problemas_de_techo("031-x", {"plan.md": plan}), [])
        self.assertTrue(problemas_de_techo("031-x", {"plan.md": plan + " uno dos tres"}))

    def test_el_encabezado_de_los_criterios_cuenta_de_su_lado(self):  # 029-AC1
        prosa, criterios = partir_spec(
            "# T\n\nuno dos\n\n## Criterios de aceptación\n\n- AC1 tres\n"
        )
        self.assertEqual(palabras(prosa), 3)
        self.assertEqual(palabras(criterios), 5)

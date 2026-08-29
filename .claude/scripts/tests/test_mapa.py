"""El gate del registro: que `specs/mapa.json` diga lo que GitHub dice.

No es un test de una función: es un **gate sobre un dato**, y por eso vive con los otros
tests del harness aunque su sujeto sea `specs/`. La alternativa —una segunda carpeta de tests
con su propia corrida— pide un lanzador que las junte, y un lanzador que un día deja de mirar
una de las dos es el modo de falla que este archivo entero existe para evitar.

## Los dos espejos

Son dos afirmaciones opuestas y las dos tienen que ser falsas:

1. Un spec cuyo PR **aterrizó** y que el mapa sigue llamando `Propuesto` es una mentira.
2. Un spec `Implementado` **sin** PR aterrizado es la mentira al revés.

Juntas **prohíben actualizar el mapa adentro del PR que lo justifica**: mientras el PR está
abierto el mapa tiene que decir `Propuesto`, y en cuanto se mergea tiene que decir otra cosa.
No hay ningún commit del propio PR que deje las dos ciertas — y por eso el estado no lo
escribe nadie: lo deriva `.github/workflows/mapa.yml` en el push a `staging`.

## Por qué se saltea sin red, y por qué eso se declara

Sin `gh` con sesión, la mitad de este archivo no puede correr. Saltearse es correcto;
saltearse **callado** no: un gate que no puede correr y no lo dice se ve igual que uno que
pasó, y así estuvo en verde el gate del repo original mientras el registro se desincronizaba
cinco veces seguidas.
"""

import functools
import json
import subprocess
import unittest

from lib.repo import RAIZ, REPO
from lib.specs import (
    ESTADOS,
    LIMITE_DE_LISTA,
    agrupar_prs_por_spec,
    aterrizo,
    en_vuelo,
    leer_mapa,
)

MAPA_JSON = RAIZ / "specs" / "mapa.json"


@functools.lru_cache(maxsize=1)
def _mapa():
    return leer_mapa(MAPA_JSON.read_text(encoding="utf-8"))


@functools.lru_cache(maxsize=1)
def _github():
    """`(issues, prs)` desde GitHub, o `None` si no se puede preguntar.

    Se pregunta **una sola vez** para toda la corrida: son dos llamadas de red y cada test las
    querría de nuevo.
    """
    try:
        issues = subprocess.run(
            ["gh", "issue", "list", "--repo", REPO, "--state", "all",
             "--limit", str(LIMITE_DE_LISTA), "--json", "number,state,title"],
            capture_output=True, text=True, encoding="utf-8", timeout=60,
        )
        prs = subprocess.run(
            ["gh", "pr", "list", "--repo", REPO, "--state", "all",
             "--limit", str(LIMITE_DE_LISTA), "--json", "number,headRefName,state"],
            capture_output=True, text=True, encoding="utf-8", timeout=60,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if issues.returncode != 0 or prs.returncode != 0:
        return None
    return json.loads(issues.stdout), json.loads(prs.stdout)


class SinRed(unittest.TestCase):
    """Lo que se puede verificar mirando sólo el archivo. Corre siempre."""

    def test_todos_los_estados_son_legales(self):
        for id_spec, entrada in _mapa().items():
            self.assertIn(entrada["estado"], ESTADOS, f"el spec {id_spec}")

    def test_la_carpeta_empieza_con_el_numero_de_su_spec(self):
        # Es lo que hace que `carpeta_existente` pueda emparejar por `NNN`.
        for id_spec, entrada in _mapa().items():
            self.assertTrue(entrada["carpeta"].startswith(f"{id_spec}-"), f"el spec {id_spec}")

    def test_ningun_issue_se_repite(self):
        # Dos specs apuntando al mismo issue es una publicación que se corrió dos veces con el
        # mapa a medias, y hace que hidratar uno pise al otro.
        numeros = [e["issue"] for e in _mapa().values()]
        self.assertEqual(len(numeros), len(set(numeros)))

    def test_ningun_issue_es_cero(self):
        # El `0` es lo que escribe una corrida `--dry` si alguien la deja guardar.
        for id_spec, entrada in _mapa().items():
            self.assertGreater(entrada["issue"], 0, f"el spec {id_spec}")

    def test_las_fechas_son_iso(self):
        for id_spec, entrada in _mapa().items():
            self.assertRegex(entrada["fecha"], r"^\d{4}-\d{2}-\d{2}$", f"el spec {id_spec}")


class ContraGitHub(unittest.TestCase):
    """El cruce contra los issues y los PR. Se saltea sin red, **declarándolo**."""

    def setUp(self):
        if not _mapa():
            self.skipTest("el mapa está vacío: no hay ningún spec publicado todavía")
        datos = _github()
        if datos is None:
            self.skipTest(
                "no se pudo preguntarle a GitHub (sin `gh` o sin sesión): este gate NO corrió"
            )
        self.issues, self.prs = datos
        if len(self.issues) >= LIMITE_DE_LISTA or len(self.prs) >= LIMITE_DE_LISTA:
            self.fail(
                f"la lista de gh llegó al límite de {LIMITE_DE_LISTA} y puede estar cortada: "
                "«este spec no tiene PR» y «su PR no entró en la página» no se distinguen. "
                "Subí `LIMITE_DE_LISTA` en `.claude/scripts/lib/specs.py`."
            )

    def test_cada_spec_apunta_a_un_issue_que_existe(self):
        numeros = {i["number"] for i in self.issues}
        for id_spec, entrada in _mapa().items():
            self.assertIn(entrada["issue"], numeros, f"el spec {id_spec}")

    def test_el_titulo_del_mapa_es_el_del_issue(self):
        por_numero = {i["number"]: i for i in self.issues}
        for id_spec, entrada in _mapa().items():
            issue = por_numero.get(entrada["issue"])
            if issue is None:
                continue  # ya lo grita el test de arriba
            self.assertEqual(entrada["titulo"], issue["title"], f"el spec {id_spec}")

    def test_un_pr_aterrizado_no_deja_el_spec_en_propuesto(self):
        # Primer espejo.
        por_spec = agrupar_prs_por_spec(self.prs)
        for id_spec, entrada in _mapa().items():
            if entrada["estado"] != "Propuesto":
                continue
            self.assertFalse(
                aterrizo(por_spec.get(id_spec)),
                f"el spec {id_spec} dice `Propuesto` y su PR ya está mergeado",
            )

    def test_un_implementado_tiene_su_pr_aterrizado(self):
        # Segundo espejo. Si un PR se mergeó a mano —figura CLOSED—, la salida es agregar su
        # número a `ATERRIZARON_A_MANO`, que es donde esos casos se nombran uno por uno.
        por_spec = agrupar_prs_por_spec(self.prs)
        for id_spec, entrada in _mapa().items():
            if entrada["estado"] != "Implementado":
                continue
            self.assertTrue(
                aterrizo(por_spec.get(id_spec)),
                f"el spec {id_spec} dice `Implementado` y no tiene ningún PR mergeado",
            )

    def test_el_issue_esta_abierto_si_y_solo_si_el_spec_esta_en_vuelo(self):
        por_numero = {i["number"]: i for i in self.issues}
        for id_spec, entrada in _mapa().items():
            issue = por_numero.get(entrada["issue"])
            if issue is None:
                continue
            esperado = "OPEN" if en_vuelo(entrada["estado"]) else "CLOSED"
            self.assertEqual(issue["state"], esperado, f"el spec {id_spec}")

    def test_un_spec_cerrado_no_deja_su_origen_abierto(self):
        # `origen` significa SALDAR, no citar: un spec que aterrizó y dejó abierto el issue que
        # venía a saldar son dos issues por el mismo trabajo, y uno abierto para siempre. Lo
        # que falta en ese caso es un `Closes #N` en el PR — y por eso el rojo no llega en el
        # PR del spec sino en el siguiente, que es de otra persona.
        por_numero = {i["number"]: i for i in self.issues}
        for id_spec, entrada in _mapa().items():
            if en_vuelo(entrada["estado"]):
                continue
            for numero in entrada.get("origen", []):
                issue = por_numero.get(numero)
                if issue is None:
                    continue
                self.assertEqual(
                    issue["state"], "CLOSED",
                    f"el spec {id_spec} ya no está en vuelo y su origen #{numero} sigue abierto",
                )


if __name__ == "__main__":
    unittest.main()

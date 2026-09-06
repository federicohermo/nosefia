"""El CLI de `publicar_spec.py`: qué llamadas a `gh` emite una corrida, y sobre qué specs.

**El observador es `gh` mismo.** El script ya lo recibe inyectado —`--dry` lo reemplaza por una
que imprime—, así que acá se lo reemplaza por una que **anota**. Eso convierte «no toca los
issues de los otros specs» en una aserción sobre una lista, en vez de en una promesa.

El disco sí se toca, pero es un `specs/` de mentira en un directorio temporal: el árbol real de
un worktree tiene una sola carpeta hidratada, y un test que dependa de cuántas haya mide la
hidratación y no el filtro. Lo puro de la selección se ejerce sin disco ni red en
`test_specs.py`.
"""

import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import publicar_spec
from lib.specs import escribir_mapa

#: Las tres carpetas del árbol de mentira, con su número de issue distinto a propósito: es lo
#: que hace que «este `gh` nombró otro spec» se pueda ver en los argumentos de la llamada.
CARPETAS = {"028": "028-uno", "029": "029-dos", "030": "030-tres"}

#: Las subórdenes de `gh issue` que llevan el número del issue en el tercer argumento.
CON_NUMERO = ("edit", "comment", "close", "view")


class GhGrabador:
    """Un `gh` que anota lo que le pidieron y contesta lo mínimo para que la corrida siga."""

    def __init__(self) -> None:
        self.llamadas: list[list[str]] = []

    def __call__(self, args, entrada=None) -> str:
        self.llamadas.append(list(args))
        if args[:2] == ["issue", "view"]:
            return json.dumps({"comments": [], "state": "OPEN"})
        if args[:2] == ["issue", "create"]:
            return "https://github.com/u/r/issues/123"
        return ""

    def issues_tocados(self) -> set[str]:
        return {
            a[2] for a in self.llamadas if a[0] == "issue" and len(a) > 2 and a[1] in CON_NUMERO
        }

    def cierres(self) -> list[str]:
        return [a[2] for a in self.llamadas if a[:2] == ["issue", "close"]]


def fila(id_spec: str, estado: str) -> dict:
    return {
        "issue": int(id_spec),
        "carpeta": CARPETAS[id_spec],
        "fecha": "2026-09-06",
        "estado": estado,
        "titulo": f"Spec {id_spec} — de mentira",
    }


class CorridaDeCli(unittest.TestCase):
    """La base: un `specs/` temporal, un mapa a medida y `gh` grabado."""

    #: El 028 está `Implementado`, o sea que es el que la lógica de cierre cerraría. Los otros
    #: dos quedan `Propuesto`, que es el estado que no cierra.
    ESTADOS = {"028": "Implementado", "029": "Propuesto", "030": "Propuesto"}

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.raiz = Path(self.tmp.name)
        for id_spec, carpeta in CARPETAS.items():
            destino = self.raiz / carpeta
            destino.mkdir()
            (destino / "spec.md").write_text(
                f"# Spec {id_spec} — de mentira\n\n## Criterios de aceptación\n\n- **AC1** — x\n",
                encoding="utf-8",
            )
            (destino / "research.md").write_text(f"# Research — {id_spec}\n", encoding="utf-8")
            (destino / "plan.md").write_text(f"# Plan — {id_spec}\n", encoding="utf-8")
        self.addCleanup(self.tmp.cleanup)

    def escribir_mapa_con(self, ids: list[str]) -> Path:
        mapa = {i: fila(i, self.ESTADOS[i]) for i in ids}
        ruta = self.raiz / "mapa.json"
        ruta.write_text(escribir_mapa(mapa), encoding="utf-8")
        return ruta

    def correr(self, argv: list[str], en_el_mapa: list[str] | None = None) -> GhGrabador:
        """Una corrida entera de `main()` con el árbol de mentira montado."""
        ruta_mapa = self.escribir_mapa_con(en_el_mapa or list(CARPETAS))
        grabador = GhGrabador()
        with (
            mock.patch.object(publicar_spec, "SPECS", self.raiz),
            mock.patch.object(publicar_spec, "MAPA_JSON", ruta_mapa),
            mock.patch.object(publicar_spec, "lanzar_gh", grabador),
            mock.patch.object(sys, "argv", ["publicar_spec.py", *argv]),
            mock.patch("sys.stdout", new=io.StringIO()),
        ):
            publicar_spec.main()
        return grabador


class PublicarAcotado(CorridaDeCli):
    def test_un_nnn_deja_los_demas_issues_en_paz(self):  # 030-AC1
        grabador = self.correr(["publicar", "029"])
        self.assertEqual(grabador.issues_tocados(), {"29"})

    def test_varios_nnn_operan_sobre_esos_y_ninguno_mas(self):  # 030-AC3
        grabador = self.correr(["publicar", "029", "030"])
        self.assertEqual(grabador.issues_tocados(), {"29", "30"})

    def test_sin_nnn_recorre_todas_las_carpetas(self):  # 030-AC2
        grabador = self.correr(["publicar"])
        self.assertEqual(grabador.issues_tocados(), {"28", "29", "30"})


class CrearAcotado(CorridaDeCli):
    def test_un_nnn_crea_solo_ese_issue(self):  # 030-AC1
        # El mapa arranca con el 028 nomás, así que sin el filtro `crear` abriría los issues
        # del 029 y del 030 de una: dos issues que nadie pidió, y ya no se deshacen.
        grabador = self.correr(["crear", "030"], en_el_mapa=["028"])
        creados = [a for a in grabador.llamadas if a[:2] == ["issue", "create"]]
        self.assertEqual(len(creados), 1)
        self.assertIn("Spec `030-tres`", " ".join(creados[0]))

    def test_sin_nnn_crea_los_que_falten(self):  # 030-AC2
        grabador = self.correr(["crear"], en_el_mapa=["028"])
        creados = [a for a in grabador.llamadas if a[:2] == ["issue", "create"]]
        self.assertEqual(len(creados), 2)


class ElCierreNoSaleDeLaLista(CorridaDeCli):
    """El AC5 es la mitad cara del spec: hoy el daño es cero por coincidencia, no por diseño."""

    def test_sin_filtro_el_terminado_se_cierra(self):  # 030-AC5
        # El control, y sin él el test de abajo pasaría con un script que no cierra NUNCA.
        self.assertEqual(self.correr(["publicar"]).cierres(), ["28"])

    def test_con_nnn_acotado_no_se_cierra_un_spec_de_afuera(self):  # 030-AC5
        self.assertEqual(self.correr(["publicar", "030"]).cierres(), [])


class UnNnnSinCarpeta(CorridaDeCli):
    def test_corta_antes_de_la_primera_llamada_a_gh(self):  # 030-AC4
        # Con un `NNN` válido al lado, y a propósito: media corrida deja el mapa y los issues
        # discrepando, y nada la nombra después.
        grabador = GhGrabador()
        ruta_mapa = self.escribir_mapa_con(list(CARPETAS))
        with (
            mock.patch.object(publicar_spec, "SPECS", self.raiz),
            mock.patch.object(publicar_spec, "MAPA_JSON", ruta_mapa),
            mock.patch.object(publicar_spec, "lanzar_gh", grabador),
            mock.patch.object(sys, "argv", ["publicar_spec.py", "publicar", "029", "031"]),
        ):
            with self.assertRaises(SystemExit) as caso:
                publicar_spec.main()

        self.assertNotEqual(caso.exception.code, 0)
        self.assertIn("031", str(caso.exception))
        self.assertEqual(grabador.llamadas, [])


class LaSuperficieDelUso(unittest.TestCase):
    def test_el_uso_nombra_el_nnn(self):  # 030-AC4
        # Hasta el 030 la fase salía de `sys.argv[1]` y todo lo demás se ignoraba en silencio:
        # `publicar 029` corría sobre los 29. El `uso:` es lo único que le dice a quien lo lea
        # que ahora el número se acepta.
        self.assertIn("NNN", publicar_spec.USO)

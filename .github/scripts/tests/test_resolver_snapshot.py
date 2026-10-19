import importlib.util
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError


RUTA = Path(__file__).resolve().parents[1] / "resolver_snapshot.py"
SPEC = importlib.util.spec_from_file_location("resolver_snapshot", RUTA)
resolver = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = resolver
SPEC.loader.exec_module(resolver)


class SnapshotTests(unittest.TestCase):
    def fuente(self, previo=False):
        return resolver.FuenteSnapshot(123, "importaciones", previo, "sha-objetivo", "rama")

    def corrida(self):
        return {
            "id": 123, "path": ".github/workflows/medir-verificacion.yml",
            "event": "workflow_dispatch", "head_sha": "sha-objetivo", "head_branch": "rama",
            "status": "completed", "conclusion": "success", "run_attempt": 2,
        }

    def artefacto(self):
        return {
            "id": 456, "name": "snapshot-importaciones-2", "expired": False,
            "size_in_bytes": 1024, "created_at": "2026-10-18T20:00:00Z", "digest": "sha256:abc",
        }

    def test_origen_previo_exige_misma_corrida_workflow_evento_rama_commit_y_exito(self):
        for campo, valor in (
            ("id", 234), ("path", "otro.yml"), ("event", "pull_request"),
            ("head_sha", "otro"), ("head_branch", "otra"),
            ("status", "in_progress"), ("conclusion", "failure"),
        ):
            with self.subTest(campo=campo), self.assertRaises(ValueError):
                resolver.validar_corrida(self.corrida() | {campo: valor}, self.fuente(True))

    def test_origen_actual_rechaza_otro_intento_y_corrida_fallida(self):
        with patch.dict("os.environ", {"GITHUB_RUN_ATTEMPT": "1"}):
            with self.assertRaisesRegex(ValueError, "intento"):
                resolver.validar_corrida(self.corrida(), self.fuente())
        with patch.dict("os.environ", {"GITHUB_RUN_ATTEMPT": "2"}):
            with self.assertRaisesRegex(ValueError, "sin éxito"):
                resolver.validar_corrida(self.corrida() | {"conclusion": "failure"}, self.fuente())

    def test_reutilizacion_conserva_id_inmutable_y_procedencia(self):
        with patch.object(resolver, "api", return_value=self.corrida()), patch.object(
            resolver, "listar", return_value=[self.artefacto()]
        ):
            datos = resolver.resolver(self.fuente(True))
        self.assertEqual(datos["artefacto_id"], 456)
        self.assertEqual(datos["run_id"], 123)
        self.assertEqual(datos["run_attempt"], 2)
        self.assertEqual(datos["digest"], "sha256:abc")
        self.assertTrue(datos["previo"])

    def test_reutilizacion_rechaza_ausente_otro_tipo_otro_intento_expirado_vacio_duplicado(self):
        artefacto = self.artefacto()
        for artefactos in (
            [], [artefacto | {"name": "snapshot-completo-2"}],
            [artefacto | {"name": "snapshot-importaciones-1"}],
            [artefacto | {"expired": True}], [artefacto | {"size_in_bytes": 0}],
            [artefacto, artefacto | {"id": 789}],
        ):
            with self.subTest(artefactos=artefactos), patch.object(
                resolver, "api", return_value=self.corrida()
            ), patch.object(resolver, "listar", return_value=artefactos):
                with self.assertRaises(ValueError):
                    resolver.resolver(self.fuente(True))

    def test_productor_puede_publicar_antes_de_que_termine_el_workflow(self):
        corrida = self.corrida() | {"status": "in_progress", "conclusion": None}
        with patch.dict("os.environ", {"GITHUB_RUN_ATTEMPT": "2"}), patch.object(
            resolver, "api", return_value=corrida
        ), patch.object(resolver, "listar", side_effect=[[], [], [self.artefacto()]]), patch.object(
            resolver.time, "sleep"
        ) as dormir:
            datos = resolver.resolver(self.fuente())
        self.assertEqual(datos["artefacto_id"], 456)
        dormir.assert_called_once()

    def test_productor_terminado_sin_snapshot_falla_sin_esperar(self):
        for conclusion in ("failure", "cancelled", "skipped", "success"):
            with self.subTest(conclusion=conclusion), patch.dict(
                "os.environ", {"GITHUB_RUN_ATTEMPT": "2"}
            ), patch.object(resolver, "api", return_value=self.corrida() | {
                "status": "in_progress", "conclusion": None,
            }), patch.object(resolver, "listar", side_effect=[[], [{
                "name": "Preparación compartida", "status": "completed", "conclusion": conclusion,
            }]]), patch.object(resolver.time, "sleep") as dormir:
                with self.assertRaisesRegex(ValueError, "productor terminó"):
                    resolver.resolver(self.fuente())
                dormir.assert_not_called()

    def test_deadline_agotado_no_pasa_como_ausencia_de_trabajo(self):
        with patch.dict("os.environ", {"GITHUB_RUN_ATTEMPT": "2"}), patch.object(
            resolver, "api", return_value=self.corrida()
        ), patch.object(resolver, "listar", return_value=[]), patch.object(
            resolver.time, "monotonic", side_effect=[0, 601]
        ):
            with self.assertRaises(TimeoutError):
                resolver.resolver(self.fuente())

    def test_listado_pagina_hasta_encontrar_el_artefacto(self):
        with patch.object(resolver, "api", side_effect=[
            {"artifacts": [{"id": i} for i in range(100)]},
            {"artifacts": [self.artefacto()]},
        ]) as api:
            datos = resolver.listar("actions/runs/123/artifacts", "artifacts")
        self.assertEqual(len(datos), 101)
        self.assertEqual(datos[-1]["id"], 456)
        self.assertIn("page=2", api.call_args.args[0])

    def test_consulta_condicional_autorizada_reutiliza_304_sin_ocultar_403(self):
        respuesta = MagicMock()
        respuesta.__enter__.return_value = respuesta
        respuesta.read.return_value = b'{"artifacts": []}'
        respuesta.headers = {"ETag": '"version-1"', "X-RateLimit-Remaining": "900"}
        entorno = {
            "GITHUB_API_URL": "https://api.github.com", "GITHUB_REPOSITORY": "owner/repo",
            "GH_TOKEN": "token-de-prueba",
        }
        with patch.dict("os.environ", entorno), patch.dict(
            resolver._RESPUESTAS, {}, clear=True
        ), patch.object(resolver.urllib.request, "urlopen", side_effect=[
            respuesta, HTTPError("url", 304, "Not Modified", {}, io.BytesIO()),
            HTTPError("url", 403, "Forbidden", {}, io.BytesIO()),
        ]) as abrir:
            self.assertEqual(resolver.api("artifacts"), {"artifacts": []})
            self.assertEqual(resolver.api("artifacts"), {"artifacts": []})
            solicitud = abrir.call_args.args[0]
            self.assertEqual(solicitud.get_header("If-none-match"), '"version-1"')
            self.assertEqual(solicitud.get_header("Authorization"), "Bearer token-de-prueba")
            with self.assertRaises(HTTPError):
                resolver.api("artifacts")


if __name__ == "__main__":
    unittest.main()

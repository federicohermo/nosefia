"""El despliegue: el par preset↔headers, el veredicto del export y el de la URL publicada.

**Este archivo es el gate del par**, y por eso corre sobre los archivos de verdad y no sólo
sobre ejemplos: la falla que persigue es que alguien apague `variant/thread_support` sin sacar
los dos headers de `vercel.json` —o al revés—, que es un cambio de una línea en un archivo que
no se lee junto al otro. Un gate que sólo mirara ejemplos fabricados seguiría en verde el día
que las dos mitades se separen.

Las sondas de abajo son la otra mitad: ahí se ejerce la lógica con entradas que en disco no se
pueden fabricar —un 404, un `.wasm` truncado, un header que se cayó del CDN—, que es por lo que
`lib/despliegue.py` recibe la función que hace el pedido en vez de hacerlo.

## Lo que este archivo NO puede correr, y qué haría falta

Tres criterios de este spec sólo se cierran **contra una URL viva**, y la cita de cada uno lo
declara en su lugar: el AC7 corrido de verdad, el AC8 entero, y la mitad de vivo del AC9. Lo
que hace falta para correrlos es un proyecto de Vercel y sus tres secretos; el comando exacto
está escrito en el comentario de cada uno y en `docs/infra/despliegue.md`.
"""

import json
import re
import unittest

from lib.despliegue import (
    AISLAMIENTO,
    CACHE,
    HILOS,
    OBLIGATORIOS,
    PISO_DEL_WASM,
    PUBLICADOS,
    REVALIDACION,
    TECHO_DEL_DIRECTORIO,
    TIPO_DEL_WASM,
    Respuesta,
    desajustes_del_par,
    headers_universales,
    pide_hilos,
    preset_web,
    problemas_de_la_publicacion,
    veredicto_del_export,
)
from lib.repo import RAIZ

PRESETS = RAIZ / "export_presets.cfg"
VERCEL = RAIZ / "vercel.json"
VERSION_DEL_MOTOR = RAIZ / ".godot-version"
WORKFLOWS = RAIZ / ".github" / "workflows"
VERIFY = WORKFLOWS / "verify.yml"
DESPLEGAR = WORKFLOWS / "desplegar.yml"
HUMO = RAIZ / ".github" / "scripts" / "humo_en_navegador.mjs"
DOC = RAIZ / "docs" / "infra" / "despliegue.md"


def _texto(ruta) -> str:
    return ruta.read_text(encoding="utf-8")


def sano(hilos: bool = True) -> tuple[str, dict]:
    """Un par atado, para que cada sonda desate exactamente una cosa y nada más."""
    cfg = (
        "[preset.0]\n\n"
        'name="Web"\nplatform="Web"\nexport_path="export/web/index.html"\n\n'
        f"[preset.0.options]\n\n{HILOS}={'true' if hilos else 'false'}\n"
    )
    headers = [{"key": k, "value": v} for k, v in AISLAMIENTO.items()] if hilos else []
    headers.append({"key": CACHE, "value": f"public, max-age=0, {REVALIDACION}"})
    return cfg, {"headers": [{"source": "/(.*)", "headers": headers}]}


class ElParEnDisco(unittest.TestCase):
    """Los archivos de verdad. Es lo que se pone rojo al desatar el par."""

    def setUp(self):
        self.assertTrue(PRESETS.is_file(), f"falta `{PRESETS.name}`: no hay preset que exportar.")
        self.assertTrue(VERCEL.is_file(), f"falta `{VERCEL.name}`: no hay headers que mandar.")
        self.cfg = _texto(PRESETS)
        self.vercel = json.loads(_texto(VERCEL))

    def test_hay_un_preset_web_con_destino_y_con_hilos(self):  # 027-AC1
        preset = preset_web(self.cfg)
        self.assertIsNotNone(preset, "`export_presets.cfg` no declara un preset de plataforma Web.")
        self.assertEqual(preset.get("export_path"), "export/web/index.html")
        self.assertTrue(pide_hilos(self.cfg), f"el preset Web no declara `{HILOS}=true`.")

    def test_vercel_apaga_el_deploy_automatico_de_git(self):
        # `docs/infra/despliegue.md` dedica una sección entera a por qué exporta Actions y no
        # Vercel, y nada lo hacía cumplir: el proyecto está vinculado al repo, así que la
        # integración de Git construía la raíz en cada push —sin Godot, sin export— y publicaba.
        # Medido el 2026-09-07 contra el proyecto de este repo: la producción contestaba **404**.
        # Y con `desplegar.yml` en `main` serían dos caminos publicando sobre el mismo proyecto,
        # con el alias de producción para el que termine último.
        self.assertIs(
            self.vercel.get("git", {}).get("deploymentEnabled"),
            False,
            "`vercel.json` no apaga el deploy automático de Git: la integración va a publicar la "
            "raíz del repo, que no tiene el juego exportado.",
        )

    def test_vercel_manda_los_dos_headers_para_todas_las_rutas(self):  # 027-AC1
        declarados = headers_universales(self.vercel)
        for header, valor in AISLAMIENTO.items():
            self.assertEqual(declarados.get(header), valor, f"falta `{header}: {valor}`.")

    def test_el_par_esta_atado(self):  # 027-AC2  # 027-AC3
        # ÉSTE es el gate. Apagar `thread_support` sin sacar los headers, o sacar un header con
        # los hilos encendidos, o borrar el `must-revalidate`: las tres lo ponen rojo, y volver
        # el archivo atrás lo pone verde. Verificado en las dos direcciones el 2026-09-06.
        self.assertEqual(desajustes_del_par(self.cfg, self.vercel), [])


class ElParDesatado(unittest.TestCase):
    """Que el gate de arriba **pueda** ponerse rojo. Un gate que nunca falla no es un gate."""

    def test_hilos_sin_headers_es_rojo(self):  # 027-AC2
        cfg, _ = sano(hilos=True)
        _, vercel = sano(hilos=False)
        problemas = desajustes_del_par(cfg, vercel)
        self.assertTrue(any("pide hilos" in p for p in problemas), problemas)

    def test_headers_sin_hilos_tambien_es_rojo(self):  # 027-AC2
        # La otra dirección. No rompe el juego, pero deja el par desatado igual y escrito al
        # revés: el próximo que lea el `vercel.json` va a creer que la web usa hilos.
        cfg, _ = sano(hilos=False)
        _, vercel = sano(hilos=True)
        problemas = desajustes_del_par(cfg, vercel)
        self.assertTrue(any("no pide hilos" in p for p in problemas), problemas)

    def test_falta_uno_solo_de_los_dos_headers_y_ya_es_rojo(self):  # 027-AC2
        cfg, vercel = sano()
        vercel["headers"][0]["headers"] = [
            h for h in vercel["headers"][0]["headers"] if h["key"] != "cross-origin-opener-policy"
        ]
        self.assertTrue(any("opener" in p for p in desajustes_del_par(cfg, vercel)))

    def test_un_header_declarado_para_una_ruta_sola_no_cuenta(self):  # 027-AC2
        # El `.wasm` y el `.pck` los pide el mismo `index.js`: un aislamiento que sólo cubre el
        # HTML deja la página cargando, que es la falla que este spec existe para no tener.
        cfg, vercel = sano()
        vercel["headers"][0]["source"] = "/index.html"
        self.assertNotEqual(desajustes_del_par(cfg, vercel), [])

    def test_sin_must_revalidate_es_rojo(self):  # 027-AC3
        cfg, vercel = sano()
        for header in vercel["headers"][0]["headers"]:
            if header["key"] == CACHE:
                header["value"] = "public, max-age=31536000, immutable"
        self.assertTrue(any(REVALIDACION in p for p in desajustes_del_par(cfg, vercel)))

    def test_sin_cache_control_tambien_es_rojo(self):  # 027-AC3
        cfg, vercel = sano()
        vercel["headers"][0]["headers"] = [
            h for h in vercel["headers"][0]["headers"] if h["key"] != CACHE
        ]
        self.assertTrue(any(REVALIDACION in p for p in desajustes_del_par(cfg, vercel)))

    def test_un_preset_sin_destino_se_nombra(self):  # 027-AC1
        cfg, vercel = sano()
        cfg = cfg.replace('export_path="export/web/index.html"\n', "")
        self.assertTrue(any("export_path" in p for p in desajustes_del_par(cfg, vercel)))

    def test_sin_preset_web_no_hay_nada_que_exportar(self):  # 027-AC1
        _, vercel = sano()
        self.assertNotEqual(desajustes_del_par('[preset.0]\nplatform="Windows Desktop"\n', vercel), [])


class ElVeredictoDelExport(unittest.TestCase):
    """El AC4: el código de salida del export no decide nada.

    Está medido que `--export-release "Web"` devuelve **0** después de un
    `Program crashed with signal 11`, así que un paso de CI que mire el `$?` sale verde con un
    directorio a medio escribir.
    """

    def completo(self) -> dict[str, int]:
        return {"index.html": 5_000, "index.js": 200_000, "index.wasm": 45 * 1024 * 1024,
                "index.pck": 3 * 1024 * 1024}

    def test_un_export_completo_no_tiene_nada_que_decir(self):  # 027-AC4
        self.assertEqual(veredicto_del_export(self.completo()), [])

    def test_cada_obligatorio_que_falta_se_nombra(self):  # 027-AC4
        for obligatorio in OBLIGATORIOS:
            archivos = {k: v for k, v in self.completo().items() if k != obligatorio}
            problemas = veredicto_del_export(archivos)
            self.assertTrue(any(obligatorio in p for p in problemas), obligatorio)

    def test_un_wasm_truncado_no_pasa_el_piso(self):  # 027-AC4
        # El caso exacto del crash: Godot murió a mitad de escribir el `.wasm` y devolvió 0.
        archivos = self.completo() | {"index.wasm": PISO_DEL_WASM - 1}
        self.assertTrue(any("index.wasm" in p for p in veredicto_del_export(archivos)))

    def test_un_directorio_que_pasa_el_techo_se_nombra(self):  # 027-AC4
        archivos = self.completo() | {"index.pck": TECHO_DEL_DIRECTORIO}
        self.assertTrue(any("techo" in p for p in veredicto_del_export(archivos)))

    def test_el_veredicto_no_mira_el_codigo_de_salida(self):  # 027-AC4
        # La firma es la prueba: `veredicto_del_export` no recibe un `$?` que mirar. Si algún
        # día lo recibiera, este test dejaría de compilar antes de dejar de afirmar.
        self.assertEqual(veredicto_del_export({}) != [], True)


class LaPublicacion(unittest.TestCase):
    """El AC7, con la respuesta inyectada: un 404 y un header caído sin publicar nada."""

    def sana(self) -> dict[str, str]:
        headers = {k: v for k, v in AISLAMIENTO.items()}
        headers[CACHE] = f"public, max-age=0, {REVALIDACION}"
        return headers

    def servidor(self, **rotos):
        """Un servidor que contesta bien salvo lo que se le rompa a propósito."""

        def pedir(url: str) -> Respuesta:
            nombre = url.rsplit("/", 1)[-1]
            if nombre in rotos:
                return rotos[nombre]
            headers = self.sana()
            if nombre.endswith(".wasm"):
                headers["Content-Type"] = TIPO_DEL_WASM
            return Respuesta(200, headers)

        return pedir

    def test_una_url_sana_no_tiene_problemas(self):  # 027-AC7
        self.assertEqual(problemas_de_la_publicacion("https://x.test/", self.servidor()), [])

    def test_un_redirect_se_nombra_como_redirect_y_no_como_headers_que_faltan(self):
        # Medido en vivo el 2026-09-07 contra el proyecto de Vercel de este repo, con la
        # Deployment Protection encendida: los cuatro archivos contestaban 302 al SSO y el
        # veredicto salieron nueve mensajes sobre headers que faltaban. El deploy no había
        # perdido ningún header: nunca se llegó a mirarlo. Un diagnóstico que nombra la causa
        # equivocada cuesta la corrida entera de quien lo lee.
        aviso = Respuesta(302, {"Location": "https://vercel.com/sso-api?url=x"})
        problemas = problemas_de_la_publicacion(
            "https://x.test", self.servidor(**{nombre: aviso for nombre in PUBLICADOS})
        )
        self.assertEqual(len(problemas), len(PUBLICADOS))
        for problema in problemas:
            self.assertIn("302", problema)
            self.assertIn("https://vercel.com/sso-api?url=x", problema)
            self.assertNotIn("SharedArrayBuffer", problema)

    def test_un_404_es_un_problema(self):  # 027-AC7
        problemas = problemas_de_la_publicacion(
            "https://x.test", self.servidor(**{"index.pck": Respuesta(404)})
        )
        self.assertTrue(any("index.pck" in p and "404" in p for p in problemas))

    def test_un_header_de_aislamiento_que_falta_es_un_problema(self):  # 027-AC7
        sin_coep = self.sana()
        del sin_coep["cross-origin-embedder-policy"]
        problemas = problemas_de_la_publicacion(
            "https://x.test", self.servidor(**{"index.js": Respuesta(200, sin_coep)})
        )
        self.assertTrue(any("embedder" in p for p in problemas))

    def test_un_wasm_sin_su_tipo_es_un_problema(self):  # 027-AC7
        problemas = problemas_de_la_publicacion(
            "https://x.test",
            self.servidor(
                **{"index.wasm": Respuesta(200, self.sana() | {"Content-Type": "text/plain"})}
            ),
        )
        self.assertTrue(any(TIPO_DEL_WASM in p for p in problemas))

    def test_los_headers_se_leen_sin_importar_la_capitalizacion(self):  # 027-AC7
        # Un CDN puede devolver `cache-control` en minúscula y Vercel lo escribe capitalizado.
        # Comparar el string tal cual diría que falta el header que está.
        gritado = {k.upper(): v for k, v in self.sana().items()}
        gritado["CONTENT-TYPE"] = TIPO_DEL_WASM
        self.assertEqual(
            problemas_de_la_publicacion("https://x.test", lambda _u: Respuesta(200, gritado)), []
        )

    def test_se_le_pide_al_wasm_y_al_pck_y_no_solo_al_html(self):  # 027-AC7
        # Que el HTML conteste 200 es lo que ya se ve a ojo. Lo que no se ve es el `.pck`.
        pedidos: list[str] = []

        def registrando(url: str) -> Respuesta:
            pedidos.append(url.rsplit("/", 1)[-1])
            return Respuesta(200, self.sana() | {"Content-Type": TIPO_DEL_WASM})

        problemas_de_la_publicacion("https://x.test", registrando)
        self.assertEqual(set(pedidos), {"index.html", "index.js", "index.wasm", "index.pck"})


class LaVersionDelMotor(unittest.TestCase):
    """El AC5: escrita dos veces, la CI y el despliegue exportan con motores distintos.

    Y eso **no da rojo en ningún lado**: las dos corridas salen verdes, cada una con su motor.
    """

    def test_hay_un_godot_version_en_la_raiz(self):  # 027-AC5
        self.assertTrue(VERSION_DEL_MOTOR.is_file(), "falta `.godot-version` en la raíz.")
        self.assertRegex(_texto(VERSION_DEL_MOTOR).strip(), r"^\d+\.\d+(\.\d+)?-[a-z0-9]+$")

    def test_ningun_workflow_escribe_la_version_a_mano(self):  # 027-AC5
        for workflow in (VERIFY, DESPLEGAR):
            self.assertTrue(workflow.is_file(), f"falta `{workflow.name}`.")
            texto = _texto(workflow)
            # `assertNotRegex` volcaría el workflow entero al fallar y el mensaje quedaría
            # sepultado; lo que hay que leer son cuatro palabras y el nombre del archivo.
            escrita = re.search(r"GODOT_VERSION:\s*\d\S*", texto)
            self.assertIsNone(
                escrita,
                f"`{workflow.name}` escribe la versión a mano "
                f"(`{escrita.group(0) if escrita else ''}`) en vez de leerla de "
                "`.godot-version`: dos copias que se separan exportan con motores distintos.",
            )
            self.assertIn(".godot-version", texto, f"`{workflow.name}` no la lee de ahí.")


class ElWorkflowDeDespliegue(unittest.TestCase):
    """El AC6 y el AC8, hasta donde se pueden leer sin desplegar."""

    def setUp(self):
        self.assertTrue(DESPLEGAR.is_file(), "falta `.github/workflows/desplegar.yml`.")
        self.texto = _texto(DESPLEGAR)

    def test_dispara_solo_en_main_y_a_mano(self):  # 027-AC6
        # Se mira el bloque `on:` y no el archivo entero: `staging` se nombra en el encabezado
        # para explicar por qué NO dispara ahí, y un `assertNotIn` sobre todo el texto
        # castigaría justamente al comentario que explica la regla.
        disparadores = self.texto.split("on:", 1)[1].split("\npermissions:", 1)[0]
        self.assertIn("workflow_dispatch", disparadores)
        self.assertIn("branches: [main]", disparadores)
        # `staging` recibe cada PR de spec: desplegar desde ahí publicaría trabajo a medio
        # integrar sobre la URL que mira la cátedra.
        self.assertNotIn("staging", disparadores)

    def test_un_secreto_que_falta_lo_hace_fallar_declarandolo(self):  # 027-AC6
        # Sin esto, el paso del deploy fallaría con un error de la CLI de Vercel que no nombra
        # al secreto — o, peor, no desplegaría y saldría verde.
        for secreto in ("VERCEL_TOKEN", "VERCEL_ORG_ID", "VERCEL_PROJECT_ID"):
            self.assertIn(secreto, self.texto, f"el workflow no nombra `{secreto}`.")
        self.assertIn("faltan", self.texto)

    def test_las_templates_se_cachean_por_version(self):  # 027-AC6
        self.assertIn("actions/cache", self.texto)
        self.assertIn("export_templates", self.texto)

    def test_el_veredicto_del_export_no_es_el_codigo_de_salida(self):  # 027-AC4
        self.assertIn("verificar_export.py", self.texto)
        self.assertIn("|| true", self.texto)

    def test_le_pega_a_la_url_publicada(self):  # 027-AC7
        # La cita del AC7 corrido de verdad. Contra una URL viva se corre con
        #   python .claude/scripts/verificar_despliegue.py https://<proyecto>.vercel.app
        # y ACÁ NO SE PUEDE: hace falta el proyecto de Vercel y sus tres secretos. Lo que este
        # test verifica es que el workflow lo llame; que la URL conteste bien lo verifica él.
        self.assertIn("verificar_despliegue.py", self.texto)

    def test_abre_la_url_en_un_navegador_de_verdad(self):  # 027-AC8
        # El AC8 entero es lo que NO se puede correr sin desplegar: pide un Chromium y una URL
        # viva. Se corre con
        #   npx playwright install --with-deps chromium
        #   node .github/scripts/humo_en_navegador.mjs https://<proyecto>.vercel.app
        # y hacen falta los tres secretos de Vercel para que exista esa URL. Lo verificable en
        # frío es que el workflow lo llame y que el script exista.
        self.assertIn("humo_en_navegador.mjs", self.texto)
        self.assertTrue(HUMO.is_file(), "falta el script de humo del navegador.")
        humo = _texto(HUMO)
        self.assertIn("crossOriginIsolated", humo)
        self.assertIn("process.exit(1)", humo)


class LaDocumentacion(unittest.TestCase):
    """El AC9 y el AC10."""

    def test_hay_un_documento_de_despliegue(self):  # 027-AC9
        self.assertTrue(DOC.is_file(), "falta `docs/infra/despliegue.md`.")
        texto = _texto(DOC)
        for tema in ("VERCEL_TOKEN", "workflow_dispatch", "a mano"):
            self.assertIn(tema, texto, f"el documento no dice nada de «{tema}».")

    def test_esta_indexado_donde_se_indexa_lo_demas(self):  # 027-AC9
        # Un documento que no está en los dos índices no lo encuentra nadie, y lo que no se
        # encuentra se vuelve a escribir distinto.
        self.assertIn("infra/despliegue.md", _texto(RAIZ / "docs" / "README.md"))
        self.assertIn("docs/infra/despliegue.md", _texto(RAIZ / "CLAUDE.md"))

    def test_verify_sigue_diciendo_que_el_no_exporta(self):  # 027-AC9
        # Ahora que SÍ hay quien exporta, el encabezado de `verify.yml` tiene que seguir
        # diciendo que él no — y nombrar al que sí, que es lo que evita que alguien le agregue
        # el paso de export por segunda vez.
        texto = _texto(VERIFY)
        self.assertIn("No exporta el juego", texto)
        self.assertIn("desplegar.yml", texto)

    def test_el_repo_ignora_lo_que_escribe_la_cli_de_vercel(self):  # 027-AC10
        # La segunda mitad del AC10 —«`verificar.py` deja los seis nodos en verde»— es la
        # corrida entera y no cabe adentro de un caso: la afirma el reporte del PR, con el
        #   python .claude/scripts/verificar.py
        # que la produjo. Acá se cierra la mitad que sí es un archivo.
        self.assertIn(".vercel/", _texto(RAIZ / ".gitignore"))


if __name__ == "__main__":
    unittest.main()

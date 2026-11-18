"""Lo que el editor re-serializa al guardar vuelve a lo que tenía, sobre un repo de juguete.

`reescritos_de_mas()` decide qué se devuelve; acá se prueba que el script lo devuelva de verdad:
lo limpio a lo de git, lo que ya tenía cambios a esos cambios, y las salidas del horneado quietas.
No hace falta Godot: el «editor» son escrituras con la fecha corrida.
"""

import contextlib
import io
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import hornear
from lib.horneado import (
    INTERMEDIOS_DEL_APOYO,
    LADO_DEL_ATLAS_SIN_LUZ,
    SALIDAS,
    SALIDAS_QUE_SE_DEVUELVEN,
    SALIDAS_SIN_LUZ,
)

#: Las texturas del modelo llevan acentos en el nombre, y cada una tiene su `.import` rastreado.
CON_ACENTO = "assets/models/textura portón.png.import"


class DevolverLoReescrito(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="hornear_")).resolve()
        self.addCleanup(shutil.rmtree, self.repo, True)
        for ruta in (
            *SALIDAS,
            "src/escenas/almacen.exr.import",
            "src/escenas/almacen.tscn",
            "sucio.tres",
            CON_ACENTO,
        ):
            self._escribir(ruta, "de git\n")
        self._git("init", "-q")
        self._git("add", ".")
        self._git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "x")
        self._escribir("sucio.tres", "cambio sin commitear\n")
        self.previos = hornear.sucios(self.repo)
        # La fecha de cada archivo la pone el caso: el reloj de los archivos tiene otra
        # resolución que `time.time()`, y uno escrito justo después puede quedar antes.
        self.desde = 1_000_000.0
        for ruta in self._git("ls-files", "-z").split("\0"):
            if ruta:
                os.utime(self.repo / ruta, (self.desde - 60, self.desde - 60))

    def _git(self, *args: str) -> str:
        return subprocess.run(
            ["git", *args], cwd=self.repo, check=True, capture_output=True, encoding="utf-8"
        ).stdout

    def _escribir(self, ruta: str, texto: str) -> None:
        (self.repo / ruta).parent.mkdir(parents=True, exist_ok=True)
        (self.repo / ruta).write_text(texto, encoding="utf-8")

    def _el_editor_escribe(self, ruta: str) -> None:
        self._escribir(ruta, "re-serializado\n")
        os.utime(self.repo / ruta, (self.desde + 60, self.desde + 60))

    def _leer(self, ruta: str) -> str:
        return (self.repo / ruta).read_text(encoding="utf-8")

    def test_lo_que_estaba_limpio_vuelve_a_lo_de_git(self) -> None:
        self._el_editor_escribe("src/escenas/almacen.tscn")
        hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(self._leer("src/escenas/almacen.tscn"), "de git\n")

    def test_lo_que_tenia_cambios_vuelve_a_esos_cambios(self) -> None:
        self._el_editor_escribe("sucio.tres")
        hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(self._leer("sucio.tres"), "cambio sin commitear\n")

    def test_las_salidas_del_horneado_quedan(self) -> None:
        for salida in SALIDAS:
            self._el_editor_escribe(salida)
        hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        for salida in SALIDAS:
            self.assertEqual(self._leer(salida), "re-serializado\n")

    def test_el_numero_de_capas_del_atlas_no_vuelve_al_horneado_anterior(self) -> None:
        ruta = "src/escenas/almacen.exr.import"
        self._escribir(ruta, "slices/vertical=16\n")
        os.utime(self.repo / ruta, (self.desde + 60, self.desde + 60))
        hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(self._leer(ruta), "slices/vertical=16\n")

    def test_lo_que_no_se_escribio_durante_la_corrida_no_se_toca(self) -> None:
        devueltos = hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(devueltos, [])
        self.assertEqual(self._leer("sucio.tres"), "cambio sin commitear\n")

    def test_una_ruta_con_acento_tambien_vuelve(self) -> None:
        # Sin `-z`, git la imprime entre comillas y con escapes octales, y esa ruta no existe:
        # el archivo se quedaba re-serializado sin que nada lo dijera.
        self._el_editor_escribe(CON_ACENTO)
        devueltos = hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(devueltos, [CON_ACENTO])
        self.assertEqual(self._leer(CON_ACENTO), "de git\n")

    def test_una_ruta_con_acento_que_tenia_cambios_vuelve_a_esos_cambios(self) -> None:
        self._escribir(CON_ACENTO, "cambio sin commitear\n")
        previos = hornear.sucios(self.repo)
        self._el_editor_escribe(CON_ACENTO)
        hornear.devolver_lo_reescrito(self.repo, self.desde, previos)
        self.assertEqual(self._leer(CON_ACENTO), "cambio sin commitear\n")


class HorneadoConLuz(unittest.TestCase):
    # El horneado con luz son varios pasos, y cada uno lo hace otro programa: acá se prueba el
    # orden y qué pasa si uno falla, con los programas reemplazados por registros.
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="hornear_")).resolve()
        self.addCleanup(shutil.rmtree, self.repo, True)
        for ruta in (*SALIDAS_QUE_SE_DEVUELVEN, SALIDAS_SIN_LUZ[1] + ".import", "sucio.tres"):
            self._escribir(ruta, "de git\n")
        subprocess.run(["git", "init", "-q"], cwd=self.repo, check=True)
        subprocess.run(["git", "add", "."], cwd=self.repo, check=True)
        subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "x"],
            cwd=self.repo,
            check=True,
        )
        self.pasos: list[str] = []

    def _escribir(self, ruta: str, texto: str) -> None:
        (self.repo / ruta).parent.mkdir(parents=True, exist_ok=True)
        (self.repo / ruta).write_text(texto, encoding="utf-8")

    def _leer(self, ruta: str) -> str:
        return (self.repo / ruta).read_text(encoding="utf-8")

    def _sesion(self, godot: str, variante: str, salidas: tuple[str, ...]) -> None:
        self.pasos.append("editor:" + (variante or "siempre"))

    def _reparar(self, blender: str, atlas: list[str]) -> None:
        self.pasos.append("reparar:" + ",".join(Path(a).name for a in atlas))

    def _mezclar(self, godot: str, nivel: float) -> None:
        self.pasos.append("mezclar")

    def _oclusionar(
        self,
        godot: str,
        entrada: str,
        salida: str,
        nivel: float,
        radio: float = 0.0,
        rayos: int = 0,
    ) -> None:
        self.pasos.append(f"oclusion:{Path(entrada).name}:{Path(salida).name}:{nivel}")

    def _correr(self, nivel: float, oclusion: float = 0.0) -> None:
        with (
            mock.patch.object(hornear, "sesion_del_editor", self._sesion),
            mock.patch.object(hornear, "reparar_lineas", self._reparar),
            mock.patch.object(hornear, "mezclar_atlas", self._mezclar),
            mock.patch.object(hornear, "oclusionar_atlas", self._oclusionar),
            mock.patch.object(hornear, "NIVEL_DE_APOYO", nivel),
            mock.patch.object(hornear, "NIVEL_DE_OCLUSION", oclusion),
        ):
            hornear.hornear_con_luz("godot", "blender")

    def test_hornea_repara_hornea_con_obstaculos_repara_mezcla_y_repara_el_resultado(self) -> None:
        self._correr(0.5)
        atlas = Path(SALIDAS[1]).name
        apoyo = Path(INTERMEDIOS_DEL_APOYO[1]).name
        self.assertEqual(
            self.pasos,
            [
                "editor:siempre",
                f"reparar:{atlas}",
                "editor:con_apoyo",
                f"reparar:{apoyo}",
                "mezclar",
                f"reparar:{atlas}",
            ],
        )

    def test_con_nivel_cero_el_atlas_de_siempre_es_el_final(self) -> None:
        self._correr(0.0)
        self.assertEqual(self.pasos, ["editor:siempre", "reparar:" + Path(SALIDAS[1]).name])

    def test_la_oclusion_corre_al_final_sobre_el_atlas_ya_mezclado_y_reparado(self) -> None:
        self._correr(0.5, 0.25)
        atlas = Path(SALIDAS[1]).name
        apoyo = Path(INTERMEDIOS_DEL_APOYO[1]).name
        self.assertEqual(
            self.pasos,
            [
                "editor:siempre",
                f"reparar:{atlas}",
                "editor:con_apoyo",
                f"reparar:{apoyo}",
                "mezclar",
                f"reparar:{atlas}",
                f"oclusion:{atlas}:{atlas}:0.25",
            ],
        )

    def test_sin_sombra_de_apoyo_la_oclusion_igual_corre_despues_de_reparar(self) -> None:
        self._correr(0.0, 1.0)
        atlas = Path(SALIDAS[1]).name
        self.assertEqual(
            self.pasos, ["editor:siempre", f"reparar:{atlas}", f"oclusion:{atlas}:{atlas}:1.0"]
        )

    def test_con_nivel_de_oclusion_cero_el_paso_no_corre(self) -> None:
        self._correr(0.5, 0.0)
        self.assertFalse([paso for paso in self.pasos if paso.startswith("oclusion")])

    def test_el_horneado_sin_luz_no_recibe_oclusion(self) -> None:
        with (
            mock.patch.object(hornear, "sesion_del_editor", self._sesion),
            mock.patch.object(hornear, "reparar_lineas", self._reparar),
            mock.patch.object(hornear, "reducir_atlas", self._reducir),
            mock.patch.object(hornear, "oclusionar_atlas", self._oclusionar),
            mock.patch.object(hornear, "NIVEL_DE_OCLUSION", 1.0),
        ):
            hornear.hornear_sin_luz("godot", "blender")
        self.assertFalse([paso for paso in self.pasos if paso.startswith("oclusion")])

    def _solo_la_oclusion(self, argumentos: list[str], oclusionar=None) -> int:
        with (
            mock.patch.object(hornear, "RAIZ", str(self.repo)),
            mock.patch.object(hornear, "resolver", lambda entorno: ("godot", None)),
            mock.patch.object(hornear.lib_blender, "resolver", lambda entorno: (None, None)),
            mock.patch.object(hornear, "oclusionar_atlas", oclusionar or self._oclusionar),
        ):
            return hornear.main(argumentos)

    def test_el_comando_suelto_aplica_la_oclusion_al_atlas_de_la_rama_sin_hornear(self) -> None:
        self.assertEqual(self._solo_la_oclusion(["--oclusion"]), 0)
        atlas = Path(SALIDAS[1]).name
        self.assertEqual(self.pasos, [f"oclusion:{atlas}:{atlas}:{hornear.NIVEL_DE_OCLUSION}"])

    def test_el_comando_suelto_acepta_otro_nivel_y_otro_destino(self) -> None:
        destino = str(self.repo / "afuera" / "prueba.exr")
        self.assertEqual(
            self._solo_la_oclusion(["--oclusion", "--nivel", "0.25", "--salida", destino]), 0
        )
        self.assertEqual(self.pasos, [f"oclusion:{Path(SALIDAS[1]).name}:prueba.exr:0.25"])

    def test_el_comando_suelto_con_nivel_cero_no_hace_nada(self) -> None:
        self.assertEqual(self._solo_la_oclusion(["--oclusion", "--nivel", "0"]), 0)
        self.assertEqual(self.pasos, [])

    def test_las_opciones_de_la_oclusion_sin_oclusion_se_rechazan_y_no_hornean(self) -> None:
        for argumentos in (
            ["--nivel", "0.5"],
            ["--radio", "0.3"],
            ["--rayos", "8"],
            ["--salida", "prueba.exr"],
        ):
            with self.subTest(argumentos=argumentos):
                horneos: list[str] = []
                with (
                    mock.patch.object(hornear, "hornear_con_luz", lambda *_: horneos.append("luz")),
                    contextlib.redirect_stderr(io.StringIO()) as error,
                    self.assertRaises(SystemExit) as salida,
                ):
                    self._solo_la_oclusion(argumentos)
                self.assertNotEqual(salida.exception.code, 0)
                self.assertIn(argumentos[0], error.getvalue())
                self.assertEqual(horneos, [])
                self.assertEqual(self.pasos, [])

    def test_sin_luz_junto_con_oclusion_se_rechaza_y_no_aplica_nada(self) -> None:
        with (
            contextlib.redirect_stderr(io.StringIO()) as error,
            self.assertRaises(SystemExit) as salida,
        ):
            self._solo_la_oclusion(["--oclusion", "--sin-luz"])
        self.assertNotEqual(salida.exception.code, 0)
        self.assertIn("--sin-luz", error.getvalue())
        self.assertEqual(self.pasos, [])

    def test_si_la_oclusion_falla_el_atlas_queda_como_estaba(self) -> None:
        def a_medias(
            godot: str, entrada: str, salida: str, nivel: float, radio: float, rayos: int
        ) -> None:
            self._escribir(SALIDAS[1], "a medias\n")
            raise hornear.Fallo("la oclusión se cayó")

        self.assertNotEqual(self._solo_la_oclusion(["--oclusion"], a_medias), 0)
        self.assertEqual(self._leer(SALIDAS[1]), "de git\n")

    def _main_con_un_paso_que_falla(self) -> int:
        def hornear_a_medias(godot: str, blender: str) -> None:
            for ruta in (*SALIDAS_QUE_SE_DEVUELVEN, *INTERMEDIOS_DEL_APOYO):
                self._escribir(ruta, "a medias\n")
            raise hornear.Fallo("el editor se cayó")

        with (
            mock.patch.object(hornear, "RAIZ", str(self.repo)),
            mock.patch.object(hornear, "resolver", lambda entorno: ("godot", None)),
            mock.patch.object(hornear.lib_blender, "resolver", lambda entorno: ("blender", None)),
            mock.patch.object(hornear, "sesion_bloqueada", lambda procesos: False),
            mock.patch.object(hornear, "hornear_con_luz", hornear_a_medias),
        ):
            return hornear.main([])

    def test_si_un_paso_falla_las_salidas_quedan_como_estaban_y_sale_con_error(self) -> None:
        self.assertNotEqual(self._main_con_un_paso_que_falla(), 0)
        for ruta in SALIDAS_QUE_SE_DEVUELVEN:
            self.assertEqual(self._leer(ruta), "de git\n")

    def test_si_el_horneado_sin_luz_falla_el_import_de_su_atlas_queda_como_estaba(self) -> None:
        importado = SALIDAS_SIN_LUZ[1] + ".import"

        def sesion_a_medias(godot: str, variante: str, salidas: tuple[str, ...]) -> None:
            self._escribir(importado, "a medias\n")
            raise hornear.Fallo("el editor se cayó")

        with (
            mock.patch.object(hornear, "RAIZ", str(self.repo)),
            mock.patch.object(hornear, "resolver", lambda entorno: ("godot", None)),
            mock.patch.object(hornear.lib_blender, "resolver", lambda entorno: ("blender", None)),
            mock.patch.object(hornear, "sesion_bloqueada", lambda procesos: False),
            mock.patch.object(hornear, "sesion_del_editor", sesion_a_medias),
        ):
            self.assertNotEqual(hornear.main(["--sin-luz"]), 0)
        self.assertEqual(self._leer(importado), "de git\n")

    def _reducir(self, blender: str, atlas: list[str], lado: int) -> None:
        self.pasos.append(f"reducir:{Path(atlas[0]).name}:{lado}")

    def test_el_horneado_sin_luz_hornea_repara_y_recien_despues_reduce(self) -> None:
        with (
            mock.patch.object(hornear, "sesion_del_editor", self._sesion),
            mock.patch.object(hornear, "reparar_lineas", self._reparar),
            mock.patch.object(hornear, "reducir_atlas", self._reducir),
        ):
            hornear.hornear_sin_luz("godot", "blender")
        atlas = Path(SALIDAS_SIN_LUZ[1]).name
        self.assertEqual(
            self.pasos,
            ["editor:sin_luz", f"reparar:{atlas}", f"reducir:{atlas}:{LADO_DEL_ATLAS_SIN_LUZ}"],
        )

    def test_el_horneado_con_luz_nunca_se_reduce(self) -> None:
        with mock.patch.object(hornear, "reducir_atlas", self._reducir):
            self._correr(0.5)
        self.assertFalse([paso for paso in self.pasos if paso.startswith("reducir")])

    def test_si_la_reduccion_falla_el_atlas_y_el_horneado_sin_luz_quedan_como_estaban(self) -> None:
        def sesion_que_escribe(godot: str, variante: str, salidas: tuple[str, ...]) -> None:
            for ruta in SALIDAS_SIN_LUZ:
                self._escribir(ruta, "recien horneado\n")

        def reduccion_que_falla(blender: str, atlas: list[str], lado: int) -> None:
            self._escribir(atlas[0].removeprefix(str(self.repo) + os.sep), "a medias\n")
            raise hornear.Fallo("no pude reducir")

        with (
            mock.patch.object(hornear, "RAIZ", str(self.repo)),
            mock.patch.object(hornear, "resolver", lambda entorno: ("godot", None)),
            mock.patch.object(hornear.lib_blender, "resolver", lambda entorno: ("blender", None)),
            mock.patch.object(hornear, "sesion_bloqueada", lambda procesos: False),
            mock.patch.object(hornear, "sesion_del_editor", sesion_que_escribe),
            mock.patch.object(hornear, "reparar_lineas", self._reparar),
            mock.patch.object(hornear, "reducir_atlas", reduccion_que_falla),
        ):
            self.assertNotEqual(hornear.main(["--sin-luz"]), 0)
        for ruta in SALIDAS_SIN_LUZ:
            self.assertEqual(self._leer(ruta), "de git\n")

    def test_si_un_paso_falla_no_quedan_archivos_intermedios(self) -> None:
        self._main_con_un_paso_que_falla()
        for ruta in INTERMEDIOS_DEL_APOYO:
            self.assertFalse((self.repo / ruta).exists())

    def test_si_sale_bien_tampoco_quedan_archivos_intermedios(self) -> None:
        def hornear_bien(godot: str, blender: str) -> None:
            for ruta in INTERMEDIOS_DEL_APOYO:
                self._escribir(ruta, "de paso\n")
            self._escribir(SALIDAS[1], "horneado\n")

        with (
            mock.patch.object(hornear, "RAIZ", str(self.repo)),
            mock.patch.object(hornear, "resolver", lambda entorno: ("godot", None)),
            mock.patch.object(hornear.lib_blender, "resolver", lambda entorno: ("blender", None)),
            mock.patch.object(hornear, "sesion_bloqueada", lambda procesos: False),
            mock.patch.object(hornear, "hornear_con_luz", hornear_bien),
        ):
            self.assertEqual(hornear.main([]), 0)
        for ruta in INTERMEDIOS_DEL_APOYO:
            self.assertFalse((self.repo / ruta).exists())
        self.assertEqual(self._leer(SALIDAS[1]), "horneado\n")

    def test_una_salida_que_no_existia_se_borra_si_el_horneado_falla(self) -> None:
        respaldo = hornear.guardar_salidas(self.repo, ("src/escenas/nueva.exr",))
        self._escribir("src/escenas/nueva.exr", "a medias\n")
        hornear.devolver_salidas(self.repo, respaldo)
        self.assertFalse((self.repo / "src/escenas/nueva.exr").exists())


if __name__ == "__main__":
    unittest.main()

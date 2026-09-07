"""Los tests del gate del hook.

Se divide en dos: lo puro se importa y se ejerce directo, y el veredicto entero se ejerce
lanzando el script como subproceso —que es como lo lanza Claude Code— con un payload por
stdin.

**Lo que NO se ejerce acá es la rama.** El veredicto depende de en qué rama está parado el
repo cuando el test corre, y un test que cambia de rama para probarse rompería la sesión que
lo corre. Lo que sí se ejerce es todo lo que decide ANTES de mirar la rama, que es donde
estuvieron los dos bugs conocidos de este gate: el payload que no se entiende y la ruta de
otro disco.
"""

import json
import shutil
import subprocess
import tempfile
import sys
import unittest
from pathlib import Path

import gate_de_spec
from lib.repo import RAIZ

GATE = Path(gate_de_spec.__file__)


def correr(payload: dict) -> dict:
    proceso = subprocess.run(
        [sys.executable, str(GATE)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        encoding="utf-8",
        cwd=RAIZ,
    )
    assert proceso.returncode == 0, f"el gate murió: {proceso.stderr}"
    return json.loads(proceso.stdout)["hookSpecificOutput"]


class DestinosEnBash(unittest.TestCase):
    def test_la_redireccion(self):
        # El escape más corto de todos: no necesita ningún comando conocido adelante.
        self.assertIn("src/dominio/turno.gd", gate_de_spec.destinos_del_comando("echo x > src/dominio/turno.gd"))

    def test_la_redireccion_que_agrega(self):
        self.assertIn("src/x.gd", gate_de_spec.destinos_del_comando("echo x >> src/x.gd"))

    def test_no_confunde_un_descriptor_con_un_archivo(self):
        # `2>&1` redirige un descriptor, no un archivo.
        self.assertEqual(gate_de_spec.destinos_del_comando("gdlint src 2>&1"), [])

    def test_sed_con_i(self):
        # El agujero del tamaño de `sed -i`: negarle `Edit` a un agente lo empuja justo acá.
        self.assertIn("src/x.gd", gate_de_spec.destinos_del_comando("sed -i 's/a/b/' src/x.gd"))

    def test_sed_sin_i_no_escribe(self):
        self.assertEqual(gate_de_spec.destinos_del_comando("sed 's/a/b/' src/x.gd"), [])

    def test_la_ruta_absoluta_de_un_escritor_cuenta_igual(self):
        # Comparar el token entero dejaría pasar `/usr/bin/sed`.
        self.assertIn("src/x.gd", gate_de_spec.destinos_del_comando("/usr/bin/sed -i 's/a/b/' src/x.gd"))

    def test_cp_escribe_solo_el_destino(self):
        # Contar el origen bloquearía un `cp src/x.gd /tmp/` legítimo.
        self.assertEqual(gate_de_spec.destinos_del_comando("cp src/x.gd /tmp/copia.gd"), ["/tmp/copia.gd"])

    def test_rm_destruye_todos_sus_argumentos(self):
        destinos = gate_de_spec.destinos_del_comando("rm -rf src test")
        self.assertIn("src", destinos)
        self.assertIn("test", destinos)

    def test_el_tee_del_segundo_segmento(self):
        # Mirar el comando entero de una atribuiría el destino al primero.
        self.assertIn("src/x.gd", gate_de_spec.destinos_del_comando("cat viejo.gd | tee src/x.gd"))

    def test_saca_las_comillas(self):
        self.assertIn("src/con espacio.gd",
                      gate_de_spec.destinos_del_comando('echo x > "src/con espacio.gd"'))

    def test_un_comando_que_no_escribe_no_devuelve_nada(self):
        self.assertEqual(gate_de_spec.destinos_del_comando("git status"), [])


class DestinosEnPowerShell(unittest.TestCase):
    """`PowerShell` es una herramienta aparte de `Bash`, y el matcher del hook la ignoraba.

    No es hipotético: montando este harness, un bug del propio hook dejó la sesión encerrada y
    la salida fue escribir archivos con la herramienta de PowerShell — o sea que el gate se
    salteaba solo con cambiar de herramienta.
    """

    def test_set_content_con_path_nombrado(self):
        self.assertIn(
            "src/x.gd",
            gate_de_spec.destinos_del_comando('Set-Content -Path src/x.gd -Value "hola"'),
        )

    def test_set_content_posicional(self):
        self.assertIn("src/x.gd", gate_de_spec.destinos_del_comando('Set-Content src/x.gd "hola"'))

    def test_no_distingue_mayusculas(self):
        # PowerShell no las distingue: comparar sensible dejaría pasar `set-content`.
        self.assertIn("src/x.gd", gate_de_spec.destinos_del_comando("set-content -path src/x.gd -value x"))

    def test_out_file_usa_filepath(self):
        self.assertIn("src/x.gd", gate_de_spec.destinos_del_comando("$t | Out-File -FilePath src/x.gd"))

    def test_remove_item(self):
        self.assertIn("src", gate_de_spec.destinos_del_comando("Remove-Item -Recurse -Force src"))

    def test_copy_item_escribe_solo_el_destino(self):
        # Igual que `cp`: contar el origen bloquearía una copia legítima hacia afuera.
        self.assertEqual(
            gate_de_spec.destinos_del_comando("Copy-Item src/x.gd C:/tmp/copia.gd"),
            ["C:/tmp/copia.gd"],
        )

    def test_copy_item_con_destination_nombrado(self):
        self.assertEqual(
            gate_de_spec.destinos_del_comando("Copy-Item -Path a.gd -Destination src/x.gd"),
            ["src/x.gd"],
        )

    def test_un_cmdlet_que_lee_no_devuelve_nada(self):
        self.assertEqual(gate_de_spec.destinos_del_comando("Get-Content src/x.gd"), [])

    def test_la_redireccion_de_powershell_cuenta_igual(self):
        # `>` es la misma sintaxis en los dos shells, y ya la cazaba el regex de redirección.
        self.assertIn("src/x.gd", gate_de_spec.destinos_del_comando('"hola" > src/x.gd'))

    def test_el_payload_de_powershell_se_lee_como_comando(self):
        payload = json.dumps(
            {"tool_name": "PowerShell", "tool_input": {"command": "Set-Content src/x.gd -Value y"}}
        )
        # `assertIn` y no `assertEqual`: sin un parámetro nombrado, el gate devuelve TODOS los
        # posicionales, así que acá también viene el `y` del `-Value`. Devolver de más es
        # deliberado y no cuesta nada —un candidato que no es una ruta protegida se descarta
        # solo—; el porqué está en `_destino_de_cmdlet`, y lo que se compra es no perder un
        # destino real por creer saber qué parámetro lleva valor.
        self.assertIn("src/x.gd", gate_de_spec.rutas_del_payload(payload))

    def test_un_interruptor_no_se_come_el_destino(self):
        # `Remove-Item -Force src` es el caso que decidió la forma de `_destino_de_cmdlet`:
        # tratar a `-Force` como si consumiera un valor se come el `src` y el gate deja pasar un
        # borrado de verdad.
        self.assertIn("src", gate_de_spec.destinos_del_comando("Remove-Item -Force src"))


class RutasDelPayload(unittest.TestCase):
    def test_una_edicion(self):
        payload = json.dumps({"tool_name": "Edit", "tool_input": {"file_path": "src/x.gd"}})
        self.assertEqual(gate_de_spec.rutas_del_payload(payload), ["src/x.gd"])

    def test_un_bash_que_no_escribe_devuelve_lista_vacia(self):
        # `[]` es una respuesta y pasa callado. `None` no.
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "ls"}})
        self.assertEqual(gate_de_spec.rutas_del_payload(payload), [])

    def test_un_payload_que_no_se_entiende_es_none(self):
        # `None` NO es «ninguna»: es «no se pudo decidir», y el gate lo DECLARA. Un payload
        # que cambiara de forma dejaría al gate mudo para siempre, y esto es lo que lo delata.
        self.assertIsNone(gate_de_spec.rutas_del_payload("{"))
        self.assertIsNone(gate_de_spec.rutas_del_payload(json.dumps({"tool_name": "Edit"})))


class ElVeredicto(unittest.TestCase):
    def test_deja_pasar_lo_que_no_esta_protegido(self):
        salida = correr({"tool_name": "Edit", "tool_input": {"file_path": "specs/mapa.json"}})
        self.assertEqual(salida["permissionDecision"], "allow")
        # Y pasa callado: un gate que decidió que no le tocaba no tiene nada que declarar.
        self.assertNotIn("permissionDecisionReason", salida)

    def test_deja_pasar_y_lo_dice_si_no_entiende_el_payload(self):
        # Falla abierto a propósito: un gate que rompe la sesión entera se desactiva el mismo
        # día, y ahí no queda gate.
        salida = correr({"tool_name": "Edit", "tool_input": {}})
        self.assertEqual(salida["permissionDecision"], "allow")
        self.assertIn("no se pudo verificar", salida["permissionDecisionReason"])

    def test_deja_pasar_un_archivo_de_otro_disco(self):
        # El scratchpad vive en `C:` y el repo en `D:`. Sin la decisión de
        # `rutas_protegidas.py`, esto bloquearía TODA escritura ahí.
        salida = correr(
            {"tool_name": "Write", "tool_input": {"file_path": r"C:\Users\x\Temp\nota.txt"}}
        )
        self.assertEqual(salida["permissionDecision"], "allow")

    def test_no_se_bloquea_a_si_mismo(self):
        # `.claude/` queda afuera a propósito: un gate que se impide arreglarse a sí mismo se
        # termina borrando en vez de corrigiéndose.
        salida = correr(
            {"tool_name": "Edit", "tool_input": {"file_path": ".claude/scripts/gate_de_spec.py"}}
        )
        self.assertEqual(salida["permissionDecision"], "allow")


class LaRaizQueManda(unittest.TestCase):
    """De qué árbol de git es el archivo que se va a escribir.

    **Medido el 2026-09-07**: los dos batch que abren worktrees escriben el 100 % de su código
    adentro de uno, y el gate los miraba contra el checkout principal. Con ruta absoluta al
    worktree contestaba `allow` —relativa a la raíz principal, `.claude/worktrees/pr-76/src/…`
    no empieza con `src/`— y con ruta relativa contestaba `deny` nombrando la rama del
    principal. O sea: apagado donde más se escribe, y equivocado donde hablaba.
    """

    def _repo(self, nombre: str) -> Path:
        carpeta = Path(tempfile.mkdtemp(prefix=nombre))
        subprocess.run(["git", "init", "-q"], cwd=carpeta, check=True)
        (carpeta / "src").mkdir()
        (carpeta / "src" / "cosa.gd").write_text("", encoding="utf-8")
        self.addCleanup(shutil.rmtree, carpeta, True)
        return carpeta

    def test_una_ruta_absoluta_manda_su_propio_arbol_y_no_el_principal(self):
        otro = self._repo("gate_abs_")
        raiz = gate_de_spec.raiz_que_manda(str(otro / "src" / "cosa.gd"), None)
        self.assertEqual(Path(raiz).resolve(), otro.resolve())
        self.assertNotEqual(Path(raiz).resolve(), Path(RAIZ).resolve())

    def test_una_ruta_relativa_se_resuelve_contra_el_cwd_del_payload(self):
        # Es lo único que desambigua un `src/x.gd` escrito desde un worktree: el hook corre con
        # el cwd del checkout principal y la ruta no dice a cuál de los dos árboles apunta.
        otro = self._repo("gate_rel_")
        raiz = gate_de_spec.raiz_que_manda("src/cosa.gd", str(otro))
        self.assertEqual(Path(raiz).resolve(), otro.resolve())

    def test_sin_cwd_ni_arbol_legible_cae_en_la_raiz_y_no_revienta(self):
        # Falla abierto, como todo el resto del gate.
        raiz = gate_de_spec.raiz_que_manda("src/dominio/reglas.gd", None)
        self.assertEqual(Path(raiz).resolve(), Path(RAIZ).resolve())


if __name__ == "__main__":
    unittest.main()

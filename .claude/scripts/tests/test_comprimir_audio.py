"""El compresor de audio decide bien sin correr `ffmpeg`: la CI no lo tiene instalado."""

import io
import struct
import tempfile
import unittest
import wave
from contextlib import redirect_stderr
from pathlib import Path

import comprimir_audio as ca


def _wav(ruta: Path, canales: int, hz: int) -> Path:
    with wave.open(str(ruta), "wb") as escrito:
        escrito.setnchannels(canales)
        escrito.setsampwidth(2)
        escrito.setframerate(hz)
        escrito.writeframes(b"\x00\x00" * canales * 10)
    return ruta


def _wav_de_punto_flotante(ruta: Path) -> Path:
    # `wave` no escribe este formato, así que la cabecera va a mano. El 3 es punto flotante.
    fmt = struct.pack("<HHIIHH", 3, 1, 22050, 22050 * 4, 4, 32)
    datos = b"\x00" * 8
    cuerpo = b"WAVEfmt " + struct.pack("<I", len(fmt)) + fmt
    cuerpo += b"data" + struct.pack("<I", len(datos)) + datos
    ruta.write_bytes(b"RIFF" + struct.pack("<I", len(cuerpo)) + cuerpo)
    return ruta


class Destino(unittest.TestCase):
    def test_ambiente_y_musica_van_a_ogg(self) -> None:
        self.assertEqual(ca.destino(Path("AMB_X.mp3")).suffix, ".ogg")
        self.assertEqual(ca.destino(Path("MUS_X.mp3")).suffix, ".ogg")

    def test_efectos_van_a_wav(self) -> None:
        self.assertEqual(ca.destino(Path("SFX_X.mp3")).suffix, ".wav")

    def test_un_prefijo_desconocido_falla_y_lo_nombra(self) -> None:
        with self.assertRaisesRegex(ca.PrefijoDesconocido, "Voz_X.mp3"):
            ca.destino(Path("Voz_X.mp3"))


class Comando(unittest.TestCase):
    def test_ambiente_sale_mono_y_musica_estereo(self) -> None:
        amb = ca.comando(Path("AMB_X.mp3"), Path("o"))
        mus = ca.comando(Path("MUS_X.mp3"), Path("o"))
        self.assertIn("libvorbis", amb)
        self.assertEqual(amb[amb.index("-ac") + 1], "1")
        self.assertEqual(mus[mus.index("-ac") + 1], "2")

    def test_efectos_salen_mono_a_22050(self) -> None:
        sfx = ca.comando(Path("SFX_X.mp3"), Path("o"))
        self.assertEqual(sfx[sfx.index("-ar") + 1], "22050")
        self.assertEqual(sfx[sfx.index("-ac") + 1], "1")
        self.assertIn("pcm_s16le", sfx)

    def test_la_salida_es_determinista(self) -> None:
        self.assertIn("+bitexact", ca.comando(Path("MUS_X.mp3"), Path("o")))

    def test_el_neon_se_recorta_a_un_bucle(self) -> None:
        self.assertIn("-filter_complex", ca.comando(Path("AMB_PROXIMIDAD_Neon.mp3"), Path("o")))
        self.assertNotIn("-filter_complex", ca.comando(Path("AMB_Otro.mp3"), Path("o")))


class YaComprimido(unittest.TestCase):
    def test_un_mp3_no_esta_comprimido(self) -> None:
        self.assertFalse(ca.ya_comprimido(Path("SFX_X.mp3")))

    def test_un_ogg_no_se_vuelve_a_codificar(self) -> None:
        self.assertTrue(ca.ya_comprimido(Path("MUS_X.ogg")))

    def test_un_wav_estereo_pasa_igual_por_el_script(self) -> None:
        with tempfile.TemporaryDirectory() as carpeta:
            wav = _wav(Path(carpeta) / "SFX_Garage.wav", 2, 44100)
            self.assertFalse(ca.ya_comprimido(wav))

    def test_un_wav_mono_a_22050_queda_como_esta(self) -> None:
        with tempfile.TemporaryDirectory() as carpeta:
            wav = _wav(Path(carpeta) / "SFX_Listo.wav", 1, 22050)
            self.assertTrue(ca.ya_comprimido(wav))

    def test_un_wav_de_punto_flotante_pasa_por_el_script(self) -> None:
        with tempfile.TemporaryDirectory() as carpeta:
            wav = _wav_de_punto_flotante(Path(carpeta) / "SFX_Float.wav")
            self.assertFalse(ca.ya_comprimido(wav))


class Comprimir(unittest.TestCase):
    def test_reemplaza_el_original_y_borra_su_import(self) -> None:
        with tempfile.TemporaryDirectory() as carpeta:
            origen = Path(carpeta) / "SFX_X.mp3"
            origen.write_bytes(b"mp3")
            (Path(carpeta) / "SFX_X.mp3.import").write_bytes(b"")
            final = ca.comprimir(origen, lambda args: Path(args[-1]).write_bytes(b"wav"))
            self.assertEqual(sorted(p.name for p in Path(carpeta).iterdir()), ["SFX_X.wav"])
            self.assertEqual(final.read_bytes(), b"wav")


class Main(unittest.TestCase):
    def test_sin_ffmpeg_falla_con_un_mensaje_que_lo_nombra(self) -> None:
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertEqual(ca.main(buscar=lambda _: None), 1)
        self.assertIn("ffmpeg", err.getvalue())


if __name__ == "__main__":
    unittest.main()

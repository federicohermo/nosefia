"""Comprime los audios de `assets/audio/` con `ffmpeg`, según el prefijo de cada archivo.

Uso, desde la raíz del repo:

    python .claude/scripts/comprimir_audio.py

`AMB_` y `MUS_` van a Ogg Vorbis; `SFX_` va a WAV mono de 16 bits, que Godot importa con QOA.
El original se reemplaza y su `.import` se borra: el `--import` siguiente de Godot escribe el
nuevo.

**Es idempotente**: un archivo que ya está en su formato de destino no se vuelve a codificar.
Recodificar un Ogg lo degrada y cambia sus bytes en cada corrida. `-bitexact` saca además el
número de serie al azar del Ogg y la versión del codificador.

Un prefijo desconocido frena todo antes de tocar un solo archivo: copiarlo tal cual dejaría un
audio sin comprimir que nadie mira.
"""

import shutil
import subprocess
import sys
import wave
from pathlib import Path
from typing import Callable

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / ".claude" / "scripts"))

from lib.consola import configurar  # noqa: E402

configurar()

CARPETA = RAIZ / "assets" / "audio"

PREFIJOS = ("AMB_", "MUS_", "SFX_")

KBPS_DE_AMBIENTE = 64
KBPS_DE_MUSICA = 80
HZ_DE_EFECTOS = 22050

# Inicio, largo y cruce, en segundos. El cruce funde la cola del tramo con su principio, y por
# eso el final empalma con el comienzo sin un clic.
BUCLES = {"AMB_PROXIMIDAD_Neon": (60.0, 30.0, 3.0)}

BANDERAS_FIJAS = ["-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1"]


class PrefijoDesconocido(ValueError):
    pass


def destino(origen: Path) -> Path:
    """La ruta que el archivo tiene que tener después de comprimirse."""
    if origen.name.startswith(("AMB_", "MUS_")):
        return origen.with_suffix(".ogg")
    if origen.name.startswith("SFX_"):
        return origen.with_suffix(".wav")
    raise PrefijoDesconocido(origen.name)


def ya_comprimido(origen: Path) -> bool:
    if origen.suffix != destino(origen).suffix:
        return False
    if origen.suffix == ".ogg":
        return True
    with wave.open(str(origen), "rb") as leido:
        return (
            leido.getnchannels() == 1
            and leido.getframerate() == HZ_DE_EFECTOS
            and leido.getsampwidth() == 2
        )


def _filtro_de_bucle(inicio: float, largo: float, cruce: float) -> str:
    fin = inicio + largo + cruce
    return (
        f"[0:a]atrim={inicio}:{fin},asetpts=PTS-STARTPTS,asplit=3[a][b][c];"
        f"[a]atrim=0:{cruce},asetpts=PTS-STARTPTS,afade=t=in:d={cruce}:curve=qsin[entra];"
        f"[b]atrim={largo}:{largo + cruce},asetpts=PTS-STARTPTS,"
        f"afade=t=out:d={cruce}:curve=qsin[sale];"
        f"[entra][sale]amix=inputs=2:normalize=0[cabeza];"
        f"[c]atrim={cruce}:{largo},asetpts=PTS-STARTPTS[cuerpo];"
        f"[cabeza][cuerpo]concat=n=2:v=0:a=1[out]"
    )


def comando(origen: Path, salida: Path) -> list[str]:
    """Los argumentos de `ffmpeg` que llevan `origen` a su formato, escritos en `salida`."""
    args = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(origen)]
    bucle = BUCLES.get(origen.stem)
    if bucle:
        args += ["-filter_complex", _filtro_de_bucle(*bucle), "-map", "[out]"]
    else:
        args += ["-map", "0:a"]
    nombre = origen.name
    if nombre.startswith("AMB_"):
        args += ["-ac", "1", "-c:a", "libvorbis", "-b:a", f"{KBPS_DE_AMBIENTE}k", "-f", "ogg"]
    elif nombre.startswith("MUS_"):
        args += ["-ac", "2", "-c:a", "libvorbis", "-b:a", f"{KBPS_DE_MUSICA}k", "-f", "ogg"]
    else:
        args += ["-ac", "1", "-ar", str(HZ_DE_EFECTOS), "-c:a", "pcm_s16le", "-f", "wav"]
    return args + BANDERAS_FIJAS + [str(salida)]


def audios(carpeta: Path) -> list[Path]:
    return sorted(p for p in carpeta.iterdir() if p.is_file() and p.suffix != ".import")


def comprimir(origen: Path, correr: Callable[[list[str]], None]) -> Path:
    final = destino(origen)
    temporal = final.with_name(final.name + ".tmp")
    correr(comando(origen, temporal))
    temporal.replace(final)
    if final != origen:
        origen.unlink()
        origen.with_name(origen.name + ".import").unlink(missing_ok=True)
    return final


def _correr(args: list[str]) -> None:
    subprocess.run(args, check=True)


def main(buscar: Callable[[str], str | None] = shutil.which) -> int:
    if buscar("ffmpeg") is None:
        print(
            "No encuentro `ffmpeg` en el PATH. Instalalo (en Windows: `scoop install ffmpeg`)"
            " y abrí una terminal nueva.",
            file=sys.stderr,
        )
        return 1
    archivos = audios(CARPETA)
    desconocidos = [p.name for p in archivos if not p.name.startswith(PREFIJOS)]
    if desconocidos:
        print(
            "Prefijo desconocido (va AMB_, MUS_ o SFX_): " + ", ".join(desconocidos),
            file=sys.stderr,
        )
        return 1
    for origen in archivos:
        if ya_comprimido(origen):
            continue
        final = comprimir(origen, _correr)
        print(f"{origen.name} -> {final.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

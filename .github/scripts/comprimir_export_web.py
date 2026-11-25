"""Precomprime con Brotli los binarios pesados del export web y arma su `vercel.json`.

    python .github/scripts/comprimir_export_web.py export/web vercel.json

Godot exporta `index.wasm` e `index.pck` sin comprimir. Vercel no aplica compresión automática
sobre archivos grandes ni sobre `application/octet-stream`, y además rechaza archivos sueltos por
encima de su límite por archivo. Precomprimirlos en `*.br` con rewrites y headers explícitos reduce
la transferencia inicial, evita la doble compresión del CDN y mantiene `vercel.json` de raíz
compatible con exports sin comprimir.
"""

import copy
import hashlib
import json
import sys
from pathlib import Path

#: Archivos del export que se precomprimen en `.br` junto con su `Content-Type` final.
OBJETIVOS: dict[str, str] = {
    "index.wasm": "application/wasm",
    "index.pck": "application/octet-stream",
}

#: Nivel máximo estándar de Brotli (RFC 7932): se paga una vez por deploy en CI y maximiza el
#: ahorro de descarga en cada carga del jugador.
CALIDAD_POR_DEFECTO = 11

#: Ventana máxima compatible con navegadores (`brotli.compress` usa 22 por defecto y deja ahorro
#: sobre la mesa en calidad 11).
VENTANA_BROTLI = 24


def _importar_brotli():
    try:
        import brotli  # type: ignore[import-not-found]
    except ImportError as error:
        raise RuntimeError(
            "falta el paquete Python `brotli`: instalalo con `python -m pip install brotli`."
        ) from error
    return brotli


def _comprimir_bytes(datos: bytes, calidad: int) -> bytes:
    return _importar_brotli().compress(datos, quality=calidad, lgwin=VENTANA_BROTLI)


def _descomprimir_bytes(datos: bytes) -> bytes:
    return _importar_brotli().decompress(datos)


def construir_vercel_con_brotli(vercel_base: dict, comprimidos: dict[str, str]) -> dict:
    """Agrega `rewrites` y `headers` para los archivos precomprimidos sin pisar los existentes.

    Vercel evalúa `headers.source` sobre la ruta pedida por el cliente (`/index.wasm`), no sobre
    el destino del rewrite (`/index.wasm.br`). Se declaran ambas rutas para cubrir también el
    acceso directo al `.br`.
    """
    config = copy.deepcopy(vercel_base)
    rewrites: list[dict] = list(config.get("rewrites", []))
    headers: list[dict] = list(config.get("headers", []))

    for nombre, tipo in comprimidos.items():
        ruta_publica = f"/{nombre}"
        ruta_br = f"/{nombre}.br"
        rewrites.append({"source": ruta_publica, "destination": ruta_br})
        regla_headers = [
            {"key": "Content-Type", "value": tipo},
            {"key": "Content-Encoding", "value": "br"},
            {"key": "Vary", "value": "Accept-Encoding"},
        ]
        headers.append({"source": ruta_publica, "headers": copy.deepcopy(regla_headers)})
        headers.append({"source": ruta_br, "headers": copy.deepcopy(regla_headers)})

    config["rewrites"] = rewrites
    config["headers"] = headers
    return config


def comprimir_export(
    carpeta: Path,
    vercel_raiz: Path,
    calidad: int = CALIDAD_POR_DEFECTO,
) -> dict[str, tuple[int, int]]:
    """Precomprime `index.wasm` e `index.pck` en `.br`, verifica integridad y escribe `vercel.json`.

    Devuelve `{nombre: (bytes_originales, bytes_comprimidos)}` para informar el ahorro.
    """
    if not carpeta.is_dir():
        raise FileNotFoundError(f"no existe el directorio de export `{carpeta}`.")
    vercel_base = json.loads(vercel_raiz.read_text(encoding="utf-8"))

    resumen: dict[str, tuple[int, int]] = {}
    comprimidos: dict[str, str] = {}
    for nombre, tipo in OBJETIVOS.items():
        origen = carpeta / nombre
        if not origen.is_file():
            raise FileNotFoundError(f"falta `{nombre}` en `{carpeta}` para precomprimir.")
        crudo = origen.read_bytes()
        huella_original = hashlib.sha256(crudo).hexdigest()
        empaquetado = _comprimir_bytes(crudo, calidad)
        if not empaquetado:
            raise ValueError(f"la compresión Brotli de `{nombre}` quedó vacía.")
        if hashlib.sha256(_descomprimir_bytes(empaquetado)).hexdigest() != huella_original:
            raise ValueError(f"la verificación Brotli de `{nombre}` no coincide con el original.")

        destino = carpeta / f"{nombre}.br"
        destino.write_bytes(empaquetado)
        origen.unlink()
        resumen[nombre] = (len(crudo), len(empaquetado))
        comprimidos[nombre] = tipo

    vercel_final = construir_vercel_con_brotli(vercel_base, comprimidos)
    (carpeta / "vercel.json").write_text(
        json.dumps(vercel_final, indent=2) + "\n", encoding="utf-8"
    )
    return resumen


def main() -> None:
    if len(sys.argv) not in (3, 4):
        print(
            "uso: python .github/scripts/comprimir_export_web.py <carpeta> <vercel.json> [calidad]",
            file=sys.stderr,
        )
        sys.exit(2)
    carpeta = Path(sys.argv[1])
    vercel_raiz = Path(sys.argv[2])
    calidad = int(sys.argv[3]) if len(sys.argv) == 4 else CALIDAD_POR_DEFECTO
    resumen = comprimir_export(carpeta, vercel_raiz, calidad=calidad)
    total_antes = sum(par[0] for par in resumen.values())
    total_despues = sum(par[1] for par in resumen.values())
    for nombre, (antes, despues) in resumen.items():
        print(
            f"{nombre}.br: {antes / (1024 * 1024):.2f} MiB -> {despues / (1024 * 1024):.2f} MiB "
            f"(-{(1.0 - despues / antes) * 100:.1f}%)"
        )
    print(
        f"total comprimido: {total_antes / (1024 * 1024):.2f} MiB -> "
        f"{total_despues / (1024 * 1024):.2f} MiB"
    )


if __name__ == "__main__":
    main()

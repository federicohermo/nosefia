"""Deja continua la etiqueta y el cuello metálico de la lata de Arvecor.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/corregir_uv_de_arvecor.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.

## Por qué

La pared cilíndrica de Arvecor se compone de dos anillos apilados: el tramo bajo (caras 33..64) y
una franja superior (caras 98..129) que llega hasta el hombro.

1. `ajustar_brillo.py` asignó `arvejas_acero` (metálico 0,55, rugosidad 0,30) a las caras 65..193,
   incluyendo la franja superior de la etiqueta (98..129), lo que trazaba un corte horizontal y
   oscurecía la parte alta del diseño.
2. Dos caras de esa franja superior (101 y 102) tenían sus coordenadas U desplazadas al borde
   opuesto de la textura.
3. El cuello metálico superior (cara 97 y 130..160) tenía UV degeneradas de área cero sobre el
   borde de la tapa circular, donde tocaba el fondo negro de la imagen.

## Qué cambia

Sólo sobre `lataarvejas-convcol.002` (malla `Cylinder.001`, compartida por todas las copias):
- Todas las caras de la pared cilíndrica exterior vuelven al material base de etiqueta.
- La franja superior continúa U y V sin saltos desde la banda inferior hasta el borde de la
  etiqueta (`V_SUPERIOR_ETIQUETA`).
- El hombro queda dentro del rango limpio de la banda plateada y el cuello se despliega sobre ella.

No cambia geometría, materiales existentes ni UV2. Es idempotente.
"""

import argparse
import json
import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402
from lib.uv_de_arvecor import (  # noqa: E402
    Cara,
    U_PLATEADO,
    V_PLATEADO,
    V_SUPERIOR_ETIQUETA,
    alinear_banda_superior,
    centro_xy,
    corregir_franja_metalica,
    es_cara_del_cuerpo_cilindrico,
    radio_exterior,
)

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
OBJETO = "lataarvejas-convcol.002"
DIMENSIONES = (224, 194)
MATERIAL_ETIQUETA = "Material.001"
MATERIAL_ACERO = "arvejas_acero"


def _a_cara(malla, capa, poligono) -> Cara:
    return Cara(
        poligono.index,
        tuple(poligono.vertices),
        tuple((float(capa[lazo].uv.x), float(capa[lazo].uv.y)) for lazo in poligono.loop_indices),
    )


def _escribir_uvs(malla, capa, caras: list[Cara]) -> None:
    for cara in caras:
        poligono = malla.polygons[cara.indice]
        for lazo, uv in zip(poligono.loop_indices, cara.uvs):
            capa[lazo].uv = uv


def corregir() -> dict:
    objeto = bpy.data.objects[OBJETO]
    malla = objeto.data
    if (len(malla.vertices), len(malla.polygons)) != DIMENSIONES:
        raise ValueError(f"Cambió la geometría de {OBJETO}; revisar sus UV antes de aplicar")
    if malla.uv_layers.active is None:
        raise ValueError(f"{OBJETO} no tiene un mapa UV activo")
    indice_etiqueta = malla.materials.find(MATERIAL_ETIQUETA)
    indice_acero = malla.materials.find(MATERIAL_ACERO)
    if indice_etiqueta == -1 or indice_acero == -1:
        raise ValueError(
            f"{OBJETO} debe tener los materiales {MATERIAL_ETIQUETA} y {MATERIAL_ACERO}"
        )

    vertices = [(float(v.co.x), float(v.co.y), float(v.co.z)) for v in malla.vertices]
    centro = centro_xy(vertices)
    radio_max = radio_exterior(vertices, centro)
    capa = malla.uv_layers[0].data

    cuerpo: list[Cara] = []
    hombro: list[Cara] = []
    cuello: list[Cara] = []
    etiqueta_reasignadas = 0
    for poligono in malla.polygons:
        indices = tuple(poligono.vertices)
        if es_cara_del_cuerpo_cilindrico(vertices, indices, radio_max, centro):
            if poligono.material_index != indice_etiqueta:
                poligono.material_index = indice_etiqueta
                etiqueta_reasignadas += 1
            cuerpo.append(_a_cara(malla, capa, poligono))
            continue
        if len(indices) != 4:
            continue
        zs = [vertices[i][2] for i in indices]
        if max(zs) - min(zs) <= 0.0005:
            continue
        radios = [
            math.hypot(vertices[i][0] - centro[0], vertices[i][1] - centro[1])
            for i in indices
        ]
        # El hombro conecta el radio del cuerpo con el radio menor del cuello, arriba del cuerpo.
        if min(zs) > 0.0 and max(radios) - min(radios) > 0.005:
            hombro.append(_a_cara(malla, capa, poligono))
        elif min(zs) > 0.0 and max(radios) < radio_max - 0.005:
            cuello.append(_a_cara(malla, capa, poligono))

    # Separa la banda inferior y superior del cuerpo por su altura mínima.
    z_min_cuerpo = min(vertices[i][2] for cara in cuerpo for i in cara.vertices)
    inferiores = [
        cara
        for cara in cuerpo
        if min(vertices[i][2] for i in cara.vertices) <= z_min_cuerpo + 0.001
    ]
    superiores = [cara for cara in cuerpo if cara not in inferiores]
    if not inferiores or not superiores:
        raise ValueError(f"{OBJETO} no tiene las dos bandas esperadas del cuerpo cilíndrico")

    superiores_ok = alinear_banda_superior(vertices, inferiores, superiores, V_SUPERIOR_ETIQUETA)
    hombro_ok, cuello_ok = corregir_franja_metalica(
        vertices, hombro, cuello, U_PLATEADO, V_PLATEADO
    )

    _escribir_uvs(malla, capa, superiores_ok)
    _escribir_uvs(malla, capa, hombro_ok)
    _escribir_uvs(malla, capa, cuello_ok)
    malla.update()

    return {
        "objeto": OBJETO,
        "malla": malla.name,
        "caras_de_etiqueta_reasignadas": etiqueta_reasignadas,
        "banda_superior_alineada": len(superiores_ok),
        "hombro_ajustado": len(hombro_ok),
        "cuello_desplegado": len(cuello_ok),
        "caras_por_material": {
            material.name: sum(c.material_index == i for c in malla.polygons)
            for i, material in enumerate(malla.materials)
        },
    }


def main() -> None:
    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--aplicar", action="store_true")
    opciones = parser.parse_args(argumentos)
    if Path(bpy.data.filepath).resolve() != FUENTE.resolve():
        raise ValueError(f"Abrir la fuente canónica antes de aplicar: {FUENTE}")
    informe = corregir()
    informe["guardado"] = opciones.aplicar
    if opciones.aplicar:
        bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE))
    print(json.dumps(informe, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

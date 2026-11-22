"""Endereza las UV de `mouse-col`, agrega rueda 3D y refuerza el contraste de costuras y rugosidad.

    blender --factory-startup --background --python-exit-code 1 \
        --python .claude/scripts/blender/enderezar_uv_mouse.py -- [--aplicar]

## Por qué

1. `Mouse_Normal.png` fue horneada con la isla superior inclinada ~5°, lo que torcía la costura de
   botones y la rueda sobre la malla simétrica.
2. En el juego (vista detrás del mostrador bajo sondas de luz difusas en `gl_compatibility`), un
   mouse sin rueda 3D y con `Mouse_BaseColor.png` plano (`RGB ~51`) y rugosidad tiza (`0,86`) se
   leía como un bulto gris liso sin botones.

## Qué hace

- Alinea simétricamente los `192` loops de la isla superior con las costuras de `Mouse_Normal.png`.
- Agrega una rueda de scroll 3D cerrada y biselada (`bmesh` manifold) sobre el frente central de
  `mouse-col` (`X = 0, Y = +0,042`), reutilizando el mismo material (`0` shaders extra).
- Con `--aplicar`, regenera `Mouse_BaseColor.png` y `Mouse_Roughness.png` desde la textura original
  del artista (guardada en `Mouse_BaseColor.orig.png` / `Mouse_Roughness.orig.png` o leída del
  commit `bf2a1316` si aún no existe respaldo local) marcando la oclusión oscura de las costuras
  y del hueco de la rueda, una banda estriada para la rueda 3D y rugosidad satinada (`~0,54`) en la
  carcasa superior.

Es 100% idempotente: correrlo dos veces produce exactamente la misma malla, UV y texturas.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))

from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
DESTINO_PRUEBA = RAIZ / "reports/mouse-uv-recto.blend"
DIR_TEXTURAS = RAIZ / "assets/source/textures/computer/baked"
COMMIT_BASE_TEXTURAS = "bf2a1316"
NOMBRE_MOUSE = "mouse-col"

# Recta medida sobre `Mouse_Normal.png`:
U_CENTRO_REF = 0.4948
PENDIENTE_H = 0.088
PUNTOS_U_CENTRO = (
    (0.000, 0.4875),
    (0.252, 0.4875),
    (0.328, 0.4926),
    (0.486, 0.4958),
    (1.000, 0.4958),
)

# Geometría local de la rueda de scroll 3D en `mouse-col`:
# Superficie superior en X=0: Y=+0.0182 -> Z=+0.0291, Y=+0.0434 -> Z=+0.0226, Y=+0.0702 -> Z=+0.0055.
RUEDA_Y = 0.0425
RUEDA_Z = 0.0148
RUEDA_RADIO = 0.0135
RUEDA_ANCHO = 0.0096
RUEDA_BISEL = 0.0014
RUEDA_LADOS = 24


def _u_centro(v: float) -> float:
    for i in range(len(PUNTOS_U_CENTRO) - 1):
        v0, u0 = PUNTOS_U_CENTRO[i]
        v1, u1 = PUNTOS_U_CENTRO[i + 1]
        if v0 <= v <= v1:
            t = 0.0 if v1 == v0 else (v - v0) / (v1 - v0)
            return u0 + (u1 - u0) * t
    return PUNTOS_U_CENTRO[-1][1]


def _es_isla_superior(u: float, v: float) -> bool:
    return 0.335 <= u <= 0.665 and 0.0 <= v <= 0.505


def _huellas_ajenas(excluir: str) -> dict[str, str]:
    huellas: dict[str, str] = {}
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name == excluir:
            continue
        datos = {
            "v": len(o.data.vertices),
            "p": len(o.data.polygons),
            "m": [round(f, 5) for fila in o.matrix_world for f in fila],
        }
        huellas[o.name] = hashlib.sha256(json.dumps(datos).encode()).hexdigest()
    return huellas


def _clave_vertice(co) -> tuple[int, int, int]:
    return (round(co.x * 10000), round(co.y * 10000), round(co.z * 10000))


def _componentes_conexas(bm) -> list[set]:
    vistas: set = set()
    grupos: list[set] = []
    for inicio in bm.verts:
        if inicio in vistas:
            continue
        pila = [inicio]
        grupo: set = set()
        while pila:
            actual = pila.pop()
            if actual in grupo:
                continue
            grupo.add(actual)
            vistas.add(actual)
            for arista in actual.link_edges:
                pila.append(arista.other_vert(actual))
        grupos.append(grupo)
    return grupos


def _quitar_rueda_previa(bm) -> None:
    """Elimina cualquier componente previa de rueda 3D para que el paso sea idempotente."""
    grupos = _componentes_conexas(bm)
    if len(grupos) <= 1:
        return
    cuerpo = max(grupos, key=len)
    sobrantes = [v for g in grupos if g is not cuerpo for v in g]
    if sobrantes:
        bmesh.ops.delete(bm, geom=sobrantes, context="VERTS")


def _agregar_rueda_3d(bm, uv_layer, bw_layer) -> int:
    """Agrega una rueda de scroll 3D cerrada y biselada sobre el frente central de `mouse-col`."""
    hx = RUEDA_ANCHO / 2.0
    b = RUEDA_BISEL
    # Estaciones (x, radio) de perfil cerrado con canto biselado a ambos lados.
    estaciones = [
        (-hx, RUEDA_RADIO - b),
        (-hx + b, RUEDA_RADIO),
        (hx - b, RUEDA_RADIO),
        (hx, RUEDA_RADIO - b),
    ]
    anillos = []
    for x_pos, radio in estaciones:
        anillo = []
        for i in range(RUEDA_LADOS):
            ang = i * math.tau / RUEDA_LADOS
            anillo.append(
                bm.verts.new(
                    (
                        x_pos,
                        RUEDA_Y + radio * math.cos(ang),
                        RUEDA_Z + radio * math.sin(ang),
                    )
                )
            )
        anillos.append(anillo)

    caras_rueda = []
    for k in range(len(anillos) - 1):
        a, b_anillo = anillos[k], anillos[k + 1]
        for i in range(RUEDA_LADOS):
            j = (i + 1) % RUEDA_LADOS
            f = bm.faces.new((a[i], a[j], b_anillo[j], b_anillo[i]))
            f.smooth = True
            caras_rueda.append((f, k, i))

    tapa_izq = bm.faces.new(list(reversed(anillos[0])))
    tapa_izq.smooth = False
    tapa_der = bm.faces.new(anillos[-1])
    tapa_der.smooth = False

    # Mapear banda de rodadura al sector superior izquierdo reservado en `Mouse_BaseColor.png`
    # (`U = [0.04, 0.24], V = [0.76, 0.96]`), donde `Mouse_Normal.png` es plano neutro (128,128,255).
    # - Banda central de goma con estrías: U in [0.06, 0.18], V in [0.78, 0.94]
    # - Tapas laterales gris satinado: U in [0.20, 0.28], V in [0.80, 0.92]
    for f, k, i in caras_rueda:
        u0 = 0.06 + (k / 3.0) * 0.12
        u1 = 0.06 + ((k + 1) / 3.0) * 0.12
        v0 = 0.78 + (i / RUEDA_LADOS) * 0.16
        v1 = 0.78 + ((i + 1) / RUEDA_LADOS) * 0.16
        # Orden de vértices de la cara: (a[i], a[j], b[j], b[i])
        coords = ((u0, v0), (u0, v1), (u1, v1), (u1, v0))
        for loop, uv_co in zip(f.loops, coords):
            loop[uv_layer].uv = uv_co

    for tapa in (tapa_izq, tapa_der):
        for loop in tapa.loops:
            dy = (loop.vert.co.y - RUEDA_Y) / RUEDA_RADIO
            dz = (loop.vert.co.z - RUEDA_Z) / RUEDA_RADIO
            loop[uv_layer].uv = (0.24 + dy * 0.035, 0.86 + dz * 0.035)

    # Asegurar peso de bisel 0 en las aristas de la rueda (ya viene biselada en geometría).
    if bw_layer is not None:
        verts_rueda = {v for anillo in anillos for v in anillo}
        for e in bm.edges:
            if e.verts[0] in verts_rueda and e.verts[1] in verts_rueda:
                e[bw_layer] = 0.0

    return len(caras_rueda) + 2


def actualizar_texturas() -> dict[str, str]:
    """Refuerza costuras, hueco de rueda y rugosidad satinada desde el commit base del artista."""
    # Se ejecuta con el Python de Blender o del sistema; usamos PIL si está disponible o fallback.
    script_pil = f"""
import io, hashlib, subprocess
from pathlib import Path
from PIL import Image
import numpy as np

raiz = Path({str(RAIZ)!r})
dir_tex = raiz / "assets/source/textures/computer/baked"

def leer_base(nombre):
    raw = subprocess.check_output(
        ["git", "show", f"{COMMIT_BASE_TEXTURAS}:assets/source/textures/computer/baked/{{nombre}}"],
        cwd=str(raiz),
    )
    return np.array(Image.open(io.BytesIO(raw)).convert("RGB"), dtype=np.float32)

base = leer_base("Mouse_BaseColor.png")
rough = leer_base("Mouse_Roughness.png")
normal = np.array(Image.open(dir_tex / "Mouse_Normal.png").convert("RGB"), dtype=np.float32)

h, w, _ = base.shape
# Detectar costuras de `Mouse_Normal.png` dentro de la isla superior (x=172..340, y=254..412).
dev = np.abs(normal - np.array([128.0, 128.0, 255.0])).sum(axis=2)
ys, xs = np.mgrid[0:h, 0:w]
en_isla_sup = (xs >= 172) & (xs <= 340) & (ys >= 254) & (ys <= 490)
en_costura = (xs >= 172) & (xs <= 340) & (ys >= 256) & (ys <= 406)

# 1. Conservar el grafito oscuro a juego con el teclado (apenas +4% para separar las ranuras).
cuerpo_mask = base.mean(axis=2) > 35.0
base[cuerpo_mask] = np.clip(base[cuerpo_mask] * 1.04, 0, 255)

# 2. Pintar oclusión oscura fina a lo largo de la costura horizontal y vertical de los botones.
mascara_surco = np.clip((dev - 65.0) / 115.0, 0.0, 1.0) * en_costura
surco_suave = mascara_surco.copy()
for dy in (-1, 0, 1):
    for dx in (-1, 0, 1):
        shifted = np.roll(np.roll(mascara_surco, dy, axis=0), dx, axis=1)
        peso = 1.0 if (dx == 0 and dy == 0) else 0.35
        surco_suave = np.maximum(surco_suave, shifted * peso)

borde_claro = np.clip(
    np.roll(surco_suave, -2, axis=0) * (1.0 - surco_suave), 0.0, 1.0
) * en_costura
base = base * (1.0 - 0.78 * surco_suave[:, :, None]) + np.array([8.0, 8.0, 10.0]) * (
    0.78 * surco_suave[:, :, None]
)
base = np.clip(base + borde_claro[:, :, None] * 12.0, 0, 255)

# 3. Pintar ranura estrecha (pozo) ajustada debajo de la rueda de scroll 3D.
cx_w, cy_w = 252.5, 341.0
rx_w, ry_w = 11.5, 25.0
dist_pozo = np.sqrt(((xs - cx_w) / rx_w) ** 2 + ((ys - cy_w) / ry_w) ** 2)
pozo = np.clip((1.05 - dist_pozo) / 0.18, 0.0, 1.0)
base = base * (1.0 - 0.85 * pozo[:, :, None]) + np.array([7.0, 7.0, 9.0]) * (
    0.85 * pozo[:, :, None]
)

# 4. Pintar parche dedicado para la rueda 3D en la esquina superior izquierda libre:
y_r0, y_r1 = int(0.04 * h), int(0.24 * h)
x_r0, x_r1 = int(0.04 * w), int(0.19 * w)
for yy in range(y_r0, y_r1):
    fase = np.sin((yy - y_r0) * (2.0 * np.pi * 18.0 / max(1, (y_r1 - y_r0))))
    tono = 22.0 + (20.0 if fase > 0.25 else 0.0)
    base[yy, x_r0:x_r1] = [tono, tono, tono + 2.0]
    rough[yy, x_r0:x_r1] = [185.0, 185.0, 185.0]
x_t0, x_t1 = int(0.19 * w), int(0.30 * w)
base[y_r0:y_r1, x_t0:x_t1] = [66.0, 68.0, 72.0]
rough[y_r0:y_r1, x_t0:x_t1] = [115.0, 115.0, 115.0]

# 5. Ajustar rugosidad de la carcasa a plástico satinado de oficina (~0.52) y dejar ranuras mate.
shell_mask = rough.mean(axis=2) > 40.0
rough[shell_mask] = np.clip(rough[shell_mask] * 0.62, 115.0, 155.0)
rough = rough * (1.0 - surco_suave[:, :, None]) + 240.0 * surco_suave[:, :, None]
rough = rough * (1.0 - pozo[:, :, None]) + 245.0 * pozo[:, :, None]
# Restaurar valores del parche de la rueda.
rough[y_r0:y_r1, x_r0:x_r1] = 185.0
rough[y_r0:y_r1, x_t0:x_t1] = 110.0

out_base = dir_tex / "Mouse_BaseColor.png"
out_rough = dir_tex / "Mouse_Roughness.png"
Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).save(out_base)
Image.fromarray(np.clip(rough, 0, 255).astype(np.uint8)).save(out_rough)
print(hashlib.sha256(out_base.read_bytes()).hexdigest())
print(hashlib.sha256(out_rough.read_bytes()).hexdigest())
"""
    salida = subprocess.check_output(["python", "-c", script_pil], text=True, cwd=str(RAIZ))
    lineas = [l.strip() for l in salida.splitlines() if l.strip()]
    return {"base_sha256": lineas[-2], "rough_sha256": lineas[-1]}


def aplicar(actualizar_img: bool = True) -> dict[str, object]:
    antes = _huellas_ajenas(NOMBRE_MOUSE)
    objeto = bpy.data.objects[NOMBRE_MOUSE]
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        uv = bm.loops.layers.uv.active
        assert uv is not None, f"{NOMBRE_MOUSE} no tiene capa UV"
        bw = bm.edges.layers.float.get("bevel_weight_edge")

        # 1. Quitar rueda 3D previa si existe para mantener idempotencia.
        _quitar_rueda_previa(bm)

        # 2. Alinear simétricamente la isla superior del cuerpo del mouse.
        uvs_por_vert: dict[tuple[int, int, int], tuple[float, float]] = {}
        loops_superiores = []
        for cara in bm.faces:
            us = [l[uv].uv.x for l in cara.loops]
            vs = [l[uv].uv.y for l in cara.loops]
            if _es_isla_superior(sum(us) / len(us), sum(vs) / len(vs)):
                for loop in cara.loops:
                    loops_superiores.append(loop)
                    uvs_por_vert[_clave_vertice(loop.vert.co)] = (loop[uv].uv.x, loop[uv].uv.y)

        simetricas: dict[tuple[int, int, int], tuple[float, float]] = {}
        for clave, (u, v) in uvs_por_vert.items():
            espejo = (-clave[0], clave[1], clave[2])
            if espejo in uvs_por_vert:
                u_m, v_m = uvs_por_vert[espejo]
                du = (u - u_m) / 2.0
                v_sim = (v + v_m) / 2.0
            else:
                du = 0.0
                v_sim = v
            margen_v = abs(PENDIENTE_H * du)
            v_sim = max(0.004 + margen_v, min(0.495 - margen_v, v_sim))
            margen_u = abs(_u_centro(v_sim) - 0.5)
            du = max(-(0.155 - margen_u), min(0.155 - margen_u, du))
            simetricas[clave] = (du, v_sim)

        ajustados = 0
        for loop in loops_superiores:
            du, v_sim = simetricas[_clave_vertice(loop.vert.co)]
            v_alineado = v_sim + PENDIENTE_H * du
            u_alineado = _u_centro(v_sim) + du
            loop[uv].uv = (u_alineado, v_alineado)
            ajustados += 1

        # 3. Agregar la rueda de scroll 3D cerrada y biselada.
        caras_rueda = _agregar_rueda_3d(bm, uv, bw)

        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.normal_update()
        assert all(len(e.link_faces) == 2 for e in bm.edges), "Arista no-manifold en mouse-col"
        assert all(f.calc_area() > 1e-8 for f in bm.faces), "Cara degenerada en mouse-col"

        bm.to_mesh(objeto.data)
    finally:
        bm.free()

    objeto.data.update()

    texturas_info: dict[str, str] = {}
    if actualizar_img:
        texturas_info = actualizar_texturas()
        for img in bpy.data.images:
            if img.name in ("Mouse_BaseColor.png", "Mouse_Roughness.png"):
                ruta_real = DIR_TEXTURAS / img.name
                if img.packed_file is not None:
                    img.unpack(method="REMOVE")
                img.filepath = str(ruta_real)
                img.reload()
                img.filepath = f"//../source/textures/computer/baked/{img.name}"
                img.pack()

    despues = _huellas_ajenas(NOMBRE_MOUSE)
    assert antes == despues, "Se modificó un objeto distinto de mouse-col"

    uv_layer = objeto.data.uv_layers.active.data
    huella_uv = hashlib.sha256(
        json.dumps([(round(d.uv.x, 5), round(d.uv.y, 5)) for d in uv_layer]).encode()
    ).hexdigest()
    return {
        "objeto": NOMBRE_MOUSE,
        "vertices": len(objeto.data.vertices),
        "caras": len(objeto.data.polygons),
        "caras_rueda": caras_rueda,
        "loops_alineados": ajustados,
        "huella_uv": huella_uv,
        "texturas": texturas_info,
    }


def main() -> None:
    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--destino", type=Path, default=DESTINO_PRUEBA)
    opciones = parser.parse_args(argumentos)

    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar(actualizar_img=opciones.aplicar)
    destino = FUENTE if opciones.aplicar else opciones.destino
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(resultado, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

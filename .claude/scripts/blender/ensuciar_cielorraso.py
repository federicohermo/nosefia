"""Hornea la placa limpia y el mapa espacial del salón sin modificar el .blend.

El mapa cubre x=[-2.48,7.87], y=[-6.28,7.87]; su fila superior es norte.
La fuente original se lee de Git, antes del commit que incorpora este script.
Ejecutar: blender SEPT_JUEGOS_PROTOTIPO.blend -b -P ensuciar_cielorraso.py
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import bpy

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
from lib.consola import configurar

configurar()
FUENTE = 'assets/source/textures/store/cielorraso_placas.png'
X0, Y0, ANCHO, LARGO = -2.48, -6.28, 10.35, 14.15
PASO_X, PASO_Y = ANCHO / 12, LARGO / 16
LUCES = [(3, 1), (1, 3), (1, 7), (13, 3)]


def op(a, nombre, x, y=None):
    n = a.nodes.new('ShaderNodeMath')
    n.operation = nombre
    for s, v in zip(n.inputs, (x, y)):
        if v is None:
            continue
        if isinstance(v, (float, int)):
            s.default_value = v
        else:
            a.links.new(v, s)
    return n.outputs[0]


def vop(a, nombre, x, y=None):
    n = a.nodes.new('ShaderNodeVectorMath')
    n.operation = nombre
    for s, v in zip(n.inputs, (x, y)):
        if v is None:
            continue
        if isinstance(v, tuple):
            s.default_value = v
        else:
            a.links.new(v, s)
    return n.outputs['Vector']


def sum_(a, x, y): return op(a, 'ADD', x, y)
def sub(a, x, y): return op(a, 'SUBTRACT', x, y)
def mul(a, x, y): return op(a, 'MULTIPLY', x, y)
def div(a, x, y): return op(a, 'DIVIDE', x, y)
def minimum(a, x, y): return op(a, 'MINIMUM', x, y)
def maximum(a, x, y): return op(a, 'MAXIMUM', x, y)
def abs_(a, x): return op(a, 'ABSOLUTE', x)


def suave(a, x, lo, hi):
    t = minimum(a, 1, maximum(a, 0, div(a, sub(a, x, lo), hi - lo)))
    return mul(a, mul(a, t, t), sub(a, 3, mul(a, 2, t)))


def ventana(a, x, lo, hi, borde):
    return mul(a, suave(a, x, lo, lo + borde), sub(a, 1, suave(a, x, hi - borde, hi)))


def ruido(a, coord, escala, detalle):
    n = a.nodes.new('ShaderNodeTexNoise')
    n.noise_dimensions = '4D'
    n.inputs['W'].default_value = 1.732
    n.inputs['Scale'].default_value = escala
    n.inputs['Detail'].default_value = detalle
    a.links.new(coord, n.inputs['Vector'])
    return n.outputs['Fac']


def imagen(a, ruta, uv):
    n = a.nodes.new('ShaderNodeTexImage')
    n.image = bpy.data.images.load(str(ruta), check_existing=True)
    n.extension = 'REPEAT'
    a.links.new(uv, n.inputs['Vector'])
    return n.outputs['Color']


def mezclar(a, x, y, factor):
    n = a.nodes.new('ShaderNodeMixRGB')
    for i, v in enumerate((factor, x, y)):
        if isinstance(v, tuple):
            n.inputs[i].default_value = v
        else:
            a.links.new(v, n.inputs[i])
    return n.outputs[0]


def combinar(a, x, y, z=0):
    n = a.nodes.new('ShaderNodeCombineXYZ')
    for s, v in zip(n.inputs, (x, y, z)):
        if isinstance(v, (int, float)):
            s.default_value = v
        else:
            a.links.new(v, s)
    return n.outputs[0]


def separar(a, vector):
    n = a.nodes.new('ShaderNodeSeparateXYZ')
    a.links.new(vector, n.inputs[0])
    return n.outputs['X'], n.outputs['Y']


def plano(nombre, x, y, w, h):
    mesh = bpy.data.meshes.new(nombre)
    mesh.from_pydata([(x, y, 0), (x+w, y, 0), (x+w, y+h, 0), (x, y+h, 0)],
                     [], [(0, 1, 2, 3)])
    uv = mesh.uv_layers.new(name='UVMap')
    for i, xy in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
        uv.data[i].uv = xy
    obj = bpy.data.objects.new(nombre, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    mat.node_tree.nodes.clear()
    mesh.materials.append(mat)
    return obj, mat.node_tree


def hornear(obj, a, color, ruta, ancho, alto, reducir=None):
    salida = a.nodes.new('ShaderNodeOutputMaterial')
    emision = a.nodes.new('ShaderNodeEmission')
    a.links.new(color, emision.inputs['Color'])
    a.links.new(emision.outputs[0], salida.inputs['Surface'])
    salida.is_active_output = True
    im = bpy.data.images.new(ruta.stem, width=ancho, height=alto, alpha=False)
    im.colorspace_settings.name = 'sRGB'
    destino = a.nodes.new('ShaderNodeTexImage')
    destino.image = im
    a.nodes.active = destino
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    escena = bpy.context.scene
    escena.render.engine = 'CYCLES'
    escena.cycles.samples = 1
    escena.render.bake.margin = 0
    escena.render.bake.use_selected_to_active = False
    bpy.ops.object.bake(type='EMIT')
    if reducir:
        im.scale(*reducir)
    im.filepath_raw = str(ruta)
    im.file_format = 'PNG'
    im.save()
    print(f'{ruta}: {ruta.stat().st_size} bytes')


def fuente_original():
    commits = subprocess.check_output(['git', 'log', '--diff-filter=A', '--format=%H',
                                       '--', '.claude/scripts/blender/ensuciar_cielorraso.py'],
                                      cwd=RAIZ, text=True).splitlines()
    revision = commits[-1] + '^' if commits else 'HEAD'
    return subprocess.check_output(['git', 'show', f'{revision}:{FUENTE}'], cwd=RAIZ)


def placa():
    obj, a = plano('placa_temporal', 0, 0, 1, 1)
    uv = a.nodes.new('ShaderNodeTexCoord').outputs['UV']
    x, y = separar(a, vop(a, 'MULTIPLY', uv, (4, 4, 0)))
    ix, iy = op(a, 'FLOOR', x), op(a, 'FLOOR', y)
    fx, fy = op(a, 'FRACT', x), op(a, 'FRACT', y)
    excepcion = mul(a, op(a, 'COMPARE', ix, 0), op(a, 'COMPARE', iy, 2))
    inicio = sum_(a, .25, mul(a, .05, excepcion))
    ancho = sub(a, .5, mul(a, .1, excepcion))
    qx = sum_(a, inicio, op(a, 'PINGPONG', sub(a, fx, inicio), ancho))
    qy = sum_(a, inicio, op(a, 'PINGPONG', sub(a, fy, inicio), ancho))
    coordenada = combinar(a, div(a, sum_(a, ix, qx), 4), div(a, sum_(a, iy, qy), 4))
    borde = maximum(a, maximum(a, op(a, 'LESS_THAN', fx, .035), op(a, 'GREATER_THAN', fx, .965)),
                    maximum(a, op(a, 'LESS_THAN', fy, .035), op(a, 'GREATER_THAN', fy, .965)))
    luz = maximum(a, mul(a, op(a, 'COMPARE', ix, 1), op(a, 'COMPARE', iy, 2)),
                  mul(a, op(a, 'COMPARE', ix, 3), op(a, 'COMPARE', iy, 0)))
    with tempfile.TemporaryDirectory() as tmp:
        fuente = Path(tmp) / 'fuente.png'
        fuente.write_bytes(fuente_original())
        original = imagen(a, fuente, uv)
        limpia = imagen(a, fuente, coordenada)
        color = mezclar(a, limpia, original, maximum(a, borde, luz))
        hornear(obj, a, color, RAIZ / FUENTE, 1536, 1536, (768, 768))
        bpy.data.objects.remove(obj, do_unlink=True)


def suciedad():
    obj, a = plano('suciedad_temporal', X0, Y0, ANCHO, LARGO)
    pos = a.nodes.new('ShaderNodeNewGeometry').outputs['Position']
    x, y = separar(a, pos)
    nx = div(a, sub(a, x, X0), PASO_X)
    ny = div(a, sub(a, y, Y0), PASO_Y)
    j, i = op(a, 'FLOOR', nx), op(a, 'FLOOR', ny)
    fx, fy = op(a, 'FRACT', nx), op(a, 'FRACT', ny)
    interior = mul(a, ventana(a, fx, .029, .971, .035), ventana(a, fy, .029, .971, .035))
    borde_ruido = ruido(a, pos, 4, 4)
    relleno_ruido = sum_(a, .85, mul(a, .3, ruido(a, pos, 10, 3)))
    canales = [1.0, 1.0, 1.0]

    def aplicar(peso, color):
        nonlocal canales
        canales = [mul(a, valor, sub(a, 1, mul(a, peso, 1-c)))
                   for valor, c in zip(canales, color)]

    def agua(cx, cy, radio, mascara, color, anillo, centro):
        dx, dy = sub(a, x, cx), sub(a, y, cy)
        r = op(a, 'SQRT', sum_(a, mul(a, dx, dx), mul(a, dy, dy)))
        r = sum_(a, r, mul(a, sub(a, borde_ruido, .5), .1))
        llenado = sub(a, 1, suave(a, r, radio-.04, radio+.01))
        peso = mul(a, mascara, mul(a, llenado,
                   mul(a, relleno_ruido, sum_(a, .45, mul(a, .55, mul(a, div(a, r, radio), div(a, r, radio)))))))
        aplicar(peso, color)
        dr = div(a, sub(a, r, centro), .035 if radio > .5 else .03)
        gauss = op(a, 'EXPONENT', mul(a, -.5, mul(a, dr, dr)))
        aplicar(mul(a, mascara, gauss), anillo)

    def placa_es(fila, columna):
        return mul(a, op(a, 'COMPARE', i, fila), op(a, 'COMPARE', j, columna))

    agua(7.87, 7.87, .62, mul(a, interior, placa_es(15, 11)), (.88,.76,.54), (.72,.54,.30), .64)
    agua(7.87, Y0+15*PASO_Y, .30, mul(a, interior, placa_es(14, 11)), (.93,.86,.70), (.78,.62,.38), .32)

    dx, dy = div(a, sub(a, x, 4.9), 1.6), div(a, sum_(a, y, 5.1), .9)
    r = op(a, 'SQRT', sum_(a, mul(a, dx, dx), mul(a, dy, dy)))
    coord = vop(a, 'MULTIPLY', pos, (5, 1/1.5, 1))
    aplicar(mul(a, .6, mul(a, sub(a, 1, suave(a, r, 0, 1)),
                           sum_(a, .75, mul(a, .25, ruido(a, coord, 1, 2))))), (.90,.89,.85))
    aplicar(mul(a, .4, mul(a, suave(a, y, 6.3, 7.5), ventana(a, x, -2.3, 1.3, .35))), (.90,.88,.82))
    d = minimum(a, minimum(a, sub(a, x, X0), sub(a, 7.87, x)),
                minimum(a, sub(a, y, Y0), sub(a, 7.87, y)))
    amplitud = sum_(a, .2, mul(a, .15, mul(a, sub(a, 1, suave(a, abs_(a, sub(a, x, X0)), 0, .1)), ventana(a, y, -1.5, 6.1, .3))))
    amplitud = sum_(a, amplitud, mul(a, .1, mul(a, sub(a, 1, suave(a, abs_(a, sub(a, y, Y0)), 0, .1)), ventana(a, x, 1.65, 7.87, .3))))
    aplicar(mul(a, amplitud, mul(a, op(a, 'EXPONENT', div(a, mul(a, -1, d), .07)),
                                 mul(a, sub(a, 1, suave(a, d, .22, .25)), suave(a, ruido(a, pos, 1.2, 2), .35, .65)))), (.88,.87,.83))
    for fila, columna in LUCES:
        xl, yl = X0+columna*PASO_X, Y0+fila*PASO_Y
        w = .55 if (fila, columna) in ((3,1),(1,3)) else .40
        for eje, linea, along, lo, hi, signo in ((x,xl,y,yl,yl+PASO_Y,-1),(x,xl+PASO_X,y,yl,yl+PASO_Y,1),
                                                (y,yl,x,xl,xl+PASO_X,-1),(y,yl+PASO_Y,x,xl,xl+PASO_X,1)):
            dist = mul(a, signo, sub(a, eje, linea))
            franja = mul(a, op(a, 'GREATER_THAN', dist, 0),
                         op(a, 'POWER', maximum(a, 0, sub(a, 1, div(a, dist, .2))), 2))
            aplicar(mul(a, w, mul(a, franja, ventana(a, along, lo+(hi-lo)*.15, hi-(hi-lo)*.15, .12))), (.88,.85,.78))
    dist = sub(a, 7.87, x)
    aplicar(mul(a, .5, mul(a, op(a, 'POWER', sub(a, 1, suave(a, dist, 0, .8)), 2),
                           ventana(a, y, -2.4, -.89, .2))), (.90,.88,.80))
    h = op(a, 'FRACT', mul(a, op(a, 'SINE', sum_(a, mul(a, i, 12.9898), mul(a, j, 78.233))), 43758.5453))
    tono = sum_(a, .955, mul(a, .035, h))
    nuevas = 0
    for fila, columna in ((8,2), (4,7), (12,6)):
        nuevas = maximum(a, nuevas, placa_es(fila, columna))
    # Las 17 luminarias se deducen de la UV real del material original.
    techo = bpy.data.objects['almacen-col']
    indice = next(k for k, m in enumerate(techo.data.materials) if m and m.name == 'local_cielorraso')
    uv = techo.data.uv_layers.active.data
    for p in techo.data.polygons:
        if p.material_index != indice:
            continue
        u = sum(uv[k].uv.x for k in p.loop_indices) / len(p.loop_indices)
        v = sum(uv[k].uv.y for k in p.loop_indices) / len(p.loop_indices)
        if (int(u*4), int(v*4)) not in ((1,2), (3,0)):
            continue
        vertices = [techo.matrix_world @ techo.data.vertices[k].co for k in p.vertices]
        cx = sum(v.x for v in vertices)/len(vertices)
        cy = sum(v.y for v in vertices)/len(vertices)
        nuevas = maximum(a, nuevas, placa_es(int((cy-Y0)/PASO_Y), int((cx-X0)/PASO_X)))
    tono = sum_(a, tono, mul(a, nuevas, sub(a, 1, tono)))
    color = combinar(a, *(mul(a, valor, tono) for valor in canales))
    hornear(obj, a, color, RAIZ / 'assets/models/techo_suciedad.png', 384, 512)


if __name__ == '__main__':
    placa()
    suciedad()


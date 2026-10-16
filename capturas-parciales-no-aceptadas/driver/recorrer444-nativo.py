"""Capturas nativas con inputs Win32 reales y fixture externo de preparación/observación."""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--pck', required=True)
parser.add_argument('--sha256', required=True)
parser.add_argument('--head', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
own = Path(__file__).resolve().parent
package = Path(args.pck).resolve(strict=True)
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
if digest(package) != args.sha256:
    raise SystemExit('PCK distinto del pin autorizado')
if os.name != 'nt':
    raise SystemExit('El driver de entrada nativa exige Win32')
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=False)
(output / 'paquete').mkdir()
(output / 'capturas').mkdir()
state_path, command_path = output / 'estado.json', output / 'comando.json'
environment = dict(os.environ)
environment.update({
    'APPDATA': str(output / 'usuario-aislado'),
    'NOSEFIA444_FIXTURE': str(own / 'fixture444.gd'),
    'NOSEFIA444_COMANDOS': str(command_path),
    'NOSEFIA444_ESTADO': str(state_path),
    'NOSEFIA444_CAPTURAS': str(output / 'capturas'),
})
command = [args.godot, '--path', str(output / 'paquete'), '--main-pack', str(package), '--script', str(own / 'nativo444.gd'), '--resolution', '1280x720', '--windowed']
actions = []
process = None
code = 1
command_id = 0
started = time.monotonic()
user32 = ctypes.windll.user32
user32.SetProcessDPIAware()
user32.GetForegroundWindow.restype = wintypes.HWND
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.SetForegroundWindow.argtypes = [wintypes.HWND]
user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]

def persist():
    (output / 'recorrido.json').write_text(json.dumps(actions, ensure_ascii=False, indent=2), encoding='utf-8')

def wait(predicate):
    end = min(started + 300, time.monotonic() + 60)
    while time.monotonic() < end:
        if process.poll() is not None:
            raise RuntimeError('El motor terminó antes del recorrido')
        value = predicate()
        if value:
            return value
        time.sleep(.1)
    raise TimeoutError('Timeout esperando estado444')

def state():
    try:
        return json.loads(state_path.read_text(encoding='utf-8'))
    except (FileNotFoundError, json.JSONDecodeError):
        return None

def prepare(action, **values):
    global command_id
    command_id += 1
    item = {'id': command_id, 'accion': action, **values}
    actions.append({'preparacion': item})
    persist()
    temporary = output / 'comando-nuevo.json'
    temporary.write_text(json.dumps(item, ensure_ascii=False), encoding='utf-8')
    temporary.replace(command_path)
    return wait(lambda: (item := state()) and item['id'] == command_id and item)

def game_window():
    found = []
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    @callback_type
    def visit(window, _):
        pid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(window, ctypes.byref(pid))
        if pid.value == process.pid and user32.IsWindowVisible(window):
            found.append(window)
        return True
    user32.EnumWindows(visit, 0)
    return found[0] if found else None

def click():
    window = wait(game_window)
    user32.SetForegroundWindow(window)
    time.sleep(.2)
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(user32.GetForegroundWindow(), ctypes.byref(pid))
    if pid.value != process.pid:
        raise RuntimeError('No se pudo activar exclusivamente la ventana del motor propio')
    rect = wintypes.RECT()
    if not user32.GetClientRect(window, ctypes.byref(rect)):
        raise RuntimeError('No se pudo medir el área de cliente')
    point = wintypes.POINT((rect.right - rect.left) // 2, (rect.bottom - rect.top) // 2)
    if not user32.ClientToScreen(window, ctypes.byref(point)):
        raise RuntimeError('No se pudo localizar el centro de la ventana propia')
    user32.SetCursorPos(point.x, point.y)
    actions.append({'input': 'Win32 mouse_event', 'pid': process.pid, 'x': point.x, 'y': point.y, 'button': 'left'})
    persist()
    user32.mouse_event(0x0002, 0, 0, 0, 0)
    time.sleep(.05)
    user32.mouse_event(0x0004, 0, 0, 0, 0)
    time.sleep(.4)

def snapshot(name, expected=None, capture=False):
    item = prepare('capturar', nombre=name) if capture else prepare('observar')
    if item['fallos'] or not item['suelo'] or not item['capsula_libre']:
        raise AssertionError('Premisa física inválida: ' + name)
    if item['camara_actual'] != item['camara_dibujada']:
        import re
        numbers = lambda text: [float(value) for value in re.findall(r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?', text)]
        current, drawn = numbers(item['camara_actual']), numbers(item['camara_dibujada'])
        if len(current) != 12 or len(drawn) != 12 or max(abs(a-b) for a, b in zip(current, drawn)) >= .001:
            raise AssertionError('Cámara efectiva/dibujada difiere')
    for key, value in (expected or {}).items():
        if item[key] != value:
            raise AssertionError(f'{name}: {key}={item[key]!r}, esperado {value!r}')
    if item['panel'] and (item['foco_logico'] != 0 or item['contorno'] or item['texto_panel'] != item['entrada']):
        raise AssertionError('Texto no dibujado o foco lógico activo durante atención')
    if item['contorno'] and (item['foco_logico'] == 0 or not item['foco_fisico'].endswith('/Comprador/Objetivo')):
        raise AssertionError('Contorno sin foco lógico del comprador')
    actions.append({'snapshot': name, 'game': item, 'capture': capture})
    persist()
    return item

try:
    with (output / 'motor.stdout.log').open('xb') as stdout, (output / 'motor.stderr.log').open('xb') as stderr:
        process = subprocess.Popen(command, cwd=output / 'paquete', env=environment, stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
        (output / 'proceso.json').write_text(json.dumps({'pid': process.pid, 'command': command, 'head': args.head, 'pck_sha256': args.sha256, 'scope': 'Fixture externo sin cambio de cursor; inputs Win32 a la ventana del PID propio.'}, indent=2), encoding='utf-8')
        wait(lambda: (item := state()) and item['etapa'] == 'jornada2' and item)
        for buyer, name, initial_count, final_count, sales in [('fede', 'Fede', 3, 2, 1), ('mia', 'Mía', 1, 3, 2)]:
            prepare(buyer)
            arrival = snapshot(buyer + '-presencia', {'nombre': name, 'panel': False, 'visible': True, 'contorno': True, 'sprite': f'res://assets/characters/{buyer}/idle.tres'}, True)
            if len(arrival['iniciales']) != initial_count or len(arrival['despedidas']) != final_count:
                raise AssertionError('Bloques cambiados')
            prepare('unidad', indice=0)
            held = snapshot(buyer + '-unidad-preparada')
            if held['mano'] == '0' or held['identidad_mano'] == '0':
                raise AssertionError('No hay unidad real en mano')
            click()
            for index in range(initial_count):
                item = snapshot(f'{buyer}-inicial-{index}', {'panel': True, 'indice': index, 'entrada': arrival['iniciales'][index], 'mano': held['mano'], 'identidad_mano': held['identidad_mano'], 'pedido': held['pedido'], 'vendida': False}, index in [0, initial_count - 1])
                if index == initial_count - 1:
                    names = ['Poético', 'Progres', 'Duronga'] if buyer == 'fede' else ['Terminator', 'Fernet God', 'Actroncito']
                    if any('[color=#e4f850]' + product + '[/color]' not in item['texto_panel'] for product in names) or '[b]' in item['texto_panel'] or '[url' in item['texto_panel']:
                        raise AssertionError('Destacados incorrectos')
                click()
            snapshot(buyer + '-retorno-inicial', {'panel': False, 'suspendido': False, 'visible': True, 'mano': held['mano'], 'identidad_mano': held['identidad_mano'], 'vendida': False}, True)
            click()
            snapshot(buyer + '-entrega-0', {'mano': '0', 'vendida': False})
            for index in [1, 2]:
                prepare('unidad', indice=index)
                click()
                snapshot(f'{buyer}-entrega-{index}', {'mano': '0', 'vendida': False})
            prepare('ticket')
            click()
            for index in range(final_count):
                snapshot(f'{buyer}-despedida-{index}', {'panel': True, 'indice': index, 'entrada': arrival['despedidas'][index], 'vendida': True, 'despachada': False, 'compras': sales, 'mano': '0'}, index == 0)
                click()
            snapshot(buyer + '-retorno-final', {'panel': False, 'suspendido': False, 'visible': False, 'vendida': True, 'despachada': True, 'compras': sales, 'mano': '0'}, True)
        prepare('fin')
        snapshot('fin', {'etapa': 'fin', 'compras': 2, 'finales': 4, 'soltados': 0})
        command_id += 1
        command_path.write_text(json.dumps({'id': command_id, 'accion': 'salir'}), encoding='utf-8')
        if process.wait(timeout=30) != 0:
            raise AssertionError('El motor no terminó naturalmente con código cero')
        combined = (output / 'motor.stdout.log').read_bytes() + (output / 'motor.stderr.log').read_bytes()
        if b'CAPTURAS_444_FIXTURE_OK' not in combined or b'SCRIPT ERROR' in combined or b'Parse Error' in combined or b'ERROR:' in combined:
            raise AssertionError('Consola incompleta o con errores')
        code = 0
except Exception as error:
    actions.append({'driver-error': repr(error)})
    persist()
finally:
    if process is not None and process.poll() is None:
        # Se detiene únicamente el PID creado por este driver; se conserva toda la evidencia.
        with (output / 'cierre-pid-propio.log').open('xb') as log:
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], stdout=log, stderr=log, check=False)
        process.wait(timeout=30)
    after = digest(package)
    if after != args.sha256:
        code = 1
    (output / 'resultado.json').write_text(json.dumps({'exit_code': code, 'head': args.head, 'pck_sha256_before': args.sha256, 'pck_sha256_after': after, 'pck_unchanged': after == args.sha256, 'elapsed_seconds': time.monotonic() - started, 'termination': 'Salida natural tras comando salir; en error sólo se termina PID propio y queda registrado'}, indent=2), encoding='utf-8')
raise SystemExit(code)

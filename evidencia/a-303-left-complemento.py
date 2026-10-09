import ctypes
import json
import os
import queue
import re
import subprocess
import sys
import threading
import time
from pathlib import Path
from ctypes import wintypes

script = Path(__file__).with_suffix('.gd')
proceso = subprocess.Popen(
    [os.environ['GODOT_BIN'], '--path', '.', '--script', str(script)],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    text=True, encoding='utf-8', errors='replace',
)
lineas = queue.Queue()


def leer():
    for linea in proceso.stdout:
        lineas.put(linea)
    lineas.put(None)


threading.Thread(target=leer, daemon=True).start()
user32 = ctypes.WinDLL('user32', use_last_error=True)
user32.SetProcessDpiAwarenessContext.argtypes = [ctypes.c_void_p]
user32.SetProcessDpiAwarenessContext.restype = ctypes.c_bool
if not user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4)):
    raise ctypes.WinError(ctypes.get_last_error())
user32.PostMessageW.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_size_t, ctypes.c_ssize_t]
user32.PostMessageW.restype = ctypes.c_bool
user32.GetWindowThreadProcessId.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]


class EntradaProceso(ctypes.Structure):
    _fields_ = [('dwSize', wintypes.DWORD), ('cntUsage', wintypes.DWORD),
                ('th32ProcessID', wintypes.DWORD), ('th32DefaultHeapID', ctypes.c_size_t),
                ('th32ModuleID', wintypes.DWORD), ('cntThreads', wintypes.DWORD),
                ('th32ParentProcessID', wintypes.DWORD), ('pcPriClassBase', wintypes.LONG),
                ('dwFlags', wintypes.DWORD), ('szExeFile', wintypes.WCHAR * 260)]


def pertenece_a_la_sonda(pid):
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    kernel.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(EntradaProceso)]
    kernel.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(EntradaProceso)]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    snapshot = kernel.CreateToolhelp32Snapshot(2, 0)
    padres = {}
    entrada = EntradaProceso()
    entrada.dwSize = ctypes.sizeof(EntradaProceso)
    try:
        activo = kernel.Process32FirstW(snapshot, ctypes.byref(entrada))
        while activo:
            padres[entrada.th32ProcessID] = entrada.th32ParentProcessID
            activo = kernel.Process32NextW(snapshot, ctypes.byref(entrada))
    finally:
        kernel.CloseHandle(snapshot)
    visitados = set()
    while pid and pid not in visitados:
        if pid == proceso.pid:
            return True
        visitados.add(pid)
        pid = padres.get(pid, 0)
    return False


def ejecutable_propio(pid):
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = kernel.OpenProcess(0x1000, False, pid)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    ruta = ctypes.create_unicode_buffer(32768)
    largo = wintypes.DWORD(len(ruta))
    try:
        if not kernel.QueryFullProcessImageNameW(handle, 0, ruta, ctypes.byref(largo)):
            raise ctypes.WinError(ctypes.get_last_error())
    finally:
        kernel.CloseHandle(handle)
    esperado = Path(os.environ['GODOT_BIN'].replace('_console.exe', '.exe')).resolve()
    return Path(ruta.value).resolve() == esperado
user32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.SetCursorPos.argtypes = [ctypes.c_int, ctypes.c_int]
user32.GetCursorPos.argtypes = [ctypes.POINTER(wintypes.POINT)]
cursor_anterior = wintypes.POINT()
user32.GetCursorPos(ctypes.byref(cursor_anterior))
registro = []
limite = time.monotonic() + 40
pid_propio = None
try:
    while time.monotonic() < limite:
        try:
            linea = lineas.get(timeout=0.2)
        except queue.Empty:
            continue
        if linea is None:
            break
        registro.append(linea)
        print(linea, end='', flush=True)
        if 'SONDA303_PROPIA ' in linea:
            montaje = json.loads(linea.split('SONDA303_PROPIA ', 1)[1])
            if Path(montaje['proyecto']).resolve() != Path.cwd().resolve():
                raise RuntimeError('El proyecto no es el worktree propio')
            pid_propio = montaje['pid']
        if 'SONDA303_POPUP_LISTO ' not in linea:
            continue
        datos = re.findall(r'-?\d+', linea.split('SONDA303_POPUP_LISTO ', 1)[1])
        paso, popup, raiz, x, y = map(int, datos[:5])
        hwnd = popup or raiz
        pid = ctypes.c_uint32()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        if pid.value != pid_propio or not pertenece_a_la_sonda(pid.value) or not ejecutable_propio(pid.value):
            raise RuntimeError('El HWND no pertenece a la sonda propia')
        time.sleep(0.1)
        if paso == 2:
            factor = float(re.search(r'factor=([0-9.]+)', linea).group(1))
            cliente_x, cliente_y = x + round(60*factor), y + round(70*factor)
            rect = wintypes.RECT()
            user32.GetClientRect(hwnd, ctypes.byref(rect))
            print('LEFT_CLIENTE', rect.right, rect.bottom, 'post=', cliente_x, cliente_y, flush=True)
            pantalla = wintypes.POINT(cliente_x, cliente_y)
            if not user32.ClientToScreen(hwnd, ctypes.byref(pantalla)):
                raise ctypes.WinError(ctypes.get_last_error())
            if not user32.SetCursorPos(pantalla.x, pantalla.y):
                raise ctypes.WinError(ctypes.get_last_error())
            coordenadas = (cliente_x | (cliente_y << 16))
            user32.PostMessageW(hwnd, 0x200, 0, coordenadas)
            time.sleep(0.05)
            if not user32.PostMessageW(hwnd, 0x201, 0x0001, coordenadas):
                raise ctypes.WinError(ctypes.get_last_error())
            if not user32.PostMessageW(hwnd, 0x202, 0, coordenadas):
                raise ctypes.WinError(ctypes.get_last_error())
        elif paso == 1:
            coordenadas = (30 | (30 << 16)) if popup and popup != raiz else ((x + 30) | ((y + 30) << 16))
            if not user32.PostMessageW(hwnd, 0x204, 0x0002, coordenadas):
                raise ctypes.WinError(ctypes.get_last_error())
            user32.PostMessageW(hwnd, 0x205, 0, coordenadas)
        else:
            if not user32.PostMessageW(hwnd, 0x100, 0x1B, 1):
                raise ctypes.WinError(ctypes.get_last_error())
            user32.PostMessageW(hwnd, 0x101, 0x1B, 1 << 30 | 1 << 31)
    codigo = proceso.wait(timeout=3)
finally:
    user32.SetCursorPos(cursor_anterior.x, cursor_anterior.y)
    if proceso.poll() is None:
        proceso.kill()
        proceso.wait()
salida = ''.join(registro)
if codigo or 'SONDA303_LEFT_SCOPE_LIBERADO' not in salida or 'SONDA303_LEFT_MONTAJE_LIBERADO' not in salida or any(x in salida for x in (
    'ERROR:', 'SCRIPT ERROR', 'resources still in use', 'instances were leaked', 'Leaked instance',
)):
    sys.exit(1)
print('SONDA303_LEFT_FINAL_LIMPIA')

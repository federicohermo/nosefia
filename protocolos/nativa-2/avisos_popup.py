"""Borrador nativo externo. Sólo se lanza tras A304 certificada, con --ejecutar y en turno.py."""
import argparse
import ctypes
import json
import os
import queue
import re
import subprocess
import threading
import time
from ctypes import wintypes
from pathlib import Path


class EntradaProceso(ctypes.Structure):
    _fields_ = [
        ('dwSize', wintypes.DWORD), ('cntUsage', wintypes.DWORD),
        ('th32ProcessID', wintypes.DWORD), ('th32DefaultHeapID', ctypes.c_size_t),
        ('th32ModuleID', wintypes.DWORD), ('cntThreads', wintypes.DWORD),
        ('th32ParentProcessID', wintypes.DWORD), ('pcPriClassBase', wintypes.LONG),
        ('dwFlags', wintypes.DWORD), ('szExeFile', wintypes.WCHAR * 260),
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ejecutar', action='store_true')
    parser.add_argument('--base-certificada')
    parser.add_argument('--proyecto', type=Path)
    parser.add_argument('--salida', type=Path)
    args = parser.parse_args()
    if not args.ejecutar:
        print('BORRADOR309_NO_EJECUTADO: falta A304 certificada; sólo preparación externa.')
        return 0
    if not args.base_certificada or not re.fullmatch(r'[0-9a-f]{40}', args.base_certificada):
        parser.error('--base-certificada requiere el hash completo entregado por el padre')
    if args.proyecto is None or args.salida is None:
        parser.error('--proyecto y --salida absolutos son obligatorios')
    if not args.proyecto.is_absolute() or not args.salida.is_absolute():
        parser.error('No se admiten rutas relativas de proyecto o evidencia')
    proyecto = args.proyecto.resolve(strict=True)
    salida = args.salida.resolve()
    subprocess.run(['git', 'merge-base', '--is-ancestor', args.base_certificada, 'HEAD'],
                   cwd=proyecto, check=True)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=proyecto, text=True).strip()
    if not (proyecto / 'src/ui/pila_de_notificaciones.gd').is_file():
        parser.error('La pila309 debe estar implementada/importada antes de esta sonda')
    salida.mkdir(parents=True, exist_ok=True)
    entorno = dict(os.environ)
    # Aislar user:// antes de iniciar el motor: el montaje incluye EnlaceDeGuardado.
    usuario = salida / 'usuario-aislado'
    usuario.mkdir(exist_ok=True)
    entorno['APPDATA'] = str(usuario)
    entorno['SONDA309_SALIDA'] = str(salida)
    godot = Path(entorno['GODOT_BIN']).resolve(strict=True)
    esperado_gui = Path(str(godot).replace('_console.exe', '.exe')).resolve(strict=True)
    script = Path(__file__).with_suffix('.gd').resolve(strict=True)
    # Las coordenadas del motor son físicas: evitar la virtualización DPI de Win32.
    user32 = ctypes.WinDLL('user32', use_last_error=True)
    user32.SetProcessDpiAwarenessContext.argtypes = [ctypes.c_void_p]
    user32.SetProcessDpiAwarenessContext.restype = wintypes.BOOL
    user32.GetThreadDpiAwarenessContext.restype = ctypes.c_void_p
    user32.AreDpiAwarenessContextsEqual.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    user32.AreDpiAwarenessContextsEqual.restype = wintypes.BOOL
    dpi_v2 = ctypes.c_void_p(-4)
    dpi_fijado = user32.SetProcessDpiAwarenessContext(dpi_v2)
    error_dpi = ctypes.get_last_error()
    if not user32.AreDpiAwarenessContextsEqual(user32.GetThreadDpiAwarenessContext(), dpi_v2):
        if not dpi_fijado:
            raise ctypes.WinError(error_dpi)
        raise RuntimeError('No se confirmó PER_MONITOR_AWARE_V2 antes de iniciar Godot')
    proceso = subprocess.Popen(
        [str(godot), '--path', str(proyecto), '--script', str(script)], cwd=proyecto,
        env=entorno, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding='utf-8', errors='replace',
    )
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, ctypes.c_size_t, ctypes.c_ssize_t]
    user32.PostMessageW.restype = wintypes.BOOL
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetWindowThreadProcessId.restype = wintypes.DWORD
    kernel.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    kernel.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(EntradaProceso)]
    kernel.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(EntradaProceso)]
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR,
                                               ctypes.POINTER(wintypes.DWORD)]
    kernel.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    kernel.GetExitCodeProcess.restype = wintypes.BOOL
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    lineas = queue.Queue()

    def leer():
        for linea in proceso.stdout:
            lineas.put(linea)
        lineas.put(None)

    def pertenece(pid):
        snapshot = kernel.CreateToolhelp32Snapshot(2, 0)
        if snapshot == ctypes.c_void_p(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        padres = {}
        entrada = EntradaProceso()
        entrada.dwSize = ctypes.sizeof(entrada)
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

    def abrir_handle_propio(pid):
        if not pertenece(pid):
            raise RuntimeError('PID declarado no desciende del proceso propio')
        handle = kernel.OpenProcess(0x1001, False, pid)  # QUERY_LIMITED_INFORMATION | TERMINATE.
        if not handle:
            raise ctypes.WinError(ctypes.get_last_error())
        ruta = ctypes.create_unicode_buffer(32768)
        largo = wintypes.DWORD(len(ruta))
        if not kernel.QueryFullProcessImageNameW(handle, 0, ruta, ctypes.byref(largo)):
            kernel.CloseHandle(handle)
            raise ctypes.WinError(ctypes.get_last_error())
        if Path(ruta.value).resolve() not in (godot, esperado_gui):
            kernel.CloseHandle(handle)
            raise RuntimeError('El PID no ejecuta el Godot declarado')
        return handle

    def mensaje(hwnd, tipo, wparam, lparam):
        pid = wintypes.DWORD()
        if not user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid)):
            raise ctypes.WinError(ctypes.get_last_error())
        if pid.value != pid_propio or not pertenece(pid.value):
            raise RuntimeError('HWND no pertenece a la sonda propia')
        if not user32.PostMessageW(hwnd, tipo, wparam, lparam):
            raise ctypes.WinError(ctypes.get_last_error())

    threading.Thread(target=leer, daemon=True).start()
    registro = []
    enviadas = []
    esperado = [(1920, 'ESC'), (1920, 'RIGHT'), (1280, 'ESC'), (1280, 'RIGHT')]
    pid_propio = None
    handle_propio = None
    resultado = None
    codigo = None
    cancelacion_propia = False
    try:
        limite = time.monotonic() + 45
        while time.monotonic() < limite:
            try:
                linea = lineas.get(timeout=0.2)
            except queue.Empty:
                continue
            if linea is None:
                break
            registro.append(linea)
            print(linea, end='', flush=True)
            if 'SONDA309_PROPIA ' in linea:
                if pid_propio is not None:
                    raise RuntimeError('Se recibió dos veces la identidad del montaje')
                datos = json.loads(linea.split('SONDA309_PROPIA ', 1)[1])
                if Path(datos['proyecto']).resolve() != proyecto:
                    raise RuntimeError('El montaje declara otro proyecto')
                pid_propio = int(datos['pid'])
                handle_propio = abrir_handle_propio(pid_propio)
            if 'SONDA309_RESULTADO ' in linea:
                resultado = json.loads(linea.split('SONDA309_RESULTADO ', 1)[1])
            if 'SONDA309_POPUP_LISTO ' not in linea:
                continue
            if handle_propio is None:
                raise RuntimeError('Pedido de entrada sin identidad verificada')
            datos = json.loads(linea.split('SONDA309_POPUP_LISTO ', 1)[1])
            paso = (int(datos['ancho']), datos['accion'])
            if len(enviadas) >= len(esperado) or paso != esperado[len(enviadas)]:
                raise RuntimeError('Secuencia de resoluciones/gestos inesperada')
            popup, raiz = int(datos['popup']), int(datos['raiz'])
            hwnd = popup or raiz
            time.sleep(0.1)
            if datos['accion'] == 'RIGHT':
                x, y = (30, 30) if popup and popup != raiz else (int(datos['x']) + 30,
                                                                           int(datos['y']) + 30)
                coordenadas = ((y & 0xFFFF) << 16) | (x & 0xFFFF)
                mensaje(hwnd, 0x204, 0x0002, coordenadas)
                mensaje(hwnd, 0x205, 0, coordenadas)
            else:
                mensaje(hwnd, 0x100, 0x1B, 1 | (0x01 << 16))
                mensaje(hwnd, 0x101, 0x1B, 1 | (0x01 << 16) | (1 << 30) | (1 << 31))
            enviadas.append(paso)
        codigo = proceso.wait(timeout=3)
    finally:
        # El handle retenido refiere al proceso validado original, incluso si el PID se reutiliza.
        if handle_propio:
            estado = wintypes.DWORD()
            if kernel.GetExitCodeProcess(handle_propio, ctypes.byref(estado)) and estado.value == 259:
                kernel.TerminateProcess(handle_propio, 1)
                cancelacion_propia = True
        if proceso.poll() is None:
            proceso.kill()
            proceso.wait()
            cancelacion_propia = True
        if handle_propio:
            kernel.CloseHandle(handle_propio)
        (salida / 'nativa309.log').write_text(''.join(registro), encoding='utf-8', newline='\n')
        (salida / 'procedencia.json').write_text(json.dumps({
            'base_certificada': args.base_certificada, 'head': head, 'proyecto': str(proyecto),
            'pid_launcher': proceso.pid, 'pid_godot': pid_propio, 'gestos_enviados': enviadas,
            'appdata_aislado': str(usuario), 'resultado': resultado,
            'cancelacion_propia': cancelacion_propia,
        }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    texto = ''.join(registro)
    if codigo != 0 or cancelacion_propia or enviadas != esperado or resultado is None or resultado['fallo']:
        return 1
    if 'SONDA309_MONTAJE_LIBERADO' not in texto or any(p in texto for p in (
        'ERROR:', 'SCRIPT ERROR', 'Parse Error', 'resources still in use',
        'instances were leaked', 'Leaked instance',
    )):
        return 1
    if len(resultado['fotos']) != 8 or not all(Path(p).is_file() for p in resultado['fotos']):
        return 1
    print('SONDA309_NATIVA_LIMPIA: quedan por revisar las ocho capturas visualmente.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

"""Contrasta bytes locales y publica hashes calculados sobre los blobs remotos."""

from pathlib import Path
import hashlib
import json
import subprocess
import sys

s = Path(__file__).parent
e = s / 'capturas374'


def git(*args):
    return subprocess.check_output(['git', *args])


sha = git('ls-remote', 'origin', 'refs/heads/capturas/374').decode().split()[0]
subprocess.run(['git', 'fetch', '-q', 'origin', 'capturas/374'], check=True)
blobs = {line.split('\t', 1)[1]: line.split()[2]
         for line in git('ls-tree', '-r', sha).decode('utf-8').splitlines()}

if sys.argv[1] == 'crear':
    assert 'sha256.json' not in blobs
    manifest = {}
    normalizados = []
    locales = {p.relative_to(e).as_posix() for p in e.rglob('*') if p.is_file()}
    assert locales == set(blobs)
    for nombre, blob in blobs.items():
        publicado = git('cat-file', 'blob', blob)
        local = (e / nombre).read_bytes()
        if local != publicado:
            assert local.replace(b'\r\n', b'\n') == publicado, nombre
            assert not nombre.endswith(('.png', '.zip')), nombre
            normalizados.append(nombre)
        manifest[nombre] = {'bytes': len(publicado),
                            'sha256': hashlib.sha256(publicado).hexdigest(), 'git_blob': blob}
    carpeta = s / '374-manifiesto-solo'
    carpeta.mkdir(exist_ok=True)
    (carpeta / 'sha256.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    (s / '374-publicacion-inicial.json').write_text(json.dumps(
        {'commit': sha, 'artefactos': len(blobs), 'textos_con_EOL_normalizados': normalizados},
        ensure_ascii=False, indent=2), encoding='utf-8')
    print(sha, len(blobs), 'artefactos;', len(normalizados), 'textos CRLF→LF')
else:
    manifest = json.loads(git('show', sha + ':sha256.json').decode('utf-8'))
    assert set(blobs) == set(manifest) | {'sha256.json'}
    for nombre, datos in manifest.items():
        assert blobs[nombre] == datos['git_blob'], nombre
        publicado = git('cat-file', 'blob', blobs[nombre])
        assert len(publicado) == datos['bytes'], nombre
        assert hashlib.sha256(publicado).hexdigest() == datos['sha256'], nombre
    anterior = json.loads((s / '374-publicacion-inicial.json').read_text(encoding='utf-8'))
    assert git('rev-parse', sha+'^').decode().strip() == anterior['commit']
    datos = {'commit': sha, 'artefactos_verificados': len(manifest), 'blobs_totales': len(blobs),
             'manifest_sha256': hashlib.sha256(git('show', sha+':sha256.json')).hexdigest(),
             'normalizacion_EOL': anterior['textos_con_EOL_normalizados']}
    (s / '374-publicacion-verificada.json').write_text(json.dumps(datos, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(datos, ensure_ascii=False, indent=2))

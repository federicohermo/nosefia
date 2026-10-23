import hashlib
import json
import struct
from pathlib import Path


def read_pack(path):
    data = path.read_bytes()
    assert struct.unpack_from('<6I', data) == (0x43504447, 4, 4, 7, 2, 2)
    base, directory = struct.unpack_from('<QQ', data, 24)
    count = struct.unpack_from('<I', data, directory)[0]
    cursor = directory + 4
    entries = []
    for _ in range(count):
        length = struct.unpack_from('<I', data, cursor)[0]
        cursor += 4
        name = data[cursor:cursor + length].rstrip(b'\0').decode()
        cursor += length
        offset, size = struct.unpack_from('<QQ', data, cursor)
        digest = data[cursor + 16:cursor + 32]
        flags = struct.unpack_from('<I', data, cursor + 32)[0]
        cursor += 36
        content = data[base + offset:base + offset + size]
        assert len(content) == size and hashlib.md5(content).digest() == digest, name
        entries.append((name, offset, size, digest, flags))
    assert cursor == len(data)
    return data, base, directory, entries


def main():
    root = Path('reports/cami-631')
    inventories = {}
    for side in ['base', 'cami']:
        path = Path(f'export/{side}/index.pck')
        data, base, directory, entries = read_pack(path)
        inventories[side] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                             'files': {name: size for name, _, size, _, _ in entries}}
    data, base, directory, entries = read_pack(Path('export/cami/index.pck'))
    for n in range(1, 9):
        source = f'assets/characters/cami/{n:02}.png.import'
        assert source in inventories['cami']['files']
        name, offset, size, *_ = next(e for e in entries if e[0] == source)
        remap = data[base + offset:base + offset + size].decode()
        ctex = next(line.split('="', 1)[1].rstrip('"') for line in remap.splitlines() if line.startswith('path='))
        assert ctex.removeprefix('res://') in inventories['cami']['files']
    assert 'assets/characters/cami/idle.tres.remap' in inventories['cami']['files']
    (root / 'paquetes.json').write_text(json.dumps(inventories, indent=2), encoding='utf-8')
    added = set(inventories['cami']['files']) - set(inventories['base']['files'])
    print(json.dumps({'delta_bytes': len(data) - inventories['base']['bytes'],
                      'added_files': {n: inventories['cami']['files'][n] for n in sorted(added)}}))

    output = bytearray(data[:directory])
    additions = [
        ('capture_driver.gd', root / 'capture_driver.gd'),
        *[(p, Path(p)) for p in ['test/escenas/captura_de_cami.gd',
                                'test/escenas/captura_de_compradores_jornada_2.gd',
                                'test/reloj_de_prueba.gd']],
    ]
    replacements = {}
    name = 'project.binary'
    _, offset, size, *_ = next(e for e in entries if e[0] == name)
    content = bytearray(data[base + offset:base + offset + size])
    count = struct.unpack_from('<I', content, 4)[0]
    struct.pack_into('<I', content, 4, count + 1)
    key = b'autoload/CamiCapture'
    value = b'*res://capture_driver.gd'
    variant = struct.pack('<II', 4, len(value)) + value + b'\0' * (-len(value) % 4)
    content.extend(struct.pack('<I', len(key)) + key + struct.pack('<I', len(variant)) + variant)
    replacements[name] = bytes(content)
    entries = [e for e in entries if e[0] not in replacements]
    contents = [(name, source.read_bytes()) for name, source in additions] + list(replacements.items())
    for name, content in contents:
        output.extend(b'\0' * (-len(output) % 16))
        entries.append((name, len(output) - base, len(content), hashlib.md5(content).digest(), 0))
        output.extend(content)
    output.extend(b'\0' * (-len(output) % 16))
    struct.pack_into('<Q', output, 32, len(output))
    output.extend(struct.pack('<I', len(entries)))
    for name, offset, size, digest, flags in sorted(entries):
        encoded = name.encode()
        encoded += b'\0' * (-len(encoded) % 4)
        output.extend(struct.pack('<I', len(encoded)) + encoded + struct.pack('<QQ', offset, size) + digest + struct.pack('<I', flags))
    target = Path('export/captura')
    target.mkdir(exist_ok=True)
    (target / 'index.pck').write_bytes(output)
    read_pack(target / 'index.pck')
    allowed = {p.name for p in Path('export/base').iterdir() if p.is_file()}
    for source in Path('export/cami').iterdir():
        if source.name == 'index.pck' or source.name not in allowed:
            continue
        content = source.read_bytes()
        if source.name == 'index.html':
            content = content.replace(str(len(data)).encode(), str(len(output)).encode())
        (target / source.name).write_bytes(content)


if __name__ == '__main__':
    main()

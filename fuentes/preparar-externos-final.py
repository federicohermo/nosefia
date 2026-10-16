from pathlib import Path
s=Path(__file__).parent
head='fb4236e69c752e6879bb338b80e734e16b211b41'
exportador=(s/'exportar_paquete22.py').read_text(encoding='utf8').replace('893109542cafeef5a6483a8b3f041e5dc39c8f05',head)
(s/'exportar_paquete22-02.py').write_text(exportador,encoding='utf8')
runner=(s/'paquete-y-nativo.py').read_text(encoding='utf8').replace('893109542cafeef5a6483a8b3f041e5dc39c8f05',head).replace('evidencia-01','evidencia-02').replace('22-export-01','22-export-02').replace('22-usuario-evidencia-01','22-usuario-evidencia-02').replace('exportar_paquete22.py','exportar_paquete22-02.py')
(s/'paquete-y-nativo-02.py').write_text(runner,encoding='utf8')
publisher=(s.parent/'carril-C-431/publicar-blobs-exactos.py').read_text(encoding='utf8').replace('capturas/431','capturas/22').replace('evidencia431','evidencia22')
publisher=publisher.replace('padre = texto("ls-remote", "origin", "refs/heads/" + rama).split()[0]\ngit("fetch", "-q", "origin", rama)', 'remoto = texto("ls-remote", "origin", "refs/heads/" + rama)\npadre = remoto.split()[0] if remoto else None\nif padre:\n    git("fetch", "-q", "origin", rama)')
publisher=publisher.replace('git("read-tree", padre, env=env)','git("read-tree", *([padre] if padre else ["--empty"]), env=env)')
publisher=publisher.replace('final, "-p", padre, "-m"','final, *(["-p", padre] if padre else []), "-m"')
(s/'publicar-blobs-exactos.py').write_text(publisher,encoding='utf8')

#!/usr/bin/env python3
"""Gera a versão web (PWA offline) em app/build/web, pronta para ficar em <site>/biblia/.

Uso: python tools/build_web.py [pasta-de-destino]
Sem destino, deixa o resultado só em app/build/web. Com destino, substitui o conteúdo dessa pasta.
Requer app/assets/db/biblia.db.gz (gerado por tools/build_db.py + gzip, ou baixado do CI).
"""
import hashlib, json, os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, 'app')
OUT = os.path.join(APP, 'build', 'web')
BASE = '/biblia/'

if not os.path.exists(os.path.join(APP, 'assets/db/biblia.db.gz')):
    sys.exit('Falta app/assets/db/biblia.db.gz')

flutter = shutil.which('flutter') or 'flutter'
subprocess.run([flutter, 'build', 'web', '--release', '--base-href', BASE, '--no-web-resources-cdn',
                '--no-wasm-dry-run'], cwd=APP, check=True, shell=(os.name == 'nt'))

# skwasm só serve para builds --wasm; este build é JS (canvaskit): descarta para não pesar no site e no cache
for n in os.listdir(os.path.join(OUT, 'canvaskit')):
    if n.startswith('skwasm'):
        os.remove(os.path.join(OUT, 'canvaskit', n))

# arquivos que o service worker guarda para uso offline (tudo, menos o próprio sw.js e mapas de depuração)
files, h = [], hashlib.sha256()
for dp, _, names in os.walk(OUT):
    for n in sorted(names):
        full = os.path.join(dp, n)
        rel = os.path.relpath(full, OUT).replace(os.sep, '/')
        if rel in ('sw.js', '.last_build_id', 'flutter_service_worker.js') or rel.endswith('.map'):
            continue
        files.append(rel)
        h.update(rel.encode())
        h.update(os.path.getsize(full).to_bytes(8, 'little'))
        if os.path.getsize(full) < 5_000_000:
            h.update(open(full, 'rb').read())
files.sort()
version = h.hexdigest()[:12]

sw = open(os.path.join(OUT, 'sw.js'), encoding='utf-8').read()
sw = sw.replace('__VERSION__', version).replace('__FILES__', json.dumps(files, indent=1))
open(os.path.join(OUT, 'sw.js'), 'w', encoding='utf-8').write(sw)
print(f'{len(files)} arquivos, versão {version}')

if len(sys.argv) > 1:
    dest = sys.argv[1]
    if os.path.exists(dest):
        shutil.rmtree(dest)
    shutil.copytree(OUT, dest)
    print('copiado para', dest)

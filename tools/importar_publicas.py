#!/usr/bin/env python3
"""Exporta as Bíblias em português de domínio público/licença aberta de módulos MySword para textos-publicos/.

Uso: python3 tools/importar_publicas.py <pasta com os .bbl.mybible>
Saída: textos-publicos/<id>.tsv (livro, capítulo, versículo, texto), livros 1 a 66 como no banco do app.
"""
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_mysword import clean  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'textos-publicos')
MODULES = {'arc1911': 'ARC 1911 (', 'bl': 'BL ('}


def main():
    src = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for vid, prefix in MODULES.items():
        name = next(f for f in sorted(os.listdir(src)) if f.startswith(prefix) and f.endswith('.bbl.mybible'))
        db = sqlite3.connect('file:' + os.path.join(src, name) + '?mode=ro', uri=True)
        n = 0
        with open(os.path.join(OUT, vid + '.tsv'), 'w', encoding='utf-8', newline='\n') as f:
            for b, c, v, t in db.execute('SELECT Book, Chapter, Verse, Scripture FROM Bible ORDER BY Book, Chapter, Verse'):
                t = clean(t or '').replace('﻿', '').strip()
                if t:
                    f.write(f'{b}\t{c}\t{v}\t{t}\n')
                    n += 1
        print(f'{vid}: {n} versículos <- {name}')


if __name__ == '__main__':
    main()

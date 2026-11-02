#!/usr/bin/env python3
"""Monta o banco SQLite do app (textos, palavras do original, léxicos).

Uso: python3 tools/build_db.py [saida.db]
Requer as fontes baixadas por tools/fetch_sources.sh.
"""
import csv
import glob
import json
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'sources')
PT = os.path.join(ROOT, 'pt')
PERFIS = os.path.join(ROOT, '..', 'perfis')


def carregar_perfil():
    """Perfil do build: BIBLIA_PERFIL=pessoal (padrão) ou publica; ver perfis/*.json."""
    nome = os.environ.get('BIBLIA_PERFIL', 'publica')
    caminho = os.path.join(PERFIS, nome + '.json')
    if not os.path.exists(caminho):
        sys.exit(f'perfil desconhecido: {nome} (esperado perfis/{nome}.json)')
    return json.load(open(caminho, encoding='utf-8'))


PERFIL = carregar_perfil()

# (código STEP, código USFM, nome em português, testamento)
BOOKS = [
    ('Gen', 'GEN', 'Gênesis'), ('Exo', 'EXO', 'Êxodo'), ('Lev', 'LEV', 'Levítico'),
    ('Num', 'NUM', 'Números'), ('Deu', 'DEU', 'Deuteronômio'), ('Jos', 'JOS', 'Josué'),
    ('Jdg', 'JDG', 'Juízes'), ('Rut', 'RUT', 'Rute'), ('1Sa', '1SA', '1 Samuel'),
    ('2Sa', '2SA', '2 Samuel'), ('1Ki', '1KI', '1 Reis'), ('2Ki', '2KI', '2 Reis'),
    ('1Ch', '1CH', '1 Crônicas'), ('2Ch', '2CH', '2 Crônicas'), ('Ezr', 'EZR', 'Esdras'),
    ('Neh', 'NEH', 'Neemias'), ('Est', 'EST', 'Ester'), ('Job', 'JOB', 'Jó'),
    ('Psa', 'PSA', 'Salmos'), ('Pro', 'PRO', 'Provérbios'), ('Ecc', 'ECC', 'Eclesiastes'),
    ('Sng', 'SNG', 'Cânticos'), ('Isa', 'ISA', 'Isaías'), ('Jer', 'JER', 'Jeremias'),
    ('Lam', 'LAM', 'Lamentações'), ('Ezk', 'EZK', 'Ezequiel'), ('Dan', 'DAN', 'Daniel'),
    ('Hos', 'HOS', 'Oseias'), ('Jol', 'JOL', 'Joel'), ('Amo', 'AMO', 'Amós'),
    ('Oba', 'OBA', 'Obadias'), ('Jon', 'JON', 'Jonas'), ('Mic', 'MIC', 'Miqueias'),
    ('Nam', 'NAM', 'Naum'), ('Hab', 'HAB', 'Habacuque'), ('Zep', 'ZEP', 'Sofonias'),
    ('Hag', 'HAG', 'Ageu'), ('Zec', 'ZEC', 'Zacarias'), ('Mal', 'MAL', 'Malaquias'),
    ('Mat', 'MAT', 'Mateus'), ('Mrk', 'MRK', 'Marcos'), ('Luk', 'LUK', 'Lucas'),
    ('Jhn', 'JHN', 'João'), ('Act', 'ACT', 'Atos'), ('Rom', 'ROM', 'Romanos'),
    ('1Co', '1CO', '1 Coríntios'), ('2Co', '2CO', '2 Coríntios'), ('Gal', 'GAL', 'Gálatas'),
    ('Eph', 'EPH', 'Efésios'), ('Php', 'PHP', 'Filipenses'), ('Col', 'COL', 'Colossenses'),
    ('1Th', '1TH', '1 Tessalonicenses'), ('2Th', '2TH', '2 Tessalonicenses'),
    ('1Ti', '1TI', '1 Timóteo'), ('2Ti', '2TI', '2 Timóteo'), ('Tit', 'TIT', 'Tito'),
    ('Phm', 'PHM', 'Filemom'), ('Heb', 'HEB', 'Hebreus'), ('Jas', 'JAS', 'Tiago'),
    ('1Pe', '1PE', '1 Pedro'), ('2Pe', '2PE', '2 Pedro'), ('1Jn', '1JN', '1 João'),
    ('2Jn', '2JN', '2 João'), ('3Jn', '3JN', '3 João'), ('Jud', 'JUD', 'Judas'),
    ('Rev', 'REV', 'Apocalipse'),
]
STEP_IDX = {b[0]: i + 1 for i, b in enumerate(BOOKS)}
USFM_IDX = {b[1]: i + 1 for i, b in enumerate(BOOKS)}

VERSIONS = [
    # id, nome, sigla, idioma, licença, crédito (só conteúdo público; as demais vêm de perfis/pessoal_versoes.json)
    ('arc1911', 'Almeida Corrigida (1911)', 'ARC 1911', 'pt', 'Domínio público', 'João Ferreira de Almeida, Corrigida (edição de 1911), domínio público.'),
    ('bl', 'Bíblia Livre', 'BL', 'pt', 'CC BY 3.0 BR', 'Bíblia Livre, Projeto Bíblia Livre. Licença Creative Commons Atribuição 3.0 Brasil (CC BY 3.0 BR).'),
    ('kjv', 'King James (inglês)', 'BKJ (Inglês)', 'en', 'Domínio público', 'King James Version (1769), domínio público.'),
]

CREDITS = [
    ('STEPBible', 'Textos hebraico (TAHOT) e grego (TAGNT), léxicos (TBESH, TBESG) e morfologia (TEHMC, TEGMC): Tyndale House, Cambridge, STEP Bible, www.STEPBible.org. Licença Creative Commons Atribuição 4.0.'),
    ('Falas de Deus e de Jesus', 'MACULA Quotation and Speaker Data, © 2023 by Clear Bible, Inc, available at https://github.com/Clear-Bible/speaker-quotations/. Licença Creative Commons Atribuição 4.0. Inclui dados do Glyssen, © 2014-2020 SIL LSDev e Faith Comes By Hearing (licença MIT).'),
    ('Referências cruzadas', 'Vínculos entre versículos do OpenBible.info (www.openbible.info), licença Creative Commons Atribuição. Inclui dados do Treasury of Scripture Knowledge (domínio público).'),
    ('Pessoas e lugares', 'TIPNR, Translators Individualised Proper Names with all References: Tyndale House, Cambridge, STEP Bible, www.STEPBible.org. Licença Creative Commons Atribuição 4.0. Resumos e artigos traduzidos para o português para este app.'),
    ('Resumos de livros e capítulos', 'Resumos condensados em português a partir das unfoldingWord Translation Notes (uW tN), © unfoldingWord. Licença Creative Commons Atribuição-CompartilhaIgual 4.0 (CC BY-SA 4.0).'),
    ('Traduções dos significados', 'Significados em português traduzidos do inglês para este app a partir dos dados da STEPBible.'),
]


def carregar_extras_pessoais():
    """Versões e créditos extras do perfil pessoal (perfis/pessoal_versoes.json, fora do repositório público)."""
    caminho = os.path.join(PERFIS, 'pessoal_versoes.json')
    if PERFIL['nome'] != 'pessoal':
        return [], [], {}, [], ''
    if not os.path.exists(caminho):
        sys.exit(f'perfil pessoal exige {caminho}')
    d = json.load(open(caminho, encoding='utf-8'))
    vs = [(v['id'], v['nome'], v['sigla'], v['idioma'], v['licenca'], v['credito']) for v in d['versoes']]
    return vs, [(c['titulo'], c['texto']) for c in d['creditos']], {v['id']: v['fonte'] for v in d['versoes']}, [v['id'] for v in d['versoes'] if v.get('aspas')], d.get('notas_fonte', '')


EXTRA_VERSIONS, EXTRA_CREDITS, EXTRA_FONTES, VERSOES_ASPAS, NOTAS_FONTE = carregar_extras_pessoais()


def clean_html(t):
    t = re.sub(r'<ref=[^>]*>', '', t)
    t = re.sub(r'<br\s*/?>', '\n', t, flags=re.I)
    t = re.sub(r'<[^>]+>', '', t)
    t = t.replace('__', '').replace('&nbsp;', ' ')
    t = re.sub(r'[ \t]+', ' ', t)
    t = re.sub(r' *\n *', '\n', t)
    return re.sub(r'\n{2,}', '\n', t).strip()


def load_json(name, default):
    p = os.path.join(PT, name)
    return json.load(open(p, encoding='utf-8')) if os.path.exists(p) else default


def load_pt_glosses():
    out = {}
    for f in sorted(glob.glob(os.path.join(PT, 'glosas_*.tsv'))):
        for line in open(f, encoding='utf-8'):
            c = line.rstrip('\n').split('\t')
            if len(c) >= 2 and c[0] and c[1]:
                out[c[0]] = c[1]
    return out


def load_en2pt():
    """Glosas inglesas da STEPBible -> português (tools/pt/glosas.tsv)."""
    out = {}
    path = os.path.join(PT, 'glosas.tsv')
    if os.path.exists(path):
        for line in open(path, encoding='utf-8'):
            c = line.rstrip('\n').split('\t')
            if len(c) >= 2 and c[0] and not c[0].startswith('#') and c[1]:
                out[c[0]] = c[1]
    return out


def load_pt_defs():
    """Definições do léxico traduzidas (tools/pt/definicoes*.tsv: strong, definição)."""
    out = {}
    for f in sorted(glob.glob(os.path.join(PT, 'definicoes*.tsv'))):
        for line in open(f, encoding='utf-8'):
            c = line.rstrip('\n').split('\t')
            if len(c) >= 2 and c[0] and not c[0].startswith('#') and c[1]:
                out[c[0]] = c[1].replace('\\n', '\n')
    return out


def gloss_to_pt(g, en2pt):
    """Glosa inglesa de uma ocorrência -> português; '' quando ainda não traduzida."""
    m = re.match(r'^(.*?)([,.;:!?]*)$', g)
    core, punct = m.group(1), m.group(2)
    for key in (g, core, core.lower()):
        if key in en2pt:
            return en2pt[key] + (punct if key != g else '')
    for en, pt in (('and ', 'e '), ('And ', 'E ')):
        if core.startswith(en) and core[len(en):] in en2pt:
            return pt + en2pt[core[len(en):]] + punct
    return ''


def scrollmapper(name):
    rows = list(csv.DictReader(open(os.path.join(SRC, 'scrollmapper/formats/csv', name + '.csv'), encoding='utf-8')))
    order = []
    for r in rows:
        if not order or order[-1] != r['Book']:
            order.append(r['Book'])
    assert len(order) == 66, (name, len(order))
    idx = {b: i + 1 for i, b in enumerate(order)}
    for r in rows:
        t = r['Text'].strip()
        if t:
            yield idx[r['Book']], int(r['Chapter']), int(r['Verse']), t


def tsv_bible(path):
    """Texto já limpo por tools/import_mysword.py: livro, capítulo, versículo e texto separados por tab."""
    for line in open(path, encoding='utf-8'):
        b, c, v, t = line.rstrip('\n').split('\t', 3)
        yield int(b), int(c), int(v), t


def study_notes(path):
    """Notas de estudo (textos/notas-nvi.tsv, só perfil pessoal): livro, capítulo/versículo inicial e final, rótulo, HTML."""
    for line in open(path, encoding='utf-8'):
        b, c1, v1, c2, v2, rot, html = line.rstrip('\n').split('\t', 6)
        yield int(b), int(c1) * 1000 + int(v1), int(c2) * 1000 + int(v2), rot, html


def markdown_bible(path):
    """Bíblia em Markdown: '## Livro', '### Capítulo N' (ou 'Salmo N'), '**N** texto'; *itálico* = palavras supridas."""
    book, ch = 0, 0
    for line in open(path, encoding='utf-8'):
        line = line.strip()
        if line.startswith('## '):
            book, ch = book + 1, 0
        elif line.startswith('### '):
            m = re.match(r'^### (?:Capítulo|Salmo) (\d+)$', line)
            if m:
                ch = int(m.group(1))
        else:
            m = re.match(r'^\*\*(\d+)\*\*\s+(.*)$', line)
            if m and book and ch:
                t = re.sub(r'\s+', ' ', m.group(2).replace('*', '')).strip()
                yield book, ch, int(m.group(1)), t


def verse_markdown_bible(paths):
    """Bíblia em Markdown com versículos '<sup>N</sup>' no meio do texto.

    '# Livro' abre um livro (na ordem canônica; cabeçalho repetido em seguida e 'Antigo/Novo Testamento' não contam),
    '## ... N' abre o capítulo N (livro de um capítulo só não tem). Cabeçalhos, notas de rodapé e referências
    cruzadas ('*(Lc 3.23-38)*', '*1Cr 1.1-4*') ficam de fora."""
    book, ch, last_head, empty = 0, 0, None, True
    verses, cur = {}, None
    for path in ([paths] if isinstance(paths, str) else paths):
        for raw in open(path, encoding='utf-8'):
            st = raw.strip()
            if st.startswith('# '):
                name = st[2:].strip()
                if name.lower() in ('antigo testamento', 'novo testamento') or (name == last_head and empty):
                    continue
                last_head, empty = name, True
                book, ch, cur = book + 1, 1, None
                continue
            if not book:
                continue
            if st.startswith('## '):
                m = re.search(r'(\d+)\s*$', st)
                if m:
                    ch, cur = int(m.group(1)), None
                continue
            if st.startswith(('#', '>')) or re.match(r'^\[\^\d+\]:', st) or re.match(r'^\*[^*]*\*$', st):
                continue
            st = st.replace('&emsp;', ' ').replace('&nbsp;', ' ')
            st = re.sub(r'\[\^\d+\]', '', st)
            parts = re.split(r'<sup>(\d+)</sup>', st)
            empty = empty and len(parts) == 1
            if parts[0].strip() and cur:
                verses[cur].append(parts[0].strip())
            for i in range(1, len(parts), 2):
                cur = (book, ch, int(parts[i]))
                verses.setdefault(cur, [])
                if parts[i + 1].strip():
                    verses[cur].append(parts[i + 1].strip())
    for (b, c, v), t in verses.items():
        text = re.sub(r'\s+', ' ', ' '.join(t).replace('*', '')).strip()
        if text:
            yield b, c, v, text


def biblenlp(code):
    refs = open(os.path.join(SRC, 'biblenlp/metadata/vref.txt'), encoding='utf-8').read().split('\n')
    lines = open(os.path.join(SRC, 'biblenlp/corpus', code + '.txt'), encoding='utf-8').read().split('\n')
    for ref, t in zip(refs, lines):
        t = t.strip()
        m = re.match(r'^(\w{3}) (\d+):(\d+)$', ref)
        if not t or not m or m.group(1) not in USFM_IDX or t == '<range>':
            continue
        # marcas de tradutor da TFT, como [MET] e [RHQ]
        t = re.sub(r'\s*\[[A-Z]{3}(?:, [A-Z]{3})*\]', '', t)
        yield USFM_IDX[m.group(1)], int(m.group(2)), int(m.group(3)), t


def read_rows(pattern):
    for f in sorted(glob.glob(os.path.join(SRC, 'step', 'Translators Amalgamated OT+NT', pattern))):
        for line in open(f, encoding='utf-8'):
            yield line.rstrip('\n').split('\t')


def norm_morph(m):
    # 'HR/Ncfsa' -> 'HR/HNcfsa' (o prefixo H/A de idioma vale para todos os segmentos)
    if not m:
        return ''
    segs = m.split('/')
    lang = segs[0][0]
    return '/'.join(s if s.startswith(lang) else lang + s for s in segs)


def hebrew_words():
    rx = re.compile(r'^(\w+)\.(\d+)\.(\d+)(?:\([\d.]+\))?#(\d+)=(\S+)$')
    for c in read_rows('TAHOT*.txt'):
        m = rx.match(c[0])
        if not m or len(c) < 6 or m.group(1) not in STEP_IDX:
            continue
        strongs = c[4]
        main = re.search(r'\{(H\d{4}[A-Z]?)\}', strongs) or re.search(r'(H\d{4}[A-Z]?)', strongs)
        yield dict(
            book=STEP_IDX[m.group(1)], ch=int(m.group(2)), v=int(m.group(3)), pos=int(m.group(4)),
            text=c[1].replace('/', '').replace('\\', ''), translit=c[2].replace('/', ''),
            gloss=re.sub(r'\s*/\s*', ' ', c[3]).strip(), strong=main.group(1) if main else '',
            strongs=' '.join(re.findall(r'H\d{4}[A-Z]?', strongs)), morph_full=norm_morph(c[5]), ed=m.group(5))


def greek_words():
    rx = re.compile(r'^(\w+)\.(\d+)\.(\d+)#(\d+)=(\S+)$')
    for c in read_rows('TAGNT*.txt'):
        m = rx.match(c[0])
        if not m or len(c) < 6 or m.group(1) not in STEP_IDX:
            continue
        gk = re.match(r'(.*?)\s*\((.*)\)$', c[1])
        st, morph = (c[3].split('=', 1) + [''])[:2]
        yield dict(
            book=STEP_IDX[m.group(1)], ch=int(m.group(2)), v=int(m.group(3)), pos=int(m.group(4)),
            text=gk.group(1) if gk else c[1], translit=gk.group(2) if gk else '',
            gloss=c[2].strip(), strong=st.split('+')[0], strongs=' '.join(re.findall(r'G\d{4}[A-Z]?', st)),
            morph=morph, morph_full=morph, ed=m.group(5))


def lexicon(path, prefix):
    rows = {}
    for line in open(path, encoding='utf-8'):
        c = line.rstrip('\n').split('\t')
        if len(c) > 7 and re.match(r'^' + prefix + r'\d', c[0]):
            rows.setdefault(c[1].split(' ')[0], c)
    return rows


def morph_table(pt_vals):
    out = {}
    for f in glob.glob(os.path.join(SRC, 'step', 'Morphology codes', '*.txt')):
        for line in open(f, encoding='utf-8'):
            c = line.rstrip('\n').split('\t')
            if len(c) < 2 or '=' not in c[1] or not re.match(r'^[A-Z][A-Za-z0-9\-/]*$', c[0]) or c[0] in out:
                continue
            d = re.sub(r'\(hence[^)]*\)?', '', c[1])
            parts_pt = []
            for part in d.split(';'):
                if '=' not in part:
                    continue
                k, v = part.split('=', 1)
                v = v.strip().rstrip(')').strip()
                if k.strip() in ('Original language', 'Name in Original language') or not v:
                    continue
                parts_pt.append(pt_vals.get(v, v))
            out[c[0]] = (' · '.join(parts_pt), c[1].strip())
    return out


# Falas de Deus (D) e de Jesus (J), a partir dos dados de citações e falantes da Clear Bible (MACULA).
FALANTES = {'God': 'D', 'Holy Spirit, the': 'D', 'Jesus': 'J', 'Jesus (child)': 'J'}


def usfm_ref(s):
    m = re.match(r'^(\w{3}) (\d+):(\d+)$', s.strip())
    return (USFM_IDX.get(m.group(1)), int(m.group(2)), int(m.group(3))) if m else None


def speech_segments():
    """Trechos de fala por versículo: (livro, cap, vers, quem, início, fim), em fração das palavras do original.

    Os dados da Clear seguem a numeração hebraica no AT; a TAHOT dá a correspondência com a numeração
    usada nas traduções (ex.: Mal.4.5(3.23))."""
    qdir = os.path.join(SRC, 'quotes', 'tsv')
    heb2eng = {}
    rx = re.compile(r'^(\w+)\.(\d+)\.(\d+)\((\d+)\.(\d+)\)#')
    for c in read_rows('TAHOT*.txt'):
        m = rx.match(c[0])
        if m and m.group(1) in STEP_IDX:
            b = STEP_IDX[m.group(1)]
            heb2eng[(b, int(m.group(4)), int(m.group(5)))] = (b, int(m.group(2)), int(m.group(3)))

    order, verse_of, pos = [], [], {}
    rv = re.compile(r'^(\w{3}) (\d+):(\d+)!')
    with open(os.path.join(qdir, 'alignment-quotations-clear.tsv'), encoding='utf-8') as f:
        for line in f:
            c = line.rstrip('\n').split('\t')
            if len(c) < 5 or not c[2][:1] in 'on':
                continue
            m = rv.match(c[3])
            if not m or m.group(1) not in USFM_IDX or c[2] in pos or not re.match(r'^[on]\d{11,12}$', c[2]):
                continue
            pos[c[2]] = len(order)
            order.append(c[2])
            verse_of.append((USFM_IDX[m.group(1)], int(m.group(2)), int(m.group(3))))
    verse_len, verse_first = {}, {}
    for i, k in enumerate(verse_of):
        verse_len[k] = verse_len.get(k, 0) + 1
        verse_first.setdefault(k, i)

    who = [''] * len(order)
    with open(os.path.join(qdir, 'Clear-Aligned-Projections.tsv'), encoding='utf-8') as f:
        rows = csv.DictReader(f, delimiter='\t')
        for r in rows:
            q = FALANTES.get(r['SPEAKER (FCBH)'])
            a, z = pos.get(r['CLEAR START']), pos.get(r['CLEAR END'])
            if not (q and a is not None and z is not None and a <= z):
                continue
            # o trecho tem de ficar dentro dos versículos que a própria linha declara
            ini, fim = usfm_ref(r['START VS']), usfm_ref(r['END VS'])
            if not (ini and fim and ini <= verse_of[a] and verse_of[z] <= fim):
                continue
            for i in range(a, z + 1):
                who[i] = who[i] or q

    out, i = [], 0
    while i < len(order):
        if not who[i]:
            i += 1
            continue
        k, q, j = verse_of[i], who[i], i
        while j + 1 < len(order) and verse_of[j + 1] == k and who[j + 1] == q:
            j += 1
        n, f0 = verse_len[k], verse_first[k]
        b, ch, v = heb2eng.get(k, k) if k[0] < 40 else k
        out.append((b, ch, v, q, round((i - f0) / n, 3), round((j + 1 - f0) / n, 3)))
        i = j + 1
    return out


OSIS = ('Gen Exod Lev Num Deut Josh Judg Ruth 1Sam 2Sam 1Kgs 2Kgs 1Chr 2Chr Ezra Neh Esth Job Ps Prov Eccl Song '
        'Isa Jer Lam Ezek Dan Hos Joel Amos Obad Jonah Mic Nah Hab Zeph Hag Zech Mal Matt Mark Luke John Acts Rom '
        '1Cor 2Cor Gal Eph Phil Col 1Thess 2Thess 1Tim 2Tim Titus Phlm Heb Jas 1Pet 2Pet 1John 2John 3John Jude Rev').split()
OSIS_IDX = {b: i + 1 for i, b in enumerate(OSIS)}


def cross_references(per_verse=40):
    """Referências cruzadas do OpenBible.info: (livro, cap, vers, livro, cap, vers, cap fim, vers fim, votos)."""
    def ref(s):
        b, c, v = s.split('.')
        return OSIS_IDX[b], int(c), int(v)
    by_verse = {}
    path = os.path.join(SRC, 'scrollmapper', 'sources', 'extras', 'cross_references.txt')
    for i, line in enumerate(open(path, encoding='utf-8')):
        c = line.rstrip('\n').split('\t')
        if i == 0 or len(c) < 3 or int(c[2]) < 1:
            continue
        a = ref(c[0])
        parts = c[1].split('-')
        t = ref(parts[0])
        e = ref(parts[-1])
        if e[0] != t[0]:
            e = t
        by_verse.setdefault(a, []).append((*a, *t, e[1], e[2], int(c[2])))
    out = []
    for rows in by_verse.values():
        rows.sort(key=lambda r: -r[8])
        out.extend(rows[:per_verse])
    return out


def proper_names():
    """Pessoas, lugares e outros nomes da TIPNR (STEPBible), com todas as referências."""
    path = glob.glob(os.path.join(SRC, 'step', 'Proper Nouns', 'TIPNR*.txt'))[0]
    recs, cur, sect = [], None, None
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\r\n')
        if line.startswith('$'):
            m = re.match(r'\$=+\s*(PERSON|PLACE\+PERSON|PLACE|OTHER|EXCLUDED)', line)
            sect, cur = (m.group(1) if m else None), None
            continue
        if sect in (None, 'EXCLUDED'):
            continue
        t = line.rstrip('\t').split('\t')
        if cur is None:
            if not re.match(r"[^\s@=]+@\w{3}\.\d", t[0]):
                continue
            cur = {'key': t[0].split('=')[0].strip(), 'sect': sect, 'head': t, 'refs': set(),
                   'brief': '', 'short': '', 'article': ''}
            recs.append(cur)
            continue
        if line.startswith('– ') and not line.startswith('– Total') and len(t) >= 5:
            for r in t[4].split(';'):
                r = r.strip()
                if r.startswith('LXX'):
                    continue
                m = re.fullmatch(r'(\w{3})\.(\d+)\.(\d+)[a-z]?', r)
                if m and m.group(1) in STEP_IDX:
                    cur['refs'].add((STEP_IDX[m.group(1)], int(m.group(2)), int(m.group(3))))
        for k in ('Brief', 'Short', 'Article'):
            if line.startswith('@%s=' % k):
                v = line.split('=', 1)[1].split('\t')[0]
                cur[k.lower()] = re.sub(r'\s*\(<ref=[^>]*>[^<]*</ref>\)', '', v).strip()
    for r in recs:
        h = r['head'] + [''] * 9
        r['name'] = r['key'].split('@')[0].replace('_', ' ')
        r['kind'] = h[8].strip() if not h[8].startswith('@') else ''
        if r['sect'] == 'PERSON':
            r['family'] = {'pais': h[2], 'irmaos': h[3], 'conjuges': h[4], 'filhos': h[5]}
        else:
            r['family'] = {}
    return recs


def name_key(s):
    s = re.sub(r'\([a-z?]\)', '', s).strip()
    return s.split('|')[-1].strip()


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, '..', 'build', 'biblia.db')
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    if os.path.exists(out):
        os.remove(out)
    db = sqlite3.connect(out)
    db.executescript('''
    PRAGMA page_size=4096;
    CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
    CREATE TABLE books(id INTEGER PRIMARY KEY, code TEXT, name TEXT, testament TEXT, chapters INTEGER);
    CREATE TABLE versions(id TEXT PRIMARY KEY, name TEXT, abbr TEXT, lang TEXT, license TEXT, credit TEXT, sort INTEGER);
    CREATE TABLE credits(name TEXT, credit TEXT);
    -- ini/fim codificados como capítulo*1000+versículo; o livro fica em book
    CREATE TABLE notas(id INTEGER PRIMARY KEY, book INTEGER, ini INTEGER, fim INTEGER, rotulo TEXT, html TEXT);
    -- imagens das notas (mapas, quadros); o html da nota as cita por <img src='id'/>
    CREATE TABLE imagens(id INTEGER PRIMARY KEY, data BLOB);
    CREATE TABLE verses(id INTEGER PRIMARY KEY, version TEXT, book INTEGER, chapter INTEGER, verse INTEGER, text TEXT);
    CREATE TABLE words(book INTEGER, chapter INTEGER, verse INTEGER, pos INTEGER, lang TEXT, text TEXT, translit TEXT,
                       gloss TEXT, strong TEXT, strongs TEXT, morph TEXT, ed TEXT, gloss_pt TEXT);
    CREATE TABLE lexicon(strong TEXT PRIMARY KEY, lemma TEXT, translit TEXT, gloss_en TEXT, gloss_pt TEXT, def_en TEXT,
                         def_pt TEXT);
    CREATE TABLE morph(code TEXT PRIMARY KEY, pt TEXT, en TEXT);
    CREATE TABLE falas(book INTEGER, chapter INTEGER, verse INTEGER, quem TEXT, ini REAL, fim REAL);
    -- referências codificadas como livro*1000000 + capítulo*1000 + versículo
    CREATE TABLE vinculos(ref INTEGER, alvo INTEGER, fim INTEGER, votos INTEGER, PRIMARY KEY(ref, alvo, fim)) WITHOUT ROWID;
    CREATE TABLE nomes(id INTEGER PRIMARY KEY, grupo TEXT, tipo TEXT, nome_en TEXT, nome_pt TEXT, resumo_en TEXT,
                       resumo_pt TEXT, artigo_en TEXT, artigo_pt TEXT, pais TEXT, irmaos TEXT, conjuges TEXT,
                       filhos TEXT, total INTEGER);
    CREATE TABLE intros(book INTEGER, chapter INTEGER, texto TEXT, PRIMARY KEY(book, chapter));
    CREATE TABLE nome_refs(nome INTEGER, book INTEGER, chapter INTEGER, verse INTEGER);
    ''')
    db.execute("INSERT INTO meta VALUES('schema','1')")
    db.execute("INSERT INTO meta VALUES('perfil',?)", (PERFIL['nome'],))
    # versões que marcam as falas com aspas e fonte das notas de estudo (o app lê daqui, sem ids fixos)
    db.execute("INSERT INTO meta VALUES('versoes_aspas',?)", (','.join(VERSOES_ASPAS),))
    db.execute("INSERT INTO meta VALUES('notas_fonte',?)", (NOTAS_FONTE,))
    versoes = [v for v in EXTRA_VERSIONS + VERSIONS if v[0] in PERFIL['versoes']]
    print(f"perfil: {PERFIL['nome']} ({len(versoes)} versões)")

    verse_rows = []
    T = os.path.join(ROOT, '..', 'textos')
    TP = os.path.join(ROOT, '..', 'textos-publicos')
    leitores = {
        'markdown': lambda arqs: markdown_bible(os.path.join(T, arqs[0])),
        'verse_markdown': lambda arqs: verse_markdown_bible([os.path.join(T, x) for x in arqs]),
        'tsv': lambda arqs: tsv_bible(os.path.join(T, arqs[0])),
    }
    sources = {k: (lambda f=f: leitores[f['tipo']](f['arquivos'])) for k, f in EXTRA_FONTES.items()}
    sources.update({
        'arc1911': lambda: tsv_bible(os.path.join(TP, 'arc1911.tsv')),
        'bl': lambda: tsv_bible(os.path.join(TP, 'bl.tsv')),
        'kjv': lambda: scrollmapper('KJV'),
    })
    for i, v in enumerate(versoes):
        db.execute('INSERT INTO versions VALUES(?,?,?,?,?,?,?)', (*v, i))
        n = 0
        for b, c, vs, t in sources[v[0]]():
            verse_rows.append((v[0], b, c, vs, t))
            n += 1
        print(f'{v[0]}: {n} versículos')
    verse_rows.sort(key=lambda r: (r[1], r[2], r[3], r[0]))
    db.executemany('INSERT INTO verses(version,book,chapter,verse,text) VALUES(?,?,?,?,?)', verse_rows)
    db.executemany('INSERT INTO credits VALUES(?,?)',
                   [c for c in EXTRA_CREDITS + CREDITS if c[0] not in PERFIL['creditos_excluir']])
    img_dir = os.path.join(T, 'notas-nvi-img')
    notas = list(study_notes(os.path.join(T, 'notas-nvi.tsv'))) if PERFIL['notas_estudo'] else []
    db.executemany('INSERT INTO notas(book, ini, fim, rotulo, html) VALUES(?,?,?,?,?)', notas)
    intros = []
    for line in open(os.path.join(T, 'intros.tsv'), encoding='utf-8') if PERFIL['introducoes'] else []:
        b, c, x = line.rstrip('\n').split('\t', 2)
        intros.append((int(b), int(c), x.replace('\\n', '\n')))
    db.executemany('INSERT INTO intros VALUES(?,?,?)', intros)
    print(f'resumos de livros e capítulos: {len(intros)}')
    imagens = [(int(os.path.splitext(f)[0]), open(os.path.join(img_dir, f), 'rb').read()) for f in sorted(os.listdir(img_dir))] if PERFIL['notas_estudo'] else []
    db.executemany('INSERT INTO imagens VALUES(?,?)', imagens)
    print(f'notas de estudo: {len(notas)}, imagens: {len(imagens)}')

    chapters = {}
    for _, b, c, _, _ in verse_rows:
        chapters[b] = max(chapters.get(b, 0), c)
    for i, (code, _, name) in enumerate(BOOKS):
        db.execute('INSERT INTO books VALUES(?,?,?,?,?)', (i + 1, code, name, 'AT' if i < 39 else 'NT', chapters[i + 1]))

    en2pt = load_en2pt() if PERFIL['traducoes_pt'] else {}
    words = [(w['book'], w['ch'], w['v'], w['pos'], 'he', w['text'], w['translit'], w['gloss'], w['strong'],
              w['strongs'], w['morph_full'], w['ed'], gloss_to_pt(w['gloss'], en2pt)) for w in hebrew_words()]
    words += [(w['book'], w['ch'], w['v'], w['pos'], 'gr', w['text'], w['translit'], w['gloss'], w['strong'],
               w['strongs'], w['morph'], w['ed'], gloss_to_pt(w['gloss'], en2pt)) for w in greek_words()]
    db.executemany('INSERT INTO words VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)', words)
    print(f'palavras do original: {len(words)}, {sum(1 for w in words if w[12])} com glosa em português')

    pt_gloss = load_pt_glosses() if PERFIL['traducoes_pt'] else {}
    pt_defs = load_pt_defs() if PERFIL['traducoes_pt'] else {}
    lexd = os.path.join(SRC, 'step', 'Lexicons')
    lex_rows = {}
    lex_rows.update(lexicon(glob.glob(os.path.join(lexd, 'TBESH*.txt'))[0], 'H'))
    lex_rows.update(lexicon(glob.glob(os.path.join(lexd, 'TBESG*.txt'))[0], 'G'))
    needed = set()
    for w in words:
        needed.update(w[9].split())
        if w[8]:
            needed.add(w[8])
    lex_out, missing = [], 0
    for k in sorted(needed):
        c = lex_rows.get(k) or lex_rows.get(k + 'G') or lex_rows.get(k[:5] + 'G') or lex_rows.get(k[:5]) \
            or lex_rows.get(k[:5] + 'A')
        if not c:
            missing += 1
            continue
        d = clean_html(c[7]) or clean_html((lex_rows.get(c[2]) or c)[7])
        dpt = pt_defs.get(k) or pt_defs.get(c[2]) or ''
        lex_out.append((k, c[3], c[4], c[6], pt_gloss.get(k) or pt_gloss.get(c[2]) or en2pt.get(c[6]) or '', d, dpt))
    db.executemany('INSERT INTO lexicon VALUES(?,?,?,?,?,?,?)', lex_out)
    have_pt = sum(1 for r in lex_out if r[4])
    have_def = sum(1 for r in lex_out if r[6])
    print(f'léxico: {len(lex_out)} verbetes, {have_pt} com significado e {have_def} com definição em português, '
          f'{missing} sem verbete')

    mt = morph_table(load_json('morph_values.json', {}))
    used = {seg for w in words if w[10] for seg in w[10].split('/')}
    rows = [(code, *mt[code]) for code in used if code in mt]
    db.executemany('INSERT OR IGNORE INTO morph VALUES(?,?,?)', rows)
    print(f'códigos de morfologia: {len(rows)} de {len(used)}')

    falas = speech_segments()
    db.executemany('INSERT INTO falas VALUES(?,?,?,?,?,?)', falas)
    print(f"falas: {sum(1 for f in falas if f[3] == 'D')} trechos de Deus, {sum(1 for f in falas if f[3] == 'J')} de Jesus")

    xrefs = cross_references()
    db.executemany('INSERT OR IGNORE INTO vinculos VALUES(?,?,?,?)',
                   [(b * 1000000 + c * 1000 + v, tb * 1000000 + tc * 1000 + tv, tb * 1000000 + ec * 1000 + ev, n)
                    for b, c, v, tb, tc, tv, ec, ev, n in xrefs])
    print(f'vínculos: {len(xrefs)}')

    names = proper_names()
    pt_names = {}
    for line in open(os.path.join(PT, 'nomes.tsv'), encoding='utf-8') if PERFIL['traducoes_pt'] and os.path.exists(os.path.join(PT, 'nomes.tsv')) else []:
        c = line.rstrip('\n').split('\t')
        if len(c) >= 3 and not c[0].startswith('#'):
            pt_names[c[0]] = c[1:]
    ids = {r['key']: i + 1 for i, r in enumerate(names)}
    rows, refs = [], []
    for i, r in enumerate(names, 1):
        fam = {k: ' '.join(str(ids[name_key(x)]) for x in re.split(r'[,+]', v) if name_key(x) in ids)
               for k, v in r['family'].items()}
        pt = pt_names.get(r['key'], []) + ['', '', '']
        grupo = {'PERSON': 'pessoa', 'OTHER': 'outro'}.get(r['sect'], 'lugar')
        rows.append((i, grupo, r['kind'], r['name'], pt[0], clean_html(r['short']), pt[1],
                     clean_html(r['article'].replace('<BR>', '\n')), clean_html(pt[2].replace('<BR>', '\n')),
                     fam.get('pais', ''), fam.get('irmaos', ''), fam.get('conjuges', ''), fam.get('filhos', ''), len(r['refs'])))
        refs.extend((i, *x) for x in sorted(r['refs']))
    db.executemany('INSERT INTO nomes VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)', rows)
    db.executemany('INSERT INTO nome_refs VALUES(?,?,?,?)', refs)
    print(f'nomes próprios: {len(rows)} ({sum(1 for r in rows if r[4])} em português), {len(refs)} referências')

    db.executescript('''
    CREATE INDEX nome_refs_ref ON nome_refs(book, chapter, verse);
    CREATE INDEX nome_refs_nome ON nome_refs(nome);
    CREATE INDEX notas_ref ON notas(book, ini);
    CREATE INDEX falas_ref ON falas(book, chapter);
    CREATE INDEX verses_ref ON verses(book, chapter, version);
    CREATE INDEX words_ref ON words(book, chapter, verse);
    CREATE INDEX words_strong ON words(strong);
    CREATE VIRTUAL TABLE verses_fts USING fts5(text, content='verses', content_rowid='id',
        tokenize='unicode61 remove_diacritics 2');
    INSERT INTO verses_fts(rowid, text) SELECT id, text FROM verses;
    INSERT INTO verses_fts(verses_fts) VALUES('optimize');
    ''')
    db.commit()
    db.execute('VACUUM')
    db.close()
    print(f'banco gerado: {out} ({os.path.getsize(out) // 1024 // 1024} MB)')


if __name__ == '__main__':
    main()

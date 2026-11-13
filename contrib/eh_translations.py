#!/usr/bin/env python3
"""Schȅi Wallet: write the table of all the app's own texts (Italian, Venetian, English).

It reads electrum/eh_strings.py (the app's translations) without importing it and writes:
  TRADUZIONI.md   — the table GitHub shows (searchable with Ctrl+F)
  traduzioni.csv  — the same table for Excel / LibreOffice (UTF-8, ; separated)
The English text is the source text used in the app's code (qsTr). A missing translation
is marked, and in the app it falls back (Venetian -> Italian -> English).

Run from the repository root:  python3 contrib/eh_translations.py
The GitHub workflow .github/workflows/translations.yml runs it on every change of
electrum/eh_strings.py and saves the result.
"""
import ast
import csv
import io
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, 'electrum', 'eh_strings.py')
LANGS = [('it_IT', 'Italiano'), ('vec_IT', 'Veneto')]


def load():
    tree = ast.parse(open(SRC, encoding='utf-8').read())
    for node in ast.walk(tree):
        if isinstance(node, ast.Dict) and any(isinstance(k, ast.Constant) and k.value == 'it_IT' for k in node.keys):
            out = {}
            for k, v in zip(node.keys, node.values):
                if isinstance(k, ast.Constant) and isinstance(v, ast.Dict):
                    out[k.value] = {kk.value: vv.value for kk, vv in zip(v.keys, v.values)
                                    if isinstance(kk, ast.Constant) and isinstance(vv, ast.Constant)}
            return out
    sys.exit('no translation table found in ' + SRC)


def plain(s):
    return re.sub(r'<[^>]+>', '', s)


def md_cell(s):
    if s is None:
        return '❌ *manca*'
    s = s.replace('\\', '\\\\').replace('|', '\\|').replace('\n', '<br>')
    return s


def main():
    data = load()
    keys = []
    for code, _ in LANGS:
        for k in data.get(code, {}):
            if k not in keys:
                keys.append(k)
    keys.sort(key=lambda s: plain(s).lower())
    missing = {code: sum(1 for k in keys if k not in data.get(code, {})) for code, _ in LANGS}

    md = io.StringIO()
    md.write('# Traduzioni di Schȅi Wallet\n\n')
    md.write('Tutti i testi dell\'app in **italiano**, **veneto** e **inglese**. '
             'Questo file si aggiorna da solo a ogni modifica delle traduzioni '
             '(`electrum/eh_strings.py`): non modificarlo a mano.\n\n')
    md.write('- Frasi: **%d**' % len(keys))
    for code, name in LANGS:
        md.write(' · mancano in %s: **%d**' % (name.lower(), missing[code]))
    md.write('\n- La colonna **Inglese** è il testo di partenza scritto nel codice; '
             '`%1`, `%2` vengono sostituiti da un numero, una cifra o un nome.\n')
    md.write('- Se una frase manca, l\'app usa quella di un\'altra lingua (veneto → italiano → inglese).\n')
    md.write('- Per proporre una correzione: apri una *Issue* o una *Pull request* che cambia `electrum/eh_strings.py`.\n')
    md.write('- Versione da aprire con Excel / LibreOffice: [`traduzioni.csv`](traduzioni.csv).\n\n')
    md.write('| # | Italiano | Veneto | Inglese |\n|---:|---|---|---|\n')
    for i, k in enumerate(keys, 1):
        md.write('| %d | %s | %s | %s |\n' % (i, md_cell(data['it_IT'].get(k)), md_cell(data['vec_IT'].get(k)), md_cell(k)))
    with open(os.path.join(ROOT, 'TRADUZIONI.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(md.getvalue())

    with open(os.path.join(ROOT, 'traduzioni.csv'), 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f, delimiter=';', lineterminator='\n')
        w.writerow(['#', 'Italiano', 'Veneto', 'Inglese'])
        for i, k in enumerate(keys, 1):
            w.writerow([i, data['it_IT'].get(k, ''), data['vec_IT'].get(k, ''), k])
    print('TRADUZIONI.md and traduzioni.csv: %d texts, missing %s' % (len(keys), missing))


if __name__ == '__main__':
    main()

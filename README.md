# Bíblia Local

Leitor da Bíblia que funciona sem internet, para Android, Windows e web (PWA).

- **Versões:** Almeida Corrigida 1911 (domínio público), Bíblia Livre (CC BY 3.0 BR) e King James (inglês, domínio público).
- **Originais:** hebraico e grego palavra por palavra, com análise gramatical e léxico (STEPBible, CC BY 4.0).
- **Recursos:** um capítulo por página, comparação entre versões, busca sem acento, marcadores e anotações, falas de Deus e de Jesus em cores, referências cruzadas, pessoas e lugares.

## Baixar

Cada envio para a branch `main` gera uma versão em **Releases**, com o APK do Android e o instalador do Windows.

## Como funciona

1. `tools/fetch_sources.sh` baixa as fontes (STEPBible, scrollmapper, BibleNLP, Clear-Bible).
2. `tools/build_db.py` monta um banco SQLite com os textos, as palavras do original, os léxicos e a busca.
3. O app Flutter (`app/`) leva o banco compactado e o abre no aparelho na primeira execução.

## Licenças

Veja a tela **Sobre e licenças** no app. Textos e dados: ARC 1911 (domínio público), Bíblia Livre (CC BY 3.0 BR), King James (domínio público), STEPBible, MACULA e OpenBible (CC BY). As glosas e os resumos em português foram traduzidos por IA a partir dos dados da STEPBible e não foram revisados por humanos.

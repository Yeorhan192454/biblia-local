#!/usr/bin/env bash
# Baixa as fontes de texto (todas no GitHub) para tools/sources/.
set -euo pipefail
cd "$(dirname "$0")/sources"

sparse() { # repo dir paths...
  local repo=$1 dir=$2; shift 2
  if [ ! -d "$dir/.git" ]; then
    git clone --depth 1 --filter=blob:none --no-checkout "https://github.com/$repo.git" "$dir"
  fi
  git -C "$dir" checkout HEAD -- "$@"
}

sparse STEPBible/STEPBible-Data step \
  "Translators Amalgamated OT+NT" Lexicons "Morphology codes" "Proper Nouns"
sparse scrollmapper/bible_databases scrollmapper \
  formats/csv/PorNVA.csv formats/csv/KJV.csv sources/extras/cross_references.txt
sparse BibleNLP/ebible biblenlp \
  metadata/vref.txt corpus/por-porbrbsl.txt corpus/por-portft.txt
sparse Clear-Bible/speaker-quotations quotes \
  tsv/alignment-quotations-clear.tsv tsv/Clear-Aligned-Projections.tsv
echo "Fontes prontas em $(pwd)"

#!/usr/bin/env bash
# HEIMDALL - prepara la web estática para GitHub Pages. Uso: site/construir.sh [carpeta-destino]
# Copia site/ y las imágenes de docs/img (en <destino>/img). Por defecto, _site/.
set -euo pipefail
cd "$(dirname "$0")/.."
DESTINO="${1:-_site}"
rm -rf "$DESTINO"
mkdir -p "$DESTINO/img"
cp -r site/. "$DESTINO/"
rm -f "$DESTINO/construir.sh"
cp -r docs/img/. "$DESTINO/img/"
touch "$DESTINO/.nojekyll"
echo "Web preparada en $DESTINO"

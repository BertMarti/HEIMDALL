#!/usr/bin/env bash
# HEIMDALL - actualizar a la última versión. Uso: ./update.sh
set -euo pipefail
cd "$(dirname "$0")"
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"

echo "==> Haciendo copia de seguridad antes de actualizar..."
./backup.sh
echo "==> Descargando cambios del repositorio..."
git pull --ff-only
echo "==> Descargando imágenes nuevas..."
$DOCKER compose pull
echo "==> Aplicando..."
./install.sh
$DOCKER image prune -f >/dev/null
echo "HEIMDALL actualizado."

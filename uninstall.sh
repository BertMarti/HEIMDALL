#!/usr/bin/env bash
# HEIMDALL - desinstalador. Uso: ./uninstall.sh [--purge]
#   --purge  borra también las claves y clientes de la VPN (carpeta data/) y el .env
set -euo pipefail
cd "$(dirname "$0")"
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"

$DOCKER compose --profile ddns down
echo "Contenedores de HEIMDALL detenidos y eliminados."

if [ "${1:-}" = "--purge" ]; then
  sudo rm -rf data .env
  echo "Datos y .env eliminados: los perfiles VPN de tus dispositivos dejarán de funcionar."
fi

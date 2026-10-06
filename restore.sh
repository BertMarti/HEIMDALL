#!/usr/bin/env bash
# HEIMDALL - restaurar una copia. Uso: ./restore.sh backups/heimdall-AAAAMMDD-HHMM.tar.gz
# Sustituye la configuración actual por la de la copia (servidor, dispositivos y .env).
# Útil tras formatear: clona el repo, copia aquí el archivo de copia y ejecuta este script.
set -euo pipefail
cd "$(dirname "$0")"
COPIA="${1:-}"
[ -f "$COPIA" ] || { echo "Uso: ./restore.sh <archivo.tar.gz>" >&2; exit 1; }
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"

read -r -p "Se reemplazará la configuración actual de HEIMDALL por la de $COPIA. ¿Continuar? [s/N] " r
[[ "$r" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }

$DOCKER compose --profile ddns down 2>/dev/null || true
sudo rm -rf data/wireguard data/caddy
sudo tar -xzf "$COPIA" -C .
sudo chown "$(id -u):$(id -g)" .env; chmod 600 .env
echo "Copia restaurada. Arrancando..."
./install.sh

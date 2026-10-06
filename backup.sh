#!/usr/bin/env bash
# HEIMDALL - copia de seguridad. Uso: ./backup.sh
# Guarda .env, la base de datos de wg-easy (servidor y dispositivos) y la CA de Caddy en
# backups/heimdall-AAAAMMDD-HHMM.tar.gz. Conserva las 7 más recientes.
# IMPORTANTE: contiene las claves privadas de la VPN. Guárdala en un sitio seguro.
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo "No hay .env: ¿está instalado HEIMDALL?" >&2; exit 1; }
[ -f data/wireguard/wg-easy.db ] || { echo "No hay datos de wg-easy todavía." >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'sudo rm -rf "$TMP"' EXIT
mkdir -p "$TMP/data/wireguard" backups
# Copia consistente de SQLite aunque wg-easy esté en marcha
sudo python3 -c "import sqlite3,sys; s=sqlite3.connect(sys.argv[1]); d=sqlite3.connect(sys.argv[2]); s.backup(d); d.close(); s.close()" \
  data/wireguard/wg-easy.db "$TMP/data/wireguard/wg-easy.db"
sudo cp -a data/caddy "$TMP/data/caddy" 2>/dev/null || true
cp .env "$TMP/.env"

ARCHIVO="backups/heimdall-$(date +%Y%m%d-%H%M).tar.gz"
sudo tar -czf "$ARCHIVO" -C "$TMP" .env data
sudo chown "$(id -u):$(id -g)" "$ARCHIVO"; chmod 600 "$ARCHIVO"
ls -1t backups/heimdall-*.tar.gz | tail -n +8 | xargs -r rm -f
echo "Copia creada: $(pwd)/$ARCHIVO ($(du -h "$ARCHIVO" | cut -f1))"

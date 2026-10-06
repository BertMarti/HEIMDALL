#!/usr/bin/env bash
# HEIMDALL - instalador. Uso: ./install.sh
set -euo pipefail
cd "$(dirname "$0")"

info()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✔\033[0m  %s\n' "$*"; }
aviso() { printf '\033[1;33m!\033[0m  %s\n' "$*"; }
fallo() { printf '\033[1;31m✘\033[0m  %s\n' "$*" >&2; exit 1; }

set_env() { # set_env CLAVE VALOR  (solo si está vacía)
  if ! grep -qE "^$1=.+" .env; then
    if grep -qE "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
    ok "$1 = $([ "$1" = WG_ADMIN_PASSWORD ] && echo '(generada)' || echo "$2")"
  fi
}

# 1. Docker
if ! command -v docker >/dev/null 2>&1; then
  info "Docker no está instalado. Instalando con el script oficial (get.docker.com)..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
fi
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"
$DOCKER compose version >/dev/null 2>&1 || fallo "Falta el plugin 'docker compose'."
ok "Docker disponible"

# 2. Módulo WireGuard del kernel
sudo modprobe wireguard 2>/dev/null || aviso "No se pudo cargar el módulo wireguard (puede que esté integrado en el kernel)."

# 3. .env
[ -f .env ] || { cp .env.example .env; ok "Creado .env"; }
set -a; . ./.env; set +a

LAN_IP_DET="$(hostname -I | awk '{print $1}')"
set_env LAN_IP "$LAN_IP_DET"
set_env PI_HOSTNAME "$(hostname | tr '[:upper:]' '[:lower:]')"
set_env WG_ADMIN_PASSWORD "$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-20)"

if [ -n "${DUCKDNS_SUBDOMAIN:-}" ]; then
  set_env WG_HOST "${DUCKDNS_SUBDOMAIN}.duckdns.org"
else
  PUB_IP="$(curl -fsS --max-time 10 https://api.ipify.org || true)"
  [ -n "$PUB_IP" ] || fallo "No pude averiguar tu IP pública. Rellena WG_HOST en .env y repite."
  set_env WG_HOST "$PUB_IP"
fi

# DNS de la VPN: SHIELD-DNS si responde en esta Pi
if [ -z "${WG_DNS:-}" ]; then
  if $DOCKER ps --format '{{.Names}}' | grep -qx shield-pihole; then
    set_env WG_DNS "$LAN_IP_DET"
  else
    set_env WG_DNS "1.1.1.1"
    aviso "SHIELD-DNS no está instalado: la VPN usará 1.1.1.1 (sin bloqueo de anuncios)."
  fi
fi
chmod 600 .env
set -a; . ./.env; set +a

if [ -d data/wireguard ] && [ -n "$(ls -A data/wireguard 2>/dev/null)" ]; then
  aviso "HEIMDALL ya estaba configurado: los cambios de WG_* en .env no se aplican (usa la web)."
fi
mkdir -p data/wireguard data/caddy

# 4. Arranque
PERFILES=""
if [ -n "${DUCKDNS_SUBDOMAIN:-}" ] && [ -n "${DUCKDNS_TOKEN:-}" ]; then PERFILES="--profile ddns"; fi
info "Arrancando contenedores..."
$DOCKER compose $PERFILES up -d

info "Esperando al panel web..."
for i in $(seq 1 40); do
  code="$(curl -sk -o /dev/null -w '%{http_code}' "https://${LAN_IP}:${WEB_PORT:-51843}/" || true)"
  [[ "$code" =~ ^(200|302)$ ]] && break
  sleep 3
done
[[ "$code" =~ ^(200|302)$ ]] || fallo "El panel no responde (HTTP $code). Revisa: docker compose logs"
ok "Panel web funcionando"

cat <<EOF

────────────────────────────────────────────────────────
 HEIMDALL instalado
   Panel web:   https://${LAN_IP}:${WEB_PORT:-51843}
                (certificado autofirmado: acepta el aviso del navegador)
   Usuario:     ${WG_ADMIN_USER:-admin}
   Contraseña:  la variable WG_ADMIN_PASSWORD de $(pwd)/.env
   Servidor:    ${WG_HOST}:${WG_PORT:-51820}/udp
   DNS de la VPN: ${WG_DNS}

 IMPRESCINDIBLE para conectarte desde fuera de casa:
   En tu router, redirige el puerto ${WG_PORT:-51820} UDP hacia ${LAN_IP}.

 Para añadir un dispositivo: entra en el panel → "Nuevo cliente"
 → escanea el QR con la app WireGuard del móvil/TV o descarga el .conf.
────────────────────────────────────────────────────────
EOF

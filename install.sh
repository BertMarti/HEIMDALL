#!/usr/bin/env bash
# HEIMDALL - instalador. Uso: ./install.sh [--comprobar | --sin-preguntas | --ayuda]
set -euo pipefail
cd "$(dirname "$0")"

info()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✔\033[0m  %s\n' "$*"; }
aviso() { printf '\033[1;33m!\033[0m  %s\n' "$*"; }
mal()   { printf '\033[1;31m✘\033[0m  %s\n' "$*" >&2; }
fallo() { mal "$*"; exit 1; }

uso() {
  cat <<'EOF'
HEIMDALL: tu propia VPN WireGuard (wg-easy) para entrar en casa desde cualquier sitio.

Uso:
  ./install.sh                  instala (o aplica la configuración) y arranca HEIMDALL
  ./install.sh --comprobar      solo comprueba los requisitos; no cambia nada
  ./install.sh --sin-preguntas  instala con los valores por defecto, sin preguntar nada
  ./install.sh --ayuda          muestra esta ayuda

La primera vez (sin .env) hace tres preguntas. Si .env ya existe no pregunta nada
(así lo usa ./update.sh).
EOF
}

MODO="instalar"; PREGUNTAR="auto"
while [ $# -gt 0 ]; do
  case "$1" in
    --comprobar) MODO="comprobar" ;;
    --sin-preguntas|-y) PREGUNTAR="no" ;;
    -h|--ayuda|--help) uso; exit 0 ;;
    *) mal "Opción desconocida: $1"; uso >&2; exit 2 ;;
  esac
  shift
done

# --- Utilidades -----------------------------------------------------------------------------------
# Contraseña segura de 24 caracteres alfanuméricos (sin símbolos: no hay que escaparla en .env).
generar_clave() { head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-24; }

# Lee una variable de .env sin ejecutarlo (vacío si no existe).
leer_env() { [ -f .env ] && grep -E "^$1=" .env | tail -n1 | cut -d= -f2- | sed -E 's/^"(.*)"$/\1/' || true; }

# Escribe CLAVE=VALOR en .env (sustituye la línea o la añade). Con awk: el valor no se interpreta.
poner_env() {
  local tmp; tmp="$(mktemp .env.XXXXXX)"
  CLAVE="$1" VALOR="$2" awk 'BEGIN{c=ENVIRON["CLAVE"]; v=ENVIRON["VALOR"]; hecho=0}
    index($0, c "=")==1 {print c "=" v; hecho=1; next} {print}
    END{if(!hecho) print c "=" v}' .env > "$tmp"
  chmod 600 "$tmp"; mv "$tmp" .env
}
# Solo si está vacía o no existe; muestra el valor (salvo contraseñas y tokens).
rellenar_env() {
  [ -n "$(leer_env "$1")" ] && return 0
  poner_env "$1" "$2"
  case "$1" in *PASSWORD*|*TOKEN*) ok "$1 = (generada)" ;; *) ok "$1 = $2" ;; esac
}

ip_lan()     { hostname -I 2>/dev/null | awk '{print $1}'; }
ip_router()  { ip -4 route show default 2>/dev/null | awk '{print $3; exit}'; }
ip_publica() { curl -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true; }
zona_horaria() {
  local tz
  tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  [ -n "$tz" ] || tz="$(cat /etc/timezone 2>/dev/null || true)"
  printf '%s' "${tz:-Europe/Madrid}"
}
puerto_valido() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }

# Puerto alternativo para sugerir (el siguiente, o el anterior si ya es el último).
otro_puerto() { if [ "$1" -lt 65535 ]; then echo $(($1 + 1)); else echo $(($1 - 1)); fi; }

# Sockets que escuchan en tcp|udp PUERTO (una línea de `ss` por socket).
escuchando() {
  local opc="-tlnH"; [ "$1" = udp ] && opc="-ulnH"
  { ss "$opc" 2>/dev/null || true; } | awk -v p="$2" '{n = split($4, a, ":"); if (a[n] == p) print}'
}

contenedor_activo() {
  local nombres; nombres="$($DOCKER ps --format '{{.Names}}' 2>/dev/null || true)"
  grep -qx "$1" <<<"$nombres"
}

# --- Comprobación de requisitos ---------------------------------------------------------------------
PROBLEMAS=0
problema() { mal "$1"; shift; local l; for l in "$@"; do printf '     %s\n' "$l" >&2; done; PROBLEMAS=$((PROBLEMAS + 1)); }

comprobar_docker() {
  DOCKER=""
  if ! command -v docker >/dev/null 2>&1; then
    problema "Docker no está instalado." \
      "Instálalo con:  curl -fsSL https://get.docker.com | sh" \
      "y después:      sudo usermod -aG docker \$USER   (cierra sesión y vuelve a entrar)" \
      "(./install.sh sin --comprobar lo instala por ti)."
    return
  fi
  if docker info >/dev/null 2>&1; then
    DOCKER="docker"
  elif sudo -n docker info >/dev/null 2>&1 || { [ "$MODO" = instalar ] && sudo docker info >/dev/null 2>&1; }; then
    DOCKER="sudo docker"
  else
    problema "Docker está instalado pero no responde (o tu usuario no tiene permiso)." \
      "Arráncalo:     sudo systemctl enable --now docker" \
      "Dale permiso:  sudo usermod -aG docker \$USER   (cierra sesión y vuelve a entrar)"
    return
  fi
  ok "Docker funciona"
  if $DOCKER compose version >/dev/null 2>&1; then
    ok "Docker Compose v2 disponible"
  else
    problema "Falta Docker Compose v2 (el comando 'docker compose')." \
      "Instálalo con:  sudo apt install -y docker-compose-plugin"
  fi
}

comprobar_arquitectura() {
  local arq
  arq="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  case "$arq" in
    arm64|aarch64|amd64|x86_64) ok "Arquitectura compatible ($arq)" ;;
    armhf|armv7l|armel|armv6l)
      problema "Sistema de 32 bits ($arq): wg-easy 15 solo funciona en sistemas de 64 bits." \
        "En una Raspberry Pi 3, 4 o 5, instala «Raspberry Pi OS (64-bit)» con Raspberry Pi Imager." ;;
    *) problema "Arquitectura no compatible: $arq." "HEIMDALL necesita un equipo arm64 o amd64 (64 bits)." ;;
  esac
}

comprobar_herramientas() {
  if command -v curl >/dev/null 2>&1; then ok "curl disponible"
  else problema "Falta curl (sirve para averiguar tu IP pública y comprobar el panel)." "Instálalo con:  sudo apt install -y curl"
  fi
  if [ -d /sys/module/wireguard ] || modinfo wireguard >/dev/null 2>&1; then ok "Módulo WireGuard del kernel disponible"
  else aviso "No veo el módulo WireGuard del kernel; normalmente se carga solo al arrancar."
  fi
}

comprobar_puertos() {
  if ! command -v ss >/dev/null 2>&1; then
    aviso "No puedo comprobar los puertos: falta 'ss' (instálalo con: sudo apt install -y iproute2)."
    return
  fi
  local wg web
  wg="$(leer_env WG_PORT)"; wg="${wg:-51820}"
  web="$(leer_env WEB_PORT)"; web="${web:-51843}"
  if ! puerto_valido "$wg"; then
    problema "WG_PORT=$wg no es un puerto válido." "Pon un número entre 1 y 65535 en .env (por defecto, 51820)."
  elif [ -n "${DOCKER:-}" ] && contenedor_activo heimdall-wg; then
    ok "Puerto $wg/udp: lo usa HEIMDALL, que ya está en marcha"
  elif [ -n "$(escuchando udp "$wg")" ]; then
    problema "El puerto $wg/udp (VPN) está ocupado por otro servicio." \
      "Mira cuál es con:  sudo ss -ulpn | grep ':$wg '" \
      "o elige otro en .env (p. ej. WG_PORT=$(otro_puerto "$wg")) y redirige ese en el router."
  else
    ok "Puerto $wg/udp (VPN) libre"
  fi
  if ! puerto_valido "$web"; then
    problema "WEB_PORT=$web no es un puerto válido." "Pon un número entre 1 y 65535 en .env (por defecto, 51843)."
  elif [ -n "${DOCKER:-}" ] && contenedor_activo heimdall-caddy; then
    ok "Puerto $web/tcp: lo usa HEIMDALL, que ya está en marcha"
  elif [ -n "$(escuchando tcp "$web")" ]; then
    problema "El puerto $web/tcp (panel web) está ocupado por otro servicio." \
      "Mira cuál es con:  sudo ss -tlpn | grep ':$web '" \
      "o elige otro en .env (p. ej. WEB_PORT=$(otro_puerto "$web"))."
  else
    ok "Puerto $web/tcp (panel web) libre"
  fi
}

comprobar_todo() { comprobar_docker; comprobar_arquitectura; comprobar_herramientas; comprobar_puertos; }

# --- Modo --comprobar: solo informa, no cambia nada -------------------------------------------------
if [ "$MODO" = comprobar ]; then
  info "Comprobando los requisitos de HEIMDALL (no se cambia nada)..."
  comprobar_todo
  if [ "$PROBLEMAS" -eq 0 ]; then
    ok "Todo listo. Instala con: ./install.sh"
    exit 0
  fi
  mal "Hay $PROBLEMAS problema(s). Arréglalos con las instrucciones de arriba y repite: ./install.sh --comprobar"
  exit 1
fi

# --- 1. Requisitos ----------------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  info "Docker no está instalado. Instalando con el script oficial (get.docker.com)..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
fi
info "Comprobando requisitos..."
comprobar_todo
[ "$PROBLEMAS" -eq 0 ] || fallo "Todavía no se puede instalar: arregla lo de arriba y repite ./install.sh"
sudo modprobe wireguard 2>/dev/null || aviso "No se pudo cargar el módulo wireguard (puede que esté integrado en el kernel)."

# --- 2. Configuración (.env) --------------------------------------------------------------------------
CLAVE_GENERADA=""
ASISTENTE="no"
if [ ! -f .env ]; then
  (umask 077; cp .env.example .env)
  poner_env TZ "$(zona_horaria)"
  ok "Creado .env (solo lo puede leer tu usuario)"
  if [ "$PREGUNTAR" = auto ] && [ -t 0 ] && [ -t 1 ]; then ASISTENTE="si"; fi
fi
chmod 600 .env

if [ "$ASISTENTE" = si ]; then
  printf '\n\033[1mConfiguración rápida\033[0m (Enter acepta lo que va entre corchetes)\n\n'
  clave=""; otra=""; resp=""
  for _ in 1 2 3; do
    read -rsp "1/3 Contraseña para el panel de la VPN [Enter = generar una segura]: " clave || true; echo
    [ -z "$clave" ] && break
    if [ "${#clave}" -lt 12 ]; then aviso "Debe tener al menos 12 caracteres."; clave=""; continue; fi
    if [[ ! "$clave" =~ ^[A-Za-z0-9._@%+=,:!*^-]+$ ]]; then
      aviso "Usa solo letras, números y estos símbolos: . _ - @ % + = , : ! * ^"; clave=""; continue
    fi
    read -rsp "    Repítela: " otra || true; echo
    [ "$clave" = "$otra" ] && break
    aviso "No coinciden."; clave=""
  done
  if [ -n "$clave" ]; then poner_env WG_ADMIN_PASSWORD "$clave"; ok "Contraseña guardada en .env"; fi
  unset clave otra

  detectada="$(ip_publica)"
  echo "2/3 ¿Con qué dirección te conectarás desde fuera de casa?"
  echo "    Si tienes un dominio gratuito de DuckDNS, escríbelo (p. ej. micasa.duckdns.org)."
  for _ in 1 2 3; do
    read -rp "    Dirección [Enter = tu IP pública actual${detectada:+: $detectada}]: " resp || true
    resp="${resp:-$detectada}"
    if [[ "$resp" =~ ^[A-Za-z0-9.-]+$ ]]; then break; fi
    aviso "Escribe un dominio o una IP (solo letras, números, puntos y guiones)."; resp=""
  done
  if [ -n "$resp" ]; then
    poner_env WG_HOST "$resp"; ok "WG_HOST = $resp"
    if [[ "$resp" =~ ^([A-Za-z0-9-]+)\.duckdns\.org$ ]]; then
      poner_env DUCKDNS_SUBDOMAIN "${BASH_REMATCH[1]}"
      read -rsp "    Token de DuckDNS para mantener tu IP al día [Enter = ahora no]: " token || true; echo
      if [[ "$token" =~ ^[A-Za-z0-9-]+$ ]]; then poner_env DUCKDNS_TOKEN "$token"; ok "DuckDNS activado"; fi
      unset token
    fi
  fi
  for _ in 1 2 3; do
    read -rp "3/3 Puerto UDP de la VPN (el que abrirás en el router) [51820]: " resp || true
    resp="${resp:-51820}"
    if ! puerto_valido "$resp"; then aviso "Escribe un número entre 1 y 65535."; continue; fi
    if [ -n "$(escuchando udp "$resp")" ]; then aviso "El $resp/udp está ocupado; elige otro."; continue; fi
    poner_env WG_PORT "$resp"; ok "WG_PORT = $resp"; break
  done
fi

set -a
# shellcheck source=/dev/null
. ./.env
set +a

LAN_IP_DET="$(ip_lan)"
rellenar_env LAN_IP "$LAN_IP_DET"
rellenar_env PI_HOSTNAME "$(hostname | tr '[:upper:]' '[:lower:]')"
if [ -z "$(leer_env WG_ADMIN_PASSWORD)" ]; then
  CLAVE_GENERADA="$(generar_clave)"
  rellenar_env WG_ADMIN_PASSWORD "$CLAVE_GENERADA"
fi

# Dirección pública: solo se averigua si aún no hay ninguna (antes se consultaba siempre).
if [ -z "$(leer_env WG_HOST)" ]; then
  if [ -n "${DUCKDNS_SUBDOMAIN:-}" ]; then
    rellenar_env WG_HOST "${DUCKDNS_SUBDOMAIN}.duckdns.org"
  else
    PUB_IP="$(ip_publica)"
    [ -n "$PUB_IP" ] || fallo "No pude averiguar tu IP pública. Escribe tu dirección en WG_HOST de .env y repite ./install.sh"
    rellenar_env WG_HOST "$PUB_IP"
  fi
fi

# DNS de la VPN: SHIELD-DNS si está en marcha en esta máquina
if [ -z "$(leer_env WG_DNS)" ]; then
  if contenedor_activo shield-pihole; then
    rellenar_env WG_DNS "$LAN_IP_DET"
  else
    rellenar_env WG_DNS "1.1.1.1"
    aviso "SHIELD-DNS no está instalado: la VPN usará 1.1.1.1 (sin bloqueo de anuncios)."
  fi
fi
chmod 600 .env
set -a
# shellcheck source=/dev/null
. ./.env
set +a

if [ -d data/wireguard ] && [ -n "$(ls -A data/wireguard 2>/dev/null)" ]; then
  aviso "HEIMDALL ya estaba configurado: los cambios de WG_* en .env no se aplican (usa la web)."
fi
mkdir -p data/wireguard data/caddy

# --- 3. Arranque --------------------------------------------------------------------------------------
PERFILES=()
if [ -n "${DUCKDNS_SUBDOMAIN:-}" ] && [ -n "${DUCKDNS_TOKEN:-}" ]; then PERFILES=(--profile ddns); fi
info "Arrancando contenedores..."
$DOCKER compose "${PERFILES[@]}" up -d

info "Esperando al panel web..."
code=""
for _ in $(seq 1 40); do
  code="$(curl -sk -o /dev/null -w '%{http_code}' "https://${LAN_IP}:${WEB_PORT:-51843}/" || true)"
  [[ "$code" =~ ^(200|302)$ ]] && break
  sleep 3
done
[[ "$code" =~ ^(200|302)$ ]] || fallo "El panel no responde (HTTP $code). Mira qué pasa con: docker compose logs"
ok "Panel web funcionando"

# --- 4. Resumen y siguientes pasos -------------------------------------------------------------------------
ROUTER="$(ip_router)"; ROUTER="${ROUTER:-192.168.1.1}"
PUERTO="${WG_PORT:-51820}"
# La contraseña generada se muestra UNA sola vez y solo en una terminal (nunca en un registro).
if [ -n "$CLAVE_GENERADA" ] && [ -t 1 ]; then
  LINEA_CLAVE="${CLAVE_GENERADA}
                 ⚠ Guárdala ahora en tu gestor de contraseñas: no se volverá a mostrar.
                   (Queda en $(pwd)/.env, que solo puede leer tu usuario.)"
else
  LINEA_CLAVE="la de WG_ADMIN_PASSWORD en $(pwd)/.env   (grep WG_ADMIN_PASSWORD .env)"
fi
cat <<EOF

────────────────────────────────────────────────────────────────────
 ✔ HEIMDALL instalado
   Panel web:     https://${LAN_IP}:${WEB_PORT:-51843}
                  (certificado propio: acepta el aviso del navegador)
   Usuario:       ${WG_ADMIN_USER:-admin}
   Contraseña:    ${LINEA_CLAVE}
   Servidor VPN:  ${WG_HOST}:${PUERTO}/udp
   DNS de la VPN: ${WG_DNS}

 SIGUIENTES PASOS
 1. Abre el puerto de la VPN en el router (imprescindible para conectarte desde fuera):
    a) Entra en el router: http://${ROUTER}  (usuario y clave suelen ir en su pegatina).
    b) Busca «Redirección de puertos», «NAT», «Port forwarding» o «Servidores virtuales».
    c) Crea una regla: protocolo UDP, puerto externo ${PUERTO},
       IP interna ${LAN_IP}, puerto interno ${PUERTO}. Guarda.
    d) NO abras el ${WEB_PORT:-51843} (el panel): debe quedarse dentro de casa.
 2. Crea tu primer cliente: abre el panel → «Nuevo cliente» (New Client) →
    ponle un nombre (p. ej. «movil») → Crear.
 3. Escanea el QR: instala la app WireGuard (App Store o Google Play), toca «+» →
    «Escanear código QR» y apunta al QR del cliente en el panel. Activa el túnel.
 4. Pruébalo con el móvil SIN Wi-Fi (con datos): si en el panel aparece el último
    «handshake» del cliente, ya estás dentro de casa.
EOF
if [[ "${WG_HOST}" =~ ^[0-9.]+$ ]]; then
  cat <<EOF
 Consejo: tu IP pública puede cambiar. Con DuckDNS (gratis) tendrás un nombre fijo:
    rellena DUCKDNS_SUBDOMAIN y DUCKDNS_TOKEN en .env, repite ./install.sh y, en el
    panel (Administración), cambia el «Host» por tu-nombre.duckdns.org.
EOF
fi
echo "────────────────────────────────────────────────────────────────────"

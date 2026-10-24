#!/usr/bin/env bash
# Pruebas de install.sh SIN tocar nada real: cada caso copia el instalador a una carpeta temporal y
# lo ejecuta con un PATH aislado en el que docker, sudo, ss, curl, ip... son dobles de prueba.
# Nunca llega a Docker, a la red ni a los puertos de verdad. Uso: tests/instalador.sh
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(mktemp -d)"; trap 'rm -rf "$BASE"' EXIT
SCRIPT_BIN="$(command -v script || true)"
FALLOS=0; TOTAL=0

# Herramientas reales permitidas. docker, sudo, ss, curl, ip, hostname... NO están: son dobles.
SYS="$BASE/sys"; mkdir -p "$SYS"
for h in bash sh env awk sed grep cat cut tr head tail base64 chmod cp mv mkdir mktemp rm seq sort \
         dirname wc uname stat ls tee; do
  r="$(command -v "$h")" && ln -s "$r" "$SYS/$h"
done

doble() { printf '#!/bin/sh\n%s\n' "$2" > "$STUBS/$1"; chmod +x "$STUBS/$1"; }

preparar() {
  CASO="$BASE/caso$((TOTAL + 1))"; STUBS="$CASO/dobles"; LOG="$CASO/llamadas.log"
  mkdir -p "$CASO/repo" "$STUBS"; : > "$LOG"
  cp "$RAIZ/install.sh" "$RAIZ/.env.example" "$RAIZ/docker-compose.yml" "$CASO/repo/"
  doble docker 'echo "docker $*" >> "$LOG"
case "$1" in
  info) exit "${DOBLE_DOCKER_INFO:-0}" ;;
  compose) [ "$2" = version ] && echo "Docker Compose version v2.40.0"; exit 0 ;;
  ps) for c in ${DOBLE_CONTENEDORES:-}; do echo "$c"; done; exit 0 ;;
esac
exit 0'
  doble sudo 'echo "sudo $*" >> "$LOG"; [ "$1" = -n ] && shift; exec "$@"'
  doble ss 'case "$1" in -tlnH) cat "${DOBLE_SS_TCP:-/dev/null}" ;; -ulnH) cat "${DOBLE_SS_UDP:-/dev/null}" ;; esac'
  doble dpkg 'echo "${DOBLE_ARQ:-arm64}"'
  doble hostname '[ "$1" = -I ] && echo "192.168.1.50 172.17.0.1" || echo RaspberryPi'
  doble ip 'echo "default via 192.168.1.1 dev eth0 proto dhcp"'
  doble timedatectl 'echo Europe/Madrid'
  doble modprobe 'exit 0'
  doble curl 'echo "curl $*" >> "$LOG"
case "$*" in
  *ipify*) [ -n "${DOBLE_SIN_IP:-}" ] && exit 6; echo 203.0.113.7 ;;
  *http_code*) echo 200 ;;
  *) exit 1 ;;
esac'
  doble sleep 'exit 0'
}

# ejecutar [VAR=valor ...] -- [argumentos de install.sh]   (sin terminal: stdin vacío)
ejecutar() {
  local vars=(); while [ "$1" != -- ]; do vars+=("$1"); shift; done; shift
  (cd "$CASO/repo" && env -i PATH="$STUBS:$SYS" HOME="$CASO" USER=prueba LOG="$LOG" "${vars[@]}" \
     bash ./install.sh "$@") > "$CASO/salida.txt" 2>&1 < /dev/null
  CODIGO=$?
}

# en_terminal "respuestas" [VAR=valor ...]: ejecuta con una terminal de verdad (script) y teclea las respuestas
en_terminal() {
  local respuestas="$1"; shift
  (cd "$CASO/repo" && printf '%b' "$respuestas" | env -i PATH="$STUBS:$SYS" HOME="$CASO" USER=prueba \
     LOG="$LOG" TERM=dumb "$@" "$SCRIPT_BIN" -qec "bash ./install.sh" /dev/null) > "$CASO/salida.txt" 2>&1
  CODIGO=$?
}

prueba() { # prueba "descripción" condición...
  local desc="$1"; shift; TOTAL=$((TOTAL + 1))
  if "$@"; then echo "ok $TOTAL - $desc"
  else echo "FALLO $TOTAL - $desc"; FALLOS=$((FALLOS + 1)); sed 's/^/    | /' "$CASO/salida.txt" | tail -n 25; fi
}
salida_tiene() { grep -qF -- "$1" "$CASO/salida.txt"; }
log_tiene()    { grep -qF -- "$1" "$LOG"; }
env_valor()    { grep -E "^$1=" "$CASO/repo/.env" | tail -n1 | cut -d= -f2-; }
veces()        { grep -oF -- "$1" "$CASO/salida.txt" | wc -l | tr -d ' '; }
# Solo el resumen final. (Con `script`, la terminal de prueba repite al principio todo lo tecleado
# antes de que `read -s` apague el eco; con una persona tecleando eso no ocurre.)
veces_resumen() { sed -n '/HEIMDALL instalado/,$p' "$CASO/salida.txt" | grep -oF -- "$1" | wc -l | tr -d ' '; }

# --- Ayuda y opciones ---
preparar; ejecutar -- --ayuda
prueba "--ayuda explica --comprobar y sale con 0" eval '[ $CODIGO -eq 0 ] && salida_tiene "--comprobar"'
preparar; ejecutar -- --inventada
prueba "una opción desconocida sale con 2 y lo dice" eval '[ $CODIGO -eq 2 ] && salida_tiene "Opción desconocida"'

# --- --comprobar ---
preparar; ejecutar -- --comprobar
prueba "--comprobar con todo bien: sale con 0 y dice cómo instalar" eval '[ $CODIGO -eq 0 ] && salida_tiene "Todo listo"'
prueba "--comprobar no crea .env, no arranca nada ni carga módulos" \
  eval '[ ! -e "$CASO/repo/.env" ] && ! log_tiene "compose up" && ! log_tiene "modprobe" && ! log_tiene "curl"'

preparar; printf 'UNCONN 0 0 0.0.0.0:51820 0.0.0.0:*\n' > "$CASO/udp"
ejecutar DOBLE_SS_UDP="$CASO/udp" -- --comprobar
prueba "puerto 51820/udp ocupado: falla y propone otro" eval '[ $CODIGO -eq 1 ] && salida_tiene "51820/udp (VPN) está ocupado" && salida_tiene "WG_PORT=51821"'

preparar; printf 'UNCONN 0 0 0.0.0.0:51820 0.0.0.0:*\n' > "$CASO/udp"; printf 'LISTEN 0 4096 *:51843 *:*\n' > "$CASO/tcp"
ejecutar DOBLE_SS_UDP="$CASO/udp" DOBLE_SS_TCP="$CASO/tcp" DOBLE_CONTENEDORES="heimdall-wg heimdall-caddy" -- --comprobar
prueba "si HEIMDALL ya está en marcha, sus propios puertos no son un problema" eval '[ $CODIGO -eq 0 ]'

preparar; printf 'LISTEN 0 4096 *:51843 *:*\n' > "$CASO/tcp"
ejecutar DOBLE_SS_TCP="$CASO/tcp" -- --comprobar
prueba "puerto del panel ocupado: falla y propone WEB_PORT=51844" eval '[ $CODIGO -eq 1 ] && salida_tiene "WEB_PORT=51844"'

preparar; rm "$STUBS/docker"; ejecutar -- --comprobar
prueba "sin Docker: falla, explica cómo instalarlo y NO lo instala" \
  eval '[ $CODIGO -eq 1 ] && salida_tiene "Docker no está instalado" && salida_tiene "get.docker.com" && ! log_tiene "get.docker.com"'

preparar; ejecutar DOBLE_DOCKER_INFO=1 -- --comprobar
prueba "Docker sin permiso o parado: falla y da los dos arreglos" \
  eval '[ $CODIGO -eq 1 ] && salida_tiene "systemctl enable --now docker" && salida_tiene "usermod -aG docker"'

preparar; printf 'WG_PORT=65535\n' > "$CASO/repo/.env"; printf 'UNCONN 0 0 0.0.0.0:65535 0.0.0.0:*\n' > "$CASO/udp"
ejecutar DOBLE_SS_UDP="$CASO/udp" -- --comprobar
prueba "con el último puerto (65535) ocupado propone uno válido (65534)" eval '[ $CODIGO -eq 1 ] && salida_tiene "WG_PORT=65534"'

preparar; ejecutar DOBLE_ARQ=armhf -- --comprobar
prueba "Raspberry Pi OS de 32 bits: falla y dice que instale el de 64 bits" eval '[ $CODIGO -eq 1 ] && salida_tiene "Raspberry Pi OS (64-bit)"'

preparar; ejecutar DOBLE_ARQ=amd64 -- --comprobar
prueba "PC de 64 bits (amd64) es compatible" eval '[ $CODIGO -eq 0 ]'

preparar; rm "$STUBS/curl"; ejecutar -- --comprobar
prueba "sin curl: falla y dice cómo instalarlo" eval '[ $CODIGO -eq 1 ] && salida_tiene "sudo apt install -y curl"'

# --- Instalación sin terminal (como desde ARIA: curl | bash) ---
preparar; ejecutar -- --sin-preguntas
CLAVE="$(env_valor WG_ADMIN_PASSWORD)"
prueba "instalación sin preguntas: termina bien y arranca los contenedores" eval '[ $CODIGO -eq 0 ] && log_tiene "compose up -d"'
prueba ".env queda con permisos 600" eval '[ "$(stat -c %a "$CASO/repo/.env")" = 600 ]'
prueba "contraseña generada de 24 caracteres alfanuméricos" eval '[[ "$CLAVE" =~ ^[A-Za-z0-9]{24}$ ]]'
prueba "sin terminal la contraseña NO se imprime (no acaba en registros)" eval '[ "$(veces "$CLAVE")" -eq 0 ] && salida_tiene "grep WG_ADMIN_PASSWORD .env"'
prueba "valores por defecto: IP pública, IP de la LAN, nombre en minúsculas y DNS 1.1.1.1" \
  eval '[ "$(env_valor WG_HOST)" = 203.0.113.7 ] && [ "$(env_valor LAN_IP)" = 192.168.1.50 ] && [ "$(env_valor PI_HOSTNAME)" = raspberrypi ] && [ "$(env_valor WG_DNS)" = 1.1.1.1 ]'
prueba "resumen: abrir UDP 51820 en el router, primer cliente y QR" \
  eval 'salida_tiene "http://192.168.1.1" && salida_tiene "protocolo UDP, puerto externo 51820" && salida_tiene "Nuevo cliente" && salida_tiene "Escanear código QR"'
prueba "con IP pública (sin DuckDNS) sugiere DuckDNS" eval 'salida_tiene "DuckDNS (gratis)"'

preparar; ejecutar DOBLE_CONTENEDORES="shield-unbound shield-pihole" -- --sin-preguntas
prueba "con SHIELD-DNS en marcha, la VPN usa la Raspberry como DNS" eval '[ $CODIGO -eq 0 ] && [ "$(env_valor WG_DNS)" = 192.168.1.50 ]'

preparar; ejecutar DOBLE_SIN_IP=1 -- --sin-preguntas
prueba "sin IP pública detectable: se para y dice qué rellenar" eval '[ $CODIGO -eq 1 ] && salida_tiene "WG_HOST de .env" && ! log_tiene "compose up"'

# --- Ruta de ./update.sh: .env ya existe ---
preparar; cp "$CASO/repo/.env.example" "$CASO/repo/.env"
sed -i -e 's/^WG_ADMIN_PASSWORD=.*/WG_ADMIN_PASSWORD=ya-existente-solo-pruebas/' -e 's/^WG_HOST=.*/WG_HOST=vpn.example.com/' \
  -e 's/^WG_DNS=.*/WG_DNS=192.168.1.50/' -e 's/^LAN_IP=.*/LAN_IP=192.168.1.50/' -e 's/^PI_HOSTNAME=.*/PI_HOSTNAME=raspberrypi/' "$CASO/repo/.env"
cp "$CASO/repo/.env" "$CASO/env-antes"
printf 'LISTEN 0 4096 0.0.0.0:51843 0.0.0.0:*\n' > "$CASO/tcp"; printf 'UNCONN 0 0 0.0.0.0:51820 0.0.0.0:*\n' > "$CASO/udp"
if [ -n "$SCRIPT_BIN" ]; then
  en_terminal "" DOBLE_SIN_IP=1 DOBLE_CONTENEDORES="heimdall-wg heimdall-caddy shield-pihole" DOBLE_SS_TCP="$CASO/tcp" DOBLE_SS_UDP="$CASO/udp"
else
  ejecutar DOBLE_SIN_IP=1 DOBLE_CONTENEDORES="heimdall-wg heimdall-caddy shield-pihole" DOBLE_SS_TCP="$CASO/tcp" DOBLE_SS_UDP="$CASO/udp" --
fi
prueba "con .env existente (update.sh) y sus puertos en uso por HEIMDALL: no pregunta y termina bien" eval '[ $CODIGO -eq 0 ] && ! salida_tiene "Configuración rápida"'
prueba "con .env existente no cambia .env ni muestra la contraseña" \
  eval 'cmp -s "$CASO/env-antes" "$CASO/repo/.env" && [ "$(veces ya-existente-solo-pruebas)" -eq 0 ]'
prueba "con WG_HOST ya puesto no consulta la IP pública (antes fallaba si ipify no respondía)" eval '! log_tiene "ipify"'

# --- Asistente en una terminal de verdad ---
if [ -n "$SCRIPT_BIN" ]; then
  preparar; en_terminal '\n\n\n'
  CLAVE="$(env_valor WG_ADMIN_PASSWORD)"
  prueba "asistente: tres Enter dan una instalación completa" \
    eval '[ $CODIGO -eq 0 ] && salida_tiene "Configuración rápida" && [ "$(env_valor WG_HOST)" = 203.0.113.7 ] && [ "$(env_valor WG_PORT)" = 51820 ]'
  prueba "asistente: la contraseña generada se muestra UNA sola vez" \
    eval '[[ "$CLAVE" =~ ^[A-Za-z0-9]{24}$ ]] && [ "$(veces "$CLAVE")" -eq 1 ] && salida_tiene "no se volverá a mostrar"'

  preparar; en_terminal 'MiClaveSegura2026\nMiClaveSegura2026\nmicasa.duckdns.org\ntoken-de-prueba-123\n51999\n'
  prueba "asistente: contraseña elegida, DuckDNS con token y puerto propio" \
    eval '[ $CODIGO -eq 0 ] && [ "$(env_valor WG_ADMIN_PASSWORD)" = MiClaveSegura2026 ] && [ "$(env_valor WG_HOST)" = micasa.duckdns.org ] && [ "$(env_valor DUCKDNS_SUBDOMAIN)" = micasa ] && [ "$(env_valor DUCKDNS_TOKEN)" = token-de-prueba-123 ] && [ "$(env_valor WG_PORT)" = 51999 ]'
  prueba "asistente: con DuckDNS arranca también el perfil ddns" eval 'log_tiene "compose --profile ddns up -d"'
  prueba "asistente: el resumen usa el puerto elegido y no repite la contraseña ni el token" \
    eval 'salida_tiene "puerto externo 51999" && [ "$(veces_resumen token-de-prueba-123)" -eq 0 ] && [ "$(veces_resumen MiClaveSegura2026)" -eq 0 ] && salida_tiene "grep WG_ADMIN_PASSWORD .env"'

  preparar; en_terminal 'Clave.Segura_2026!@%+=,:*^-\nClave.Segura_2026!@%+=,:*^-\n\n\n'
  prueba "asistente: una contraseña con todos los símbolos permitidos se guarda literal y .env se carga bien" \
    eval '[ $CODIGO -eq 0 ] && [ "$(env_valor WG_ADMIN_PASSWORD)" = "Clave.Segura_2026!@%+=,:*^-" ]'

  preparar; printf 'UNCONN 0 0 0.0.0.0:51999 0.0.0.0:*\n' > "$CASO/udp"
  en_terminal 'corta\n\nhost con espacios\nvpn.example.com\n51999\n70000\n51821\n' DOBLE_SS_UDP="$CASO/udp"
  prueba "asistente: rechaza contraseña corta, dirección y puertos no válidos u ocupados" \
    eval '[ $CODIGO -eq 0 ] && salida_tiene "al menos 12" && salida_tiene "Escribe un dominio o una IP" && salida_tiene "ocupado; elige otro" && salida_tiene "entre 1 y 65535" && [ "$(env_valor WG_PORT)" = 51821 ] && [ "$(env_valor WG_HOST)" = vpn.example.com ]'
else
  echo "# aviso: falta 'script' (util-linux); se omiten las pruebas con terminal"
fi

echo "---"
echo "$((TOTAL - FALLOS))/$TOTAL pruebas correctas"
[ "$FALLOS" -eq 0 ]

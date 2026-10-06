# CLAUDE.md – Guía para Claude Code en HEIMDALL

## Estructura del proyecto

```
HEIMDALL/
├── docker-compose.yml      Definición de servicios (wg-easy, Caddy, DuckDNS opcional)
├── Caddyfile               Configuración de proxy inverso TLS
├── install.sh              Script de instalación (idempotente)
├── uninstall.sh            Script de desinstalación
├── .env.example            Plantilla de variables
├── .env                    Configuración local (NUNCA commitear)
├── data/wireguard/         Claves y perfiles VPN (NUNCA commitear)
├── data/caddy/             Certificados TLS (NUNCA commitear)
├── data/duckdns/           Config de DNS dinámico (NUNCA commitear)
├── README.md               Documentación para usuarios
├── CLAUDE.md               Esta guía
├── AGENTS.md               Distribución de trabajo entre agentes
├── SKILLS.md               Procedimientos operacionales
├── MEMORY.md               Decisiones y registro de pruebas
└── LICENSE                 MIT license
```

## Convenciones

### Idioma
- **Usuarios:** español de España (Castilla) en todos los mensajes, comentarios y documentos públicos
- **Código (scripts, comentarios internos):** español de España

### Secretos y configuración
- **NUNCA commitear `.env`** (está en `.gitignore`)
- **Secretos solo en `.env`:** contraseñas de admin, IPs privadas, tokens DuckDNS
- **Datos persistentes:** carpeta `data/` (en `.gitignore`)

### Scripts bash
Todos los scripts usan:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
```

Garantiza:
- Fallo si hay errores
- Fallo si se usan variables vacías
- Fallo si hay pipes que fallan
- El script funciona desde cualquier directorio

### Idempotencia
- `install.sh` puede ejecutarse múltiples veces sin consecuencias
- Las variables solo se rellenan si están vacías
- Cambios de configuración de WireGuard después del primer arranque se hacen desde el panel web

## Lo importante de HEIMDALL

### Topología de la red Docker

```
docker network heimdall
├── wg-easy (WireGuard VPN server)
│   └── Expone: 51820/UDP (público), internal API :51821
└── caddy (reverse proxy HTTPS)
    └── Expone: 51843/TCP (panel web seguro)
```

### Caddyfile y TLS

El archivo `Caddyfile` es crítico:
```
default_sni {$LAN_IP}  # Sin esto, conexiones por IP sin SNI se rompen
reverse_proxy wg-easy:51821  # Apunta al servidor interno de wg-easy
```

**No cambies esto sin razón.** Es el "secreto" para que HTTPS funcione sin certificados válidos.

### Variables que solo se aplican al arranque

En `docker-compose.yml`:
```yaml
environment:
  INIT_ENABLED: "true"
  INIT_USERNAME: ${WG_ADMIN_USER:-admin}
  INIT_PASSWORD: ${WG_ADMIN_PASSWORD:?...}
  INIT_HOST: ${WG_HOST:?...}
  INIT_PORT: ${WG_PORT:-51820}
  INIT_DNS: ${WG_DNS:-1.1.1.1}
```

Estos `INIT_*` **solo funcionan en el primer arranque**. Si borras `data/wireguard/`, se reinicializan.

Cambios después del primer arranque: panel web, no `.env`.

### Integración con SHIELD-DNS

En `install.sh`, líneas 48-56:
```bash
if $DOCKER ps --format '{{.Names}}' | grep -qx shield-pihole; then
  set_env WG_DNS "$LAN_IP_DET"  # Usa la Raspberry como DNS
else
  set_env WG_DNS "1.1.1.1"      # Fallback a Cloudflare
fi
```

Esto detecta automáticamente si Pi-hole está corriendo. **Importante:** esta lógica solo se ejecuta en el primer arranque (si `WG_DNS` está vacío en `.env`).

## Cómo probar cambios en la Raspberry Pi

### Opción 1: SSH en la Pi
```bash
ssh pi@raspberrypi.local
cd /ruta/a/HEIMDALL
git pull origin main
./install.sh
# Probar desde el panel: https://<IP>:51843
# O crear un cliente de prueba y verificar túnel
```

### Opción 2: Crear un cliente de prueba via API
```bash
IP=$(hostname -I | awk '{print $1}')
PASS=$(grep WG_ADMIN_PASSWORD .env | cut -d= -f2)

# Crear cliente
curl -k -u admin:$PASS -X POST "https://$IP:51843/api/client" \
  -H "Content-Type: application/json" \
  -d '{"name":"test"}'

# Listar clientes
curl -k -u admin:$PASS "https://$IP:51843/api/client"
```

### Opción 3: Túnel de prueba real
Desde otra máquina con WireGuard:
```bash
# Descarga el .conf de cliente
curl -k -u admin:PASS "https://<IP>:51843/api/client/<id>/config"

# Conecta con wg-quick (Linux) o app WireGuard (Android/iPhone)
wg-quick up ./client.conf
ping 10.8.0.1  # El servidor VPN debe responder

# Desconecta
wg-quick down ./client.conf
```

## Cambios comunes y dónde hacerlos

| Cambio | Archivo | Nota |
|--------|---------|------|
| Cambiar puerto VPN | `.env.example` → `WG_PORT` | Requiere reenvío en router |
| Cambiar puerto panel | `.env.example` → `WEB_PORT` | Puerto TCP, acceso LAN |
| Cambiar DNS de VPN | Panel web → Administración → DNS | No editando `.env` después del arranque |
| Cambiar admin user/password | Panel web → Administración | Primera vez: `.env.example` |
| Añadir DuckDNS | `.env.example` → `DUCKDNS_*` | Ejecutar `./install.sh` de nuevo |
| Cambiar hostname | No (auto-detectado) | Si cambias en la Raspberry, ejecuta `./install.sh` |
| Cambiar IP privada LAN | `.env` → `LAN_IP` | Manual; después `docker compose up -d` |

## Lo que NO hacer

- **No commitear `.env`** – es privado
- **No tocar `data/`** – son claves VPN (invaluable)
- **No cambiar `INIT_*` en docker-compose.yml** después de crear clientes; usarás el panel
- **No editar `Caddyfile` sin entender TLS**
- **No usar `--profile ddns` sin configurar DUCKDNS_* en .env**
- **No ejecutar `install.sh` si `data/wireguard/` existe con un endpoint diferente** (reenvío cambiado, IP pública cambió): eso sobrescribirá la configuración

## Gotchas

### "WG_HOST no se cambió aunque edité .env"

Esperado. `WG_HOST` solo se aplica en el primer arranque (si `data/wireguard/` está vacío).

**Solución:** cambia desde el panel web:
1. Panel → Administración → General → Endpoint
2. Edita manualmente a la nueva dirección
3. Guarda

O si quieres empezar de cero:
```bash
./uninstall.sh --purge
rm -rf data/
./install.sh
```

### "El panel web muestra certificado inválido"

Normal. Caddy genera un certificado autofirmado con CA interna. Tu navegador mostrará advertencia.

Solución: haz clic en "Avanzado" → "Continuar" (Chrome) o "Mostrar detalles" → "Acceder" (Safari).

### "Cambié la IP privada de la Raspberry y la VPN se rompió"

Razón: `LAN_IP` en `.env` está desactualizada, y wg-easy todavía apunta a la antigua.

**Solución:**
```bash
# 1. Edita .env con la nueva IP
nano .env  # Cambia LAN_IP=192.168.1.X

# 2. Reinicia
docker compose up -d

# 3. Reconfigura desde el panel si es necesario
```

### "¿Por qué DuckDNS en un perfil ('profile: ddns')?

Porque el contenedor es opcional. Si no lo configuras, no necesita ejecutarse. Esto ahorra recursos en la Raspberry Pi.

El instalador lo activa automáticamente si `DUCKDNS_SUBDOMAIN` y `DUCKDNS_TOKEN` están definidos.

### "El reenvío de puertos no funciona"

Los pasos comunes:
1. ¿Está el puerto 51820 UDP reenviado en el router? (comprueba de nuevo)
2. ¿La Raspberry está en la IP correcta? (`ip a` desde SSH)
3. ¿Está activo docker? (`docker ps`)
4. ¿El firewall de la Raspberry permite UDP 51820? (`sudo ufw status`)

## Testing

### Verificar que el panel responde

```bash
curl -k https://<IP>:51843/ -w '\n%{http_code}\n'
```

Debe retornar `200` (o `302` si redirige a login).

### Verificar que WireGuard escucha

```bash
docker exec heimdall-wg wg show
```

Debe mostrar la interfaz `wg0` con dirección 10.8.0.1.

### Crear un cliente de prueba y conectar

```bash
# API para listar clientes
curl -k -u admin:PASSWORD "https://127.0.0.1:51843/api/client" | jq

# API para crear cliente
curl -k -u admin:PASSWORD -X POST "https://127.0.0.1:51843/api/client" \
  -H "Content-Type: application/json" -d '{"name":"test"}'

# En otra máquina: descargar .conf y conectar
wg-quick up test.conf
ip link show wg0  # Debe mostrar la interfaz activa
```

### Ver logs

```bash
docker compose logs -f wg-easy
docker compose logs -f caddy
```

Busca `Client connected`, `Client disconnected`, o errores TLS.

## Herramientas útiles

- `docker compose ps` – estado de servicios
- `docker compose logs wg-easy` – logs de WireGuard
- `docker compose logs caddy` – logs de Caddy
- `docker exec heimdall-wg wg show` – estado de la interfaz WireGuard
- `docker exec heimdall-wg wg show peers` – clientes conectados

## Referencias

- [wg-easy Documentation](https://github.com/wg-easy/wg-easy)
- [WireGuard](https://www.wireguard.com/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [DuckDNS](https://www.duckdns.org/)

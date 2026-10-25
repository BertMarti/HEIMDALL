# Guía de desarrollo de HEIMDALL

Esta guía describe la arquitectura, la configuración y la validación para desarrollar o mantener HEIMDALL. La guía de uso está en [README.md](../README.md).

## Estructura

```text
HEIMDALL/
├── .claude/                 # Agentes y skills para Claude Code
├── .github/workflows/       # CI y GitHub Pages
├── docs/img/                # Imágenes del README y la web
├── site/                    # Web estática, única salida de Pages
├── docker-compose.yml       # wg-easy, Caddy y DuckDNS opcional
├── Caddyfile                # Proxy HTTPS
├── install.sh               # Instalación idempotente
├── update.sh backup.sh restore.sh uninstall.sh
└── .env.example             # Plantilla de configuración
```

## Configuración

| Variable | Descripción | Aplicación |
|---|---|---|
| `TZ` | Zona horaria | Compose |
| `WG_ADMIN_USER` | Usuario del panel | Solo primer arranque |
| `WG_ADMIN_PASSWORD` | Contraseña inicial | Solo primer arranque |
| `WG_HOST` | Dominio o IP pública para clientes | Solo primer arranque |
| `WG_PORT` | Puerto UDP de WireGuard, por defecto `51820` | Solo primer arranque |
| `WG_DNS` | DNS de los clientes | Solo primer arranque |
| `WEB_PORT` | Panel HTTPS, por defecto `51843` | Compose |
| `LAN_IP` | IP LAN de la máquina | Caddy y panel |
| `PI_HOSTNAME` | Nombre local de la máquina | Caddy |
| `DUCKDNS_SUBDOMAIN` | Subdominio DuckDNS | Perfil `ddns` |
| `DUCKDNS_TOKEN` | Token DuckDNS | Perfil `ddns` |

Las variables `INIT_*` del Compose solo se leen al crear los datos de wg-easy. Los cambios posteriores se hacen desde el panel o `docker compose exec -it wg-easy cli`.

## Qué mueve el instalador

`install.sh --comprobar` solo valida Docker, Compose v2, arquitectura de 64 bits, `curl`, el módulo WireGuard y los puertos configurados. El instalador normal instala Docker si falta, comprueba el plugin Compose, intenta cargar WireGuard, crea `.env` con permisos `600`, detecta `LAN_IP` y `PI_HOSTNAME`, ofrece un asistente de tres preguntas en una terminal nueva, determina `WG_HOST`, elige SHIELD-DNS o `1.1.1.1`, crea `data/`, arranca los servicios y espera una respuesta del panel. Si hay subdominio y token DuckDNS activa el perfil `ddns`. `--sin-preguntas` usa los valores por defecto; `--ayuda` muestra el uso. Sin terminal también usa los valores por defecto y no imprime la contraseña.

Es idempotente: solo rellena variables vacías y no reemplaza datos persistentes. Si ya existe `data/wireguard/`, los cambios de `WG_*` en `.env` no cambian la configuración inicial de wg-easy.

## Versiones fijadas

| Imagen | Versión | Digest |
|---|---|---|
| `ghcr.io/wg-easy/wg-easy` | `15.4.0` | `sha256:0e7bc9d34e86ddcaa92bc700d4d7dc9b33291dbc07ac8d13382f7c2095f949ec` |
| `caddy` | `2.11.7-alpine` | `sha256:d8542f48d34a9cf4e4c11a478865229840e87e4c96ea3f439101f31a5d35f75f` (lo que corre; `2.11.7` sin `-alpine` es otra variante) |
| `lscr.io/linuxserver/duckdns` | `8d8f7eba-ls94` | `sha256:7736cb8f1b0cde0e24f6e80fac6c5ab9567b77e10fe62b753a4977ac767bbd5c` (perfil opcional; etiqueta no semver, revisar a mano) |

La referencia completa desplegada de wg-easy es:
`ghcr.io/wg-easy/wg-easy:15.4.0@sha256:0e7bc9d34e86ddcaa92bc700d4d7dc9b33291dbc07ac8d13382f7c2095f949ec`.
Para comprobar la imagen local y contrastarla con el registro:

```bash
# solo lectura: digest de la imagen con la que corre el contenedor
docker image inspect --format '{{json .RepoDigests}}' "$(docker inspect -f '{{.Image}}' heimdall-wg)"
docker buildx imagetools inspect ghcr.io/wg-easy/wg-easy:15.4.0
```

Para actualizar una imagen, revisa primero compatibilidad con ARIA, cambia la versión y
el digest en `docker-compose.yml`, valida Compose y prueba en un entorno aislado antes de
aplicar `./update.sh`. Dependabot propone parches y menores y actualiza ambos valores;
las versiones mayores se revisan a mano porque ARIA usa la API de wg-easy v15.

## Topología, puertos y contenedores

| Contenedor | Puerto | Publicación | Uso |
|---|---:|---|---|
| `heimdall-wg` | `51820/udp` | Host | Túnel WireGuard; se reenvía en el router |
| `heimdall-wg` | `51821/tcp` | Solo red Docker | Web/API para Caddy; no se publica en el host |
| `heimdall-caddy` | `51843/tcp` | Host/LAN | Panel HTTPS |
| `heimdall-duckdns` | - | Ninguna | DNS dinámico opcional, perfil `ddns` |

La red se llama `heimdall`. Caddy hace `reverse_proxy wg-easy:51821`. `default_sni {$LAN_IP}` permite el acceso por IP y `tls internal` crea certificados internos. Las cabeceras son `nosniff`, `X-Frame-Options`, `Referrer-Policy` y `Permissions-Policy`; no hay CSP ni HSTS en Caddy. El `Caddyfile` va montado en el contenedor y Caddy no lo recarga solo: tras cambiarlo (o tras `./update.sh`), `docker compose restart caddy`.

## DNS de los dispositivos conectados

```mermaid
flowchart LR
    A["install.sh"] --> Q{"¿shield-pihole está activo?"}
    Q -- Sí --> S["WG_DNS = IP LAN\nSHIELD-DNS"]
    Q -- No --> C["WG_DNS = 1.1.1.1"]
```

La decisión se toma al instalar y solo se conserva si `WG_DNS` estaba vacío. Después se modifica en el panel.

## Operación diaria avanzada

### Apagar la VPN un rato

```bash
docker compose --profile ddns down
./install.sh
```

El primer comando detiene también DuckDNS si está configurado; el segundo vuelve a levantar los servicios.

### Ver los registros

```bash
docker compose logs -f wg-easy
docker compose logs -f caddy
```

## Gotchas

- Editar `WG_ADMIN_PASSWORD` en `.env` no cambia la contraseña de una base de datos ya creada. Usa el panel o `docker compose exec -it wg-easy cli db:admin:reset`.
- `WG_HOST`, `WG_PORT` y `WG_DNS` iniciales no se aplican otra vez al repetir el instalador. Cambia el endpoint en el panel y regenera perfiles si cambia la dirección.
- El certificado de Caddy es interno; la advertencia del navegador es esperada.
- Si cambia la IP LAN, actualiza `LAN_IP` y reinicia el Compose; comprueba después el panel y el `default_sni`.
- DuckDNS es opcional y solo se activa cuando están definidas ambas variables del perfil.
- El reenvío de puertos requiere UDP `51820` y una IP LAN estable. CG-NAT no se arregla desde el código.

## Cambios comunes y dónde hacerlos

| Cambio | Lugar | Nota |
|---|---|---|
| Puerto VPN | `.env.example` / `.env`, `WG_PORT` | Requiere ajustar el router y perfiles |
| Puerto del panel | `.env`, `WEB_PORT` | TCP, solo LAN |
| DNS de clientes | Panel, Administración | No editar `.env` tras el primer arranque |
| Usuario o contraseña | Panel; inicialización en `.env` | Reset por CLI si se pierde |
| DuckDNS | `.env`, `DUCKDNS_*` | Reejecutar `./install.sh` para activar el perfil |
| Hostname | Detección de `install.sh` | Reejecutar si cambia |
| IP LAN | `.env`, `LAN_IP` | Debe coincidir con la máquina y Caddy |

## Lo que NO hacer

- No commitear `.env`, `data/`, claves, QR ni perfiles.
- No tocar `data/wireguard/` para cambiar una opción inicial sin entender que se perderían clientes.
- No cambiar `INIT_*` después de crear clientes esperando que el panel se actualice.
- No publicar `51821`; Caddy debe ser el único acceso web.
- No abrir `51843` en internet.
- No ejecutar scripts de gestión o Docker sobre producción sin autorización.
- No usar el perfil `ddns` sin configurar sus variables.

## Testing

La API de wg-easy v15 la usa ARIA; para pruebas manuales usa el panel o la CLI `docker compose exec -it wg-easy cli`. No se documentan llamadas con credenciales en la línea de comandos.

Validación local:

```bash
bash -n *.sh site/*.sh
shellcheck *.sh site/*.sh
tests/instalador.sh
cp .env.example /tmp/heimdall.env
sed -i -e 's/^WG_ADMIN_PASSWORD=.*/WG_ADMIN_PASSWORD=solo-para-ci/' -e 's/^WG_HOST=.*/WG_HOST=vpn.example.com/' -e 's/^LAN_IP=.*/LAN_IP=192.168.1.50/' -e 's/^PI_HOSTNAME=.*/PI_HOSTNAME=raspberrypi/' /tmp/heimdall.env
docker compose --env-file /tmp/heimdall.env config -q
docker compose --env-file /tmp/heimdall.env --profile ddns config -q
gitleaks git . --redact
```

Caddy se valida con un binario instalado o con la imagen de Caddy fijada en `docker-compose.yml`, pasando `LAN_IP`, `WEB_PORT` y `PI_HOSTNAME`. No se debe ejecutar Docker sobre la máquina de producción solo para validar.

`tests/instalador.sh` contiene 34 pruebas del instalador en una carpeta temporal. Sustituye
Docker, `sudo`, `ss`, `curl`, `ip` y otras herramientas por dobles, por lo que no toca
Docker real, la red ni los puertos; las pruebas que necesitan terminal usan `script`
(util-linux).

La CI real tiene estos jobs:

- `scripts`: `bash -n` y ShellCheck para scripts raíz, `site/` y `tests/*.sh`, además de las pruebas del instalador.
- `compose`: crea un `.env` ficticio, ejecuta Compose con y sin `ddns`, comprueba que solo se publican `51820/udp` y `51843/tcp`, y exige versión y digest en wg-easy, Caddy y DuckDNS, y ejecuta `caddy validate` con la imagen fijada con `LAN_IP`, `WEB_PORT` y `PI_HOSTNAME`.
- `gitleaks`: descarga el binario oficial 8.30.1, verifica su suma y revisa historial y árbol.
- `web`: ejecuta `site/construir.sh`, comprueba CSP, ausencia de inline JS/CSS y `innerHTML`, enlaces existentes y JavaScript válido.

Pages ejecuta `site/construir.sh`, sube `_site` con `upload-pages-artifact` y publica con `deploy-pages`. Se dispara en `push` a `main` que toque `site/`, `docs/img/` o el workflow, y manualmente. Publica solo la web de `site/`, no la documentación Markdown.

## Vista previa de la web

```bash
site/construir.sh /tmp/heimdall-web/HEIMDALL
python3 -m http.server 8000 -d /tmp/heimdall-web
```

## Referencias

- [wg-easy](https://github.com/wg-easy/wg-easy)
- [WireGuard](https://www.wireguard.com/)
- [Caddy](https://caddyserver.com/docs/)
- [DuckDNS](https://www.duckdns.org/)
- [Docker Networking](https://docs.docker.com/network/)

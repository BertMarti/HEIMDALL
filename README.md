# HEIMDALL – VPN WireGuard para tu hogar

HEIMDALL transforma tu Raspberry Pi en un servidor VPN WireGuard. Conecta tu móvil, PC, tablet o TV desde cualquier lugar y accede a tu red como si estuvieras en casa, con bloqueo de anuncios automático si tienes SHIELD-DNS.

## ¿Cómo funciona en tu casa?

**SHIELD-DNS** (bloqueador de publicidad) + **HEIMDALL** (este proyecto, VPN) + **ARIA** (asistente IA):

- **SHIELD-DNS**: bloquea anuncios en el DNS de tu red (puerto 53).
- **HEIMDALL**: VPN WireGuard para conectarte desde fuera de casa. Accede a tu red y usa SHIELD-DNS aunque viajes.
- **ARIA**: asistente IA local en puertos 80/443.

## Requisitos

- **Raspberry Pi** (4 o 5) con Raspberry Pi OS de 64 bits, u otra distribución Linux con Docker
- **Docker y Docker Compose** (el instalador lo pone si falta)
- **Puerto 51820 UDP reenviado en el router** hacia la IP de la Raspberry Pi (necesario para conectar desde fuera)
- **IP pública o DNS dinámico** (ej. DuckDNS, si tu ISP cambia tu IP frecuentemente)

**Nota importante:** algunos ISPs usan CG-NAT (Carrier Grade NAT). Si tu IP pública en el router difiere de tu IP mostrada en https://api.ipify.org, el reenvío de puertos no funcionará. Contacta a tu ISP para solicitar una IP pública.

## Instalación en 3 comandos

```bash
git clone https://github.com/BertMarti/HEIMDALL.git
cd HEIMDALL
./install.sh
```

### Qué hace el instalador

1. Instala Docker si no lo tienes (mediante el script oficial)
2. Intenta cargar el módulo WireGuard del kernel (puede estar integrado)
3. Crea `.env` y rellena automáticamente:
   - `LAN_IP`: IP interna de la Raspberry Pi
   - `PI_HOSTNAME`: nombre del ordenador (ej. `raspberrypi`)
   - `WG_ADMIN_PASSWORD`: contraseña fuerte para el panel web
   - `WG_HOST`: tu IP pública (o subdominio DuckDNS si lo configuraste)
   - `WG_DNS`: automáticamente SHIELD-DNS si está instalado; si no, Cloudflare (1.1.1.1)
4. Descarga imágenes Docker (wg-easy, Caddy, opcionalmente DuckDNS)
5. Arranca los contenedores y espera a que el panel web responda
6. Muestra las credenciales

**Importante:** `WG_ADMIN_*`, `WG_HOST`, `WG_PORT` y `WG_DNS` solo se aplican en el **primer arranque**. Después, cámbialos desde el panel web, no editando `.env`.

### Reenvío de puertos (necesario para conectar desde fuera)

Después de instalar, **en tu router:**

1. Accede a la configuración del router (suele ser 192.168.1.1)
2. Busca "Reenvío de puertos" o "Port Forwarding"
3. Crea una regla: **Puerto externo 51820 UDP → IP interna de la Raspberry Pi, puerto 51820**
4. Guarda

Sin este paso, **solo puedes conectar desde dispositivos en tu misma red Wi-Fi**. Desde móvil en 4G/5G o desde otra red, la VPN no funcionará.

## Primero: acceso al panel web

Después de instalar, accede al panel desde una máquina en tu red:

```
https://<IP-de-la-Raspberry-Pi>:51843
```

O si tu Raspberry tiene nombre (ej. `raspberrypi.local`):

```
https://raspberrypi.local:51843
```

**Importante:** el certificado es autofirmado. Tu navegador te mostrará una advertencia. En:
- **Chrome/Edge/Firefox**: haz clic en "Avanzado" → "Continuar a la página"
- **Safari**: haz clic en "Mostrar detalles" → "Acceder a este sitio web"

Usuario: `admin` (o lo que tengas en `WG_ADMIN_USER` en `.env`)  
Contraseña: la que está en `.env` (`WG_ADMIN_PASSWORD`), generada durante la instalación.

## Uso día a día

### Añadir un dispositivo

#### Desde un móvil (recomendado)

1. Instala **WireGuard** (descárgalo de la app store: iOS App Store o Google Play)
2. Entra en el panel web (https://<IP>:51843)
3. Haz clic en "Nuevo cliente" o "New Client"
4. Se genera un QR
5. En la app WireGuard del móvil: "+" → "Crear desde código QR"
6. Escanea el QR
7. La app te mostrará el perfil; toca "Activar" para conectar

**Resultado:** el móvil ahora accede a tu red como si fuera otro dispositivo en casa. Si tienes SHIELD-DNS, se bloqueará publicidad automáticamente.

#### Desde un PC o Mac

1. Entra en el panel web
2. Haz clic en "Nuevo cliente"
3. Se genera un QR o un archivo `.conf`
4. Descarga el archivo `.conf`
5. Instala **WireGuard** en el PC (https://www.wireguard.com/)
6. Abre WireGuard → "+" → "Importar túnel(es) desde archivo"
7. Elige el `.conf` descargado
8. Activa el túnel

#### Desde un TV (Android TV / Google TV)

1. TV: descarga la app **WireGuard** de Google Play
2. En la Raspberry: genera un cliente en el panel
3. Elige descargar el QR o el `.conf`
4. En el TV: abre WireGuard → "+" → "Crear desde código QR"
5. Escanea desde otro móvil si no puedes mostrar el QR en pantalla
6. O copia el `.conf` a una USB y abrirlo desde la app

**Nota:** la mayoría de TVs normales no soportan WireGuard. Comprueba si tu TV es Android TV o Google TV antes de intentar.

### Revocar un dispositivo (borrar acceso)

1. Entra en el panel web
2. Busca el cliente (dispositivo)
3. Haz clic en el icono de papelera o "Eliminar"
4. Confirma

El dispositivo **perderá acceso inmediatamente** a la VPN. Si lo intentas reconectar con el perfil anterior, la VPN rechazará la conexión.

### Cambiar la contraseña del panel

1. Entra en el panel web
2. En la sección de "Administración" o "Admin", busca "Cambiar contraseña"
3. Introduce la contraseña actual y la nueva
4. Guarda

La contraseña en `.env` no se actualiza automáticamente (si editada `.env` manualmente, ejecuta `docker compose up -d`).

### Ver quién está conectado

En el panel web:

1. Entra en "Pares" o "Peers"
2. Verás una lista de dispositivos
3. "Conectado hace": cuándo fue el último handshake (si es reciente, está conectado ahora)
4. "Datos enviados/recibidos": tráfico del dispositivo

### Revisar logs

```bash
docker compose logs -f wg-easy
```

Muestra eventos de conexión/desconexión de dispositivos.

## DNS dinámico (si tu IP pública cambia)

Por defecto, HEIMDALL usa tu **IP pública actual** (consultando https://api.ipify.org). Si tu ISP cambia tu IP frecuentemente (cada día, cada semana), los clientes VPN no podrán reconectar (el servidor habrá desaparecido de internet).

**Solución: DuckDNS** (gratuito)

### Configurar DuckDNS

1. Entra en https://www.duckdns.org
2. Crea una cuenta (con Gmail, GitHub, etc.)
3. Haz clic en "Crear un subdominio" (ej. `micasa.duckdns.org`)
4. Copia el **token** (cadena larga de caracteres)
5. En la Raspberry, edita `.env`:
   ```
   DUCKDNS_SUBDOMAIN=micasa
   DUCKDNS_TOKEN=abc123def456ghi789
   ```
6. Ejecuta `./install.sh` de nuevo
7. Comprueba que `WG_HOST` en `.env` ahora es `micasa.duckdns.org`
8. En el panel web, ve a "Administración" → "General" → "Endpoint" y confirma que dice `micasa.duckdns.org`

Ahora, aunque tu ISP cambie tu IP pública, `micasa.duckdns.org` siempre apuntará a ti.

## Actualizar

```bash
cd ~/homelab/HEIMDALL   # o donde lo clonaras
./update.sh
```

`update.sh` hace primero una copia de seguridad, descarga los cambios del repositorio y las imágenes nuevas, y vuelve a aplicar la instalación. Tus dispositivos VPN siguen funcionando: la configuración está en `data/wireguard/`.

## Copia de seguridad y restauración

```bash
./backup.sh
```

Crea `backups/heimdall-AAAAMMDD-HHMM.tar.gz` con tu `.env`, la base de datos de wg-easy (claves del servidor y de todos los dispositivos) y la autoridad de certificados del panel. **Contiene claves privadas: guárdala en un sitio seguro**. Se conservan las 7 más recientes. **Copia ese archivo fuera de la Raspberry** (a tu PC o a un USB): si formateas, es lo único que necesitas.

Para restaurar (por ejemplo, en una Raspberry recién formateada):

```bash
git clone https://github.com/BertMarti/HEIMDALL.git && cd HEIMDALL
mkdir -p backups && cp /ruta/a/heimdall-AAAAMMDD-HHMM.tar.gz backups/
./restore.sh backups/heimdall-AAAAMMDD-HHMM.tar.gz
```

`restore.sh` pide confirmación, recupera la configuración y arranca todo con `install.sh`.

## Desinstalar

Sin borrar datos (puedes reinstalar sin perder perfiles VPN):
```bash
./uninstall.sh
```

Con purga completa (borra clientes y .env):
```bash
./uninstall.sh --purge
```

**Aviso:** si haces `--purge`, todos los clientes VPN dejarán de funcionar (sus perfiles quedarán inválidos).

## Solución de problemas

### La VPN no funciona desde fuera de casa

**Comprobación 1: ¿está el puerto 51820 UDP reenviado en el router?**
```bash
# Desde fuera de casa (en 4G/5G con otro ISP), en tu PC:
nc -u -zv <TU-IP-PUBLICA> 51820
```

Si dice `succeeded` o `open`, el puerto está abierto. Si `refused` o `timeout`, el reenvío no está activo.

**Comprobación 2: ¿tienes CG-NAT (Carrier Grade NAT)?**
Compara:
- IP en el router WAN: (accede a la configuración del router y mira "Estado")
- IP pública real: https://api.ipify.org

Si son diferentes, tu ISP usa CG-NAT. Tendrás que solicitar una IP pública dedicada o usar DuckDNS.

**Comprobación 3: ¿está HEIMDALL corriendo?**
```bash
docker compose ps
```

Debe mostrar `wg-easy` y `caddy` con estado `Up`.

### El panel web no carga (error 502)

```bash
docker compose restart
```

Si sigue sin funcionar:
```bash
docker compose logs caddy
docker compose logs wg-easy
```

Busca mensajes de `ERROR`.

### Cambié WG_HOST en .env pero el panel no lo refleja

Esto es **normal y esperado**. `WG_HOST` solo se aplica en el primer arranque (por si tienes datos existentes).

Para cambiar el endpoint públicamente:
1. En el panel: "Administración" → "General" → "Endpoint"
2. Cambia manualmente el campo
3. Guarda

O si quieres empezar de cero:
```bash
./uninstall.sh --purge
rm -rf data/
./install.sh
```

### Quiero deshabilitar la VPN temporalmente

```bash
docker compose down
```

Los clientes verán que la VPN está desconectada. Para volver a arrancar:
```bash
docker compose up -d
```

### El TV no puede conectar (no tiene WireGuard)

**Lamentablemente**, la mayoría de TVs normales no soportan WireGuard. Solo TVs con Android TV o Google TV lo permiten.

**Alternativas:**
- Conecta un Chromecast con Android TV / Google TV a la TV
- Usa un router con WireGuard (algunos modelos de TP-Link o ASUS lo soportan)
- Instala un cliente WireGuard en una Raspberry Pi adicional y conéctalo por HDMI

## Puertos

| Servicio | Puerto | Protocolo | Uso |
|----------|--------|-----------|-----|
| WireGuard | 51820 | UDP | Conexiones VPN (se reenvía en router) |
| Panel HTTPS | 51843 | TCP | Gestión de clientes (en la LAN) |

## Características verificadas (2026-10-06)

- ✓ Instalación idempotente: el script funciona varias veces
- ✓ API WireGuard: aceptación de HTTP Basic auth
- ✓ Integración DNS: detecta automáticamente SHIELD-DNS
- ✓ Túneles funcionales: handshake confirmado, tráfico de datos
- ✓ Certificados TLS: Caddy genera CA interna automáticamente
- ✓ Múltiples clientes: pruebas con varios perfiles simultáneos

## Limitaciones conocidas

### 1. Servicios de streaming detectan que estás en casa
Netflix, Disney+, Amazon Prime, etc., usan varios señales para determinar si accedes desde "tu hogar":
- **IP pública:** la VPN te hace salir por tu casa
- **Pero también:** geolocalización GPS, velocidad de red, historial de reproducción, dispositivo conocido, etc.

**Impacto:** la VPN ayuda, pero no garantiza acceso a contenido regional. Algunos servicios pueden seguir detectando que no estás en casa.

**Solución:** no hay una solución perfecta. Algunos usuarios reportan que funciona; otros que no. Depende del servicio y sus criterios.

### 2. TV antiguos / Smart TV no soportan WireGuard
Solo Android TV y Google TV tienen apps WireGuard. LG webOS, Samsung Tizen, etc., no las soportan.

**Impacto:** no puedes conectar un TV Samsung/LG directamente a la VPN.

**Solución:** usa un router con WireGuard integrado, o una Raspberry Pi adicional como puerta de enlace.

### 3. IPv6 deshabilitado en la VPN
`DISABLE_IPV6=true` en docker-compose.yml.

**Motivo:** la mayoría de redes domésticas usan solo IPv4. IPv6 requería configuración extra.

**Impacto:** dispositivos en la VPN usarán solo IPv4. Sitios solo-IPv6 no funcionarán (raro en 2026).

## Licencia

MIT – 2026, BertMarti

# SKILLS.md – Procedimientos operacionales

## Tabla de procedimientos

| Procedimiento | Comando | Tiempo |
|---------------|---------|--------|
| Instalar HEIMDALL | `./install.sh` | 2-3 min |
| Desinstalar (mantener clientes) | `./uninstall.sh` | <30 seg |
| Desinstalar (purgar todo) | `./uninstall.sh --purge` | <30 seg |
| Actualizar versión | `git pull && docker compose pull && docker compose up -d` | 1-2 min |
| Añadir un dispositivo (móvil) | Panel web → Nuevo cliente → QR | 1 min |
| Añadir un dispositivo (PC) | Panel web → Nuevo cliente → descargar .conf | 2 min |
| Revocar un dispositivo | Panel web → cliente → eliminar | <30 seg |
| Ver conectados ahora | Panel web → Pares | <5 seg |
| Cambiar contraseña | Panel web → Administración → Cambiar contraseña | 1 min |
| Configurar DuckDNS | `.env` → editar, `./install.sh` | 3 min |
| Ver logs en tiempo real | `docker compose logs -f wg-easy` | — |
| Testear conexión VPN | `wg-quick up client.conf` (desde otra máquina) | 5 seg |

---

## 1. Instalar HEIMDALL

### Requisitos previos
- Raspberry Pi con SSH habilitado
- Docker y Docker Compose (script lo instala si falta)
- Puerto 51820 UDP libre en la Raspberry
- Acceso a la configuración del router (para reenvío de puertos)

### Pasos

```bash
ssh pi@raspberrypi.local
cd ~
git clone https://github.com/BertMarti/HEIMDALL.git
cd HEIMDALL
./install.sh
```

**Resultado esperado:**
```
✔ Docker disponible
✔ Creado .env
✔ LAN_IP = 192.168.1.10
✔ PI_HOSTNAME = raspberrypi
✔ WG_ADMIN_PASSWORD = (generada)
✔ WG_HOST = (tu IP pública)
✔ WG_DNS = (SHIELD-DNS si está instalado, o 1.1.1.1)
✔ Panel web funcionando
```

### Después de instalar: reenvío de puertos

**Importante:** sin esto, solo puedes conectar desde dispositivos en tu red Wi-Fi.

1. Entra en tu router (suele ser 192.168.1.1)
2. Busca "Reenvío de puertos" o "Port Forwarding"
3. Crea una regla:
   - **Protocolo:** UDP
   - **Puerto externo:** 51820
   - **Puerto interno:** 51820
   - **Dirección interna:** IP de la Raspberry Pi (ej. 192.168.1.10)
4. Guarda y reinicia el router si es necesario

---

## 2. Añadir un dispositivo (móvil)

### Pasos

1. En la Raspberry, accede a `https://<IP>:51843`
   - Usuario: `admin` (o el que esté en `.env`)
   - Contraseña: la de `.env`

2. Haz clic en "Nuevo cliente" o "+ Nuevo cliente"

3. Se genera un código QR

4. En el móvil:
   - Descarga **WireGuard** (App Store o Google Play)
   - Abre la app
   - Toca "+"
   - Elige "Crear desde código QR"
   - Escanea el QR de la pantalla

5. La app importa el perfil. Toca "Activar" para conectar

**Resultado:** el móvil se conecta a tu red como si estuviera en casa. Si tienes SHIELD-DNS instalado, la publicidad se bloquea automáticamente.

---

## 3. Añadir un dispositivo (PC/Mac)

### Pasos

1. En la Raspberry, accede a `https://<IP>:51843`

2. Haz clic en "Nuevo cliente"

3. Se genera un código QR. Debajo, hay un botón "Descargar" para descargar el archivo `.conf`

4. En el PC/Mac:
   - Descarga e instala **WireGuard** desde https://www.wireguard.com/
   - Abre la app
   - Toca "+" → "Importar túnel(es) desde archivo"
   - Elige el `.conf` descargado

5. El perfil aparece en la lista. Toca "Activar" para conectar

---

## 4. Añadir un dispositivo (TV Android)

### Pasos

1. En la Raspberry, genera un cliente (igual que móvil/PC)

2. En el TV (con Android TV / Google TV):
   - Descarga **WireGuard** de Google Play
   - Abre la app
   - Toca "+"
   - Elige "Crear desde código QR"

3. Desde otro dispositivo (móvil/PC), **muestra el QR** de la pantalla de la Raspberry

4. El TV escanea el QR y conecta

**Nota:** La mayoría de TVs normales (LG, Samsung, etc.) no soportan WireGuard. Solo Android TV y Google TV lo tienen.

---

## 5. Revocar un dispositivo (borrar acceso)

### Desde el panel web

1. Accede a `https://<IP>:51843`

2. Busca el dispositivo en la lista

3. Haz clic en el icono de papelera o "Eliminar"

4. Confirma

**Resultado:** el dispositivo pierde acceso inmediatamente. El perfil descargado antes quedará inválido.

---

## 6. Ver dispositivos conectados

1. En el panel web, ve a "Pares" o "Peers"

2. Verás una tabla con:
   - **Nombre:** nombre del cliente
   - **Conectado hace:** cuándo fue el último handshake (si es hace poco, está conectado)
   - **Datos enviados/recibidos:** tráfico pasado por este cliente
   - **Acciones:** borrar cliente

---

## 7. Cambiar la contraseña del panel

### Desde el panel web (recomendado)

1. Accede a `https://<IP>:51843`

2. Entra en "Administración" o "Admin"

3. Busca "Cambiar contraseña" o "Change password"

4. Introduce:
   - Contraseña actual
   - Contraseña nueva
   - Confirma

5. Guarda

**Nota:** la contraseña en `.env` no se sincroniza automáticamente.

### Si olvidaste la contraseña

1. En la Raspberry:
   ```bash
   cd /ruta/a/HEIMDALL
   nano .env
   ```

2. Busca `WG_ADMIN_PASSWORD=` y pon una nueva

3. Guarda (Ctrl+X en nano)

4. Reinicia:
   ```bash
   docker compose up -d
   ```

5. Accede con la nueva contraseña

---

## 8. Configurar DNS dinámico (DuckDNS)

### Problema: tu IP pública cambia frecuentemente

Si tu ISP te cambia la IP (cada día, cada semana), los clientes VPN no podrán reconectar.

### Solución: DuckDNS (gratuito)

#### Paso 1: Crear un subdominio en DuckDNS

1. Entra en https://www.duckdns.org
2. Crea una cuenta (Gmail, GitHub, etc.)
3. Haz clic en "Crear subdominio"
4. Elige un nombre (ej. `micasa`)
5. Se crea automáticamente `micasa.duckdns.org`
6. Copia el **TOKEN** (cadena larga)

#### Paso 2: Configurar en HEIMDALL

1. En la Raspberry:
   ```bash
   cd /ruta/a/HEIMDALL
   nano .env
   ```

2. Rellena:
   ```
   DUCKDNS_SUBDOMAIN=micasa
   DUCKDNS_TOKEN=abc123def456ghi789jkl012
   ```

3. Guarda

4. Vuelve a ejecutar el instalador:
   ```bash
   ./install.sh
   ```

5. Verifica que `WG_HOST` en `.env` ahora es `micasa.duckdns.org`

6. En el panel web, comprueba que "Administración" → "General" → "Endpoint" muestra `micasa.duckdns.org`

**Resultado:** aunque tu ISP cambie tu IP pública, `micasa.duckdns.org` siempre te apuntará.

---

## 9. Verificar que la VPN funciona desde fuera

### Desde un dispositivo en otra red (4G/5G, otra casa, etc.)

1. Activa el perfil WireGuard en el dispositivo

2. Espera a que aparezca "Conectado"

3. Verifica conectividad:
   - **Ping:** `ping 10.8.0.1` (el servidor VPN)
   - **DNS:** `ping google.com` (debe resolver)
   - **IP pública:** visita https://api.ipify.org (debe mostrar la IP de tu casa, no la del ISP del dispositivo)

---

## 10. Revisar logs

### Ver eventos de conexión en tiempo real

```bash
cd /ruta/a/HEIMDALL
docker compose logs -f wg-easy
```

**Resultado esperado:**
```
[+] Client connected: usuario1
[+] Client connected: usuario2
[-] Client disconnected: usuario1
```

Presiona **Ctrl+C** para salir.

### Ver logs de Caddy (certificados TLS)

```bash
docker compose logs -f caddy
```

---

## 11. Actualizar a la última versión

```bash
cd /ruta/a/HEIMDALL
git pull
docker compose pull
docker compose up -d
```

Tus clientes seguirán funcionando. Los perfiles VPN se preservan en `data/wireguard/`.

---

## 12. Desinstalar sin perder clientes

```bash
./uninstall.sh
```

**Resultado:** los contenedores se detienen y se eliminan, pero `data/` se preserva.

Si ejecutas `./install.sh` después, recuperarás todos tus clientes.

---

## 13. Desinstalar y borrar todo

```bash
./uninstall.sh --purge
```

**Resultado:** los contenedores, `data/` y `.env` se eliminan.

**Advertencia:** todos los clientes VPN quedarán inválidos (sus perfiles dejarán de funcionar).

---

## Troubleshooting

| Problema | Diagnóstico | Solución |
|----------|-------------|----------|
| VPN no funciona desde fuera | ¿Puerto 51820 UDP reenviado en router? | Ve a tu router → Port Forwarding → comprueba regla |
| Panel retorna 502 | `docker compose logs caddy` | Reinicia: `docker compose restart` |
| "Certificado inválido" en navegador | Normal (autofirmado) | Haz clic en "Avanzado" → "Continuar" |
| Cambié WG_HOST pero panel no cambió | WG_HOST solo se aplica al arranque | Cambia desde panel → "Endpoint" |
| Cliente no puede conectar | ¿Está el servidor corriendo? | `docker compose ps` → busca `Up` |
| Olvidé contraseña admin | `.env` tiene la anterior | Edita `.env`, cambia `WG_ADMIN_PASSWORD`, ejecuta `docker compose up -d` |
| Un dispositivo se perdió | ¿Lo eliminaste del panel? | Lo siento, el perfil es inválido; crea uno nuevo |
| IPv4 de la VPN no es mi casa | ¿Está bien el reenvío de puertos? | Comprueba que tu IP pública es la del reenvío |

---

## Verificación rápida: "¿Funciona mi VPN?"

```bash
# 1. En la Raspberry
docker compose ps
# Resultado: wg-easy y caddy deben estar "Up"

# 2. Desde otro dispositivo en la red
curl -k https://192.168.1.X:51843  # X = IP de la Raspberry
# Resultado: debe retornar un HTML o 302 (redirect)

# 3. Desde la Raspberry misma
curl -k -u admin:PASSWORD https://127.0.0.1:51843/api/client | jq
# Resultado: debe listar los clientes en JSON

# 4. Conecta un cliente desde fuera de tu red (4G/5G)
# Activa el perfil VPN
# Espera a "Conectado"
# Verifica: ping 10.8.0.1
```

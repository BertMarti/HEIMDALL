# SKILLS.md - Procedimientos operacionales

## Tabla de procedimientos

| Procedimiento | Comando o lugar | Tiempo |
|---|---|---|
| Instalar HEIMDALL | `./install.sh` | 2-3 min |
| Desinstalar manteniendo clientes | `./uninstall.sh` | <30 s |
| Desinstalar y purgar todo | `./uninstall.sh --purge` | <30 s |
| Actualizar | `./update.sh` | 1-2 min |
| Añadir móvil | Panel -> Nuevo cliente -> QR | 1 min |
| Añadir PC/Mac | Panel -> Nuevo cliente -> descargar `.conf` | 2 min |
| Revocar dispositivo | Panel -> cliente -> eliminar | <30 s |
| Ver conectados | Panel -> Pares | <5 s |
| Cambiar contraseña | Panel -> Administración | 1 min |
| Configurar DuckDNS | `.env` y `./install.sh` | 3 min |
| Ver logs | `docker compose logs -f wg-easy` | - |
| Probar VPN | `wg-quick up client.conf` desde otra máquina | 5 s |

## 1. Instalar HEIMDALL

Requisitos: Raspberry Pi o PC Linux, SSH si procede, Docker (el instalador lo instala si falta), puerto UDP `51820` libre y acceso al router.

```bash
ssh usuario@192.168.1.50
cd ~
git clone https://github.com/BertMarti/HEIMDALL.git
cd HEIMDALL
./install.sh
```

El resultado esperado incluye Docker disponible, `.env` creado, `LAN_IP`, `PI_HOSTNAME`, contraseña generada, `WG_HOST`, DNS seleccionado y panel funcionando. Después crea en el router una regla UDP `51820` -> `192.168.1.50:51820`.

## 2. Añadir un móvil

1. Abre `https://192.168.1.50:51843` desde casa.
2. Crea un cliente nuevo y muestra el QR.
3. Instala WireGuard, pulsa `+`, elige crear desde QR y escanéalo.
4. Activa el túnel.

## 3. Añadir un PC o Mac

1. Crea el cliente en el panel y descarga el archivo `.conf`.
2. Instala WireGuard desde [wireguard.com](https://www.wireguard.com/).
3. Importa el túnel desde el archivo y actívalo.

## 4. Añadir una TV Android

En Android TV o Google TV instala WireGuard, crea un cliente y escanea el QR mostrado en otro dispositivo. Los televisores LG y Samsung normalmente no tienen aplicación WireGuard.

## 5. Revocar un dispositivo

En el panel, localiza el dispositivo, pulsa eliminar y confirma. El perfil descargado deja de funcionar. Para una suspensión temporal usa desactivar.

## 6. Ver dispositivos conectados

En `Pares` se muestran nombre, último handshake, tráfico y acciones disponibles.

## 7. Cambiar la contraseña

Desde el panel entra en Administración y cambia la contraseña. `.env` no se sincroniza automáticamente.

Si la has olvidado, desde la carpeta de HEIMDALL ejecuta:

```bash
docker compose exec -it wg-easy cli db:admin:reset
```

Introduce la nueva contraseña cuando la CLI la solicite. Editar `.env` no cambia una contraseña ya guardada.

## 8. Configurar DuckDNS

1. Crea un subdominio en [duckdns.org](https://www.duckdns.org) y copia el token.
2. En `.env` escribe:

   ```text
   DUCKDNS_SUBDOMAIN=micasa
   DUCKDNS_TOKEN=pega-aqui-tu-token
   ```

3. Ejecuta `./install.sh`.
4. En una instalación existente, cambia también el `Host` en el panel y regenera los perfiles si tenían la dirección antigua.

## 9. Verificar desde fuera

Con datos móviles u otra red, activa el perfil, espera el estado conectado, comprueba `ping 10.8.0.1` y visita `https://api.ipify.org`; debe mostrar la IP pública de casa.

## 10. Revisar logs

```bash
docker compose logs -f wg-easy
```

## 11. Actualizar

Usa el script del proyecto, que hace la copia antes de descargar cambios:

```bash
./update.sh
```

Los clientes se conservan en `data/wireguard/`.

## 12. Desinstalar sin perder clientes

```bash
./uninstall.sh
```

Detiene y elimina contenedores, pero conserva `data/` y `.env`. Volver a ejecutar `./install.sh` recupera los clientes.

## 13. Desinstalar y borrar todo

```bash
./uninstall.sh --purge
```

Elimina contenedores, `data/` y `.env`; todos los perfiles VPN quedan inválidos.

## Troubleshooting

| Problema | Diagnóstico | Solución |
|---|---|---|
| VPN no funciona desde fuera | Regla UDP 51820 y posible CG-NAT | Revisa router, IP LAN y operador |
| Panel 502 | `docker compose logs caddy` | `docker compose restart` |
| Certificado inválido | CA interna esperada | Continúa desde el aviso del navegador |
| WG_HOST no cambia | Solo aplica al primer arranque | Cambia el endpoint en el panel |
| Cliente no conecta | `docker compose ps` | Comprueba servicios y handshake |
| Contraseña olvidada | Base de datos ya inicializada | Usa `cli db:admin:reset` |
| IPv4 no es la de casa | Reenvío o endpoint incorrectos | Comprueba router y endpoint |

## Verificación rápida

```bash
# 1. Servicios
docker compose ps

# 2. Panel desde otra máquina de la LAN
curl -k https://192.168.1.50:51843

# 3. En el panel, comprueba que aparecen los clientes

# 4. Desde 4G/5G, activa el perfil y verifica ping 10.8.0.1
```

## Playbook

1. Copia: `./backup.sh`; guarda `backups/*.tar.gz` fuera de la máquina.
2. Restaura: clona el repositorio, copia el archivo a `backups/` y ejecuta `./restore.sh backups/<archivo>`.
3. Actualiza: `./update.sh`, que hace copia antes.

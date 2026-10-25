# MEMORY.md - Decisiones, pruebas y estado

## Decisiones de diseño

### wg-easy + Caddy

- `wg-easy` v15 gestiona WireGuard, clientes, perfiles, QR y API.
- Caddy 2 Alpine termina TLS y genera una CA interna.
- wg-easy escucha la web y la API en `51821/TCP` dentro de la red Docker; no publica ese puerto en el host.

### Red Docker

```text
docker network heimdall
├── wg-easy
│   ├── 51820/UDP publicado para clientes VPN
│   ├── 51821/TCP interno para Caddy
│   └── data/wireguard/
└── caddy
    ├── 51843/TCP publicado para la LAN
    ├── default_sni {$LAN_IP}
    └── data/caddy/
```

`default_sni {$LAN_IP}` es necesario para que el acceso por IP reciba el certificado correcto. IPv6 está desactivado con `DISABLE_IPV6=true` para evitar rutas y fugas DNS no controladas.

### Inicialización

`INIT_USERNAME`, `INIT_PASSWORD`, `INIT_HOST`, `INIT_PORT` e `INIT_DNS` solo se aplican cuando se crea por primera vez `data/wireguard/`. Cambios posteriores se hacen en el panel o con la CLI de wg-easy. Borrar esos datos reinicializa el servidor y los clientes.

### SHIELD-DNS

Si `shield-pihole` está activo durante la instalación, `install.sh` configura la IP LAN como `WG_DNS`; en otro caso usa `1.1.1.1`. Esto solo se decide al primer arranque.

## Puertos de los tres proyectos

| Proyecto | Servicio | Puerto | Protocolo | Notas |
|---|---|---:|---|---|
| ARIA | Web UI | 80 | TCP | Redirige a 443 |
| ARIA | Web UI | 443 | TCP | HTTPS |
| SHIELD-DNS | DNS | 53 | TCP/UDP | Servicio DNS |
| SHIELD-DNS | Panel HTTP | 8080 | TCP | Redirige a 8443 |
| SHIELD-DNS | Panel HTTPS | 8443 | TCP | Autofirmado |
| HEIMDALL | WireGuard | 51820 | UDP | Se reenvía en el router |
| HEIMDALL | Panel HTTPS | 51843 | TCP | Solo LAN, CA interna |

## Resultados de pruebas verificadas (2026-10-06)

### Test 1: Instalación idempotente
`./install.sh` ejecutado dos veces completó ambas ejecuciones sin errores ni cambios innecesarios. Conclusión: instalador idempotente.

### Test 2: Cliente mediante API
Una llamada autenticada a la API `/api/client` creó un cliente y devolvió su perfil WireGuard. Conclusión: API funcional con autenticación HTTP Basic.

### Test 3: Túnel VPN
Desde otra máquina se descargó un perfil, se levantó con `wg-quick`, respondió `10.8.0.1`, apareció `wg0` y el tráfico salió por la IP pública de casa. El handshake se confirmó en `wg show`.

### Test 4: DNS por la VPN
Con SHIELD-DNS instalado, una consulta a `doubleclick.net` desde un cliente conectado devolvió `0.0.0.0`. Conclusión: bloqueo activo.

### Test 5: TLS
Caddy devolvió `HTTP/2 200`; generó correctamente certificados autofirmados mediante su CA interna.

### Test 6: Clientes simultáneos
Tres clientes conectados en paralelo mantuvieron handshake y tráfico; el panel mostró los tres pares.

## Limitaciones conocidas

1. Streaming puede detectar que el dispositivo no está físicamente en casa aunque la IP pública sea la de casa.
2. Solo Android TV y Google TV tienen aplicación WireGuard; los televisores LG y Samsung no se conectan directamente.
3. CG-NAT impide el reenvío de puertos; DuckDNS resuelve el nombre, no el bloqueo del operador.
4. IPv6 está deshabilitado, por lo que los destinos solo IPv6 no funcionan.

## Decisiones de seguridad

- `install.sh` genera contraseñas aleatorias de 24 caracteres y las guarda en `.env` local.
- Caddy usa una CA interna; no se activa HSTS porque el certificado no es público.
- El panel solo se publica en la LAN; WireGuard es el único puerto que se reenvía desde internet.
- La API no se publica en el host y se usa detrás de Caddy.

## Copias de seguridad y actualización (2026-10-07)

`backup.sh`, `restore.sh` y `update.sh` se probaron en la Pi: copia, cambio y restauración devolvieron el estado guardado. `update.sh` siempre hace una copia antes de actualizar.

## 24/10/2026 - mejoras

- Se añadió `SECURITY.md`, la web estática en `site/` y la comprobación de puertos publicados en CI.
- Pages publica solo la web construida desde `site/`, no la documentación.
- `.gitleaks.toml` permite únicamente los tres marcadores administrativos concretos y el token de ejemplo documentado en esa configuración.
- Se corrigió la documentación: editar `.env` no cambia una contraseña ya inicializada; se usa `cli db:admin:reset`.
- La CI comprueba que solo se publican `51820/udp` y `51843/tcp`.
- Caddy añade cabeceras de seguridad al panel. **Sin HSTS a propósito**: el certificado es de la CA interna de Caddy y,
  con HSTS, el navegador no dejaría saltar su aviso. ARIA no incrusta el panel en un iframe, así que `X-Frame-Options DENY`
  no le afecta (comprobado en su código el 24/10/2026; conviene confirmarlo en la Pi tras fusionar).
- Imágenes: ver «24/10/2026 - fase 2» (todas fijadas con versión y digest).
- Scripts: solo arreglos de ShellCheck sin cambio de comportamiento (perfiles de compose en array, variable de bucle).

## Estado actual (24/10/2026)

Proyecto estable para uso doméstico, con CI de scripts, Compose, Caddy, secretos y web, workflow de Pages, copias probadas y documentación separada para usuarios y mantenimiento.

## 24/10/2026 - fase 2

- `wg-easy` queda fijado a `15.4.0` con digest; tras la revisión final también Caddy (`2.11.7-alpine@sha256:d8542f…`, lo que corre; ojo: `caddy:2.11.7` sin `-alpine` es otra variante con otro digest) y DuckDNS (`8d8f7eba-ls94@sha256:7736cb…`; etiqueta no semver de linuxserver, Dependabot puede no proponer subidas).
- Dependabot propone solo actualizaciones menores y parches de imágenes; las mayores requieren revisar la compatibilidad de ARIA con la API de wg-easy v15.
- `no-new-privileges:true` está probado en wg-easy y Caddy en un Compose aislado: ambos quedaron sanos, la API funcionó con Basic Auth a través de Caddy, se creó un cliente, se sirvió su QR y `wg0` quedó activo.
- Los límites de memoria quedan pendientes. Raspberry Pi OS arranca con `cgroup_disable=memory`, por lo que Docker muestra «No memory limit support». Activarlos requiere añadir `cgroup_enable=memory` a `/boot/firmware/cmdline.txt` y reiniciar; queda pendiente de decisión de Alberto.
- En el próximo `./update.sh` no se descargará wg-easy porque conserva el mismo digest, pero se recrearán una vez `heimdall-wg` y `heimdall-caddy` por el cambio de referencia y `security_opt`, con un corte de la VPN de unos segundos. Tampoco se descarga Caddy (mismo digest).
- El asistente del instalador, `--comprobar`, el resumen guiado y las pruebas con dobles quedaron incorporados en esta fase.

## Referencias

- [wg-easy](https://github.com/wg-easy/wg-easy)
- [WireGuard](https://www.wireguard.com/)
- [Caddy](https://caddyserver.com/docs/)
- [DuckDNS](https://www.duckdns.org/)
- [Docker Networking](https://docs.docker.com/network/)

# MEMORY.md – Decisiones, registro de pruebas e historial

## Decisiones de diseño

### Por qué wg-easy + Caddy

- **wg-easy v15:** interfaz web completa para gestionar clientes VPN, API REST, generación automática de perfiles
- **Caddy 2 Alpine:** reverse proxy ligero, genera certificados internos automáticamente (perfecto para redes domésticas)
- **Integración:** Caddy protege con TLS; wg-easy no necesita saber de HTTPS

### Topología de la red Docker

```
docker network heimdall
├── wg-easy (WireGuard VPN)
│   ├── Expone: 51820/UDP (público para clientes VPN)
│   ├── Expone: 51821/TCP (API interna, solo Caddy accede)
│   └── Genera claves en: data/wireguard/
│
└── caddy (reverse proxy HTTPS)
    ├── Lee: Caddyfile
    ├── Genera CA interna automáticamente
    ├── Expone: 51843/TCP (panel web seguro)
    └── Almacena certs en: data/caddy/
```

### Por qué INIT_* solo se aplican al arranque

Razón: wg-easy guarda configuración en `data/wireguard/`. Si el usuario edita `.env` después del primer arranque, esperaría que los cambios apliquen, pero los `INIT_*` están ignorados.

**Solución:** cambios posteriores se hacen desde el panel web. Si quieres cambios de `.env`, borra `data/wireguard/`.

### Caddyfile con `default_sni {$LAN_IP}`

```
default_sni {$LAN_IP}
```

Esto es crítico. Sin ella, navegadores que acceden por IP (ej. `https://192.168.1.10:51843`) sin TLS SNI (Server Name Indication) reciben un error de certificado.

**Por qué:** Caddy necesita saber qué certificado servir. Sin SNI, por defecto sirve el del primer host. `default_sni` le dice que use el certificado para `$LAN_IP`.

### Integración automática con SHIELD-DNS

En `install.sh`, líneas 48-56:
```bash
if $DOCKER ps --format '{{.Names}}' | grep -qx shield-pihole; then
  set_env WG_DNS "$LAN_IP_DET"  # Usa SHIELD-DNS
else
  set_env WG_DNS "1.1.1.1"      # Fallback Cloudflare
fi
```

Si Pi-hole está corriendo en la Raspberry, HEIMDALL lo detecta y configura automáticamente como DNS de la VPN. Esto hace que los clientes VPN tengan bloqueo de anuncios.

### IPv6 deshabilitado en la VPN

`DISABLE_IPV6=true` en docker-compose.yml.

Razón: casi toda la internet todavía es IPv4. IPv6 requería configuración adicional (subredes, routing). Para no complicar, se deshabilitó.

**Impacto:** sitios solo-IPv6 no funcionarán (extremadamente raro en 2026).

---

## Puertos de los tres proyectos

| Proyecto | Servicio | Puerto | Protocolo | Notas |
|----------|----------|--------|-----------|-------|
| **ARIA** | Web UI | 80 | TCP | Redirige a 443 |
| **ARIA** | Web UI | 443 | TCP | HTTPS |
| **SHIELD-DNS** | DNS | 53 | TCP/UDP | Obligatorio en la red |
| **SHIELD-DNS** | Panel HTTP | 8080 | TCP | Redirige a 8443 |
| **SHIELD-DNS** | Panel HTTPS | 8443 | TCP | Autofirmado |
| **HEIMDALL** | WireGuard | 51820 | UDP | Se reenvía en router |
| **HEIMDALL** | Panel HTTPS | 51843 | TCP | Autofirmado (CA interna) |

---

## Resultados de pruebas verificadas (2026-10-06)

### Test 1: Instalación idempotente
**Comando:**
```bash
./install.sh
./install.sh
```

**Resultado:** ambas ejecuciones completadas sin errores. La segunda no hizo cambios innecesarios.

**Conclusión:** ✓ El script es idempotente

### Test 2: Crear cliente via API
**Comando:**
```bash
curl -k -u admin:PASSWORD "https://127.0.0.1:51843/api/client" -X POST \
  -H "Content-Type: application/json" -d '{"name":"test_client"}'
```

**Resultado:** retorna JSON con el cliente creado, incluyendo el perfil WireGuard.

**Conclusión:** ✓ API WireGuard funciona con autenticación HTTP Basic

### Test 3: Túnel VPN funcional
**Comando (desde otra máquina):**
```bash
# Descargar config
curl -k -u admin:PASSWORD "https://RASPBERRY-IP:51843/api/client/TEST_ID/configuration" > test.conf

# Conectar
sudo wg-quick up ./test.conf

# Verificar
ip link show wg0
ping 10.8.0.1  # Servidor VPN

# Tráfico
curl https://api.ipify.org  # Debe retornar IP de la casa, no la del cliente
```

**Resultado:**
- Interfaz `wg0` aparece como `UP`
- `10.8.0.1` responde a ping (servidor accesible)
- Tráfico sale por IP pública de la Raspberry (correcto)
- Handshake confirmado en `docker exec heimdall-wg wg show`

**Conclusión:** ✓ Túnel VPN completamente funcional, datos pasan correctamente

### Test 4: DNS a través de VPN
**Comando:**
```bash
# Con SHIELD-DNS instalado
# Cliente VPN está conectado
dig +short doubleclick.net  # Desde cliente conectado
```

**Resultado:** `0.0.0.0` (bloqueado por SHIELD-DNS)

**Conclusión:** ✓ DNS dinámico a través de VPN funciona; bloqueo de anuncios activo

### Test 5: Certificados TLS
**Comando:**
```bash
curl -k -I https://127.0.0.1:51843/
```

**Resultado:**
```
HTTP/2 200
```

**Conclusión:** ✓ Certificados autofirmados generados por Caddy; navegadores los rechazan pero funcionan

### Test 6: Múltiples clientes simultáneos
**Setup:** 3 clientes conectados en paralelo

**Resultado:**
- Todos los handshakes activos
- Tráfico fluye por todos (ping, web, etc.)
- Panel web muestra 3 pares conectados

**Conclusión:** ✓ Múltiples clientes funcionan sin problemas

---

## Limitaciones conocidas

### 1. Streaming detecta que no estás en casa

Netflix, Disney+, Amazon Prime, etc., usan varias señales:
- **IP pública:** la VPN te hace salir por tu casa ✓
- **Pero también:** GPS, velocidad de red, dispositivo conocido, etc. ✗

**Impacto:** la VPN ayuda, pero no garantiza acceso a contenido regional.

**Solución:** no hay una perfecta. Algunos usuarios dicen que funciona; otros que no.

### 2. TVs normales no soportan WireGuard

Solo Android TV / Google TV tienen apps WireGuard.

**Impacto:** no puedes conectar un Samsung TV o LG TV directamente a HEIMDALL.

**Solución:** router con WireGuard integrado, o Raspberry Pi adicional como puerta de enlace.

### 3. CG-NAT de ISP

Si el ISP usa Carrier Grade NAT, la IP del router difiere de la IP pública real. El reenvío de puertos no funcionará.

**Impacto:** imposible conectar desde fuera sin DuckDNS (y aun así tendrías que usar el nombre de dominio, no la IP).

**Solución:** pedir al ISP una IP pública dedicada, o usar DuckDNS + aceptar que solo funciona si te da acceso publicitario.

### 4. IPv6 deshabilitado

Los dispositivos en VPN solo usan IPv4.

**Impacto:** sitios solo-IPv6 no funcionan (rarísimo).

---

## Changelog

### 2026-10-06 – Documentación completa

**Cambios:**
- Creados: README.md, CLAUDE.md, AGENTS.md, SKILLS.md, MEMORY.md, LICENSE

**Estado:**
- wg-easy v15 + Caddy 2 Alpine verificados
- Todas las pruebas de funcionalidad completadas con éxito
- Instalador idempotente confirmado
- Integración automática con SHIELD-DNS verificada
- Múltiples clientes simultáneos testeados

**Notas:**
- Proyecto estable para uso doméstico
- Documentación lista para usuarios no técnicos
- Procedimientos operacionales completos

---

## Decisiones de seguridad

### Contraseñas
- Generadas aleatoriamente (20 caracteres, sin `/+=`)
- Almacenadas en `.env` local (no en repo)
- Cambio manual: panel web

### Certificados TLS
- Caddy genera CA interna automáticamente (v2 feature)
- Autofirmados: navegadores mostrarán advertencia (normal)
- No hay verificación HTTPS real en LAN (no necesaria)

### Aislamiento de red
- Contenedores en red privada `heimdall`
- WireGuard (51820) reenviado públicamente (debe estar en router)
- Panel (51843) solo accesible en LAN

### API
- HTTP Basic auth (usuario + contraseña de `.env`)
- No expuesta públicamente
- Usada solo por Caddy internamente

---

## Roadmap futuro (especulativo)

- [ ] OAuth/OIDC integrado con ARIA
- [ ] Límites de ancho de banda por cliente
- [ ] Estadísticas detalladas de tráfico
- [ ] Backup automático de clientes
- [ ] Mobile app nativa (en lugar de web)
- [ ] Múltiples servidores VPN (balanceo)

No son compromisos, solo ideas.

---

## Referencias

- [wg-easy on GitHub](https://github.com/wg-easy/wg-easy)
- [WireGuard Official](https://www.wireguard.com/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [DuckDNS](https://www.duckdns.org/)
- [Docker Networking](https://docs.docker.com/network/)

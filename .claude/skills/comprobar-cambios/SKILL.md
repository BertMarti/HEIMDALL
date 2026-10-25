---
name: comprobar-cambios
description: Úsala antes de integrar cambios para ejecutar la validación estática de HEIMDALL.
---

# Skill: Comprobar cambios

Usa esta habilidad antes de realizar cualquier commit para asegurar la calidad y seguridad del código.

## 📋 Lista de comprobaciones

Ejecuta estos comandos en orden:

1. **Sintaxis Bash**:
   ```bash
   bash -n *.sh site/*.sh
   ```
2. **ShellCheck**:
   ```bash
   shellcheck *.sh site/*.sh
   ```
3. **Docker Compose**:
   ```bash
   # Usa un .env temporal de prueba
   cp .env.example /tmp/heimdall.env
   # Rellena valores mínimos
   sed -i -e 's/^WG_ADMIN_PASSWORD=.*/WG_ADMIN_PASSWORD=solo-para-ci/' -e 's/^WG_HOST=.*/WG_HOST=vpn.example.com/' -e 's/^LAN_IP=.*/LAN_IP=192.168.1.50/' -e 's/^PI_HOSTNAME=.*/PI_HOSTNAME=raspberrypi/' /tmp/heimdall.env
   docker compose --env-file /tmp/heimdall.env config -q
   ```
4. **Caddyfile**:
   ```bash
   docker run --rm -e LAN_IP=192.168.1.50 -e WEB_PORT=51843 -e PI_HOSTNAME=raspberrypi -v "$(pwd)/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2.11.7-alpine@sha256:d8542f48d34a9cf4e4c11a478865229840e87e4c96ea3f439101f31a5d35f75f caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
   ```
5. **Secretos (Gitleaks)**:
   ```bash
   gitleaks git . --redact --no-banner
   ```

Si todos pasan, el código está listo para ser integrado.

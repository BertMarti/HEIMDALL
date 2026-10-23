# Hoja de ruta de HEIMDALL

## Hecho (24/10/2026)

- [x] CI para scripts, Compose, Caddy, secretos y web.
- [x] Workflow de GitHub Pages para la web de `site/`.
- [x] `SECURITY.md`, guía técnica y documentación operativa.
- [x] Corrección del procedimiento de reset de contraseña.

## Siguiente

- [ ] Fijar `lscr.io/linuxserver/duckdns:latest` a una versión concreta.
- [ ] Probar `security_opt: no-new-privileges` y `read_only` sin romper WireGuard.
- [ ] Definir límites de memoria y CPU tras medir en Raspberry Pi.
- [ ] Tomar capturas reales actualizadas de la web.
- [ ] Fusionar la PR y comprobar que el workflow Pages publica la web.

## Ideas

- [ ] OAuth/OIDC con ARIA.
- [ ] Límites de ancho de banda por cliente.
- [ ] Estadísticas de tráfico.
- [ ] Backup automático de clientes.
- [ ] Varios servidores VPN.

Estas ideas no son compromisos.

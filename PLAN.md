# Hoja de ruta de HEIMDALL

## Hecho (24/10/2026)

- [x] CI para scripts, Compose, Caddy, secretos y web.
- [x] Workflow de GitHub Pages para la web de `site/`.
- [x] `SECURITY.md`, guía técnica y documentación operativa.
- [x] Corrección del procedimiento de reset de contraseña.
- [x] Asistente de instalación con valores por defecto y `./install.sh --comprobar`.
- [x] Fijar wg-easy a versión y digest; conservar Caddy en la rama 2.
- [x] Probar `security_opt: no-new-privileges` en wg-easy y Caddy en un Compose aislado.

## Siguiente

- [ ] Fijar `lscr.io/linuxserver/duckdns:latest` a una versión concreta.
- [ ] Probar `read_only` sin romper WireGuard.
- [ ] Decidir y definir límites de memoria y CPU tras medir en Raspberry Pi; antes hay que valorar activar `cgroup_enable=memory`.
- [ ] Tomar capturas reales actualizadas de la web.
- [ ] Fusionar la PR y comprobar que el workflow Pages publica la web.

## Ideas

- [ ] OAuth/OIDC con ARIA.
- [ ] Límites de ancho de banda por cliente.
- [ ] Estadísticas de tráfico.
- [ ] Backup automático de clientes.
- [ ] Varios servidores VPN.

Estas ideas no son compromisos.

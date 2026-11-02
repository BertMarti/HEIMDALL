# Changelog

## [1.0.0] - 2026-11-02

Primera versión estable: lo que corre en la Raspberry de casa desde octubre de 2026.

### Incluye
- VPN WireGuard con **wg-easy**: crear dispositivos, código QR y `.conf`, con el bloqueo de anuncios de SHIELD-DNS también fuera de casa.
- Panel HTTPS con Caddy y cabeceras de seguridad; solo se publican `51820/udp` y `51843/tcp`.
- Instalador guiado (`install.sh`, con `--comprobar`, `--sin-preguntas` y `--ayuda`), `update.sh`, `backup.sh`, `restore.sh` y `uninstall.sh`.
- Imágenes fijadas por versión y digest; `no-new-privileges` en wg-easy y Caddy; `.env` con permisos `600`.
- Integración con ARIA: dispositivos de la VPN, avisos de conexión y de ubicación nueva, y resumen diario.
- CI (ShellCheck, `docker compose config`, `caddy validate`, gitleaks, puertos publicados), Dependabot y web en GitHub Pages.

## [2026-10-24] Fase 2

### Añadido
- `install.sh --comprobar`, `--sin-preguntas` y `--ayuda`, además del asistente inicial de tres preguntas y el resumen con los siguientes pasos.
- 34 pruebas aisladas de `tests/instalador.sh` y su ejecución en CI.
- Sección «Empieza en 5 minutos» en la web.

### Cambiado
- `wg-easy` queda fijado a `15.4.0` y su digest exacto; Caddy a `2.11.7-alpine` con el digest que corre (`d8542f…`) y DuckDNS a `8d8f7eba-ls94` con digest.
- Dependabot queda limitado a versiones menores y parches de imágenes.
- `.env` se crea y conserva con permisos `600`; no se consulta la IP pública si `WG_HOST` ya está definido.

### Corregido
- El instalador ya no falla por consultar la IP pública en ejecuciones posteriores cuando `WG_HOST` ya existe.
- La comprobación previa informa de los arreglos exactos para Docker, arquitectura, herramientas y puertos.

### Seguridad
- `no-new-privileges:true` para wg-easy y Caddy, probado en un Compose aislado con API, cliente, QR y `wg0` funcionales.
- Los límites de memoria siguen pendientes porque Raspberry Pi OS usa `cgroup_disable=memory` por defecto.

## [2026-10-24]

### Añadido
- CI (`.github/workflows/ci.yml`): `bash -n`, ShellCheck, `docker compose config`, `caddy validate`, gitleaks y comprobación de la web.
- Dependabot semanal y agrupado para imágenes Docker y GitHub Actions.
- `.gitleaks.toml` con lista de permitidos concreta para marcadores de ejemplo antiguos.
- Cabeceras de seguridad en el panel (Caddy): nosniff, X-Frame-Options DENY, Referrer-Policy, Permissions-Policy y sin cabecera Server. En una instalación existente se aplican tras `./update.sh` con `docker compose restart caddy` (Caddy no recarga el `Caddyfile` solo).
- `PLAN.md`, `docs/DESARROLLO.md`, subagentes en `.claude/agents/` y skills en `.claude/skills/`.
- `SECURITY.md` para avisos privados de vulnerabilidades.
- Web estática en `site/` y workflow de GitHub Pages.
- Comprobación en CI de que solo se publican `51820/udp` y `51843/tcp`.

### Cambiado
- README orientado a usuarios, con enlace a la web; lo técnico pasa a `docs/DESARROLLO.md`.
- Arreglos de ShellCheck en los scripts sin cambiar su comportamiento.

### Corregido
- Documentación de contraseña: editar `.env` no cambia una contraseña ya inicializada; se usa `cli db:admin:reset`.
- Guía técnica y documentación operativa, conservando la información útil del README original.

## [2026-10-07]

- Añadidos backup, restauración y actualización.

## [2026-10-06]

- Primera versión con wg-easy v15, Caddy, instalación idempotente, SHIELD-DNS y DuckDNS opcional.

# Changelog

## [2026-10-24]

### Añadido
- CI (`.github/workflows/ci.yml`): `bash -n`, ShellCheck, `docker compose config`, `caddy validate`, gitleaks y comprobación de la web.
- Dependabot semanal y agrupado para imágenes Docker y GitHub Actions.
- `.gitleaks.toml` con lista de permitidos concreta para marcadores de ejemplo antiguos.
- Cabeceras de seguridad en el panel (Caddy): nosniff, X-Frame-Options DENY, Referrer-Policy, Permissions-Policy y sin cabecera Server.
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

# AGENTS.md - Guía para agentes de IA en HEIMDALL

HEIMDALL es una VPN autoalojada basada en WireGuard (`wg-easy` v15), con Caddy como proxy HTTPS. Forma parte del ecosistema ARIA junto con SHIELD-DNS y está pensado para Raspberry Pi o PC Linux con Docker.

## Estructura y reglas

- Los scripts principales están en la raíz: `install.sh`, `update.sh`, `backup.sh`, `restore.sh` y `uninstall.sh`.
- `docs/` contiene la guía técnica y las imágenes; `site/` contiene únicamente la web estática.
- `docker-compose.yml` define `wg-easy`, `caddy` y el perfil opcional `ddns`.
- `.env` y `data/` son locales y no deben leerse, solicitarse ni publicarse.
- Escribe documentación y mensajes en español de España.
- Los scripts Bash usan `#!/usr/bin/env bash` y `set -euo pipefail`, y deben ser idempotentes.
- Las variables `INIT_*` solo se aplican al crear por primera vez los datos de wg-easy. Después se usa el panel o la CLI.
- No cambies los nombres de servicio o contenedor, los puertos ni las redes: los usa ARIA.
- No subas versiones mayores de las imágenes sin revisar antes la compatibilidad con ARIA.

## Seguridad y producción

El repositorio es público: no incluyas IPs reales, dominios privados, nombres, MACs, claves, perfiles `.conf`, QR ni secretos. Ejemplos permitidos: `192.168.1.50`, `192.168.1.1`, `10.8.0.x`, `1.1.1.1` y `micasa.duckdns.org`.

HEIMDALL está en producción. No ejecutes `install.sh`, `update.sh`, `restore.sh` ni `uninstall.sh` sobre una instalación real sin autorización explícita. Tampoco ejecutes comandos Docker que manipulen los contenedores `heimdall-*`. Usa validación estática y máquinas de prueba.

## Trabajo con varios modelos

| Papel | Modelo | Uso |
|---|---|---|
| Orquestador | Claude Code, modelo Opus | Planificación, arquitectura, integración y revisión final |
| Código e interfaz | `openai/gpt-5.6-luna` | Cambios de código y UI siguiendo los patrones del proyecto |
| Documentación | `google/gemini-3-flash-preview` | Documentación y traducciones; si no hay cuota, `gemini-3.5-flash` o `gemini-3.7-flash` |
| Pruebas y accesibilidad sin datos sensibles | OpenCode Zen gratis: `big-pickle`, `mimo-v2.6-flash-free` | Consultas, verificaciones y borradores sin secretos |
| Revisión cruzada de solo lectura | `google/gemini-3.7-flash` con `--agent plan` | Auditoría independiente sin modificar archivos |

Claude orquesta y revisa. Los delegados trabajan en un worktree separado, no reciben secretos y no hacen commit, push ni despliegues.

## Validación

Ejecuta, cuando proceda:

```bash
bash -n *.sh site/*.sh
shellcheck *.sh site/*.sh
./install.sh --comprobar
tests/instalador.sh
cp .env.example /tmp/heimdall.env
sed -i -e 's/^WG_ADMIN_PASSWORD=.*/WG_ADMIN_PASSWORD=solo-para-ci/' -e 's/^WG_HOST=.*/WG_HOST=vpn.example.com/' -e 's/^LAN_IP=.*/LAN_IP=192.168.1.50/' -e 's/^PI_HOSTNAME=.*/PI_HOSTNAME=raspberrypi/' /tmp/heimdall.env
```

Para Caddy se usa un binario local o la misma imagen fijada en `docker-compose.yml` (la usa la CI) con `LAN_IP`, `WEB_PORT` y `PI_HOSTNAME`. No se valida ejecutando Docker sobre la máquina de producción.

Para previsualizar la web:

```bash
site/construir.sh /tmp/heimdall-web/HEIMDALL
python3 -m http.server 8000 -d /tmp/heimdall-web
```

La red real solo se puede verificar en hardware real. El reenvío depende del router y CG-NAT puede impedir conexiones entrantes.

## Ejemplos de tareas

- Documentación o cambios mecánicos: modelo de documentación.
- Revisar un flujo VPN, TLS, Docker o SHIELD-DNS: Claude y revisión cruzada de solo lectura.
- Implementar una función o una mejora de interfaz: `openai/gpt-5.6-luna` en worktree separado.
- Pruebas manuales sin datos sensibles y accesibilidad: OpenCode Zen gratis.

# CLAUDE.md - Guía para Claude Code en HEIMDALL

Lee primero [AGENTS.md](AGENTS.md). Claude Code es el orquestador: entiende la tarea, delega cuando conviene, revisa los resultados y ejecuta la validación final.

## Precauciones

- HEIMDALL está en producción. No ejecutes `install.sh`, `update.sh`, `restore.sh` ni `uninstall.sh` sin permiso explícito.
- No ejecutes Docker sobre los contenedores `heimdall-*` de una instalación real.
- Nunca imprimas, leas ni pidas `.env`, `data/`, claves privadas, perfiles WireGuard, QR o contraseñas.
- No cambies archivos fuera del alcance solicitado y no hagas commit salvo petición expresa.

## Skills y agentes

Los agentes viven en `.claude/agents/` y las skills en `.claude/skills/`. La skill `comprobar-cambios` se usa desde Claude Code; no se ejecuta mediante una orden de skill de OpenCode.

Usa `revisor-seguridad` para revisar secretos, exposición de puertos, TLS y privilegios. Usa `mantenedor-docs` cuando cambie la documentación, los procedimientos o la relación entre `.env.example` y la guía técnica.

## Validación

```bash
bash -n *.sh site/*.sh
shellcheck *.sh site/*.sh
docker compose --env-file /tmp/heimdall.env config -q
```

Para Caddy, valida con un binario local o con la imagen de Caddy fijada en `docker-compose.yml` y las variables `LAN_IP`, `WEB_PORT` y `PI_HOSTNAME`. Para la web:

```bash
site/construir.sh /tmp/heimdall-web/HEIMDALL
python3 -m http.server 8000 -d /tmp/heimdall-web
```

La API de wg-easy v15 la usa ARIA; para pruebas manuales usa el panel o la CLI `docker compose exec -it wg-easy cli`, sin copiar credenciales a comandos o logs.

## Commits

Solo si el usuario lo pide: autor `BertMarti`, email `107127310+BertMarti@users.noreply.github.com`, mensaje conciso en español y esta línea:

```text
Co-Authored-By: Claude <noreply@anthropic.com>
```

# 🔐 HEIMDALL - VPN para tu hogar

**Estado:** En desarrollo (esqueleto inicial)
**Versión:** 0.1.0
**Licencia:** MIT

## ¿Qué es HEIMDALL?

HEIMDALL convierte tu Raspberry Pi en un servidor **WireGuard** para que móvil, PC, tablet o TV se conecten a tu red de casa desde cualquier lugar, como si estuvieran en el salón.

### Funcionalidades previstas

- 🔒 VPN WireGuard (rápida y ligera en Raspberry Pi)
- 📱 Alta de dispositivos con código QR desde una web de gestión
- 🛡️ DNS de la VPN apuntando a SHIELD-DNS para bloquear publicidad
- 🔑 Acceso protegido con usuario/contraseña y HTTPS

> **Nota sobre plataformas de streaming:** salir a internet por la IP de tu casa ayuda a que el servicio te vea en tu hogar, pero Netflix, Disney+ y similares usan además otros criterios para detectar el hogar y pueden cambiar sus políticas. No es algo que este proyecto pueda garantizar.

## Estado actual

El repositorio contiene un servidor FastAPI mínimo (`/health` y un endpoint de prueba), el `Dockerfile` y el `docker-compose.yml`. La generación real de claves y configuraciones de WireGuard está pendiente.

## Requisitos

- Raspberry Pi 5 con Raspberry Pi OS de 64 bits, u otra distribución Linux
- Docker y Docker Compose
- Reenviar en el router el puerto UDP de WireGuard hacia la Raspberry Pi
- IP pública o un DNS dinámico (por ejemplo DuckDNS)

## Instalación

```bash
git clone https://github.com/BertMarti/HEIMDALL.git
cd HEIMDALL
cp .env.example .env
docker compose up -d
```

## Documentación para agentes

- [CLAUDE.md](CLAUDE.md) – instrucciones para Claude Code
- [AGENTS.md](AGENTS.md) – reparto de tareas entre agentes
- [SKILLS.md](SKILLS.md) – capacidades
- [MEMORY.md](MEMORY.md) – memoria y decisiones del proyecto

## Licencia

MIT

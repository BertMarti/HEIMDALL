# 🔐 HEIMDALL - Centralized VPN

**Status:** Pre-release
**Version:** 0.1.0

## What is HEIMDALL?

HEIMDALL es una VPN centralizada que te permite acceder a tu hogar desde cualquier lugar en España.

### Features
- 🔒 WireGuard encryption
- 🌐 Access from anywhere
- 🔧 Easy device management
- 📱 Mobile + Desktop support
- 🆓 Completely free

## Quick Start

```bash
docker-compose up -d
```

## Architecture

```
WireGuard (1194/UDP)
├── Key generation
├── Client management
└── Traffic routing
```

## License

MIT

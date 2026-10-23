---
name: publicar-web
description: Úsala cuando haya que construir, revisar o publicar la web estática de HEIMDALL en Pages.
---

# Skill: Publicar web

Esta habilidad permite validar y desplegar la web oficial de HEIMDALL.

## 🧪 Probar en local

Antes de subir cambios a la web (`site/`), pruébalos:

1. Ejecuta el script de construcción:
   ```bash
   site/construir.sh /tmp/heimdall-web/HEIMDALL
   ```
2. Levanta un servidor temporal:
   ```bash
   python3 -m http.server 8000 -d /tmp/heimdall-web
   ```
3. Abre `http://localhost:8000/` y verifica el diseño, modo oscuro y enlaces.

## 🚀 Despliegue

El despliegue es automático mediante GitHub Actions:

1. Asegúrate de que los cambios en `site/` son correctos.
2. Haz push a la rama `main`.
3. El workflow `Pages` se activará y publicará en `https://bertmarti.github.io/HEIMDALL/`.

> [!NOTE]
> La construcción copia el contenido de `site/` y las imágenes de `docs/img/` al directorio raíz de la web. Pages publica solo esa salida; no publica la documentación Markdown.

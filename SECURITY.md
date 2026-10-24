# Seguridad

HEIMDALL es una VPN casera: un fallo de seguridad puede abrir la puerta de una casa. Gracias por avisar con discreción.

## Cómo avisar de un fallo

- **No abras una issue pública.** Usa el aviso privado de GitHub:
  [Security → Report a vulnerability](https://github.com/BertMarti/HEIMDALL/security/advisories/new).
- Cuenta qué has visto, cómo reproducirlo y qué versión usas (`git log -1 --oneline`).
- **Nunca** incluyas tu `.env`, claves de WireGuard, perfiles `.conf`, códigos QR, IPs públicas ni contraseñas.

Respondo en cuanto pueda (es un proyecto personal, sin plazos garantizados). Si el fallo se confirma, se arregla en `main`
y se explica en el [CHANGELOG](CHANGELOG.md).

## Versiones con soporte

Solo la última versión de la rama `main`. Actualiza con `./update.sh`.

## Buenas prácticas para quien lo instala

- Abre en el router **solo** el puerto UDP de WireGuard (51820). El panel (51843) nunca debe verse desde internet.
- Guarda las copias de `./backup.sh` fuera de la máquina y en un sitio seguro: contienen claves privadas.
- Si pierdes un dispositivo, desactívalo o bórralo en el panel cuanto antes.
- Mantén la Raspberry y las imágenes al día (`sudo apt upgrade` y `./update.sh`).

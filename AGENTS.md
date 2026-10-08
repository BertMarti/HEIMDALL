# AGENTS.md – Distribución de trabajo para agentes

## Reparto recomendado

### Modelo económico (ej. Haiku)
**Tareas:** edición de documentación, cambios mecánicos, verificación de sintaxis

- Actualizar `.env.example` con nuevas variables
- Editar README.md y procedimientos
- Cambios en puertos o variables de configuración
- Revisar que Caddyfile esté bien formado
- Formatear scripts bash

### Modelo de razonamiento profundo (ej. Opus)
**Tareas:** debugging de red/VPN, diseño arquitectónico, resolución de problemas complejos

- Debuguear problemas de conectividad VPN
- Diseñar cambios en la topología de Docker
- Resolver conflictos de certificados o TLS
- Integración entre HEIMDALL y SHIELD-DNS
- Procedimientos de migración de datos o cambios de endpoint
- Testing end-to-end de túneles VPN

## División por área

| Área | Modelo económico | Modelo fuerte | Notas |
|------|------------------|---------------|-------|
| Documentación, README | ✓ | — | Edición directa, sin complejidad de red |
| .env.example, variables | ✓ | — | Cambios simples; lógica de dependencias → fuerte |
| docker-compose.yml | — | ✓ | Cambios de red, INIT_* requieren validación |
| Caddyfile | — | ✓ | TLS/SNI es crítico; errores rompen conectividad |
| Scripts bash | — | ✓ | Lógica condicional, idempotencia, manejo de errores |
| Debugging de conectividad | — | ✓ | Requiere entender WireGuard, iptables, DNS, routing |
| Integración con SHIELD-DNS | — | ✓ | Coordinación entre dos proyectos, testing completo |
| Testing de VPN | — | ✓ | Crear clientes, conectar túneles, verificar datos |

## Flux de trabajo sugerido

1. **Tarea en modelo económico:** actualizar documentación o variables simples
   - Lee el archivo, verifica con `git diff`
   - Commitea si es seguro (sin cambios de lógica)

2. **Tarea en modelo fuerte:** debugging o cambios de arquitectura
   - Lee docker-compose.yml, Caddyfile, install.sh
   - Entiende las dependencias (INIT_*, LAN_IP, WG_HOST, etc.)
   - Toma decisiones de diseño
   - Crea un cliente de prueba y verifica el túnel
   - Commitea con mensaje detallado en español

3. **Trabajo en paralelo:** si hay dos tareas independientes (doc + bugfix), dos agentes pueden trabajar en paralelo

## Limitaciones conocidas

- No hay CI/CD automatizado (tests manuales via SSH en la Pi)
- Cambios de red requieren verificación manual en hardware real
- El reenvío de puertos depende de la configuración de cada router (no es verificable remotamente)
- CG-NAT de algunos ISPs impide reenvío de puertos; no hay solución en el código

## Ejemplos de tareas

### Tarea A: "Actualizar instrucciones de DuckDNS en README"
→ **Modelo económico** (edita README.md)

### Tarea B: "Debuguear por qué Caddy retorna 'certificate verify failed'"
→ **Modelo fuerte** (verifica Caddyfile, SSL/TLS, usa `docker logs`)

### Tarea C: "Hacer que HEIMDALL detecte automáticamente SHIELD-DNS"
→ **Modelo fuerte** (complejo: requiere cambiar install.sh, testing)

### Tarea D: "Un cliente no puede conectar desde fuera de casa"
→ **Modelo fuerte** (debugging: CG-NAT?, puerto reenviado?, firewall?)

### Tarea E: "Añadir nuevo parámetro 'WG_SUBNET' al .env.example"
→ **Modelo económico** (edita .env.example, README)

### Tarea F: "Implementar backup automático de perfiles VPN"
→ **Modelo fuerte** (script complejo, testing, integración con .env)

## Reunión diaria (si hay sprints)

- **Modelo económico:** repasa cambios de doc y variables de la mañana
- **Modelo fuerte:** planifica cambios de red, verifica tests, coordina con SHIELD-DNS si es necesario

## Trabajo con varios modelos (opcional, vía OpenCode)

Un agente orquestador (por ejemplo Claude en Claude Code) puede repartir tareas entre los modelos que tengas conectados en [OpenCode](https://opencode.ai): GitHub Copilot, ChatGPT, Gemini, modelos gratuitos de OpenCode Zen, etc. Así se ahorra cuota del modelo principal sin perder el control.

**Papeles**
- **Orquestador:** entiende la petición, planifica, divide en tareas pequeñas con rutas y objetivo concretos, revisa todo lo que vuelve, pasa las pruebas, hace commit y despliega. Es el único que hace commit, push o despliega.
- **Delegados:** reciben una tarea cerrada (escribir una función, redactar documentación, revisar un diff) y devuelven el resultado.

**Cómo delegar**
```bash
opencode models                    # modelos disponibles (proveedor/modelo)
opencode auth list                 # cuentas conectadas
# Revisión o consulta, sin tocar archivos:
opencode run --agent plan -m <proveedor/modelo> --dir <repo> "Revisa ... y lista los problemas"
# Cambios: siempre en un worktree aparte, nunca en la copia desplegada
git worktree add ../.wt/<tarea> -b feat/<tarea>
opencode run -m <proveedor/modelo> --dir ../.wt/<tarea> "Implementa ... siguiendo AGENTS.md"
```

**Reparto orientativo**
| Tarea | Modelo |
|---|---|
| Diseño, seguridad, depuración difícil, revisión final | El más capaz (orquestador) |
| Implementar funciones siguiendo un patrón existente | Modelo de código (Copilot / GPT) |
| Documentación, traducciones, textos | Modelo rápido (Gemini / Copilot) |
| Búsquedas, resúmenes, borradores sin datos sensibles | Modelos gratuitos (Zen) |

**Reglas**
- Nunca pases a un delegado secretos, `.env`, contraseñas ni datos personales. Con los modelos **gratuitos**, todavía menos: algunos usan lo que reciben para entrenar.
- Los delegados no hacen commit, push ni despliegues, ni tocan servicios en marcha. Las revisiones se hacen con `--agent plan` (solo lectura).
- Todo lo que devuelva un delegado lo revisa el orquestador y pasa la suite completa de pruebas antes de integrarse.
- Dale a cada delegado el contexto que necesita (rutas, este `AGENTS.md`, criterios de aceptación): no comparte la memoria del orquestador.

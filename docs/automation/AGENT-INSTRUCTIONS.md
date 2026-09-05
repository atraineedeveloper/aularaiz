# Instrucciones para agentes externos (OpenClaw u otros)

Estas reglas aplican a cualquier agente automatizado que opere el CLI de AulaRaíz — `aula`, `aularaiz` o `aularaiz-agent.exe` (o `dart run bin\aularaiz_agent.dart` en desarrollo). El contrato completo de comandos, JSON y errores está en [`docs/automation/agent-cli.md`](./agent-cli.md).

1. **Incluye `--format json` en todos los comandos, incluso `--help` y `status`.** Sin esa opción la salida es legible para personas, también al redirigirla. Ejecuta `status --format json` primero. Confirma que la base existe (`database.exists`) y lee las capacidades antes de cualquier otra operación.
2. **No uses `--include-personal-data` sin autorización explícita del docente.** La salida minimizada es suficiente para casi todo flujo de trabajo.
3. **Toda mutación es dry-run por defecto.** Ejecuta primero sin `--apply`, revisa el resultado, y usa `--apply` sólo con permiso explícito del usuario en esa misma conversación.
4. **Las eliminaciones (`school-delete`, `group-delete`, `activity-delete`) requieren `--apply` Y `--confirm-delete`.** Nunca las ejecutes sin confirmación directa; son irreversibles.
5. **Nunca envíes salida del agente ni datos de AulaRaíz a la red, telemetría o servicios externos** (incluidas IAs remotas) sin consentimiento explícito y diseñado por separado.
6. **Usa `--text-stdin` para notas y textos sensibles** de `student-note`; nunca coloques contenido sensible en la línea de comandos.
7. **No inventes comandos ni SQL directo.** Descubre IDs con `schools`, `groups`, `projects`, `activities` y `students`; muta sólo con los comandos documentados.
8. **Nunca apliques mutaciones contra la base de producción sin respaldo** ni autorización. Para experimentar usa `--profile demo` o una base temporal con `--database`.

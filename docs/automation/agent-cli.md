# AulaRaiz Agent CLI — Contrato canónico

Versión del contrato: `aularaiz.automation/v1` (estable; se valida en CI).

El ejecutable `aularaiz-agent.exe` (fuente: `bin/aularaiz_agent.dart`) es un agente Dart **independiente de Flutter** que lee y, con autorización explícita, escribe en la base SQLite local de AulaRaíz. No realiza llamadas de red. Toda consulta pasa por repositorios y casos de uso del dominio; el CLI no ejecuta SQL de dominio.

Fuente de verdad del contrato: este documento. La documentación de fase (`docs/phase-9/local-automation.md`) se mantiene como referencia histórica.

## Comando de terminal

A partir del instalador 0.1.12, el instalador registra `%LOCALAPPDATA%\Programs\AulaRaiz\automation\bin` en el `Path` del usuario. En cualquier terminal **nueva** (PowerShell, CMD) el agente responde a tres nombres equivalentes:

```
aula --help          # comando corto (recomendado)
aularaiz --help      # nombre largo
aularaiz-agent --help
```

- Las terminales ya abiertas antes de instalar deben reabrirse para heredar el `Path` actualizado.
- El alta es idempotente: reinstalar o actualizar no duplica la entrada.
- Sin instalador (desarrollo), usa `dart run bin\aularaiz_agent.dart ...` o `.\tool\aularaiz-agent.ps1 ...`.

En los ejemplos de abajo se usa `aula`; los tres nombres aceptan las mismas opciones.

## Contrato de salida

Todos los comandos (incluidos los errores) imprimen un único JSON en `stdout`:

```json
{
  "schema": "aularaiz.automation/v1",
  "kind": "...",
  "generated_at": "2026-09-01T12:00:00.000Z",
  "privacy": { "personal_data_included": false, "mode": "minimized" },
  "data": {}
}
```

- `kind` identifica el comando (`status`, `schools`, `projects`, …) o `error`.
- `privacy.mode` es `minimized` por defecto y `explicit-opt-in` sólo con `--include-personal-data`.
- Los errores nunca incluyen stack traces, rutas internas ni contenido de notas.

### Errores y códigos de salida

| Código | Exit | Significado |
| --- | --- | --- |
| `usage` | 2 | Argumentos inválidos, opción desconocida, falta un valor, o eliminación con `--apply` sin `--confirm-delete`. |
| `invalid-input` | 2 | Valor de opción con formato inválido (fecha, grado, entero, catálogo). |
| `database-not-found` | 3 | No se encontró la base local y no se indicó `--database`. |
| `database-open-failed` | 3 | La base existe pero no se pudo abrir. |
| `data-state` | 4 | La operación violó una regla del dominio (referencia inexistente, solapamiento de contratos, etc.). |
| `automation-failed` | 1 | Fallo inesperado y genérico. |

## Opciones globales

| Opción | Descripción |
| --- | --- |
| `--database <ruta>` | Ruta explícita del archivo SQLite a usar. |
| `--profile production\|demo` | Perfil de almacenamiento para el descubrimiento automático (por defecto `production`). |
| `--apply` | Ejecuta la escritura real. Sin esta bandera toda mutación es dry-run. |
| `--confirm-delete` | Confirmación adicional requerida por eliminaciones ejecutadas con `--apply`. |
| `--include-personal-data` | Expande identidades en la salida. Requiere autorización explícita del docente. |
| `--text-stdin` | Lee el texto de `student-note` desde stdin (evita historial del shell). |
| `--pretty` | JSON con indentación. |
| `--help` | Contrato de ayuda en JSON (lo valida CI). |

## Comandos de lectura

Ningún comando de lectura expone identidad de alumnos por defecto.

### `status`

```powershell
aularaiz-agent.exe status --pretty
```

Configuración activa, ciclo escolar, conteo de grupos y capacidades. Si no hay base, responde con `database.exists = false`.

### `schools`

```powershell
aularaiz-agent.exe schools --pretty
```

Escuelas registradas con id, nombre, ciclo activo y organización. Útil para descubrir `--school <id>` antes de mutar.

### `groups`

```powershell
aularaiz-agent.exe groups --pretty
```

Grupos del ciclo activo: id, nombre, grados, multigrado y turno. Útil para descubrir `--group <id>`.

### `projects --group <id>`

```powershell
aularaiz-agent.exe projects --group demo-group --pretty
```

Proyectos del grupo: id, título, ciclo de vida, metodología y grados objetivo. Sin datos personales.

### `activities --project <id>`

```powershell
aularaiz-agent.exe activities --project demo-project-community --pretty
```

Actividades del proyecto: id, título, campo formativo, grados y `occurs_on` opcional. Sin datos personales.

### `students --group <id>`

```powershell
# Minimizado por defecto: sólo conteos.
aularaiz-agent.exe students --group demo-group --pretty

# Con autorización explícita: identidades.
aularaiz-agent.exe students --group demo-group --include-personal-data --pretty
```

Por defecto devuelve `student_count`, `active_count`, `inactive_count` y `enrollment_by_grade`, sin identidades. Con `--include-personal-data` agrega `students` con `student_id`, nombre, número de lista, grado, estado activo y fechas de matrícula (la última inscripción por alumno).

### `group-summary --group <id> --month YYYY-MM`

Conteos agregados de asistencia/evaluación del mes. Con `--include-personal-data` agrega métricas por alumno.

### `recommend --group <id> --month YYYY-MM`

Señales con evidencia (inasistencias, retardos, apoyo requerido, no entregados, evaluaciones pendientes). No son diagnósticos.

### `database-diagnose`

```powershell
aularaiz-agent.exe database-diagnose --pretty
```

Diagnóstico **de sólo lectura**: `integrity` (resultado de `PRAGMA integrity_check`), `foreign_key_violation_count`, `user_version` y `expected_version`. No repara nada; la reparación sigue siendo manual y respaldada.

## Comandos de mutación

Todas las mutaciones son **dry-run por defecto**: validan referencias y reglas del dominio, reportan `dry_run: true` y **no escriben**. Sólo escriben con `--apply`. Ninguna mutación requiere `--confirm-delete` salvo las eliminaciones.

### `workspace-create`

Crea escuela + ciclo + grupo como una sola alta (conserva escuelas anteriores).

```powershell
aularaiz-agent.exe workspace-create `
  --school-name "Primaria Nueva" `
  --school-year 2027-2028 `
  --starts-on 2027-08-30 `
  --ends-on 2028-07-14 `
  --group-name "2.º B" `
  --grades 2 `
  --shift Matutino `
  [--cct 27DPR0000X] [--organization complete] [--state Tabasco] `
  [--municipality Centro] [--locality Villahermosa] [--apply]
```

### `school-update --school <id> --school-name <v>`

Actualiza nombre/CCT/ubicación. Opciones: `--cct`, `--state`, `--municipality`, `--locality`.

### `school-delete --school <id>`

Elimina la escuela con su grupo, matrículas, asistencias, proyectos, actividades y evaluaciones. Con `--apply` requiere además `--confirm-delete`. Irreversible.

### `group-create --school <id> --school-year-id <id> --group-name <v> --grades 1..6`

Crea un grupo (asignación) en la escuela y ciclo indicados. Permite varios grupos por ciclo; los contratos no pueden solaparse. Opciones: `--shift` (catálogo SEP: `Matutino`, `Vespertino`, `Nocturno`, `Discontinuo`, `Continuo`).

### `group-update --group <id> --group-name <v> --grades 1..6`

Actualiza nombre/grados/turno del grupo preservando su horario y fechas de contratación.

### `group-delete --group <id>`

Elimina el grupo con sus datos. Con `--apply` requiere `--confirm-delete`.

### `student-create --group <id> --given-names <v> --first-surname <v> --grade 1..6 --list-number <n>`

Crea alumno con matrícula. Opciones: `--second-surname`, `--sex male|female`, `--birth-date YYYY-MM-DD`. La identidad del alumno creado sólo aparece en la salida con `--include-personal-data`.

### `student-update --student <id> --given-names <v> --first-surname <v>`

Actualiza datos del alumno (opciones de identidad como `student-create`).

### `project-create --group <id> --title <v> --grades 1..6`

Opción: `--methodology` (`unspecified`, `communityProjects`, `inquirySteam`, `problemBasedLearning`).

### `project-update --project <id> --title <v> --grades 1..6`

Actualiza título/metodología/grados. `project-delete` **no existe**; se requiere primero un caso de uso de dominio con eliminación transaccional segura.

### `activity-create --project <id> --title <v> --formative-field <v> --grades 1..6 --date YYYY-MM-DD`

Crea actividad con roster congelado de alumnos activos. `--formative-field` según el catálogo del dominio.

### `activity-delete --activity <id>`

Elimina la actividad con sus evaluaciones y roster. Con `--apply` requiere `--confirm-delete`.

### `student-note --student <id> --kind <v> --text <v> | --text-stdin`

Agrega una entrada de seguimiento. `--kind` según catálogo (`observation`, `familyAgreement`, …). El texto nunca se repite en la salida (sólo longitud). Fecha opcional con `--date`.

### `attendance-set --group <id> --student <id> --date YYYY-MM-DD --status present|absent|late|justified-absence`

Marca asistencia de un alumno. Devuelve estado anterior/nuevo y `dry_run`/`applied`.

### `student-deactivate --group <id> --student <id> [--date YYYY-MM-DD]`

Baja del alumno en el grupo (cierra su matrícula con fecha).

### `student-reactivate --group <id> --student <id> --grade 1..6 --list-number <n> [--date YYYY-MM-DD]`

Reinscribe al alumno con nueva matrícula (respeta la política de solapamiento y números de lista).

## Privacidad

- Ningún comando expone nombres, IDs de alumno, fechas de nacimiento, número de lista, fortalezas, dificultades, apoyos, acuerdos o contenido de notas sin `--include-personal-data`.
- `--include-personal-data` amplía sólo la proyección local: **no** constituye autorización para copiarla a una IA o servicio remoto.
- El texto de `student-note` nunca se hace eco en JSON y debe enviarse por `--text-stdin` cuando sea sensible.
- Los logs locales (`aularaiz.log`) registran códigos seguros (`unsupportedFile`, `data-state`, …) sin datos personales, CCT ni notas.

## Limitaciones conocidas

- **Sin PDF ni respaldos desde el CLI:** `PdfReportRenderer` y `DeviceBackupProtector` dependen de Flutter (`dart:ui`) y no se pueden importar en un ejecutable Dart puro. Si se requiere, implementar un renderizador/respaldo puro o un coordinador Flutter separado, conservando PDF Unicode y respaldo cifrado.
- **Sin `project-delete`:** el dominio no expone una eliminación segura de proyectos con sus relaciones hijas. No se inventa en el CLI hasta que exista un caso de uso transaccional.
- **`.xls` binario no soportado** en importación (usar `.xlsx`, `.xlsm` o `.csv`).

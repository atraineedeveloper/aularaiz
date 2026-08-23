# Phase 9 — Automatización local segura

La Fase 9 añade una interfaz de automatización local para AulaRaíz sin convertir SQLite en una API pública ni permitir que un agente salte las reglas del dominio.

## Principios

- **Local primero:** el agente no realiza llamadas de red. Lee y, cuando se autoriza, escribe únicamente en la base local de AulaRaíz.
- **Mismos límites que la UI:** las consultas se construyen con repositorios y proyecciones de aplicación; las mutaciones pasan por casos de uso existentes.
- **Datos minimizados por defecto:** ningún comando de grupo devuelve nombres o identificadores de alumnos salvo que se use `--include-personal-data`.
- **Mutaciones en dry-run:** `student-note` sólo previsualiza la operación mientras no se indique `--apply`.
- **Sin eco de texto sensible:** el contenido de una observación o acuerdo familiar nunca se reproduce en la salida JSON; sólo se informa su longitud.
- **Entrada sensible por stdin:** `--text-stdin` evita colocar observaciones/acuerdos en la línea de comandos o en el historial del shell.
- **Recomendaciones con evidencia:** cada sugerencia contiene una métrica y un umbral observable. Son señales para revisión docente, no diagnósticos ni decisiones automáticas.
- **Sin SQL en comandos:** `bin/aularaiz_agent.dart` no conoce tablas ni sentencias SQL. La composición abre la base y entrega repositorios/casos de uso al servicio de automatización.
- **Sin autorización implícita para IA remota:** poder obtener una proyección local no autoriza enviarla a ChatGPT, otra IA, telemetría o un servicio cloud. Cualquier integración remota requiere un diseño y consentimiento separados.

## Contrato de salida

Todos los comandos producen JSON con el esquema estable:

```json
{
  "schema": "aularaiz.automation/v1",
  "kind": "...",
  "generated_at": "...",
  "privacy": {
    "personal_data_included": false,
    "mode": "minimized"
  },
  "data": {}
}
```

Los errores también son JSON y no incluyen stack traces, rutas internas ni el contenido de notas.

## Comandos

### Estado y capacidades

```powershell
.\tool\aularaiz-agent.ps1 status --pretty
```

`status` informa si existe una configuración escolar activa, el ciclo escolar, el número de grupos y las capacidades disponibles. Si no se encuentra la base, sigue devolviendo un resultado de estado válido con `database.exists = false`.

### Listar grupos

```powershell
.\tool\aularaiz-agent.ps1 groups --pretty
```

Devuelve metadatos del grupo y grados, nunca alumnos.

### Resumen mensual

```powershell
.\tool\aularaiz-agent.ps1 group-summary --group group-id --month 2026-09 --pretty
```

Por defecto sólo devuelve conteos agregados de asistencia y evaluación. Para una automatización que realmente necesite identificar alumnos:

```powershell
.\tool\aularaiz-agent.ps1 group-summary --group group-id --month 2026-09 --include-personal-data --pretty
```

### Recomendaciones basadas en evidencia

```powershell
.\tool\aularaiz-agent.ps1 recommend --group group-id --month 2026-09 --pretty
```

Las reglas iniciales señalan únicamente patrones verificables:

- dos o más faltas en el mes;
- dos o más retardos;
- evaluaciones marcadas como `requiresSupport`;
- actividades no entregadas;
- dos o más evaluaciones pendientes.

La salida agregada informa cuántos alumnos activan cada señal. Los nombres/IDs de los alumnos afectados sólo aparecen con `--include-personal-data`.

### Agregar una observación o acuerdo familiar

Dry-run por defecto. Para texto sensible se recomienda stdin, de modo que el contenido no forme parte del historial de comandos:

```powershell
$note = Read-Host "Texto de la observación"
$note | .\tool\aularaiz-agent.ps1 student-note `
  --student student-id `
  --kind observation `
  --text-stdin `
  --date 2026-09-05 `
  --pretty
```

Para escribir realmente se añade `--apply`:

```powershell
$note = Read-Host "Texto de la observación"
$note | .\tool\aularaiz-agent.ps1 student-note `
  --student student-id `
  --kind observation `
  --text-stdin `
  --date 2026-09-05 `
  --apply
```

También se admite `--text "..."` para automatizaciones controladas, pero puede quedar visible en el historial del shell o en información del proceso y no es la opción recomendada para contenido P3.

Tipos admitidos: `observation` y `family-agreement`.

El servicio valida primero que el alumno exista y después, sólo con `--apply`, ejecuta `AddStudentRecordEntry`. No se expone una mutación genérica de SQL.

## Descubrimiento de la base

En Windows, el agente intenta localizar la base de producción dentro del directorio de datos de la aplicación para `MindTzijib/AulaRaíz`. Puede forzarse una ruta concreta:

```powershell
.\tool\aularaiz-agent.ps1 status --database "C:\ruta\aularaiz-production.sqlite"
```

También existe `--profile demo`. En plataformas donde no existe descubrimiento automático debe usarse `--database`.

El ejecutable de producción `aularaiz-agent.exe` se compila como binario independiente y se incluye en el instalador de Windows. No requiere que el usuario instale Dart.

## Revisión de privacidad por proyección

| Proyección | Datos por defecto | Opt-in de datos personales | Escritura |
| --- | --- | --- | --- |
| `status` | estado de configuración, ciclo, conteo de grupos, capacidades | No aplica | No |
| `groups` | ID/nombre de grupo, grados, turno | No aplica; no contiene alumnos | No |
| `group-summary` | conteos agregados de asistencia/evaluación | `--include-personal-data` añade ID, nombre, lista, grado y métricas por alumno | No |
| `recommend` | códigos de señal, métricas, umbrales y número de afectados | `--include-personal-data` añade los alumnos asociados a cada evidencia | No |
| `student-note` | tipo, fecha, longitud del texto y estado dry-run/aplicado | `--include-personal-data` añade identidad del alumno; el texto nunca se devuelve | Sí, sólo con `--apply` |

Ninguna proyección expone fecha de nacimiento, CCT, localidad, fortalezas, dificultades, apoyos, observaciones previas o acuerdos familiares existentes.

La salida del agente sigue siendo información escolar local. `--include-personal-data` sólo amplía la proyección local; no constituye permiso para copiarla a una IA o servicio remoto.

## Integración y pruebas

CI verifica:

- formato incluyendo `bin/`;
- análisis estático y suite completa;
- contrato JSON de `--help`;
- compilación del agente como ejecutable Dart independiente;
- compilación de `aularaiz-agent.exe` en Windows antes de validar el instalador.

La pipeline de release firma `aularaiz.exe`, `aularaiz-agent.exe` y el instalador final con el mismo certificado de producción.

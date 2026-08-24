# Automatización: mutaciones seguras ampliadas

AulaRaíz 0.1.6 amplía el agente local con tres operaciones de escritura controlada:

- `attendance-set` para registrar o corregir el estado de asistencia de un alumno en una fecha;
- `student-deactivate` para cerrar una matrícula activa conservando todo el historial;
- `student-reactivate` para crear una nueva matrícula después de una baja previa.

Todas son **dry-run por defecto**. La validación se ejecuta a través de casos de uso de la capa de aplicación y sólo `--apply` persiste cambios. La salida mantiene datos personales minimizados salvo opt-in explícito con `--include-personal-data`.

La desactivación usada por la interfaz también comparte el nuevo caso de uso, y la reactivación reutiliza `EnrollStudent` y su política de matrícula. Las pruebas cubren preview/apply y un recorrido real contra SQLite Demo.

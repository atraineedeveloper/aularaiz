# Complete group export

AulaRaíz 0.1.3 expands the teacher-facing group export so it no longer behaves as a student-summary-only file.

## Excel workbook

The complete `.xlsx` export contains these worksheets by default:

- `Contexto`
- `Alumnos`
- `Asistencia`
- `Proyectos`
- `Actividades`
- `Evaluacion`

When the teacher explicitly enables sensitive follow-up content, the workbook also includes `Seguimiento` and the sensitive observation fields that belong to the corresponding datasets.

## CSV

CSV exports exactly one selected dataset per file. The Reports screen asks which dataset to export before the save/share flow begins. CSV uses UTF-8 with BOM, comma delimiters, ISO dates and neutralizes formula-leading user text such as `=`, `+`, `-` and `@`.

## Historical semantics

Attendance is exported as one row per stored student/date entry and resolves the enrollment that was active on that date. No attendance rows are fabricated for students absent from the historical roster.

Evaluation is exported from each activity's frozen roster. Applicable students without a saved evaluation remain visible as pending rather than disappearing from the export.

## Privacy

Student pedagogical summaries, evaluation observations and chronological follow-up are excluded by default. They are added only after the existing sensitive-content opt-in is enabled.

## Current model boundary

Project and activity sheets export all fields currently maintained by AulaRaíz. Richer project/activity description, date range and observation fields are a separate parity follow-up; once those fields exist in the domain model they can be added to these sheets without changing the normalized export design.

XLSX/CSV exports are for review, analysis and controlled sharing. They are not backup/restore packages.

# Literacy assessment records

AulaRaiz now stores manual literacy assessment results for each student. The app does not apply tests, calculate levels, or show prompts; it only records the final result from an assessment performed outside the app.

## Model

The new `literacy_assessments` table keeps a historical record per student with:

- assessment date;
- writing level: Presilabico, Silabico, Silabico-alfabetico, Alfabetico;
- reading level: No lee, Silabico, Palabrico, Oracional, Fluido;
- optional notes.

The records are structured domain data, not `StudentRecordEntry` text, so future reports and filters can query them directly.

## UI

Student records now include a `Lectoescritura` section. Teachers can record a level quickly, view the latest result, open the full history, edit a mistaken capture, or delete only the selected literacy assessment after confirmation.

## Migration

Drift schema version 9 creates `literacy_assessments` for existing installations without recreating user data. Backup and restore include the table naturally because snapshots copy the SQLite database.

## Tests

Coverage was added for the domain entity, application use cases, Drift repository behavior, v8 to v9 migration, and current schema baseline.

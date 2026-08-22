# Phase 2 — SQLite schema v1

Schema v1 is the relational persistence baseline for the complete Phase 2 domain. Drift declarations live under `lib/data/local/schema/`, and the serialized baseline is retained under `drift_schemas/app_database/`.

## Tables

### `schools`

Local school identity, name, optional CCT, organization and optional geographic context. CCT is unique when present.

### `school_years`

School-year label and inclusive start/end dates. SQLite rejects an end date before the start date.

### `teaching_groups`

A group belongs to one school and one school year. Optional schedule boundaries must either both be null or form a valid minute-of-day interval with `0 <= start < end < 1440`.

### `group_grades`

Maps a teaching group to one or more primary grades. `(group_id, grade)` is the primary key and is referenced by historical enrollments.

### `students`

Minimum classroom identity: given names, first surname, optional second surname and optional birth date. Birth date is P2 personal data and is used as the source for derived age. CURP, address, family contacts and medical data are not part of schema v1.

### `enrollments`

Historical student membership in a group, including grade, list number and inclusive start/end dates. SQLite enforces:

- positive list number;
- end date null or not earlier than start date;
- `(group_id, grade)` must exist in `group_grades`.

Overlap and date-within-school-year rules remain application/domain policies because they depend on interval and parent-record state.

### `attendance_days`

One atomic attendance record per group/date. `(group_id, date)` is unique.

### `attendance_entries`

One status per student inside an attendance day. `(attendance_day_id, student_id)` is the primary key.

### `projects`

Project ownership, title, lifecycle, methodology and formative field.

### `project_grades`

Explicit grade scope for a project. `(project_id, grade)` is the primary key.

### `activities`

Activities belong to projects and store their classroom-facing title.

### `activity_grades`

Explicit grade scope for an activity. `(activity_id, grade)` is the primary key.

### `activity_roster`

Historical student applicability for an activity. `(activity_id, student_id)` is the primary key. A composite foreign key requires `(activity_id, grade)` to exist in `activity_grades`, preventing a historical roster row outside the activity's grade scope.

Activity deletion is restricted once historical roster rows depend on it.

### `activity_evaluations`

Delivery/evaluation state per historical activity participant. `(activity_id, student_id)` is the primary key and must exist in `activity_roster`.

SQLite also enforces that achievement is null unless `delivery_status = 'delivered'`. This mirrors the domain rule that non-delivery is not a low achievement result.

### `student_records`

Longitudinal summary fields for strengths, difficulties and supports, keyed by student.

### `student_record_entries`

Chronological observations and family/tutor agreements with stable IDs and occurrence dates.

## Referential and deletion behavior

Historical classroom evidence is protected from accidental parent deletion. Core relationships use restrictive foreign keys when deleting the parent could erase or invalidate history. Cascades are reserved for true owned configuration rows where their lifetime is inseparable from the parent and no historical dependent row remains.

Foreign keys are enabled with `PRAGMA foreign_keys = ON` before normal use.

## Storage profiles

Production and Demo are separate storage profiles with separate database names:

- `aularaiz-production`;
- `aularaiz-demo`.

`DemoDataSeeder` also checks the declared storage profile before any reset, so Demo reset cannot be used against a Production-profile database.

`openAulaRaizConnection()` uses `drift_flutter` and the application support directory. Classroom data therefore remains in app-controlled storage on Windows and Android instead of ordinary document folders.

## Schema snapshot and migrations

`build.yaml` registers `AppDatabase` with `drift_dev`. The committed `drift_schema_v1.json` is the authoritative serialized baseline for this release line.

CI runs:

```text
dart run drift_dev make-migrations
```

and rejects uncommitted differences in Drift migration artifacts. This prevents a schema declaration from silently changing while `schemaVersion` remains unchanged.

Because v1 has no predecessor, there is no v0→v1 migration. Runtime tests validate the fresh schema and foreign-key configuration. When v2 is introduced, the schema version must be incremented and Drift's generated v1→v2 migration helper/tests must be committed and adapted for data-integrity scenarios.

# Phase 2 — Data and domain foundation

**Status:** complete, pending final CI and merge

## Goal

Build the durable non-UI heart of AulaRaíz before feature screens depend on it. Domain rules remain independent from Flutter widgets and from the concrete SQLite implementation.

## Domain delivered

Phase 2 now covers:

- Mexican primary grades 1–6 and derived NEM phases;
- school years and school context;
- teaching groups, including multigrade grade membership and optional class schedules;
- students with stable IDs, minimized identity data and optional birth date for derived age;
- historical enrollments with grade, list number and inclusive start/end dates;
- daily attendance and the four required attendance states;
- projects, target grades, methodology, formative field and lifecycle;
- activities with explicit grade scope and frozen historical participant roster;
- formative evaluation with separate delivery and achievement semantics;
- longitudinal student records with strengths, difficulties, supports, observations and family/tutor agreements.

## Core decisions

### NEM grade/phase mapping

- Grades 1–2 → Phase 3.
- Grades 3–4 → Phase 4.
- Grades 5–6 → Phase 5.

Phase is derived from grade instead of being stored as independently editable truth.

### Multigrade groups

A teaching group owns a non-empty set of primary grades. One grade is unigrade; two or more grades are multigrade. A group may span more than one NEM phase.

Each enrollment records the student's grade during that historical membership, which keeps grade/phase interpretation stable in multigrade classrooms.

### Historical membership

Students do not have a mutable `currentGroupId`. Membership is represented by `Enrollment` periods. Policy validation rejects grades not offered by the group, dates outside the school year, overlapping memberships for the same student and overlapping list-number assignments inside a group.

SQLite additionally enforces positive list numbers, chronological enrollment dates and membership grades that belong to the group's configured grade set.

### Attendance history

Attendance is stored as a daily group record plus student entries. The monthly matrix will be a projection in Phase 4 rather than a separate source of truth.

### Project and activity history

Projects and activities carry explicit grade scope. `activity_roster` freezes the participants applicable when the activity is created. Persistence prevents a roster row from using a grade outside the activity scope.

### Evaluation semantics

Delivery and achievement remain separate. Achievement may exist only for delivered work. An evaluation row must reference an existing historical activity-roster row, so persistence cannot create evidence for a student who was not applicable to that activity.

### Expediente

Student follow-up is longitudinal and pedagogical. The model stores structured summary fields plus chronological observations and family/tutor agreements without introducing clinical diagnoses, sanctions or ranking semantics.

## Privacy baseline

The core student identity stores:

- given names;
- first surname;
- optional second surname;
- optional birth date.

Birth date is P2 personal data and is optional. When present, it is the source used to derive age; age is not stored as an independently editable value. CURP, address, family contacts, medical data and other unnecessary identifiers are not part of the core model.

Attendance, evaluation and free-form student-record content are P3 classroom data and remain local by default.

All committed fixtures and Demo records are fictitious.

## Persistence delivered

Drift/SQLite schema v1 contains the complete Phase 2 model. Foreign keys are enabled before normal use. Domain entities do not depend on Drift row classes, and application contracts are implemented by explicit Drift repository adapters.

The first real persistence flow is covered automatically:

`EnrollStudent use case → repository contracts → Drift adapters → SQLite → domain read-back`.

Production and Demo use separate database names. `DemoDataSeeder` also requires an explicit Demo storage profile before seeding or resetting, providing a logical safety barrier in addition to physical separation.

## Demo fixture

The deterministic Demo seed spans multiple modules:

- school/year and multigrade group;
- fictitious students and enrollments;
- attendance;
- project and activity;
- historical roster;
- delivered/evaluated and non-delivered examples;
- student-record summary and chronological entries.

`resetAndSeed()` restores the same IDs and refuses to run against a Production-profile database.

## Schema and migration policy

`drift_schemas/app_database/drift_schema_v1.json` is the frozen schema-v1 baseline.

Every future schema change must:

1. increment `AppDatabase.schemaVersion`;
2. run `dart run drift_dev make-migrations`;
3. implement the generated step-by-step migration;
4. adapt the generated migration/data-integrity tests;
5. commit all migration artifacts.

CI runs `make-migrations` and fails if generated migration artifacts differ from the repository. Because v1 has no previous version to migrate from, its baseline consists of the frozen schema plus runtime schema/integrity tests. The first v1→v2 change will generate the transition helper and migration test scaffold.

## Phase 2 exit evidence

Phase 2 is accepted when the final branch passes:

- Drift code generation;
- migration-artifact verification;
- Dart formatting;
- `flutter analyze`;
- all unit/data tests;
- Windows release build;
- Android debug build.

After merge, Phase 3 may build school setup, group workspace and student-roster UI on this foundation without redefining these persistence rules.

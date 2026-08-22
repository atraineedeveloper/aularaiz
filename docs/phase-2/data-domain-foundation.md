# Phase 2 — Data and domain foundation

**Status:** in progress

## Goal

Build the first durable classroom data model before adding feature UI. The domain must remain independent from Flutter widgets and from the concrete SQLite implementation.

## First domain slice

The initial slice models:

- Mexican primary grades 1–6 and their NEM phases;
- school years;
- schools;
- teaching groups, including multigrade groups;
- students with data minimization by default;
- historical group enrollments, including the grade a student attends inside the group.

Attendance, projects, evaluation and student records will be added only after this base is stable.

## Domain decisions

### NEM grade/phase mapping

- Grades 1–2 → Phase 3.
- Grades 3–4 → Phase 4.
- Grades 5–6 → Phase 5.

This mapping is represented as domain code instead of UI text so it can be reused by validation, reports and persistence.

### Multigrade groups

A group owns a non-empty set of primary grades. A group is multigrade when that set contains more than one grade. The model does not force all grades in a group to belong to the same NEM phase.

Each enrollment records the student's grade within that group. This is required to resolve the student's NEM phase correctly in a multigrade classroom.

### Historical rosters

A student is not modeled with a mutable `currentGroupId`. Membership is represented by an `Enrollment` with start/end dates and the grade attended during that membership. This preserves historical rosters for attendance, evaluation and reporting.

Enrollment policy rejects a grade that the group does not offer, dates outside the school year and overlapping memberships for the same student. Inclusive boundary dates are treated as overlapping, so a transfer must close on the day before the new membership starts.

### Privacy baseline

The initial `Student` entity stores only the minimum identity needed for classroom workflows:

- given names;
- first surname;
- optional second surname.

CURP, birth date, address, family contacts, medical data and other sensitive fields are intentionally absent from the base entity. They may be introduced later only when a concrete requirement and retention/privacy rule justify them.

## Persistence plan

Drift remains the persistence choice. Schema v1 mirrors these entities and stores the enrollment grade explicitly. The next persistence slice will introduce the generated database class, foreign-key activation, schema snapshots and repositories after the declarations are stable.

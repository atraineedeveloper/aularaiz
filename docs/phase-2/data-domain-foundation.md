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
- historical group enrollments.

Attendance, projects, evaluation and student records will be added only after this base is stable.

## Domain decisions

### NEM grade/phase mapping

- Grades 1–2 → Phase 3.
- Grades 3–4 → Phase 4.
- Grades 5–6 → Phase 5.

This mapping is represented as domain code instead of UI text so it can be reused by validation, reports and persistence.

### Multigrade groups

A group owns a non-empty set of primary grades. A group is multigrade when that set contains more than one grade. The model does not force all grades in a group to belong to the same NEM phase.

### Historical rosters

A student is not modeled with a mutable `currentGroupId`. Membership is represented by an `Enrollment` with start/end dates. This preserves historical rosters for attendance, evaluation and reporting.

Overlap prevention and cross-entity integrity belong in the repository/use-case layer and will be covered when persistence is introduced.

### Privacy baseline

The initial `Student` entity stores only the minimum identity needed for classroom workflows:

- given names;
- first surname;
- optional second surname.

CURP, birth date, address, family contacts, medical data and other sensitive fields are intentionally absent from the base entity. They may be introduced later only when a concrete requirement and retention/privacy rule justify them.

## Persistence plan

Drift remains the persistence choice. The next slice will add the SQLite boundary and schema v1 for these entities, with foreign keys enabled and migration tests. Drift's generated database code will not be introduced until the schema and code-generation workflow are validated.

## Definition of done for this slice

- domain entities compile without Flutter UI dependencies;
- invalid date ranges and empty required values are rejected;
- NEM grade/phase mapping has unit tests;
- multigrade behavior has unit tests;
- enrollment history semantics have unit tests;
- CI remains green.

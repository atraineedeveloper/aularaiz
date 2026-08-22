# Phase 2 — SQLite schema v1

This document describes the first relational persistence shape for the core school structure. Drift table declarations live under `lib/data/local/schema/`.

## Tables

### `school_years`

Stores the cycle identifier, display label and inclusive start/end dates.

### `schools`

Stores the local school identity, name and optional CCT. CCT is not required so the app remains usable while initial setup is incomplete.

### `teaching_groups`

A group belongs to exactly one school and one school year. Grades are intentionally not stored directly on this table because multigrade groups require a one-to-many relation.

### `group_grades`

Maps a teaching group to one or more primary grades. The pair `(group_id, grade)` is the primary key.

### `students`

Stores only the minimum classroom identity defined by the domain model. No CURP, address, birth date or family/medical data is introduced in schema v1.

### `enrollments`

Represents historical membership of a student in a group using inclusive start/end dates. This prevents a mutable `current_group_id` from destroying roster history.

## Delete behavior

Historical educational data should not disappear because a parent entity is removed accidentally. Foreign keys from groups and enrollments therefore use restrictive deletion. `group_grades` may cascade with its group because it is configuration owned exclusively by that group.

The product layer will prefer archive/deactivation over destructive deletes.

## SQLite location

`openAulaRaizConnection()` uses `drift_flutter` and the application support directory. This keeps the database in app-owned storage on Windows and Android instead of user-facing document folders.

## Next persistence slice

1. Introduce the generated `AppDatabase` class and schema version 1.
2. Enable `PRAGMA foreign_keys = ON` before normal use.
3. Generate and retain Drift schema snapshots.
4. Add migration/integrity tests.
5. Implement repositories mapping database rows to the pure domain entities.

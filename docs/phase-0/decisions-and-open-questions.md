# Phase 0 Decisions and Open Questions

This file separates decisions already justified by the product baseline from choices that should not be silently locked in.

## Accepted baseline decisions

### Clean-room rewrite

AulaRaíz does not migrate WPF/.NET source code. The old application is used as a functional/domain reference only.

### Offline-first core

Core classroom work remains available without Internet access.

### Initial platforms

Windows and Android are the first-class targets. Other Flutter targets remain possible but do not constrain the first implementation.

### Local relational persistence

SQLite remains the required local relational store unless Phase 1 discovers a concrete blocker. The Dart package/ORM remains a Phase 1 technical choice.

### No mandatory account or cloud sync

The first parity release works locally without account creation. Automatic cloud synchronization is deferred.

### Adaptive UI

Desktop and mobile use the same domain/application rules but may use different screen structures and interaction patterns.

### History is preserved

Attendance rosters, activity applicability and existing evidence are not silently recomputed from later student/group configuration.

### New database and backup format allowed

The rewrite is not constrained by the historical SQLite schema or `.sdocbackup` format.

### One-way migration preferred over permanent legacy compatibility

If users need to bring real data from the WPF app, design a controlled one-way migration/import process rather than embedding old-schema assumptions throughout the new domain.

### CURP excluded initially

CURP is not a core field unless a verified institutional workflow requires it.

### Piaget derived reference removed from parity scope

The prior general Piaget-stage reference does not justify complexity in the new baseline. It can be reconsidered only for a concrete teacher need.

## Product-owner decisions still open

These are not blockers for documenting Phase 0, but they should be resolved before the relevant implementation phase.

### 1. Product/package identity

Need to pin:

- Android application ID;
- Windows package identity;
- publisher/copyright string;
- whether technical identifiers should use `aularaiz`, `AulaRaiz`, or an organization namespace.

Recommended direction: choose a stable organization namespace once and never make user data paths depend on UI branding text.

### 2. License

The previous application used `GPL-3.0-only`. The new repository is public, but the new project should explicitly confirm whether it keeps GPL-3.0-only or uses another open-source license before third-party dependency review and public release.

### 3. Cross-device workflow before sync

Without cloud sync, Windows and Android each have local data. Need to decide whether the first public release should support:

- manual backup transfer between devices;
- a dedicated device-to-device export/import;
- or simply independent installations until encrypted sync exists.

Recommendation: do not invent sync during the core rewrite. Keep stable IDs and versioned schemas, then design sync separately.

### 4. Old-app data migration

Need to decide whether any real WPF installations must be supported.

If yes, Phase 6 or 8 should add a one-way importer for a known old database/backup version. If no, the new schema starts without legacy compatibility code.

### 5. Android scope

Need to decide whether Android 1.0 is intended primarily for:

- full feature parity;
- classroom capture/consultation while Windows remains best for heavy reporting/import;
- or both.

Current roadmap assumes the domain is shared but allows platform-specific UX and selected desktop-only operational conveniences.

### 6. CLI/agent release timing

The previous application had a local agent/terminal interface. The rewrite keeps it as a target but schedules it after the core domain is stable.

Need to decide whether it must be included in the public 1.0 release or may land in 1.x.

### 7. Richer NEM planning timing

The old roadmap planned purpose, expected product, curriculum content, PDA and articulating axes.

Need to decide whether these should remain post-parity or whether the new rewrite is the right moment to include them before 1.0.

Recommendation: recover the proven project/activity workflow first, then extend planning from a stable domain rather than making Phase 2 too broad.

## Phase 1 decisions intentionally deferred

Do not lock these during Phase 0 without implementation evidence:

- state-management package;
- routing package;
- dependency-injection package;
- SQLite ORM/query package;
- PDF package;
- XLSX package;
- backup crypto/container libraries;
- updater/installer tooling;
- exact folder-by-feature/package structure;
- exact Android minimum SDK and desktop architectures beyond Flutter-supported baselines.

Phase 1 should compare candidates against the product invariants, supported platforms, maintenance health, license compatibility and testability.

## Completion rule

An open question becomes a decision only when recorded here (or superseded by an ADR/spec) with the reason and consequences. Implementation convenience alone must not silently decide product scope.

# AulaRaíz — Product Specification

**Status:** Phase 0 baseline  
**Product:** AulaRaíz  
**Implementation:** clean-room Flutter rewrite  
**Reference product:** `atraineedeveloper/SistemaDocenteNEM`

## 1. Product intent

AulaRaíz is an offline-first classroom-management application for Mexican public-primary-school teachers working within the Nueva Escuela Mexicana (NEM) framework.

The new product is not a source-code migration from WPF/.NET. The previous application is a behavioral reference: it tells us which teacher problems were already solved, which domain rules proved important, and which workflows need to be improved. The Flutter implementation is free to use a new architecture, new persistence schema, new UI and new platform-specific integrations.

## 2. Primary users

The first-class user is a primary-school teacher who may work in:

- a regular unigrade classroom;
- a multigrade classroom;
- a school with limited or unreliable connectivity;
- a Windows computer, an Android device, or both.

AulaRaíz must favor teacher workflow speed, clarity and safety over administrative-form imitation or unnecessary visual complexity.

## 3. Product principles

### 3.1 Offline first

Core classroom work must remain usable without Internet access. Creating or editing groups, students, attendance, projects, activities, evaluation evidence, student records and reports must not require a network connection.

Network-dependent capabilities must be optional and clearly separated from classroom data.

### 3.2 Teacher workflow first

The application models teacher tasks rather than exposing database concepts. Common workflows should minimize repetitive navigation and unnecessary confirmation steps while protecting destructive or sensitive actions.

### 3.3 NEM-aware, not NEM-rigid

Stable official concepts should be structured when they create useful consistency: primary grade, learning phase, formative field, project methodology, articulating axes and other catalog-like values.

Teacher-authored planning, evidence and contextual interpretation must remain flexible. AulaRaíz must not invent pedagogical intent or silently infer ambiguous educational data.

### 3.4 Historical integrity

Past classroom evidence must not be silently rewritten because a current configuration changed.

Examples:

- changing a student's current grade must not change the student's applicability to an activity that already happened;
- activating or deactivating a student must not retroactively change historical attendance rosters;
- changing group configuration must not reinterpret old evaluation data;
- calendar/configuration changes must not rewrite attendance history automatically.

### 3.5 Privacy by design

Student, family and school data must be minimized, stored locally by default and excluded from technical logs. Sensitive exports, reports, backups and future AI/agent boundaries must be explicit.

### 3.6 Adaptive, not merely responsive

Windows and Android share product concepts and business rules, but they do not need identical layouts.

Desktop may use high-density matrices, keyboard shortcuts, split views and side navigation. Mobile should use touch-friendly flows, smaller working sets and navigation appropriate to a phone or tablet.

### 3.7 Testable domain rules

Rules that determine historical applicability, grade compatibility, attendance state, evaluation semantics, import validation, backup integrity or privacy behavior must not live only inside Flutter widgets.

## 4. Platform scope

### First-class targets for the initial product line

- **Windows 10/11 desktop**.
- **Android**.

Flutter currently supports Windows 10/11 and Android API 24+ as deployment targets. Exact minimum versions and architecture support will be pinned in Phase 1 after toolchain validation.

### Deferred targets

- macOS;
- Linux;
- iOS;
- Web.

The architecture should avoid unnecessary platform lock-in, but deferred platforms are not Phase 1–8 release blockers. Web in particular must not dictate the local file-system, recovery and privacy model of the desktop/mobile product.

## 5. Data and connectivity model

### 5.1 Local source of truth

A local relational database remains the source of truth for classroom data. SQLite is the required storage technology unless Phase 1 uncovers a concrete blocker.

The Flutter package/ORM used to access SQLite is an implementation decision for Phase 1.

### 5.2 No mandatory account

The initial product must not require teacher sign-in or a cloud account to use core classroom features.

### 5.3 Cross-device synchronization

Automatic cloud synchronization is **not part of the initial parity release**. Windows and Android must each remain fully usable offline.

The data model should use stable identifiers and versioned migrations so that a later opt-in encrypted synchronization layer remains possible without redesigning the domain.

Manual backup/restore or controlled transfer can be used before cloud sync exists.

## 6. NEM baseline

For primary education, the product baseline follows the current Plan de Estudio 2022 structure used by SEP:

- 1st–2nd primary → Phase 3;
- 3rd–4th primary → Phase 4;
- 5th–6th primary → Phase 5.

The four formative fields are:

- Lenguajes;
- Saberes y Pensamiento Científico;
- Ética, Naturaleza y Sociedades;
- De lo Humano y lo Comunitario.

The richer planning model should be able to add the seven articulating axes without forcing them into every workflow prematurely.

Official-source validation is a continuing product requirement: NEM catalogs and rules must not be treated as permanently frozen application constants when the official framework can change.

## 7. Core product areas

The clean-room rewrite will eventually provide:

1. teacher/school/classroom context;
2. groups and students;
3. attendance;
4. projects and activities;
5. formative evaluation;
6. longitudinal student record (`Expediente`);
7. reports and PDF output;
8. safe XLSX/CSV import and export;
9. Demo mode with isolated fictitious data;
10. local backup and restore;
11. settings, themes and accessibility;
12. Windows and Android distribution/update behavior;
13. privacy-safe diagnostics;
14. a controlled local automation/agent surface after the core application is stable.

The detailed parity decisions are maintained in `functional-parity.md`.

## 8. Product behaviors that are not optional

### Attendance

Attendance must preserve distinct states for present, absent, late and justified absence. Daily save behavior must be atomic. The monthly view is a projection of daily records, not a single giant transaction.

### Evaluation

Delivery and achievement remain separate concepts internally. The product must represent at least:

- pending work;
- delivered but not yet evaluated;
- not delivered;
- evaluated achievement levels.

A UI may present these concepts compactly, but it must not collapse them into an ambiguous single score in the domain.

### Historical applicability

Activities own a historical roster/scope. Later student activation, deactivation, grade changes or group configuration changes must not retroactively rewrite which students were applicable to an existing activity.

### Import

Selecting/parsing an XLSX or CSV file must not write to the classroom database. Import requires preview, correction/review and an explicit confirmation boundary. The confirmed batch must be atomic.

### Export

Exports are teacher-controlled derived copies. Sensitive observations/follow-up must be excluded by default and require explicit inclusion.

### Recovery

Restore must validate the selected backup before touching live data and must create a safety recovery point before destructive publication where technically practical.

## 9. Intentional differences from the old application

### 9.1 New schema

The Flutter rewrite does not inherit the old SQLite schema, `PRAGMA user_version`, extension-table strategy, .NET namespaces or WPF compatibility constraints.

The new database starts with a coherent versioned schema designed for the new domain.

### 9.2 New backup format

The new product may define a new backup container/manifest. Backward compatibility with historical `.sdocbackup` packages is not an automatic requirement.

If real users need migration from the old application, the preferred design is a one-way migration/import tool rather than permanent internal compatibility layers.

### 9.3 New UI

No WPF screen is a pixel-level design requirement. Workflows and safety semantics are the reference; visual structure is redesigned for Flutter and multiple form factors.

### 9.4 Derived Piaget reference

The old product exposed a derived, explicitly non-diagnostic Piaget developmental reference. It is **not a required parity feature** for AulaRaíz 1.0. It should return only if a concrete teacher workflow and evidence justify it.

### 9.5 CURP

CURP remains excluded from the core student model unless a future verified institutional workflow requires it. Fields are not added merely because they appear on external lists.

## 10. Out of scope for initial parity

These may be valuable later but must not delay the first stable parity release:

- mandatory cloud accounts;
- automatic cloud synchronization;
- parent/student portals;
- AI-generated diagnoses or unsupported pedagogical conclusions;
- competitive student ranking;
- automatic sanctions or behavior labels;
- full school-administration/HR functionality;
- web parity;
- permanent compatibility with every historical WPF implementation detail.

## 11. Future expansion candidates

Once parity is stable, AulaRaíz can extend into capabilities that were only planned in the previous product:

- richer NEM planning: purpose, expected product, curriculum content, PDA and articulating axes;
- evaluation criteria and qualitative rubrics;
- reporting/evaluation periods;
- teacher journal/classroom log;
- family meeting and agreement workflows;
- objective school-incident/coexistence records;
- digital evidence attachments;
- school calendar and agenda;
- automatic backup policy and retention;
- optional local application lock;
- controlled deletion/anonymization;
- optional encrypted cross-device synchronization.

## 12. Phase 0 acceptance criteria

Phase 0 is complete when:

- the reference application's implemented features are classified;
- required domain invariants are documented independently from WPF;
- privacy/data-handling boundaries are documented;
- initial release scope and deferred capabilities are explicit;
- platform assumptions are explicit;
- unresolved product decisions are recorded rather than silently guessed;
- a phased delivery roadmap exists;
- no production Flutter architecture/package choice has been prematurely treated as irreversible.

## 13. Sources used for this baseline

- Previous repository: `atraineedeveloper/SistemaDocenteNEM`.
- Previous architecture, UI, planning, import/export, backup and privacy documentation.
- Secretaría de Educación Pública, Plataforma Digital de la Nueva Escuela Mexicana, primary Plan 2022 resources.
- Flutter official supported-platform and desktop documentation, checked during Phase 0 in August 2026.

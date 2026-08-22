# Delivery Roadmap

AulaRaíz is rebuilt incrementally. Each phase ends with testable, reviewable behavior and does not depend on unfinished UI from a later phase.

## Phase 0 — Product baseline

Deliverables:

- product specification;
- functional parity matrix;
- domain invariants;
- privacy baseline;
- platform/delivery assumptions;
- unresolved decisions recorded explicitly;
- this roadmap.

No production Flutter feature work begins before this baseline is accepted.

## Phase 1 — Flutter foundation

Goal: create a clean, testable application shell.

Scope:

- Flutter project generation;
- Windows and Android targets;
- package/application identity;
- folder/module architecture;
- dependency injection/composition approach;
- state-management decision;
- navigation/routing;
- design tokens and base themes;
- localization foundation (`es-MX` first);
- error/result model;
- privacy-safe logging foundation;
- linting/formatting;
- unit/widget/integration test structure;
- GitHub Actions quality gates.

Exit criteria:

- `flutter analyze` passes;
- unit/widget smoke tests pass;
- Windows release build succeeds;
- Android build succeeds;
- CI reproduces the checks.

## Phase 2 — Domain and persistence

Goal: implement the non-UI heart of AulaRaíz.

Scope:

- stable IDs;
- school year/context;
- group/student model;
- primary grades/phases;
- multigrade rules;
- attendance model;
- project/activity model;
- evaluation delivery/achievement semantics;
- expediente model;
- SQLite schema and migrations;
- repository interfaces/adapters;
- Production/Demo profile isolation;
- deterministic fictitious seed data.

Exit criteria:

- all Phase 0 domain invariants implemented and unit-tested where applicable;
- migration tests exist;
- Demo/Production isolation proven automatically.

## Phase 3 — School, groups and students

Goal: first genuinely usable teacher workflow.

Scope:

- first-run/basic school setup;
- group list/workspace;
- group context;
- student roster;
- add/edit/activate/deactivate;
- search/filter;
- unigrade/multigrade UX;
- unsaved-change protection;
- adaptive desktop/mobile navigation for these modules.

Milestone: **AulaRaíz Alpha**.

## Phase 4 — Daily classroom work

Goal: support frequent operational work.

Scope:

- daily attendance;
- desktop monthly attendance matrix;
- mobile attendance capture;
- attendance metrics;
- projects;
- activities;
- project lifecycle;
- NEM methodology/formative-field/grade scope;
- historical activity roster behavior.

Exit criteria include keyboard and touch workflow validation.

## Phase 5 — Evaluation and expediente

Goal: restore the pedagogical core.

Scope:

- student × activity evaluation workflow;
- delivery vs achievement states;
- observations;
- filters/metrics;
- mobile evaluation workflow;
- student expediente;
- strengths/difficulties/supports;
- chronological notes;
- tutor/family agreements;
- cross-links to attendance and evaluation evidence.

Exit criteria require explicit tests for historical applicability and non-delivery semantics.

## Phase 6 — Reports and interchange

Goal: move data safely into and out of AulaRaíz.

Scope:

- individual report;
- group report;
- PDF generation;
- XLSX/CSV student import;
- mapping/preview/correction/review;
- atomic import confirmation;
- XLSX/CSV group export;
- privacy-sensitive opt-ins;
- formula-safe CSV;
- safe file publication;
- Android sharing/export UX where appropriate.

Milestone: **AulaRaíz Beta**.

## Phase 7 — Product UX and accessibility hardening

Goal: make the product coherent and polished rather than merely functional.

Scope:

- complete responsive/adaptive review;
- desktop keyboard navigation and shortcuts;
- touch target review;
- Light/Dark/High Contrast validation;
- screen-reader semantics;
- focus management;
- text scaling;
- 30–40 student stress scenarios;
- loading/progress states;
- actionable error states;
- design consistency review across modules.

Design work begins in Phase 1; this phase is the cross-product hardening pass.

## Phase 8 — Recovery, distribution and lifecycle

Goal: make AulaRaíz safe to install, update, recover and distribute.

Scope:

- new versioned backup format;
- safe SQLite snapshot;
- checksums/integrity validation;
- optional protected backups;
- restore inspection;
- safety backup/rollback;
- Windows install package;
- separation of program and classroom files;
- GitHub release pipeline;
- Windows update discovery/install flow;
- Android App Bundle and Play release configuration;
- signing strategy;
- lifecycle tests for update/uninstall/data preservation.

Milestone: **AulaRaíz 1.0 parity release** after all required parity items are accepted.

## Phase 9 — Advanced local automation

Goal: restore and improve the local CLI/agent capability without making the database an unsafe automation API.

Scope:

- capability/status discovery;
- machine-readable projections;
- minimized output by default;
- explicit personal-data opt-ins;
- dry-run mutations;
- evidence-backed local recommendations;
- no direct domain SQL from command handlers;
- privacy review of every projection.

This may ship before or after the public 1.0 depending on value versus release risk, but it does not block the core teacher UI from reaching Beta.

## Post-parity expansion tracks

After the parity baseline is stable, independent feature tracks may add:

- richer NEM planning (purpose, product, content, PDA, articulating axes);
- criteria/rubrics;
- evaluation/reporting periods;
- teacher journal;
- family communication workflow;
- coexistence/incident records;
- evidence attachments;
- calendar/agenda;
- automatic backup and retention;
- optional app lock;
- controlled deletion/anonymization;
- opt-in encrypted cross-device sync.

## Development loop inside every phase

Each meaningful change follows:

`specify → design → implement → unit/widget/integration tests as applicable → UX review → pull request → CI → merge`.

Large phase branches are avoided. Use small branches such as `feat/student-roster`, `feat/attendance-domain`, or `feat/import-preview` so failures and regressions stay localized.

## Release philosophy

A phase is not complete because screens exist. It is complete when applicable behavior, persistence, privacy, tests, error handling and platform interaction are all accepted.

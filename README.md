# AulaRaíz

AulaRaíz is a Flutter application for classroom management and teacher workflows aligned with Mexico's Nueva Escuela Mexicana (NEM).

This repository is a clean-room rewrite. The previous `SistemaDocenteNEM` application is used only as a functional and product reference: implementation details from WPF/.NET are not migration constraints.

## Current status

**Phases 0–9 implementation complete.** AulaRaíz now covers the planned core teacher product, recovery/distribution lifecycle and the privacy-bounded local automation layer. Publishing signed production binaries still requires the repository's private Android and Windows signing credentials to be provisioned.

Implemented foundations and workflows now include:

- offline-first local persistence with Drift/SQLite;
- school, school-year and teaching-group setup;
- student roster and enrollment history;
- daily attendance;
- projects and activities with frozen historical applicability;
- formative student × activity evaluation with delivery and achievement kept separate;
- evaluation observations, filters and metrics;
- pedagogical student expediente with strengths, difficulties, supports, chronological observations and family agreements;
- related attendance and evaluation evidence inside the expediente;
- individual and group monthly PDF reports;
- CSV/XLSX student import with column mapping, preview, correction, validation and atomic confirmation;
- CSV/XLSX group export with sensitive-data opt-in and formula-safe CSV output;
- safe desktop file publication and Android sharing/export flow;
- adaptive Windows/Android-oriented UI;
- Spanish as the default language with optional English support;
- cross-product keyboard/focus, semantics, touch-target, high-contrast and text-scaling hardening;
- lazy rendering for large attendance/evaluation rosters and 30–40 student scenarios;
- recoverable loading/error states for critical roster workflows;
- versioned `.aularaiz` backups with SQLite integrity validation and crash-safe restore rollback;
- AES-256-GCM backup encryption using an installation key held in OS secure storage;
- separation of program files from classroom SQLite data;
- a per-user Windows installer with non-blocking update discovery, in-app download/verification and coordinated close/install/reopen updates;
- Android App Bundle production-signing configuration for Google Play;
- a signed GitHub Release pipeline for Android and Windows with SHA-256 release assets;
- lifecycle tests covering recovery and program/data preservation;
- a local machine-readable automation contract (`aularaiz.automation/v1`);
- minimized group/status projections with explicit personal-data opt-in;
- evidence-backed attendance/evaluation review recommendations;
- dry-run-by-default student-note mutations routed through application use cases;
- a standalone Windows `aularaiz-agent.exe` included in the installer and production signing pipeline;
- a standalone Windows `aularaiz-updater.exe` that re-verifies and coordinates verified updates outside the running app;
- automated Drift, formatting, analysis, tests, automation-agent and Android/Windows package validation in CI.

The planned delivery roadmap through **Phase 9 — Advanced local automation** is implemented. Further product work can now be prioritized by real classroom feedback rather than a required roadmap phase.

## Product direction

- Offline-first classroom work.
- Windows as the first-class desktop target.
- Android as a first-class mobile target.
- Adaptive UI rather than a desktop interface merely shrunk to mobile.
- NEM-aware without turning teacher professional judgment into a rigid form.
- Privacy by design for student, family and school information.
- Historical classroom records must not be silently rewritten by later configuration changes.
- Testable domain/application logic kept independent from Flutter widgets and persistence details.

## Product and architecture documents

- [`product-specification.md`](docs/phase-0/product-specification.md) — product intent, scope, platform and NEM baseline.
- [`functional-parity.md`](docs/phase-0/functional-parity.md) — preserve/improve/replace/defer/remove matrix against the previous application.
- [`domain-invariants.md`](docs/phase-0/domain-invariants.md) — behavioral rules that survive the technology rewrite.
- [`privacy-baseline.md`](docs/phase-0/privacy-baseline.md) — local-data, diagnostics, exports, backups and agent privacy boundaries.
- [`delivery-roadmap.md`](docs/phase-0/delivery-roadmap.md) — implementation phases from Flutter foundation through distribution and automation.
- [`decisions-and-open-questions.md`](docs/phase-0/decisions-and-open-questions.md) — accepted defaults and decisions that still require an explicit product-owner choice.
- [`release-and-lifecycle.md`](docs/phase-8/release-and-lifecycle.md) — production signing, package, coordinated Windows update and data-preservation contract.
- [`local-automation.md`](docs/phase-9/local-automation.md) — Phase 9 CLI/agent, privacy projection matrix, dry-run mutations and evidence contract.

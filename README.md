# AulaRaíz

AulaRaíz is a new Flutter application for classroom management and teacher workflows aligned with Mexico's Nueva Escuela Mexicana (NEM).

This repository is a clean-room rewrite. The previous `SistemaDocenteNEM` application is used only as a functional and product reference: implementation details from WPF/.NET are not migration constraints.

## Current status

**Phase 0 — Product specification and functional baseline.**

No production Flutter code should be added until the Phase 0 product scope, parity matrix, domain invariants, privacy baseline and delivery roadmap are accepted.

## Product direction

- Offline-first classroom work.
- Windows as the first-class desktop target.
- Android as a first-class mobile target.
- Adaptive UI rather than a desktop interface merely shrunk to mobile.
- NEM-aware without turning teacher professional judgment into a rigid form.
- Privacy by design for student, family and school information.
- Historical classroom records must not be silently rewritten by later configuration changes.
- Testable domain/application logic kept independent from Flutter widgets and persistence details.

## Phase 0 documents

- [`product-specification.md`](docs/phase-0/product-specification.md) — product intent, scope, platform and NEM baseline.
- [`functional-parity.md`](docs/phase-0/functional-parity.md) — preserve/improve/replace/defer/remove matrix against the previous application.
- [`domain-invariants.md`](docs/phase-0/domain-invariants.md) — behavioral rules that survive the technology rewrite.
- [`privacy-baseline.md`](docs/phase-0/privacy-baseline.md) — local-data, diagnostics, exports, backups and agent privacy boundaries.
- [`delivery-roadmap.md`](docs/phase-0/delivery-roadmap.md) — implementation phases from Flutter foundation through distribution and automation.
- [`decisions-and-open-questions.md`](docs/phase-0/decisions-and-open-questions.md) — accepted defaults and decisions that still require an explicit product-owner choice.

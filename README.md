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

The Phase 0 specification will live under `docs/phase-0/`.

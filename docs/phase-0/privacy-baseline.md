# Privacy Baseline

AulaRaíz manages classroom information locally and must treat privacy as a product requirement, not a later hardening task.

This document uses engineering sensitivity levels. They are not legal classifications.

## 1. Engineering sensitivity levels

| Level | Meaning | Typical examples |
| --- | --- | --- |
| P0 | Public/technical | app version, schema version, technical event category |
| P1 | Internal/pseudonymous | internal IDs, list numbers, aggregate counts |
| P2 | Personal/contextual | names, birth date, teacher/school context |
| P3 | Sensitive educational/family | attendance, evaluation, observations, supports, family agreements |

Any derived file inherits the highest level of data it contains.

## 2. Local storage

Core classroom data is local by default. Production and Demo storage are isolated.

The initial product must not require cloud storage, analytics or account creation for core use.

## 3. Data minimization

Before adding a field, answer:

1. What teacher workflow requires it?
2. Is a less sensitive value sufficient?
3. Where will it be stored?
4. Which reports, exports, backups or agent projections will copy it?
5. Can it enter logs or error messages?
6. What is its lifecycle and deletion/history behavior?

If the need is unclear, the field should not be added.

CURP is not part of the initial core model.

## 4. Sensitive free text

Pedagogical observations, strengths, difficulties, support actions and family/tutor agreements can contain highly sensitive information even when the application does not ask for it explicitly.

These fields must never be copied into technical diagnostics and must be excluded from broad exports/agent output by default.

## 5. Diagnostics

Persistent diagnostics use a strict allowlist of technical metadata.

Allowed examples:

- timestamp;
- random event ID;
- predefined event category;
- app/database version;
- Production/Demo mode;
- exception type name or a non-reversible technical fingerprint when needed.

Not allowed by default:

- exception messages;
- stack traces containing local data;
- arbitrary metadata dictionaries;
- local user paths;
- names or IDs tied to classroom evidence;
- attendance/evaluation values;
- observations/agreement text;
- raw imported rows or exported content.

## 6. Import/export

Import preview data is temporary and is not persisted unless the teacher confirms the import.

Exports are new copies outside AulaRaíz control. The UI must communicate this boundary. Sensitive follow-up and observations are excluded by default and require explicit selection.

## 7. PDF reports

Reports can contain P2/P3 data. Saving/sharing a report creates a new external copy. Report generation should avoid hidden metadata that is not required for the teacher workflow.

## 8. Backups

A complete backup is P3. The new backup design must support integrity validation and should support password protection/encryption for portable backup files.

Passwords/secrets must not be persisted in ordinary app state or logs.

## 9. Android considerations

Mobile introduces additional risks:

- shared/exported files;
- device backup behavior;
- screenshots/recent-app previews;
- removable/shared storage;
- permissions;
- device loss.

Phase 1 must choose platform storage locations and sharing mechanisms that keep private data in app-controlled storage by default.

## 10. Network boundary

The app may use network access for optional non-classroom operations such as checking software updates. Such requests must not include classroom data.

Any future sync, telemetry, AI or cloud service is a separate privacy boundary requiring its own explicit design and user-facing control.

## 11. Agent/AI boundary

A local CLI/agent interface does not automatically authorize sending its output to a remote AI service.

Default agent projections should prefer aggregates and stable internal IDs over direct names. Sensitive free-form notes are excluded from default projections. Any future remote AI integration requires a separate data-flow review and explicit product decision.

## 12. Repository and test data

GitHub, CI, screenshots, fixtures and Demo data use fictitious records only. Real student, family, teacher or school datasets must not be committed as examples, tests or debugging artifacts.

## 13. Phase 0 rule

Every Phase 1+ feature specification must identify the data it reads, writes, exports and logs before implementation begins.

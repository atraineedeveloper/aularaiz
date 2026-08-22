# Domain Invariants for the Flutter Rewrite

These rules survive the technology replacement. They should be enforced below the widget layer and covered by automated tests.

## 1. Group and student history

- Student list numbers must satisfy group consistency rules.
- Deactivation is not historical deletion.
- A later activation/deactivation must not rewrite old attendance or activity applicability.
- A student's current grade may change, but historical activity applicability remains unchanged.
- Derived values such as age and NEM phase are calculated from their source values rather than stored as independently editable truth.

## 2. NEM phase and classroom modality

Primary phases are derived from grade:

- 1st–2nd → Phase 3;
- 3rd–4th → Phase 4;
- 5th–6th → Phase 5.

One served grade derives a unigrade classroom; two or more served grades derive a multigrade classroom. Classroom modality is not the same concept as whole-school organization.

No ambiguous pedagogical metadata is inferred from project titles, free text, group names or current configuration.

## 3. Attendance

A daily attendance record is the atomic unit for a group/date.

Required semantic states:

- present;
- absent;
- late;
- justified absence.

The monthly matrix is a projection of independent daily records. Historical attendance membership is not recalculated from today's active student list.

## 4. Projects and activities

A project belongs to a group and has a lifecycle and an explicit target-grade scope when applicable.

An activity belongs to a project and may target all or a subset of the project's target grades.

At creation, an activity's initial applicable roster is based on active students whose current grade belongs to the activity scope. After creation, that scope/roster becomes historical and is not silently rewritten by later student or group changes.

## 5. Evaluation semantics

Delivery and achievement are separate internal dimensions.

The model must distinguish:

- pending delivery decision;
- delivered and awaiting evaluation;
- not delivered;
- delivered and evaluated.

A non-delivery decision must not be represented as a low achievement result. A historical non-applicable student/activity combination cannot be edited as though the student had participated.

The UI may use compact teacher-friendly states, but storage/domain logic must preserve the distinctions.

## 6. Expediente

Student follow-up is pedagogical and longitudinal. It may include strengths, difficulties, supports, chronological observations and family/tutor agreements.

The product must not transform these fields into unsupported clinical diagnoses, automated sanctions or competitive rankings.

## 7. Reporting

Reports are derived output, not independent sources of truth.

Every calculated result must be traceable to classroom evidence. Pending delivery decisions are excluded from delivery-compliance denominators. If there are no decided deliveries, the result is undefined rather than 0%.

Group reporting must not rank students competitively.

## 8. Import

File selection and parsing never mutate live classroom data.

The import workflow is:

`file → mapping → preview/review → explicit confirmation → result`.

Before confirmation, changes exist only in memory. Confirmation must revalidate against current group/context state. The included batch commits atomically or not at all.

An import never implicitly overwrites, reactivates, deactivates or merges an existing student. Ambiguous values are reviewed rather than guessed.

## 9. Export

Export never mutates classroom data.

Sensitive follow-up/observations are excluded by default. When selected, the UI must make the privacy consequence explicit.

Failed serialization must not leave a destination that appears to be a complete successful export. CSV output must neutralize spreadsheet-formula injection where applicable.

## 10. Backup and restore

A backup represents one consistent application profile.

A restore candidate must be inspected and validated before any destructive mutation of live storage. Where technically possible, restore creates a safety recovery point before replacing live state and uses rollback staging if publication fails.

Backup format versioning is independent of the application version.

## 11. Demo isolation

Demo mode uses fictitious data and a physically/logically separate storage profile. A Demo reset cannot read, overwrite or delete production classroom data.

## 12. Diagnostics

Persistent technical diagnostics must not contain student names, group names, classroom values, free-form observations, import rows, export content, raw file-system paths or arbitrary exception messages that may include such information.

Diagnostic design uses an allowlist of technical fields rather than a denylist of sensitive fields.

## 13. Agent/automation boundary

A future local agent/CLI interface must call application use cases rather than treating SQLite as a public API.

Machine-readable output is minimized by default. Personal identifiers require explicit opt-in where supported. Sensitive free-form pedagogical text is not part of a default agent projection. Mutations default to dry-run behavior and require explicit application.

## 14. Change rule

Any feature that intentionally changes one of these invariants requires a written product/domain decision, migration impact analysis and regression tests. UI convenience alone is not sufficient reason to weaken a historical-integrity or privacy invariant.

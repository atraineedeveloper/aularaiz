# Functional Parity Matrix

The previous `SistemaDocenteNEM` application is a behavioral reference, not an implementation template.

Legend: **Preserve** keeps behavior, **Improve** keeps the user need with redesigned UX, **Replace** changes the platform implementation, **Defer** is not an initial parity blocker, and **Remove** has no parity obligation.

| Area | Capability | Decision | Initial target |
| --- | --- | --- | --- |
| Classroom | Multiple groups | Preserve | Core parity |
| Classroom | School year and school context | Preserve | Core parity |
| Classroom | Served primary grades | Preserve | Core parity |
| Classroom | NEM phase derived from grade | Preserve | Core parity |
| Classroom | Unigrade / multigrade derivation | Preserve | Core parity |
| Classroom | School organization, shift, schedule | Preserve | Core parity |
| Classroom | Derived Piaget reference | Remove | — |
| Students | Create/edit | Preserve | Core parity |
| Students | Activate/deactivate with history | Preserve | Core parity |
| Students | Structured/display names | Preserve | Core parity |
| Students | Birth date and derived age | Preserve | Core parity |
| Students | Primary grade | Preserve | Core parity |
| Students | Pedagogical observations | Preserve | Core parity |
| Students | CURP in core model | Remove | — |
| Attendance | Daily attendance | Preserve | Core parity |
| Attendance | Monthly matrix | Improve | Core parity |
| Attendance | Present/absent/late/justified states | Preserve | Core parity |
| Attendance | Keyboard capture | Improve | Windows parity |
| Attendance | Counts/percentages | Preserve | Core parity |
| Attendance | Historical roster | Preserve | Core parity |
| Projects | Project lifecycle | Preserve | Core parity |
| Projects | Activities | Preserve | Core parity |
| Projects | NEM methodology | Preserve | Core parity |
| Projects | Formative field | Preserve | Core parity |
| Projects | Project/activity target grades | Preserve | Core parity |
| Projects | Historical activity roster | Preserve | Core parity |
| Evaluation | Student × activity workflow | Improve | Core parity |
| Evaluation | Delivery separate from achievement | Preserve | Core parity |
| Evaluation | Delivered but awaiting evaluation | Preserve | Core parity |
| Evaluation | Non-delivery distinct from achievement | Preserve | Core parity |
| Evaluation | Achievement levels and observations | Preserve | Core parity |
| Evaluation | Non-applicable historical cells | Preserve | Core parity |
| Evaluation | Competitive ranking | Remove | — |
| Expediente | Student profile/timeline | Improve | Core parity |
| Expediente | Strengths, difficulties, supports | Preserve | Core parity |
| Expediente | Chronological observations | Preserve | Core parity |
| Expediente | Family/tutor agreements | Preserve | Core parity |
| Reports | Individual report | Preserve | Core parity |
| Reports | Group report | Preserve | Core parity |
| Reports | Attendance/compliance/achievement summaries | Preserve | Core parity |
| Reports | PDF output | Replace | Core parity |
| Reports | Direct print/preview | Defer | Post-parity |
| Import | XLSX and UTF-8 CSV | Preserve | Core parity |
| Import | Mapping and preview wizard | Improve | Core parity |
| Import | In-memory corrections/review | Preserve | Core parity |
| Import | Duplicate/list-number review | Preserve | Core parity |
| Import | Multigrade grade resolution | Preserve | Core parity |
| Import | Atomic confirmed batch | Preserve | Core parity |
| Export | Students/attendance/projects/evaluation | Preserve | Core parity |
| Export | Multi-sheet XLSX and focused CSV | Preserve | Core parity |
| Export | Sensitive follow-up explicit opt-in | Preserve | Core parity |
| Export | Formula-safe CSV/value-only XLSX | Preserve | Core parity |
| Demo | Isolated fictitious data | Preserve | Core parity |
| Demo | Reset/reseed | Preserve | Core parity |
| Recovery | Manual complete backup | Preserve | Core parity |
| Recovery | Consistent SQLite snapshot | Preserve | Core parity |
| Recovery | Manifest/version/checksum validation | Preserve | Core parity |
| Recovery | Inspect before restore | Preserve | Core parity |
| Recovery | Safety backup and rollback | Preserve | Core parity |
| Recovery | Optional password protection | Preserve | Core parity |
| Recovery | Old `.sdocbackup` compatibility | Defer | Migration decision |
| UX | Light/Dark/High Contrast | Improve | Core parity |
| UX | Keyboard navigation/focus | Improve | Windows parity |
| UX | Adaptive Windows/Android layouts | Replace | Core parity |
| UX | Unsaved-change protection | Preserve | Core parity |
| Privacy | Local privacy-safe diagnostics | Preserve | Core parity |
| Privacy | Production/Demo isolation | Preserve | Core parity |
| Privacy | Maintained data inventory | Preserve | Core parity |
| Distribution | Windows package | Replace | Release phase |
| Distribution | User data survives ordinary app update | Preserve | Release phase |
| Distribution | GitHub Releases desktop pipeline | Preserve | Release phase |
| Distribution | Desktop update discovery | Replace | Release phase |
| Distribution | Android Play updates | Replace | Release phase |
| Distribution | Code signing | Preserve | Release phase |
| Agent | Machine-readable local interface | Preserve | Late parity |
| Agent | Minimized output by default | Preserve | Late parity |
| Agent | Dry-run writes by default | Preserve | Late parity |
| Agent | Direct SQLite access as API | Remove | — |

## Planned features from the old roadmap

The following were not completed in the reference product and therefore are expansion work rather than parity blockers: richer NEM planning with purpose/product/content/PDA/ejes; rubrics; evaluation periods; teacher journal; dedicated family communication; incident/coexistence records; evidence attachments; school calendar/agenda; automatic backups; retention; local app lock; and controlled deletion/anonymization.

## Definition of parity

AulaRaíz reaches functional parity when every `Core parity`, `Windows parity` and `Release phase` capability has an accepted Flutter implementation or an explicit product decision replaces/removes it. Pixel parity, WPF class parity, .NET API parity and historical SQLite-schema parity are not required.

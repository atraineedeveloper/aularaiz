# Phase 1 — Technical foundation

**Status:** in progress

## Baseline

AulaRaíz follows Flutter's current architecture guidance while adapting it to a domain-heavy offline product.

### Layers

- **UI:** Views + ViewModels.
- **Domain:** use cases and domain rules when behavior spans repositories or must remain independent from UI/storage.
- **Data:** abstract repositories + concrete services/adapters.
- **Platform:** file system, SQLite, printing, updates and other OS-specific capabilities behind services.

Widgets must not own classroom business rules.

## Initial package decisions

| Concern | Choice | Reason |
| --- | --- | --- |
| ViewModel state + dependency injection | `provider` + `ChangeNotifier` | Simple, explicit and aligned with Flutter's architecture examples; avoids introducing a second DI system. |
| Navigation | `go_router` | Flutter team's recommended router for most applications. |
| Local relational persistence | Drift + SQLite | Type-safe reactive SQLite access, migrations, transactions and cross-platform native support. |
| Localization | Flutter `gen-l10n` + `intl` | Official toolchain; Spanish-first with English-ready source generation. |
| Static analysis | `flutter_lints` + stricter analyzer settings | Strong baseline without an external opinionated lint stack. |
| Code generation | `build_runner` only where justified | Drift requires generation; avoid extra generators until they reduce real complexity. |

## Deliberately not selected

Phase 1 does **not** add Riverpod, BLoC, Freezed, GetIt, auto_route or another parallel state/DI/navigation stack. A dependency may be reconsidered only when a concrete requirement exceeds the chosen baseline.

## Toolchain pin

CI is pinned to Flutter `3.44.9` for repeatability. Local developers may use a compatible newer stable SDK, but CI remains the release-quality reference until deliberately upgraded.

## Platform scaffold strategy

The repository currently keeps product source independent from generated platform boilerplate. CI and `tool/bootstrap.ps1` recreate the standard Android/Windows host scaffold with:

```text
flutter create --platforms=android,windows --org=com.mindtzijib --project-name=aularaiz .
```

This is temporary during the foundation work. Before Phase 1 closes, the platform host files that are intentionally owned by AulaRaíz will be reviewed and committed so a normal clone is directly runnable without hidden setup.

`com.mindtzijib` is a provisional technical namespace until package/publisher identity is explicitly frozen before store publication.

## Privacy-safe diagnostics baseline

Framework and unhandled-error capture may persist/log only controlled technical categories and exception type names at this stage. Raw exception messages, stack traces, local paths, classroom identifiers, names and pedagogical content are excluded by design.

## Phase 1 remaining work

- commit reviewed Android and Windows host scaffolds;
- add the initial database connection boundary without defining Phase 2 domain tables early;
- add reusable result/error primitives;
- establish adaptive navigation shell/design tokens beyond the smoke UI;
- verify CI on the PR;
- add dependency/license inventory;
- freeze package/publisher identity before distribution work.

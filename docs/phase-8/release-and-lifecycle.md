# Phase 8 — Release and lifecycle

This document records the production distribution contract for AulaRaíz on Windows and Android.

## Release artifacts

A production release is created from a tag that exactly matches the semantic version in `pubspec.yaml` (for example, `version: 1.0.0+1` requires tag `v1.0.0`). The release workflow publishes:

- `AulaRaiz-<version>.aab` — production-signed Android App Bundle for Google Play;
- `AulaRaiz-<version>.aab.sha256` — App Bundle checksum;
- `AulaRaiz-Setup-<version>.exe` — production-signed per-user Windows installer;
- `AulaRaiz-Setup-<version>.exe.sha256` — Windows installer checksum.

The Windows installer contains the Flutter desktop application (`aularaiz.exe`), the standalone local automation executable (`aularaiz-agent.exe`) and the small update coordinator (`aularaiz-updater.exe`).

The workflow refuses to publish when the tag and application version disagree or when production signing credentials are missing.

## Android / Google Play signing

The stable application ID is `com.mindtzijib.aularaiz`.

Local production signing can use `android/key.properties`; `android/key.properties.example` documents the expected fields. CI does not commit or generate private signing material. The release workflow reads the following GitHub Actions secrets:

- `ANDROID_KEYSTORE_BASE64`;
- `ANDROID_KEYSTORE_PASSWORD`;
- `ANDROID_KEY_ALIAS`;
- `ANDROID_KEY_PASSWORD`.

The keystore is decoded only on the ephemeral release runner and removed after the App Bundle is built. The Gradle configuration never falls back to the debug keystore for a release.

For Google Play, the generated `.aab` is the upload artifact. Google Play App Signing should hold the app-signing key; the CI keystore should be treated as the upload key and backed up securely outside the repository.

## Windows package and signing

AulaRaíz uses an Inno Setup per-user installer. Program files are installed under the current user's local Programs directory, so routine install/update does not require administrator privileges.

The release workflow requires:

- `WINDOWS_CERTIFICATE_PFX_BASE64`;
- `WINDOWS_CERTIFICATE_PASSWORD`.

It signs `aularaiz.exe`, `aularaiz-agent.exe`, `aularaiz-updater.exe` and the final installer with SHA-256 and an RFC 3161 timestamp. The certificate is materialized only on the ephemeral runner and removed before artifact upload.

The installer intentionally does not delete application-support data during uninstall. Classroom data belongs to the user, not to the program package.

## Classroom-data preservation

AulaRaíz stores its SQLite database and restore artifacts in the platform application-support directory through `AulaRaizStorageLayout`. They are not stored next to `aularaiz.exe`.

This separation is a lifecycle invariant:

- installing a newer program version must not replace classroom data;
- uninstalling program files must not silently delete classroom data;
- a failed restore uses its own staged/safety files and rollback path;
- explicit backup/export remains the supported way to move classroom data between installations.

`test/data/storage_lifecycle_test.dart` guards the program/data separation by deleting a simulated program directory and verifying that the classroom database remains intact.

## Windows update flow

Windows update discovery is non-blocking. After the main screen becomes usable, AulaRaíz performs a best-effort background check and surfaces a short notification only when a newer eligible release exists. Opening **Preferences → Updates** also checks automatically, while **Check again** remains available for an explicit retry. Network failure never blocks local classroom work.

AulaRaíz reads published Releases from the official `atraineedeveloper/aularaiz` repository. During the 0.x Preview line, published prereleases are eligible; once the installed major version is 1 or greater, prereleases are ignored. Draft releases are always ignored. The client selects the highest compatible semantic version greater than the installed version.

For an eligible release AulaRaíz:

1. requires the exact release URL for the official repository/tag;
2. requires the exact versioned Windows installer and `.sha256` asset names;
3. requires each asset URL to remain bound to that same repository/tag/file name, with no query or fragment ambiguity;
4. downloads the checksum and installer to an application-created temporary directory;
5. verifies the installer bytes against the published SHA-256;
6. verifies Windows Authenticode before considering the download ready; unsigned installers are accepted only for version `0.x` betas after SHA-256 succeeds;
7. keeps the running application open and presents **Close and update** only after verification succeeds.

When the teacher chooses **Close and update**, AulaRaíz copies the installed `aularaiz-updater.exe` beside the verified temporary installer, launches that copy with only technical arguments, closes its SQLite connection and exits. The coordinator:

1. re-verifies the installer SHA-256;
2. re-verifies Authenticode using the same beta exception policy;
3. waits for the previous AulaRaíz process to exit;
4. runs Inno Setup silently with restart suppressed;
5. requires a successful installer exit code;
6. verifies that the installed `aularaiz.exe` still exists;
7. relaunches AulaRaíz automatically.

The coordinator runs from the temporary update directory so the installer can replace the installed coordinator itself. It receives only process id, installer path, expected SHA-256 and application executable path; no school, group, student or other classroom data is passed to it.

The first seamless-updater beta is `0.1.2`. An existing `0.1.0` or `0.1.1` installation still uses its older manual installer-opening flow to reach `0.1.2`; subsequent updates can use the coordinated close/install/reopen path.

Android updates are distributed through Google Play rather than the Windows updater.

## Creating a release

1. Update `pubspec.yaml` to the intended application version and increment the Android build number after every Play upload.
2. Merge the version change only after normal CI passes.
3. Push a matching `v<version>` tag, or run the Release workflow manually with that exact tag.
4. The workflow reruns quality checks, builds the signed App Bundle, builds/signs the Windows application, automation executable and update coordinator, builds/signs the installer, creates SHA-256 files, and publishes the GitHub Release.
5. Upload the `.aab` from that release to the intended Google Play track.

Production artifacts must never be built with debug signing or with a certificate/private key committed to the repository.

## Backup-encryption lifecycle note

Current encrypted `.aularaiz` backups are protected with an installation key held in OS secure storage. This is deliberate confidentiality protection, but it also means a protected backup cannot be restored on a different installation unless that installation has the original key. Password/recovery-key portability is intentionally not part of the current update work; legacy unencrypted backups remain readable for compatibility.

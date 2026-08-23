# Phase 8 — Backup encryption

## Scope for this increment

This increment adds encryption only. Password-based backup protection is intentionally deferred.

## Protection model

- Every new portable `.aularaiz` backup created by the production app is wrapped with AES-256-GCM.
- The entire existing AulaRaíz backup payload is encrypted, including its manifest and SQLite snapshot.
- A fresh random nonce is generated for every encryption operation.
- GCM authentication detects ciphertext, nonce and authentication-tag tampering.
- The 256-bit encryption key is generated per AulaRaíz installation and stored through the operating system secure-storage facility.
- The key itself is never written into the `.aularaiz` backup, logs, diagnostics or ordinary application preferences.
- The protected wrapper contains only technical cryptographic metadata: wrapper version, protection identifier, non-secret key fingerprint, nonce, authentication tag and ciphertext length.

## Compatibility

Legacy unencrypted AulaRaíz backups remain readable. New backups are encrypted before publication.

The encrypted wrapper is deliberately separate from the inner versioned backup format. A future password-based protector can therefore wrap the same inner format without changing SQLite restore semantics, schema compatibility rules, safety snapshots or rollback behavior.

## Deliberate limitation before password support

An encrypted backup created in this increment is installation-bound. It can only be decrypted where the corresponding installation key is still available in secure storage.

Consequences:

- copying the file to another device or a clean installation does not copy the key;
- uninstalling an app may remove its secure-storage key, particularly on Android;
- therefore this encryption-only increment is not yet the final cross-device or uninstall-recovery design.

AulaRaíz must report this case explicitly rather than treating it as silent corruption. Password-based portable protection is deferred to a later increment, as requested.

## Security rationale

Embedding a fixed application key, storing the key beside the backup, or deriving a key from public application metadata would make the file appear encrypted without providing meaningful confidentiality. This increment avoids those designs.

## Algorithms and dependencies

- AES-256-GCM via `cryptography`.
- Installation-key persistence via `flutter_secure_storage`.
- SHA-256 is used only to derive a non-secret key identifier; it is not used as encryption.

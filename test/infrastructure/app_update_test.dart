import 'dart:convert';

import 'package:aularaiz/infrastructure/update/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SemanticVersion', () {
    test('parses tags and compares numeric components', () {
      expect(SemanticVersion.parse('v1.2.3').toString(), '1.2.3');
      expect(
        SemanticVersion.parse('1.10.0')
            .compareTo(SemanticVersion.parse('1.9.9')),
        greaterThan(0),
      );
    });

    test('rejects unsupported version shapes', () {
      expect(
        () => SemanticVersion.parse('1.2'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('unsigned beta installer policy', () {
    test('allows only NotSigned installers targeting a 0.x version', () {
      expect(
        mayLaunchUnsignedBetaInstaller(
          installerFileName: 'AulaRaiz-Setup-0.1.1.exe',
          signatureStatus: 'NotSigned',
        ),
        isTrue,
      );
      expect(
        mayLaunchUnsignedBetaInstaller(
          installerFileName: 'AulaRaiz-Setup-1.0.0.exe',
          signatureStatus: 'NotSigned',
        ),
        isFalse,
      );
      expect(
        mayLaunchUnsignedBetaInstaller(
          installerFileName: 'AulaRaiz-Setup-0.1.1.exe',
          signatureStatus: 'HashMismatch',
        ),
        isFalse,
      );
      expect(
        mayLaunchUnsignedBetaInstaller(
          installerFileName: 'other.exe',
          signatureStatus: 'NotSigned',
        ),
        isFalse,
      );
    });
  });

  group('GitHub release parsing', () {
    Map<String, Object?> release({
      required String tag,
      bool draft = false,
      bool prerelease = false,
      String? body,
      bool includeAssets = true,
    }) {
      final version = tag.substring(1);
      return <String, Object?>{
        'tag_name': tag,
        'html_url':
            'https://github.com/atraineedeveloper/aularaiz/releases/tag/$tag',
        'draft': draft,
        'prerelease': prerelease,
        'body': body,
        'assets': includeAssets
            ? <Object?>[
                <String, Object?>{
                  'name': 'AulaRaiz-Setup-$version.exe',
                  'browser_download_url':
                      'https://github.com/atraineedeveloper/aularaiz/releases/download/$tag/AulaRaiz-Setup-$version.exe',
                },
                <String, Object?>{
                  'name': 'AulaRaiz-Setup-$version.exe.sha256',
                  'browser_download_url':
                      'https://github.com/atraineedeveloper/aularaiz/releases/download/$tag/AulaRaiz-Setup-$version.exe.sha256',
                },
              ]
            : const <Object?>[],
      };
    }

    test('returns a verified update projection for a newer release', () {
      final payload = jsonEncode(
        release(tag: 'v1.2.0', body: 'Safer update flow.'),
      );

      final update = parseLatestGithubRelease(payload, currentVersion: '1.1.9');

      expect(update, isNotNull);
      expect(update!.version.toString(), '1.2.0');
      expect(update.installerFileName, 'AulaRaiz-Setup-1.2.0.exe');
      expect(update.releaseNotes, 'Safer update flow.');
    });

    test(
      'returns no update for current, older, draft, or prerelease builds',
      () {
        expect(
          parseLatestGithubRelease(
            jsonEncode(release(tag: 'v1.0.0')),
            currentVersion: '1.0.0',
          ),
          isNull,
        );
        expect(
          parseLatestGithubRelease(
            jsonEncode(release(tag: 'v0.9.9')),
            currentVersion: '1.0.0',
          ),
          isNull,
        );
        expect(
          parseLatestGithubRelease(
            jsonEncode(release(tag: 'v2.0.0', draft: true)),
            currentVersion: '1.0.0',
          ),
          isNull,
        );
        expect(
          parseLatestGithubRelease(
            jsonEncode(release(tag: 'v2.0.0', prerelease: true)),
            currentVersion: '1.0.0',
          ),
          isNull,
        );
      },
    );

    test('preview 0.x channel selects the newest published prerelease', () {
      final payload = jsonEncode([
        release(tag: 'v0.1.2', prerelease: true),
        release(tag: 'v0.1.4', prerelease: true),
        release(tag: 'v0.1.3'),
      ]);

      final update = parseLatestGithubReleases(
        payload,
        currentVersion: '0.1.1',
      );

      expect(update, isNotNull);
      expect(update!.version.toString(), '0.1.4');
    });

    test('stable 1.x channel ignores prereleases', () {
      final payload = jsonEncode([
        release(tag: 'v1.3.0', prerelease: true),
        release(tag: 'v1.2.0'),
      ]);

      final update = parseLatestGithubReleases(
        payload,
        currentVersion: '1.1.0',
      );

      expect(update, isNotNull);
      expect(update!.version.toString(), '1.2.0');
    });

    test('requires both installer and checksum assets', () {
      final payload = jsonEncode(
        release(tag: 'v2.0.0', includeAssets: false),
      );

      expect(
        () => parseLatestGithubRelease(payload, currentVersion: '1.0.0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects assets that are not bound to the exact repository tag', () {
      final payload = release(tag: 'v1.2.0');
      final assets = payload['assets']! as List<Object?>;
      final installer = assets.first! as Map<String, Object?>;
      installer['browser_download_url'] =
          'https://github.com/other/repo/releases/download/v1.2.0/AulaRaiz-Setup-1.2.0.exe';

      expect(
        () => parseLatestGithubRelease(
          jsonEncode(payload),
          currentVersion: '1.1.0',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('checksum parser selects the exact installer filename', () {
    const hash =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    final checksum = parseSha256Checksum(
      '$hash  AulaRaiz-Setup-1.2.0.exe\n',
      fileName: 'AulaRaiz-Setup-1.2.0.exe',
    );

    expect(checksum, hash);
  });
}

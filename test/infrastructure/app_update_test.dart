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

  group('GitHub release parsing', () {
    test('returns a verified update projection for a newer release', () {
      final payload = jsonEncode({
        'tag_name': 'v1.2.0',
        'html_url':
            'https://github.com/atraineedeveloper/aularaiz/releases/tag/v1.2.0',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'AulaRaiz-Setup-1.2.0.exe',
            'browser_download_url': 'https://github.com/atraineedeveloper/aularaiz/releases/download/v1.2.0/AulaRaiz-Setup-1.2.0.exe',
          },
          {
            'name': 'AulaRaiz-Setup-1.2.0.exe.sha256',
            'browser_download_url': 'https://github.com/atraineedeveloper/aularaiz/releases/download/v1.2.0/AulaRaiz-Setup-1.2.0.exe.sha256',
          },
        ],
      });

      final update = parseLatestGithubRelease(payload, currentVersion: '1.1.9');

      expect(update, isNotNull);
      expect(update!.version.toString(), '1.2.0');
      expect(update.installerFileName, 'AulaRaiz-Setup-1.2.0.exe');
    });

    test(
      'returns no update for current, older, draft, or prerelease builds',
      () {
        Map<String, Object> payload({
          required String tag,
          bool draft = false,
          bool prerelease = false,
        }) => {
          'tag_name': tag,
          'html_url':
              'https://github.com/atraineedeveloper/aularaiz/releases/tag/$tag',
          'draft': draft,
          'prerelease': prerelease,
          'assets': const <Object>[],
        };

        expect(
          parseLatestGithubRelease(
            jsonEncode(payload(tag: 'v1.0.0')),
            currentVersion: '1.0.0',
          ),
          isNull,
        );
        expect(
          parseLatestGithubRelease(
            jsonEncode(payload(tag: 'v0.9.9')),
            currentVersion: '1.0.0',
          ),
          isNull,
        );
        expect(
          parseLatestGithubRelease(
            jsonEncode(payload(tag: 'v2.0.0', draft: true)),
            currentVersion: '1.0.0',
          ),
          isNull,
        );
        expect(
          parseLatestGithubRelease(
            jsonEncode(payload(tag: 'v2.0.0', prerelease: true)),
            currentVersion: '1.0.0',
          ),
          isNull,
        );
      },
    );

    test('requires both installer and checksum assets', () {
      final payload = jsonEncode({
        'tag_name': 'v2.0.0',
        'html_url':
            'https://github.com/atraineedeveloper/aularaiz/releases/tag/v2.0.0',
        'draft': false,
        'prerelease': false,
        'assets': const <Object>[],
      });

      expect(
        () => parseLatestGithubRelease(payload, currentVersion: '1.0.0'),
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

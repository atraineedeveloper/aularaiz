import 'dart:convert';

final class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(this.major, this.minor, this.patch);

  factory SemanticVersion.parse(String value) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Unsupported semantic version: $value');
    }

    return SemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(SemanticVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) return majorComparison;

    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) return minorComparison;

    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

final class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.installerUri,
    required this.checksumUri,
    required this.releaseUri,
    required this.installerFileName,
  });

  final SemanticVersion version;
  final Uri installerUri;
  final Uri checksumUri;
  final Uri releaseUri;
  final String installerFileName;
}

bool mayLaunchUnsignedBetaInstaller({
  required String installerFileName,
  required String signatureStatus,
}) {
  if (signatureStatus != 'NotSigned') return false;

  final match = RegExp(
    r'^AulaRaiz-Setup-(\d+\.\d+\.\d+)\.exe$',
  ).firstMatch(installerFileName);
  if (match == null) return false;

  return SemanticVersion.parse(match.group(1)!).major == 0;
}

AppUpdate? parseLatestGithubRelease(
  String source, {
  required String currentVersion,
}) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('GitHub release payload must be an object.');
  }

  if (decoded['draft'] == true || decoded['prerelease'] == true) {
    return null;
  }

  final tagName = decoded['tag_name'];
  final htmlUrl = decoded['html_url'];
  final assets = decoded['assets'];
  if (tagName is! String || htmlUrl is! String || assets is! List) {
    throw const FormatException('GitHub release metadata is incomplete.');
  }

  final availableVersion = SemanticVersion.parse(tagName);
  final installedVersion = SemanticVersion.parse(currentVersion);
  if (availableVersion.compareTo(installedVersion) <= 0) {
    return null;
  }

  final installerFileName = 'AulaRaiz-Setup-${availableVersion.toString()}.exe';
  final checksumFileName = '$installerFileName.sha256';

  Uri? installerUri;
  Uri? checksumUri;
  for (final asset in assets) {
    if (asset is! Map<String, dynamic>) continue;
    final name = asset['name'];
    final url = asset['browser_download_url'];
    if (name is! String || url is! String) continue;

    if (name == installerFileName) {
      installerUri = _validatedGithubAssetUri(url);
    } else if (name == checksumFileName) {
      checksumUri = _validatedGithubAssetUri(url);
    }
  }

  if (installerUri == null || checksumUri == null) {
    throw FormatException(
      'Release $tagName is missing the Windows installer or checksum.',
    );
  }

  final releaseUri = Uri.parse(htmlUrl);
  if (releaseUri.scheme != 'https' || releaseUri.host != 'github.com') {
    throw const FormatException('Unexpected GitHub release URL.');
  }

  return AppUpdate(
    version: availableVersion,
    installerUri: installerUri,
    checksumUri: checksumUri,
    releaseUri: releaseUri,
    installerFileName: installerFileName,
  );
}

String parseSha256Checksum(String source, {required String fileName}) {
  for (final rawLine in const LineSplitter().convert(source)) {
    final match = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$')
        .firstMatch(rawLine.trim());
    if (match == null) continue;

    final candidateName = match.group(2)!.trim();
    if (candidateName == fileName) {
      return match.group(1)!.toLowerCase();
    }
  }

  throw FormatException('Checksum for $fileName was not found.');
}

Uri _validatedGithubAssetUri(String value) {
  final uri = Uri.parse(value);
  if (uri.scheme != 'https' || uri.host != 'github.com') {
    throw const FormatException('Unexpected GitHub asset URL.');
  }
  return uri;
}

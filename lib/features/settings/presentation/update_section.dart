import 'dart:io';

import 'package:aularaiz/infrastructure/update/app_update.dart';
import 'package:aularaiz/infrastructure/update/github_update_service.dart';
import 'package:flutter/material.dart';

class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  final GithubUpdateService _service = GithubUpdateService();

  String? _currentVersion;
  AppUpdate? _availableUpdate;
  String? _status;
  bool _checking = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _loadCurrentVersion();
    }
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final version = await _service.currentVersion();
      if (!mounted) return;
      setState(() => _currentVersion = version);
    } catch (_) {
      // Version display is informative only. Update checks still surface errors.
    }
  }

  Future<void> _checkForUpdates(_UpdateStrings strings) async {
    if (_checking || _installing) return;
    setState(() {
      _checking = true;
      _status = null;
      _availableUpdate = null;
    });

    try {
      final update = await _service.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _availableUpdate = update;
        _status = update == null
            ? strings.upToDate
            : strings.updateAvailable(update.version.toString());
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = strings.checkFailed);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadAndInstall(_UpdateStrings strings) async {
    final update = _availableUpdate;
    if (update == null || _checking || _installing) return;

    setState(() {
      _installing = true;
      _status = strings.verifying;
    });

    try {
      final installer = await _service.downloadAndVerify(update);
      await _service.launchInstaller(installer);
      if (!mounted) return;
      setState(() => _status = strings.installerOpened);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.installerReadyTitle),
          content: Text(strings.installerReadyBody),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.ok),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = strings.installFailed);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    final strings = _UpdateStrings.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentVersion == null
                            ? strings.description
                            : strings.currentVersion(_currentVersion!),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_status != null) ...[
              const SizedBox(height: 18),
              Text(_status!),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _checking || _installing
                      ? null
                      : () => _checkForUpdates(strings),
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _checking ? strings.checking : strings.checkButton,
                  ),
                ),
                if (_availableUpdate != null)
                  FilledButton.tonalIcon(
                    onPressed: _installing
                        ? null
                        : () => _downloadAndInstall(strings),
                    icon: _installing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      _installing ? strings.preparing : strings.installButton,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _UpdateStrings {
  const _UpdateStrings({required this.english});

  factory _UpdateStrings.of(BuildContext context) => _UpdateStrings(
    english: Localizations.localeOf(context).languageCode == 'en',
  );

  final bool english;

  String get title => english ? 'Updates' : 'Actualizaciones';
  String get description => english
      ? 'Check verified AulaRaíz releases for Windows. Beta 0.x installers may be unsigned, but their SHA-256 checksum is always verified.'
      : 'Busca versiones verificadas de AulaRaíz para Windows. Las betas 0.x pueden no estar firmadas, pero siempre se verifica su checksum SHA-256.';
  String currentVersion(String version) => english
      ? 'Installed version: $version · updates are checked manually'
      : 'Versión instalada: $version · las actualizaciones se buscan manualmente';
  String get checkButton =>
      english ? 'Check for updates' : 'Buscar actualizaciones';
  String get checking => english ? 'Checking…' : 'Buscando…';
  String get upToDate => english
      ? 'You already have the latest version.'
      : 'Ya tienes la versión más reciente.';
  String updateAvailable(String version) => english
      ? 'Version $version is available.'
      : 'La versión $version está disponible.';
  String get checkFailed => english
      ? 'Could not check for updates. Check your connection and try again.'
      : 'No se pudo buscar actualizaciones. Revisa tu conexión e inténtalo de nuevo.';
  String get installButton =>
      english ? 'Download and install' : 'Descargar e instalar';
  String get preparing => english ? 'Preparing…' : 'Preparando…';
  String get verifying => english
      ? 'Downloading and verifying the installer…'
      : 'Descargando y verificando el instalador…';
  String get installerOpened => english
      ? 'Verified installer opened.'
      : 'Se abrió el instalador verificado.';
  String get installFailed => english
      ? 'The update could not be verified or opened.'
      : 'No se pudo verificar o abrir la actualización.';
  String get installerReadyTitle =>
      english ? 'Update ready' : 'Actualización lista';
  String get installerReadyBody => english
      ? 'Follow the installer steps. During the 0.x beta Windows may show Unknown publisher for unsigned builds. AulaRaíz may ask you to close the current window while it updates. Classroom data is stored separately from the program files.'
      : 'Sigue los pasos del instalador. Durante la beta 0.x Windows puede mostrar Editor desconocido en compilaciones sin firma. AulaRaíz puede pedirte cerrar esta ventana mientras se actualiza. Los datos del aula se guardan separados de los archivos del programa.';
  String get ok => english ? 'OK' : 'Entendido';
}

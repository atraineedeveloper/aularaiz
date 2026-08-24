import 'dart:io';

import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/infrastructure/update/app_update.dart';
import 'package:aularaiz/infrastructure/update/github_update_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  final GithubUpdateService _service = GithubUpdateService();

  String? _currentVersion;
  AppUpdate? _availableUpdate;
  VerifiedUpdateInstaller? _preparedInstaller;
  String? _status;
  bool _checking = false;
  bool _downloading = false;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _loadAndCheck();
    }
  }

  Future<void> _loadAndCheck() async {
    await _loadCurrentVersion();
    if (!mounted) return;
    await _checkForUpdates(_UpdateStrings.of(context), automatic: true);
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

  Future<void> _checkForUpdates(
    _UpdateStrings strings, {
    bool automatic = false,
  }) async {
    if (_checking || _downloading || _launching) return;
    setState(() {
      _checking = true;
      if (!automatic) _status = null;
      _availableUpdate = null;
      _preparedInstaller = null;
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
      if (!automatic) {
        setState(() => _status = strings.checkFailed);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadAndPrepare(_UpdateStrings strings) async {
    final update = _availableUpdate;
    if (update == null || _checking || _downloading || _launching) return;

    setState(() {
      _downloading = true;
      _preparedInstaller = null;
      _status = strings.verifying;
    });

    try {
      final prepared = await _service.downloadAndVerify(update);
      if (!mounted) return;
      setState(() {
        _preparedInstaller = prepared;
        _status = strings.readyToRestart(update.version.toString());
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = strings.installFailed);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _closeAndUpdate(_UpdateStrings strings) async {
    final prepared = _preparedInstaller;
    if (prepared == null || _checking || _downloading || _launching) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.restartTitle),
        content: Text(strings.restartBody(prepared.update.version.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.later),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.closeAndUpdate),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _launching = true;
      _status = strings.closing;
    });

    try {
      await _service.launchUpdateCoordinator(prepared);
      await context.read<AppDatabase>().close();
      exit(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _launching = false;
        _status = strings.launchFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    final strings = _UpdateStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final notes = _availableUpdate?.releaseNotes;

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
            if (notes != null) ...[
              const SizedBox(height: 14),
              Text(
                strings.releaseNotes,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                notes.length > 1200 ? '${notes.substring(0, 1200)}…' : notes,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _checking || _downloading || _launching
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
                if (_availableUpdate != null && _preparedInstaller == null)
                  FilledButton.tonalIcon(
                    onPressed: _downloading
                        ? null
                        : () => _downloadAndPrepare(strings),
                    icon: _downloading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      _downloading ? strings.preparing : strings.downloadButton,
                    ),
                  ),
                if (_preparedInstaller != null)
                  FilledButton.tonalIcon(
                    onPressed: _launching
                        ? null
                        : () => _closeAndUpdate(strings),
                    icon: _launching
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restart_alt_rounded),
                    label: Text(strings.closeAndUpdate),
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
      ? 'AulaRaíz checks Windows releases when this section opens and can complete a verified update without leaving the app.'
      : 'AulaRaíz revisa las versiones de Windows al abrir esta sección y puede completar una actualización verificada sin salir del flujo de la app.';
  String currentVersion(String version) => english
      ? 'Installed version: $version · background checks are non-blocking'
      : 'Versión instalada: $version · la comprobación automática no bloquea el trabajo';
  String get checkButton =>
      english ? 'Check again' : 'Buscar de nuevo';
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
  String get downloadButton =>
      english ? 'Download update' : 'Descargar actualización';
  String get preparing => english ? 'Preparing…' : 'Preparando…';
  String get verifying => english
      ? 'Downloading and verifying SHA-256 and Authenticode…'
      : 'Descargando y verificando SHA-256 y Authenticode…';
  String readyToRestart(String version) => english
      ? 'Version $version is verified and ready. AulaRaíz will reopen automatically after installation.'
      : 'La versión $version está verificada y lista. AulaRaíz se volverá a abrir automáticamente después de instalarla.';
  String get installFailed => english
      ? 'The update could not be downloaded or verified.'
      : 'No se pudo descargar o verificar la actualización.';
  String get releaseNotes => english ? 'Release notes' : 'Novedades';
  String get restartTitle => english ? 'Close and update?' : '¿Cerrar y actualizar?';
  String restartBody(String version) => english
      ? 'AulaRaíz will close, install version $version with the verified installer, and reopen automatically. Save any work in other open AulaRaíz windows first.'
      : 'AulaRaíz se cerrará, instalará la versión $version con el instalador verificado y se volverá a abrir automáticamente. Guarda primero cualquier trabajo pendiente en otras ventanas de AulaRaíz.';
  String get later => english ? 'Later' : 'Más tarde';
  String get closeAndUpdate =>
      english ? 'Close and update' : 'Cerrar y actualizar';
  String get closing => english
      ? 'Closing AulaRaíz to install the update…'
      : 'Cerrando AulaRaíz para instalar la actualización…';
  String get launchFailed => english
      ? 'The update coordinator could not start. AulaRaíz remains open.'
      : 'No se pudo iniciar el coordinador de actualización. AulaRaíz permanecerá abierta.';
}

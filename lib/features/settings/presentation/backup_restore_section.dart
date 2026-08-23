import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/infrastructure/backup/backup_restore_gateway.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BackupRestoreSection extends StatefulWidget {
  const BackupRestoreSection({super.key});

  @override
  State<BackupRestoreSection> createState() => _BackupRestoreSectionState();
}

class _BackupRestoreSectionState extends State<BackupRestoreSection> {
  BackupSelection? _selection;
  bool _busy = false;
  bool _restorePrepared = false;
  bool _pendingChecked = false;
  String? _status;
  bool _statusIsError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pendingChecked) return;
    _pendingChecked = true;
    _loadPendingRestore();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _BackupRestoreStrings.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.settings_backup_restore_rounded,
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
                        strings.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy || _restorePrepared ? null : _exportBackup,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: Text(strings.createBackup),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || _restorePrepared ? null : _selectBackup,
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(strings.chooseBackup),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(strings.working),
            ],
            if (_status != null) ...[
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: _StatusPanel(
                  message: _status!,
                  isError: _statusIsError,
                ),
              ),
            ],
            if (_selection != null && !_restorePrepared) ...[
              const SizedBox(height: 18),
              _BackupPreviewCard(
                selection: _selection!,
                strings: strings,
                onRestore: _busy ? null : _confirmRestore,
              ),
            ],
            if (_restorePrepared) ...[
              const SizedBox(height: 18),
              _PreparedRestorePanel(strings: strings),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadPendingRestore() async {
    try {
      final pending = await context
          .read<BackupRestoreGateway>()
          .hasPendingRestore();
      if (!mounted || !pending) return;
      setState(() {
        _restorePrepared = true;
      });
    } on Object {
      if (!mounted) return;
      final strings = _BackupRestoreStrings.of(context);
      _setStatus(strings.pendingCheckError, isError: true);
    }
  }

  Future<void> _exportBackup() async {
    final strings = _BackupRestoreStrings.of(context);
    await _runBusy(() async {
      final published = await context
          .read<BackupRestoreGateway>()
          .exportBackup();
      if (!mounted) return;
      _setStatus(
        published ? strings.backupSaved : strings.backupCancelled,
        isError: false,
      );
    });
  }

  Future<void> _selectBackup() async {
    final strings = _BackupRestoreStrings.of(context);
    await _runBusy(() async {
      final selection = await context
          .read<BackupRestoreGateway>()
          .selectBackup();
      if (!mounted || selection == null) return;
      setState(() {
        _selection = selection;
        _status = strings.backupReady;
        _statusIsError = false;
      });
    });
  }

  Future<void> _confirmRestore() async {
    final selection = _selection;
    if (selection == null) return;
    final strings = _BackupRestoreStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.confirmTitle),
        content: Text(strings.confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.confirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runBusy(() async {
      await context.read<BackupRestoreGateway>().stageRestore(selection);
      if (!mounted) return;
      setState(() {
        _selection = null;
        _restorePrepared = true;
        _status = null;
        _statusIsError = false;
      });
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.preparedTitle),
          content: Text(strings.preparedBody),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.understood),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
      _statusIsError = false;
    });
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      _setStatus(_friendlyError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _setStatus(String value, {required bool isError}) {
    setState(() {
      _status = value;
      _statusIsError = isError;
    });
  }

  String _friendlyError(Object error) {
    final strings = _BackupRestoreStrings.of(context);
    if (error is BackupFormatException) return strings.invalidBackup;
    if (error is RestoreException) {
      return switch (error.problem) {
        RestoreProblem.profileMismatch => strings.incompatibleProfile,
        RestoreProblem.newerSchema => strings.newerVersion,
        RestoreProblem.invalidDatabase ||
        RestoreProblem.invalidRequest ||
        RestoreProblem.missingRestoreArtifact ||
        RestoreProblem.stagedArtifactChanged => strings.invalidBackup,
        RestoreProblem.applyFailed || RestoreProblem.rollbackFailed =>
          strings.restoreError,
      };
    }
    return strings.genericError;
  }
}

class _BackupPreviewCard extends StatelessWidget {
  const _BackupPreviewCard({
    required this.selection,
    required this.strings,
    required this.onRestore,
  });

  final BackupSelection selection;
  final _BackupRestoreStrings strings;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final manifest = selection.preview.manifest;
    final created = manifest.createdAtUtc.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatMediumDate(created);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(created));
    final profile = manifest.storageProfile == 'production'
        ? strings.productionProfile
        : strings.demoProfile;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.previewTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PreviewRow(
              label: strings.createdLabel,
              value: '$date · $time',
            ),
            _PreviewRow(
              label: strings.schemaLabel,
              value: manifest.schemaVersion.toString(),
            ),
            _PreviewRow(label: strings.profileLabel, value: profile),
            const SizedBox(height: 14),
            Text(
              strings.previewWarning,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.restore_page_rounded),
              label: Text(strings.restoreThisBackup),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PreparedRestorePanel extends StatelessWidget {
  const _PreparedRestorePanel({required this.strings});

  final _BackupRestoreStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.restart_alt_rounded, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                strings.preparedBody,
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.surfaceContainer;
    final foreground = isError ? scheme.onErrorContainer : scheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: foreground))),
          ],
        ),
      ),
    );
  }
}

final class _BackupRestoreStrings {
  const _BackupRestoreStrings(this.spanish);

  factory _BackupRestoreStrings.of(BuildContext context) =>
      _BackupRestoreStrings(
        Localizations.localeOf(context).languageCode.toLowerCase() != 'en',
      );

  final bool spanish;

  String get title => spanish
      ? 'Copia de seguridad y restauración'
      : 'Backup and restore';
  String get description => spanish
      ? 'Guarda una copia completa de AulaRaíz o prepara una restauración validada. La restauración se aplica al volver a abrir la app.'
      : 'Save a complete AulaRaíz backup or prepare a validated restore. The restore is applied when you reopen the app.';
  String get createBackup =>
      spanish ? 'Crear copia de seguridad' : 'Create backup';
  String get chooseBackup =>
      spanish ? 'Elegir copia para restaurar' : 'Choose backup to restore';
  String get working =>
      spanish ? 'Procesando de forma segura…' : 'Processing safely…';
  String get backupSaved => spanish
      ? 'Copia de seguridad guardada o compartida.'
      : 'Backup saved or shared.';
  String get backupCancelled =>
      spanish ? 'No se guardó ninguna copia.' : 'No backup was saved.';
  String get backupReady => spanish
      ? 'La copia fue reconocida y es compatible. Se validará completamente al preparar la restauración.'
      : 'The backup was recognized and is compatible. It will be fully validated when the restore is prepared.';
  String get previewTitle =>
      spanish ? 'Copia reconocida' : 'Recognized backup';
  String get createdLabel => spanish ? 'Creada' : 'Created';
  String get schemaLabel => spanish ? 'Versión de datos' : 'Data version';
  String get profileLabel => spanish ? 'Perfil' : 'Profile';
  String get productionProfile =>
      spanish ? 'Datos principales' : 'Main data';
  String get demoProfile =>
      spanish ? 'Datos de demostración' : 'Demo data';
  String get previewWarning => spanish
      ? 'Al preparar la restauración, AulaRaíz hará una validación SQLite completa. Solo entonces dejará la copia lista para el próximo arranque; los datos actuales todavía no se reemplazan.'
      : 'When preparing the restore, AulaRaíz performs a full SQLite validation. Only then is the backup staged for the next launch; current data is not replaced yet.';
  String get restoreThisBackup =>
      spanish ? 'Restaurar esta copia' : 'Restore this backup';
  String get confirmTitle =>
      spanish ? '¿Preparar esta restauración?' : 'Prepare this restore?';
  String get confirmBody => spanish
      ? 'La copia se validará completamente y, si pasa, se dejará preparada para el próximo arranque. Guarda cualquier trabajo pendiente y después cierra completamente AulaRaíz y vuelve a abrirla.'
      : 'The backup will be fully validated and, if it passes, staged for the next launch. Save any pending work, then fully close AulaRaíz and open it again.';
  String get cancel => spanish ? 'Cancelar' : 'Cancel';
  String get confirmAction =>
      spanish ? 'Preparar restauración' : 'Prepare restore';
  String get preparedTitle =>
      spanish ? 'Restauración preparada' : 'Restore prepared';
  String get preparedBody => spanish
      ? 'Cierra completamente AulaRaíz y vuelve a abrirla para aplicar la restauración. No continúes editando datos antes de reiniciar.'
      : 'Fully close AulaRaíz and open it again to apply the restore. Do not keep editing data before restarting.';
  String get understood => spanish ? 'Entendido' : 'Got it';
  String get invalidBackup => spanish
      ? 'El archivo no es una copia válida de AulaRaíz o está dañado.'
      : 'The file is not a valid AulaRaíz backup or is damaged.';
  String get incompatibleProfile => spanish
      ? 'Esta copia pertenece a otro perfil de datos y no puede restaurarse aquí.'
      : 'This backup belongs to a different data profile and cannot be restored here.';
  String get newerVersion => spanish
      ? 'Esta copia fue creada con una versión de AulaRaíz más nueva. Actualiza la app antes de restaurarla.'
      : 'This backup was created by a newer AulaRaíz version. Update the app before restoring it.';
  String get restoreError => spanish
      ? 'No se pudo preparar la restauración de forma segura.'
      : 'The restore could not be prepared safely.';
  String get pendingCheckError => spanish
      ? 'No se pudo comprobar si hay una restauración pendiente. Intenta cerrar y volver a abrir AulaRaíz.'
      : 'AulaRaíz could not check whether a restore is pending. Try closing and reopening the app.';
  String get genericError => spanish
      ? 'No se pudo completar la operación. Tus datos actuales no fueron reemplazados.'
      : 'The operation could not be completed. Your current data was not replaced.';
}

import 'dart:io';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/infrastructure/backup/backup_restore_gateway.dart';
import 'package:aularaiz/infrastructure/backup/local_backup_transfer_server.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final actions = <Widget>[
                  FilledButton.icon(
                    onPressed: _busy || _restorePrepared ? null : _exportBackup,
                    icon: const Icon(Icons.save_alt_rounded),
                    label: Text(strings.createBackup),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy || _restorePrepared
                        ? null
                        : _exportPortableBackup,
                    icon: const Icon(Icons.devices_other_rounded),
                    label: Text(strings.createPortableBackup),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy || _restorePrepared
                        ? null
                        : _startWifiTransfer,
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(strings.startWifiTransfer),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _restorePrepared ? null : _selectBackup,
                    icon: const Icon(Icons.restore_rounded),
                    label: Text(strings.chooseBackup),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _restorePrepared
                        ? null
                        : _selectPortableBackup,
                    icon: const Icon(Icons.phonelink_setup_rounded),
                    label: Text(strings.choosePortableBackup),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _restorePrepared
                        ? null
                        : () => context.push('/settings/receive-backup'),
                    icon: Icon(
                      Platform.isAndroid
                          ? Icons.qr_code_scanner_rounded
                          : Icons.link_rounded,
                    ),
                    label: Text(strings.receiveFromDevice),
                  ),
                ];
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < actions.length; index++) ...[
                        actions[index],
                        if (index < actions.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  );
                }
                return Wrap(spacing: 12, runSpacing: 12, children: actions);
              },
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
                child: _StatusPanel(message: _status!, isError: _statusIsError),
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

  Future<void> _exportPortableBackup() async {
    final strings = _BackupRestoreStrings.of(context);
    PortableBackupExport? portable;
    await _runBusy(() async {
      portable = await context
          .read<BackupRestoreGateway>()
          .exportPortableBackup();
      if (!mounted) return;
      _setStatus(
        portable == null
            ? strings.backupCancelled
            : strings.portableBackupSaved,
        isError: false,
      );
    });
    if (!mounted || portable == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.transferCodeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.transferCodeBody),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Center(
                  child: SelectableText(
                    portable!.transferCode,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.understood),
          ),
        ],
      ),
    );
  }

  Future<void> _startWifiTransfer() async {
    final strings = _BackupRestoreStrings.of(context);
    Object? startError;
    PortableBackupTransferSession? session;
    await _runBusy(() async {
      try {
        session = await context
            .read<BackupRestoreGateway>()
            .startPortableBackupTransfer();
      } on Object catch (error) {
        startError = error;
        rethrow;
      }
    });
    if (!mounted || session == null || startError != null) return;
    final activeSession = session!;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.wifiTransferTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.wifiTransferBody),
                  const SizedBox(height: 18),
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 220,
                          child: QrImageView(
                            data: activeSession.downloadUrl,
                            version: QrVersions.auto,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    strings.transferCodeLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  _SelectableCode(value: activeSession.transferCode),
                  const SizedBox(height: 14),
                  Text(
                    strings.downloadUrlLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(activeSession.downloadUrl),
                  const SizedBox(height: 14),
                  Text(strings.wifiTransferWarning),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.stopWifiTransfer),
            ),
          ],
        ),
      );
    } finally {
      await activeSession.stop();
    }
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

  Future<void> _selectPortableBackup() async {
    final strings = _BackupRestoreStrings.of(context);
    final transferCode = await _askTransferCode(strings);
    if (!mounted || transferCode == null) return;
    await _runBusy(() async {
      final selection = await context
          .read<BackupRestoreGateway>()
          .selectPortableBackup(transferCode: transferCode);
      if (!mounted || selection == null) return;
      setState(() {
        _selection = selection;
        _status = strings.backupReady;
        _statusIsError = false;
      });
    });
  }

  Future<String?> _askTransferCode(_BackupRestoreStrings strings) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.enterTransferCodeTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: strings.transferCodeLabel,
            helperText: strings.transferCodeHelper,
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(strings.continueAction),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result;
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

    var prepared = false;
    await _runBusy(() async {
      await context.read<BackupRestoreGateway>().stageRestore(selection);
      if (!mounted) return;
      setState(() {
        _selection = null;
        _restorePrepared = true;
        _status = null;
        _statusIsError = false;
      });
      prepared = true;
    });
    if (!mounted || !prepared) return;

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
    if (error is BackupProtectionException) {
      return switch (error.problem) {
        BackupProtectionProblem.keyUnavailable ||
        BackupProtectionProblem.keyMismatch => strings.encryptionKeyUnavailable,
        BackupProtectionProblem.unsupportedProtection =>
          strings.unsupportedProtection,
        BackupProtectionProblem.invalidEnvelope ||
        BackupProtectionProblem.authenticationFailed => strings.invalidBackup,
      };
    }
    if (error is RestoreException) {
      return switch (error.problem) {
        RestoreProblem.profileMismatch => strings.incompatibleProfile,
        RestoreProblem.newerSchema => strings.newerVersion,
        RestoreProblem.invalidDatabase ||
        RestoreProblem.invalidRequest ||
        RestoreProblem.missingRestoreArtifact ||
        RestoreProblem.stagedArtifactChanged => strings.invalidBackup,
        RestoreProblem.applyFailed ||
        RestoreProblem.rollbackFailed => strings.restoreError,
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
            _PreviewRow(label: strings.createdLabel, value: '$date · $time'),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(value),
              ],
            );
          }
          return Row(
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
          );
        },
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
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableCode extends StatelessWidget {
  const _SelectableCode({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Center(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
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

  String get title =>
      spanish ? 'Copia de seguridad y restauración' : 'Backup and restore';
  String get description => spanish
      ? 'Guarda una copia completa cifrada de AulaRaíz o prepara una restauración validada. Por ahora, las copias cifradas solo pueden restaurarse en la instalación que las creó.'
      : 'Save a complete encrypted AulaRaíz backup or prepare a validated restore. For now, encrypted backups can only be restored by the installation that created them.';
  String get createBackup =>
      spanish ? 'Crear copia de seguridad' : 'Create backup';
  String get createPortableBackup => spanish
      ? 'Crear copia para otro dispositivo'
      : 'Create backup for another device';
  String get startWifiTransfer => spanish
      ? 'Enviar a otro dispositivo por Wi-Fi'
      : 'Send to another device over Wi-Fi';
  String get chooseBackup =>
      spanish ? 'Elegir copia para restaurar' : 'Choose backup to restore';
  String get choosePortableBackup =>
      spanish ? 'Restaurar copia portable' : 'Restore portable backup';
  String get receiveFromDevice =>
      spanish ? 'Recibir por Wi-Fi' : 'Receive over Wi-Fi';
  String get working =>
      spanish ? 'Procesando de forma segura…' : 'Processing safely…';
  String get backupSaved => spanish
      ? 'Copia de seguridad cifrada guardada o compartida.'
      : 'Encrypted backup saved or shared.';
  String get portableBackupSaved => spanish
      ? 'Copia portable guardada. Usa el código de transferencia para abrirla en otro dispositivo.'
      : 'Portable backup saved. Use the transfer code to open it on another device.';
  String get backupCancelled =>
      spanish ? 'No se guardó ninguna copia.' : 'No backup was saved.';
  String get backupReady => spanish
      ? 'La copia fue reconocida y es compatible. Se validará completamente al preparar la restauración.'
      : 'The backup was recognized and is compatible. It will be fully validated when the restore is prepared.';
  String get previewTitle => spanish ? 'Copia reconocida' : 'Recognized backup';
  String get createdLabel => spanish ? 'Creada' : 'Created';
  String get schemaLabel => spanish ? 'Versión de datos' : 'Data version';
  String get profileLabel => spanish ? 'Perfil' : 'Profile';
  String get productionProfile => spanish ? 'Datos principales' : 'Main data';
  String get demoProfile => spanish ? 'Datos de demostración' : 'Demo data';
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
  String get continueAction => spanish ? 'Continuar' : 'Continue';
  String get preparedTitle =>
      spanish ? 'Restauración preparada' : 'Restore prepared';
  String get preparedBody => spanish
      ? 'Cierra completamente AulaRaíz y vuelve a abrirla para aplicar la restauración. No continúes editando datos antes de reiniciar.'
      : 'Fully close AulaRaíz and open it again to apply the restore. Do not keep editing data before restarting.';
  String get understood => spanish ? 'Entendido' : 'Got it';
  String get transferCodeTitle =>
      spanish ? 'Código de transferencia' : 'Transfer code';
  String get transferCodeBody => spanish
      ? 'Guarda este código. Lo necesitarás para restaurar esta copia en otro dispositivo. No lo compartas con personas que no deban ver tus datos.'
      : 'Save this code. You will need it to restore this backup on another device. Do not share it with anyone who should not see your data.';
  String get enterTransferCodeTitle =>
      spanish ? 'Ingresar código de transferencia' : 'Enter transfer code';
  String get transferCodeLabel =>
      spanish ? 'Código de transferencia' : 'Transfer code';
  String get transferCodeHelper => spanish
      ? 'Es el código mostrado al crear la copia portable.'
      : 'This is the code shown when the portable backup was created.';
  String get wifiTransferTitle =>
      spanish ? 'Enviar datos por Wi-Fi' : 'Send data over Wi-Fi';
  String get wifiTransferBody => spanish
      ? 'Conecta el otro dispositivo a la misma red Wi-Fi. En ese dispositivo abre Recibir por Wi-Fi, escanea el QR o pega la liga, y usa el código de transferencia para restaurar los datos.'
      : 'Connect the other device to the same Wi-Fi network. On that device, open Receive over Wi-Fi, scan the QR or paste the link, and use the transfer code to restore the data.';
  String get downloadUrlLabel => spanish ? 'Liga de descarga' : 'Download link';
  String get wifiTransferWarning => spanish
      ? 'Mantén esta ventana abierta mientras el otro dispositivo recibe la copia. Al cerrarla, AulaRaíz apagará la transferencia local.'
      : 'Keep this window open while the other device receives the backup. When you close it, AulaRaíz will stop the local transfer.';
  String get stopWifiTransfer =>
      spanish ? 'Cerrar transferencia' : 'Close transfer';
  String get invalidBackup => spanish
      ? 'El archivo no es una copia válida de AulaRaíz, está dañado o su cifrado fue alterado.'
      : 'The file is not a valid AulaRaíz backup, is damaged, or its encrypted contents were altered.';
  String get encryptionKeyUnavailable => spanish
      ? 'No se encontró la clave local necesaria para abrir esta copia cifrada. Por ahora, solo puede restaurarse en la instalación que la creó.'
      : 'The local key required to open this encrypted backup is not available. For now, it can only be restored by the installation that created it.';
  String get unsupportedProtection => spanish
      ? 'Esta copia usa un método de protección que esta versión de AulaRaíz no reconoce.'
      : 'This backup uses a protection method that this version of AulaRaíz does not recognize.';
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

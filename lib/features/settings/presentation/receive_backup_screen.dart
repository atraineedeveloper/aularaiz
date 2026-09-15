import 'dart:io';

import 'package:aularaiz/app/layout/responsive_layout.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/infrastructure/backup/backup_restore_gateway.dart';
import 'package:aularaiz/infrastructure/backup/local_backup_transfer_server.dart';
import 'package:aularaiz/infrastructure/sync/record_level_sync_service.dart';
import 'package:aularaiz/infrastructure/sync/sync_device_registry.dart';
import 'package:aularaiz/infrastructure/window/window_title_service.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class ReceiveBackupScreen extends StatefulWidget {
  const ReceiveBackupScreen({super.key});

  @override
  State<ReceiveBackupScreen> createState() => _ReceiveBackupScreenState();
}

class _ReceiveBackupScreenState extends State<ReceiveBackupScreen> {
  late final MobileScannerController _scannerController;
  bool _processing = false;
  String? _status;
  bool _statusIsError = false;

  bool get _canScanQr => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _ReceiveBackupStrings.of(context);
    final layout = ResponsiveLayoutInfo.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WindowTitleService.setTitle('AulaRaíz · ${strings.title}');
    });

    return Scaffold(
      appBar: AppBar(title: Text(strings.title)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(layout.pagePadding),
          children: [
            Text(
              strings.heading,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!layout.preferDenseUi) ...[
              const SizedBox(height: 8),
              Text(
                _canScanQr ? strings.instructions : strings.manualInstructions,
              ),
            ],
            SizedBox(height: layout.preferDenseUi ? 12 : 18),
            if (_canScanQr) ...[
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: layout.preferDenseUi ? 260 : 420,
                    maxHeight: layout.preferDenseUi ? 260 : 420,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: _onDetect,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          if (_processing)
                            ColoredBox(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    Text(
                                      strings.processing,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: layout.preferDenseUi ? 12 : 18),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.link_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.manualOnlyBody,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            OutlinedButton.icon(
              onPressed: _processing ? null : _enterLinkManually,
              icon: const Icon(Icons.link_rounded),
              label: Text(strings.manualLink),
            ),
            if (_status != null) ...[
              const SizedBox(height: 18),
              _ReceiveStatusPanel(message: _status!, isError: _statusIsError),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null || value.isEmpty) return;
    final payload = parsePortableBackupTransferQrPayload(value);
    if (payload != null) {
      await _receiveWithTransferCode(
        downloadUrl: payload.downloadUrl,
        uploadUrl: payload.uploadUrl,
        transferCode: payload.transferCode,
        sourceDeviceId: payload.sourceDeviceId,
        sourceDeviceName: payload.sourceDeviceName,
      );
      return;
    }
    await _receiveFromUrl(value);
  }

  Future<void> _enterLinkManually() async {
    final strings = _ReceiveBackupStrings.of(context);
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.manualLinkTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: strings.manualLinkLabel),
          keyboardType: TextInputType.url,
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
    if (value == null || value.isEmpty) return;
    await _receiveFromUrl(value);
  }

  Future<void> _receiveFromUrl(String url) async {
    if (_processing) return;
    final strings = _ReceiveBackupStrings.of(context);
    final code = await _askTransferCode(strings);
    if (!mounted || code == null) return;
    await _receiveWithTransferCode(downloadUrl: url, transferCode: code);
  }

  Future<void> _receiveWithTransferCode({
    required String downloadUrl,
    String? uploadUrl,
    required String transferCode,
    String? sourceDeviceId,
    String? sourceDeviceName,
  }) async {
    if (_processing) return;
    final strings = _ReceiveBackupStrings.of(context);
    final gateway = context.read<BackupRestoreGateway>();
    final registry = context.read<SyncDeviceRegistry>();

    setState(() {
      _processing = true;
      _status = null;
      _statusIsError = false;
    });
    try {
      if (_canScanQr) await _scannerController.stop();
      final selection = await gateway.receivePortableBackupSelectionFromUrl(
        downloadUrl: downloadUrl,
        transferCode: transferCode,
      );
      final current = await gateway.currentContentSummary();
      if (!mounted) return;
      final linked = await _linkedDevice(
        registry: registry,
        sourceDeviceId: sourceDeviceId,
      );
      if (!mounted) return;
      final autoApply = _canApplyAutomatically(
        linked: linked,
        current: current,
        selection: selection,
      );
      if (!autoApply) {
        final confirmed = await _confirmIncomingRestore(
          strings: strings,
          selection: selection,
          current: current,
          linked: linked,
        );
        if (confirmed != true) {
          if (_canScanQr) await _scannerController.start();
          return;
        }
      }

      final syncSummary = await gateway.mergeIncomingBackup(selection);
      final returnedSummary = uploadUrl == null || uploadUrl.trim().isEmpty
          ? null
          : await gateway.pushCurrentBackupToUrl(
              uploadUrl: uploadUrl,
              transferCode: transferCode,
            );
      if (!mounted) return;
      final normalizedDeviceId = sourceDeviceId?.trim();
      if (normalizedDeviceId != null && normalizedDeviceId.isNotEmpty) {
        await registry.rememberLinkedDevice(
          id: normalizedDeviceId,
          name: sourceDeviceName ?? strings.unknownDevice,
          receivedBackupCreatedAtUtc: selection.preview.manifest.createdAtUtc,
        );
      }
      if (!mounted) return;
      setState(() {
        _status = strings.syncApplied(syncSummary.changed, returnedSummary);
        _statusIsError = false;
      });
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.syncAppliedTitle),
          content: Text(strings.syncAppliedBody(syncSummary, returnedSummary)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.understood),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _friendlyError(error, strings);
        _statusIsError = true;
      });
      if (_canScanQr) await _scannerController.start();
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<bool?> _confirmIncomingRestore({
    required _ReceiveBackupStrings strings,
    required BackupSelection selection,
    required BackupContentSummary current,
    LinkedSyncDevice? linked,
  }) {
    final incoming = selection.preview.summary;
    final manifest = selection.preview.manifest;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.confirmTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SyncRecommendationPanel(
                strings: strings,
                incomingCreatedAtUtc: manifest.createdAtUtc,
                currentModifiedAtUtc: current.localModifiedAtUtc,
                linked: linked,
              ),
              const SizedBox(height: 16),
              _SummaryComparison(
                strings: strings,
                current: current,
                incoming: incoming,
                incomingCreatedAtUtc: manifest.createdAtUtc,
              ),
              const SizedBox(height: 14),
              Text(strings.confirmBody),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.replaceThisDevice),
          ),
        ],
      ),
    );
  }

  Future<LinkedSyncDevice?> _linkedDevice({
    required SyncDeviceRegistry registry,
    required String? sourceDeviceId,
  }) async {
    final normalized = sourceDeviceId?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return registry.linkedDevice(normalized);
  }

  bool _canApplyAutomatically({
    required LinkedSyncDevice? linked,
    required BackupContentSummary current,
    required BackupSelection selection,
  }) {
    if (linked == null) return false;
    final currentModifiedAtUtc = current.localModifiedAtUtc;
    if (currentModifiedAtUtc == null) return false;
    final incomingCreatedAtUtc = selection.preview.manifest.createdAtUtc;
    return incomingCreatedAtUtc.isAfter(currentModifiedAtUtc);
  }

  Future<String?> _askTransferCode(_ReceiveBackupStrings strings) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.transferCodeTitle),
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

  String _friendlyError(Object error, _ReceiveBackupStrings strings) {
    if (error is BackupProtectionException) return strings.invalidCode;
    if (error is RestoreException) return strings.restoreError;
    if (error is FormatException) return strings.invalidQr;
    return strings.downloadError;
  }
}

class _ReceiveStatusPanel extends StatelessWidget {
  const _ReceiveStatusPanel({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle,
              color: isError ? scheme.onErrorContainer : scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _SyncRecommendationPanel extends StatelessWidget {
  const _SyncRecommendationPanel({
    required this.strings,
    required this.incomingCreatedAtUtc,
    required this.currentModifiedAtUtc,
    this.linked,
  });

  final _ReceiveBackupStrings strings;
  final DateTime incomingCreatedAtUtc;
  final DateTime? currentModifiedAtUtc;
  final LinkedSyncDevice? linked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recommendation = strings.recommendation(
      incomingCreatedAtUtc: incomingCreatedAtUtc,
      currentModifiedAtUtc: currentModifiedAtUtc,
      linked: linked,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sync_rounded, color: scheme.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                recommendation,
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryComparison extends StatelessWidget {
  const _SummaryComparison({
    required this.strings,
    required this.current,
    required this.incoming,
    required this.incomingCreatedAtUtc,
  });

  final _ReceiveBackupStrings strings;
  final BackupContentSummary current;
  final BackupContentSummary? incoming;
  final DateTime incomingCreatedAtUtc;

  @override
  Widget build(BuildContext context) {
    final incomingSummary = incoming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.comparisonTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _SummaryColumn(
          strings: strings,
          title: strings.thisDevice,
          subtitle: strings.modifiedLabel(current.localModifiedAtUtc),
          summary: current,
        ),
        const SizedBox(height: 10),
        _SummaryColumn(
          strings: strings,
          title: strings.receivedData,
          subtitle: strings.createdLabel(incomingCreatedAtUtc),
          summary: incomingSummary,
        ),
      ],
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.strings,
    required this.title,
    required this.subtitle,
    required this.summary,
  });

  final _ReceiveBackupStrings strings;
  final String title;
  final String subtitle;
  final BackupContentSummary? summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = summary;
    final details = value == null
        ? <String>[strings.summaryUnavailable]
        : <String>[
            if (value.schoolNames.isNotEmpty) value.schoolNames.join(', '),
            strings.studentCount(value.students),
            strings.attendanceCount(value.attendanceDays),
            strings.projectCount(value.projects),
            strings.activityCount(value.activities),
            strings.evaluationCount(value.evaluations),
            strings.literacyCount(value.literacyAssessments),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final item in details) Text('• $item'),
          ],
        ),
      ),
    );
  }
}

final class _ReceiveBackupStrings {
  const _ReceiveBackupStrings(this.spanish);

  factory _ReceiveBackupStrings.of(BuildContext context) =>
      _ReceiveBackupStrings(
        Localizations.localeOf(context).languageCode.toLowerCase() != 'en',
      );

  final bool spanish;

  String get title => spanish ? 'Recibir por Wi-Fi' : 'Receive over Wi-Fi';
  String get heading => spanish
      ? 'Recibe datos de otro dispositivo'
      : 'Receive data from another device';
  String get instructions => spanish
      ? 'En el otro dispositivo abre Preferencias → Enviar a otro dispositivo por Wi-Fi. Escanea el QR; AulaRaíz tomará la liga y el código automáticamente.'
      : 'On the other device, open Preferences → Send to another device over Wi-Fi. Scan the QR; AulaRaíz will read the link and code automatically.';
  String get manualInstructions => spanish
      ? 'En el otro dispositivo abre Preferencias → Enviar a otro dispositivo por Wi-Fi. Copia la liga de descarga y el código de transferencia para pegarlos aquí.'
      : 'On the other device, open Preferences → Send to another device over Wi-Fi. Copy the download link and transfer code, then paste them here.';
  String get manualOnlyBody => spanish
      ? 'Este equipo recibirá los datos pegando la liga de descarga. Si el otro dispositivo muestra un QR, también muestra la misma liga debajo del código.'
      : 'This device receives data by pasting the download link. If the other device shows a QR, it also shows the same link below the code.';
  String get processing => spanish
      ? 'Recibiendo y sincronizando datos…'
      : 'Receiving and syncing data…';
  String get manualLink =>
      spanish ? 'Pegar liga manualmente' : 'Paste link manually';
  String get manualLinkTitle =>
      spanish ? 'Pegar liga de transferencia' : 'Paste transfer link';
  String get manualLinkLabel => spanish
      ? 'Liga mostrada en el otro dispositivo'
      : 'Link shown on the other device';
  String get transferCodeTitle =>
      spanish ? 'Código de transferencia' : 'Transfer code';
  String get transferCodeLabel =>
      spanish ? 'Código de transferencia' : 'Transfer code';
  String get transferCodeHelper => spanish
      ? 'Es el código que aparece debajo del QR o junto a la liga.'
      : 'This is the code shown under the QR or next to the link.';
  String get cancel => spanish ? 'Cancelar' : 'Cancel';
  String get continueAction => spanish ? 'Continuar' : 'Continue';
  String get preparedTitle =>
      spanish ? 'Restauración preparada' : 'Restore prepared';
  String get preparedBody => spanish
      ? 'Cierra completamente AulaRaíz y vuelve a abrirla para aplicar los datos recibidos.'
      : 'Fully close AulaRaíz and open it again to apply the received data.';
  String get autoPreparedBody => spanish
      ? 'El dispositivo ya estaba vinculado y los datos recibidos parecen más recientes. Cierra completamente AulaRaíz y vuelve a abrirla para aplicarlos.'
      : 'The device was already linked and the received data appears newer. Fully close AulaRaíz and open it again to apply it.';
  String get understood => spanish ? 'Entendido' : 'Got it';
  String get prepared => spanish
      ? 'La copia se recibió y quedó preparada para el próximo arranque.'
      : 'The backup was received and staged for the next launch.';
  String get autoPrepared => spanish
      ? 'Sincronización preparada automáticamente.'
      : 'Sync was prepared automatically.';
  String get syncAppliedTitle =>
      spanish ? 'Sincronización aplicada' : 'Sync applied';
  String syncApplied(int changed, RecordLevelSyncSummary? returnedSummary) {
    final returned = returnedSummary;
    if (returned == null) {
      return spanish
          ? 'Sincronización aplicada: $changed cambios incorporados.'
          : 'Sync applied: $changed changes merged.';
    }
    return spanish
        ? 'Sincronización bidireccional aplicada: $changed cambios aquí y ${returned.changed} en el otro dispositivo.'
        : 'Two-way sync applied: $changed changes here and ${returned.changed} on the other device.';
  }

  String syncAppliedBody(
    RecordLevelSyncSummary summary,
    RecordLevelSyncSummary? returnedSummary,
  ) {
    final returned = returnedSummary;
    final returnedText = returned == null
        ? (spanish
              ? 'El otro dispositivo no confirmó devolución automática; si necesitas actualizarlo, repite la sincronización desde allá.'
              : 'The other device did not confirm the automatic return; repeat sync from there if you need to update it.')
        : (spanish
              ? 'Además, el otro dispositivo incorporó ${returned.inserted} nuevos y actualizó ${returned.updated}.'
              : 'Also, the other device inserted ${returned.inserted} and updated ${returned.updated}.');
    return spanish
        ? 'AulaRaíz comparó los registros recibidos con este dispositivo. '
              'Agregó ${summary.inserted}, actualizó ${summary.updated} '
              'y omitió ${summary.skipped} que no eran más recientes. '
              '$returnedText No necesitas reiniciar.'
        : 'AulaRaíz compared the received records with this device. '
              'It inserted ${summary.inserted}, updated ${summary.updated}, '
              'and skipped ${summary.skipped} that were not newer. '
              '$returnedText No restart is required.';
  }

  String get confirmTitle =>
      spanish ? 'Confirmar sincronización' : 'Confirm sync';
  String get comparisonTitle =>
      spanish ? 'Comparación antes de aplicar' : 'Comparison before applying';
  String get thisDevice => spanish ? 'Este dispositivo' : 'This device';
  String get receivedData => spanish ? 'Datos recibidos' : 'Received data';
  String get unknownDevice =>
      spanish ? 'Dispositivo AulaRaíz' : 'AulaRaíz device';
  String get confirmBody => spanish
      ? 'Si continúas, este dispositivo se actualizará con los datos recibidos al reiniciar AulaRaíz. Hazlo solo si esos datos son los que quieres conservar aquí.'
      : 'If you continue, this device will be updated with the received data when AulaRaíz restarts. Continue only if those are the data you want to keep here.';
  String get replaceThisDevice =>
      spanish ? 'Actualizar este dispositivo' : 'Update this device';
  String createdLabel(DateTime value) =>
      spanish ? 'Creado: ${_dateTime(value)}' : 'Created: ${_dateTime(value)}';
  String modifiedLabel(DateTime? value) => value == null
      ? (spanish
            ? 'Última modificación: no disponible'
            : 'Last modified: unavailable')
      : (spanish
            ? 'Última modificación: ${_dateTime(value)}'
            : 'Last modified: ${_dateTime(value)}');
  String recommendation({
    required DateTime incomingCreatedAtUtc,
    required DateTime? currentModifiedAtUtc,
    LinkedSyncDevice? linked,
  }) {
    final linkedDevice = linked;
    if (linkedDevice != null &&
        currentModifiedAtUtc != null &&
        incomingCreatedAtUtc.isAfter(currentModifiedAtUtc)) {
      return spanish
          ? 'Dispositivo vinculado: ${linkedDevice.name}. Los datos recibidos parecen más recientes, así que AulaRaíz puede preparar la actualización automáticamente.'
          : 'Linked device: ${linkedDevice.name}. The received data appears newer, so AulaRaíz can prepare the update automatically.';
    }
    if (linkedDevice != null &&
        currentModifiedAtUtc != null &&
        !incomingCreatedAtUtc.isAfter(currentModifiedAtUtc)) {
      return spanish
          ? 'Dispositivo vinculado: ${linkedDevice.name}. Este dispositivo parece tener cambios iguales o más recientes; revisa antes de actualizar.'
          : 'Linked device: ${linkedDevice.name}. This device appears to have equal or newer changes; review before updating.';
    }
    if (currentModifiedAtUtc == null) {
      return spanish
          ? 'No se pudo determinar cuál dispositivo es más reciente. Revisa el resumen antes de actualizar.'
          : 'AulaRaíz could not determine which device is newer. Review the summary before updating.';
    }
    if (incomingCreatedAtUtc.isAfter(currentModifiedAtUtc)) {
      return spanish
          ? 'Los datos recibidos parecen más recientes que este dispositivo.'
          : 'The received data appears newer than this device.';
    }
    if (incomingCreatedAtUtc.isBefore(currentModifiedAtUtc)) {
      return spanish
          ? 'Este dispositivo parece tener cambios más recientes. Ten cuidado: actualizarlo podría reemplazarlos.'
          : 'This device appears to have newer changes. Be careful: updating may replace them.';
    }
    return spanish
        ? 'Ambos dispositivos parecen tener la misma fecha de actualización.'
        : 'Both devices appear to have the same update time.';
  }

  String get invalidCode => spanish
      ? 'No se pudo abrir la copia. Revisa que el código de transferencia sea correcto.'
      : 'The backup could not be opened. Check that the transfer code is correct.';
  String get invalidQr => spanish
      ? 'El QR no contiene una liga válida de transferencia.'
      : 'The QR does not contain a valid transfer link.';
  String get restoreError => spanish
      ? 'La copia se descargó, pero no se pudo preparar la restauración.'
      : 'The backup was downloaded, but the restore could not be prepared.';
  String get downloadError => spanish
      ? 'No se pudo descargar la copia. Verifica que ambos dispositivos estén en la misma red Wi-Fi y que la ventana de envío siga abierta.'
      : 'The backup could not be downloaded. Check that both devices are on the same Wi-Fi network and the sending window is still open.';
  String get summaryUnavailable => spanish
      ? 'No se pudo leer el resumen.'
      : 'The summary could not be read.';
  String studentCount(int count) =>
      spanish ? '$count alumnos' : '$count students';
  String attendanceCount(int count) =>
      spanish ? '$count días de asistencia' : '$count attendance days';
  String projectCount(int count) =>
      spanish ? '$count proyectos' : '$count projects';
  String activityCount(int count) =>
      spanish ? '$count actividades' : '$count activities';
  String evaluationCount(int count) =>
      spanish ? '$count evaluaciones' : '$count evaluations';
  String literacyCount(int count) => spanish
      ? '$count registros de lectoescritura'
      : '$count literacy records';

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

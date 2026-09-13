import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/infrastructure/backup/backup_restore_gateway.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WindowTitleService.setTitle('AulaRaíz · ${strings.title}');
    });

    return Scaffold(
      appBar: AppBar(title: Text(strings.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              strings.heading,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(strings.instructions),
            const SizedBox(height: 18),
            AspectRatio(
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
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
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
    final gateway = context.read<BackupRestoreGateway>();
    final code = await _askTransferCode(strings);
    if (!mounted || code == null) return;

    setState(() {
      _processing = true;
      _status = null;
      _statusIsError = false;
    });
    try {
      await _scannerController.stop();
      await gateway.receivePortableBackupFromUrl(
        downloadUrl: url,
        transferCode: code,
      );
      if (!mounted) return;
      setState(() {
        _status = strings.prepared;
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
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _friendlyError(error, strings);
        _statusIsError = true;
      });
      await _scannerController.start();
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
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

final class _ReceiveBackupStrings {
  const _ReceiveBackupStrings(this.spanish);

  factory _ReceiveBackupStrings.of(BuildContext context) =>
      _ReceiveBackupStrings(
        Localizations.localeOf(context).languageCode.toLowerCase() != 'en',
      );

  final bool spanish;

  String get title => spanish ? 'Recibir desde PC' : 'Receive from PC';
  String get heading =>
      spanish ? 'Escanea el QR de tu computadora' : 'Scan your computer QR';
  String get instructions => spanish
      ? 'En tu PC abre Preferencias → Vincular celular por Wi-Fi. Mantén esa ventana abierta mientras este celular recibe la copia.'
      : 'On your PC, open Preferences → Link phone over Wi-Fi. Keep that window open while this phone receives the backup.';
  String get processing =>
      spanish ? 'Recibiendo y validando copia…' : 'Receiving and validating…';
  String get manualLink =>
      spanish ? 'Pegar liga manualmente' : 'Paste link manually';
  String get manualLinkTitle =>
      spanish ? 'Pegar liga de transferencia' : 'Paste transfer link';
  String get manualLinkLabel =>
      spanish ? 'Liga mostrada en la PC' : 'Link shown on the PC';
  String get transferCodeTitle =>
      spanish ? 'Código de transferencia' : 'Transfer code';
  String get transferCodeLabel =>
      spanish ? 'Código de transferencia' : 'Transfer code';
  String get transferCodeHelper => spanish
      ? 'Es el código que aparece debajo del QR en la PC.'
      : 'This is the code shown under the QR on the PC.';
  String get cancel => spanish ? 'Cancelar' : 'Cancel';
  String get continueAction => spanish ? 'Continuar' : 'Continue';
  String get preparedTitle =>
      spanish ? 'Restauración preparada' : 'Restore prepared';
  String get preparedBody => spanish
      ? 'Cierra completamente AulaRaíz y vuelve a abrirla para aplicar los datos recibidos.'
      : 'Fully close AulaRaíz and open it again to apply the received data.';
  String get understood => spanish ? 'Entendido' : 'Got it';
  String get prepared => spanish
      ? 'La copia se recibió y quedó preparada para el próximo arranque.'
      : 'The backup was received and staged for the next launch.';
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
      ? 'No se pudo descargar la copia. Verifica que ambos dispositivos estén en la misma red Wi-Fi y que la ventana siga abierta en la PC.'
      : 'The backup could not be downloaded. Check that both devices are on the same Wi-Fi network and the PC window is still open.';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/open_vts_radius.dart';
import '../../../core/theme/open_vts_spacing.dart';
import '../../../shared/helpers/mobile_text.dart';
import '../../../shared/helpers/toast_helper.dart';
import '../services/server_url_configuration.dart';

class ApiBaseUrlScannerScreen extends ConsumerStatefulWidget {
  const ApiBaseUrlScannerScreen({super.key});

  @override
  ConsumerState<ApiBaseUrlScannerScreen> createState() =>
      _ApiBaseUrlScannerScreenState();
}

class _ApiBaseUrlScannerScreenState
    extends ConsumerState<ApiBaseUrlScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionTimeoutMs: 700,
  );

  bool _working = false;
  String? _error;
  String? _lastInvalidCode;

  bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_working) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      final url = apiBaseUrlFromQrCode(raw);
      if (url == null) {
        if (_lastInvalidCode != raw || _error == null) {
          _lastInvalidCode = raw;
          setState(() => _error = context.mobileText(
                'This QR code does not contain a valid server URL.',
              ));
        }
        continue;
      }
      unawaited(_saveScannedUrl(url));
      return;
    }
  }

  Future<void> _saveScannedUrl(String url) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    await _stopCamera();
    try {
      await configureApiBaseUrl(ref, url);
      if (!mounted) return;
      ToastHelper.showSuccess(context.mobileText('Server URL updated'));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error =
            context.mobileText('Unable to save this server URL. Try again.');
      });
      await _startCamera();
    }
  }

  Future<void> _openManual() async {
    if (_working) return;
    final previousUrl = ref.read(apiBaseUrlProvider);
    setState(() {
      _working = true;
      _error = null;
    });
    await _stopCamera();
    if (!mounted) return;

    final saved = await context.push<bool>(RoutePaths.apiBaseUrlSettings);
    if (!mounted) return;
    if (saved == true || ref.read(apiBaseUrlProvider) != previousUrl) {
      context.pop();
      return;
    }

    setState(() => _working = false);
    await _startCamera();
  }

  Future<void> _stopCamera() async {
    if (!_cameraSupported) return;
    try {
      await _scanner.stop();
    } catch (_) {
      // Manual configuration remains available if the camera is unavailable.
    }
  }

  Future<void> _startCamera() async {
    if (!_cameraSupported || !mounted) return;
    try {
      await _scanner.start();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.mobileText(
              'Camera unavailable. Configure the server URL manually.',
            ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.mobileText('Scan Server QR Code'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OpenVtsSpacing.md),
          child: Column(
            children: [
              Text(
                context.mobileText(
                  'Point your camera at a QR code containing the full API URL.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: OpenVtsSpacing.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(OpenVtsRadius.lg),
                  child: _cameraSupported
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: _scanner,
                              onDetect: _onDetect,
                              errorBuilder: (context, error) => ColoredBox(
                                color: colors.surface,
                                child: Center(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(OpenVtsSpacing.lg),
                                    child: Text(
                                      context.mobileText(
                                        'Camera unavailable. Check camera permission or configure manually.',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: FractionallySizedBox(
                                    widthFactor: 0.72,
                                    heightFactor: 0.72,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          OpenVtsRadius.lg,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_working)
                              const ColoredBox(
                                color: Colors.black54,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : ColoredBox(
                          color: colors.surface,
                          child: Center(
                            child: Text(
                              context.mobileText(
                                'Camera scanning is unavailable on this device.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: OpenVtsSpacing.sm),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              ],
              const SizedBox(height: OpenVtsSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _working ? null : _openManual,
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(context.mobileText('Configure manually')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

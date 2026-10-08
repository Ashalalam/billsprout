import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_theme.dart';

/// Native (Android / iOS / Windows) camera scanner implementation.
Widget buildNativeScanner(BuildContext context) {
  return _NativeScannerWidget(
    onScanned: (code) => Navigator.of(context).pop(code),
    onCancel: () => Navigator.of(context).pop(null),
  );
}

class _NativeScannerWidget extends StatefulWidget {
  final void Function(String) onScanned;
  final VoidCallback onCancel;

  const _NativeScannerWidget({
    required this.onScanned,
    required this.onCancel,
  });

  @override
  State<_NativeScannerWidget> createState() => _NativeScannerWidgetState();
}

class _NativeScannerWidgetState extends State<_NativeScannerWidget> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    setState(() => _scanned = true);
    Future.delayed(
      const Duration(milliseconds: 400),
      () => widget.onScanned(barcode!.rawValue!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 400,
          height: 500,
          child: Stack(
            children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              // Scan frame
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 240,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          _scanned ? AppTheme.successGreen : Colors.white,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _scanned
                      ? const Center(
                          child: Icon(Icons.check_circle,
                              color: AppTheme.successGreen, size: 48))
                      : null,
                ),
              ),
              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scan Barcode / QR Code',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.flash_on,
                                color: Colors.white),
                            onPressed: () => _controller.toggleTorch(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white),
                            onPressed: widget.onCancel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom hint
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Text(
                    'Align barcode within the frame.\nSupports EAN-13, QR, DataMatrix, Code128.',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

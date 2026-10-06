import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Service for scanning and decoding medicine barcodes
class BarcodeScannerService {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  /// Scan barcode from an image file path
  /// Returns the barcode value if found, null otherwise
  Future<String?> scanBarcodeFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        return null;
      }

      // Return the first barcode's raw value
      return barcodes.first.rawValue;
    } catch (e) {
      throw Exception('Failed to scan barcode: $e');
    }
  }

  /// Scan barcode and return detailed information
  Future<BarcodeInfo?> scanBarcodeDetails(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        return null;
      }

      final barcode = barcodes.first;
      return BarcodeInfo(
        rawValue: barcode.rawValue ?? '',
        format: _getBarcodeFormatName(barcode.format),
        type: _getBarcodeTypeName(barcode.type),
      );
    } catch (e) {
      throw Exception('Failed to scan barcode details: $e');
    }
  }

  /// Get barcode format name
  String _getBarcodeFormatName(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.code128:
        return 'CODE_128';
      case BarcodeFormat.code39:
        return 'CODE_39';
      case BarcodeFormat.code93:
        return 'CODE_93';
      case BarcodeFormat.codabar:
        return 'CODABAR';
      case BarcodeFormat.dataMatrix:
        return 'DATA_MATRIX';
      case BarcodeFormat.ean13:
        return 'EAN_13';
      case BarcodeFormat.ean8:
        return 'EAN_8';
      case BarcodeFormat.itf:
        return 'ITF';
      case BarcodeFormat.qrCode:
        return 'QR_CODE';
      case BarcodeFormat.upca:
        return 'UPC_A';
      case BarcodeFormat.upce:
        return 'UPC_E';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.aztec:
        return 'AZTEC';
      default:
        return 'UNKNOWN';
    }
  }

  /// Get barcode type name
  String _getBarcodeTypeName(BarcodeType type) {
    switch (type) {
      case BarcodeType.product:
        return 'PRODUCT';
      case BarcodeType.text:
        return 'TEXT';
      case BarcodeType.url:
        return 'URL';
      case BarcodeType.contactInfo:
        return 'CONTACT';
      case BarcodeType.email:
        return 'EMAIL';
      case BarcodeType.phone:
        return 'PHONE';
      case BarcodeType.sms:
        return 'SMS';
      case BarcodeType.wifi:
        return 'WIFI';
      case BarcodeType.geoCoordinates:
        return 'GEO';
      case BarcodeType.calendarEvent:
        return 'CALENDAR';
      case BarcodeType.driverLicense:
        return 'DRIVER_LICENSE';
      default:
        return 'UNKNOWN';
    }
  }

  /// Dispose of resources
  void dispose() {
    _barcodeScanner.close();
  }
}

/// Information extracted from a barcode
class BarcodeInfo {
  final String rawValue;
  final String format;
  final String type;

  BarcodeInfo({
    required this.rawValue,
    required this.format,
    required this.type,
  });

  @override
  String toString() {
    return 'BarcodeInfo(rawValue: $rawValue, format: $format, type: $type)';
  }
}

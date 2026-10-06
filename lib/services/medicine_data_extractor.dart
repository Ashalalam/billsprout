import '../models/product_model.dart';

/// Service for extracting and validating medicine data for ProductModel
class MedicineDataExtractor {
  /// Convert scanned OCR/barcode data to a format suitable for pre-filling ProductModel
  /// Only returns fields that were successfully extracted - leaves others null
  Map<String, dynamic> extractProductData(Map<String, dynamic> scannedData) {
    final Map<String, dynamic> productData = {};

    // Extract medicine name
    if (scannedData.containsKey('name') && scannedData['name'] != null) {
      final name = scannedData['name'].toString().trim();
      if (name.isNotEmpty) {
        productData['name'] = name;
      }
    }

    // Extract generic/salt name
    if (scannedData.containsKey('genericSalt') && scannedData['genericSalt'] != null) {
      final generic = scannedData['genericSalt'].toString().trim();
      if (generic.isNotEmpty) {
        productData['genericSalt'] = generic;
      }
    }

    // Extract barcode
    if (scannedData.containsKey('barcode') && scannedData['barcode'] != null) {
      final barcode = scannedData['barcode'].toString().trim();
      if (barcode.isNotEmpty) {
        productData['barcode'] = barcode;
      }
    }

    // Extract manufacturer
    if (scannedData.containsKey('manufacturer') && scannedData['manufacturer'] != null) {
      final manufacturer = scannedData['manufacturer'].toString().trim();
      if (manufacturer.isNotEmpty) {
        productData['manufacturer'] = manufacturer;
      }
    }

    // Extract and infer dose type from quantity string
    if (scannedData.containsKey('quantity') && scannedData['quantity'] != null) {
      final doseType = _inferDoseType(scannedData['quantity'].toString());
      if (doseType != null) {
        productData['doseType'] = doseType;
      }
    }

    // Extract batch information if available
    final batchInfo = _extractBatchInfo(scannedData);
    if (batchInfo.isNotEmpty) {
      productData['batchInfo'] = batchInfo;
    }

    // Store raw OCR text for reference
    if (scannedData.containsKey('rawText')) {
      productData['rawText'] = scannedData['rawText'];
    }

    return productData;
  }

  /// Extract batch information from scanned data
  Map<String, dynamic> _extractBatchInfo(Map<String, dynamic> scannedData) {
    final Map<String, dynamic> batchInfo = {};

    // Batch number
    if (scannedData.containsKey('batchNumber') && scannedData['batchNumber'] != null) {
      final batchNumber = scannedData['batchNumber'].toString().trim();
      if (batchNumber.isNotEmpty) {
        batchInfo['batchNumber'] = batchNumber;
      }
    }

    // MRP
    if (scannedData.containsKey('mrp') && scannedData['mrp'] != null) {
      final mrp = scannedData['mrp'];
      if (mrp is double && mrp > 0) {
        batchInfo['mrp'] = mrp;
      } else if (mrp is int && mrp > 0) {
        batchInfo['mrp'] = mrp.toDouble();
      } else if (mrp is String) {
        final parsed = double.tryParse(mrp);
        if (parsed != null && parsed > 0) {
          batchInfo['mrp'] = parsed;
        }
      }
    }

    // Expiry date
    if (scannedData.containsKey('expiryDate') && scannedData['expiryDate'] != null) {
      final expiryDate = scannedData['expiryDate'].toString().trim();
      if (expiryDate.isNotEmpty && _isValidDate(expiryDate)) {
        batchInfo['expiryDate'] = expiryDate;
      }
    }

    // Manufacturing date
    if (scannedData.containsKey('mfgDate') && scannedData['mfgDate'] != null) {
      final mfgDate = scannedData['mfgDate'].toString().trim();
      if (mfgDate.isNotEmpty && _isValidDate(mfgDate)) {
        batchInfo['mfgDate'] = mfgDate;
      }
    }

    return batchInfo;
  }

  /// Infer dose type from quantity string
  /// Examples: "10 Tablets" -> DoseType.tablet, "100ml Syrup" -> DoseType.syrup
  DoseType? _inferDoseType(String quantity) {
    final lowerQuantity = quantity.toLowerCase();

    if (lowerQuantity.contains('tablet')) {
      return DoseType.tablet;
    } else if (lowerQuantity.contains('capsule')) {
      return DoseType.capsule;
    } else if (lowerQuantity.contains('syrup') || lowerQuantity.contains('ml')) {
      return DoseType.syrup;
    } else if (lowerQuantity.contains('injection') || lowerQuantity.contains('vial')) {
      return DoseType.injection;
    } else if (lowerQuantity.contains('drop')) {
      return DoseType.drops;
    } else if (lowerQuantity.contains('cream')) {
      return DoseType.cream;
    } else if (lowerQuantity.contains('ointment')) {
      return DoseType.ointment;
    } else if (lowerQuantity.contains('gel')) {
      return DoseType.gel;
    } else if (lowerQuantity.contains('powder') || lowerQuantity.contains('sachet')) {
      return DoseType.powder;
    } else if (lowerQuantity.contains('inhaler')) {
      return DoseType.inhaler;
    } else if (lowerQuantity.contains('patch')) {
      return DoseType.patch;
    } else if (lowerQuantity.contains('suppository')) {
      return DoseType.suppository;
    }

    return null;
  }

  /// Validate date format (MM/YYYY or MM-YYYY)
  bool _isValidDate(String date) {
    // Check format MM/YYYY or MM-YYYY
    final datePattern = RegExp(r'^\d{2}[/-]\d{4}$');
    if (!datePattern.hasMatch(date)) {
      return false;
    }

    // Parse and validate month/year
    final parts = date.split(RegExp(r'[/-]'));
    if (parts.length != 2) return false;

    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);

    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    if (year < 2000 || year > 2100) return false;

    return true;
  }

  /// Validate extracted data before pre-filling
  /// Returns validation errors as a list of messages
  List<String> validateExtractedData(Map<String, dynamic> productData) {
    final List<String> errors = [];

    // Check if at least one field was extracted
    if (productData.isEmpty || 
        (productData.length == 1 && productData.containsKey('rawText'))) {
      errors.add('No medicine information could be extracted from the image');
      return errors;
    }

    // Validate MRP if present
    if (productData.containsKey('batchInfo')) {
      final batchInfo = productData['batchInfo'] as Map<String, dynamic>;
      if (batchInfo.containsKey('mrp')) {
        final mrp = batchInfo['mrp'];
        if (mrp is double && mrp <= 0) {
          errors.add('Invalid MRP: must be greater than 0');
        }
      }

      // Validate expiry date is in the future
      if (batchInfo.containsKey('expiryDate')) {
        final expiryDate = batchInfo['expiryDate'] as String;
        if (!_isExpiryDateValid(expiryDate)) {
          errors.add('Expiry date appears to be in the past');
        }
      }
    }

    return errors;
  }

  /// Check if expiry date is in the future
  bool _isExpiryDateValid(String expiryDate) {
    try {
      final parts = expiryDate.split(RegExp(r'[/-]'));
      if (parts.length != 2) return false;

      final month = int.parse(parts[0]);
      final year = int.parse(parts[1]);

      final expiryDateTime = DateTime(year, month, 1);
      final now = DateTime.now();

      // Consider valid if expiry is in current month or future
      return expiryDateTime.isAfter(DateTime(now.year, now.month, 1)) ||
             (expiryDateTime.year == now.year && expiryDateTime.month == now.month);
    } catch (e) {
      return false;
    }
  }

  /// Format extracted data for display in review dialog
  Map<String, String> formatForDisplay(Map<String, dynamic> productData) {
    final Map<String, String> displayData = {};

    if (productData.containsKey('name')) {
      displayData['Medicine Name'] = productData['name'].toString();
    }

    if (productData.containsKey('genericSalt')) {
      displayData['Generic/Salt'] = productData['genericSalt'].toString();
    }

    if (productData.containsKey('barcode')) {
      displayData['Barcode'] = productData['barcode'].toString();
    }

    if (productData.containsKey('manufacturer')) {
      displayData['Manufacturer'] = productData['manufacturer'].toString();
    }

    if (productData.containsKey('doseType')) {
      final doseType = productData['doseType'] as DoseType;
      displayData['Dose Type'] = doseType.label;
    }

    if (productData.containsKey('batchInfo')) {
      final batchInfo = productData['batchInfo'] as Map<String, dynamic>;
      
      if (batchInfo.containsKey('batchNumber')) {
        displayData['Batch Number'] = batchInfo['batchNumber'].toString();
      }

      if (batchInfo.containsKey('mrp')) {
        displayData['MRP'] = '₹${batchInfo['mrp'].toStringAsFixed(2)}';
      }

      if (batchInfo.containsKey('expiryDate')) {
        displayData['Expiry Date'] = batchInfo['expiryDate'].toString();
      }

      if (batchInfo.containsKey('mfgDate')) {
        displayData['Manufacturing Date'] = batchInfo['mfgDate'].toString();
      }
    }

    return displayData;
  }
}

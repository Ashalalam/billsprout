import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for extracting medicine information from images using OCR
class MedicineOCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extract text from an image file
  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      return recognizedText.text;
    } catch (e) {
      throw Exception('Failed to extract text from image: $e');
    }
  }

  /// Extract structured medicine data from OCR text
  /// Returns a map with extracted fields (only fields that were confidently detected)
  Future<Map<String, dynamic>> extractMedicineData(String imagePath) async {
    try {
      final text = await extractTextFromImage(imagePath);
      return _parseMedicineInfo(text);
    } catch (e) {
      throw Exception('Failed to extract medicine data: $e');
    }
  }

  /// Parse medicine information from OCR text
  /// Only returns fields that can be confidently identified - leaves others null
  Map<String, dynamic> _parseMedicineInfo(String text) {
    final Map<String, dynamic> extractedData = {};
    final lines = text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

    // Extract MRP (Maximum Retail Price)
    final mrpMatch = _extractMRP(text);
    if (mrpMatch != null) {
      extractedData['mrp'] = mrpMatch;
    }

    // Extract Batch Number
    final batchMatch = _extractBatchNumber(text);
    if (batchMatch != null) {
      extractedData['batchNumber'] = batchMatch;
    }

    // Extract Expiry Date
    final expiryMatch = _extractExpiryDate(text);
    if (expiryMatch != null) {
      extractedData['expiryDate'] = expiryMatch;
    }

    // Extract Manufacturing Date
    final mfgMatch = _extractManufacturingDate(text);
    if (mfgMatch != null) {
      extractedData['mfgDate'] = mfgMatch;
    }

    // Extract Manufacturer
    final manufacturerMatch = _extractManufacturer(text);
    if (manufacturerMatch != null) {
      extractedData['manufacturer'] = manufacturerMatch;
    }

    // Extract Medicine Name (usually the first prominent line)
    final medicineNameMatch = _extractMedicineName(lines);
    if (medicineNameMatch != null) {
      extractedData['name'] = medicineNameMatch;
    }

    // Extract Generic/Salt Name
    final genericMatch = _extractGenericName(text);
    if (genericMatch != null) {
      extractedData['genericSalt'] = genericMatch;
    }

    // Extract Quantity/Pack Size
    final quantityMatch = _extractQuantity(text);
    if (quantityMatch != null) {
      extractedData['quantity'] = quantityMatch;
    }

    // Add raw text for user reference
    extractedData['rawText'] = text;

    return extractedData;
  }

  /// Extract MRP from text
  /// Patterns: MRP Rs. 150, MRP: 150.00, MRP ₹150, Rs.150/-
  double? _extractMRP(String text) {
    final patterns = [
      RegExp(r'MRP[:\s]*(?:Rs\.?|₹)\s*(\d+(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'(?:Rs\.?|₹)\s*(\d+(?:\.\d{2})?)\s*/-', caseSensitive: false),
      RegExp(r'MRP[:\s]*(\d+(?:\.\d{2})?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final priceStr = match.group(1);
        if (priceStr != null) {
          return double.tryParse(priceStr);
        }
      }
    }
    return null;
  }

  /// Extract Batch Number from text
  /// Patterns: Batch: ABC123, Batch No: 12345, B.No: XYZ789
  String? _extractBatchNumber(String text) {
    final patterns = [
      RegExp(r'Batch\s*(?:No\.?|Number)?[:\s]*([A-Z0-9]+)', caseSensitive: false),
      RegExp(r'B\.?\s*No\.?[:\s]*([A-Z0-9]+)', caseSensitive: false),
      RegExp(r'Lot\s*(?:No\.?)?[:\s]*([A-Z0-9]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final batch = match.group(1);
        if (batch != null && batch.length >= 3) {
          return batch;
        }
      }
    }
    return null;
  }

  /// Extract Expiry Date from text
  /// Patterns: EXP: 12/2025, Exp. Date: 12-2025, Best Before: 12/25
  String? _extractExpiryDate(String text) {
    final patterns = [
      RegExp(r'EXP(?:IRY)?(?:\s*DATE)?[:\s]*(\d{2}[-/]\d{4})', caseSensitive: false),
      RegExp(r'EXP(?:IRY)?[:\s]*(\d{2}[-/]\d{2,4})', caseSensitive: false),
      RegExp(r'Best\s*Before[:\s]*(\d{2}[-/]\d{4})', caseSensitive: false),
      RegExp(r'Use\s*Before[:\s]*(\d{2}[-/]\d{4})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final dateStr = match.group(1);
        if (dateStr != null) {
          return _normalizeDate(dateStr);
        }
      }
    }
    return null;
  }

  /// Extract Manufacturing Date from text
  /// Patterns: MFG: 01/2024, Mfg. Date: 01-2024
  String? _extractManufacturingDate(String text) {
    final patterns = [
      RegExp(r'MFG(?:\s*DATE)?[:\s]*(\d{2}[-/]\d{4})', caseSensitive: false),
      RegExp(r'Manufactured[:\s]*(\d{2}[-/]\d{4})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final dateStr = match.group(1);
        if (dateStr != null) {
          return _normalizeDate(dateStr);
        }
      }
    }
    return null;
  }

  /// Extract Manufacturer name
  /// Usually appears with keywords like "Mfg by", "Manufactured by"
  String? _extractManufacturer(String text) {
    final patterns = [
      RegExp(r'(?:Mfg\.?|Manufactured)\s*by[:\s]*([A-Za-z\s&.,]+?)(?=\n|Ltd|Pvt|Inc|\d)', caseSensitive: false),
      RegExp(r'Marketed\s*by[:\s]*([A-Za-z\s&.,]+?)(?=\n|Ltd|Pvt|Inc|\d)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final mfr = match.group(1)?.trim();
        if (mfr != null && mfr.length > 2) {
          return mfr;
        }
      }
    }
    return null;
  }

  /// Extract medicine name (usually first prominent line, often in larger text)
  String? _extractMedicineName(List<String> lines) {
    if (lines.isEmpty) return null;

    // Look for medicine name in first few lines
    // Skip very short lines (likely labels) and very long lines (likely descriptions)
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i];
      // Medicine names are typically 3-50 characters
      if (line.length >= 3 && line.length <= 50) {
        // Skip common label words
        final lowerLine = line.toLowerCase();
        if (!lowerLine.startsWith('mfg') &&
            !lowerLine.startsWith('exp') &&
            !lowerLine.startsWith('batch') &&
            !lowerLine.startsWith('mrp')) {
          return line;
        }
      }
    }
    return null;
  }

  /// Extract generic/salt name
  /// Often in parentheses or after the medicine name
  String? _extractGenericName(String text) {
    // Look for text in parentheses which often contains generic name
    final parenthesesMatch = RegExp(r'\(([A-Za-z\s,]+)\)').firstMatch(text);
    if (parenthesesMatch != null) {
      final generic = parenthesesMatch.group(1)?.trim();
      if (generic != null && generic.length > 2 && generic.length < 100) {
        return generic;
      }
    }

    // Look for "contains" or "composition"
    final compositionMatch = RegExp(
      r'(?:Contains|Composition)[:\s]*([A-Za-z\s,]+?)(?=\n|MRP|Batch|Exp)',
      caseSensitive: false,
    ).firstMatch(text);
    if (compositionMatch != null) {
      final composition = compositionMatch.group(1)?.trim();
      if (composition != null && composition.length > 2) {
        return composition;
      }
    }

    return null;
  }

  /// Extract quantity/pack size
  /// Patterns: 10 Tablets, 100ml, 30 Capsules
  String? _extractQuantity(String text) {
    final patterns = [
      RegExp(r'(\d+)\s*(Tablets?|Capsules?|ml|Syrup|Injections?)', caseSensitive: false),
      RegExp(r'Pack\s*(?:of|size)?[:\s]*(\d+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0)?.trim();
      }
    }
    return null;
  }

  /// Normalize date format to MM/YYYY
  String _normalizeDate(String dateStr) {
    // Convert MM-YYYY or MM/YY to MM/YYYY
    final parts = dateStr.split(RegExp(r'[-/]'));
    if (parts.length == 2) {
      final month = parts[0].padLeft(2, '0');
      var year = parts[1];
      // Convert 2-digit year to 4-digit
      if (year.length == 2) {
        final currentYear = DateTime.now().year;
        final century = (currentYear ~/ 100) * 100;
        final twoDigitYear = int.tryParse(year) ?? 0;
        year = (century + twoDigitYear).toString();
      }
      return '$month/$year';
    }
    return dateStr;
  }

  /// Dispose of resources
  void dispose() {
    _textRecognizer.close();
  }
}

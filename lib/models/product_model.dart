import 'batch_model.dart';
import 'selling_unit_model.dart';

// ── Dose type enum ────────────────────────────────────────────────────────────
enum DoseType {
  tablet,
  capsule,
  syrup,
  injection,
  drops,
  cream,
  ointment,
  gel,
  powder,
  inhaler,
  patch,
  suppository,
  other,
}

extension DoseTypeX on DoseType {
  String get label {
    switch (this) {
      case DoseType.tablet:     return 'Tablet';
      case DoseType.capsule:    return 'Capsule';
      case DoseType.syrup:      return 'Syrup';
      case DoseType.injection:  return 'Injection';
      case DoseType.drops:      return 'Drops / Eye-Ear-Nasal';
      case DoseType.cream:      return 'Cream';
      case DoseType.ointment:   return 'Ointment';
      case DoseType.gel:        return 'Gel';
      case DoseType.powder:     return 'Powder / Sachet';
      case DoseType.inhaler:    return 'Inhaler';
      case DoseType.patch:      return 'Transdermal Patch';
      case DoseType.suppository:return 'Suppository';
      case DoseType.other:      return 'Other';
    }
  }

  /// Unit label shown on POS (e.g. "strip", "bottle", "vial")
  String get unitLabel {
    switch (this) {
      case DoseType.tablet:
      case DoseType.capsule:    return 'strip';
      case DoseType.syrup:
      case DoseType.drops:      return 'bottle';
      case DoseType.injection:  return 'vial';
      case DoseType.cream:
      case DoseType.ointment:
      case DoseType.gel:        return 'tube';
      case DoseType.powder:     return 'sachet';
      case DoseType.inhaler:    return 'unit';
      case DoseType.patch:      return 'patch';
      case DoseType.suppository:return 'unit';
      default:                  return 'unit';
    }
  }

  /// Whether this dose type supports strip/blister pack configuration
  bool get isStripBased =>
      this == DoseType.tablet || this == DoseType.capsule;

  /// Whether this dose type is a liquid (volume-based)
  bool get isLiquid =>
      this == DoseType.syrup ||
      this == DoseType.drops ||
      this == DoseType.injection;
}

// ── Standard packaging configs ────────────────────────────────────────────────
class PackagingConfig {
  /// Human-readable label  e.g. "10×10", "10×15", "60ml"
  final String label;
  /// Units per strip / pack  (tablets in a blister, ml volume, etc.)
  final int unitsPerStrip;
  /// Strips per box (1 for liquids/injections)
  final int stripsPerBox;

  const PackagingConfig({
    required this.label,
    required this.unitsPerStrip,
    this.stripsPerBox = 1,
  });

  /// Total units in one box
  int get unitsPerBox => unitsPerStrip * stripsPerBox;

  /// Display: "10 strips × 10 tabs" or "60 ml"
  String get displayText {
    if (stripsPerBox > 1) {
      return '$stripsPerBox strips × $unitsPerStrip units';
    }
    return '$unitsPerStrip $label';
  }

  // Common presets
  static const PackagingConfig strip10x10 =
      PackagingConfig(label: '10×10', unitsPerStrip: 10, stripsPerBox: 10);
  static const PackagingConfig strip10x15 =
      PackagingConfig(label: '10×15', unitsPerStrip: 15, stripsPerBox: 10);
  static const PackagingConfig strip10x6 =
      PackagingConfig(label: '10×6', unitsPerStrip: 6, stripsPerBox: 10);
  static const PackagingConfig strip6x10 =
      PackagingConfig(label: '6×10', unitsPerStrip: 10, stripsPerBox: 6);
  static const PackagingConfig strip4x10 =
      PackagingConfig(label: '4×10', unitsPerStrip: 10, stripsPerBox: 4);
  static const PackagingConfig strip1x10 =
      PackagingConfig(label: '1×10', unitsPerStrip: 10, stripsPerBox: 1);
  static const PackagingConfig strip1x15 =
      PackagingConfig(label: '1×15', unitsPerStrip: 15, stripsPerBox: 1);
  static const PackagingConfig strip1x6 =
      PackagingConfig(label: '1×6', unitsPerStrip: 6, stripsPerBox: 1);
  // New common pharmacy pack sizes
  static const PackagingConfig strip1x20 =
      PackagingConfig(label: '1×20', unitsPerStrip: 20, stripsPerBox: 1);
  static const PackagingConfig strip2x5 =
      PackagingConfig(label: '2×5', unitsPerStrip: 5, stripsPerBox: 2);
  static const PackagingConfig strip2x10 =
      PackagingConfig(label: '2×10', unitsPerStrip: 10, stripsPerBox: 2);
  static const PackagingConfig strip3x10 =
      PackagingConfig(label: '3×10', unitsPerStrip: 10, stripsPerBox: 3);
  static const PackagingConfig strip4x15 =
      PackagingConfig(label: '4×15', unitsPerStrip: 15, stripsPerBox: 4);
  static const PackagingConfig strip5x10 =
      PackagingConfig(label: '5×10', unitsPerStrip: 10, stripsPerBox: 5);
  static const PackagingConfig strip10x20 =
      PackagingConfig(label: '10×20', unitsPerStrip: 20, stripsPerBox: 10);
  static const PackagingConfig bottle30ml =
      PackagingConfig(label: '30 ml', unitsPerStrip: 30);
  static const PackagingConfig bottle60ml =
      PackagingConfig(label: '60 ml', unitsPerStrip: 60);
  static const PackagingConfig bottle100ml =
      PackagingConfig(label: '100 ml', unitsPerStrip: 100);
  static const PackagingConfig bottle200ml =
      PackagingConfig(label: '200 ml', unitsPerStrip: 200);
  static const PackagingConfig vial1ml =
      PackagingConfig(label: '1 ml vial', unitsPerStrip: 1);
  static const PackagingConfig vial2ml =
      PackagingConfig(label: '2 ml vial', unitsPerStrip: 2);
  static const PackagingConfig vial10ml =
      PackagingConfig(label: '10 ml vial', unitsPerStrip: 10);

  static List<PackagingConfig> presetsFor(DoseType dose) {
    switch (dose) {
      case DoseType.tablet:
      case DoseType.capsule:
        return [
          strip10x10, strip10x15, strip10x6, strip6x10,
          strip4x10, strip1x10, strip1x15, strip1x6,
          strip1x20, strip2x5, strip2x10, strip3x10,
          strip4x15, strip5x10, strip10x20,
          PackagingConfig(label: 'Custom', unitsPerStrip: 10),
        ];
      case DoseType.syrup:
      case DoseType.drops:
        return [bottle30ml, bottle60ml, bottle100ml, bottle200ml,
            PackagingConfig(label: 'Custom', unitsPerStrip: 0)];
      case DoseType.injection:
        return [vial1ml, vial2ml, vial10ml,
            PackagingConfig(label: 'Custom', unitsPerStrip: 0)];
      default:
        return [PackagingConfig(label: 'Unit', unitsPerStrip: 1)];
    }
  }
}

// ── Product model ─────────────────────────────────────────────────────────────
class ProductModel {
  final String id;
  final String name;
  final String genericSalt;
  final String barcode;
  final String hsnCode;
  final double taxPercent;
  final String manufacturer;
  final bool isScheduleH;
  final bool isScheduleH1;
  final bool isNarcotic;
  final List<BatchModel> batches;

  // ── New pharma fields ──────────────────────────────────────────────────────
  final DoseType doseType;
  final PackagingConfig? packagingConfig;
  
  // ── Loose-unit sales configuration ─────────────────────────────────────────
  final bool allowLooseSales;
  final int baseUnitsPerPack;        // Authoritative conversion: tablets per strip, ml per bottle
  final double? pricePerBaseUnit;    // Per-tablet, per-capsule, or per-ml price
  final SellingUnit minSaleUnit;     // Minimum unit that can be sold
  final SellingUnit baseUnit;        // Base unit for inventory (tablet, capsule, ml, gm)

  ProductModel({
    required this.id,
    required this.name,
    required this.genericSalt,
    required this.barcode,
    required this.hsnCode,
    required this.taxPercent,
    required this.manufacturer,
    this.isScheduleH  = false,
    this.isScheduleH1 = false,
    this.isNarcotic   = false,
    required this.batches,
    this.doseType      = DoseType.tablet,
    this.packagingConfig,
    this.allowLooseSales = false,
    this.baseUnitsPerPack = 10,
    this.pricePerBaseUnit,
    this.minSaleUnit = SellingUnit.strip,
    this.baseUnit = SellingUnit.tablet,
  });

  bool get requiresPharmacistPin => isScheduleH || isScheduleH1 || isNarcotic;

  // ── FEFO: first non-expired in-stock batch by earliest expiry ─────────────
  BatchModel? get fefoBatch {
    final valid = batches
        .where((b) => b.stockCount > 0 && !b.isExpired)
        .toList()
      ..sort((a, b) => a.expDate.compareTo(b.expDate));
    return valid.isEmpty ? null : valid.first;
  }

  // ── Near expiry batches (≤ 90 days) ──────────────────────────────────────
  List<BatchModel> get nearExpiryBatches =>
      batches.where((b) => b.isNearExpiry && !b.isExpired).toList()
        ..sort((a, b) => a.expDate.compareTo(b.expDate));

  int get totalStock => batches.fold(0, (s, b) => s + b.stockCount);
  
  /// Format total stock display across all batches
  String get formattedTotalStock {
    final packLabel = doseType.unitLabel;
    final unitLabel = baseUnit.label;
    
    int totalPacks = 0;
    int totalLoose = 0;
    
    for (final batch in batches) {
      totalPacks += batch.stockCount;
      totalLoose += batch.looseUnits;
    }
    
    // Normalize: convert excess loose units to packs
    if (totalLoose >= baseUnitsPerPack) {
      final extraPacks = totalLoose ~/ baseUnitsPerPack;
      totalPacks += extraPacks;
      totalLoose = totalLoose % baseUnitsPerPack;
    }
    
    final totalUnits = (totalPacks * baseUnitsPerPack) + totalLoose;
    
    if (totalUnits == 0) {
      return 'Out of stock';
    }
    
    if (totalLoose == 0) {
      return '$totalPacks $packLabel${totalPacks != 1 ? 's' : ''}';
    } else if (totalPacks == 0) {
      return '$totalLoose $unitLabel${totalLoose != 1 ? 's' : ''}';
    } else {
      return '$totalPacks $packLabel${totalPacks != 1 ? 's' : ''} + $totalLoose $unitLabel${totalLoose != 1 ? 's' : ''}';
    }
  }
  
  /// Total available units (packs converted to units + loose units)
  int get totalAvailableUnits => batches.fold(
    0, 
    (sum, b) => sum + b.totalAvailableUnits(baseUnitsPerPack)
  );
  
  /// Total loose units across all batches
  int get totalLooseUnits => batches.fold(0, (sum, b) => sum + b.looseUnits);
  
  /// Get available selling units for this product
  List<SellingUnit> get availableSellingUnits {
    if (!allowLooseSales) {
      // Only pack-level sales allowed
      return [minSaleUnit];
    }
    
    // Both pack and loose units can be sold
    return [minSaleUnit, baseUnit];
  }

  /// Packaging label for POS display e.g. "10×10 strips"
  String get packagingLabel {
    if (packagingConfig == null) return doseType.unitLabel;
    if (doseType.isStripBased && packagingConfig!.stripsPerBox > 1) {
      return '${packagingConfig!.label} (${packagingConfig!.stripsPerBox} strips)';
    }
    return packagingConfig!.label;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'genericSalt': genericSalt,
        'barcode': barcode,
        'hsnCode': hsnCode,
        'taxPercent': taxPercent,
        'manufacturer': manufacturer,
        'isScheduleH': isScheduleH,
        'isScheduleH1': isScheduleH1,
        'isNarcotic': isNarcotic,
        'batches': batches.map((b) => b.toJson()).toList(),
        'doseType': doseType.name,
        'packagingLabel': packagingConfig?.label,
        'packagingUnitsPerStrip': packagingConfig?.unitsPerStrip,
        'packagingStripsPerBox': packagingConfig?.stripsPerBox,
        'allowLooseSales': allowLooseSales,
        'baseUnitsPerPack': baseUnitsPerPack,
        'pricePerBaseUnit': pricePerBaseUnit,
        'minSaleUnit': minSaleUnit.dbValue,
        'baseUnit': baseUnit.dbValue,
      };

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'],
        name: json['name'],
        genericSalt: json['genericSalt'],
        barcode: json['barcode'],
        hsnCode: json['hsnCode'],
        taxPercent: (json['taxPercent'] as num).toDouble(),
        manufacturer: json['manufacturer'],
        isScheduleH: json['isScheduleH'] ?? false,
        isScheduleH1: json['isScheduleH1'] ?? false,
        isNarcotic: json['isNarcotic'] ?? false,
        batches: (json['batches'] as List)
            .map((b) => BatchModel.fromJson(b))
            .toList(),
        doseType: DoseType.values.firstWhere(
          (e) => e.name == (json['doseType'] ?? 'tablet'),
          orElse: () => DoseType.tablet,
        ),
        packagingConfig: json['packagingLabel'] != null
            ? PackagingConfig(
                label: json['packagingLabel'],
                unitsPerStrip: json['packagingUnitsPerStrip'] ?? 10,
                stripsPerBox: json['packagingStripsPerBox'] ?? 1,
              )
            : null,
        allowLooseSales: json['allowLooseSales'] ?? false,
        baseUnitsPerPack: json['baseUnitsPerPack'] ?? json['packagingUnitsPerStrip'] ?? 10,
        pricePerBaseUnit: json['pricePerBaseUnit'] != null 
            ? (json['pricePerBaseUnit'] as num).toDouble() 
            : null,
        minSaleUnit: json['minSaleUnit'] != null 
            ? _parseSellingUnit(json['minSaleUnit']) 
            : SellingUnit.strip,
        baseUnit: json['baseUnit'] != null 
            ? _parseSellingUnit(json['baseUnit']) 
            : SellingUnit.tablet,
      );
  
  /// Helper to parse SellingUnit from string
  static SellingUnit _parseSellingUnit(dynamic value) {
    if (value == null) return SellingUnit.unit;
    final str = value.toString().toLowerCase();
    return SellingUnit.values.firstWhere(
      (e) => e.name == str,
      orElse: () => SellingUnit.unit,
    );
  }
}

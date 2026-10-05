// =====================================================
// Selling Unit & Compound Quantity Models
// =====================================================
// Models for flexible unit-based medicine billing
// Supports selling by strips, tablets, capsules, ml, etc.

/// Selling unit types for pharmacy products
enum SellingUnit {
  /// Complete strip/blister pack
  strip,
  
  /// Individual tablet
  tablet,
  
  /// Individual capsule
  capsule,
  
  /// Milliliters (for liquids)
  ml,
  
  /// Grams (for creams, ointments)
  gm,
  
  /// Complete bottle
  bottle,
  
  /// Complete vial (injection)
  vial,
  
  /// Complete tube (cream/ointment)
  tube,
  
  /// Individual sachet
  sachet,
  
  /// Complete box/pack
  pack,
  
  /// Generic unit (inhaler, patch, etc.)
  unit,
}

extension SellingUnitX on SellingUnit {
  /// Display label for UI
  String get label {
    switch (this) {
      case SellingUnit.strip:   return 'Strip';
      case SellingUnit.tablet:  return 'Tablet';
      case SellingUnit.capsule: return 'Capsule';
      case SellingUnit.ml:      return 'ml';
      case SellingUnit.gm:      return 'gm';
      case SellingUnit.bottle:  return 'Bottle';
      case SellingUnit.vial:    return 'Vial';
      case SellingUnit.tube:    return 'Tube';
      case SellingUnit.sachet:  return 'Sachet';
      case SellingUnit.pack:    return 'Pack';
      case SellingUnit.unit:    return 'Unit';
    }
  }
  
  /// Plural form for display
  String get pluralLabel {
    switch (this) {
      case SellingUnit.strip:   return 'Strips';
      case SellingUnit.tablet:  return 'Tablets';
      case SellingUnit.capsule: return 'Capsules';
      case SellingUnit.ml:      return 'ml';
      case SellingUnit.gm:      return 'gm';
      case SellingUnit.bottle:  return 'Bottles';
      case SellingUnit.vial:    return 'Vials';
      case SellingUnit.tube:    return 'Tubes';
      case SellingUnit.sachet:  return 'Sachets';
      case SellingUnit.pack:    return 'Packs';
      case SellingUnit.unit:    return 'Units';
    }
  }
  
  /// Whether this is a pack-level unit (strip, bottle, box, etc.)
  bool get isPackUnit => this == SellingUnit.strip || 
                        this == SellingUnit.bottle || 
                        this == SellingUnit.vial ||
                        this == SellingUnit.tube ||
                        this == SellingUnit.pack;
  
  /// Whether this is a loose/individual unit (tablet, capsule, ml, gm)
  bool get isLooseUnit => this == SellingUnit.tablet || 
                         this == SellingUnit.capsule || 
                         this == SellingUnit.ml ||
                         this == SellingUnit.gm;
  
  /// Database value (lowercase string)
  String get dbValue => name;
  
  /// Parse from database value
  static SellingUnit fromDbValue(String value) {
    return SellingUnit.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SellingUnit.unit,
    );
  }
}

/// Compound quantity for sales (pack + loose units)
/// Example: 2 strips + 5 tablets
class SaleQuantity {
  /// Number of complete packs (strips, bottles, boxes)
  final int packQuantity;
  
  /// Number of loose units (tablets, capsules, ml)
  final int looseQuantity;
  
  /// Selling unit type
  final SellingUnit sellingUnit;
  
  /// Number of free packs (schemes/promotions)
  final int freePackQuantity;
  
  /// Number of free loose units
  final int freeLooseQuantity;
  
  const SaleQuantity({
    this.packQuantity = 0,
    this.looseQuantity = 0,
    required this.sellingUnit,
    this.freePackQuantity = 0,
    this.freeLooseQuantity = 0,
  });
  
  /// Create from pack quantity only (existing behavior)
  factory SaleQuantity.packsOnly({
    required int quantity,
    required SellingUnit sellingUnit,
    int freeQuantity = 0,
  }) {
    return SaleQuantity(
      packQuantity: quantity,
      looseQuantity: 0,
      sellingUnit: sellingUnit,
      freePackQuantity: freeQuantity,
      freeLooseQuantity: 0,
    );
  }
  
  /// Create from loose quantity only
  factory SaleQuantity.looseOnly({
    required int quantity,
    required SellingUnit sellingUnit,
  }) {
    return SaleQuantity(
      packQuantity: 0,
      looseQuantity: quantity,
      sellingUnit: sellingUnit,
      freePackQuantity: 0,
      freeLooseQuantity: 0,
    );
  }
  
  /// Create mixed quantity (packs + loose)
  factory SaleQuantity.mixed({
    required int packs,
    required int loose,
    required SellingUnit sellingUnit,
    int freePacks = 0,
    int freeLoose = 0,
  }) {
    return SaleQuantity(
      packQuantity: packs,
      looseQuantity: loose,
      sellingUnit: sellingUnit,
      freePackQuantity: freePacks,
      freeLooseQuantity: freeLoose,
    );
  }
  
  /// Total paid quantity (packs + loose, excluding free)
  int get totalPaidQuantity => packQuantity + looseQuantity;
  
  /// Total free quantity (free packs + free loose)
  int get totalFreeQuantity => freePackQuantity + freeLooseQuantity;
  
  /// Total quantity (paid + free)
  int get totalQuantity => totalPaidQuantity + totalFreeQuantity;
  
  /// Whether this includes any loose units
  bool get hasLooseUnits => looseQuantity > 0 || freeLooseQuantity > 0;
  
  /// Whether this includes any pack units
  bool get hasPackUnits => packQuantity > 0 || freePackQuantity > 0;
  
  /// Whether this is a mixed sale (both packs and loose)
  bool get isMixedSale => hasPackUnits && hasLooseUnits;
  
  /// Whether this sale has any free items
  bool get hasFreeItems => totalFreeQuantity > 0;
  
  /// Convert to total base units (for stock deduction calculation)
  /// baseUnitsPerPack: number of tablets/capsules/ml per strip/bottle
  int toTotalBaseUnits(int baseUnitsPerPack) {
    final paidBaseUnits = (packQuantity * baseUnitsPerPack) + looseQuantity;
    final freeBaseUnits = (freePackQuantity * baseUnitsPerPack) + freeLooseQuantity;
    return paidBaseUnits + freeBaseUnits;
  }
  
  /// Display text for invoice/cart
  /// Examples:
  /// - "2 Strips" (pack only)
  /// - "5 Tablets" (loose only)
  /// - "1 Strip + 3 Tablets" (mixed)
  /// - "2 Strips + 5 Tablets (+ 2 free)" (mixed with free items)
  String displayText({bool showFree = true}) {
    final parts = <String>[];
    
    // Add pack quantity
    if (packQuantity > 0) {
      parts.add('$packQuantity ${packQuantity == 1 ? sellingUnit.label : sellingUnit.pluralLabel}');
    }
    
    // Add loose quantity
    if (looseQuantity > 0) {
      final looseUnit = _getLooseUnitForDisplay();
      final looseLabel = looseQuantity == 1 ? looseUnit.label : looseUnit.pluralLabel;
      parts.add('$looseQuantity $looseLabel');
    }
    
    String result = parts.join(' + ');
    
    // Add free quantity if present
    if (showFree && hasFreeItems) {
      result += ' (+ $totalFreeQuantity free)';
    }
    
    return result.isNotEmpty ? result : '0';
  }
  
  /// Compact display for small UI elements
  /// Examples: "2×Strip", "5×Tab", "1×Strip+3×Tab"
  String compactDisplay() {
    final parts = <String>[];
    
    if (packQuantity > 0) {
      parts.add('$packQuantity×${_abbreviate(sellingUnit)}');
    }
    
    if (looseQuantity > 0) {
      final looseUnit = _getLooseUnitForDisplay();
      parts.add('$looseQuantity×${_abbreviate(looseUnit)}');
    }
    
    return parts.join('+');
  }
  
  /// Get the appropriate loose unit for display based on selling unit
  SellingUnit _getLooseUnitForDisplay() {
    switch (sellingUnit) {
      case SellingUnit.strip:
      case SellingUnit.tablet:
        return SellingUnit.tablet;
      case SellingUnit.capsule:
        return SellingUnit.capsule;
      case SellingUnit.bottle:
      case SellingUnit.ml:
        return SellingUnit.ml;
      case SellingUnit.tube:
      case SellingUnit.gm:
        return SellingUnit.gm;
      default:
        return SellingUnit.unit;
    }
  }
  
  /// Abbreviate unit for compact display
  String _abbreviate(SellingUnit unit) {
    switch (unit) {
      case SellingUnit.strip:   return 'Strip';
      case SellingUnit.tablet:  return 'Tab';
      case SellingUnit.capsule: return 'Cap';
      case SellingUnit.ml:      return 'ml';
      case SellingUnit.gm:      return 'gm';
      case SellingUnit.bottle:  return 'Btl';
      case SellingUnit.vial:    return 'Vial';
      case SellingUnit.tube:    return 'Tube';
      case SellingUnit.sachet:  return 'Sach';
      case SellingUnit.pack:    return 'Pack';
      case SellingUnit.unit:    return 'Unit';
    }
  }
  
  /// Create a copy with modified values
  SaleQuantity copyWith({
    int? packQuantity,
    int? looseQuantity,
    SellingUnit? sellingUnit,
    int? freePackQuantity,
    int? freeLooseQuantity,
  }) {
    return SaleQuantity(
      packQuantity: packQuantity ?? this.packQuantity,
      looseQuantity: looseQuantity ?? this.looseQuantity,
      sellingUnit: sellingUnit ?? this.sellingUnit,
      freePackQuantity: freePackQuantity ?? this.freePackQuantity,
      freeLooseQuantity: freeLooseQuantity ?? this.freeLooseQuantity,
    );
  }
  
  /// Convert to JSON for API/database
  Map<String, dynamic> toJson() => {
    'packQuantity': packQuantity,
    'looseQuantity': looseQuantity,
    'sellingUnit': sellingUnit.dbValue,
    'freePackQuantity': freePackQuantity,
    'freeLooseQuantity': freeLooseQuantity,
  };
  
  /// Parse from JSON
  factory SaleQuantity.fromJson(Map<String, dynamic> json) {
    return SaleQuantity(
      packQuantity: json['packQuantity'] ?? 0,
      looseQuantity: json['looseQuantity'] ?? 0,
      sellingUnit: _parseSellingUnit(json['sellingUnit']),
      freePackQuantity: json['freePackQuantity'] ?? 0,
      freeLooseQuantity: json['freeLooseQuantity'] ?? 0,
    );
  }
  
  /// Helper to parse SellingUnit from string
  static SellingUnit _parseSellingUnit(dynamic value) {
    if (value == null) return SellingUnit.unit;
    final str = value.toString().toLowerCase();
    return SellingUnit.values.firstWhere(
      (e) => e.name == str,
      orElse: () => SellingUnit.unit,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleQuantity &&
          runtimeType == other.runtimeType &&
          packQuantity == other.packQuantity &&
          looseQuantity == other.looseQuantity &&
          sellingUnit == other.sellingUnit &&
          freePackQuantity == other.freePackQuantity &&
          freeLooseQuantity == other.freeLooseQuantity;
  
  @override
  int get hashCode =>
      packQuantity.hashCode ^
      looseQuantity.hashCode ^
      sellingUnit.hashCode ^
      freePackQuantity.hashCode ^
      freeLooseQuantity.hashCode;
  
  @override
  String toString() => displayText();
}

/// Available stock representation (packs + loose units)
class AvailableStock {
  /// Number of complete packs available
  final int packStock;
  
  /// Number of loose units available (from opened packs)
  final int looseUnits;
  
  /// Base units per pack (for conversion)
  final int baseUnitsPerPack;
  
  const AvailableStock({
    required this.packStock,
    required this.looseUnits,
    required this.baseUnitsPerPack,
  });
  
  /// Total available units (packs converted to units + loose units)
  int get totalUnits => (packStock * baseUnitsPerPack) + looseUnits;
  
  /// Whether there is any stock available
  bool get hasStock => totalUnits > 0;
  
  /// Whether there are any loose units available
  bool get hasLooseUnits => looseUnits > 0;
  
  /// Display text (e.g., "8 strips + 5 tablets available")
  String displayText(SellingUnit packUnit, SellingUnit looseUnit) {
    if (packStock > 0 && looseUnits > 0) {
      return '$packStock ${packStock == 1 ? packUnit.label : packUnit.pluralLabel} + '
             '$looseUnits ${looseUnits == 1 ? looseUnit.label : looseUnit.pluralLabel}';
    } else if (packStock > 0) {
      return '$packStock ${packStock == 1 ? packUnit.label : packUnit.pluralLabel}';
    } else if (looseUnits > 0) {
      return '$looseUnits ${looseUnits == 1 ? looseUnit.label : looseUnit.pluralLabel}';
    } else {
      return 'Out of stock';
    }
  }
  
  /// Check if requested quantity can be fulfilled
  bool canFulfill(SaleQuantity quantity) {
    final requiredUnits = quantity.toTotalBaseUnits(baseUnitsPerPack);
    return totalUnits >= requiredUnits;
  }
  
  /// Calculate how many packs need to be opened for a loose-unit sale
  int packsToOpen(int requestedLooseUnits) {
    if (requestedLooseUnits <= looseUnits) {
      return 0; // Sufficient loose units available
    }
    
    final additionalUnitsNeeded = requestedLooseUnits - looseUnits;
    return (additionalUnitsNeeded / baseUnitsPerPack).ceil();
  }
}

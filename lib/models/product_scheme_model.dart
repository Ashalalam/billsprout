// =====================================================
// ProductScheme Model - Medicine-Level Scheme/Offer
// =====================================================
// Supports promotional schemes like "Buy 10 Get 1 Free"

import 'package:intl/intl.dart';

enum SchemeType {
  buyXGetYFree,
}

extension SchemeTypeX on SchemeType {
  String get value {
    switch (this) {
      case SchemeType.buyXGetYFree:
        return 'buy_x_get_y_free';
    }
  }

  String get label {
    switch (this) {
      case SchemeType.buyXGetYFree:
        return 'Buy X Get Y Free';
    }
  }

  static SchemeType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'buy_x_get_y_free':
        return SchemeType.buyXGetYFree;
      default:
        return SchemeType.buyXGetYFree;
    }
  }
}

enum SchemeUnit {
  strip,
  tablet,
  capsule,
  bottle,
  vial,
  tube,
  sachet,
  unit,
}

extension SchemeUnitX on SchemeUnit {
  String get value {
    switch (this) {
      case SchemeUnit.strip:
        return 'strip';
      case SchemeUnit.tablet:
        return 'tablet';
      case SchemeUnit.capsule:
        return 'capsule';
      case SchemeUnit.bottle:
        return 'bottle';
      case SchemeUnit.vial:
        return 'vial';
      case SchemeUnit.tube:
        return 'tube';
      case SchemeUnit.sachet:
        return 'sachet';
      case SchemeUnit.unit:
        return 'unit';
    }
  }

  String get label {
    switch (this) {
      case SchemeUnit.strip:
        return 'Strip';
      case SchemeUnit.tablet:
        return 'Tablet';
      case SchemeUnit.capsule:
        return 'Capsule';
      case SchemeUnit.bottle:
        return 'Bottle';
      case SchemeUnit.vial:
        return 'Vial';
      case SchemeUnit.tube:
        return 'Tube';
      case SchemeUnit.sachet:
        return 'Sachet';
      case SchemeUnit.unit:
        return 'Unit';
    }
  }

  static SchemeUnit fromString(String value) {
    switch (value.toLowerCase()) {
      case 'strip':
        return SchemeUnit.strip;
      case 'tablet':
        return SchemeUnit.tablet;
      case 'capsule':
        return SchemeUnit.capsule;
      case 'bottle':
        return SchemeUnit.bottle;
      case 'vial':
        return SchemeUnit.vial;
      case 'tube':
        return SchemeUnit.tube;
      case 'sachet':
        return SchemeUnit.sachet;
      case 'unit':
        return SchemeUnit.unit;
      default:
        return SchemeUnit.strip;
    }
  }
}

class ProductScheme {
  final String id;
  final String productId;
  final String tenantId;
  final String? branchId;
  final SchemeType schemeType;
  final int buyQuantity;
  final int freeQuantity;
  final SchemeUnit schemeUnit;
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductScheme({
    required this.id,
    required this.productId,
    required this.tenantId,
    this.branchId,
    this.schemeType = SchemeType.buyXGetYFree,
    required this.buyQuantity,
    required this.freeQuantity,
    required this.schemeUnit,
    required this.validFrom,
    this.validUntil,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if the scheme is currently valid (active and within date range)
  bool get isCurrentlyValid {
    if (!isActive) return false;

    final now = DateTime.now();
    
    // Check if started
    if (now.isBefore(validFrom)) return false;
    
    // Check if expired (if validUntil is set)
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    
    return true;
  }

  /// Calculate free quantity based on paid quantity
  /// Example: Buy 10 Get 1 Free, paid = 25 → free = 2
  int calculateFreeQuantity(int paidQuantity) {
    if (!isCurrentlyValid) return 0;
    if (paidQuantity < buyQuantity) return 0;

    final completeSchemes = paidQuantity ~/ buyQuantity;
    return completeSchemes * freeQuantity;
  }

  /// Total quantity (paid + free) for a given paid quantity
  int calculateTotalQuantity(int paidQuantity) {
    return paidQuantity + calculateFreeQuantity(paidQuantity);
  }

  /// Display format: "Buy 10 Get 1 Free"
  String get displayText {
    final unitLabel = schemeUnit.label.toLowerCase();
    final unitPlural = buyQuantity > 1 || freeQuantity > 1 ? '${unitLabel}s' : unitLabel;
    return 'Buy $buyQuantity Get $freeQuantity Free ($unitPlural)';
  }

  /// Short display: "10+1"
  String get shortDisplay {
    return '$buyQuantity+$freeQuantity';
  }

  /// Full display with validity
  String get fullDisplay {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final validityText = validUntil != null
        ? 'Valid: ${dateFormat.format(validFrom)} - ${dateFormat.format(validUntil!)}'
        : 'Valid from: ${dateFormat.format(validFrom)}';
    return '$displayText\n$validityText';
  }

  /// Status badge text
  String get statusText {
    if (!isActive) return 'Inactive';
    if (!isCurrentlyValid) return 'Expired';
    return 'Active';
  }

  /// Copy with
  ProductScheme copyWith({
    String? id,
    String? productId,
    String? tenantId,
    String? branchId,
    SchemeType? schemeType,
    int? buyQuantity,
    int? freeQuantity,
    SchemeUnit? schemeUnit,
    DateTime? validFrom,
    DateTime? validUntil,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductScheme(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      schemeType: schemeType ?? this.schemeType,
      buyQuantity: buyQuantity ?? this.buyQuantity,
      freeQuantity: freeQuantity ?? this.freeQuantity,
      schemeUnit: schemeUnit ?? this.schemeUnit,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'scheme_type': schemeType.value,
      'buy_quantity': buyQuantity,
      'free_quantity': freeQuantity,
      'scheme_unit': schemeUnit.value,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (Supabase response)
  factory ProductScheme.fromJson(Map<String, dynamic> json) {
    return ProductScheme(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String?,
      schemeType: SchemeTypeX.fromString(json['scheme_type'] as String),
      buyQuantity: json['buy_quantity'] as int,
      freeQuantity: json['free_quantity'] as int,
      schemeUnit: SchemeUnitX.fromString(json['scheme_unit'] as String),
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() => displayText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductScheme &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

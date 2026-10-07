class BatchModel {
  final String id;
  final String batchNumber;
  final DateTime mfgDate;
  final DateTime expDate;
  final double mrp;
  final double purchasePrice;
  final double wholesalePrice;
  final double ptrPrice;        // Price to Retailer
  int stockCount;               // Number of complete packs (strips, bottles, etc.)
  int looseUnits;              // Loose units from opened packs (tablets, capsules, ml)
  final String rackLocation;

  BatchModel({
    required this.id,
    required this.batchNumber,
    required this.mfgDate,
    required this.expDate,
    required this.mrp,
    required this.purchasePrice,
    required this.wholesalePrice,
    this.ptrPrice = 0.0,
    required this.stockCount,
    this.looseUnits = 0,
    required this.rackLocation,
  });

  bool get isExpired => DateTime.now().isAfter(expDate);
  int  get daysUntilExpiry => expDate.difference(DateTime.now()).inDays;
  bool get isNearExpiry => daysUntilExpiry >= 0 && daysUntilExpiry <= 90;

  /// Urgency colour label for UI
  String get expiryStatus {
    if (isExpired)               return 'Expired';
    if (daysUntilExpiry <= 30)   return 'Critical (<30d)';
    if (daysUntilExpiry <= 60)   return 'Warning (<60d)';
    if (daysUntilExpiry <= 90)   return 'Near Expiry (<90d)';
    return 'OK';
  }

  /// Display-friendly expiry date (MM/YYYY format)
  String get expiryDate => '${expDate.month.toString().padLeft(2, '0')}/${expDate.year}';
  
  /// Get total available units given units per pack
  int totalAvailableUnits(int unitsPerPack) {
    return (stockCount * unitsPerPack) + looseUnits;
  }
  
  /// Format stock display: "100 strips" or "97 strips + 7 tablets"
  String formatStockDisplay(String packLabel, String unitLabel, int unitsPerPack) {
    final totalUnits = totalAvailableUnits(unitsPerPack);
    
    if (totalUnits == 0) {
      return 'Out of stock';
    }
    
    if (looseUnits == 0) {
      // Only complete packs
      return '$stockCount $packLabel${stockCount != 1 ? 's' : ''}';
    } else if (stockCount == 0) {
      // Only loose units
      return '$looseUnits $unitLabel${looseUnits != 1 ? 's' : ''}';
    } else {
      // Both packs and loose units
      return '$stockCount $packLabel${stockCount != 1 ? 's' : ''} + $looseUnits $unitLabel${looseUnits != 1 ? 's' : ''}';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchNumber': batchNumber,
        'mfgDate': mfgDate.toIso8601String(),
        'expDate': expDate.toIso8601String(),
        'expiryDate': expiryDate,
        'mrp': mrp,
        'purchasePrice': purchasePrice,
        'wholesalePrice': wholesalePrice,
        'ptrPrice': ptrPrice,
        'stockCount': stockCount,
        'looseUnits': looseUnits,
        'rackLocation': rackLocation,
      };

  factory BatchModel.fromJson(Map<String, dynamic> json) => BatchModel(
        id: json['id'],
        batchNumber: json['batchNumber'],
        mfgDate: DateTime.parse(json['mfgDate']),
        expDate: DateTime.parse(json['expDate']),
        mrp: (json['mrp'] as num).toDouble(),
        purchasePrice: (json['purchasePrice'] as num).toDouble(),
        wholesalePrice: (json['wholesalePrice'] as num).toDouble(),
        ptrPrice: (json['ptrPrice'] as num? ?? 0).toDouble(),
        stockCount: json['stockCount'],
        looseUnits: json['looseUnits'] ?? 0,
        rackLocation: json['rackLocation'],
      );
}

class BatchModel {
  final String id;
  final String batchNumber;
  final DateTime mfgDate;
  final DateTime expDate;
  final double mrp;
  final double purchasePrice;
  final double wholesalePrice;
  final double ptrPrice;        // Price to Retailer
  int stockCount;
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
        rackLocation: json['rackLocation'],
      );
}

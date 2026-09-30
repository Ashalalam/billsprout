class WholesaleCustomerModel {
  final String id;
  final String tenantId;
  final String businessName;
  final String contactPerson;
  final String phone;
  final String? email;
  final String? gstin;
  final String? drugLicenseNo;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final double creditLimit;
  final double outstandingAmount;
  final int creditPeriodDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  WholesaleCustomerModel({
    required this.id,
    required this.tenantId,
    required this.businessName,
    required this.contactPerson,
    required this.phone,
    this.email,
    this.gstin,
    this.drugLicenseNo,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.creditLimit = 0.0,
    this.outstandingAmount = 0.0,
    this.creditPeriodDays = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullAddress => '$address, $city, $state - $pincode';

  bool get hasCreditAvailable => creditLimit > outstandingAmount;
  double get availableCredit => creditLimit - outstandingAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'customer_name': businessName,
        'phone': phone,
        'email': email,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'gstin': gstin,
        'drug_license_no': drugLicenseNo,
        'customer_type': 'wholesale',
        'credit_limit': creditLimit,
        'outstanding_amount': outstandingAmount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory WholesaleCustomerModel.fromJson(Map<String, dynamic> json) =>
      WholesaleCustomerModel(
        id: json['id'],
        tenantId: json['tenant_id'],
        businessName: json['customer_name'],
        contactPerson: json['customer_name'], // May need separate field
        phone: json['phone'],
        email: json['email'],
        address: json['address'] ?? '',
        city: json['city'] ?? '',
        state: json['state'] ?? '',
        pincode: json['pincode'] ?? '',
        gstin: json['gstin'],
        drugLicenseNo: json['drug_license_no'],
        creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
        outstandingAmount:
            (json['outstanding_amount'] as num?)?.toDouble() ?? 0.0,
        creditPeriodDays: 0, // TODO: Add to database schema if needed
        isActive: true,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  WholesaleCustomerModel copyWith({
    String? id,
    String? tenantId,
    String? businessName,
    String? contactPerson,
    String? phone,
    String? email,
    String? gstin,
    String? drugLicenseNo,
    String? address,
    String? city,
    String? state,
    String? pincode,
    double? creditLimit,
    double? outstandingAmount,
    int? creditPeriodDays,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      WholesaleCustomerModel(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        businessName: businessName ?? this.businessName,
        contactPerson: contactPerson ?? this.contactPerson,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        gstin: gstin ?? this.gstin,
        drugLicenseNo: drugLicenseNo ?? this.drugLicenseNo,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        pincode: pincode ?? this.pincode,
        creditLimit: creditLimit ?? this.creditLimit,
        outstandingAmount: outstandingAmount ?? this.outstandingAmount,
        creditPeriodDays: creditPeriodDays ?? this.creditPeriodDays,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

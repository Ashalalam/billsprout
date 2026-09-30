class SupplierModel {
  final String id;
  final String tenantId;
  final String supplierName;
  final String contactPerson;
  final String email;
  final String phone;
  final String gstin;
  final String drugLicenseNo;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final int creditPeriodDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierModel({
    required this.id,
    required this.tenantId,
    required this.supplierName,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.gstin,
    required this.drugLicenseNo,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.creditPeriodDays = 30,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullAddress => '$address, $city, $state - $pincode';

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'supplier_name': supplierName,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'gstin': gstin,
        'drug_license_no': drugLicenseNo,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'credit_period_days': creditPeriodDays,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
        id: json['id'],
        tenantId: json['tenant_id'],
        supplierName: json['supplier_name'],
        contactPerson: json['contact_person'],
        email: json['email'],
        phone: json['phone'],
        gstin: json['gstin'],
        drugLicenseNo: json['drug_license_no'],
        address: json['address'],
        city: json['city'],
        state: json['state'],
        pincode: json['pincode'],
        creditPeriodDays: json['credit_period_days'] ?? 30,
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );
}

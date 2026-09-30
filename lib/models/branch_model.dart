class BranchModel {
  final String id;
  final String tenantId;
  final String branchName;
  final String branchCode;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String? gstin;
  final String drugLicenseNo;
  final DateTime? drugLicenseExpiry;
  final String phone;
  final String email;
  final String managerName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  BranchModel({
    required this.id,
    required this.tenantId,
    required this.branchName,
    required this.branchCode,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.gstin,
    required this.drugLicenseNo,
    this.drugLicenseExpiry,
    required this.phone,
    required this.email,
    required this.managerName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullAddress => '$address, $city, $state - $pincode';

  bool get isDrugLicenseExpired =>
      drugLicenseExpiry != null &&
      DateTime.now().isAfter(drugLicenseExpiry!);

  int get daysUntilLicenseExpiry =>
      drugLicenseExpiry?.difference(DateTime.now()).inDays ?? 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'branch_name': branchName,
        'branch_code': branchCode,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'gstin': gstin,
        'drug_license_no': drugLicenseNo,
        'drug_license_expiry': drugLicenseExpiry?.toIso8601String(),
        'phone': phone,
        'email': email,
        'manager_name': managerName,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory BranchModel.fromJson(Map<String, dynamic> json) => BranchModel(
        id: json['id'],
        tenantId: json['tenant_id'],
        branchName: json['branch_name'],
        branchCode: json['branch_code'],
        address: json['address'],
        city: json['city'],
        state: json['state'],
        pincode: json['pincode'],
        gstin: json['gstin'],
        drugLicenseNo: json['drug_license_no'],
        drugLicenseExpiry: json['drug_license_expiry'] != null
            ? DateTime.parse(json['drug_license_expiry'])
            : null,
        phone: json['phone'],
        email: json['email'],
        managerName: json['manager_name'],
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  BranchModel copyWith({
    String? id,
    String? tenantId,
    String? branchName,
    String? branchCode,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstin,
    String? drugLicenseNo,
    DateTime? drugLicenseExpiry,
    String? phone,
    String? email,
    String? managerName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      BranchModel(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        branchName: branchName ?? this.branchName,
        branchCode: branchCode ?? this.branchCode,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        pincode: pincode ?? this.pincode,
        gstin: gstin ?? this.gstin,
        drugLicenseNo: drugLicenseNo ?? this.drugLicenseNo,
        drugLicenseExpiry: drugLicenseExpiry ?? this.drugLicenseExpiry,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        managerName: managerName ?? this.managerName,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

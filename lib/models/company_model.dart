enum IndustryType {
  pharmacy,
  wholesale,
  retail,
  fmcg,
  manufacturing,
  hospitality,
}

extension IndustryTypeX on IndustryType {
  String get label {
    switch (this) {
      case IndustryType.pharmacy:
        return 'Pharmacy / Medical';
      case IndustryType.wholesale:
        return 'Wholesale Distribution';
      case IndustryType.retail:
        return 'Retail Supermarket';
      case IndustryType.fmcg:
        return 'FMCG & Manufacturing';
      case IndustryType.manufacturing:
        return 'Manufacturing';
      case IndustryType.hospitality:
        return 'Restaurant & Hospitality';
    }
  }
}

enum BusinessMode {
  retail,
  wholesale,
  both,
}

extension BusinessModeX on BusinessMode {
  String get label {
    switch (this) {
      case BusinessMode.retail:
        return 'Retail';
      case BusinessMode.wholesale:
        return 'Wholesale';
      case BusinessMode.both:
        return 'Retail + Wholesale';
    }
  }
}

class CompanyModel {
  final String id;
  final String businessName;
  final String ownerName;
  final String email;
  final String phone;
  final String gstin;
  final String drugLicenseNo;
  final DateTime? drugLicenseExpiry;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String? logoUrl;
  final IndustryType industryType;
  final BusinessMode businessMode;
  final String subscriptionPlan;
  final String subscriptionStatus; // active, inactive, trial, expired
  final int maxBranches;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyModel({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.gstin,
    required this.drugLicenseNo,
    this.drugLicenseExpiry,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.logoUrl,
    this.industryType = IndustryType.pharmacy,
    this.businessMode = BusinessMode.retail,
    this.subscriptionPlan = 'Basic',
    this.subscriptionStatus = 'active',
    this.maxBranches = 1,
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
        'business_name': businessName,
        'owner_name': ownerName,
        'email': email,
        'phone': phone,
        'gstin': gstin,
        'drug_license_no': drugLicenseNo,
        'drug_license_expiry': drugLicenseExpiry?.toIso8601String(),
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'logo_url': logoUrl,
        'industry_type': industryType.name,
        'business_mode': businessMode.name,
        'subscription_plan': subscriptionPlan,
        'subscription_status': subscriptionStatus,
        'max_branches': maxBranches,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CompanyModel.fromJson(Map<String, dynamic> json) => CompanyModel(
        id: json['id'],
        businessName: json['business_name'],
        ownerName: json['owner_name'],
        email: json['email'],
        phone: json['phone'],
        gstin: json['gstin'],
        drugLicenseNo: json['drug_license_no'],
        drugLicenseExpiry: json['drug_license_expiry'] != null
            ? DateTime.parse(json['drug_license_expiry'])
            : null,
        address: json['address'],
        city: json['city'],
        state: json['state'],
        pincode: json['pincode'],
        logoUrl: json['logo_url'],
        industryType: IndustryType.values.firstWhere(
          (e) => e.name == (json['industry_type'] ?? 'pharmacy'),
          orElse: () => IndustryType.pharmacy,
        ),
        businessMode: BusinessMode.values.firstWhere(
          (e) => e.name == (json['business_mode'] ?? 'retail'),
          orElse: () => BusinessMode.retail,
        ),
        subscriptionPlan: json['subscription_plan'] ?? 'Basic',
        subscriptionStatus: json['subscription_status'] ?? 'active',
        maxBranches: json['max_branches'] ?? 1,
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  CompanyModel copyWith({
    String? id,
    String? businessName,
    String? ownerName,
    String? email,
    String? phone,
    String? gstin,
    String? drugLicenseNo,
    DateTime? drugLicenseExpiry,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? logoUrl,
    IndustryType? industryType,
    BusinessMode? businessMode,
    String? subscriptionPlan,
    String? subscriptionStatus,
    int? maxBranches,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CompanyModel(
        id: id ?? this.id,
        businessName: businessName ?? this.businessName,
        ownerName: ownerName ?? this.ownerName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        gstin: gstin ?? this.gstin,
        drugLicenseNo: drugLicenseNo ?? this.drugLicenseNo,
        drugLicenseExpiry: drugLicenseExpiry ?? this.drugLicenseExpiry,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        pincode: pincode ?? this.pincode,
        logoUrl: logoUrl ?? this.logoUrl,
        industryType: industryType ?? this.industryType,
        businessMode: businessMode ?? this.businessMode,
        subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
        subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
        maxBranches: maxBranches ?? this.maxBranches,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

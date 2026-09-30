class PharmacistModel {
  final String id;
  final String tenantId;
  final String name;
  final String email;
  final String phone;
  final String? licenseNo;
  final String? registrationNo;
  final String pinHash; // Hashed PIN for security
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PharmacistModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.email,
    required this.phone,
    this.licenseNo,
    this.registrationNo,
    required this.pinHash,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'name': name,
        'email': email,
        'phone': phone,
        'license_no': licenseNo,
        'registration_no': registrationNo,
        'pharmacist_pin_hash': pinHash,
        'is_active': isActive,
        'role': 'pharmacist',
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PharmacistModel.fromJson(Map<String, dynamic> json) =>
      PharmacistModel(
        id: json['id'],
        tenantId: json['tenant_id'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        licenseNo: json['license_no'],
        registrationNo: json['registration_no'],
        pinHash: json['pharmacist_pin_hash'] ?? '',
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  PharmacistModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? email,
    String? phone,
    String? licenseNo,
    String? registrationNo,
    String? pinHash,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      PharmacistModel(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        licenseNo: licenseNo ?? this.licenseNo,
        registrationNo: registrationNo ?? this.registrationNo,
        pinHash: pinHash ?? this.pinHash,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

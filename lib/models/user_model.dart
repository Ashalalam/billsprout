enum UserRole { superAdmin, businessAdmin, pharmacist, cashier, customer }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? companyId;
  final String? licenseNo; // MCI or Pharmacy Registration Number

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.companyId,
    this.licenseNo,
  });

  String get roleDisplay {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin (SaaS Owner)';
      case UserRole.businessAdmin:
        return 'Business Admin';
      case UserRole.pharmacist:
        return 'Authorized Pharmacist';
      case UserRole.cashier:
        return 'POS Cashier';
      case UserRole.customer:
        return 'Customer / Patient';
    }
  }

  /// Alias for companyId to match new naming convention
  String? get tenantId => companyId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'companyId': companyId,
        'licenseNo': licenseNo,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        role: UserRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => UserRole.cashier,
        ),
        companyId: json['companyId'],
        licenseNo: json['licenseNo'],
      );
}

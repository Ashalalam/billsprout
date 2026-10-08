class PrescriptionRx {
  final String id;
  final String doctorName;
  final String doctorMci;
  final DateTime uploadDate;
  final String imageUrl;
  final List<String> prescribedMedications;

  PrescriptionRx({
    required this.id,
    required this.doctorName,
    required this.doctorMci,
    required this.uploadDate,
    required this.imageUrl,
    required this.prescribedMedications,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'doctor_name': doctorName,
        'doctor_mci_no': doctorMci,
        'upload_date': uploadDate.toIso8601String(),
        'prescription_file_url': imageUrl,
        'prescribed_medications': prescribedMedications,
      };

  factory PrescriptionRx.fromJson(Map<String, dynamic> json) => PrescriptionRx(
        id: json['id'],
        doctorName: json['doctor_name'],
        doctorMci: json['doctor_mci_no'],
        uploadDate: DateTime.parse(json['upload_date']),
        imageUrl: json['prescription_file_url'],
        prescribedMedications:
            List<String>.from(json['prescribed_medications'] ?? []),
      );
}

class ChronicRefillItem {
  final String medicineName;
  final int refillIntervalDays;
  final DateTime lastPurchasedDate;
  final DateTime nextRefillDueDate;

  ChronicRefillItem({
    required this.medicineName,
    required this.refillIntervalDays,
    required this.lastPurchasedDate,
    required this.nextRefillDueDate,
  });

  bool get isDueSoon =>
      nextRefillDueDate.difference(DateTime.now()).inDays <= 5;

  int get daysUntilRefill =>
      nextRefillDueDate.difference(DateTime.now()).inDays;

  Map<String, dynamic> toJson() => {
        'medicine_name': medicineName,
        'refill_interval_days': refillIntervalDays,
        'last_purchased_date': lastPurchasedDate.toIso8601String(),
        'next_refill_due_date': nextRefillDueDate.toIso8601String(),
      };

  factory ChronicRefillItem.fromJson(Map<String, dynamic> json) =>
      ChronicRefillItem(
        medicineName: json['medicine_name'],
        refillIntervalDays: json['refill_interval_days'],
        lastPurchasedDate: DateTime.parse(json['last_purchased_date']),
        nextRefillDueDate: DateTime.parse(json['next_refill_due_date']),
      );
}

enum CustomerType {
  retail,
  wholesale,
  distributor,
}

extension CustomerTypeX on CustomerType {
  String get label {
    switch (this) {
      case CustomerType.retail:
        return 'Retail Customer';
      case CustomerType.wholesale:
        return 'Wholesale Customer';
      case CustomerType.distributor:
        return 'Distributor';
    }
  }
}

class CustomerModel {
  final String id;
  final String tenantId;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String? gstin; // For wholesale customers
  final String? drugLicenseNo; // For wholesale customers
  final CustomerType customerType;
  final double creditLimit;
  final double outstandingAmount;
  final List<PrescriptionRx> prescriptions;
  final List<ChronicRefillItem> chronicRefills;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.phone,
    required this.email,
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.gstin,
    this.drugLicenseNo,
    this.customerType = CustomerType.retail,
    this.creditLimit = 0.0,
    this.outstandingAmount = 0.0,
    this.prescriptions = const [],
    this.chronicRefills = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isWholesale =>
      customerType == CustomerType.wholesale ||
      customerType == CustomerType.distributor;

  bool get hasOutstanding => outstandingAmount > 0;

  double get availableCredit => creditLimit - outstandingAmount;

  String get fullAddress {
    if (address.isEmpty) return '';
    final parts = [address, city, state, pincode]
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'customer_name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'gstin': gstin,
        'drug_license_no': drugLicenseNo,
        'customer_type': customerType.name,
        'credit_limit': creditLimit,
        'outstanding_amount': outstandingAmount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'],
        tenantId: json['tenant_id'] ?? 'default',
        name: json['customer_name'] ?? json['name'],
        phone: json['phone'],
        email: json['email'],
        address: json['address'] ?? '',
        city: json['city'] ?? '',
        state: json['state'] ?? '',
        pincode: json['pincode'] ?? '',
        gstin: json['gstin'],
        drugLicenseNo: json['drug_license_no'],
        customerType: CustomerType.values.firstWhere(
          (e) => e.name == (json['customer_type'] ?? 'retail'),
          orElse: () => CustomerType.retail,
        ),
        creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
        outstandingAmount:
            (json['outstanding_amount'] as num?)?.toDouble() ?? 0.0,
        prescriptions: [], // Loaded separately if needed
        chronicRefills: [], // Loaded separately if needed
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );

  CustomerModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstin,
    String? drugLicenseNo,
    CustomerType? customerType,
    double? creditLimit,
    double? outstandingAmount,
    List<PrescriptionRx>? prescriptions,
    List<ChronicRefillItem>? chronicRefills,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CustomerModel(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        pincode: pincode ?? this.pincode,
        gstin: gstin ?? this.gstin,
        drugLicenseNo: drugLicenseNo ?? this.drugLicenseNo,
        customerType: customerType ?? this.customerType,
        creditLimit: creditLimit ?? this.creditLimit,
        outstandingAmount: outstandingAmount ?? this.outstandingAmount,
        prescriptions: prescriptions ?? this.prescriptions,
        chronicRefills: chronicRefills ?? this.chronicRefills,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}


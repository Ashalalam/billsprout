class DemoRequestModel {
  final String id;
  final String name;
  final String? businessName;
  final String mobile;
  final String? email;
  final String? city;
  final String? pincode;
  final String? businessType;
  final int numBranches;
  final String? message;
  final String status; // new, contacted, converted, closed
  final DateTime createdAt;

  DemoRequestModel({
    required this.id,
    required this.name,
    this.businessName,
    required this.mobile,
    this.email,
    this.city,
    this.pincode,
    this.businessType,
    this.numBranches = 1,
    this.message,
    this.status = 'new',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'business_name': businessName,
        'mobile': mobile,
        'email': email,
        'city': city,
        'pincode': pincode,
        'business_type': businessType,
        'num_branches': numBranches,
        'message': message,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  factory DemoRequestModel.fromJson(Map<String, dynamic> json) =>
      DemoRequestModel(
        id: json['id'],
        name: json['name'],
        businessName: json['business_name'],
        mobile: json['mobile'],
        email: json['email'],
        city: json['city'],
        pincode: json['pincode'],
        businessType: json['business_type'],
        numBranches: json['num_branches'] ?? 1,
        message: json['message'],
        status: json['status'] ?? 'new',
        createdAt: DateTime.parse(json['created_at']),
      );
}

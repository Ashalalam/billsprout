import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every pharmacy that buys BillSprout sets up their own company profile.
/// This replaces the hardcoded "LIFESPROUT Care" everywhere in the app.
class CompanyProfile {
  final String pharmacyName;
  final String ownerName;
  final String address;
  final String city;
  final String state;
  final String pinCode;
  final String gstin;
  final String drugLicenseNo;       // e.g. DL-KA-2024-0001
  final String phone;
  final String altPhone;
  final String email;
  final String stateCode;           // For GST e.g. "36" for Telangana
  final String businessType;        // Retail / Wholesale / Both
  final String bankName;
  final String accountNumber;
  final String ifscCode;

  const CompanyProfile({
    this.pharmacyName    = 'My Pharmacy',
    this.ownerName       = '',
    this.address         = '',
    this.city            = '',
    this.state           = '',
    this.pinCode         = '',
    this.gstin           = '',
    this.drugLicenseNo   = '',
    this.phone           = '',
    this.altPhone        = '',
    this.email           = '',
    this.stateCode       = '36',
    this.businessType    = 'Retail',
    this.bankName        = '',
    this.accountNumber   = '',
    this.ifscCode        = '',
  });

  bool get isConfigured =>
      pharmacyName != 'My Pharmacy' && gstin.isNotEmpty;

  /// Full address string for invoice printing
  String get fullAddress {
    final parts = [address, city, state, pinCode]
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  CompanyProfile copyWith({
    String? pharmacyName,
    String? ownerName,
    String? address,
    String? city,
    String? state,
    String? pinCode,
    String? gstin,
    String? drugLicenseNo,
    String? phone,
    String? altPhone,
    String? email,
    String? stateCode,
    String? businessType,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
  }) =>
      CompanyProfile(
        pharmacyName:  pharmacyName  ?? this.pharmacyName,
        ownerName:     ownerName     ?? this.ownerName,
        address:       address       ?? this.address,
        city:          city          ?? this.city,
        state:         state         ?? this.state,
        pinCode:       pinCode       ?? this.pinCode,
        gstin:         gstin         ?? this.gstin,
        drugLicenseNo: drugLicenseNo ?? this.drugLicenseNo,
        phone:         phone         ?? this.phone,
        altPhone:      altPhone      ?? this.altPhone,
        email:         email         ?? this.email,
        stateCode:     stateCode     ?? this.stateCode,
        businessType:  businessType  ?? this.businessType,
        bankName:      bankName      ?? this.bankName,
        accountNumber: accountNumber ?? this.accountNumber,
        ifscCode:      ifscCode      ?? this.ifscCode,
      );

  Map<String, dynamic> toJson() => {
        'pharmacyName':  pharmacyName,
        'ownerName':     ownerName,
        'address':       address,
        'city':          city,
        'state':         state,
        'pinCode':       pinCode,
        'gstin':         gstin,
        'drugLicenseNo': drugLicenseNo,
        'phone':         phone,
        'altPhone':      altPhone,
        'email':         email,
        'stateCode':     stateCode,
        'businessType':  businessType,
        'bankName':      bankName,
        'accountNumber': accountNumber,
        'ifscCode':      ifscCode,
      };

  factory CompanyProfile.fromJson(Map<String, dynamic> j) => CompanyProfile(
        pharmacyName:  j['pharmacyName']  ?? 'My Pharmacy',
        ownerName:     j['ownerName']     ?? '',
        address:       j['address']       ?? '',
        city:          j['city']          ?? '',
        state:         j['state']         ?? '',
        pinCode:       j['pinCode']       ?? '',
        gstin:         j['gstin']         ?? '',
        drugLicenseNo: j['drugLicenseNo'] ?? '',
        phone:         j['phone']         ?? '',
        altPhone:      j['altPhone']      ?? '',
        email:         j['email']         ?? '',
        stateCode:     j['stateCode']     ?? '36',
        businessType:  j['businessType']  ?? 'Retail',
        bankName:      j['bankName']      ?? '',
        accountNumber: j['accountNumber'] ?? '',
        ifscCode:      j['ifscCode']      ?? '',
      );
}

class CompanyProfileProvider extends ChangeNotifier {
  static const _key = 'company_profile_v1';

  CompanyProfile _profile = const CompanyProfile();

  CompanyProfile get profile => _profile;
  bool get isConfigured => _profile.isConfigured;

  CompanyProfileProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _profile = CompanyProfile.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CompanyProfile] load error: $e');
    }
  }

  Future<void> save(CompanyProfile updated) async {
    _profile = updated;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(updated.toJson()));
    } catch (e) {
      debugPrint('[CompanyProfile] save error: $e');
    }
  }
}

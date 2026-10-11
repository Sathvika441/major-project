import 'dart:convert';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final String? phoneVerificationOtp;
  final DateTime? phoneVerificationSentAt;
  final bool termsAccepted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.phoneVerificationOtp,
    this.phoneVerificationSentAt,
    this.termsAccepted = true,
    required this.createdAt,
    this.updatedAt,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    String? phoneVerificationOtp,
    DateTime? phoneVerificationSentAt,
    bool? clearPhoneOtp,
    bool? termsAccepted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      phoneVerificationOtp: clearPhoneOtp == true
          ? null
          : (phoneVerificationOtp ?? this.phoneVerificationOtp),
      phoneVerificationSentAt: clearPhoneOtp == true
          ? null
          : (phoneVerificationSentAt ?? this.phoneVerificationSentAt),
      termsAccepted: termsAccepted ?? this.termsAccepted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'phoneVerificationOtp': phoneVerificationOtp,
      'phoneVerificationSentAt': phoneVerificationSentAt?.toIso8601String(),
      'termsAccepted': termsAccepted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String? ?? '',
      isEmailVerified: map['isEmailVerified'] as bool? ?? false,
      isPhoneVerified: map['isPhoneVerified'] as bool? ?? false,
      phoneVerificationOtp: map['phoneVerificationOtp'] as String?,
      phoneVerificationSentAt: map['phoneVerificationSentAt'] != null
          ? DateTime.parse(map['phoneVerificationSentAt'] as String)
          : null,
      termsAccepted: map['termsAccepted'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, email: $email, phone: $phone, isEmailVerified: $isEmailVerified, isPhoneVerified: $isPhoneVerified)';
  }
}

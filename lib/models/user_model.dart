class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? avatar;
  final double walletBalance;
  final bool isHost;
  final bool hasPassword; // true = user can also login with password
  final DateTime createdAt;
  final String? gender; // 'male' | 'female' | 'other'
  final int? age;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.avatar,
    required this.walletBalance,
    required this.isHost,
    this.hasPassword = false,
    required this.createdAt,
    this.gender,
    this.age,
  });

  // Safely parses PostgreSQL DECIMAL/NUMERIC which arrives as String from node-postgres
  static double _pd(dynamic v, [double fb = 0.0]) {
    if (v == null) return fb;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fb;
  }

  // Handles both camelCase (auth response) and snake_case (profile/DB)
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'].toString(),
        name: (json['name'] as String?) ?? 'User',
        phone: (json['phone'] as String?) ?? '',
        avatar: json['avatar'] as String?,
        walletBalance: _pd(json['walletBalance'] ?? json['wallet_balance']),
        isHost: ((json['isHost'] ?? json['is_host']) as bool?) ?? false,
        hasPassword: (json['hasPassword'] as bool?) ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        gender: json['gender'] as String?,
        age: json['age'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'avatar': avatar,
        'wallet_balance': walletBalance,
        'is_host': isHost,
        'hasPassword': hasPassword,
        'created_at': createdAt.toIso8601String(),
        'gender': gender,
        'age': age,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? avatar,
    double? walletBalance,
    bool? isHost,
    bool? hasPassword,
    DateTime? createdAt,
    Object? gender = _sentinel,
    Object? age = _sentinel,
  }) =>
      UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        avatar: avatar ?? this.avatar,
        walletBalance: walletBalance ?? this.walletBalance,
        isHost: isHost ?? this.isHost,
        hasPassword: hasPassword ?? this.hasPassword,
        createdAt: createdAt ?? this.createdAt,
        gender: gender == _sentinel ? this.gender : gender as String?,
        age: age == _sentinel ? this.age : age as int?,
      );
}

// Sentinel object for nullable copyWith fields
const _sentinel = Object();

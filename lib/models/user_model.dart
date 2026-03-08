class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? avatar;
  final double walletBalance;
  final bool isHost;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.avatar,
    required this.walletBalance,
    required this.isHost,
    required this.createdAt,
  });

  // Handles both camelCase (auth) and snake_case (profile/DB)
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'User',
        phone: (json['phone'] as String?) ?? '',
        avatar: json['avatar'] as String?,
        walletBalance:
            ((json['walletBalance'] ?? json['wallet_balance']) as num?)
                    ?.toDouble() ??
                0.0,
        isHost: ((json['isHost'] ?? json['is_host']) as bool?) ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'avatar': avatar,
        'wallet_balance': walletBalance,
        'is_host': isHost,
        'created_at': createdAt.toIso8601String(),
      };
}

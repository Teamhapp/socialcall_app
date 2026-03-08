enum TransactionType { recharge, call, gift, payout }

class TransactionModel {
  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final bool isCredit;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.isCredit,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Map backend enum values (call_charge, gift_sent, etc.) to Flutter enum
    final rawType = (json['type'] as String?) ?? 'recharge';
    final type = switch (rawType) {
      'recharge'                      => TransactionType.recharge,
      'call_charge'                   => TransactionType.call,
      'gift_sent' || 'gift_received'  => TransactionType.gift,
      'payout'                        => TransactionType.payout,
      _                               => TransactionType.recharge,
    };
    return TransactionModel(
      id: json['id'] as String,
      type: type,
      amount: (json['amount'] as num).toDouble(),
      description: (json['description'] as String?) ?? '',
      isCredit: (json['is_credit'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static List<TransactionModel> demoTransactions = [
    TransactionModel(id: '1', type: TransactionType.recharge, amount: 500,
        description: 'Wallet recharge via UPI', isCredit: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    TransactionModel(id: '2', type: TransactionType.call, amount: 120,
        description: 'Audio call with Priya Sharma (8 min)', isCredit: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 5))),
    TransactionModel(id: '3', type: TransactionType.gift, amount: 50,
        description: 'Gift sent to Anjali Verma', isCredit: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1))),
    TransactionModel(id: '4', type: TransactionType.recharge, amount: 200,
        description: 'Wallet recharge via Card', isCredit: true,
        createdAt: DateTime.now().subtract(const Duration(days: 2))),
    TransactionModel(id: '5', type: TransactionType.call, amount: 200,
        description: 'Video call with Meera Nair (5 min)', isCredit: false,
        createdAt: DateTime.now().subtract(const Duration(days: 3))),
  ];
}

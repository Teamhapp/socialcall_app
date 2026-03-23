class AdminStats {
  final int totalUsers;
  final int hostsOnline;
  final int totalHosts;
  final int callsToday;
  final double revenueToday;
  final int totalCalls;
  final double totalRevenue;
  final int pendingPayouts;
  final int unverifiedHosts;
  final int activePromos;
  final int pendingKyc;

  const AdminStats({
    required this.totalUsers,
    required this.hostsOnline,
    required this.totalHosts,
    required this.callsToday,
    required this.revenueToday,
    required this.totalCalls,
    required this.totalRevenue,
    required this.pendingPayouts,
    required this.unverifiedHosts,
    required this.activePromos,
    required this.pendingKyc,
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
        totalUsers: _int(j['total_users']),
        hostsOnline: _int(j['hosts_online']),
        totalHosts: _int(j['total_hosts']),
        callsToday: _int(j['calls_today']),
        revenueToday: _double(j['revenue_today']),
        totalCalls: _int(j['total_calls']),
        totalRevenue: _double(j['total_revenue']),
        pendingPayouts: _int(j['pending_payouts']),
        unverifiedHosts: _int(j['unverified_hosts']),
        activePromos: _int(j['active_promos']),
        pendingKyc: _int(j['pending_kyc']),
      );
}

class AdminUser {
  final String id;
  final String name;
  final String phone;
  final String? avatar;
  final double walletBalance;
  final bool isHost;
  final bool isActive;
  final String createdAt;

  const AdminUser({
    required this.id,
    required this.name,
    required this.phone,
    this.avatar,
    required this.walletBalance,
    required this.isHost,
    required this.isActive,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Unknown',
        phone: j['phone'] as String? ?? '',
        avatar: j['avatar'] as String?,
        walletBalance: _double(j['wallet_balance']),
        isHost: j['is_host'] as bool? ?? false,
        isActive: j['is_active'] as bool? ?? true,
        createdAt: j['created_at'] as String? ?? '',
      );
}

class AdminHost {
  final String id;
  final String userId;
  final String name;
  final String? avatar;
  final double rating;
  final int totalCalls;
  final double totalEarnings;
  final bool isVerified;
  final bool isOnline;
  final String kycStatus;

  const AdminHost({
    required this.id,
    required this.userId,
    required this.name,
    this.avatar,
    required this.rating,
    required this.totalCalls,
    required this.totalEarnings,
    required this.isVerified,
    required this.isOnline,
    required this.kycStatus,
  });

  factory AdminHost.fromJson(Map<String, dynamic> j) => AdminHost(
        id: j['id'] as String,
        userId: j['user_id'] as String? ?? '',
        name: j['name'] as String? ?? 'Unknown',
        avatar: j['avatar'] as String?,
        rating: _double(j['rating']),
        totalCalls: _int(j['total_calls']),
        totalEarnings: _double(j['total_earnings']),
        isVerified: j['is_verified'] as bool? ?? false,
        isOnline: j['is_online'] as bool? ?? false,
        kycStatus: j['kyc_status'] as String? ?? 'not_submitted',
      );
}

class AdminPayout {
  final String id;
  final String hostId;
  final String hostName;
  final double amount;
  final String status;
  final String? upiId;
  final String? bankAccount;
  final String requestedAt;
  final String? processedAt;
  final String? notes;

  const AdminPayout({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.amount,
    required this.status,
    this.upiId,
    this.bankAccount,
    required this.requestedAt,
    this.processedAt,
    this.notes,
  });

  factory AdminPayout.fromJson(Map<String, dynamic> j) => AdminPayout(
        id: j['id'] as String,
        hostId: j['host_id'] as String? ?? '',
        hostName: j['host_name'] as String? ?? 'Unknown',
        amount: _double(j['amount']),
        status: j['status'] as String? ?? 'pending',
        upiId: j['upi_id'] as String?,
        bankAccount: j['bank_account'] as String?,
        requestedAt: j['requested_at'] as String? ?? '',
        processedAt: j['processed_at'] as String?,
        notes: j['notes'] as String?,
      );
}

class AdminKyc {
  final String id;
  final String hostId;
  final String hostName;
  final String documentType;
  final String? frontUrl;
  final String? backUrl;
  final String? selfieUrl;
  final String status;
  final String? rejectionReason;
  final String submittedAt;

  const AdminKyc({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.documentType,
    this.frontUrl,
    this.backUrl,
    this.selfieUrl,
    required this.status,
    this.rejectionReason,
    required this.submittedAt,
  });

  factory AdminKyc.fromJson(Map<String, dynamic> j) => AdminKyc(
        id: j['id'] as String,
        hostId: j['host_id'] as String? ?? '',
        hostName: j['host_name'] as String? ?? 'Unknown',
        documentType: j['document_type'] as String? ?? '',
        frontUrl: j['front_url'] as String?,
        backUrl: j['back_url'] as String?,
        selfieUrl: j['selfie_url'] as String?,
        status: j['status'] as String? ?? 'pending',
        rejectionReason: j['rejection_reason'] as String?,
        submittedAt: j['submitted_at'] as String? ?? '',
      );
}

class AdminPromo {
  final String id;
  final String code;
  final double amount;
  final int maxUses;
  final int usedCount;
  final bool isActive;
  final String? expiresAt;

  const AdminPromo({
    required this.id,
    required this.code,
    required this.amount,
    required this.maxUses,
    required this.usedCount,
    required this.isActive,
    this.expiresAt,
  });

  factory AdminPromo.fromJson(Map<String, dynamic> j) => AdminPromo(
        id: j['id'] as String,
        code: j['code'] as String? ?? '',
        amount: _double(j['amount']),
        maxUses: _int(j['max_uses']),
        usedCount: _int(j['used_count']),
        isActive: j['is_active'] as bool? ?? false,
        expiresAt: j['expires_at'] as String?,
      );
}

class AdminReview {
  final String id;
  final String? callId;
  final String userName;
  final String hostName;
  final int rating;
  final String? comment;
  final String createdAt;

  const AdminReview({
    required this.id,
    this.callId,
    required this.userName,
    required this.hostName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory AdminReview.fromJson(Map<String, dynamic> j) => AdminReview(
        id: j['id'] as String,
        callId: j['call_id'] as String?,
        userName: j['user_name'] as String? ?? 'Unknown',
        hostName: j['host_name'] as String? ?? 'Unknown',
        rating: _int(j['rating']),
        comment: j['comment'] as String?,
        createdAt: j['created_at'] as String? ?? '',
      );
}

class AdminOffer {
  final String id;
  final String title;
  final String? subtitle;
  final String bgColorHex;
  final String iconEmoji;
  final String ctaLabel;
  final String? promoCode;
  final bool isActive;
  final String startsAt;
  final String endsAt;
  final String createdAt;

  const AdminOffer({
    required this.id,
    required this.title,
    this.subtitle,
    required this.bgColorHex,
    required this.iconEmoji,
    required this.ctaLabel,
    this.promoCode,
    required this.isActive,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
  });

  factory AdminOffer.fromJson(Map<String, dynamic> j) => AdminOffer(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String?,
        bgColorHex: j['bg_color_hex'] as String? ?? '#FF4D79',
        iconEmoji: j['icon_emoji'] as String? ?? '🎉',
        ctaLabel: j['cta_label'] as String? ?? 'Claim Now',
        promoCode: j['promo_code'] as String?,
        isActive: j['is_active'] as bool? ?? false,
        startsAt: j['starts_at'] as String? ?? '',
        endsAt: j['ends_at'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
      );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

int _int(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

double _double(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

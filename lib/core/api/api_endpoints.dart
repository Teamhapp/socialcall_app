class ApiEndpoints {
  // ── Switch between environments ────────────────────────────────────────────
  // Local emulator    → 'http://10.0.2.2:5000'
  // Local real device → 'http://192.168.1.12:5000'   (your PC's WiFi IP)
  // Render.com        → 'https://socialcall-backend.onrender.com'
  // Google Cloud Run  → 'https://socialcall-backend-xxxxxxxx-el.a.run.app'
  //                      ↑ paste the URL printed at the end of deploy.sh
  static const String baseUrl = 'https://socialcallbackend.replit.app';

  // Auth — OTP
  static const String sendOtp    = '/api/auth/send-otp';
  static const String verifyOtp  = '/api/auth/verify-otp';
  // Auth — Password
  static const String register      = '/api/auth/register';
  static const String loginPassword = '/api/auth/login-password';
  static const String setPassword   = '/api/auth/set-password';
  // Auth — Shared
  static const String refresh = '/api/auth/refresh';
  static const String logout  = '/api/auth/logout';
  static const String me      = '/api/auth/me';

  // User
  static const String profile        = '/api/users/profile';
  static const String profileUpdate  = '/api/users/profile'; // PATCH
  static const String fcmToken       = '/api/users/fcm-token';

  // KYC
  static const String kycSubmit = '/api/hosts/kyc';
  static const String kycStatus = '/api/hosts/kyc';

  // Hosts
  static const String hosts = '/api/hosts';
  static const String randomHost = '/api/hosts/random';
  static String hostById(String id) => '/api/hosts/$id';
  static String hostFollow(String id) => '/api/hosts/$id/follow';
  static const String hostProfile = '/api/hosts/profile';
  static const String hostStatus = '/api/hosts/status';
  static const String hostDashboard = '/api/hosts/me';
  static const String hostFollowing = '/api/hosts/following';

  // Calls
  static const String callInitiate  = '/api/calls/initiate';
  static String callAgoraToken(String id) => '/api/calls/$id/agora-token';
  static String callAccept(String id) => '/api/calls/$id/accept';
  static String callEnd(String id) => '/api/calls/$id/end';
  static String callReview(String id) => '/api/calls/$id/review';
  static const String callHistory = '/api/calls/history';
  static const String callHistoryHost = '/api/calls/history/host';

  // Chat
  static const String conversations = '/api/chat';
  static String messages(String userId) => '/api/chat/$userId';

  // User actions
  static const String hostPayout   = '/api/hosts/payout';
  static const String hostPayouts  = '/api/hosts/payouts';
  static const String deleteAccount = '/api/users/me'; // DELETE

  // Wallet
  static const String walletOrder = '/api/wallet/order';
  static const String walletVerify = '/api/wallet/verify';
  static const String walletTransactions = '/api/wallet/transactions';
  static const String gifts = '/api/wallet/gifts';
  static const String sendGift = '/api/wallet/gift';
  static const String redeemPromo = '/api/wallet/redeem-promo';
  static const String referralCode = '/api/wallet/referral';
  static const String applyReferral = '/api/wallet/referral/apply';

  // Live Streams
  static const String streams = '/api/streams';
  static const String goLive = '/api/streams/go-live';
  static String streamToken(String id) => '/api/streams/$id/token';
  static String streamLeave(String id) => '/api/streams/$id/leave';
  static String streamEnd(String id) => '/api/streams/$id/end';

  // Subscriptions
  static String subscribeHost(String hostId) => '/api/subscriptions/$hostId';
  static String subscriptionStatus(String hostId) => '/api/subscriptions/status/$hostId';

  // Reports & Moderation
  static const String submitReport = '/api/reports';

  // Host Analytics
  static const String hostAnalytics = '/api/hosts/me/analytics';

  // Chat — Voice Messages
  static String chatVoice(String userId) => '/api/chat/$userId/voice';

  // Admin
  static const String adminLogin   = '/admin/api/login';
  static const String adminStats   = '/admin/api/stats';
  static const String adminUsers   = '/admin/api/users';
  static String adminUserWallet(String id)      => '/admin/api/users/$id/wallet';
  static String adminUserStatus(String id)      => '/admin/api/users/$id/status';
  static const String adminHosts   = '/admin/api/hosts';
  static String adminHostVerify(String id)      => '/admin/api/hosts/$id/verify';
  static String adminHostPromote(String id)     => '/admin/api/hosts/$id/promote';
  static String adminHostDemote(String id)      => '/admin/api/hosts/$id/demote';
  static const String adminPayouts = '/admin/api/payouts';
  static String adminPayout(String id)          => '/admin/api/payouts/$id';
  static const String adminKyc     = '/admin/api/kyc';
  static String adminKycApprove(String id)      => '/admin/api/kyc/$id/approve';
  static String adminKycReject(String id)       => '/admin/api/kyc/$id/reject';
  static const String adminPromos  = '/admin/api/promo-codes';
  static String adminPromoDeactivate(String id) => '/admin/api/promo-codes/$id/deactivate';
  static const String adminReviews = '/admin/api/reviews';
  static String adminReview(String id)          => '/admin/api/reviews/$id';
  static const String adminPush    = '/admin/api/push/broadcast';
  static const String adminHealth  = '/admin/api/health';
  static const String adminOffers  = '/admin/api/offers';
  static String adminOffer(String id) => '/admin/api/offers/$id';
  static const String adminWalletBonus = '/admin/api/offers/wallet-bonus';

  // Offers (public)
  static const String offers = '/api/offers';

  // Host tags
  static const String hostTags = '/api/hosts/tags';
}

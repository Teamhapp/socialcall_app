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
  static String hostById(String id) => '/api/hosts/$id';
  static String hostFollow(String id) => '/api/hosts/$id/follow';
  static const String hostProfile = '/api/hosts/profile';
  static const String hostStatus = '/api/hosts/status';
  static const String hostDashboard = '/api/hosts/me';
  static const String hostFollowing = '/api/hosts/following';

  // Calls
  static const String iceServers    = '/api/calls/ice-servers';
  static const String callInitiate  = '/api/calls/initiate';
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
}

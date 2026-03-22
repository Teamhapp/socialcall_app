class HostModel {
  final String id;
  final String userId;
  final String name;
  final String? avatar;
  final String bio;
  final List<String> languages;
  final List<String> tags;
  final double audioRatePerMin;
  final double videoRatePerMin;
  final double rating;
  final int totalCalls;
  final int totalReviews;
  final bool isOnline;
  final bool isVerified;
  final int followersCount;
  final String? gender; // 'male' | 'female' | 'other'
  final int? age;

  const HostModel({
    required this.id,
    required this.userId,
    required this.name,
    this.avatar,
    required this.bio,
    required this.languages,
    this.tags = const [],
    required this.audioRatePerMin,
    required this.videoRatePerMin,
    required this.rating,
    required this.totalCalls,
    this.totalReviews = 0,
    required this.isOnline,
    required this.isVerified,
    required this.followersCount,
    this.gender,
    this.age,
  });

  // PostgreSQL DECIMAL/NUMERIC columns are returned as strings by node-postgres.
  static double _pd(dynamic v, [double fb = 0.0]) {
    if (v == null) return fb;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fb;
  }

  factory HostModel.fromJson(Map<String, dynamic> json) => HostModel(
        id: json['id'].toString(),
        userId: json['user_id'].toString(),
        name: json['name'] as String? ?? 'Host',
        avatar: json['avatar'] as String?,
        bio: json['bio'] as String? ?? '',
        languages: List<String>.from(json['languages'] ?? []),
        tags: List<String>.from(json['tags'] ?? []),
        audioRatePerMin: _pd(json['audio_rate_per_min'], 15),
        videoRatePerMin: _pd(json['video_rate_per_min'], 40),
        rating: _pd(json['rating']),
        totalCalls: json['total_calls'] as int? ?? 0,
        totalReviews: json['total_reviews'] as int? ?? 0,
        isOnline: json['is_online'] as bool? ?? false,
        isVerified: json['is_verified'] as bool? ?? false,
        followersCount: json['followers_count'] as int? ?? 0,
        gender: json['gender'] as String?,
        age: json['age'] as int?,
      );

  HostModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? avatar,
    String? bio,
    List<String>? languages,
    List<String>? tags,
    double? audioRatePerMin,
    double? videoRatePerMin,
    double? rating,
    int? totalCalls,
    int? totalReviews,
    bool? isOnline,
    bool? isVerified,
    int? followersCount,
    String? gender,
    int? age,
  }) =>
      HostModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        bio: bio ?? this.bio,
        languages: languages ?? this.languages,
        tags: tags ?? this.tags,
        audioRatePerMin: audioRatePerMin ?? this.audioRatePerMin,
        videoRatePerMin: videoRatePerMin ?? this.videoRatePerMin,
        rating: rating ?? this.rating,
        totalCalls: totalCalls ?? this.totalCalls,
        totalReviews: totalReviews ?? this.totalReviews,
        isOnline: isOnline ?? this.isOnline,
        isVerified: isVerified ?? this.isVerified,
        followersCount: followersCount ?? this.followersCount,
        gender: gender ?? this.gender,
        age: age ?? this.age,
      );

  // Demo data for UI testing
  static List<HostModel> demoHosts = [
    HostModel(
      id: '1', userId: 'u1', name: 'Priya Sharma',
      avatar: 'https://randomuser.me/api/portraits/women/44.jpg',
      bio: 'I love deep conversations, music and travelling. Let\'s chat!',
      languages: ['Hindi', 'English'],
      tags: ['music', 'travel'],
      audioRatePerMin: 15, videoRatePerMin: 40,
      rating: 4.8, totalCalls: 1240, isOnline: true,
      isVerified: true, followersCount: 3200,
      gender: 'female', age: 24,
    ),
    HostModel(
      id: '2', userId: 'u2', name: 'Anjali Verma',
      avatar: 'https://randomuser.me/api/portraits/women/68.jpg',
      bio: 'Singer & dancer. Here to make your day better!',
      languages: ['Hindi', 'Punjabi'],
      tags: ['music', 'dance'],
      audioRatePerMin: 20, videoRatePerMin: 50,
      rating: 4.9, totalCalls: 890, isOnline: true,
      isVerified: true, followersCount: 5100,
      gender: 'female', age: 22,
    ),
    HostModel(
      id: '3', userId: 'u3', name: 'Sneha Patel',
      avatar: 'https://randomuser.me/api/portraits/women/23.jpg',
      bio: 'Love talking about life, food and everything in between.',
      languages: ['Gujarati', 'Hindi', 'English'],
      tags: ['cooking', 'lifestyle'],
      audioRatePerMin: 12, videoRatePerMin: 35,
      rating: 4.6, totalCalls: 560, isOnline: false,
      isVerified: false, followersCount: 1800,
      gender: 'female', age: 27,
    ),
    HostModel(
      id: '4', userId: 'u4', name: 'Meera Nair',
      avatar: 'https://randomuser.me/api/portraits/women/12.jpg',
      bio: 'Storyteller & listener. Here whenever you need someone.',
      languages: ['Malayalam', 'Hindi', 'English'],
      tags: ['stories', 'wellness'],
      audioRatePerMin: 18, videoRatePerMin: 45,
      rating: 4.7, totalCalls: 2100, isOnline: true,
      isVerified: true, followersCount: 4500,
      gender: 'female', age: 30,
    ),
    HostModel(
      id: '5', userId: 'u5', name: 'Kavya Reddy',
      avatar: 'https://randomuser.me/api/portraits/women/33.jpg',
      bio: 'Artist & dreamer. Let\'s create something beautiful together.',
      languages: ['Telugu', 'Hindi'],
      tags: ['art', 'travel'],
      audioRatePerMin: 16, videoRatePerMin: 42,
      rating: 4.5, totalCalls: 430, isOnline: true,
      isVerified: false, followersCount: 980,
      gender: 'female', age: 25,
    ),
    HostModel(
      id: '6', userId: 'u6', name: 'Riya Kapoor',
      avatar: 'https://randomuser.me/api/portraits/women/55.jpg',
      bio: 'Fitness lover and life coach. Talk to me about goals!',
      languages: ['Hindi', 'English'],
      tags: ['fitness', 'wellness'],
      audioRatePerMin: 25, videoRatePerMin: 60,
      rating: 4.9, totalCalls: 3400, totalReviews: 312,
      isOnline: false, isVerified: true, followersCount: 8200,
      gender: 'female', age: 28,
    ),
  ];
}

// ── Review model ──────────────────────────────────────────────────────────────

class ReviewModel {
  final String reviewerName;
  final String? reviewerAvatar;
  final double rating;
  final String? comment;
  final DateTime? createdAt;

  const ReviewModel({
    required this.reviewerName,
    this.reviewerAvatar,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  static double _pd(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory ReviewModel.fromJson(Map<String, dynamic> j) => ReviewModel(
        reviewerName: j['reviewer_name'] as String? ?? 'Anonymous',
        reviewerAvatar: j['reviewer_avatar'] as String?,
        rating: _pd(j['rating']),
        comment: (j['comment'] as String?)?.trim().isEmpty == true
            ? null
            : j['comment'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );
}

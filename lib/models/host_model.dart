class HostModel {
  final String id;
  final String userId;
  final String name;
  final String? avatar;
  final String bio;
  final List<String> languages;
  final double audioRatePerMin;
  final double videoRatePerMin;
  final double rating;
  final int totalCalls;
  final bool isOnline;
  final bool isVerified;
  final int followersCount;

  const HostModel({
    required this.id,
    required this.userId,
    required this.name,
    this.avatar,
    required this.bio,
    required this.languages,
    required this.audioRatePerMin,
    required this.videoRatePerMin,
    required this.rating,
    required this.totalCalls,
    required this.isOnline,
    required this.isVerified,
    required this.followersCount,
  });

  factory HostModel.fromJson(Map<String, dynamic> json) => HostModel(
        id: json['id'],
        userId: json['user_id'],
        name: json['name'],
        avatar: json['avatar'],
        bio: json['bio'] ?? '',
        languages: List<String>.from(json['languages'] ?? []),
        audioRatePerMin: (json['audio_rate_per_min'] as num).toDouble(),
        videoRatePerMin: (json['video_rate_per_min'] as num).toDouble(),
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        totalCalls: json['total_calls'] ?? 0,
        isOnline: json['is_online'] ?? false,
        isVerified: json['is_verified'] ?? false,
        followersCount: json['followers_count'] ?? 0,
      );

  // Demo data for UI testing
  static List<HostModel> demoHosts = [
    HostModel(
      id: '1', userId: 'u1', name: 'Priya Sharma',
      avatar: 'https://randomuser.me/api/portraits/women/44.jpg',
      bio: 'I love deep conversations, music and travelling. Let\'s chat!',
      languages: ['Hindi', 'English'],
      audioRatePerMin: 15, videoRatePerMin: 40,
      rating: 4.8, totalCalls: 1240, isOnline: true,
      isVerified: true, followersCount: 3200,
    ),
    HostModel(
      id: '2', userId: 'u2', name: 'Anjali Verma',
      avatar: 'https://randomuser.me/api/portraits/women/68.jpg',
      bio: 'Singer & dancer. Here to make your day better!',
      languages: ['Hindi', 'Punjabi'],
      audioRatePerMin: 20, videoRatePerMin: 50,
      rating: 4.9, totalCalls: 890, isOnline: true,
      isVerified: true, followersCount: 5100,
    ),
    HostModel(
      id: '3', userId: 'u3', name: 'Sneha Patel',
      avatar: 'https://randomuser.me/api/portraits/women/23.jpg',
      bio: 'Love talking about life, food and everything in between.',
      languages: ['Gujarati', 'Hindi', 'English'],
      audioRatePerMin: 12, videoRatePerMin: 35,
      rating: 4.6, totalCalls: 560, isOnline: false,
      isVerified: false, followersCount: 1800,
    ),
    HostModel(
      id: '4', userId: 'u4', name: 'Meera Nair',
      avatar: 'https://randomuser.me/api/portraits/women/12.jpg',
      bio: 'Storyteller & listener. Here whenever you need someone.',
      languages: ['Malayalam', 'Hindi', 'English'],
      audioRatePerMin: 18, videoRatePerMin: 45,
      rating: 4.7, totalCalls: 2100, isOnline: true,
      isVerified: true, followersCount: 4500,
    ),
    HostModel(
      id: '5', userId: 'u5', name: 'Kavya Reddy',
      avatar: 'https://randomuser.me/api/portraits/women/33.jpg',
      bio: 'Artist & dreamer. Let\'s create something beautiful together.',
      languages: ['Telugu', 'Hindi'],
      audioRatePerMin: 16, videoRatePerMin: 42,
      rating: 4.5, totalCalls: 430, isOnline: true,
      isVerified: false, followersCount: 980,
    ),
    HostModel(
      id: '6', userId: 'u6', name: 'Riya Kapoor',
      avatar: 'https://randomuser.me/api/portraits/women/55.jpg',
      bio: 'Fitness lover and life coach. Talk to me about goals!',
      languages: ['Hindi', 'English'],
      audioRatePerMin: 25, videoRatePerMin: 60,
      rating: 4.9, totalCalls: 3400, isOnline: false,
      isVerified: true, followersCount: 8200,
    ),
  ];
}

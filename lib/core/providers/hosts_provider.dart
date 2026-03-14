import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../socket/socket_service.dart';
import '../../models/host_model.dart';

// ── State ──────────────────────────────────────────────────────────────────────
class HostsState {
  final List<HostModel> hosts;
  final bool isLoading;
  final String? error;
  final int page;
  final bool hasMore;
  final String search;
  final String filter; // All / Online / language

  const HostsState({
    this.hosts = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
    this.search = '',
    this.filter = 'All',
  });

  HostsState copyWith({
    List<HostModel>? hosts,
    bool? isLoading,
    String? error,
    int? page,
    bool? hasMore,
    String? search,
    String? filter,
  }) =>
      HostsState(
        hosts: hosts ?? this.hosts,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        search: search ?? this.search,
        filter: filter ?? this.filter,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────
class HostsNotifier extends StateNotifier<HostsState> {
  HostsNotifier() : super(const HostsState()) {
    fetchHosts();
    _listenToStatusChanges();
  }

  // Listen for real-time host online/offline events
  void _listenToStatusChanges() {
    SocketService.on('host_status_changed', _onStatusChanged);
    SocketService.on('host_online', _onHostOnline);
    SocketService.on('host_offline', _onHostOffline);
  }

  void _onStatusChanged(Map<String, dynamic> data) {
    final userId = data['userId']?.toString();
    final isOnline = data['isOnline'] as bool? ?? false;
    if (userId == null) return;
    _updateHostOnlineStatus(userId, isOnline);
  }

  void _onHostOnline(Map<String, dynamic> data) {
    final userId = data['userId']?.toString();
    if (userId != null) _updateHostOnlineStatus(userId, true);
  }

  void _onHostOffline(Map<String, dynamic> data) {
    final userId = data['userId']?.toString();
    if (userId != null) _updateHostOnlineStatus(userId, false);
  }

  void _updateHostOnlineStatus(String userId, bool isOnline) {
    final updated = state.hosts.map((h) {
      if (h.userId == userId) {
        return HostModel(
          id: h.id, userId: h.userId, name: h.name, avatar: h.avatar,
          bio: h.bio, languages: h.languages, audioRatePerMin: h.audioRatePerMin,
          videoRatePerMin: h.videoRatePerMin, rating: h.rating,
          totalCalls: h.totalCalls, isOnline: isOnline,
          isVerified: h.isVerified, followersCount: h.followersCount,
        );
      }
      return h;
    }).toList();
    state = state.copyWith(hosts: updated);
  }

  @override
  void dispose() {
    SocketService.off('host_status_changed', _onStatusChanged);
    SocketService.off('host_online', _onHostOnline);
    SocketService.off('host_offline', _onHostOffline);
    super.dispose();
  }

  Future<void> fetchHosts({bool refresh = true}) async {
    if (state.isLoading) return;
    final page = refresh ? 1 : state.page + 1;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final params = <String, dynamic>{'page': page, 'limit': 20};
      if (state.filter == 'Online') params['online'] = 'true';
      if (state.filter != 'All' && state.filter != 'Online') {
        params['language'] = state.filter;
      }
      if (state.search.isNotEmpty) params['search'] = state.search;

      final resp = await ApiClient.dio.get(
        ApiEndpoints.hosts,
        queryParameters: params,
      );
      final data = ApiClient.parseData(resp) as Map<String, dynamic>;
      final newHosts = (data['hosts'] as List)
          .map((h) => HostModel.fromJson(h as Map<String, dynamic>))
          .toList();
      final pagination = data['pagination'] as Map<String, dynamic>;
      final totalPages = pagination['pages'] as int;

      state = state.copyWith(
        hosts: refresh ? newHosts : [...state.hosts, ...newHosts],
        isLoading: false,
        page: page,
        hasMore: page < totalPages,
      );
    } on Exception catch (e) {
      // Fallback to demo data if backend unreachable
      if (refresh && state.hosts.isEmpty) {
        state = state.copyWith(
          hosts: HostModel.demoHosts,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  void setFilter(String filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter, hosts: [], page: 1, hasMore: true);
    fetchHosts();
  }

  void setSearch(String search) {
    state = state.copyWith(search: search, hosts: [], page: 1, hasMore: true);
    fetchHosts();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await fetchHosts(refresh: false);
  }

  List<HostModel> get filteredHosts {
    // Client-side filter for categories not yet applied server-side
    return state.hosts;
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────
final hostsProvider = StateNotifierProvider<HostsNotifier, HostsState>(
  (ref) => HostsNotifier(),
);

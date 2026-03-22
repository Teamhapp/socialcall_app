import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../socket/socket_service.dart';
import '../../models/host_model.dart';

// Sentinel for nullable copyWith fields
const _nil = Object();

// ── State ──────────────────────────────────────────────────────────────────────
class HostsState {
  final List<HostModel> hosts;
  final bool isLoading;
  final String? error;
  final int page;
  final bool hasMore;
  final String search;
  final String filter; // All / Online / language
  final String? genderFilter;    // null | 'male' | 'female'
  final String? ageGroupFilter;  // null | '18-25' | '25-35' | '35+'
  final String? tagFilter;       // null | any tag string
  // Non-null when a followed host just came online — UI shows a snackbar then clears it.
  final String? followedHostOnlineMessage;

  const HostsState({
    this.hosts = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
    this.search = '',
    this.filter = 'All',
    this.genderFilter,
    this.ageGroupFilter,
    this.tagFilter,
    this.followedHostOnlineMessage,
  });

  HostsState copyWith({
    List<HostModel>? hosts,
    bool? isLoading,
    String? error,
    int? page,
    bool? hasMore,
    String? search,
    String? filter,
    Object? genderFilter = _nil,
    Object? ageGroupFilter = _nil,
    Object? tagFilter = _nil,
    String? followedHostOnlineMessage,
    bool clearHostOnlineMessage = false,
  }) =>
      HostsState(
        hosts: hosts ?? this.hosts,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        search: search ?? this.search,
        filter: filter ?? this.filter,
        genderFilter:   genderFilter   == _nil ? this.genderFilter   : genderFilter   as String?,
        ageGroupFilter: ageGroupFilter == _nil ? this.ageGroupFilter : ageGroupFilter as String?,
        tagFilter:      tagFilter      == _nil ? this.tagFilter      : tagFilter      as String?,
        followedHostOnlineMessage: clearHostOnlineMessage
            ? null
            : followedHostOnlineMessage ?? this.followedHostOnlineMessage,
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
    SocketService.on('followed_host_online', _onFollowedHostOnline);
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

  void _onFollowedHostOnline(Map<String, dynamic> data) {
    final name = data['hostName'] as String? ?? 'A host';
    state = state.copyWith(
      followedHostOnlineMessage: '💜 $name is now online! Tap to call.',
    );
  }

  /// Call this after the UI has shown the snackbar to clear the message.
  void clearFollowedHostOnlineMessage() {
    state = state.copyWith(clearHostOnlineMessage: true);
  }

  void _updateHostOnlineStatus(String userId, bool isOnline) {
    final updated = state.hosts
        .map((h) => h.userId == userId ? h.copyWith(isOnline: isOnline) : h)
        .toList();
    state = state.copyWith(hosts: updated);
  }

  @override
  void dispose() {
    SocketService.off('host_status_changed', _onStatusChanged);
    SocketService.off('host_online', _onHostOnline);
    SocketService.off('host_offline', _onHostOffline);
    SocketService.off('followed_host_online', _onFollowedHostOnline);
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
      if (state.search.isNotEmpty)       params['search']    = state.search;
      if (state.genderFilter != null)    params['gender']    = state.genderFilter!;
      if (state.ageGroupFilter != null)  params['age_group'] = state.ageGroupFilter!;
      if (state.tagFilter != null)       params['tag']       = state.tagFilter!;

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

  void setGenderFilter(String? gender) {
    if (gender == state.genderFilter) return;
    state = state.copyWith(genderFilter: gender, hosts: [], page: 1, hasMore: true);
    fetchHosts();
  }

  void setAgeGroupFilter(String? ageGroup) {
    if (ageGroup == state.ageGroupFilter) return;
    state = state.copyWith(ageGroupFilter: ageGroup, hosts: [], page: 1, hasMore: true);
    fetchHosts();
  }

  void setTagFilter(String? tag) {
    if (tag == state.tagFilter) return;
    state = state.copyWith(tagFilter: tag, hosts: [], page: 1, hasMore: true);
    fetchHosts();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await fetchHosts(refresh: false);
  }

  List<HostModel> get filteredHosts {
    return state.hosts;
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────
final hostsProvider = StateNotifierProvider<HostsNotifier, HostsState>(
  (ref) => HostsNotifier(),
);

// ── Tags provider — fetches distinct host tags from backend ───────────────────
final tagsProvider = FutureProvider<List<String>>((ref) async {
  try {
    final resp = await ApiClient.dio.get(ApiEndpoints.hostTags);
    final data = ApiClient.parseData(resp);
    if (data is List) return List<String>.from(data);
    if (data is Map && data['tags'] is List) {
      return List<String>.from(data['tags'] as List);
    }
    return const [];
  } catch (_) {
    return const [];
  }
});

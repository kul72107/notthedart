import 'package:dio/dio.dart';

import '../../../core/cache/runtime_cache.dart';
import '../../../core/network/api_client.dart';
import '../models.dart';

class CatpoisonBalance {
  const CatpoisonBalance({
    required this.balance,
    required this.watchedToday,
    this.pendingCount = 0,
    this.pendingRewards = const [],
  });

  final double balance;
  final int watchedToday;
  final int pendingCount;
  final List<Map<String, dynamic>> pendingRewards;
}

class CatloveBalance {
  const CatloveBalance({required this.balance});

  final double balance;
}

class CatloveOffer {
  const CatloveOffer({
    required this.key,
    required this.catlove,
    required this.usd,
    required this.bonusPercent,
  });

  final String key;
  final double catlove;
  final double usd;
  final int bonusPercent;

  factory CatloveOffer.fromJson(Map<String, dynamic> json) {
    return CatloveOffer(
      key: json['key']?.toString() ?? '',
      catlove: _asDouble(json['catlove']),
      usd: _asDouble(json['usd']),
      bonusPercent: _asInt(json['bonusPercent']),
    );
  }
}

class CatloveOffersResponse {
  const CatloveOffersResponse({
    required this.offers,
    this.clPerDollar,
    this.source7dIncome,
    this.nextRefreshAt,
    this.lastCalculatedAt,
  });

  final List<CatloveOffer> offers;
  final double? clPerDollar;
  final double? source7dIncome;
  final DateTime? nextRefreshAt;
  final DateTime? lastCalculatedAt;
}

class MeowverseApi {
  MeowverseApi(this._client);

  final ApiClient _client;
  final RuntimeCache _cache = RuntimeCache.instance;
  String get _userCacheScope => _client.authController.user?.id ?? 'anon';

  Future<List<AvatarRecord>> fetchGallery({
    String filter = 'newest',
    int limit = 12,
    int offset = 0,
  }) async {
    final cacheKey = 'gallery:$filter:$limit:$offset';
    final cached = _cache.get<List<AvatarRecord>>(cacheKey);
    if (cached != null) return cached;

    final data = await _safeGet(
      '/api/gallery',
      query: <String, dynamic>{
        'filter': filter,
        'limit': limit,
        'offset': offset,
      },
    );
    final avatars = (data['avatars'] as List?) ?? const [];
    final parsed = avatars
        .whereType<Map>()
        .map((raw) => AvatarRecord.fromJson(raw.cast<String, dynamic>()))
        .toList();
    _cache.put<List<AvatarRecord>>(
      cacheKey,
      parsed,
      const Duration(seconds: 20),
    );
    return parsed;
  }

  Future<List<AvatarRecord>> fetchExplore({
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = 'explore:$limit:$offset';
    final cached = _cache.get<List<AvatarRecord>>(cacheKey);
    if (cached != null) return cached;

    final data = await _safeGet(
      '/api/explore',
      query: <String, dynamic>{'limit': limit, 'offset': offset},
    );
    final avatars = (data['avatars'] as List?) ?? const [];
    final parsed = avatars
        .whereType<Map>()
        .map((raw) => AvatarRecord.fromJson(raw.cast<String, dynamic>()))
        .toList();
    _cache.put<List<AvatarRecord>>(
      cacheKey,
      parsed,
      const Duration(seconds: 12),
    );
    return parsed;
  }

  Future<void> sendView(int avatarId) async {
    await _safePost('/api/view', data: <String, dynamic>{'avatarId': avatarId});
  }

  Future<Map<String, dynamic>> likeAvatar(int avatarId) {
    _cache.invalidatePrefix('explore:');
    _cache.invalidatePrefix('gallery:');
    return _safePost(
      '/api/likes',
      data: <String, dynamic>{'avatarId': avatarId},
    );
  }

  Future<Map<String, dynamic>> dislikeAvatar(int avatarId) {
    _cache.invalidatePrefix('explore:');
    return _safePut(
      '/api/likes',
      data: <String, dynamic>{'avatarId': avatarId, 'rating': 1},
    );
  }

  Future<Map<String, dynamic>> rateAvatar(int avatarId, int rating) {
    _cache.invalidatePrefix('explore:');
    return _safePut(
      '/api/likes',
      data: <String, dynamic>{'avatarId': avatarId, 'rating': rating},
    );
  }

  Future<void> removeLike(int avatarId) async {
    _cache.invalidatePrefix('explore:');
    await _safeDelete(
      '/api/likes',
      data: <String, dynamic>{'avatarId': avatarId},
    );
  }

  Future<List<AvatarRecord>> fetchMarketListings({
    String mode = 'explore',
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = 'market:$mode:$limit:$offset:$_userCacheScope';
    final cached = _cache.get<List<AvatarRecord>>(cacheKey);
    if (cached != null) return cached;

    final data = await _safeGet(
      '/api/market-cats',
      query: <String, dynamic>{'mode': mode, 'limit': limit, 'offset': offset},
    );
    final listings = (data['listings'] as List?) ?? const [];
    final parsed = listings
        .whereType<Map>()
        .map((raw) => AvatarRecord.fromJson(raw.cast<String, dynamic>()))
        .toList();
    _cache.put<List<AvatarRecord>>(
      cacheKey,
      parsed,
      const Duration(seconds: 12),
    );
    return parsed;
  }

  Future<Map<String, dynamic>> buyMarketListing(int listingId) {
    _cache.invalidatePrefix('market:');
    _cache.invalidatePrefix('my-listings:');
    _cache.invalidatePrefix('cp-balance');
    return _safePost('/api/market-cats/$listingId');
  }

  Future<Map<String, dynamic>> createMarketListing({
    required int avatarId,
    required double priceCatpoison,
  }) {
    _cache.invalidatePrefix('market:');
    _cache.invalidatePrefix('my-listings:');
    return _safePost(
      '/api/market-cats',
      data: <String, dynamic>{
        'avatarId': avatarId,
        'priceCatpoison': priceCatpoison,
      },
    );
  }

  Future<Map<String, dynamic>> boostMarketListing(int listingId) {
    _cache.invalidatePrefix('market:');
    _cache.invalidatePrefix('my-listings:');
    return _safePatch('/api/market-cats/$listingId');
  }

  Future<void> removeMarketListing(int listingId) async {
    _cache.invalidatePrefix('market:');
    _cache.invalidatePrefix('my-listings:');
    await _safeDelete(
      '/api/market-cats',
      query: <String, dynamic>{'listingId': listingId},
    );
  }

  Future<void> markMarketListingViewed(int listingId) async {
    await _safePut('/api/market-cats/$listingId');
  }

  Future<MyListingsResponse> fetchMyListings() async {
    final cacheKey = 'my-listings:data:$_userCacheScope';
    final cached = _cache.get<MyListingsResponse>(cacheKey);
    if (cached != null) return cached;

    final data = await _safeGet('/api/my-listings');
    final parsed = MyListingsResponse.fromJson(data);
    _cache.put<MyListingsResponse>(
      cacheKey,
      parsed,
      const Duration(seconds: 10),
    );
    return parsed;
  }

  Future<List<AvatarRecord>> fetchMyCats() async {
    final cacheKey = 'my-cats:data:$_userCacheScope';
    final cached = _cache.get<List<AvatarRecord>>(cacheKey);
    if (cached != null) return cached;

    final data = await _safeGet('/api/my-cats');
    final rawCats = (data['cats'] as List?) ?? const [];
    final parsed = rawCats
        .whereType<Map>()
        .map((raw) => AvatarRecord.fromJson(raw.cast<String, dynamic>()))
        .toList();
    _cache.put<List<AvatarRecord>>(
      cacheKey,
      parsed,
      const Duration(seconds: 10),
    );
    return parsed;
  }

  Future<void> deleteMyCat(int catId) async {
    _cache.invalidatePrefix('my-cats:');
    _cache.invalidatePrefix('profile:');
    await _safeDelete('/api/my-cats', query: <String, dynamic>{'id': catId});
  }

  Future<CatpoisonBalance> fetchCatpoisonBalance() async {
    final cacheKey = 'cp-balance:$_userCacheScope';
    final cached = _cache.get<CatpoisonBalance>(cacheKey);
    if (cached != null) return cached;

    final data = await _safeGet('/api/catpoison/balance');
    final parsed = CatpoisonBalance(
      balance: _asDouble(data['balance']),
      watchedToday: _asInt(data['watchedToday']),
      pendingCount: _asInt(data['pendingCount']),
      pendingRewards: ((data['pendingRewards'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
    );
    _cache.put<CatpoisonBalance>(cacheKey, parsed, const Duration(seconds: 8));
    return parsed;
  }

  Future<CatloveBalance> fetchCatloveBalance() async {
    final cacheKey = 'cl-balance:$_userCacheScope';
    final cached = _cache.get<CatloveBalance>(cacheKey);
    if (cached != null) return cached;

    final data = await _safeGet('/api/catlove/balance');
    final parsed = CatloveBalance(balance: _asDouble(data['balance']));
    _cache.put<CatloveBalance>(cacheKey, parsed, const Duration(seconds: 8));
    return parsed;
  }

  Future<CatloveOffersResponse> fetchCatloveOffers() async {
    final data = await _safeGet('/api/catlove/offers');
    final offersRaw = (data['offers'] as List?) ?? const [];
    final offers = offersRaw
        .whereType<Map>()
        .map((raw) => CatloveOffer.fromJson(raw.cast<String, dynamic>()))
        .toList();
    return CatloveOffersResponse(
      offers: offers,
      clPerDollar: data['clPerDollar'] == null
          ? null
          : _asDouble(data['clPerDollar']),
      source7dIncome: data['source7dIncome'] == null
          ? null
          : _asDouble(data['source7dIncome']),
      nextRefreshAt: _asDateTime(data['nextRefreshAt']),
      lastCalculatedAt: _asDateTime(data['lastCalculatedAt']),
    );
  }

  Future<Map<String, dynamic>> purchaseCatlove(String packageKey) {
    _cache.invalidatePrefix('cl-balance');
    return _safePost(
      '/api/catlove/purchase',
      data: <String, dynamic>{'packageKey': packageKey},
    );
  }

  Future<Map<String, dynamic>> watchAdForCp() {
    _cache.invalidatePrefix('cp-balance');
    return _safePost('/api/catpoison/earn');
  }

  Future<Map<String, dynamic>> claimPendingReward({
    required int rewardId,
    required String rewardType,
  }) {
    _cache.invalidatePrefix('cp-balance');
    _cache.invalidatePrefix('cl-balance');
    _cache.invalidatePrefix('market:');
    return _safePost(
      '/api/catpoison/balance',
      data: <String, dynamic>{'rewardId': rewardId, 'rewardType': rewardType},
    );
  }

  Future<Map<String, dynamic>> buyCpPack(String packageKey) {
    _cache.invalidatePrefix('cp-balance');
    return _safePut(
      '/api/catpoison/earn',
      data: <String, dynamic>{'packageKey': packageKey},
    );
  }

  Future<Map<String, dynamic>> fetchRanked() {
    const cacheKey = 'ranked:state';
    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return Future<Map<String, dynamic>>.value(cached);
    return _safeGet('/api/ranked').then((data) {
      _cache.put<Map<String, dynamic>>(
        cacheKey,
        data,
        const Duration(seconds: 8),
      );
      return data;
    });
  }

  Future<Map<String, dynamic>> rankedAction(
    String action, {
    Map<String, dynamic>? extra,
  }) {
    _cache.invalidatePrefix('ranked:');
    return _safePost(
      '/api/ranked',
      data: <String, dynamic>{'action': action, ...?extra},
    );
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    const cacheKey = 'leaderboard:list';
    final cached = _cache.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

    final data = await _safeGet('/api/leaderboard');
    final list = (data['leaderboard'] as List?) ?? const [];
    final parsed = list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    _cache.put<List<Map<String, dynamic>>>(
      cacheKey,
      parsed,
      const Duration(seconds: 20),
    );
    return parsed;
  }

  Future<Map<String, dynamic>> fetchProfile(String userId) {
    final cacheKey = 'profile:$userId';
    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return Future<Map<String, dynamic>>.value(cached);
    return _safeGet('/api/profile/$userId').then((data) {
      _cache.put<Map<String, dynamic>>(
        cacheKey,
        data,
        const Duration(seconds: 12),
      );
      return data;
    });
  }

  Future<void> setProfileAvatar(String userId, int avatarId) async {
    _cache.invalidatePrefix('profile:$userId');
    _cache.invalidatePrefix('my-cats:');
    await _safePut(
      '/api/profile/$userId',
      data: <String, dynamic>{'avatarId': avatarId},
    );
  }

  Future<Map<String, dynamic>> fetchAuthToken() {
    return _safeGet('/api/auth/token');
  }

  Future<Map<String, dynamic>> fetchThemes() {
    const cacheKey = 'themes:owned';
    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return Future<Map<String, dynamic>>.value(cached);
    return _safeGet('/api/themes').then((data) {
      _cache.put<Map<String, dynamic>>(
        cacheKey,
        data,
        const Duration(seconds: 20),
      );
      return data;
    });
  }

  Future<Map<String, dynamic>> buyTheme(String themeKey) {
    _cache.invalidatePrefix('themes:');
    _cache.invalidatePrefix('cp-balance');
    return _safePost(
      '/api/themes',
      data: <String, dynamic>{'themeKey': themeKey},
    );
  }

  Future<Map<String, dynamic>> fetchSubscriptionStatus() {
    return _safePost('/api/revenue-cat/get-subscription-status');
  }

  Future<Map<String, dynamic>> _safeGet(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _client.getJson(path, queryParameters: query);
    } on DioException catch (err) {
      return _throwApiError(err);
    }
  }

  Future<Map<String, dynamic>> _safePost(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _client.postJson(path, data: data, queryParameters: query);
    } on DioException catch (err) {
      return _throwApiError(err);
    }
  }

  Future<Map<String, dynamic>> _safePut(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _client.putJson(path, data: data, queryParameters: query);
    } on DioException catch (err) {
      if (err.response?.statusCode == 405) {
        return _safePost(path, data: data, query: query);
      }
      return _throwApiError(err);
    }
  }

  Future<Map<String, dynamic>> _safePatch(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _client.patchJson(path, data: data, queryParameters: query);
    } on DioException catch (err) {
      return _throwApiError(err);
    }
  }

  Future<Map<String, dynamic>> _safeDelete(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _client.deleteJson(path, data: data, queryParameters: query);
    } on DioException catch (err) {
      return _throwApiError(err);
    }
  }

  Never _throwApiError(DioException err) {
    final payload = err.response?.data;
    if (payload is Map) {
      final map = payload.cast<String, dynamic>();
      final message =
          map['error']?.toString() ??
          map['message']?.toString() ??
          'API request failed';
      throw Exception(message);
    }
    throw Exception(err.message ?? 'API request failed');
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

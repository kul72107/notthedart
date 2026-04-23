import 'dart:convert';

class AvatarRecord {
  const AvatarRecord({
    required this.id,
    required this.avatarData,
    this.imageUrl,
    this.userId,
    this.userUsername,
    this.userEmail,
    this.description,
    this.likes,
    this.level,
    this.priceCatpoison,
    this.listingId,
    this.viewCount,
    this.totalRatings,
    this.ratingSum,
    this.isOwn = false,
    this.userLiked = false,
    this.userDisliked = false,
    this.userRating,
    this.createdAt,
    this.soldAt,
    this.source,
    this.uid,
    this.isPublished,
    this.publishCount,
    this.isListed = false,
  });

  final int id;
  final Map<String, dynamic> avatarData;
  final String? imageUrl;
  final int? userId;
  final String? userUsername;
  final String? userEmail;
  final String? description;
  final int? likes;
  final int? level;
  final double? priceCatpoison;
  final int? listingId;
  final int? viewCount;
  final int? totalRatings;
  final int? ratingSum;
  final bool isOwn;
  final bool userLiked;
  final bool userDisliked;
  final int? userRating;
  final DateTime? createdAt;
  final DateTime? soldAt;
  final String? source;
  final String? uid;
  final bool? isPublished;
  final int? publishCount;
  final bool isListed;

  factory AvatarRecord.fromJson(Map<String, dynamic> json) {
    final avatarData = _asJsonMap(json['avatar_data']);
    return AvatarRecord(
      id: _asInt(json['id']) ?? 0,
      avatarData: avatarData,
      imageUrl: json['image_url']?.toString(),
      userId: _asInt(json['user_id']),
      userUsername:
          json['user_username']?.toString() ??
          json['seller_username']?.toString(),
      userEmail:
          json['user_email']?.toString() ?? json['seller_email']?.toString(),
      description: json['description']?.toString(),
      likes: _asInt(json['likes']),
      level: _asInt(json['level']),
      priceCatpoison: _asDouble(json['price_catpoison']),
      listingId: _asInt(json['listing_id'] ?? json['id']),
      viewCount: _asInt(json['view_count']),
      totalRatings: _asInt(json['total_ratings']),
      ratingSum: _asInt(json['rating_sum']),
      isOwn: json['is_own'] == true,
      userLiked: json['user_liked'] == true,
      userDisliked: json['user_disliked'] == true,
      userRating: _asInt(json['user_rating']),
      createdAt: _parseDate(json['created_at']),
      soldAt: _parseDate(json['sold_at']),
      source: json['_source']?.toString(),
      uid: json['_uid']?.toString(),
      isPublished: json['is_published'] is bool
          ? json['is_published'] as bool
          : null,
      publishCount: _asInt(json['publish_count']),
      isListed: json['is_listed'] == true,
    );
  }

  AvatarRecord copyWith({
    int? likes,
    bool? userLiked,
    bool? userDisliked,
    int? userRating,
    int? viewCount,
  }) {
    return AvatarRecord(
      id: id,
      avatarData: avatarData,
      imageUrl: imageUrl,
      userId: userId,
      userUsername: userUsername,
      userEmail: userEmail,
      description: description,
      likes: likes ?? this.likes,
      level: level,
      priceCatpoison: priceCatpoison,
      listingId: listingId,
      viewCount: viewCount ?? this.viewCount,
      totalRatings: totalRatings,
      ratingSum: ratingSum,
      isOwn: isOwn,
      userLiked: userLiked ?? this.userLiked,
      userDisliked: userDisliked ?? this.userDisliked,
      userRating: userRating ?? this.userRating,
      createdAt: createdAt,
      soldAt: soldAt,
      source: source,
      uid: uid,
      isPublished: isPublished,
      publishCount: publishCount,
      isListed: isListed,
    );
  }
}

class MyListingsResponse {
  const MyListingsResponse({required this.active, required this.sold});

  final List<AvatarRecord> active;
  final List<AvatarRecord> sold;

  factory MyListingsResponse.fromJson(Map<String, dynamic> json) {
    final activeRaw = (json['active'] as List?) ?? const [];
    final soldRaw = (json['sold'] as List?) ?? const [];
    return MyListingsResponse(
      active: activeRaw
          .whereType<Map>()
          .map((item) => AvatarRecord.fromJson(item.cast<String, dynamic>()))
          .toList(),
      sold: soldRaw
          .whereType<Map>()
          .map((item) => AvatarRecord.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> _asJsonMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map) {
        return parsed.map((key, item) => MapEntry(key.toString(), item));
      }
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  return <String, dynamic>{};
}

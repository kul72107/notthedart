import 'dart:convert';

class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.name,
    this.image,
  });

  final String id;
  final String? email;
  final String? name;
  final String? image;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: '${json['id'] ?? ''}',
      email: json['email']?.toString(),
      name: json['name']?.toString(),
      image: json['image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'image': image,
      };
}

class AuthSession {
  const AuthSession({
    required this.jwt,
    required this.user,
  });

  final String jwt;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      jwt: json['jwt']?.toString() ?? '',
      user: AuthUser.fromJson((json['user'] as Map?)?.cast<String, dynamic>() ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'jwt': jwt,
        'user': user.toJson(),
      };

  String toStorageString() => jsonEncode(toJson());

  static AuthSession? fromStorageString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

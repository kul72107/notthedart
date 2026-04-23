import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';

enum AuthState { unknown, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController._(this._prefs, this._session);

  final SharedPreferences _prefs;
  static const _kSessionKey = 'meowverse_auth_session_v2';

  AuthSession? _session;
  AuthSession? get session => _session;
  bool get isSignedIn => _session != null && _session!.jwt.isNotEmpty;
  AuthUser? get user => _session?.user;
  String? get jwt => _session?.jwt;
  AuthState get state => isSignedIn ? AuthState.signedIn : AuthState.signedOut;

  static Future<AuthController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final session = AuthSession.fromStorageString(prefs.getString(_kSessionKey));
    return AuthController._(prefs, session);
  }

  Future<void> applyAuthPayload(Map<String, dynamic> payload) async {
    final session = AuthSession.fromJson(payload);
    if (session.jwt.isEmpty || session.user.id.isEmpty) return;
    _session = session;
    await _prefs.setString(_kSessionKey, session.toStorageString());
    notifyListeners();
  }

  Future<void> applyAuthPayloadFromTokenJson(String encodedJson) async {
    try {
      final decoded = jsonDecode(encodedJson);
      if (decoded is! Map<String, dynamic>) return;
      await applyAuthPayload(decoded);
    } catch (_) {
      return;
    }
  }

  Future<void> signOut() async {
    _session = null;
    await _prefs.remove(_kSessionKey);
    notifyListeners();
  }
}

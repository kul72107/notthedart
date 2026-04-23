import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiEnvironment { local, production }

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static const _kApiEnvironment = 'api_environment';
  static const _kLocalBaseUrl = 'api_local_base_url';
  static const _kProductionBaseUrl = 'api_production_base_url';
  static const _kDefaultEnvironment = String.fromEnvironment(
    'MEOWVERSE_API_DEFAULT_ENV',
    defaultValue: '',
  );
  static const _kDefinedLocalBaseUrl = String.fromEnvironment(
    'MEOWVERSE_API_LOCAL_BASE_URL',
    defaultValue: '',
  );
  static const _kDefinedProductionBaseUrl = String.fromEnvironment(
    'MEOWVERSE_API_PRODUCTION_BASE_URL',
    defaultValue: '',
  );
  static const _kCreateAnythingApiBaseUrl = String.fromEnvironment(
    'CREATEANYTHING_API_BASE_URL',
    defaultValue: '',
  );
  static const _kNextPublicCreateAppUrl = String.fromEnvironment(
    'NEXT_PUBLIC_CREATE_APP_URL',
    defaultValue: '',
  );
  static const _kExpoPublicBaseUrl = String.fromEnvironment(
    'EXPO_PUBLIC_BASE_URL',
    defaultValue: '',
  );
  static final String _kSafeLocalFallback = (kIsWeb && !kReleaseMode)
      ? 'http://127.0.0.1:4001'
      : 'http://10.0.2.2:3000';
  static final String _kSafeProductionFallback = kIsWeb
      ? _webOriginBaseUrl()
      : 'https://cat-oc-pfp-character-maker.created.app';

  static final String defaultLocalBaseUrl = _normalizeRuntimeBaseUrl(
    _kDefinedLocalBaseUrl,
    fallback: _kSafeLocalFallback,
  );
  static final String _forcedLocalBaseUrl = _normalizeRuntimeBaseUrl(
    _kDefinedLocalBaseUrl,
    fallback: '',
  );
  static final String _forcedProductionBaseUrl =
      _firstNonEmptyRuntimeBaseUrl(<String>[
        _kDefinedProductionBaseUrl,
        _kCreateAnythingApiBaseUrl,
        _kNextPublicCreateAppUrl,
        _kExpoPublicBaseUrl,
      ], fallback: '');
  static final String defaultProductionBaseUrl = _firstNonEmptyRuntimeBaseUrl(
    <String>[_forcedProductionBaseUrl],
    fallback: _kSafeProductionFallback,
  );

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  ApiEnvironment get apiEnvironment {
    // If explicit env is passed at build/run time, it must override persisted
    // local preference so web/debug runs can switch deterministically.
    if (_kDefaultEnvironment == 'production') return ApiEnvironment.production;
    if (_kDefaultEnvironment == 'local') return ApiEnvironment.local;

    // Flutter web debug must default to local API to avoid cross-origin
    // session/CORS issues from third-party hosted domains.
    if (kIsWeb && !kReleaseMode) {
      return ApiEnvironment.local;
    }

    final raw = _prefs.getString(_kApiEnvironment);
    if (raw == null || raw.isEmpty) {
      return kReleaseMode ? ApiEnvironment.production : ApiEnvironment.local;
    }
    if (raw == 'production') return ApiEnvironment.production;
    return ApiEnvironment.local;
  }

  String get localBaseUrl {
    if (_forcedLocalBaseUrl.isNotEmpty) {
      return _forcedLocalBaseUrl;
    }

    final storedRaw = _prefs.getString(_kLocalBaseUrl);
    if (storedRaw == null || storedRaw.trim().isEmpty) {
      return defaultLocalBaseUrl;
    }

    final normalized = _normalizeBaseUrl(
      storedRaw,
      fallback: defaultLocalBaseUrl,
    );
    if (kIsWeb && !kReleaseMode) {
      // Legacy persisted emulator host breaks Flutter web debug on desktop.
      if (normalized.contains('10.0.2.2')) {
        return defaultLocalBaseUrl;
      }
    }
    return normalized;
  }

  String get productionBaseUrl => _forcedProductionBaseUrl.isNotEmpty
      ? _forcedProductionBaseUrl
      : (_prefs.getString(_kProductionBaseUrl) ?? defaultProductionBaseUrl);

  String get apiBaseUrl => apiEnvironment == ApiEnvironment.production
      ? productionBaseUrl
      : localBaseUrl;

  Future<void> setApiEnvironment(ApiEnvironment environment) async {
    final value = environment == ApiEnvironment.production
        ? 'production'
        : 'local';
    await _prefs.setString(_kApiEnvironment, value);
    notifyListeners();
  }

  Future<void> setLocalBaseUrl(String value) async {
    await _prefs.setString(
      _kLocalBaseUrl,
      _normalizeBaseUrl(value, fallback: defaultLocalBaseUrl),
    );
    notifyListeners();
  }

  Future<void> setProductionBaseUrl(String value) async {
    await _prefs.setString(
      _kProductionBaseUrl,
      _normalizeBaseUrl(value, fallback: defaultProductionBaseUrl),
    );
    notifyListeners();
  }

  String _normalizeBaseUrl(String value, {required String fallback}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    if (isDatabaseConnectionString(trimmed)) return fallback;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !isHttpUrl(trimmed) || parsed.host.trim().isEmpty) {
      return fallback;
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static bool isDatabaseConnectionString(String value) {
    final v = value.trim().toLowerCase();
    return v.startsWith('postgres://') ||
        v.startsWith('postgresql://') ||
        v.startsWith('mysql://') ||
        v.startsWith('mariadb://') ||
        v.startsWith('mongodb://') ||
        v.startsWith('mongodb+srv://') ||
        v.startsWith('redis://') ||
        v.startsWith('rediss://') ||
        v.startsWith('sqlserver://');
  }

  static bool isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.trim().isNotEmpty;
  }

  static String _firstNonEmptyRuntimeBaseUrl(
    List<String> candidates, {
    required String fallback,
  }) {
    for (final candidate in candidates) {
      final normalized = _normalizeRuntimeBaseUrl(candidate, fallback: '');
      if (normalized.isNotEmpty) return normalized;
    }
    return fallback;
  }

  static String _normalizeRuntimeBaseUrl(
    String value, {
    required String fallback,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    if (isDatabaseConnectionString(trimmed)) return fallback;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !isHttpUrl(trimmed) || parsed.host.trim().isEmpty) {
      return fallback;
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String _webOriginBaseUrl() {
    final base = Uri.base;
    if (base.scheme != 'http' && base.scheme != 'https') {
      return 'https://cat-oc-pfp-character-maker.created.app';
    }
    final origin = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    ).toString();
    return origin.endsWith('/')
        ? origin.substring(0, origin.length - 1)
        : origin;
  }
}
